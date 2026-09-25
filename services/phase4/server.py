"""Local Phase 4 prototype API. Bind to loopback unless a TLS reverse proxy is used."""

from __future__ import annotations

import argparse
import hashlib
import json
import secrets
import sqlite3
import subprocess
import tempfile
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit

MAX_BODY = 2_097_152
MAX_ACTIONS = 20_000
LATE_SECONDS = 0
REDUCED_SINGLE_FIRST_WEEK = "2026-09-28"
UTC = timezone.utc


class ApiError(Exception):
    def __init__(self, status: int, code: str):
        super().__init__(code)
        self.status = status
        self.code = code


def canonical(value: object) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def week_bounds(now: datetime) -> tuple[str, int]:
    monday = (now - timedelta(days=now.weekday())).replace(hour=0, minute=0, second=0, microsecond=0)
    return monday.date().isoformat(), int((monday + timedelta(days=7)).timestamp())


def database(path: Path, initialize: bool = False) -> sqlite3.Connection:
    db = sqlite3.connect(path, timeout=10)
    db.row_factory = sqlite3.Row
    db.execute("PRAGMA busy_timeout=10000")
    db.execute("PRAGMA foreign_keys=ON")
    if initialize:
        db.execute("PRAGMA journal_mode=WAL")
        db.executescript("""
        CREATE TABLE IF NOT EXISTS accounts (
            id TEXT PRIMARY KEY, token_hash TEXT UNIQUE NOT NULL,
            alias TEXT NOT NULL, created_at INTEGER NOT NULL
        );
        CREATE TABLE IF NOT EXISTS challenges (
            id TEXT PRIMARY KEY, account_id TEXT NOT NULL REFERENCES accounts(id),
            week TEXT NOT NULL, seed TEXT NOT NULL, issued_at INTEGER NOT NULL,
            week_end INTEGER NOT NULL, supply_profile TEXT NOT NULL DEFAULT 'classic',
            UNIQUE(account_id, week)
        );
        CREATE TABLE IF NOT EXISTS submissions (
            challenge_id TEXT PRIMARY KEY REFERENCES challenges(id),
            account_id TEXT NOT NULL REFERENCES accounts(id), week TEXT NOT NULL,
            actions_json TEXT NOT NULL, trace_hash TEXT NOT NULL,
            floor_count INTEGER NOT NULL, tower_json TEXT NOT NULL,
            verified_at INTEGER NOT NULL
        );
        CREATE INDEX IF NOT EXISTS submissions_week_rank
            ON submissions(week, floor_count DESC, verified_at ASC);
        """)
        if "supply_profile" not in {row[1] for row in db.execute("PRAGMA table_info(challenges)")}:
            db.execute("ALTER TABLE challenges ADD COLUMN supply_profile TEXT NOT NULL DEFAULT 'classic'")
    return db


@contextmanager
def connection(path: Path, initialize: bool = False):
    db = database(path, initialize)
    try:
        yield db
        db.commit()
    except BaseException:
        db.rollback()
        raise
    finally:
        db.close()


class Api:
    def __init__(self, db_path: Path, engine: Path, project: Path):
        self.db_path, self.engine, self.project = db_path, engine, project
        db_path.parent.mkdir(parents=True, exist_ok=True)
        with connection(db_path, initialize=True):
            pass

    def account(self, token: str) -> sqlite3.Row:
        if len(token) != 64 or any(char not in "0123456789abcdef" for char in token):
            raise ApiError(401, "UNAUTHORIZED")
        with connection(self.db_path) as db:
            row = db.execute("SELECT id, alias FROM accounts WHERE token_hash=?", (hashlib.sha256(token.encode()).hexdigest(),)).fetchone()
        if row is None:
            raise ApiError(401, "UNAUTHORIZED")
        return row

    def create_account(self) -> dict:
        token = secrets.token_hex(32)
        account_id = secrets.token_hex(16)
        alias = "건축가-" + account_id[:6].upper()
        now = int(datetime.now(UTC).timestamp())
        with connection(self.db_path) as db:
            db.execute("INSERT INTO accounts VALUES (?, ?, ?, ?)",
                       (account_id, hashlib.sha256(token.encode()).hexdigest(), alias, now))
        return {"account_id": account_id, "alias": alias, "token": token}

    def challenge(self, account: sqlite3.Row) -> dict:
        now = datetime.now(UTC)
        week, week_end = week_bounds(now)
        with connection(self.db_path) as db:
            db.execute("BEGIN IMMEDIATE")
            row = db.execute("SELECT * FROM challenges WHERE account_id=? AND week=?", (account["id"], week)).fetchone()
            if row is None:
                challenge_id = secrets.token_hex(16)
                seed = str(secrets.randbelow(9_000_000_000_000_000) + 1)
                profile = "reduced_single" if week >= REDUCED_SINGLE_FIRST_WEEK else "classic"
                db.execute("""INSERT INTO challenges
                    (id, account_id, week, seed, issued_at, week_end, supply_profile)
                    VALUES (?, ?, ?, ?, ?, ?, ?)""",
                    (challenge_id, account["id"], week, seed, int(now.timestamp()), week_end, profile))
                row = db.execute("SELECT * FROM challenges WHERE id=?", (challenge_id,)).fetchone()
        return {"challenge_id": row["id"], "session_id": row["id"], "seed": row["seed"],
                "week": row["week"], "issued_at": row["issued_at"], "week_end": row["week_end"],
                "submit_until": row["week_end"] + LATE_SECONDS, "rule_version": "bt_rules_v1",
                "supply_profile": row["supply_profile"]}

    def replay(self, challenge_id: str, seed: str, supply_profile: str, actions: list) -> dict:
        with tempfile.TemporaryDirectory(prefix="blocktower_replay_") as folder:
            source, output = Path(folder) / "input.json", Path(folder) / "output.json"
            source.write_text(canonical({"session_id": challenge_id, "seed": seed,
                                         "supply_profile": supply_profile, "actions": actions}), encoding="utf-8")
            try:
                run = subprocess.run(
                    [str(self.engine), "--headless", "--path", str(self.project),
                     "--script", "res://scripts/online/verify_replay.gd", "--", str(source), str(output)],
                    capture_output=True, text=True, timeout=30, check=False,
                )
            except (OSError, subprocess.TimeoutExpired) as error:
                raise ApiError(503, "VERIFIER_UNAVAILABLE") from error
            if not output.is_file():
                raise ApiError(503, "VERIFIER_UNAVAILABLE")
            try:
                result = json.loads(output.read_text(encoding="utf-8"))
            except (ValueError, OSError) as error:
                raise ApiError(503, "VERIFIER_UNAVAILABLE") from error
            if run.returncode != 0 and isinstance(result, dict) and result.get("ok") is True:
                raise ApiError(503, "VERIFIER_UNAVAILABLE")
            if not isinstance(result, dict) or result.get("ok") is not True:
                raise ApiError(422, str(result.get("error", "INVALID_TRACE")) if isinstance(result, dict) else "INVALID_TRACE")
            if type(result.get("floor_count")) is not int or not isinstance(result.get("tower"), dict):
                raise ApiError(503, "VERIFIER_UNAVAILABLE")
            return result

    def submit(self, account: sqlite3.Row, body: object) -> dict:
        if not isinstance(body, dict) or set(body) != {"challenge_id", "actions"}:
            raise ApiError(400, "INVALID_REQUEST")
        challenge_id, actions = body["challenge_id"], body["actions"]
        if not isinstance(challenge_id, str) or not isinstance(actions, list) or len(actions) > MAX_ACTIONS:
            raise ApiError(400, "INVALID_REQUEST")
        now = int(datetime.now(UTC).timestamp())
        with connection(self.db_path) as db:
            challenge = db.execute("SELECT * FROM challenges WHERE id=? AND account_id=?", (challenge_id, account["id"])).fetchone()
            if challenge is None:
                raise ApiError(404, "CHALLENGE_NOT_FOUND")
            if now >= challenge["week_end"] + LATE_SECONDS:
                raise ApiError(409, "CHALLENGE_CLOSED")
            previous = db.execute("SELECT actions_json, trace_hash FROM submissions WHERE challenge_id=?", (challenge_id,)).fetchone()
        trace = canonical(actions)
        digest = hashlib.sha256(trace.encode("utf-8")).hexdigest()
        if previous and previous["trace_hash"] == digest and previous["actions_json"] == trace:
            return {"ok": True, "duplicate": True, "week": challenge["week"]}
        if previous and not is_extension(json.loads(previous["actions_json"]), actions):
            raise ApiError(409, "TRACE_NOT_EXTENSION")
        replay = self.replay(challenge_id, challenge["seed"], challenge["supply_profile"], actions)
        if replay["revision"] != len(actions):
            raise ApiError(422, "REVISION_MISMATCH")
        with connection(self.db_path) as db:
            db.execute("BEGIN IMMEDIATE")
            verified_at = int(datetime.now(UTC).timestamp())
            if verified_at >= challenge["week_end"] + LATE_SECONDS:
                raise ApiError(409, "CHALLENGE_CLOSED")
            current = db.execute("SELECT actions_json, trace_hash, floor_count, verified_at FROM submissions WHERE challenge_id=?", (challenge_id,)).fetchone()
            if current and current["trace_hash"] == digest and current["actions_json"] == trace:
                return {"ok": True, "duplicate": True, "week": challenge["week"]}
            if current and not is_extension(json.loads(current["actions_json"]), actions):
                raise ApiError(409, "TRACE_NOT_EXTENSION")
            rank_at = current["verified_at"] if current and current["floor_count"] == replay["floor_count"] else verified_at
            db.execute("""INSERT INTO submissions VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(challenge_id) DO UPDATE SET actions_json=excluded.actions_json,
                trace_hash=excluded.trace_hash, floor_count=excluded.floor_count,
                tower_json=excluded.tower_json, verified_at=excluded.verified_at""",
                (challenge_id, account["id"], challenge["week"], trace, digest,
                 replay["floor_count"], canonical(replay["tower"]), rank_at))
        return {"ok": True, "duplicate": False, "week": challenge["week"],
                "floor_count": replay["floor_count"], "tower": replay["tower"]}

    def leaderboard(self) -> dict:
        week, week_end = week_bounds(datetime.now(UTC))
        with connection(self.db_path) as db:
            rows = db.execute("""SELECT a.id, a.alias, s.floor_count, s.tower_json, s.verified_at
                FROM submissions s JOIN accounts a ON a.id=s.account_id WHERE s.week=?
                ORDER BY s.floor_count DESC, s.verified_at ASC, a.id ASC LIMIT 50""", (week,)).fetchall()
        return {"week": week, "final_at": week_end + LATE_SECONDS,
                "entries": [{"rank": i + 1, "account_id": row["id"], "alias": row["alias"],
                             "floor_count": row["floor_count"], "tower": json.loads(row["tower_json"])}
                            for i, row in enumerate(rows)]}


def is_extension(previous: list, proposed: list) -> bool:
    return len(proposed) > len(previous) and proposed[:len(previous)] == previous


class Handler(BaseHTTPRequestHandler):
    api: Api

    def reply(self, status: int, value: object) -> None:
        data = canonical(value).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(data)

    def body(self) -> object:
        length = self.headers.get("Content-Length", "")
        if not length.isdecimal() or int(length) > MAX_BODY:
            raise ApiError(413, "BODY_TOO_LARGE")
        try:
            return json.loads(self.rfile.read(int(length)))
        except ValueError as error:
            raise ApiError(400, "INVALID_JSON") from error

    def authenticated(self) -> sqlite3.Row:
        header = self.headers.get("Authorization", "")
        if not header.startswith("Bearer "):
            raise ApiError(401, "UNAUTHORIZED")
        return self.api.account(header[7:])

    def do_GET(self) -> None:
        try:
            path = urlsplit(self.path).path
            if path == "/v1/leaderboard/current":
                self.reply(200, self.api.leaderboard())
            elif path == "/v1/me":
                account = self.authenticated()
                self.reply(200, {"account_id": account["id"], "alias": account["alias"]})
            else:
                raise ApiError(404, "NOT_FOUND")
        except ApiError as error:
            self.reply(error.status, {"ok": False, "error": error.code})

    def do_POST(self) -> None:
        try:
            path = urlsplit(self.path).path
            body = self.body()
            if path == "/v1/accounts/guest":
                if body != {}:
                    raise ApiError(400, "INVALID_REQUEST")
                self.reply(201, self.api.create_account())
            elif path == "/v1/challenges/current":
                if body != {}:
                    raise ApiError(400, "INVALID_REQUEST")
                self.reply(200, self.api.challenge(self.authenticated()))
            elif path == "/v1/submissions":
                self.reply(200, self.api.submit(self.authenticated(), body))
            else:
                raise ApiError(404, "NOT_FOUND")
        except ApiError as error:
            self.reply(error.status, {"ok": False, "error": error.code})


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, required=True)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[2] / "game")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args()
    if args.host not in ("127.0.0.1", "::1"):
        parser.error("Bind to loopback; use a TLS reverse proxy for external access")
    if not args.godot.is_file() or not (args.project / "project.godot").is_file():
        parser.error("Pinned Godot executable and project.godot are required")
    api = Api(args.db.resolve(), args.godot.resolve(), args.project.resolve())
    server = ThreadingHTTPServer((args.host, args.port), type("Phase4Handler", (Handler,), {"api": api}))
    print(f"Phase 4 local API on {args.host}:{args.port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()

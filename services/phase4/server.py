"""Local Phase 4 prototype API. Bind to loopback unless a TLS reverse proxy is used."""

from __future__ import annotations

import argparse
import hashlib
import ipaddress
import json
import math
import secrets
import sqlite3
import subprocess
import tempfile
import threading
import time
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit

MAX_BODY = 2_097_152
MAX_ACTIONS = 20_000
RATE_WINDOW_SECONDS = 60
MAX_RATE_BUCKETS = 8192
RATE_LIMITS = {"guest": 12, "recover": 8, "submit": 12, "other": 120}
LATE_SECONDS = 0
REDUCED_SINGLE_FIRST_WEEK = "2026-09-28"
CURRENT_RULE_VERSION = "bt_rules_v1"
DEFAULT_VERIFIER_PROJECT = Path(__file__).resolve().parent / "verifiers" / CURRENT_RULE_VERSION
UTC = timezone.utc


class ApiError(Exception):
    def __init__(self, status: int, code: str, retry_after: int = 0):
        super().__init__(code)
        self.status = status
        self.code = code
        self.retry_after = retry_after


class RateLimiter:
    def __init__(self):
        self.lock = threading.Lock()
        self.buckets: dict[tuple[str, str], tuple[float, int]] = {}

    def check(self, client_ip: str, group: str) -> None:
        now = time.monotonic()
        key = (client_ip, group)
        with self.lock:
            start, count = self.buckets.get(key, (now, 0))
            if now - start >= RATE_WINDOW_SECONDS:
                start, count = now, 0
            if count >= RATE_LIMITS[group]:
                raise ApiError(429, "RATE_LIMITED", max(1, math.ceil(RATE_WINDOW_SECONDS - (now - start))))
            if key not in self.buckets and len(self.buckets) >= MAX_RATE_BUCKETS:
                # 오래된 창을 먼저 버리고, 상한을 채운 경우 가장 오래된 항목을 제거한다.
                self.buckets = {bucket: value for bucket, value in self.buckets.items()
                                if now - value[0] < RATE_WINDOW_SECONDS}
                if len(self.buckets) >= MAX_RATE_BUCKETS:
                    oldest = min(self.buckets, key=lambda bucket: self.buckets[bucket][0])
                    del self.buckets[oldest]
            self.buckets[key] = (start, count + 1)


def canonical(value: object) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def week_bounds(now: datetime) -> tuple[str, int]:
    monday = (now - timedelta(days=now.weekday())).replace(hour=0, minute=0, second=0, microsecond=0)
    return monday.date().isoformat(), int((monday + timedelta(days=7)).timestamp())


def verify_bundle(project: Path, rule_version: str) -> bool:
    manifest_path = project / "manifest.json"
    if not manifest_path.is_file():
        return False
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        files = manifest["files"]
        if (manifest["rule_version"] != rule_version or manifest["godot_version"] != "4.7.2"
                or not isinstance(files, dict) or not files):
            return False
        root = project.resolve()
        for relative, digest in files.items():
            if not isinstance(relative, str) or not isinstance(digest, str) or len(digest) != 64:
                return False
            path = (root / relative).resolve()
            if not path.is_relative_to(root) or not path.is_file():
                return False
            if hashlib.sha256(path.read_bytes()).hexdigest() != digest:
                return False
        return "project.godot" in files and "scripts/online/verify_replay.gd" in files
    except (OSError, ValueError, KeyError, TypeError):
        return False


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
            alias TEXT NOT NULL, created_at INTEGER NOT NULL,
            recovery_hash TEXT UNIQUE
        );
        CREATE TABLE IF NOT EXISTS challenges (
            id TEXT PRIMARY KEY, account_id TEXT NOT NULL REFERENCES accounts(id),
            week TEXT NOT NULL, seed TEXT NOT NULL, issued_at INTEGER NOT NULL,
            week_end INTEGER NOT NULL, supply_profile TEXT NOT NULL DEFAULT 'classic',
            rule_version TEXT NOT NULL DEFAULT 'bt_rules_v1',
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
        if "rule_version" not in {row[1] for row in db.execute("PRAGMA table_info(challenges)")}:
            db.execute("ALTER TABLE challenges ADD COLUMN rule_version TEXT NOT NULL DEFAULT 'bt_rules_v1'")
        if "recovery_hash" not in {row[1] for row in db.execute("PRAGMA table_info(accounts)")}:
            db.execute("ALTER TABLE accounts ADD COLUMN recovery_hash TEXT")
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
    def __init__(self, db_path: Path, engine: Path, project: Path,
                 verifiers: dict[str, tuple[Path, Path]] | None = None):
        self.db_path, self.engine, self.project = db_path, engine, project
        self.verifiers = verifiers or {CURRENT_RULE_VERSION: (engine, project)}
        self.frozen_versions = {version for version, (_, folder) in self.verifiers.items()
                                if (folder / "manifest.json").is_file()}
        if CURRENT_RULE_VERSION not in self.verifiers:
            raise RuntimeError("current rule verifier is not configured")
        for version, (binary, folder) in self.verifiers.items():
            if not binary.is_file() or not (folder / "project.godot").is_file():
                raise RuntimeError(f"verifier unavailable for {version}")
            if version in self.frozen_versions and not verify_bundle(folder, version):
                raise RuntimeError(f"verifier bundle changed for {version}")
        self.replay_slots = threading.BoundedSemaphore(2)
        db_path.parent.mkdir(parents=True, exist_ok=True)
        with connection(db_path, initialize=True) as db:
            versions = {row[0] for row in db.execute("SELECT DISTINCT rule_version FROM challenges")}
            missing = versions - set(self.verifiers)
            if missing:
                raise RuntimeError("missing retained verifier for: " + ", ".join(sorted(missing)))

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
            db.execute("INSERT INTO accounts (id, token_hash, alias, created_at) VALUES (?, ?, ?, ?)",
                       (account_id, hashlib.sha256(token.encode()).hexdigest(), alias, now))
        return {"account_id": account_id, "alias": alias, "token": token}

    def issue_recovery_code(self, account: sqlite3.Row) -> dict:
        raw = secrets.token_hex(16).upper()
        code = "-".join(raw[index:index + 4] for index in range(0, 32, 4))
        digest = hashlib.sha256(raw.encode("ascii")).hexdigest()
        with connection(self.db_path) as db:
            db.execute("UPDATE accounts SET recovery_hash=? WHERE id=?", (digest, account["id"]))
        return {"recovery_code": code}

    def recover_account(self, body: object) -> dict:
        if not isinstance(body, dict) or set(body) != {"recovery_code"} or not isinstance(body["recovery_code"], str):
            raise ApiError(400, "INVALID_REQUEST")
        raw = body["recovery_code"].replace("-", "").strip().upper()
        if len(raw) != 32 or any(char not in "0123456789ABCDEF" for char in raw):
            raise ApiError(401, "RECOVERY_CODE_INVALID")
        digest = hashlib.sha256(raw.encode("ascii")).hexdigest()
        token = secrets.token_hex(32)
        with connection(self.db_path) as db:
            db.execute("BEGIN IMMEDIATE")
            account = db.execute("SELECT id, alias FROM accounts WHERE recovery_hash=?", (digest,)).fetchone()
            if account is None:
                raise ApiError(401, "RECOVERY_CODE_INVALID")
            db.execute("UPDATE accounts SET token_hash=? WHERE id=?",
                       (hashlib.sha256(token.encode()).hexdigest(), account["id"]))
        return {"account_id": account["id"], "alias": account["alias"], "token": token}

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
                    (id, account_id, week, seed, issued_at, week_end, supply_profile, rule_version)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
                    (challenge_id, account["id"], week, seed, int(now.timestamp()), week_end, profile,
                     CURRENT_RULE_VERSION))
                row = db.execute("SELECT * FROM challenges WHERE id=?", (challenge_id,)).fetchone()
            accepted = db.execute("SELECT actions_json FROM submissions WHERE challenge_id=?", (row["id"],)).fetchone()
        return {"challenge_id": row["id"], "session_id": row["id"], "seed": row["seed"],
                "week": row["week"], "issued_at": row["issued_at"], "week_end": row["week_end"],
                "submit_until": row["week_end"] + LATE_SECONDS, "rule_version": row["rule_version"],
                "supply_profile": row["supply_profile"],
                "accepted_actions": json.loads(accepted["actions_json"]) if accepted else []}

    def replay(self, challenge_id: str, seed: str, supply_profile: str, actions: list,
               rule_version: str = CURRENT_RULE_VERSION) -> dict:
        if not self.replay_slots.acquire(blocking=False):
            raise ApiError(503, "VERIFIER_BUSY", 1)
        try:
            return self._replay_with_slot(challenge_id, seed, supply_profile, actions, rule_version)
        finally:
            self.replay_slots.release()

    def _replay_with_slot(self, challenge_id: str, seed: str, supply_profile: str, actions: list,
                          rule_version: str) -> dict:
        verifier = self.verifiers.get(rule_version)
        if verifier is None:
            raise ApiError(503, "VERIFIER_UNAVAILABLE")
        engine, project = verifier
        if rule_version in self.frozen_versions and not verify_bundle(project, rule_version):
            raise ApiError(503, "VERIFIER_UNAVAILABLE")
        with tempfile.TemporaryDirectory(prefix="blocktower_replay_") as folder:
            source, output = Path(folder) / "input.json", Path(folder) / "output.json"
            source.write_text(canonical({"session_id": challenge_id, "seed": seed,
                                         "supply_profile": supply_profile, "actions": actions}), encoding="utf-8")
            try:
                run = subprocess.run(
                    [str(engine), "--headless", "--path", str(project),
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
        replay = self.replay(challenge_id, challenge["seed"], challenge["supply_profile"], actions,
                             challenge["rule_version"])
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
    limiter: RateLimiter
    trust_proxy_client_ip: bool

    def log_message(self, _format: str, *_args: object) -> None:
        # 기본 로그는 요청 줄 전체(쿼리 포함)를 기록하므로 사용하지 않는다.
        return

    def begin_request(self, path: str) -> None:
        self.started_at = time.monotonic()
        self.request_id = secrets.token_hex(8)
        self.route = path if path in {
            "/health/live", "/health/ready", "/v1/leaderboard/current", "/v1/me",
            "/v1/accounts/guest", "/v1/accounts/recovery-code", "/v1/accounts/recover",
            "/v1/challenges/current", "/v1/submissions"} else "other"

    def client_ip(self) -> str:
        if not self.trust_proxy_client_ip:
            return str(ipaddress.ip_address(self.client_address[0]))
        values = self.headers.get_all("X-Real-IP", [])
        if len(values) != 1 or "," in values[0]:
            raise ApiError(400, "INVALID_CLIENT_IP")
        try:
            return str(ipaddress.ip_address(values[0].strip()))
        except ValueError as error:
            raise ApiError(400, "INVALID_CLIENT_IP") from error

    def rate_limit(self, path: str) -> None:
        if path in ("/health/live", "/health/ready"):
            return
        group = "other"
        if path == "/v1/accounts/guest":
            group = "guest"
        elif path == "/v1/accounts/recover":
            group = "recover"
        elif path == "/v1/submissions":
            group = "submit"
        self.limiter.check(self.client_ip(), group)

    def reply(self, status: int, value: object, retry_after: int = 0) -> None:
        data = canonical(value).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("X-Request-ID", self.request_id)
        if retry_after > 0:
            self.send_header("Retry-After", str(retry_after))
        self.end_headers()
        try:
            self.wfile.write(data)
        finally:
            print(canonical({"event": "http_request", "request_id": self.request_id,
                             "method": self.command, "route": self.route, "status": status,
                             "duration_ms": round((time.monotonic() - self.started_at) * 1000)}), flush=True)

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
        path = urlsplit(self.path).path
        self.begin_request(path)
        try:
            self.rate_limit(path)
            if path == "/health/live":
                self.reply(200, {"ok": True})
            elif path == "/health/ready":
                try:
                    if not self.api.db_path.is_file():
                        raise OSError("database missing")
                    with connection(self.api.db_path) as db:
                        db.execute("SELECT 1 FROM accounts LIMIT 1").fetchone()
                    ready = all(engine.is_file() and (project / "project.godot").is_file()
                                and (version not in self.api.frozen_versions or verify_bundle(project, version))
                                for version, (engine, project) in self.api.verifiers.items())
                except (OSError, sqlite3.Error):
                    ready = False
                if not ready:
                    raise ApiError(503, "NOT_READY")
                self.reply(200, {"ok": True})
            elif path == "/v1/leaderboard/current":
                self.reply(200, self.api.leaderboard())
            elif path == "/v1/me":
                account = self.authenticated()
                self.reply(200, {"account_id": account["id"], "alias": account["alias"]})
            else:
                raise ApiError(404, "NOT_FOUND")
        except ApiError as error:
            self.reply(error.status, {"ok": False, "error": error.code}, error.retry_after)

    def do_POST(self) -> None:
        path = urlsplit(self.path).path
        self.begin_request(path)
        try:
            self.rate_limit(path)
            body = self.body()
            if path == "/v1/accounts/guest":
                if body != {}:
                    raise ApiError(400, "INVALID_REQUEST")
                self.reply(201, self.api.create_account())
            elif path == "/v1/accounts/recovery-code":
                if body != {}:
                    raise ApiError(400, "INVALID_REQUEST")
                self.reply(200, self.api.issue_recovery_code(self.authenticated()))
            elif path == "/v1/accounts/recover":
                self.reply(200, self.api.recover_account(body))
            elif path == "/v1/challenges/current":
                if body != {}:
                    raise ApiError(400, "INVALID_REQUEST")
                self.reply(200, self.api.challenge(self.authenticated()))
            elif path == "/v1/submissions":
                self.reply(200, self.api.submit(self.authenticated(), body))
            else:
                raise ApiError(404, "NOT_FOUND")
        except ApiError as error:
            self.reply(error.status, {"ok": False, "error": error.code}, error.retry_after)


def load_extra_verifiers(path: Path) -> dict[str, tuple[Path, Path]]:
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        raise ValueError("cannot read verifier registry") from error
    if not isinstance(raw, dict):
        raise ValueError("verifier registry must be an object")
    result = {}
    for version, value in raw.items():
        if (not isinstance(version, str) or not version.startswith("bt_rules_v")
                or not version[10:].isdecimal() or version == CURRENT_RULE_VERSION
                or not isinstance(value, dict) or set(value) != {"engine", "project"}
                or not all(isinstance(item, str) for item in value.values())):
            raise ValueError("invalid verifier registry entry")
        engine, project = Path(value["engine"]), Path(value["project"])
        if not engine.is_absolute():
            engine = path.parent / engine
        if not project.is_absolute():
            project = path.parent / project
        result[version] = (engine.resolve(), project.resolve())
        if not verify_bundle(result[version][1], version):
            raise ValueError(f"verifier bundle is missing or changed for {version}")
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, required=True)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--project", type=Path, default=DEFAULT_VERIFIER_PROJECT)
    parser.add_argument("--verifier-registry", type=Path,
                        help="JSON map of additional rule versions to pinned engine and project paths")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--trust-proxy-client-ip", action="store_true",
                        help="Trust exactly one X-Real-IP value supplied by a loopback TLS reverse proxy")
    args = parser.parse_args()
    if args.host not in ("127.0.0.1", "::1"):
        parser.error("Bind to loopback; use a TLS reverse proxy for external access")
    if not args.godot.is_file() or not (args.project / "project.godot").is_file():
        parser.error("Pinned Godot executable and project.godot are required")
    if not verify_bundle(args.project.resolve(), CURRENT_RULE_VERSION):
        parser.error("Frozen current-rule verifier is missing or changed")
    verifiers = {CURRENT_RULE_VERSION: (args.godot.resolve(), args.project.resolve())}
    if args.verifier_registry:
        try:
            verifiers.update(load_extra_verifiers(args.verifier_registry.resolve()))
        except ValueError as error:
            parser.error(str(error))
    try:
        api = Api(args.db.resolve(), args.godot.resolve(), args.project.resolve(), verifiers)
    except RuntimeError as error:
        parser.error(str(error))
    server = ThreadingHTTPServer((args.host, args.port), type("Phase4Handler", (Handler,),
        {"api": api, "limiter": RateLimiter(), "trust_proxy_client_ip": args.trust_proxy_client_ip}))
    print(f"Phase 4 local API on {args.host}:{args.port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()

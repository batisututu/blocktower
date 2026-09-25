"""Check migration and issued challenge profiles without exposing account tokens."""

from __future__ import annotations

import argparse
import json
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from services.phase4 import server


class Friday(datetime):
    @classmethod
    def now(cls, tz=None):
        return datetime(2026, 9, 25, 12, tzinfo=timezone.utc)


class NextMonday(datetime):
    @classmethod
    def now(cls, tz=None):
        return datetime(2026, 9, 28, 12, tzinfo=timezone.utc)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1] / "game"
    original_datetime = server.datetime
    try:
        with tempfile.TemporaryDirectory(prefix="blocktower_profiles_") as folder:
            db_path = Path(folder) / "legacy.sqlite3"
            with server.connection(db_path) as db:
                db.execute("""CREATE TABLE challenges (
                    id TEXT PRIMARY KEY, account_id TEXT NOT NULL REFERENCES accounts(id),
                    week TEXT NOT NULL, seed TEXT NOT NULL, issued_at INTEGER NOT NULL,
                    week_end INTEGER NOT NULL, UNIQUE(account_id, week))""")
            api = server.Api(db_path, args.godot, project)
            with server.connection(db_path) as db:
                columns = {row[1] for row in db.execute("PRAGMA table_info(challenges)")}
            if "supply_profile" not in columns:
                raise RuntimeError("legacy schema migration failed")
            result = []
            server.datetime = Friday
            created = api.create_account()
            account = api.account(created["token"])
            first_challenge_id = ""
            for clock, expected in [(Friday, "classic"), (NextMonday, "reduced_single")]:
                server.datetime = clock
                challenge = api.challenge(account)
                if challenge["supply_profile"] != expected:
                    raise RuntimeError(f"unexpected profile for {challenge['week']}")
                duplicate = api.challenge(account)
                if duplicate != challenge:
                    raise RuntimeError("challenge profile changed on retry")
                accepted = api.submit(account, {"challenge_id": challenge["challenge_id"], "actions": []})
                if accepted["floor_count"] != 0:
                    raise RuntimeError("pinned replay did not accept the issued challenge")
                if not first_challenge_id:
                    first_challenge_id = challenge["challenge_id"]
                result.append({"week": challenge["week"], "supply_profile": expected,
                               "issued_idempotent": True, "replay_accepted": True})
            try:
                api.submit(account, {"challenge_id": first_challenge_id, "actions": []})
                raise RuntimeError("prior-week challenge accepted after cutoff")
            except server.ApiError as error:
                if error.code != "CHALLENGE_CLOSED":
                    raise
    finally:
        server.datetime = original_datetime
    report = {"ok": True, "legacy_schema_migrated": True,
              "old_week_closed": True, "challenges": result}
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False))


if __name__ == "__main__":
    main()

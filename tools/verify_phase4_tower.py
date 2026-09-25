"""Create a server-verified representative tower for the Phase 4 viewing flow."""

from __future__ import annotations

import argparse
import json
import subprocess
import tempfile
from pathlib import Path

from verify_phase4_service import call


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", default="http://127.0.0.1:8765")
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--attempts", type=int, default=4)
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1] / "game"
    for index in range(args.attempts):
        status, account = call(args.base, "/v1/accounts/guest", {})
        if status != 201:
            raise RuntimeError("account creation failed")
        status, challenge = call(args.base, "/v1/challenges/current", {}, account["token"])
        if status != 200:
            raise RuntimeError("challenge issue failed")
        with tempfile.TemporaryDirectory(prefix="blocktower_tower_") as directory:
            source, target = Path(directory) / "input.json", Path(directory) / "trace.json"
            source.write_text(json.dumps({"session_id": challenge["session_id"], "seed": challenge["seed"],
                                          "supply_profile": challenge["supply_profile"]}), encoding="utf-8")
            run = subprocess.run(
                [str(args.godot), "--headless", "--path", str(project),
                 "--script", "res://tests/integration/phase4_generate_trace.gd", "--", str(source), str(target)],
                capture_output=True, text=True, timeout=240, check=False,
            )
            if run.returncode != 0 or not target.is_file():
                raise RuntimeError("Godot trace generator failed: " + (run.stderr or run.stdout)[-1200:])
            trace = json.loads(target.read_text(encoding="utf-8"))
        if trace["floors"] < 10:
            print(f"candidate {index + 1}: {trace['floors']} verified-rule floors, retrying")
            continue
        status, result = call(args.base, "/v1/submissions",
                              {"challenge_id": challenge["challenge_id"], "actions": trace["actions"]}, account["token"])
        if status != 200 or result.get("floor_count", 0) < 10:
            raise RuntimeError("server rejected representative trace: " + str(result.get("error", status)))
        status, leaderboard = call(args.base, "/v1/leaderboard/current")
        if status != 200 or not any(row["account_id"] == account["account_id"] and
                                    row["tower"]["representative_segment"] > 0 for row in leaderboard["entries"]):
            raise RuntimeError("representative tower absent from leaderboard")
        report = {"ok": True, "floors": result["floor_count"], "actions": len(trace["actions"]),
                  "week": challenge["week"], "account_id": account["account_id"],
                  "challenge_id": challenge["challenge_id"], "tower": result["tower"]}
        if args.output:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
        print(json.dumps(report, ensure_ascii=False))
        return
    raise RuntimeError("no issued seed reached a representative segment")


if __name__ == "__main__":
    main()

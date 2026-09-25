"""Exercise the local Phase 4 HTTP flow without printing bearer tokens."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen


def call(base: str, path: str, body: dict | None = None, token: str = "") -> tuple[int, dict]:
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token
    request = Request(
        base + path,
        data=json.dumps(body).encode("utf-8") if body is not None else None,
        headers=headers,
        method="POST" if body is not None else "GET",
    )
    try:
        response = urlopen(request, timeout=45)
    except HTTPError as error:
        response = error
    with response:
        return response.status, json.load(response)


def require(condition: bool, label: str) -> None:
    if not condition:
        raise RuntimeError(label)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", default="http://127.0.0.1:8765")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    checks: list[str] = []
    base = args.base.rstrip("/")

    status, account = call(base, "/v1/accounts/guest", {})
    require(status == 201 and len(account["token"]) == 64, "guest account")
    token = account["token"]
    checks.append("guest account created")
    status, me = call(base, "/v1/me", token=token)
    require(status == 200 and me["account_id"] == account["account_id"], "account identity")
    checks.append("account identity")
    status, unauthorized = call(base, "/v1/me", token="0" * 64)
    require(status == 401 and unauthorized["error"] == "UNAUTHORIZED", "invalid token rejected")
    checks.append("invalid token rejected")
    status, challenge = call(base, "/v1/challenges/current", {}, token)
    require(status == 200 and challenge["session_id"] == challenge["challenge_id"], "challenge issue")
    status, repeated = call(base, "/v1/challenges/current", {}, token)
    require(status == 200 and repeated == challenge, "challenge idempotence")
    checks.append("one challenge per account and week")
    status, other_account = call(base, "/v1/accounts/guest", {})
    require(status == 201, "second account")
    status, forbidden = call(base, "/v1/submissions",
                             {"challenge_id": challenge["challenge_id"], "actions": []}, other_account["token"])
    require(status == 404 and forbidden["error"] == "CHALLENGE_NOT_FOUND", "cross-account submission rejected")
    checks.append("cross-account submission rejected")

    challenge_id = challenge["challenge_id"]
    body = {"challenge_id": challenge_id, "actions": []}
    status, first = call(base, "/v1/submissions", body, token)
    require(status == 200 and first["floor_count"] == 0 and not first["duplicate"], "initial replay")
    status, invented = call(base, "/v1/submissions",
                            {"challenge_id": challenge_id, "actions": [], "floor_count": 99999}, token)
    require(status == 400 and invented["error"] == "INVALID_REQUEST", "client score rejected")
    checks.append("client-supplied score rejected")
    status, duplicate = call(base, "/v1/submissions", body, token)
    require(status == 200 and duplicate["duplicate"], "duplicate replay")
    checks.append("headless replay and idempotent retry")

    action = {"type": "SET_AUTO", "session_id": challenge_id, "event_id": "1", "enabled": True, "confirmed": True}
    body = {"challenge_id": challenge_id, "actions": [action]}
    status, extended = call(base, "/v1/submissions", body, token)
    require(status == 200 and not extended["duplicate"], "trace extension")
    checks.append("valid trace extension")
    status, accepted = call(base, "/v1/challenges/current", {}, token)
    require(status == 200 and accepted["accepted_actions"] == [action], "accepted trace available to account")
    checks.append("authenticated accepted trace for device restore")
    status, branch = call(base, "/v1/submissions", {"challenge_id": challenge_id, "actions": []}, token)
    require(status == 409 and branch["error"] == "TRACE_NOT_EXTENSION", "branch rejected")
    checks.append("shortened trace rejected")
    divergent = dict(action, enabled=False)
    status, conflict = call(base, "/v1/submissions",
                            {"challenge_id": challenge_id, "actions": [divergent]}, token)
    require(status == 409 and conflict["error"] == "TRACE_NOT_EXTENSION", "same-length device conflict rejected")
    checks.append("divergent device trace rejected")

    bad = dict(action, event_id="3")
    status, invalid = call(base, "/v1/submissions", {"challenge_id": challenge_id, "actions": [action, bad]}, token)
    require(status == 422 and invalid["error"] == "EVENT_OUT_OF_ORDER", "invalid event rejected")
    checks.append("invalid event rejected by reducer")
    status, still_duplicate = call(base, "/v1/submissions", body, token)
    require(status == 200 and still_duplicate["duplicate"], "invalid trace did not replace accepted history")
    checks.append("invalid trace leaves accepted history intact")
    status, leaderboard = call(base, "/v1/leaderboard/current")
    require(status == 200 and any(row["account_id"] == account["account_id"] for row in leaderboard["entries"]), "public leaderboard")
    checks.append("verified public leaderboard")

    status, invalid_code = call(base, "/v1/accounts/recover", {"recovery_code": "0000"})
    require(status == 401 and invalid_code["error"] == "RECOVERY_CODE_INVALID", "invalid recovery code")
    checks.append("invalid recovery code rejected")
    status, issued = call(base, "/v1/accounts/recovery-code", {}, token)
    require(status == 200 and len(issued["recovery_code"].replace("-", "")) == 32, "recovery code issue")
    status, restored = call(base, "/v1/accounts/recover", {"recovery_code": issued["recovery_code"]})
    require(status == 200 and restored["account_id"] == account["account_id"], "account recovered")
    status, revoked = call(base, "/v1/me", token=token)
    require(status == 401 and revoked["error"] == "UNAUTHORIZED", "old device token revoked")
    token = restored["token"]
    status, retried = call(base, "/v1/accounts/recover", {"recovery_code": issued["recovery_code"]})
    require(status == 200 and retried["account_id"] == account["account_id"] and retried["token"] != token,
            "lost response can retry recovery")
    status, revoked_again = call(base, "/v1/me", token=token)
    require(status == 401 and revoked_again["error"] == "UNAUTHORIZED", "prior recovery token revoked")
    token = retried["token"]
    status, resumed = call(base, "/v1/challenges/current", {}, token)
    require(status == 200 and resumed["challenge_id"] == challenge_id and resumed["accepted_actions"] == [action],
            "recovered challenge continues from accepted trace")
    checks.append("recovery rotates token and restores accepted trace")
    status, replaced = call(base, "/v1/accounts/recovery-code", {}, token)
    require(status == 200 and replaced["recovery_code"] != issued["recovery_code"], "recovery code rotation")
    status, invalid_old = call(base, "/v1/accounts/recover", {"recovery_code": issued["recovery_code"]})
    require(status == 401 and invalid_old["error"] == "RECOVERY_CODE_INVALID", "old recovery code revoked")
    checks.append("new recovery code revokes old code")

    report = {"ok": True, "checks": checks, "week": challenge["week"], "challenge_id": challenge_id,
              "account_id": account["account_id"], "entry_count": len(leaderboard["entries"])}
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False))


if __name__ == "__main__":
    main()

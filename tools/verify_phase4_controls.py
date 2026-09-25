"""격리된 로컬 서버에서 Phase 4 요청 제한과 로그를 확인한다."""

from __future__ import annotations

import argparse
import json
import socket
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from services.phase4.server import Api, ApiError


def request(base: str, path: str, body: dict | None = None,
            client_ip: str | None = None, token: str = "") -> tuple[int, dict, object]:
    headers = {"Content-Type": "application/json"}
    if client_ip is not None:
        headers["X-Real-IP"] = client_ip
    if token:
        headers["Authorization"] = "Bearer " + token
    call = Request(base + path, data=json.dumps(body).encode() if body is not None else None,
                   headers=headers, method="POST" if body is not None else "GET")
    try:
        response = urlopen(call, timeout=10)
    except HTTPError as error:
        response = error
    with response:
        return response.status, json.load(response), response.headers


def require(condition: bool, label: str) -> None:
    if not condition:
        raise RuntimeError(label)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    with socket.socket() as probe:
        probe.bind(("127.0.0.1", 0))
        port = probe.getsockname()[1]
    base = f"http://127.0.0.1:{port}"
    checked: list[str] = []
    request_ids: list[str] = []
    with tempfile.TemporaryDirectory(prefix="blocktower_controls_") as folder:
        private = Path(folder)
        db_path = private / "phase4.sqlite3"
        log_path = private / "server.jsonl"
        with log_path.open("w", encoding="utf-8") as log:
            server = subprocess.Popen(
                [sys.executable, str(root / "services/phase4/server.py"), "--db", str(db_path),
                 "--godot", str(args.godot), "--port", str(port), "--trust-proxy-client-ip"],
                cwd=root, stdout=log, stderr=subprocess.STDOUT,
            )
            try:
                for _ in range(50):
                    if server.poll() is not None:
                        raise RuntimeError("server exited before readiness")
                    try:
                        status, value, headers = request(base, "/health/ready")
                        if status == 200 and value == {"ok": True}:
                            request_ids.append(headers["X-Request-ID"])
                            break
                    except URLError:
                        time.sleep(0.1)
                else:
                    raise RuntimeError("readiness timeout")
                status, value, headers = request(base, "/health/live")
                require(status == 200 and value == {"ok": True}, "liveness")
                request_ids.append(headers["X-Request-ID"])
                checked.append("liveness and DB readiness")

                for invalid_ip in (None, "invalid", "203.0.113.1,203.0.113.2"):
                    status, value, headers = request(base, "/v1/leaderboard/current", client_ip=invalid_ip)
                    require(status == 400 and value["error"] == "INVALID_CLIENT_IP", "proxy header rejected")
                    request_ids.append(headers["X-Request-ID"])
                checked.append("missing and malformed proxy IP rejected")

                ip = "203.0.113.10"
                token = ""
                for _ in range(12):
                    status, value, headers = request(base, "/v1/accounts/guest", {}, client_ip=ip)
                    require(status == 201, "guest allowance")
                    token = value["token"]
                    request_ids.append(headers["X-Request-ID"])
                status, value, headers = request(base, "/v1/accounts/guest", {}, client_ip=ip)
                require(status == 429 and value["error"] == "RATE_LIMITED"
                        and 1 <= int(headers["Retry-After"]) <= 60, "guest rate limit")
                request_ids.append(headers["X-Request-ID"])
                checked.append("guest limit 12/min and Retry-After")

                other_ip = "203.0.113.11"
                status, value, headers = request(base, "/v1/accounts/guest", {}, client_ip=other_ip)
                require(status == 201, "separate client budget")
                request_ids.append(headers["X-Request-ID"])
                checked.append("independent client budgets")

                for _ in range(8):
                    status, value, headers = request(base, "/v1/accounts/recover",
                                                     {"recovery_code": "0000"}, client_ip=ip)
                    require(status == 401 and value["error"] == "RECOVERY_CODE_INVALID", "recovery allowance")
                    request_ids.append(headers["X-Request-ID"])
                status, value, headers = request(base, "/v1/accounts/recover",
                                                 {"recovery_code": "0000"}, client_ip=ip)
                require(status == 429 and value["error"] == "RATE_LIMITED", "recovery rate limit")
                request_ids.append(headers["X-Request-ID"])
                checked.append("recovery limit 8/min")

                for _ in range(12):
                    status, value, headers = request(base, "/v1/submissions", {}, client_ip=ip, token=token)
                    require(status == 400 and value["error"] == "INVALID_REQUEST", "submission allowance")
                    request_ids.append(headers["X-Request-ID"])
                status, value, headers = request(base, "/v1/submissions", {}, client_ip=ip, token=token)
                require(status == 429 and value["error"] == "RATE_LIMITED", "submission rate limit")
                request_ids.append(headers["X-Request-ID"])
                checked.append("submission limit 12/min before action processing")

                status, value, headers = request(base, "/v1/leaderboard/current?private=log_marker",
                                                 client_ip=ip)
                require(status == 200, "sanitized route")
                request_ids.append(headers["X-Request-ID"])
            finally:
                server.terminate()
                try:
                    server.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    server.kill()
                    server.wait(timeout=5)

        lines = log_path.read_text(encoding="utf-8").splitlines()
        events = [json.loads(line) for line in lines if line.startswith("{")]
        require(len(events) == len(request_ids), "one access event per handled response")
        require({event["request_id"] for event in events} == set(request_ids), "request ID correlation")
        require(all(set(event) == {"event", "request_id", "method", "route", "status", "duration_ms"}
                    for event in events), "sanitized log fields")
        raw_log = "\n".join(lines)
        require(token not in raw_log and ip not in raw_log and "log_marker" not in raw_log,
                "no credential, IP, or query in logs")
        checked.append("request ID and sanitized access events")

        api = Api(db_path, args.godot, root / "game")
        require(api.replay_slots.acquire(blocking=False), "replay slot one")
        require(api.replay_slots.acquire(blocking=False), "replay slot two")
        try:
            try:
                api.replay("unused", "1", "classic", [])
            except ApiError as error:
                require((error.status, error.code, error.retry_after) == (503, "VERIFIER_BUSY", 1),
                        "replay saturation response")
            else:
                raise RuntimeError("third replay unexpectedly accepted")
        finally:
            api.replay_slots.release()
            api.replay_slots.release()
        checked.append("two concurrent replay slots and busy response")
    report = {"ok": True, "checks": checked, "responses": len(request_ids)}
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False))


if __name__ == "__main__":
    main()

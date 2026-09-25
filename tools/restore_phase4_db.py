"""Validate a Phase 4 backup and restore it into a new, offline DB path."""

from __future__ import annotations

import argparse
import json
import os
import sqlite3
import tempfile
from contextlib import closing
from pathlib import Path

from backup_phase4_db import inspect, open_readonly


def restore(source: Path, output: Path) -> dict:
    source, output = source.resolve(), output.resolve()
    if not source.is_file() or source == output or output.exists():
        raise ValueError("source must be an existing backup and output must be a new path")
    source_rows = inspect(source)
    output.parent.mkdir(parents=True, exist_ok=True)
    handle, temporary = tempfile.mkstemp(prefix=".phase4_restore_", suffix=".sqlite3", dir=output.parent)
    os.close(handle)
    try:
        with closing(open_readonly(source)) as backup, closing(sqlite3.connect(temporary)) as restored:
            backup.backup(restored)
            restored.commit()
        rows = inspect(Path(temporary))
        if rows != source_rows:
            raise RuntimeError("backup changed during restore")
        # 새 경로에만 게시한다. 실행 중인 DB 파일은 교체하지 않는다.
        os.link(temporary, output)
        return {"ok": True, "output": str(output), "bytes": output.stat().st_size,
                "integrity": "ok", "rows": rows}
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True, help="existing Phase 4 backup")
    parser.add_argument("--output", type=Path, required=True, help="new, unused DB path")
    args = parser.parse_args()
    print(json.dumps(restore(args.source, args.output), ensure_ascii=False))


if __name__ == "__main__":
    main()

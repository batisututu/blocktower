"""Create and verify one consistent Phase 4 SQLite backup."""

from __future__ import annotations

import argparse
import json
import os
import sqlite3
import tempfile
from contextlib import closing
from pathlib import Path
from urllib.parse import quote

REQUIRED_TABLES = {"accounts", "challenges", "submissions"}


def open_readonly(path: Path) -> sqlite3.Connection:
    return sqlite3.connect("file:" + quote(path.as_posix(), safe="/:\\") + "?mode=ro", uri=True)


def backup(source: Path, output: Path) -> dict:
    source, output = source.resolve(), output.resolve()
    if not source.is_file() or source == output or output.exists():
        raise ValueError("source must be an existing DB and output must be a new path")
    output.parent.mkdir(parents=True, exist_ok=True)
    handle, temporary = tempfile.mkstemp(prefix=".phase4_backup_", suffix=".sqlite3", dir=output.parent)
    os.close(handle)
    try:
        with closing(open_readonly(source)) as live, closing(sqlite3.connect(temporary)) as copy:
            live.backup(copy)
            copy.commit()
        with closing(sqlite3.connect(temporary)) as copied:
            integrity = copied.execute("PRAGMA integrity_check").fetchone()[0]
            if integrity != "ok":
                raise RuntimeError("backup integrity check failed")
            names = {row[0] for row in copied.execute("SELECT name FROM sqlite_master WHERE type='table'")}
            if not REQUIRED_TABLES <= names:
                raise RuntimeError("backup is missing Phase 4 tables")
            if copied.execute("PRAGMA foreign_key_check").fetchone() is not None:
                raise RuntimeError("backup contains broken references")
            counts = {name: copied.execute(f"SELECT COUNT(*) FROM {name}").fetchone()[0]
                      for name in sorted(REQUIRED_TABLES)}
        if output.exists():
            raise FileExistsError("backup destination appeared during verification")
        os.rename(temporary, output)
        return {"ok": True, "output": str(output), "bytes": output.stat().st_size,
                "integrity": "ok", "rows": counts}
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(backup(args.source, args.output), ensure_ascii=False))


if __name__ == "__main__":
    main()

"""Copy the deterministic Phase 4 replay inputs into a new, immutable project."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import tempfile
from pathlib import Path

REPLAY_FILES = (
    "scripts/online/verify_replay.gd",
    "scripts/core/game_session.gd",
    "scripts/core/memory_save_repository.gd",
    "scripts/core/growth_rules.gd",
    "scripts/core/piece_supply.gd",
    "scripts/core/generation/piece_generator.gd",
    "scripts/core/generation/piece_generator_config.gd",
    "data/piece_generator_default.tres",
    "data/piece_generator_low_single.tres",
)


def freeze(source: Path, output: Path, rule_version: str) -> dict:
    source, output = source.resolve(), output.resolve()
    if not rule_version.startswith("bt_rules_v") or not rule_version[10:].isdecimal():
        raise ValueError("rule_version must be bt_rules_v plus a decimal number")
    if output.exists():
        raise FileExistsError("a frozen verifier cannot be overwritten")
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = Path(tempfile.mkdtemp(prefix=".phase4_verifier_", dir=output.parent))
    try:
        files = {}
        project = f'config_version=5\n\n[application]\n\nconfig/name="Blocktower {rule_version} verifier"\nconfig/features=PackedStringArray("4.7")\n'
        (temporary / "project.godot").write_bytes(project.encode("utf-8"))
        files["project.godot"] = hashlib.sha256((temporary / "project.godot").read_bytes()).hexdigest()
        for relative in REPLAY_FILES:
            original = source / relative
            if not original.is_file():
                raise FileNotFoundError(original)
            target = temporary / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(original.read_bytes().replace(b"\r\n", b"\n"))
            files[relative] = hashlib.sha256(target.read_bytes()).hexdigest()
            if original.suffix == ".gd" and original.with_suffix(".gd.uid").is_file():
                uid = original.with_suffix(".gd.uid")
                copied = target.with_suffix(".gd.uid")
                copied.write_bytes(uid.read_bytes().replace(b"\r\n", b"\n"))
                files[relative + ".uid"] = hashlib.sha256(copied.read_bytes()).hexdigest()
        manifest = {"rule_version": rule_version, "godot_version": "4.7.2", "files": files}
        (temporary / "manifest.json").write_bytes(
            (json.dumps(manifest, ensure_ascii=False, sort_keys=True, indent=2) + "\n").encode("utf-8"))
        os.rename(temporary, output)
        return {"rule_version": rule_version, "output": str(output), "files": len(files)}
    finally:
        if temporary.exists():
            shutil.rmtree(temporary)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=Path(__file__).resolve().parents[1] / "game")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--rule-version", required=True)
    args = parser.parse_args()
    print(json.dumps(freeze(args.source, args.output, args.rule_version), ensure_ascii=False))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Parse every YAML file under ansible/ and fail on syntax errors.

Why this exists: the required `ci` check only yamllint-ed .github/, backup/ and
monitoring/, and the ansible workflow only ran `--syntax-check` against
playbooks/*.yml. Nothing parsed ansible/roles/**, so a truncated molecule
verify.yml reached main with every required check green.

This gate is deliberately parse-only. ansible/ still carries pre-existing
yamllint style debt; folding style rules in here would let that debt mask the
one guarantee this script exists to provide — that the files are valid YAML.
"""
from __future__ import annotations

import sys
from pathlib import Path

try:
    import yaml
except ImportError:  # pragma: no cover - environment guard
    print("::error::PyYAML is required to run this check (python3 -m pip install pyyaml)")
    sys.exit(2)

ROOT = Path("ansible")
SKIP_DIRS = {".ansible", ".git", ".venv", "__pycache__", "molecule.cache"}
SUFFIXES = {".yml", ".yaml"}


def iter_yaml(root: Path):
    """Yield every non-vendored YAML file under root, deterministically."""
    for path in sorted(root.rglob("*")):
        if not path.is_file() or path.suffix not in SUFFIXES:
            continue
        if SKIP_DIRS.intersection(path.parts):
            continue
        yield path


def main() -> int:
    if not ROOT.is_dir():
        print(f"::error::{ROOT}/ not found — run this from the repository root")
        return 2

    broken: list[str] = []
    checked = 0
    for path in iter_yaml(ROOT):
        checked += 1
        try:
            # safe_load_all is lazy; consume it so late parse errors surface.
            list(yaml.safe_load_all(path.read_text(encoding="utf-8")))
        except (yaml.YAMLError, UnicodeDecodeError, OSError) as exc:
            # OSError covers unreadable files and filesystem errors: report and
            # keep going so one bad path never hides the rest of the tree.
            first = str(exc).splitlines()[0] if str(exc) else exc.__class__.__name__
            broken.append(f"{path}: {first}")

    for entry in broken:
        print(entry)

    if broken:
        print(f"::error::{len(broken)} of {checked} YAML files under {ROOT}/ cannot be parsed")
        return 1

    print(f"OK: {checked} YAML files under {ROOT}/ parsed")
    return 0


if __name__ == "__main__":
    sys.exit(main())

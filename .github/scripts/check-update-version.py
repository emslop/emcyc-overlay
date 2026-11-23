#!/usr/bin/env python3
"""Compare the restricted release formats used by the overlay update checkers."""
import argparse
from pathlib import Path
import re


def parse(value, prereleases=False, revision=False):
    match = re.fullmatch(
        r"([0-9]+(?:\.[0-9]+)*)(?:_(alpha|beta|rc)([0-9]+))?(?:-r([0-9]+))?",
        value,
    )
    if not match:
        raise ValueError(f"Unsupported version: {value!r}")
    base, suffix, number, rev = match.groups()
    if suffix and not prereleases:
        raise ValueError(f"Unexpected prerelease: {value!r}")
    if rev is not None and not revision:
        raise ValueError(f"Release must not contain an ebuild revision: {value!r}")
    parts = base.split(".")
    if any(len(part) > 1 and part.startswith("0") for part in parts):
        raise ValueError(f"Leading-zero components require manual review: {value!r}")
    parts = [int(part) for part in parts]
    if parts[0] == 9999:
        raise ValueError("Live versions are not release candidates")
    while parts and parts[-1] == 0:
        parts.pop()
    rank = {"alpha": -3, "beta": -2, "rc": -1, None: 0}[suffix]
    return (tuple(parts), rank, int(number or 0)), int(rev or 0)


def check(directory, package, latest, prereleases=False):
    latest_key, _ = parse(latest, prereleases)
    candidates = []
    for path in sorted(directory.glob(f"{package}-*.ebuild")):
        value = path.name[len(package) + 1:-len(".ebuild")]
        if re.fullmatch(r"9999(?:-r[0-9]+)?", value):
            continue
        if not path.is_file():
            raise ValueError(f"Not a regular ebuild: {path}")
        key, revision = parse(value, prereleases, revision=True)
        candidates.append((key, revision, path))
    if not candidates:
        raise ValueError(f"No versioned ebuild found in {directory}")
    current_key, _, path = max(candidates)
    current = path.name[len(package) + 1:-len(".ebuild")]
    return path, re.sub(r"-r[0-9]+$", "", current), latest_key > current_key


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("package")
    parser.add_argument("latest")
    parser.add_argument("--prereleases", action="store_true")
    args = parser.parse_args()
    try:
        path, current, newer = check(args.directory, args.package, args.latest, args.prereleases)
    except ValueError as error:
        parser.exit(1, f"{error}\n")
    print(f"file={path}")
    print(f"version={current}")
    print(f"newer={str(newer).lower()}")


if __name__ == "__main__":
    main()

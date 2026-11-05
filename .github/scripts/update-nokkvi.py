#!/usr/bin/env python3
"""Refresh nokkvi's locked dependency blocks without building or touching Manifests."""
import argparse
import io
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import tarfile
import tomllib
from urllib.parse import urlsplit
from urllib.request import Request, urlopen

NAME = r"[A-Za-z0-9_-]+"
VERSION = r"[0-9]+\.[0-9]+\.[0-9]+(?:[-+][A-Za-z0-9.+-]+)?"
REGISTRY = "registry+https://github.com/rust-lang/crates.io-index"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def archive(repo, commit):
    request = Request(f"https://codeload.github.com/{repo}/tar.gz/{commit}",
                      headers={"User-Agent": "emcyc-overlay-nokkvi-updater"})
    with urlopen(request, timeout=120) as response:
        data = response.read()
    manifests = {}
    lock = None
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as tar:
        files = [m for m in tar.getmembers() if m.isfile()]
        roots = {PurePosixPath(m.name).parts[0] for m in files}
        require(len(roots) == 1, f"Unexpected archive layout: {repo}")
        root = roots.pop()
        require(root == f"{repo.split('/')[-1]}-{commit}",
                f"Unexpected archive root: {root}")
        for member in files:
            path = PurePosixPath(member.name)
            require(".." not in path.parts and not path.is_absolute(), "Unsafe archive path")
            relative = str(path.relative_to(root))
            if path.name == "Cargo.toml" or relative == "Cargo.lock":
                with tar.extractfile(member) as handle:
                    parsed = tomllib.loads(handle.read().decode("utf-8"))
                if relative == "Cargo.lock":
                    lock = parsed
                else:
                    manifests[relative] = parsed
    require("Cargo.toml" in manifests, f"Missing root manifest: {repo}")
    return manifests, lock


def package_version(manifests, path, package):
    version = package.get("version")
    if version == {"workspace": True}:
        for parent in PurePosixPath(path).parents:
            workspace = manifests.get(str(parent / "Cargo.toml"), {}).get("workspace", {})
            if "version" in workspace.get("package", {}):
                return workspace["package"]["version"]
        raise ValueError(f"Cannot resolve workspace version: {path}")
    return version


def package_path(manifests, name, version):
    matches = []
    for path, manifest in manifests.items():
        package = manifest.get("package", {})
        if package.get("name") == name and package_version(manifests, path, package) == version:
            matches.append(str(PurePosixPath(path).parent))
    require(len(matches) == 1, f"Expected one source directory for {name}@{version}: {matches}")
    return matches[0]


def blocks(manifests, lock):
    require(lock and lock.get("version") in (3, 4), "Unsupported or missing Cargo.lock")
    crates = set()
    git = {}
    cache = {}
    for package in lock["package"]:
        name, version = package["name"], package["version"]
        require(re.fullmatch(NAME, name) and re.fullmatch(VERSION, version),
                f"Unsafe package identifier: {name}@{version}")
        source = package.get("source")
        if source is None:
            package_path(manifests, name, version)
        elif source == REGISTRY:
            require(re.fullmatch(r"[0-9a-f]{64}", package.get("checksum", "")),
                    f"Missing registry checksum: {name}")
            crates.add((name, version))
        elif source.startswith("git+"):
            url = urlsplit(source[4:])
            require(url.scheme == "https" and url.netloc == "github.com",
                    f"Unsupported Git host: {source}")
            repo = url.path.removeprefix("/").removesuffix(".git")
            require(re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repo),
                    f"Unsupported Git repository: {source}")
            commit = url.fragment
            require(re.fullmatch(r"[0-9a-f]{40}", commit), f"Unpinned Git source: {source}")
            require(name not in git, f"Multiple Git packages named {name}; manual review required")
            key = (repo, commit)
            if key not in cache:
                cache[key] = archive(repo, commit)[0]
            path = package_path(cache[key], name, version)
            directory = f"{repo.split('/')[-1]}-%commit%"
            if path != ".":
                directory += f"/{path}"
            require(re.fullmatch(r"[A-Za-z0-9_./%+-]+", directory), "Unsafe Git crate directory")
            git[name] = f"https://github.com/{repo};{commit};{directory}"
        else:
            raise ValueError(f"Unsupported Cargo source: {source}")
    require(crates, "No registry dependencies found")
    registry_block = 'CRATES="\n' + ''.join(f' {n}@{v}\n' for n, v in sorted(crates)) + '"'
    git_block = 'declare -A GIT_CRATES=(\n' + ''.join(
        f' [{name}]="{value}"\n' for name, value in sorted(git.items())) + ')'
    return registry_block, git_block


def replace_once(text, pattern, replacement):
    text, count = re.subn(pattern, lambda match: replacement, text, flags=re.MULTILINE)
    require(count == 1, f"Expected exactly one ebuild block: {pattern}")
    return text


def render(text, manifests, lock, version):
    require(manifests["Cargo.toml"].get("package", {}).get("name") == "nokkvi",
            "Release is not nokkvi")
    require(package_version(manifests, "Cargo.toml", manifests["Cargo.toml"]["package"]) == version,
            "Release version does not match Cargo.toml")
    registry_block, git_block = blocks(manifests, lock)
    text = replace_once(text, r'^CRATES="[^"\n]*\n[^\"]*"', registry_block)
    text = replace_once(text, r'^declare -A GIT_CRATES=\(\n[\s\S]*?^\)', git_block)
    require('https://github.com/f-o-o-g-s/nokkvi/archive/refs/tags/v${PV}.tar.gz' in text,
            "Expected PV-based release SRC_URI")
    require(not re.search(r'^COMMIT=|^S=', text, re.MULTILINE), "Unexpected source override")
    package = manifests["Cargo.toml"]["package"]
    rust = package.get("rust-version")
    if rust == {"workspace": True}:
        rust = manifests["Cargo.toml"]["workspace"]["package"]["rust-version"]
    require(isinstance(rust, str) and re.fullmatch(r"[0-9]+\.[0-9]+(?:\.[0-9]+)?", rust),
            "Missing or unsupported Rust minimum version")
    return replace_once(text, r'^RUST_MIN_VER="[^"\n]+"', f'RUST_MIN_VER="{rust}"')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True)
    parser.add_argument("--commit", required=True)
    args = parser.parse_args()
    require(re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", args.version), "Unsupported release version")
    require(re.fullmatch(r"[0-9a-f]{40}", args.commit), "Invalid release commit")
    directory = Path("media-sound/nokkvi")
    candidates = []
    for path in directory.glob("nokkvi-*.ebuild"):
        match = re.fullmatch(r"nokkvi-([0-9]+)\.([0-9]+)\.([0-9]+)(?:-r([0-9]+))?\.ebuild", path.name)
        require(match is not None, f"Unsupported ebuild filename: {path}")
        candidates.append((tuple(int(n or 0) for n in match.groups()), path))
    require(candidates, "No existing ebuild")
    current, template = max(candidates)
    target = tuple(map(int, args.version.split(".")))
    updated = False
    if target > current[:3]:
        destination = directory / f"nokkvi-{args.version}.ebuild"
        require(not destination.exists(), f"Destination exists: {destination}")
        manifests, lock = archive("f-o-o-g-s/nokkvi", args.commit)
        content = render(template.read_text(), manifests, lock, args.version)
        subprocess.run(["bash", "-n"], input=content, text=True, check=True)
        with destination.open("x") as handle:
            handle.write(content)
        updated = True
    else:
        print(f"No newer release: {args.version}")
    if os.environ.get("GITHUB_OUTPUT"):
        with open(os.environ["GITHUB_OUTPUT"], "a") as handle:
            handle.write(f"updated={str(updated).lower()}\n")


if __name__ == "__main__":
    main()

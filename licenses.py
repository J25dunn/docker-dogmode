#!/usr/bin/env python3
"""Collect the licenses a DOG Mode image carries, into one directory the image ships.

    python3 licenses.py <depends-sources-dir> <COPYING> <out-dir> <repository> <commit>

<COPYING> is the license at the top of the client's source tree; the libraries bundled in that tree are found under
the src/ directory beside it. Writes, under <out-dir>:
  COPYING                        Bitcoin Core's license, which covers the client
  licenses/source-tree/src/...   the LICENSE, LICENCE, COPYING and NOTICE files of the libraries bundled in the client's
                                 source tree (leveldb, crc32c, secp256k1, minisketch, ctaes, libmultiprocess), by path
  licenses/depends/<archive>/    the same files at the top of each archive the depends step built from, or
                                 NO-LICENSE-FILE saying there is none
  SOURCES                        "sha256  archive" for every one of those archives
  BUILD                          the repository and commit the client was built from, and who packaged it

Every regular file in <depends-sources-dir> named *.tar or *.tar.* is read, compressed or not; any other file is named
in the output as not read, and depends' bookkeeping (the download-stamps directory) is not a file and is never
touched. The first version of this step, a shell loop, failed on that directory (2026-09-14); the second read only
*.tar.* and nothing in the source tree, so it would have shipped without depends' plain src-ipc-libmultiprocess.tar
and without the bundled libraries' notices, which BSD-3-Clause requires in a binary distribution (found against the
real sources before it shipped, 2026-09-15). Members are read, never extracted, and written by file name only, so a
path inside an archive cannot write outside <out-dir>. Exits non-zero if COPYING is empty, there is no archive, the
source tree holds no license file, or an archive holds two top-level license files with one name, so a broken step
fails the build instead of shipping an image without its licenses.
"""
import hashlib
import re
import sys
import tarfile
from pathlib import Path

NAMES = ("LICENSE", "LICENCE", "COPYING", "NOTICE")
ARCHIVE = re.compile(r"\.tar(\.[A-Za-z0-9]+)?$")


def is_license(file_name):
    return file_name.upper().startswith(NAMES)


def top_level_licenses(members):
    """The license files at an archive's top level: inside its one top directory when it has one (a release tarball),
    at its root when it has none (depends' own tarball of a directory, whose members start with ./)."""
    paths = [(m, [p for p in m.name.split("/") if p not in ("", ".")]) for m in members]
    firsts = {parts[0] for _, parts in paths if parts}
    depth = 2 if len(firsts) == 1 and any(len(parts) > 1 for _, parts in paths) else 1
    return [m for m, parts in paths if m.isfile() and len(parts) == depth and is_license(parts[-1])]


def main(sources, copying, out, repository, commit):
    sources, copying, out = Path(sources), Path(copying), Path(out)
    root = copying.resolve().parent
    copying_bytes = copying.read_bytes()
    if not copying_bytes:
        sys.exit("COPYING is empty")
    files = sorted(p for p in sources.iterdir() if p.is_file())
    archives = [p for p in files if ARCHIVE.search(p.name)]
    if not archives:
        sys.exit(f"no source archives in {sources}")
    tree = sorted(p for p in (root / "src").rglob("*") if p.is_file() and not p.is_symlink() and is_license(p.name))
    if not tree:
        sys.exit(f"no license files under {root / 'src'}")

    out.mkdir(parents=True, exist_ok=True)
    (out / "COPYING").write_bytes(copying_bytes)
    for p in tree:
        target = out / "licenses" / "source-tree" / p.relative_to(root)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(p.read_bytes())
        print(f"source tree: {p.relative_to(root)}")
    for p in files:
        if p not in archives:
            print(f"not an archive, not read: {p.name}")
    with open(out / "SOURCES", "w", encoding="utf-8") as fh:
        for a in archives:
            fh.write(f"{hashlib.sha256(a.read_bytes()).hexdigest()}  {a.name}\n")
    for a in archives:
        package = ARCHIVE.sub("", a.name)
        target = out / "licenses" / "depends" / package
        target.mkdir(parents=True, exist_ok=True)
        written = set()
        with tarfile.open(a) as t:
            for m in top_level_licenses(t.getmembers()):
                name = m.name.rstrip("/").split("/")[-1]
                if name in written:
                    sys.exit(f"{a.name} holds two top-level license files named {name}")
                (target / name).write_bytes(t.extractfile(m).read())
                written.add(name)
        if not written:
            (target / "NO-LICENSE-FILE").write_text(
                f"{a.name} ships no LICENSE, COPYING or NOTICE file at its top level. Its terms are in its own sources; "
                "the archive and its SHA-256 are listed in ../../../SOURCES.\n", encoding="utf-8")
        print(f"depends {package}: {len(written)} license file(s)")
    (out / "BUILD").write_text(
        f"DOG Mode bitcoind built from {repository} at commit {commit}\n"
        "Packaged by the Dog of Bitcoin Foundation (contact@dogofbitcoin.org). Not an official DOG Mode release.\n",
        encoding="utf-8")
    for p in sorted(out.rglob("*")):
        if p.is_file():
            print(p.relative_to(out))


if __name__ == "__main__":
    if len(sys.argv) != 6:
        sys.exit(__doc__)
    main(*sys.argv[1:])

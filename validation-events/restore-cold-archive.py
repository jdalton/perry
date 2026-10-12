#!/usr/bin/env python3
"""Safely restore one losslessly cold-stored Cargo archive from its JSON manifest."""
import hashlib
import json
import os
import subprocess
import sys

if len(sys.argv) != 2:
    raise SystemExit(f"usage: {sys.argv[0]} MANIFEST.json")
with open(sys.argv[1], encoding="utf-8") as f:
    m = json.load(f)
src = m["compressed_path"]
dst = m["original_path"]
expected = m["original_sha256"]
compressed_expected = m["compressed_sha256"]

def sha(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()

if sha(src) != compressed_expected:
    raise SystemExit("compressed archive hash mismatch; refusing restore")
if os.path.exists(dst):
    if sha(dst) == expected:
        print("original already exists with expected hash; no changes made")
        raise SystemExit(0)
    raise SystemExit("destination exists with a different hash; refusing overwrite")
tmp = f"{dst}.restore.tmp.{os.getpid()}"
if os.path.exists(tmp):
    raise SystemExit(f"temporary destination already exists: {tmp}")
try:
    with open(tmp, "xb") as out:
        p = subprocess.run(["zstd", "-q", "-d", "-c", src], stdout=out)
        if p.returncode:
            raise SystemExit(f"zstd decompression failed: {p.returncode}")
        out.flush()
        os.fsync(out.fileno())
    if os.path.getsize(tmp) != m["original_size_bytes"] or sha(tmp) != expected:
        raise SystemExit("restored bytes do not match manifest; refusing rename")
    os.chmod(tmp, m["original_mode"])
    os.chown(tmp, m["original_uid"], m["original_gid"])
    os.utime(tmp, ns=(m["original_mtime_ns"], m["original_mtime_ns"]))
    os.link(tmp, dst)  # atomic create-if-absent; never overwrite a racing destination
    os.unlink(tmp)
    dfd = os.open(os.path.dirname(dst), os.O_RDONLY)
    try:
        os.fsync(dfd)
    finally:
        os.close(dfd)
    print(f"restored and verified {dst}")
except BaseException:
    try:
        os.unlink(tmp)
    except FileNotFoundError:
        pass
    raise

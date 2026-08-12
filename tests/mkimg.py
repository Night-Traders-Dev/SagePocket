#!/usr/bin/env python3
"""mkimg.py - build a FAT32 SD card image for host tests.

Creates an image with mkfs.fat semantics (the caller runs mkfs.fat first)
and injects files/directories into the root directory by writing the FAT
tables and cluster data directly. This mirrors what a real card looks like
after files have been copied onto it.

Usage:
  mkimg.py <image> add <name8_3> <infile|->           # add file (stdin: -)
  mkimg.py <image> mkdir <name8_3>                    # add directory
"""

import struct
import sys

EOC = 0x0FFFFFFF


def u16(b, o):
    return struct.unpack_from("<H", b, o)[0]


def u32(b, o):
    return struct.unpack_from("<I", b, o)[0]


def put_u32(b, o, v):
    struct.pack_into("<I", b, o, v)


def read_sector(img, lba):
    img.seek(lba * 512)
    return bytearray(img.read(512))


def write_sector(img, lba, data):
    img.seek(lba * 512)
    img.write(bytes(data))


def load_bpb(img):
    s0 = read_sector(img, 0)
    spc = s0[13]
    resv = u16(s0, 14)
    nfats = s0[16]
    fatsz = u32(s0, 36)
    rootcl = u32(s0, 44)
    return spc, resv, nfats, fatsz, rootcl


def next_cluster(img, fatlba, c):
    off = c * 4
    s = read_sector(img, fatlba + off // 512)
    return u32(s, off % 512) & 0x0FFFFFFF


def set_cluster(img, fatlba, nfats, fatsz, c, value):
    off = c * 4
    rel = off // 512
    for f in range(nfats):
        s = read_sector(img, fatlba + f * fatsz + rel)
        keep = u32(s, off % 512) & 0xF0000000
        put_u32(s, off % 512, keep | (value & 0x0FFFFFFF))
        write_sector(img, fatlba + f * fatsz + rel, s)


def find_free(img, fatlba, max_cluster, start=2):
    c = start
    while c < max_cluster:
        if next_cluster(img, fatlba, c) == 0:
            return c
        c += 1
    return 0


def add_entry(img, name, first_cluster, size, attr):
    _, resv, nfats, fatsz, rootcl = load_bpb(img)
    spc = load_bpb(img)[0]
    datalba = resv + nfats * fatsz
    lba = datalba + (rootcl - 2) * spc
    base, dot, ext = name.partition(".")
    e = bytearray(32)
    nb = (base.upper() + " " * 8)[:8].encode("ascii")
    ne = (ext.upper() + " " * 3)[:3].encode("ascii")
    e[0:8] = nb
    e[8:11] = ne
    e[11] = attr
    struct.pack_into("<H", e, 26, first_cluster & 0xFFFF)
    struct.pack_into("<H", e, 20, (first_cluster >> 16) & 0xFFFF)
    struct.pack_into("<I", e, 28, size)
    for si in range(spc):
        sec = read_sector(img, lba + si)
        off = 0
        while off <= 480:
            if sec[off] == 0x00 or sec[off] == 0xE5:
                sec[off:off + 32] = e
                write_sector(img, lba + si, sec)
                return True
            off += 32
    return False


def add_file(img, name, content):
    spc, resv, nfats, fatsz, _ = load_bpb(img)
    fatlba = resv
    datalba = resv + nfats * fatsz
    max_c = 2 + 64 * 1024 * 1024 // (spc * 512)
    first = 0
    prev = 0
    off = 0
    while off < len(content):
        c = find_free(img, fatlba, max_c)
        if c == 0:
            sys.stderr.write("no free clusters\n")
            sys.exit(1)
        if first == 0:
            first = c
        if prev != 0:
            set_cluster(img, fatlba, nfats, fatsz, prev, c)
        chunk = content[off:off + spc * 512]
        for si in range(spc):
            sec = bytearray(512)
            part = chunk[si * 512:(si + 1) * 512]
            sec[:len(part)] = part
            write_sector(img, datalba + (c - 2) * spc + si, sec)
        prev = c
        off += spc * 512
    if prev != 0:
        set_cluster(img, fatlba, nfats, fatsz, prev, EOC)
    return add_entry(img, name, first if first else 0, len(content), 0x20)


def mkdir(img, name):
    spc, resv, nfats, fatsz, _ = load_bpb(img)
    c = find_free(img, resv, 2 + 64 * 1024 * 1024 // (spc * 512))
    if c == 0:
        sys.exit(1)
    set_cluster(img, resv, nfats, fatsz, c, EOC)
    datalba = resv + nfats * fatsz
    for si in range(spc):
        write_sector(img, datalba + (c - 2) * spc + si, bytearray(512))
    return add_entry(img, name, c, 0, 0x10)


def main():
    img_path, cmd = sys.argv[1], sys.argv[2]
    with open(img_path, "r+b") as img:
        if cmd == "add":
            name = sys.argv[3]
            if sys.argv[4] == "-":
                content = sys.stdin.buffer.read()
            else:
                content = open(sys.argv[4], "rb").read()
            ok = add_file(img, name, content)
        elif cmd == "mkdir":
            ok = mkdir(img, sys.argv[3])
        else:
            sys.exit(2)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
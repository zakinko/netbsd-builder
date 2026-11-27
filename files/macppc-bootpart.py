#!/usr/bin/env python3
"""Add a boot partition to an installed NetBSD/macppc disk.

QEMU's mac99 firmware (OpenBIOS) cannot read the FFS root sysinst writes,
so the disk cannot boot by itself. OpenBIOS does read ISO9660 from a
partition named in the Apple partition map, and loads an ELF kernel from
it directly. This appends an ISO9660 image holding the kernel to the end
of the raw disk and adds a third map entry for it, so that

    -prom-env 'boot-device=hd:3,\\NETBSD.'

boots the installed system. The kernel then sees a disk bootpath and
finds root on wd0a itself, with no root device prompt.

sysinst writes a map with two entries (the map itself and the NetBSD
partition, which reaches 2^31 sectors), followed by free sectors up to
the FFS boot area, so entry 3 fits in sector 3.

usage: macppc-bootpart.py <raw disk> <iso>
"""
import struct
import sys

PM_SIG = 0x504d          # "PM", partition map entry
DD_SIG = 0x4552          # "ER", driver descriptor (sector 0)

raw, iso = sys.argv[1:3]
img = open(iso, "rb").read()
img += b"\0" * (-len(img) % 512)
nblk = len(img) // 512

with open(raw, "r+b") as f:
    f.seek(0, 2)
    end = f.tell()
    if end % 512:
        sys.exit("disk size is not a multiple of 512")
    start = end // 512
    f.seek(0)
    head = bytearray(f.read(512 * 4))
    if struct.unpack_from(">H", head, 0)[0] != DD_SIG:
        sys.exit("no driver descriptor in sector 0")
    for i in (1, 2):
        if struct.unpack_from(">H", head, 512 * i)[0] != PM_SIG:
            sys.exit("partition map entry %d missing" % i)
        if struct.unpack_from(">I", head, 512 * i + 4)[0] != 2:
            sys.exit("expected a two-entry map from sysinst")
    if any(head[512 * 3:]):
        sys.exit("sector 3 is not free")

    for i in (1, 2):
        struct.pack_into(">I", head, 512 * i + 4, 3)       # pmMapBlkCnt
    e = bytearray(512)
    struct.pack_into(">HHIII", e, 0, PM_SIG, 0, 3, start, nblk)
    e[16:20] = b"boot"                                     # pmPartName
    e[48:57] = b"Apple_HFS"                                # pmParType
    struct.pack_into(">II", e, 80, 0, nblk)                # pmLgDataStart/Cnt
    struct.pack_into(">I", e, 88, 0x33)                    # pmPartStatus
    head[512 * 3:] = e

    f.seek(end)
    f.write(img)
    f.seek(0)
    f.write(head)
print("boot partition: sectors %d-%d" % (start, start + nblk - 1))

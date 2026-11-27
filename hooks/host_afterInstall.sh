#!/bin/bash
# NetBSD/macppc: give the installed disk a partition OpenBIOS can boot.
#
# OpenBIOS cannot read FFS, so after sysinst the disk would only boot
# with the install CD attached and the kernel asking for its root. Put
# the release's GENERIC kernel (the one sysinst just installed as
# /netbsd) on a small ISO9660 partition at the end of the disk; build.py
# boots it with boot-device=hd:3,\NETBSD. and the kernel finds wd0a
# itself. See files/macppc-bootpart.py.
set -euo pipefail

[ "${VM_ARCH:-}" = "powerpc" ] || exit 0

QCOW="${VM_WORK_QCOW:-${VM_OS_NAME}.qcow2}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

command -v genisoimage >/dev/null ||
  sudo apt-get install -y -q --no-install-recommends genisoimage

mkdir "$WORK/iso"
curl -fsSL -o "$WORK/netbsd.gz" "$VM_KERNEL_LINK"
gunzip -c "$WORK/netbsd.gz" > "$WORK/iso/netbsd"
genisoimage -quiet -r -J -l -N -V NBOOT -o "$WORK/boot.iso" "$WORK/iso"

qemu-img convert -O raw "$QCOW" "$WORK/disk.raw"
python3 "$(dirname "$0")/../files/macppc-bootpart.py" "$WORK/disk.raw" "$WORK/boot.iso"
qemu-img convert -O qcow2 "$WORK/disk.raw" "$QCOW"
qemu-img info "$QCOW" | sed 's/^/    /'

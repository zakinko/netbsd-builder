#!/bin/bash
# Fetch the 32-bit PowerPC OpenBIOS that NetBSD/macppc builds and boots on.
#
# The OpenBIOS bundled with QEMU before 11.1 cannot match the boot disk to
# the bootpath it hands the kernel, so an installed NetBSD/macppc finds no
# root ("boot device: memory0") on the runners' QEMU 10.2. The one in QEMU
# 11.1 (OpenBIOS e5ac46d) can. This takes that file from the QEMU v11.1.0
# tree, unmodified (pc-bios/openbios-ppc, GPL v2; the source is the
# roms/openbios submodule of the same tag), checks it against a pinned
# SHA256 and stages it. hooks/host_beforeBuild.sh puts it where the conf's
# VM_BIOS points for the build; the release-files job publishes it beside
# the images, and anyvm.py boots them with it (profile.json "bios_asset").
set -e

outdir="${1:-build}"
mkdir -p "$outdir"
url="https://gitlab.com/qemu-project/qemu/-/raw/v11.1.0/pc-bios/openbios-ppc"
want=032884eab588cd8d45903ed7be718f7a23fecaa4fc45c2dbf18c1220f13218ef

curl -fsSL -o "$outdir/openbios-ppc.tmp" "$url"
got=$(sha256sum "$outdir/openbios-ppc.tmp" | awk '{print $1}')
if [ "$want" != "$got" ]; then
  echo "fetch-openbios-ppc: SHA256 mismatch (want=$want got=$got)"
  exit 1
fi
mv "$outdir/openbios-ppc.tmp" "$outdir/openbios-ppc"
ls -l "$outdir/openbios-ppc"

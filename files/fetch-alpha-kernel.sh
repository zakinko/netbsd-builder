#!/bin/bash
# Fetch the official NetBSD/alpha GENERIC kernel(s) and stage them as release
# assets, one per alpha conf.
#
# QEMU's clipper machine has no SRM console, so an alpha image cannot boot
# from its own disk: build.py and anyvm.py both load the kernel directly
# (-kernel, root=/dev/wd0a). anyvm.py downloads it from THIS builder's
# release at the image's pinned version (profile.json "kernel_asset"),
# like the MICROVM kernel (files/fetch-microvm-kernel.sh).
#
# The kernel is NetBSD's own release build (binary/kernel/netbsd-GENERIC.gz),
# the same file the conf's VM_KERNEL_LINK names, verified against the
# release SHA512 file and shipped gunzipped.
set -e

outdir="${1:-build}"
mkdir -p "$outdir"

n=0
for tag in $(grep -oE '"[^"]+-alpha"' conf/all.release.conf | tr -d '"'); do
  conf="conf/netbsd-$tag.conf"
  if [ ! -f "$conf" ]; then
    echo "fetch-alpha-kernel: $tag is in conf/all.release.conf but $conf is missing"
    exit 1
  fi
  link=$(. "$conf"; printf '%s' "$VM_KERNEL_LINK")
  asset="netbsd-$tag-kernel"
  echo "fetch-alpha-kernel: $link -> $outdir/$asset"
  curl -fSL -o "$outdir/kernel.gz.tmp" "$link"
  curl -fSL -o "$outdir/SHA512.tmp" "$(dirname "$link")/SHA512"
  want=$(grep "($(basename "$link"))" "$outdir/SHA512.tmp" | awk '{print $NF}')
  got=$(sha512sum "$outdir/kernel.gz.tmp" | awk '{print $1}')
  if [ -z "$want" ] || [ "$want" != "$got" ]; then
    echo "fetch-alpha-kernel: SHA512 mismatch for $asset (want=$want got=$got)"
    exit 1
  fi
  gunzip -c "$outdir/kernel.gz.tmp" > "$outdir/$asset"
  rm -f "$outdir/kernel.gz.tmp" "$outdir/SHA512.tmp"
  ls -l "$outdir/$asset"
  n=$((n + 1))
done
# Unlike the microvm script, none is not an error: alpha releases are not
# required to be in the build list.
echo "fetch-alpha-kernel: $n kernel(s)"

#!/usr/bin/env bash
# Makes the Linux download: a tarball with the program, its icons and an install script.
#
#   packaging/linux/package.sh <name> <beckon-binary> <output-folder>
#
# <name> is what the download is called, such as beckon-v2.0.0-linux-x86_64; the tarball is <name>.tar.gz and
# unpacks into a folder of the same name.
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "usage: $0 <name> <beckon-binary> <output-folder>" >&2
  exit 2
fi
name="$1"
binary="$2"
output="$3"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"

stage="$(mktemp -d)"
cleanup() { if [ -n "${stage:-}" ] && [ -d "$stage" ]; then rm -r -- "$stage"; fi; }
trap cleanup EXIT

folder="$stage/$name"
mkdir -p "$folder/icons" "$output"
install -m755 "$binary" "$folder/beckon"
install -m755 "$here/install.sh" "$folder/install.sh"
install -m644 "$here/beckon.desktop" "$folder/beckon.desktop"
install -m644 "$here/60-beckon-uinput.rules" "$folder/60-beckon-uinput.rules"
install -m644 "$repo/docs/brand/icon.svg" "$folder/beckon.svg"
install -m644 "$repo"/packaging/icons/beckon-*.png "$folder/icons/"
install -m644 "$repo/LICENSE" "$folder/LICENSE"
install -m644 "$repo/THIRD_PARTY_LICENSES.md" "$folder/THIRD_PARTY_LICENSES.md"
cat > "$folder/README.txt" <<'TEXT'
Beckon: your phone as a trackpad and keyboard for this computer.

  ./install.sh              install for you (into ~/.local), no root needed
  ./install.sh --uninstall  remove it again

The first time, Beckon asks for permission to type and click (a button on its page, "Allow..."; your system
asks for your password once). To do it by hand instead, as root:

  sudo install -m644 60-beckon-uinput.rules /etc/udev/rules.d/
  echo uinput | sudo tee /etc/modules-load.d/beckon.conf
  sudo modprobe uinput
  sudo udevadm control --reload && sudo udevadm trigger

Then open Beckon from your applications menu. Its first start shows a QR code: scan it with the Beckon
app on your phone (https://github.com/omsingh02/beckon#quick-start).
TEXT

# Sorted names and a fixed owner and time, so that two builds of the same files differ as little as possible.
tar --sort=name --owner=0 --group=0 --numeric-owner --mtime='2020-01-01 00:00:00 UTC' \
  -czf "$output/$name.tar.gz" -C "$stage" "$name"
echo "Wrote $output/$name.tar.gz"

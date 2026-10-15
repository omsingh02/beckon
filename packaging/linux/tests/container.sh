#!/bin/sh
# Runs INSIDE a container (see run.sh): installs the package of the container's kind with the system's own package
# manager, checks what it did, removes it, and checks that it is gone. /pkg holds the packages, and $1 the version
# the program must report.
set -eu
fail() { echo "FAIL: $*" >&2; exit 1; }
expected="$1"
log=/tmp/install.log

if command -v apt-get > /dev/null; then kind=deb
elif command -v dnf > /dev/null; then kind=rpm
elif command -v pacman > /dev/null; then kind=arch
else fail "no package manager that Beckon has a package for"; fi

case "$kind" in
  deb)
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq > /dev/null
    install() { apt-get install -y -qq /pkg/*.deb > "$log" 2>&1; }
    add() { apt-get install -y -qq "$@" > /dev/null 2>&1; }
    remove() { apt-get remove -y -qq beckon > /dev/null 2>&1; }
    echo_installed() { dpkg-query -W -f='${Package} ${Version} ${Architecture}' beckon; } ;;
  rpm)
    install() { dnf install -y -q /pkg/*.rpm > "$log" 2>&1; }
    add() { dnf install -y -q "$@" > /dev/null 2>&1; }
    remove() { dnf remove -y -q beckon > /dev/null 2>&1; }
    echo_installed() { rpm -q --qf '%{NAME} %{VERSION} release %{RELEASE} %{ARCH}' beckon; } ;;
  arch)
    pacman -Sy --noconfirm > /dev/null 2>&1
    install() { pacman -U --noconfirm /pkg/*.pkg.tar.zst > "$log" 2>&1; }
    add() { pacman -S --noconfirm --needed "$@" > /dev/null 2>&1; }
    remove() { pacman -R --noconfirm beckon > /dev/null 2>&1; }
    echo_installed() { pacman -Q beckon; } ;;
esac

install || { cat "$log"; fail "the package manager could not install the package"; }
echo "installed: $(echo_installed)"

[ "$(beckon --version)" = "beckon $expected" ] || fail "beckon --version says '$(beckon --version)', not 'beckon $expected'"
for f in /usr/bin/beckon /usr/share/applications/beckon.desktop /usr/lib/udev/rules.d/60-beckon-uinput.rules \
    /usr/lib/modules-load.d/beckon.conf /etc/ufw/applications.d/beckon /usr/lib/firewalld/services/beckon.xml \
    /usr/share/icons/hicolor/scalable/apps/beckon.svg /usr/share/icons/hicolor/48x48/apps/beckon.png; do
    [ -e "$f" ] || fail "$f is missing"
done
grep -q uinput /usr/lib/modules-load.d/beckon.conf || fail "the module list does not name uinput"
grep -q 'TAG+="uaccess"' /usr/lib/udev/rules.d/60-beckon-uinput.rules || fail "the udev rule does not give the person access"
# A missing library is reported as "libfoo.so => not found". (A binary built on a newer system also names weak
# symbols of newer glibc versions, which ldd mentions as "weak version ... not found": harmless, the program runs.)
[ "$(ldd /usr/bin/beckon | grep -c '=> not found' || true)" = 0 ] || fail "a library the program needs is missing"

# Where each kind keeps the license, and how it reports what the package needs.
case "$kind" in
  deb)
    [ -e /usr/share/doc/beckon/copyright ] || fail "the license is missing"
    # Ubuntu's container images leave out most of /usr/share/doc, so this is asked of the package's file list.
    dpkg -L beckon | grep -q '/usr/share/doc/beckon/THIRD_PARTY_LICENSES.md$' || fail "the third-party licenses are not in the package"
    echo "dependencies: $(dpkg-query -W -f='${Depends}' beckon)" ;;
  rpm)
    [ -e /usr/share/licenses/beckon/LICENSE ] && [ -e /usr/share/licenses/beckon/THIRD_PARTY_LICENSES.md ] || fail "the licenses are missing"
    rpm -q --scripts beckon | grep -q udevadm || fail "the package does not tell udev about its rule"
    echo "requires: $(rpm -q --requires beckon | grep -v -E '^(rpmlib|/bin/sh)' | tr '\n' ',')" ;;
  arch)
    [ -e /usr/share/licenses/beckon/LICENSE ] && [ -e /usr/share/licenses/beckon/THIRD_PARTY_LICENSES.md ] || fail "the licenses are missing"
    echo "depends: $(pacman -Qi beckon | sed -n 's/^Depends On *: //p')" ;;
esac

# The desktop entry and the firewall names are valid for the tools that read them (not on Arch, where those tools are
# not part of a base system and the files are only checked to be there).
case "$kind" in
  deb)
    add desktop-file-utils ufw
    desktop-file-validate /usr/share/applications/beckon.desktop || fail "the desktop entry is not valid"
    ufw app info Beckon | grep -q '5000/udp' || fail "ufw does not know Beckon as 5000/udp" ;;
  rpm)
    add desktop-file-utils firewalld
    desktop-file-validate /usr/share/applications/beckon.desktop || fail "the desktop entry is not valid"
    firewall-offline-cmd --info-service=beckon | grep -q '5000/udp' || fail "firewalld does not know Beckon as 5000/udp" ;;
esac

remove
for f in /usr/bin/beckon /usr/lib/udev/rules.d/60-beckon-uinput.rules /usr/share/applications/beckon.desktop; do
    [ ! -e "$f" ] || fail "$f is still there after removing the package"
done
echo "ok: installs, runs, and removes cleanly"

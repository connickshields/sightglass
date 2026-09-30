#!/usr/bin/env bash
# Checks a release build of Sightglass.app: universal, validly signed, has its
# icon, and is stamped with the expected version.
#
# Usage: packaging/check-app.sh APP VERSION
set -euo pipefail

if [ $# -ne 2 ]; then
    echo "usage: $0 APP VERSION" >&2
    exit 2
fi
app=$1
version=$2

fail() {
    echo "check-app: $*" >&2
    exit 1
}

[ -d "$app" ] || fail "$app not found"
[ -f "$app/Contents/Resources/AppIcon.icns" ] || fail "AppIcon.icns missing"
archs=$(lipo -archs "$app/Contents/MacOS/Sightglass")
for arch in arm64 x86_64; do
    case " $archs " in
        *" $arch "*) ;;
        *) fail "missing $arch slice (has: $archs)" ;;
    esac
done
codesign --verify --strict "$app" || fail "signature does not verify"
actual=$(plutil -extract CFBundleShortVersionString raw "$app/Contents/Info.plist")
[ "$actual" = "$version" ] || fail "version is $actual, expected $version"
echo "check-app: $app is universal, signed, and version $version"

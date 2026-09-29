#!/usr/bin/env bash
# Renders the Homebrew cask for a release from sightglass.rb.tmpl.
#
# Usage: packaging/render-cask.sh VERSION SHA256 OUTPUT
set -euo pipefail

if [ $# -ne 3 ]; then
    echo "usage: $0 VERSION SHA256 OUTPUT" >&2
    exit 2
fi
version=$1
sha256=$2
output=$3

if ! [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "error: version must look like 1.2.3, got '$version'" >&2
    exit 1
fi
if ! [[ $sha256 =~ ^[0-9a-f]{64}$ ]]; then
    echo "error: sha256 must be 64 lowercase hex characters, got '$sha256'" >&2
    exit 1
fi

template="$(dirname "$0")/sightglass.rb.tmpl"
mkdir -p "$(dirname "$output")"
sed -e "s/@VERSION@/$version/g" -e "s/@SHA256@/$sha256/g" "$template" > "$output"

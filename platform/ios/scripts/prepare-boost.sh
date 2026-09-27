#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
if [ -f "$ROOT/vendor/boost/boost/version.hpp" ]; then
    grep -q '^#define BOOST_VERSION 108400$' "$ROOT/vendor/boost/boost/version.hpp"
    exit 0
fi
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT HUP INT TERM
curl -fL --retry 3 https://archives.boost.io/release/1.84.0/source/boost_1_84_0.tar.gz -o "$STAGE/boost.tar.gz"
printf '%s  %s\n' a5800f405508f5df8114558ca9855d2640a2de8f0445f051fa1c7c3383045724 "$STAGE/boost.tar.gz" | shasum -a 256 -c -
tar xzf "$STAGE/boost.tar.gz" -C "$STAGE"
mkdir -p "$ROOT/vendor"
mv "$STAGE/boost_1_84_0" "$ROOT/vendor/boost"

#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
CORE="$ROOT/touchHLE-ios-core"
CORE_REV=03bdf55813bcdd5f715b66cb02f2cfcaae6736a8
DYNARMIC_REV=f488f760c69c42a97331961e8e6c359b46ccc9e9

# Refuse a different checkout rather than resetting someone's local work.
if [ ! -e "$CORE" ]; then
    git clone https://github.com/johnny901901901/touchHLE.git "$CORE"
    git -C "$CORE" checkout "$CORE_REV"
fi
test "$(git -C "$CORE" rev-parse HEAD)" = "$CORE_REV" || {
    echo "Expected touchHLE at $CORE_REV; move the existing checkout aside." >&2
    exit 1
}

apply_once() {
    checkout=$1
    patch=$2
    if git -C "$checkout" apply --reverse --check "$patch" 2>/dev/null; then
        echo "Already applied: $(basename "$patch")"
    else
        git -C "$checkout" apply --check "$patch"
        git -C "$checkout" apply "$patch"
    fi
}

git -C "$ROOT" submodule update --init --recursive vendor/rust-sdl2
apply_once "$ROOT/vendor/rust-sdl2/sdl2-sys/SDL" "$ROOT/patches/sdl-orientation.patch"
apply_once "$CORE" "$ROOT/patches/touchhle-codz.patch"

# The iOS JIT commit lives in the iOS port's Dynarmic fork.
git -C "$CORE" config submodule.dynarmic.url https://github.com/johnny901901901/dynarmic.git
git -C "$CORE" submodule update --init --recursive vendor/stb vendor/openal-soft vendor/rust-sdl2
if [ ! -e "$CORE/vendor/dynarmic/.git" ]; then
    git -C "$CORE" submodule update --init vendor/dynarmic
fi
if ! git -C "$CORE/vendor/dynarmic" cat-file -e "$DYNARMIC_REV^{commit}"; then
    git -C "$CORE/vendor/dynarmic" fetch https://github.com/johnny901901901/dynarmic.git "$DYNARMIC_REV"
fi
git -C "$CORE/vendor/dynarmic" checkout "$DYNARMIC_REV"
git -C "$CORE/vendor/dynarmic" submodule update --init --recursive
echo "Prepared touchHLE $CORE_REV with Dynarmic $DYNARMIC_REV"

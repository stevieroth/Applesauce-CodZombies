# Building Applesauce-CodZombies

For installation without compiling, use the [release IPA](https://github.com/stevieroth/Applesauce-CodZombies/releases)
and [main guide](../../README.md).

RC1 was built on Apple Silicon with Xcode 27.0 (27A266a), Rust 1.98.0,
CMake, Ninja, Python 3 and Boost 1.84.0. Select full Xcode as the active developer
directory. Build unsigned for an iPhone; a simulator is not a gameplay/JIT test.

```sh
git clone https://github.com/stevieroth/Applesauce-CodZombies.git
cd Applesauce-CodZombies
brew install cmake ninja
rustup target add aarch64-apple-ios
sh platform/ios/scripts/prepare-codz.sh
sh platform/ios/scripts/prepare-boost.sh
sh platform/ios/scripts/build-sdl-shared.sh iphoneos
sh platform/ios/scripts/build-host.sh iphoneos Release
sh platform/ios/scripts/package-ipa.sh dist/Applesauce-CodZombies-0.4.1-rc1-unsigned.ipa
python3 platform/ios/scripts/verify-codz-release.py dist/Applesauce-CodZombies-0.4.1-rc1-unsigned.ipa
```

The package must be signed by your sideloading tool. No game files are included.

## Source layout

`prepare-codz.sh` checks out touchHLE at
`03bdf55813bcdd5f715b66cb02f2cfcaae6736a8`, applies
`patches/touchhle-codz.patch`, and pins Dynarmic to
`f488f760c69c42a97331961e8e6c359b46ccc9e9`. Other dependency revisions are pinned
by upstream submodules. `patches/sdl-orientation.patch` supplies the shared
SDL orientation changes.

The generated `touchHLE-ios-core` checkout is ignored by the outer repository.
The patch is the maintained source of core changes; regenerate it after edits.
Preparation refuses a different core base and does not reset local changes.
The legacy HyperHLE Rust source in the outer repository is not compiled by
these iOS commands. Only touchHLE and the shared SDL library enter the app.

`build-host.sh` also embeds the known-working script in `LCAppInfo.plist`.
The `jit` directory records its source, license and SHA-256. Historical trace
markers in runtime logs describe retained startup/rotation fixes; they do not
mean networking or controller experiments are enabled.

## Validation

`python3 platform/ios/scripts/test-runloop.py` reproduces the old main-queue
starvation and verifies the production timer launch across two starts.
The package validator checks ZIP integrity, architecture, expected libraries,
minimum OS, unsigned status, JIT metadata, and removal of experimental strings.

Before marking a release stable, test launch, loading/playing a map, audio,
movement/fire, physical rotation, Exit Game and a second launch with JIT on an
iPhone in the intended installation setup. Local checks cannot replace that test.

# Applesauce-CodZombies

An unofficial edition of [Applesauce, created by johnny901901901](https://github.com/johnny901901901/Applesauce),
focused on **Call of Duty: Zombies 1.5.0** on modern iPhones, using touchHLE.
This edition supports **offline play with
on-screen touch controls**. No game files are included.

## Download and install

Download the unsigned IPA and **Applesauce-LiveContainer-universal.js** from
[Releases](https://github.com/stevieroth/Applesauce-CodZombies/releases).
**You do not need to compile the app.** The first stable release is 0.4.1.
Stephen confirmed that Zombies launches and plays on his iPhone. This is the
exact IPA tested as RC1, with the same startup/rotation fixes; no reinstall is
needed if you already have RC1. Other devices and setups may behave differently.

1. Sideload the IPA with your existing signing setup, or import it into LiveContainer.
2. In LiveContainer, select the downloaded script as Applesauce's JIT launch
   script, enable Launch with JIT, and use your configured StikDebug/pairing setup.
   Start Applesauce with LiveContainer's normal Run button.
3. For standalone Applesauce, import/select the script in StikDebug for
   Applesauce and enable JIT before opening a game.
4. Import your own decrypted **32-bit iOS** copy of Call of Duty: Zombies 1.5.0.
   The Android package cannot be used here.
5. Start with Applesauce's Starting Orientation set to **Landscape Right**.
   Use the game's on-screen controls.

See [JIT setup](jit/README.md). The IPA also includes the script in its
LiveContainer launch metadata. JIT is required; no pairing file is supplied.

## Included fixes and scope

- One touchHLE core with the tested Dynarmic `f488f760` iOS JIT setup.
- Zombies loader-checksum compatibility, `dladdr` and audio-route support.
  The imported game file is not modified.
- The run-loop launch and orientation fixes from the working touch build.
- Touchscreen controls. The experimental Zombies controller profile/settings
  and multiplayer networking additions are omitted. Guest networking is
  disabled, including when old settings request it. Online play is unsupported.

The app targets iOS 15+, but not all devices or iOS versions have been tested.
JIT availability depends on the device and installation method. HyperHLE is
not shipped; other games requiring that core are outside this release's scope.
Exit-button placement can still vary with orientation.

The bundle identifier remains `io.github.johnny901901901.applesauce` for
compatibility with existing installs. Depending on your signer, this may
replace an existing Applesauce install. Back up saves before changing builds.

## Source and reports

See [build instructions](platform/ios/README.md) for pinned dependencies and
patches. The iOS build uses the generated `touchHLE-ios-core` checkout, not the
legacy HyperHLE source retained in the root of this upstream fork.

Report issues to [this fork](https://github.com/stevieroth/Applesauce-CodZombies/issues)
with the app version, device/iOS, installation method and JIT setup. Review
logs before posting them; do not upload game files or pairing data.

## Credits and licenses

- [Applesauce / johnny901901901](https://github.com/johnny901901901/Applesauce):
  native iOS app, interface, build and packaging work.
- [ChatProductions](https://github.com/ChatProductions/Applesauce-AppStore-StikDebug):
  intermediate fork used during development and LiveContainer/JIT diagnostics.
- [touchHLE](https://github.com/touchHLE/touchHLE) and its
  [iOS port](https://github.com/johnny901901901/touchHLE): emulator core.
- [HyperHLE](https://github.com/HyperHLE/HyperHLE): upstream repository heritage;
  its core is not included in this IPA.
- [nerivalaitis](https://github.com/nerivalaitis): upstream iOS 15, memory and
  TrollStore work. u/WorriedEquipment2241 demonstrated an earlier iOS port.
- [StikDebug](https://github.com/StikDebug/StikDebug) and
  [LiveContainer](https://github.com/LiveContainer/LiveContainer): JIT tooling.

This community project is unaffiliated with and not endorsed by those projects,
Apple or Activision. Existing MPL-2.0 notices and third-party licenses are
retained. The separately distributed JIT script is AGPL-3.0; its license and
exact source reference are in [jit](jit/README.md).

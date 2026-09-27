# Applesauce-CodZombies 0.4.1

First stable release for offline Call of Duty: Zombies 1.5.0
on iOS. **No compilation needed:** sideload the unsigned IPA, enable JIT with
the included script, and import your own decrypted iOS copy of the game.

Based on [Applesauce by johnny901901901](https://github.com/johnny901901901/Applesauce),
with emulation provided by touchHLE. This is an unofficial community edition;
full upstream and contributor credits are in the README.

Retains the working Zombies startup, audio, Dynarmic JIT and orientation/run-loop
fixes. Removes the experimental Zombies controller profile and multiplayer
networking additions. Ships only touchHLE. Use on-screen touch controls;
online multiplayer is not supported.

Downloads:
- **Applesauce-CodZombies-0.4.1-unsigned.ipa**: app for sideloading/LiveContainer.
- **Applesauce-LiveContainer-universal.js**: select as Applesauce's JIT launch
  script in LiveContainer/StikDebug. Enable Launch with JIT and use normal Run
  with your existing pairing setup.
- **JIT-SETUP.txt** and **JIT-SCRIPT-LICENSE.txt**: instructions and script license.
- **SHA256SUMS.txt**: download checksums.

Start with Applesauce's Starting Orientation set to Landscape Right. The bundle
identifier is retained for compatibility, so this may replace an existing
Applesauce install depending on your signer. Back up saves.

**Stephen confirmed that Zombies launches and plays on his iPhone.** This release
uses the exact IPA tested as RC1, renamed for the stable release. No rebuild or
reinstall is needed for existing RC1 users. Local compilation and package checks
also passed. This confirms gameplay on Stephen's setup, not every device or
installation method.

No games, signing identities or pairing files are included. Source, build
instructions and credits are in the repository.

# Applesauce-CodZombies 0.4.1 RC1

First downloadable release candidate for offline Call of Duty: Zombies 1.5.0
on iOS. **No compilation needed:** sideload the unsigned IPA, enable JIT with
the included script, and import your own decrypted iOS copy of the game.

Retains the working Zombies startup, audio, Dynarmic JIT and orientation/run-loop
fixes. Removes the experimental Zombies controller profile and multiplayer
networking additions. Ships only touchHLE. Use on-screen touch controls;
online multiplayer is not supported.

Downloads:
- **Applesauce-CodZombies-0.4.1-rc1-unsigned.ipa**: app for sideloading/LiveContainer.
- **Applesauce-LiveContainer-universal.js**: select as Applesauce's JIT launch
  script in LiveContainer/StikDebug. Enable Launch with JIT and use normal Run
  with your existing pairing setup.
- **JIT-SETUP.txt** and **JIT-SCRIPT-LICENSE.txt**: instructions and script license.
- **SHA256SUMS.txt**: download checksums.

Start with Applesauce's Starting Orientation set to Landscape Right. The bundle
identifier is retained for compatibility, so this may replace an existing
Applesauce install depending on your signer. Back up saves.

Local iPhoneOS Release compilation and package checks passed. **This exact RC1
still needs an iPhone gameplay test before being marked stable.** Its foundation
is the previously working touch build. No games, signing identities or pairing
files are included. Source, build instructions and credits are in the repository.

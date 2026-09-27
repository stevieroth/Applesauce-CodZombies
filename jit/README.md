# JIT launch script

`Applesauce-LiveContainer-universal.js` is the unmodified universal JIT script
from StikDebug 3.1.6, renamed so it is easy to select. It is distributed
separately under the accompanying AGPL-3.0 license; credit belongs to its authors.

Source: https://github.com/StikDebug/StikDebug/blob/7f2808bfb5be63aee2af9e1542b5baef6e591661/StikDebug/Scripts/universal.js

SHA-256: `e9828331a815c10c2077df6c66c2a974dfec235d03231aba4e50044c6015ea14`

Import this file into StikDebug. In LiveContainer, select it as Applesauce's
JIT launch script and enable Launch with JIT. Use your existing pairing/JIT
setup, then start Applesauce with LiveContainer's normal Run button. The IPA
also includes this script in its LiveContainer launch metadata.

For standalone Applesauce, select this script in StikDebug for Applesauce,
enable JIT, then return to Applesauce and open your game.

A generic “JIT enabled” status alone does not confirm that the memory setup
script was selected. Keep the script selected for each new process launch.
No pairing file or signing identity is included.

#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>

// Whether dynarmic can get the executable memory it needs. Without it,
// starting a game kills the app.
bool touchhle_ios_jit_available(void);

// Whether that came from an attached debugger rather than from the
// `dynamic-codesigning` entitlement. A debugger has to be re-attached every
// time the app starts as a new process; the entitlement does not.
bool touchhle_ios_jit_is_from_debugger(void);

// Start from a run-loop timer so SDL's event pump can also service the main
// dispatch queue during gameplay. The callback runs on the main thread.
void touchhle_ios_schedule_game_launch(void (^launch)(void));

// The emulator core lives in a dylib that the app loads at runtime (see
// EmulatorCore.swift), so its entry points are found with dlsym rather than
// declared here. Only the SDL shim below is part of the app binary.

typedef int32_t (*TouchHLEIOSRunGameFn)(
    const char *path,
    int32_t scale_hack,
    int32_t orientation,
    int32_t network_access,
    int32_t analog_stick_tilt_controls
);

int32_t touchhle_ios_launch_game(
    TouchHLEIOSRunGameFn run_game,
    const char *path,
    int32_t scale_hack,
    int32_t orientation,
    int32_t network_access,
    int32_t analog_stick_tilt_controls
);

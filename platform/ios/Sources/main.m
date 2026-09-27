#include <SDL.h>
#include <SDL_system.h>
#include <dlfcn.h>
#include <errno.h>
#include <limits.h>
#include <objc/message.h>
#include <objc/runtime.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/sysctl.h>
#include <sys/types.h>
#include <unistd.h>

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// This private-to-the-host SDL hint tells the UIKit view controller to hold
// the scene at the already-selected interface orientation. SDL's public
// orientation hint controls the allowed mask; iOS 26's orientation-lock
// preference is what prevents a 180-degree sensor turn from rotating the
// scene and suspending touch delivery.
#define TOUCHHLE_ORIENTATION_LOCK_HINT "SDL_TOUCHHLE_ORIENTATION_LOCKED"

// LiveContainer's guest hook intentionally broadens a landscape app to both
// landscape directions. That is useful for ordinary apps, but it is exactly
// what lets a physical 180-degree turn start a UIKit transition in the SDL
// game window. Keep the hook installed only for the game session and return
// the one direction selected by Applesauce.
static BOOL touchhle_orientation_lock_active;
static NSUInteger touchhle_orientation_lock_mask = UIInterfaceOrientationMaskAll;
static SEL touchhle_original_supported_orientations_selector;
static BOOL touchhle_orientation_lock_hook_installed;

static NSUInteger touchhle_locked_supported_interface_orientations(
    id object,
    SEL selector
) {
    if (touchhle_orientation_lock_active) {
        return touchhle_orientation_lock_mask;
    }
    if (touchhle_original_supported_orientations_selector != NULL) {
        return ((NSUInteger (*)(id, SEL))objc_msgSend)(
            object,
            touchhle_original_supported_orientations_selector
        );
    }
    return UIInterfaceOrientationMaskAll;
}

static void touchhle_install_orientation_lock_hook(void) {
    if (touchhle_orientation_lock_hook_installed) {
        return;
    }

    Class view_controller_class = UIViewController.class;
    SEL private_selector = NSSelectorFromString(@"__supportedInterfaceOrientations");
    Method private_method = class_getInstanceMethod(view_controller_class, private_selector);
    if (private_method == NULL) {
        fprintf(stderr, "TRACE14 private orientation query unavailable\n");
        return;
    }

    touchhle_original_supported_orientations_selector =
        NSSelectorFromString(@"touchHLE_original___supportedInterfaceOrientations");
    class_addMethod(
        view_controller_class,
        touchhle_original_supported_orientations_selector,
        method_getImplementation(private_method),
        method_getTypeEncoding(private_method)
    );
    method_setImplementation(
        private_method,
        (IMP)touchhle_locked_supported_interface_orientations
    );
    touchhle_orientation_lock_hook_installed = YES;
    fprintf(stderr, "TRACE14 private orientation query hook installed\n");
}

static void touchhle_set_orientation_lock(int32_t orientation) {
    if (orientation == 1) {
        touchhle_orientation_lock_mask = UIInterfaceOrientationMaskLandscapeLeft;
    } else if (orientation == 2) {
        touchhle_orientation_lock_mask = UIInterfaceOrientationMaskLandscapeRight;
    } else {
        touchhle_orientation_lock_mask = UIInterfaceOrientationMaskPortrait;
    }
    touchhle_install_orientation_lock_hook();
    touchhle_orientation_lock_active = YES;
    fprintf(stderr, "TRACE14 guest orientation mask locked: 0x%lx\n", (unsigned long)touchhle_orientation_lock_mask);
}

static void touchhle_clear_orientation_lock(void) {
    touchhle_orientation_lock_active = NO;
}

// SDL pumps a nested CFRunLoop while the emulator runs on the main thread.
// Starting it inside a main-queue dispatch block prevents that nested loop
// from servicing the main dispatch queue until the game exits. Use a timer
// callout, as SDL's own UIKit startup does, so UIKit can finish its work.
void touchhle_ios_schedule_game_launch(void (^launch)(void)) {
    NSCAssert(NSThread.isMainThread, @"Game launch must be scheduled on the main thread");
    NSTimer *timer = [NSTimer timerWithTimeInterval:1.0 repeats:NO block:^(NSTimer *unused) {
        launch();
    }];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
}

static NSTimer *touchhle_orientation_diagnostic_timer;
static NSMutableArray *touchhle_orientation_diagnostic_observers;

static void touchhle_start_orientation_diagnostics(void) {
    Class defaults = NSUserDefaults.class;
    SEL live_process_selector = NSSelectorFromString(@"isLiveProcess");
    BOOL in_livecontainer = [defaults respondsToSelector:live_process_selector];
    BOOL live_process = in_livecontainer
        && ((BOOL (*)(id, SEL))objc_msgSend)(defaults, live_process_selector);
    NSString *scheme = @"standalone";
    NSDictionary *guest_info = nil;
    if ([defaults respondsToSelector:NSSelectorFromString(@"lcAppUrlScheme")]) {
        scheme = ((id (*)(id, SEL))objc_msgSend)(defaults, NSSelectorFromString(@"lcAppUrlScheme"));
    }
    if ([defaults respondsToSelector:NSSelectorFromString(@"guestAppInfo")]) {
        guest_info = ((id (*)(id, SEL))objc_msgSend)(defaults, NSSelectorFromString(@"guestAppInfo"));
    }
    fprintf(stderr, "TRACE16 launch via run-loop timer: LiveContainer=%d LiveProcess=%d scheme=%s LCOrientationLock=%ld\n",
            in_livecontainer, live_process, scheme.UTF8String ?: "unknown",
            (long)[guest_info[@"LCOrientationLock"] integerValue]);

    __block NSString *last_snapshot = nil;
    __block NSUInteger snapshots_remaining = 48;
    void (^snapshot)(void) = ^{
        if (snapshots_remaining == 0) {
            return;
        }
        NSMutableString *state = [NSMutableString stringWithFormat:@"device=%ld", (long)UIDevice.currentDevice.orientation];
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) {
                continue;
            }
            UIWindowScene *window_scene = (UIWindowScene *)scene;
            BOOL effective_lock = NO;
            if (@available(iOS 26.0, *)) {
                effective_lock = window_scene.effectiveGeometry.isInterfaceOrientationLocked;
            }
            [state appendFormat:@" scene=(orientation=%ld bounds=%@ effectiveLock=%d)",
                (long)window_scene.interfaceOrientation,
                NSStringFromCGRect(window_scene.coordinateSpace.bounds), effective_lock];
            for (UIWindow *window in window_scene.windows) {
                if (window.hidden) {
                    continue;
                }
                UIViewController *root = window.rootViewController;
                BOOL prefers_lock = NO;
                if (@available(iOS 26.0, *)) {
                    prefers_lock = root.prefersInterfaceOrientationLocked;
                }
                [state appendFormat:@" window=(root=%@ key=%d frame=%@ mask=0x%lx autorotate=%d prefersLock=%d)",
                    NSStringFromClass(root.class), window.isKeyWindow, NSStringFromCGRect(window.frame),
                    (unsigned long)root.supportedInterfaceOrientations, root.shouldAutorotate, prefers_lock];
            }
        }
        if (![state isEqualToString:last_snapshot]) {
            fprintf(stderr, "TRACE16 orientation state: %s\n", state.UTF8String);
            last_snapshot = [state copy];
            snapshots_remaining--;
        }
    };
    snapshot();
    touchhle_orientation_diagnostic_timer = [NSTimer timerWithTimeInterval:0.5 repeats:YES block:^(NSTimer *unused) {
        snapshot();
    }];
    [[NSRunLoop mainRunLoop] addTimer:touchhle_orientation_diagnostic_timer forMode:NSRunLoopCommonModes];
    touchhle_orientation_diagnostic_observers = [NSMutableArray array];
    id key_observer = [NSNotificationCenter.defaultCenter addObserverForName:UIWindowDidBecomeKeyNotification
        object:nil queue:nil usingBlock:^(NSNotification *notification) {
            // SDL creates its key window after the native controls requested
            // the lock. Re-submit the preference for the new root controller.
            UIWindow *window = notification.object;
            if (@available(iOS 16.0, *)) {
                [window.rootViewController setNeedsUpdateOfSupportedInterfaceOrientations];
            }
            if (@available(iOS 26.0, *)) {
                [window.rootViewController setNeedsUpdateOfPrefersInterfaceOrientationLocked];
            }
            snapshot();
        }];
    [touchhle_orientation_diagnostic_observers addObject:key_observer];
    id device_observer = [NSNotificationCenter.defaultCenter addObserverForName:UIDeviceOrientationDidChangeNotification
        object:nil queue:nil usingBlock:^(NSNotification *unused) {
            snapshot();
        }];
    [touchhle_orientation_diagnostic_observers addObject:device_observer];
}

static void touchhle_stop_orientation_diagnostics(void) {
    [touchhle_orientation_diagnostic_timer invalidate];
    touchhle_orientation_diagnostic_timer = nil;
    for (id observer in touchhle_orientation_diagnostic_observers) {
        [NSNotificationCenter.defaultCenter removeObserver:observer];
    }
    touchhle_orientation_diagnostic_observers = nil;
}

// Each emulator core exports this; the host passes in the one belonging to the
// core it loaded for this game.
typedef int32_t (*TouchHLEIOSRunGameFn)(
    const char *path,
    int32_t scale_hack,
    int32_t orientation,
    int32_t network_access,
    int32_t analog_stick_tilt_controls
);

// Dynarmic needs writable-executable memory, and two things can grant it:
//
//   * An attached debugger (StikDebug, AltJIT, TrollStore's "Enable JIT"),
//     which sets CS_DEBUGGED on the process. This has to be redone every time
//     the app starts as a new process.
//   * The `dynamic-codesigning` entitlement, which makes it permanent. Only
//     TrollStore can grant that, and iOS 15+ only honours it on A11 and older
//     chips.
//
// Checking only for a debugger would tell a TrollStore user with permanent JIT
// that they have none, and hold back a launch that would have worked.

// Not declared in the public SDK, but a stable syscall wrapper in libSystem.
extern int csops(pid_t pid, unsigned int ops, void *useraddr, size_t usersize);
#define TOUCHHLE_CS_OPS_STATUS 0
#define TOUCHHLE_CS_DEBUGGED 0x10000000

bool touchhle_ios_jit_is_from_debugger(void) {
    // dynarmic's code allocator asks for its executable memory by executing
    // `brk #0xf00d` (see oaknut's prepare_jit_region), a trap that only an
    // attached debugger can service. With none attached the trap is fatal the
    // instant a game starts, which reads as the app quitting for no reason.
    unsigned int flags = 0;
    if (csops(getpid(), TOUCHHLE_CS_OPS_STATUS, &flags, sizeof(flags)) == 0
        && (flags & TOUCHHLE_CS_DEBUGGED) != 0) {
        return true;
    }

    // P_TRACED is the older signal for the same thing, and is what this app
    // shipped with through 0.3.0. Keep it as a second opinion rather than
    // replace it.
    struct kinfo_proc info;
    info.kp_proc.p_flag = 0;

    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()};
    size_t size = sizeof(info);
    if (sysctl(mib, 4, &info, &size, NULL, 0) != 0) {
        return false;
    }

    return (info.kp_proc.p_flag & P_TRACED) != 0;
}

// SecTask lives in Security.framework but is not declared in the iOS SDK.
// Resolve it at runtime so a missing symbol degrades to "no entitlement"
// rather than stopping the app from launching at all.
static bool touchhle_has_dynamic_codesigning(void) {
    typedef CFTypeRef (*create_from_self_fn)(CFAllocatorRef);
    typedef CFTypeRef (*copy_entitlement_fn)(CFTypeRef, CFStringRef, CFErrorRef *);

    static create_from_self_fn create_task;
    static copy_entitlement_fn copy_entitlement;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *security = dlopen(
            "/System/Library/Frameworks/Security.framework/Security",
            RTLD_LAZY
        );
        if (security == NULL) {
            return;
        }
        create_task = (create_from_self_fn)dlsym(security, "SecTaskCreateFromSelf");
        copy_entitlement =
            (copy_entitlement_fn)dlsym(security, "SecTaskCopyValueForEntitlement");
    });

    if (create_task == NULL || copy_entitlement == NULL) {
        return false;
    }

    CFTypeRef task = create_task(kCFAllocatorDefault);
    if (task == NULL) {
        return false;
    }
    CFTypeRef value = copy_entitlement(task, CFSTR("dynamic-codesigning"), NULL);
    bool granted = value != NULL
        && CFGetTypeID(value) == CFBooleanGetTypeID()
        && CFBooleanGetValue((CFBooleanRef)value);
    if (value != NULL) {
        CFRelease(value);
    }
    CFRelease(task);
    return granted;
}

bool touchhle_ios_jit_available(void) {
    return touchhle_ios_jit_is_from_debugger() || touchhle_has_dynamic_codesigning();
}

// Do NOT add an mmap PROT_WRITE | PROT_EXEC probe here. Per mmap(2), iOS
// returns a writable-but-not-executable mapping instead of failing when
// MAP_JIT is absent, so that probe reports success with JIT off. A false "JIT
// is on" sends the emulator into a guaranteed freeze with no explanation.
void touchhle_ios_log_jit_status(const char *context) {
    unsigned int flags = 0;
    int result = csops(getpid(), TOUCHHLE_CS_OPS_STATUS, &flags, sizeof(flags));
    fprintf(
        stderr,
        "touchHLE JIT [%s]: available=%d debugger=%d entitlement=%d "
        "cs_flags=0x%08x csops=%d/%d\n",
        context ? context : "?",
        touchhle_ios_jit_available(),
        touchhle_ios_jit_is_from_debugger(),
        touchhle_has_dynamic_codesigning(),
        flags,
        result,
        (result == 0) ? 0 : errno
    );
}

static FILE *diagnostic_log;

static void redirect_diagnostics(void) {
    const char *home = getenv("HOME");
    if (home == NULL) {
        return;
    }

    char log_path[PATH_MAX];
    int length = snprintf(log_path, sizeof(log_path), "%s/Documents/touchhle-host.log", home);
    if (length < 0 || (size_t)length >= sizeof(log_path)) {
        return;
    }

    // If a game hangs, the only way out is to force-quit, and the next launch
    // would truncate the log that recorded the hang. Keep one generation back
    // so the interesting session survives the relaunch needed to retrieve it.
    char previous_path[PATH_MAX];
    length = snprintf(
        previous_path,
        sizeof(previous_path),
        "%s/Documents/touchhle-host-previous.log",
        home
    );
    if (length > 0 && (size_t)length < sizeof(previous_path)) {
        rename(log_path, previous_path);
    }

    diagnostic_log = fopen(log_path, "w");
    if (diagnostic_log == NULL) {
        return;
    }

    setvbuf(diagnostic_log, NULL, _IONBF, 0);
    dup2(fileno(diagnostic_log), STDOUT_FILENO);
    dup2(fileno(diagnostic_log), STDERR_FILENO);
    fprintf(stderr, "touchHLE iOS port diagnostics started\n");
}

static void start_native_host(void) {
    Class host_class = NSClassFromString(@"TouchHLENativeHost");
    SEL selector = NSSelectorFromString(@"start");
    if (host_class == Nil || ![host_class respondsToSelector:selector]) {
        fprintf(stderr, "Could not start the native iOS port UI\n");
        return;
    }

    ((void (*)(id, SEL))objc_msgSend)(host_class, selector);
}

int32_t touchhle_ios_launch_game(
    TouchHLEIOSRunGameFn run_game,
    const char *path,
    int32_t scale_hack,
    int32_t orientation,
    int32_t network_access,
    int32_t analog_stick_tilt_controls
) {
    if (run_game == NULL) {
        fprintf(stderr, "touchHLE failed: no emulator core was loaded\n");
        return 1;
    }

    const char *orientation_hint = "Portrait";
    if (orientation == 1) {
        orientation_hint = "LandscapeLeft";
    } else if (orientation == 2) {
        orientation_hint = "LandscapeRight";
    }
    // Keep the SDL game window aligned with the native controls window for
    // this session. The core sets this hint at normal priority when loading
    // or rotating the guest, allowing both landscape directions. Letting that
    // override the host's choice can start a UIKit rotation while the main
    // thread is running the emulator and leave touch delivery suspended.
    // Only lock the host display; the core still handles guest coordinates.
    if (!SDL_SetHintWithPriority(SDL_HINT_ORIENTATIONS, orientation_hint, SDL_HINT_OVERRIDE)) {
        fprintf(stderr, "touchHLE: could not lock the game orientation\n");
        return 1;
    }
    if (!SDL_SetHintWithPriority(
            TOUCHHLE_ORIENTATION_LOCK_HINT,
            "1",
            SDL_HINT_OVERRIDE
        )) {
        SDL_ResetHint(SDL_HINT_ORIENTATIONS);
        fprintf(stderr, "touchHLE: could not enable the scene orientation lock\n");
        return 1;
    }
    fprintf(stderr, "TRACE13 host orientation locked: %s\n", orientation_hint);
    touchhle_set_orientation_lock(orientation);
    touchhle_start_orientation_diagnostics();

    // Breadcrumbs: the emulator runs on the main thread, so if it hangs the UI
    // freezes with it and the log is the only way to see how far it got.
    touchhle_ios_log_jit_status("game-launch");
    fprintf(
        stderr,
        "touchHLE: entering emulator: scale_hack=%d orientation=%s network=%d "
        "analog_tilt=%d\n",
        scale_hack,
        orientation_hint,
        network_access,
        analog_stick_tilt_controls
    );

    SDL_iPhoneSetEventPump(SDL_TRUE);
    __block BOOL emulator_running = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        fprintf(stderr, "TRACE16 main queue serviced: emulatorRunning=%d\n", emulator_running);
    });
    int32_t result = run_game(
        path,
        scale_hack,
        orientation,
        network_access,
        analog_stick_tilt_controls
    );
    emulator_running = NO;
    SDL_iPhoneSetEventPump(SDL_FALSE);
    touchhle_stop_orientation_diagnostics();
    touchhle_clear_orientation_lock();
    SDL_ResetHint(TOUCHHLE_ORIENTATION_LOCK_HINT);
    SDL_ResetHint(SDL_HINT_ORIENTATIONS);

    fprintf(stderr, "touchHLE: emulator returned %d\n", result);
    return result;
}

int main(int argc, char *argv[]) {
    (void)argc;
    (void)argv;

    redirect_diagnostics();
    touchhle_ios_log_jit_status("launch");

    char *base_path = SDL_GetBasePath();
    if (base_path != NULL) {
        chdir(base_path);
        SDL_free(base_path);
    }

    start_native_host();
    return 0;
}

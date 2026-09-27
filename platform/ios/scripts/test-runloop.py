from pathlib import Path
import subprocess
root = Path(__file__).resolve().parents[3]
source = (root / 'platform/ios/Sources/main.m').read_text()
helper = source.split('void touchhle_ios_schedule_game_launch(void (^launch)(void)) {', 1)[1].split('\n}\n', 1)[0]
helper = 'void touchhle_ios_schedule_game_launch(void (^launch)(void)) {' + helper + '\n}\n'
host = (root / 'platform/ios/Sources/NativeHost.swift').read_text()
assert 'touchhle_ios_schedule_game_launch {\n' in host
assert 'DispatchQueue.main.asyncAfter(deadline: .now() + 1.0)' not in host
probe = r'''
#import <Foundation/Foundation.h>
HELPER
static void probe(const char *label, BOOL expectQueuedWork) {
    __block int completed = 0;
    __block BOOL timerWorked = NO;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSCAssert(NSThread.isMainThread, @"Wrong thread");
        NSCAssert(completed == 0, @"Out of order");
        completed++;
    });
    dispatch_async(dispatch_get_main_queue(), ^{
        NSCAssert(completed == 1, @"Out of order");
        completed++;
    });
    NSTimer *timer = [NSTimer timerWithTimeInterval:0.005 repeats:NO block:^(NSTimer *t) { timerWorked = YES; }];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    CFAbsoluteTime end = CFAbsoluteTimeGetCurrent() + 0.15;
    while (CFAbsoluteTimeGetCurrent() < end) {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.000002, true);
    }
    printf("%s: timer=%d queuedCallbacks=%d expected=%d\n", label, timerWorked, completed, expectQueuedWork ? 2 : 0);
    if (!timerWorked || completed != (expectQueuedWork ? 2 : 0)) exit(1);
}
int main(void) {
    @autoreleasepool {
        __block BOOL finished = NO;
        __block int launchCount = 0;
        dispatch_async(dispatch_get_main_queue(), ^{
            probe("Previous dispatch launch (reproduces starvation)", NO);
            touchhle_ios_schedule_game_launch(^{
                NSCAssert(NSThread.isMainThread, @"Launch moved off main thread");
                launchCount++;
                probe("Production timer launch", YES);
                dispatch_async(dispatch_get_main_queue(), ^{
                    touchhle_ios_schedule_game_launch(^{
                        launchCount++;
                        probe("Second game launch", YES);
                        finished = YES;
                    });
                });
            });
        });
        CFAbsoluteTime deadline = CFAbsoluteTimeGetCurrent() + 8.0;
        while (!finished && CFAbsoluteTimeGetCurrent() < deadline) {
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.02, true);
        }
        if (!finished || launchCount != 2) return 1;
    }
    puts("PASS: actual host scheduler keeps timer and main-queue work responsive across two launches.");
}
'''.replace('HELPER', helper)
import tempfile
temp = tempfile.TemporaryDirectory()
p = Path(temp.name) / 'runloop-regression.m'
p.write_text(probe)
exe = p.with_suffix('')
subprocess.run(['xcrun', 'clang', '-fobjc-arc', '-fblocks', '-framework', 'Foundation', str(p), '-o', str(exe)], check=True)
subprocess.run([str(exe)], check=True)

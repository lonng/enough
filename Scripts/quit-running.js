ObjC.import('AppKit');
const enoughBundleID = 'com.adore.enough';
const running = $.NSRunningApplication.runningApplicationsWithBundleIdentifier(enoughBundleID);
for (let index = 0; index < running.count; index++) {
    if (!running.objectAtIndex(index).terminate) {
        throw new Error('Could not quit the running Enough app.');
    }
}
// Process workspace notifications while waiting for graceful termination.
for (let attempt = 0; attempt < 100; attempt++) {
    if (Number($.NSRunningApplication.runningApplicationsWithBundleIdentifier(enoughBundleID).count) === 0) break;
    $.NSRunLoop.currentRunLoop.runUntilDate($.NSDate.dateWithTimeIntervalSinceNow(0.1));
}
if (Number($.NSRunningApplication.runningApplicationsWithBundleIdentifier(enoughBundleID).count) !== 0) {
    throw new Error('Enough has not finished quitting.');
}

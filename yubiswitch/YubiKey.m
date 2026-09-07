//  YubiKey.m
//  yubiswitch

/*
 yubiswitch - enable/disable yubikey
 Copyright (C) 2013-2015  Angelo "pallotron" Failla <pallotron@freaknet.org>

 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#import "YubiKey.h"
// This class is responsible for communicating with the helper process, which
// itself controls the USB device

#include <IOKit/hid/IOHIDManager.h>

@interface YubiKey ()

- (BOOL)action:(NSString *)action
       vendorID:(NSString *)vendorID
     productIDs:(NSString *)productIDs;
- (void)registerKeyRemovalWithVendorID:(NSString *)vendorID
                            productIDs:(NSString *)productIDs;

@end

@implementation YubiKey

- (id)init {
    if (self = [super init]) {
        // Listen to notifications with name "changeDefaultsPrefs" and associate
        // notificationReloadHandler to it, this is the mechanism used to
        // communicate to this that UserDefaults preferences have changed,
        // typically when user hits the OK button in the Preference window.
        [[NSNotificationCenter defaultCenter]
         addObserver:self
         selector:@selector(notificationReloadHandler:)
         name:@"changeDefaultsPrefs"
         object:nil];
        if (!AXIsProcessTrusted()) {
            [self raiseAlertWindow:@"yubiswitch requires accessibility access to function. Please enable it in the Security and Privacy prefpane. Taking you there now."];
            NSString* prefPage = @"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility";
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:prefPage]];
        }

        if ([self needToInstallHelper:@"com.pallotron.yubiswitch.helper"]) {
            NSError *error = nil;
            if (![self blessHelperWithLabel:@"com.pallotron.yubiswitch.helper"
                                      error:&error]) {
                [self raiseAlertWindow:
                 [NSString stringWithFormat:@"Failed to bless helper. Error: %@",
                  error]];
                exit(EXIT_FAILURE);
            }
        }
        [self disable];
        [self registerKeyRemoval];
    }
    return self;

}

- (BOOL)needToInstallHelper:(NSString*) label {

    NSDictionary* installedHelperJobData =
    (NSDictionary*)CFBridgingRelease(SMJobCopyDictionary(kSMDomainSystemLaunchd, (__bridge CFStringRef)label));
    NSLog(@"Helper information: %@", installedHelperJobData);

    NSString* installedPath = nil;
    NSArray* programArguments = [installedHelperJobData objectForKey:@"ProgramArguments"];
    if ([programArguments isKindOfClass:[NSArray class]] && [programArguments count] > 0) {
        installedPath = [programArguments objectAtIndex:0];
    }

    // On newer macOS versions SMJobCopyDictionary may return nil for this helper.
    // In that case, check the canonical blessed helper path directly.
    if (![installedPath isKindOfClass:[NSString class]] || [installedPath length] == 0) {
        installedPath = [@"/Library/PrivilegedHelperTools" stringByAppendingPathComponent:label];
        NSLog(@"Falling back to helper path check: %@", installedPath);
    }

    NSURL* installedPathURL = [NSURL fileURLWithPath:installedPath];
    NSDictionary* installedInfoPlist =
        (NSDictionary*)CFBridgingRelease(CFBundleCopyInfoDictionaryForURL((CFURLRef)installedPathURL));
    NSString* installedBundleVersion = [installedInfoPlist objectForKey:@"CFBundleVersion"];
    if (![installedBundleVersion isKindOfClass:[NSString class]] || [installedBundleVersion length] == 0) {
        return YES;
    }

    NSBundle* appBundle = [NSBundle mainBundle];
    NSURL* appBundleURL = [appBundle bundleURL];
    NSURL* currentHelperToolURL =
        [appBundleURL URLByAppendingPathComponent:
         @"Contents/Library/LaunchServices/com.pallotron.yubiswitch.helper"];
    NSDictionary* currentInfoPlist =
        (NSDictionary*)CFBridgingRelease(CFBundleCopyInfoDictionaryForURL((CFURLRef)currentHelperToolURL));
    NSString* currentBundleVersion = [currentInfoPlist objectForKey:@"CFBundleVersion"];
    if (![currentBundleVersion isKindOfClass:[NSString class]] || [currentBundleVersion length] == 0) {
        return YES;
    }

    NSLog(@"helper installedVersion: %@", installedBundleVersion);
    NSLog(@"helper currentVersion: %@", currentBundleVersion);
    if (![currentBundleVersion isEqualToString:installedBundleVersion]) {
        return YES;
    }

    // Verify the LaunchDaemon plist is owned by root. A stale plist with wrong
    // ownership will cause launchctl bootstrap to fail with an I/O error.
    NSString *plistPath = [NSString stringWithFormat:@"/Library/LaunchDaemons/%@.plist", label];
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:plistPath error:nil];
    if (attrs && [[attrs fileOwnerAccountName] isEqualToString:@"root"] == NO) {
        NSLog(@"LaunchDaemon plist has wrong ownership, re-blessing helper");
        return YES;
    }

    return NO;
}

- (BOOL)blessHelperWithLabel:(NSString *)label error:(NSError **)error {

    BOOL result = NO;

    AuthorizationItem authItem = {kSMRightBlessPrivilegedHelper, 0, NULL, 0};
    AuthorizationRights authRights = {1, &authItem};
    AuthorizationFlags flags =
    kAuthorizationFlagDefaults | kAuthorizationFlagInteractionAllowed |
    kAuthorizationFlagPreAuthorize | kAuthorizationFlagExtendRights;
    AuthorizationRef authRef = NULL;

    /* Obtain the right to install privileged helper tools
     * (kSMRightBlessPrivilegedHelper). */
    OSStatus status = AuthorizationCreate(
                                          &authRights, kAuthorizationEmptyEnvironment, flags, &authRef);
    if (status != errAuthorizationSuccess) {
        NSLog(@"Failed to bless helper");
    } else {
        // Remove a stale LaunchDaemon plist before re-blessing. A plist with
        // wrong ownership (e.g. left over from a previous install) will cause
        // launchctl bootstrap to fail with an I/O error. We use the
        // AuthorizationRef we already hold to perform a privileged removal.
        NSString *plistPath = [NSString stringWithFormat:
                               @"/Library/LaunchDaemons/%@.plist", label];
        char *rmArgs[] = {"-f", (char *)[plistPath fileSystemRepresentation], NULL};
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        AuthorizationExecuteWithPrivileges(authRef, "/bin/rm",
                                           kAuthorizationFlagDefaults, rmArgs, NULL);
#pragma clang diagnostic pop

        /* This does all the work of verifying the helper tool against the
         * application
         * and vice-versa. Once verification has passed, the embedded launchd.plist
         * is extracted and placed in /Library/LaunchDaemons and then loaded. The
         * executable is placed in /Library/PrivilegedHelperTools.
         */
        result = SMJobBless(kSMDomainSystemLaunchd, (__bridge CFStringRef)label,
                            authRef, (void *)error);
    }

    return result;
}

- (void)raiseAlertWindow:(NSString *)message {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"OK"];
    [alert setAlertStyle:NSWarningAlertStyle];
    [alert setMessageText:message];
    [alert runModal];
}

- (void)notificationReloadHandler:(NSNotification *)notification {
    if ([[notification name] isEqualToString:@"changeDefaultsPrefs"]) {
        NSDictionary *preferences = [notification userInfo];
        NSString *vendorID = [preferences objectForKey:@"hotKeyVendorID"];
        NSString *productIDs = [preferences objectForKey:@"hotKeyProductID"];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        if (vendorID == nil) {
            vendorID = [defaults stringForKey:@"hotKeyVendorID"];
        }
        if (productIDs == nil) {
            productIDs = [defaults stringForKey:@"hotKeyProductID"];
        }

        // Rebuild the unplug matcher and reset the helper so devices seized by
        // the old matcher are released before the new filter is applied.
        BOOL wasSuspended = suspend;
        [self registerKeyRemovalWithVendorID:vendorID productIDs:productIDs];
        [self action:@"enable" vendorID:vendorID productIDs:productIDs];
        if (wasSuspended) {
            [self action:@"disable" vendorID:vendorID productIDs:productIDs];
        }
    }
}

// Parse the hotKeyProductID preference into a list of product IDs.
// The field accepts a comma-separated list of hex IDs (e.g. "0x0010,0x0407").
// An empty/blank string (or one with no valid tokens) yields an empty array,
// which downstream means "match all products for the vendor".
- (NSArray<NSNumber *> *)parseProductIDs:(NSString *)s {
    NSMutableArray<NSNumber *> *result = [NSMutableArray array];
    if (s == nil) {
        return result;
    }
    for (NSString *token in [s componentsSeparatedByString:@","]) {
        NSString *trimmed = [token stringByTrimmingCharactersInSet:
                             [NSCharacterSet whitespaceCharacterSet]];
        if ([trimmed length] == 0) {
            continue;
        }
        unsigned int value = 0;
        if ([[NSScanner scannerWithString:trimmed] scanHexInt:&value] && value != 0) {
            [result addObject:@(value)];
        }
    }
    return result;
}

- (BOOL)action:(NSString *)action {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [self action:action
               vendorID:[defaults stringForKey:@"hotKeyVendorID"]
             productIDs:[defaults stringForKey:@"hotKeyProductID"]];
}

- (BOOL)action:(NSString *)action
       vendorID:(NSString *)vendorID
     productIDs:(NSString *)productIDValues {
    xpc_connection_t connection = xpc_connection_create_mach_service(
        "com.pallotron.yubiswitch.helper", NULL,
        XPC_CONNECTION_MACH_SERVICE_PRIVILEGED);

    if (!connection) {
        [self raiseAlertWindow:@"Failed to create XPC connection with helper"];
        exit(EXIT_FAILURE);
    }

    xpc_connection_set_event_handler(connection, ^(xpc_object_t event) {
        xpc_type_t type = xpc_get_type(event);
        if (type == XPC_TYPE_ERROR) {
            if (event == XPC_ERROR_CONNECTION_INTERRUPTED) {
                // probably helper has been killed, relaunching it?
                NSLog(@"XPC connection interupted.");
            } else if (event == XPC_ERROR_CONNECTION_INVALID) {
                NSLog(@"XPC connection invalid, releasing.");
            } else {
                NSLog(@"Unexpected XPC connection error.");
            }
        } else {
            NSLog(@"Unexpected XPC connection event.");
        }
    });

    unsigned int idVendor = 0;
    [[NSScanner scannerWithString:vendorID] scanHexInt:&idVendor];

    NSArray<NSNumber *> *productIDs = [self parseProductIDs:productIDValues];

    xpc_connection_resume(connection);
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_int64(message, "idVendor", idVendor);
    // Send the list of product IDs (empty = match all products for the vendor).
    xpc_object_t products = xpc_array_create(NULL, 0);
    for (NSNumber *pid in productIDs) {
        xpc_array_set_int64(products, XPC_ARRAY_APPEND, [pid longLongValue]);
    }
    xpc_dictionary_set_value(message, "idProducts", products);
    if ([action isEqualToString:@"enable"]) {
        xpc_dictionary_set_int64(message, "request", 1);
        suspend = FALSE;
    } else if ([action isEqualToString:@"disable"]) {
        xpc_dictionary_set_int64(message, "request", 0);
        suspend = TRUE;
    }
    const char *response = NULL;
    xpc_object_t event = xpc_connection_send_message_with_reply_sync(connection, message);
    response = xpc_dictionary_get_string(event, "reply");
    if (response == NULL) {
        return FALSE;
    }
    return TRUE;
    // NSAppleScript *lockScript = [[NSAppleScript alloc]
    // initWithSource:@"activate application \"ScreenSaverEngine\""];
    // [lockScript executeAndReturnError:nil];
}

- (BOOL)state {
    return suspend;
}
- (BOOL)enable {
    return [self action:@"enable"];
}

- (BOOL)disable {
    return [self action:@"disable"];
}


// deal with disconnection of device from usb port

static void handle_removal_callback(void *context, IOReturn result,
                                    void *sender, IOHIDDeviceRef device) {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"lockWhenUnplugged"]) {
        NSLog(@"YubiKey removed, locking computer");
        NSAppleScript *lockScript =
        [[NSAppleScript alloc]
         initWithSource:@"tell application \"System Events\" to tell current screen saver to start"];
        [lockScript executeAndReturnError:nil];
    }
}

static void match_set(CFMutableDictionaryRef dict, CFStringRef key, int value) {
    CFNumberRef number = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &value);
    CFDictionarySetValue(dict, key, number);
    CFRelease(number);
}

// Build a match dictionary for the OTP keyboard interface. A productID of 0
// omits the product key, matching every product for the vendor.
static CFDictionaryRef create_match_dict(int vendorID, int productID) {
    CFMutableDictionaryRef match = CFDictionaryCreateMutable(kCFAllocatorDefault,
                                                             0,
                                                             &kCFTypeDictionaryKeyCallBacks,
                                                             &kCFTypeDictionaryValueCallBacks);
    match_set(match, CFSTR(kIOHIDVendorIDKey), vendorID);
    if (productID) {
        match_set(match, CFSTR(kIOHIDProductIDKey), productID);
    }
    match_set(match, CFSTR(kIOHIDDeviceUsagePageKey), 1);
    match_set(match, CFSTR(kIOHIDDeviceUsageKey), 6);
    return match;
}

- (void)registerKeyRemoval {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [self registerKeyRemovalWithVendorID:[defaults stringForKey:@"hotKeyVendorID"]
                              productIDs:[defaults stringForKey:@"hotKeyProductID"]];
}

- (void)registerKeyRemovalWithVendorID:(NSString *)vendorID
                            productIDs:(NSString *)productIDValues {

    // Tear down any previously-created manager so preference changes don't stack
    // duplicate removal callbacks or leak managers.
    if (removalManager != NULL) {
        IOHIDManagerUnscheduleFromRunLoop(removalManager, CFRunLoopGetMain(),
                                          kCFRunLoopCommonModes);
        IOHIDManagerClose(removalManager, kIOHIDOptionsTypeNone);
        CFRelease(removalManager);
        removalManager = NULL;
    }

    unsigned int idVendor = 0;
    [[NSScanner scannerWithString:vendorID] scanHexInt:&idVendor];

    NSArray<NSNumber *> *productIDs = [self parseProductIDs:productIDValues];

    removalManager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);

    // OR-match one dictionary per product ID, or a single vendor-only dictionary
    // when no specific product IDs are configured (match all Yubico devices).
    CFMutableArrayRef matches =
        CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
    if ([productIDs count] == 0) {
        CFDictionaryRef match = create_match_dict((int)idVendor, 0);
        CFArrayAppendValue(matches, match);
        CFRelease(match);
    } else {
        for (NSNumber *pid in productIDs) {
            CFDictionaryRef match = create_match_dict((int)idVendor, [pid intValue]);
            CFArrayAppendValue(matches, match);
            CFRelease(match);
        }
    }

    IOHIDManagerScheduleWithRunLoop(removalManager, CFRunLoopGetMain(), kCFRunLoopCommonModes);
    IOHIDManagerSetDeviceMatchingMultiple(removalManager, matches);
    IOHIDManagerRegisterDeviceRemovalCallback(removalManager, handle_removal_callback, NULL);

    CFRelease(matches);
}

@end

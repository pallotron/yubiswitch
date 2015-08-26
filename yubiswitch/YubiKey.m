//  YubiKey.m
//  yubiswitch

/*
 yubiswitch - enable/disable yubikey
 Copyright (C) 2013  Angelo "pallotron" Failla <pallotron@freaknet.org>

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
    }
    return self;

}

- (BOOL)needToInstallHelper:(NSString*) label {

    NSDictionary* installedHelperJobData =
    (__bridge NSDictionary*) SMJobCopyDictionary(kSMDomainSystemLaunchd, (__bridge CFStringRef)label);
    NSLog(@"Helper information:     %@", installedHelperJobData);

    if (installedHelperJobData) {
        NSString* installedPath = [[installedHelperJobData objectForKey:@"ProgramArguments"] objectAtIndex:0];
        NSURL* installedPathURL = [NSURL fileURLWithPath:installedPath];

        NSDictionary*  installedInfoPlist =
            (NSDictionary*)CFBridgingRelease(CFBundleCopyInfoDictionaryForURL( (CFURLRef)installedPathURL ));
        NSString* installedBundleVersion  = [installedInfoPlist objectForKey:@"CFBundleVersion"];
        NSInteger installedVersion        = [installedBundleVersion integerValue];

        NSLog(@"helper installedVersion: %ld", (long)installedVersion);

        NSBundle* appBundle = [NSBundle mainBundle];
        NSURL* appBundleURL = [appBundle bundleURL];

        NSLog(@"helper appBundleURL: %@", appBundleURL);

        NSURL*  currentHelperToolURL =
            [appBundleURL URLByAppendingPathComponent:
             @"Contents/Library/LaunchServices/com.pallotron.yubiswitch.helper"];
        NSDictionary*  currentInfoPlist =
            (NSDictionary*)CFBridgingRelease(CFBundleCopyInfoDictionaryForURL( (CFURLRef)currentHelperToolURL ));
        NSString* currentBundleVersion = [currentInfoPlist objectForKey:@"CFBundleVersion"];
        NSInteger currentVersion = [currentBundleVersion integerValue];

        NSLog( @"helper currentVersion: %ld", (long)currentVersion );
        return (currentVersion != installedVersion);
    }
    return YES;
    
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
        [self disable];
    }
}

- (BOOL)action:(NSString *)action {
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

    NSString *value =
    [[NSUserDefaults standardUserDefaults] stringForKey:@"hotKeyVendorID"];
    unsigned int idVendor = 0;
    [[NSScanner scannerWithString:value] scanHexInt:&idVendor];
    unsigned int idProduct = 0;
    value =
    [[NSUserDefaults standardUserDefaults] stringForKey:@"hotKeyProductID"];
    [[NSScanner scannerWithString:value] scanHexInt:&idProduct];

    xpc_connection_resume(connection);
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_int64(message, "idVendor", idVendor);
    xpc_dictionary_set_int64(message, "idProduct", idProduct);
    if ([action isEqualToString:@"enable"]) {
        xpc_dictionary_set_int64(message, "request", 1);
        suspend = FALSE;
    } else if ([action isEqualToString:@"disable"]) {
        xpc_dictionary_set_int64(message, "request", 0);
        suspend = TRUE;
    }
    __block const char *response;
    xpc_connection_send_message_with_reply(
                                           connection, message, dispatch_get_main_queue(), ^(xpc_object_t event) {
                                               response = xpc_dictionary_get_string(event, "reply");
                                           });
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

@end

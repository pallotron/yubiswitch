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
#include <IOKit/hid/IOHIDDevice.h>

// This class is responsible for communicating with the USB device.

@implementation YubiKey

// TODO: http://stackoverflow.com/questions/11628195/iokit-device-adding-removal-notifications-only-fire-once/16488337#16488337

-(id)init {
    if (self = [super init]) {
        hidDevice = NULL;
        [self suspendDevice];
        suspend = TRUE;
        // Listen to notifications with name "changeDefaultsPrefs" and associate
        // notificationReloadHandler to it, this is the mechanism used to
        // communicate to this that UserDefaults preferences have changed,
        // typically when user hits the OK button in the Preference window.
        [[NSNotificationCenter defaultCenter]
         addObserver:self selector:@selector(notificationReloadHandler:)
         name:@"changeDefaultsPrefs" object:nil];
    }
    return self;
}

-(void)raiseAlertWindow:(NSString*) message {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"OK"];
    [alert setAlertStyle:NSWarningAlertStyle];
    [alert setMessageText:message];
    [alert runModal];
}

-(void)notificationReloadHandler:(NSNotification *) notification {
    if ([[notification name] isEqualToString:@"changeDefaultsPrefs"]) {
        [self setHID:NULL];
    }
}

/*
static void got_hid_report(void *context, IOReturn result, void *sender,
                           IOHIDReportType type, uint32_t reportID, uint8_t *report,
                           CFIndex reportLength)
{
}
*/

static void match_callback(void *context, IOReturn result,
                           void *sender, IOHIDDeviceRef device)
{
    YubiKey *self = (__bridge YubiKey *)context;
    
    IOReturn r = IOHIDDeviceOpen(device, kIOHIDOptionsTypeSeizeDevice);
    if (r == kIOReturnSuccess) {
        NSLog(@"Openned HID device: %p", device);
        [self setHID:device];
        /*
        IOHIDDeviceRegisterInputReportCallback(
                                               device,
                                               [self getScratch],
                                               1024,
                                               got_hid_report,
                                               (void*)context);
         */
    }
    else {
        NSLog(@"Failed to open HID device: %08x", r);
    }
}
    
static void match_set(CFMutableDictionaryRef dict, CFStringRef key, int value) {
    CFNumberRef number = CFNumberCreate(
                                        kCFAllocatorDefault, kCFNumberIntType, &value);
    CFDictionarySetValue(dict, key, number);
    CFRelease(number);
}

static CFDictionaryRef matching_dictionary_create(int vendorID,
                                                  int productID,
                                                  int usagePage,
                                                  int usage)
{
    CFMutableDictionaryRef match = CFDictionaryCreateMutable(
                                                             kCFAllocatorDefault, 0,
                                                             &kCFTypeDictionaryKeyCallBacks,
                                                             &kCFTypeDictionaryValueCallBacks);
    
    if (vendorID) {
        match_set(match, CFSTR(kIOHIDVendorIDKey), vendorID);
    }
    if (productID) {
        match_set(match, CFSTR(kIOHIDProductIDKey), productID);
    }
    if (usagePage) {
        match_set(match, CFSTR(kIOHIDDeviceUsagePageKey), usagePage);
    }
    if (usage) {
        match_set(match, CFSTR(kIOHIDDeviceUsageKey), usage);
    }
    
    return match;
}

-(void)setHID:(IOHIDDeviceRef)dev {
    if(hidDevice != NULL) {
        IOHIDDeviceClose(hidDevice, kIOHIDOptionsTypeNone);
    }
    hidDevice = dev;
    suspend = (hidDevice != NULL);
}

-(uint8_t *)getScratch { return scratch; }

-(void)suspendDevice {
    NSString* value = [[NSUserDefaults standardUserDefaults]
                       stringForKey:@"hotKeyVendorID"];
    unsigned int idVendor = 0;
    [[NSScanner scannerWithString:value] scanHexInt:&idVendor];
    unsigned int idProduct = 0;
    value = [[NSUserDefaults standardUserDefaults]
             stringForKey:@"hotKeyProductID"];
    [[NSScanner scannerWithString:value] scanHexInt:&idProduct];

    IOHIDManagerRef hidManager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
    
    IOHIDManagerRegisterDeviceMatchingCallback(hidManager, match_callback, (__bridge void *)(self));
    
    IOHIDManagerScheduleWithRunLoop(hidManager, CFRunLoopGetMain(), kCFRunLoopCommonModes);
    
    // all keyboards
    CFDictionaryRef match = matching_dictionary_create(idVendor, idProduct, 1, 6);

    IOHIDManagerSetDeviceMatching(hidManager, match);
    CFRelease(match);
}

-(BOOL)action:(NSString *)action {
    BOOL oldSuspend = suspend;
    if ([action isEqualToString:@"enable"]) {
        if(oldSuspend == FALSE) return TRUE;
        [self setHID:NULL];
    } else if ([action isEqualToString:@"disable"]) {
        if(oldSuspend == TRUE) return TRUE;
        [self suspendDevice];
    }
    if(oldSuspend == suspend) {
        NSLog(@"Suspension change hasn't happened yet...");
        return FALSE;
    }
    return TRUE;
}

-(BOOL)enable {
    return [self action:@"enable"];
}

-(BOOL)disable {
    return [self action:@"disable"];
}

@end

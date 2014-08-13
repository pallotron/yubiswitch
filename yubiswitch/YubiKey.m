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

// This class is responsible for communicating with the USB device.

@implementation YubiKey

// TODO: http://stackoverflow.com/questions/11628195/iokit-device-adding-removal-notifications-only-fire-once/16488337#16488337

-(id)init {
    if (self = [super init]) {
        usbDevice = NULL;
        [self findDevice];
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
        if (usbDevice != NULL) {
            (*usbDevice)->USBDeviceClose(usbDevice);
            usbDevice = NULL;
        }
        [self findDevice];
    }
}

-(void)findDevice {
    
    CFMutableDictionaryRef matchingDictionary = NULL;
    NSString* value = [[NSUserDefaults standardUserDefaults]
                       stringForKey:@"hotKeyVendorID"];
    unsigned int idVendor = 0;
    [[NSScanner scannerWithString:value] scanHexInt:&idVendor];
    unsigned int idProduct = 0;
    value = [[NSUserDefaults standardUserDefaults]
             stringForKey:@"hotKeyProductID"];
    [[NSScanner scannerWithString:value] scanHexInt:&idProduct];
    io_iterator_t iterator = 0;
    io_service_t usbRef;
    SInt32 score;
    IOCFPlugInInterface** plugin;
    
    // search for device in the I/O registry, look for given Vendor ID
    // and Product ID.
    matchingDictionary = IOServiceMatching(kIOUSBDeviceClassName);
    CFDictionaryAddValue(matchingDictionary,
                         CFSTR(kUSBVendorID),
                         CFNumberCreate(kCFAllocatorDefault,
                                        kCFNumberSInt32Type, &idVendor));
    CFDictionaryAddValue(matchingDictionary,
                         CFSTR(kUSBProductID),
                         CFNumberCreate(kCFAllocatorDefault,
                                        kCFNumberSInt32Type, &idProduct));
    IOServiceGetMatchingServices(kIOMasterPortDefault,
                                 matchingDictionary, &iterator);
    usbRef = IOIteratorNext(iterator);
    if (usbRef == 0) {
        [self raiseAlertWindow:@"Can't find YubiKey. "
         "Check if it's plugged in then retry."];
        usbDevice = NULL;
        return;
    }
    // TODO: deal with multiple retries?
    IOObjectRelease(iterator);
    
    // Get device interface
    IOCreatePlugInInterfaceForService(usbRef, kIOUSBDeviceUserClientTypeID,
                                      kIOCFPlugInInterfaceID, &plugin, &score);
    IOObjectRelease(usbRef);
    // now hat we have intermediate interface, specify type of device
    (*plugin)->QueryInterface(plugin,
                              CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID),
                              (LPVOID)&usbDevice);
    (*plugin)->Release(plugin);
}

-(BOOL)action:(NSString *)action {
    if (usbDevice == NULL) {
        [self findDevice];
    }
    if (usbDevice != NULL) {
        IOReturn ret;
        ret = (*usbDevice)->USBDeviceOpen(usbDevice);
        if (ret == kIOReturnSuccess) {
            
        } else if ( ret == kIOReturnExclusiveAccess) {}
        else {
            [self raiseAlertWindow:@"Can't open Yubikey device! Check if"
             " it's plugged in then retry."];
            (*usbDevice)->USBDeviceClose(usbDevice);
            usbDevice = NULL;
            return FALSE;
        }
        UInt8 config = 0;
        if ([action isEqualToString:@"enable"]) {
            config = 1;
        } else if ([action isEqualToString:@"disable"]) {
            config = 0;
        }
        (*usbDevice)->SetConfiguration(usbDevice, config);
        (*usbDevice)->USBDeviceClose(usbDevice);
    } else {
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

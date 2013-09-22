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

@implementation YubiKey

-(id)init {
    if (self = [super init]) {
        usbDevice = NULL;
        [self findDevice];
    }
    return self;
}

-(void)raiseAlertWindowAndQuit:(NSString*) message {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"Quit"];
    [alert setAlertStyle:NSWarningAlertStyle];
    [alert setMessageText:message];
    [alert runModal];
    [[NSApplication sharedApplication] terminate:self];
}

-(void)findDevice {
    
    CFMutableDictionaryRef matchingDictionary = NULL;
    SInt32 idVendor = 0x1050;
    SInt32 idProduct = 0x0010;
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
        [self raiseAlertWindowAndQuit:@"Can'f find yubiKey. "
         "Check if it's plugged in then launch me again"];
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

-(void)action:(NSString *)action {
    IOReturn ret;
    ret = (*usbDevice)->USBDeviceOpen(usbDevice);
    if (ret == kIOReturnSuccess) {
        
    } else if ( ret == kIOReturnExclusiveAccess) {}
    else {
        [self raiseAlertWindowAndQuit:@"Can't open Yubikey device!"];
    }
    UInt8 config = 0;
    if ([action isEqualToString:@"enable"]) {
        config = 1;
    } else if ([action isEqualToString:@"disable"]) {
        config = 0;
    }
    (*usbDevice)->SetConfiguration(usbDevice, config);
    (*usbDevice)->USBDeviceClose(usbDevice);
}

-(void)enable {
    [self action:@"enable"];
}

-(void)disable {
    [self action:@"disable"];
}

@end

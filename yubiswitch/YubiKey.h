//
//  YubiKey.h
//  yubiswitch
//
//  Created by Angelo Failla on 9/20/13.
//  Copyright (c) 2013 Angelo Failla. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/usb/IOUSBLib.h>
#include <IOKit/usb/USBSpec.h>

@interface YubiKey : NSObject {
    IOUSBDeviceInterface** usbDevice;
}

-(void)findDevice;
-(id)init;
-(void)action:(NSString *)action;
-(void)enable;
-(void)disable;

@end

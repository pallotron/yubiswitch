//
//  YubiKey.h
//  yubiswitch
//
//  Created by Angelo Failla on 9/20/13.
//  Copyright (c) 2013 Angelo Failla. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <IOKit/usb/IOUSBLib.h>

@interface YubiKey : NSObject {
    int idVendor;
    int idProduct;
}

-(id)init;
-(void)enable;
-(void)disable;

@end

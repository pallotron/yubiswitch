//
//  YubiKey.m
//  yubiswitch
//
//  Created by Angelo Failla on 9/20/13.
//  Copyright (c) 2013 Angelo Failla. All rights reserved.
//

#import "YubiKey.h"

@implementation YubiKey

-(id)init {
    if (self = [super init]) {
        idVendor = 0x1050;
        idProduct = 0x0010;
    }
    return self;
    
}

-(void)enable {
    NSLog(@"enable");
}

-(void)disable {
    NSLog(@"disabled");
}

@end

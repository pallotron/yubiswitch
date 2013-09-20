//
//  YubiKey.h
//  yubiswitch
//
//  Created by Angelo Failla on 9/20/13.
//  Copyright (c) 2013 Angelo Failla. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface YubiKey : NSObject {
    bool isEnabled;
}

-(void)findDevice;
-(void)enable;
-(void)disable;

@end

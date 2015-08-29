//
//  ComputerStateMonitor.m
//  yubiswitch
//
//  Created by Angelo Failla on 8/29/15.
//  Copyright (c) 2015 Angelo Failla. All rights reserved.
//

#import "ComputerStateMonitor.h"
#import <Foundation/NSDistributedNotificationCenter.h>

@implementation ComputerStateMonitor

- (id)initWithYubiKey:(YubiKey *)yubikey {
    if ( self = [super init] ) {
        if (yubikey) {
            yk = yubikey;

            NSDistributedNotificationCenter * center = [NSDistributedNotificationCenter defaultCenter];

            [center addObserver: self
                       selector:    @selector(receive:)
                           name:        @"com.apple.screenIsLocked"
                         object:      nil
             ];
            [center addObserver: self
                       selector:    @selector(receive:)
                           name:        @"com.apple.screenIsUnlocked"
                         object:      nil
             ];
            return self;
        }
        else {
            return nil;
        }
    } else {
        return nil;
    }
}

-(void) receive: (NSNotification*) notification {
    BOOL activated =
        [[NSUserDefaults standardUserDefaults] boolForKey:@"disableAtLockSleep"];

    if (!activated) {
        return;
    }

    NSLog(@"Received notification %s", [[notification name] UTF8String]);

    if ([[notification name]  isEqual:@"com.apple.screenIsLocked"]) {
        NSLog(@"Screen is locked, renabling yubikey");
        [yk enable];
    }

    if ([[notification name]  isEqual:@"com.apple.screenIsUnlocked"]) {
        NSLog(@"Screen is unlocked, disabling yubikey");
        [yk disable];
    }
}

@end

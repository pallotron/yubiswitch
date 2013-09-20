//
//  AppDelegate.h
//  yubiswitch
//
//  Created by Angelo Failla on 9/20/13.
//  Copyright (c) 2013 Angelo Failla. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "YubiKey.h"

@interface AppDelegate : NSObject <NSApplicationDelegate> {
    IBOutlet NSMenu *statusMenu;
    NSStatusItem * statusItem;
    bool isEnabled;
    YubiKey* yk;
}

@property (assign) IBOutlet NSWindow *window;
-(IBAction)toggle:(id)sender;
-(IBAction)quit:(id)sender;

@end

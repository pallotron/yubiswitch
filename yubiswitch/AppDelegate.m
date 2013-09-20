//
//  AppDelegate.m
//  yubiswitch
//
//  Created by Angelo Failla on 9/20/13.
//  Copyright (c) 2013 Angelo Failla. All rights reserved.
//

#import "AppDelegate.h"

@implementation AppDelegate

@synthesize window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    NSLog(@"test");
}

-(void)awakeFromNib {
    statusItem = [[NSStatusBar systemStatusBar]
                  statusItemWithLength:NSVariableStatusItemLength];
    [statusItem setMenu:statusMenu];
    [statusItem setHighlightMode:YES];
    [statusItem setImage:[NSImage imageNamed:@"ico_disabled"]];
    [statusItem setToolTip:@"YubiKey disabled"];
    isEnabled = false;
    yk = [[YubiKey alloc] init];
}

-(IBAction)toggle:(id)sender {
    if (isEnabled == true) {
        [yk disable];
        [statusItem setToolTip:(@"Yubikey disabled")];
        [statusItem setImage:[NSImage imageNamed:@"ico_disabled"]];
        isEnabled = false;
    } else {
        [yk enable];
        [statusItem setToolTip:(@"Yubikey enabled")];
        [statusItem setImage:[NSImage imageNamed:@"ico_enabled"]];
        isEnabled = true;
    }
}

-(IBAction)quit:(id)sender {
    [yk enable];
    [[NSApplication sharedApplication] terminate:self];
}

@end

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
    yk = [[YubiKey alloc] init];
    [yk disable];
}

-(void)awakeFromNib {
    
    statusItem = [[NSStatusBar systemStatusBar]
                  statusItemWithLength:NSVariableStatusItemLength];
    [statusItem setMenu:statusMenu];
    [statusItem setHighlightMode:YES];
    [statusItem setImage:[NSImage imageNamed:@"ico_disabled"]];
    [statusItem setToolTip:@"YubiKey disabled"];
    
    isEnabled = false;
    
    // enable global hotkey
    EventHotKeyRef hotKeyRef;
    EventHotKeyID hotKeyID;
    EventTypeSpec eventType;
    eventType.eventClass=kEventClassKeyboard;
    eventType.eventKind=kEventHotKeyPressed;
    hotKeyID.signature = 'ybk1';
    hotKeyID.id = 1;
    /* Given that hotKeyHandler is a C function in the Carbon domain and
     Objective-C is a superset of C we need to cast self using __bridge so
     that we can then use the AppDelegate object from within the handler
     function...
     */
    InstallApplicationEventHandler(&hotKeyHandler, 1, &eventType,
                                   (__bridge void *) self, NULL);
    RegisterEventHotKey(16, cmdKey, hotKeyID,
                        GetApplicationEventTarget(), 0,
                        &hotKeyRef);
}

OSStatus hotKeyHandler(EventHandlerCallRef nextHandler,
                       EventRef anEvent, void *userData) {
    AppDelegate *a;
    // convert void * to AppDelegate pointer and then use the Objective-C method
    a = (__bridge AppDelegate *) userData;
    [a toggle:NULL];
    return noErr;
}

-(IBAction)toggle:(id)sender {
    if (isEnabled == true) {
        [yk disable];
        [statusItem setToolTip:(@"Yubikey disabled")];
        [statusItem setImage:[NSImage imageNamed:@"ico_disabled"]];
        isEnabled = false;
        [[statusMenu itemAtIndex:0] setTitle:(@"Enable YubiKey")];
    } else {
        [yk enable];
        [statusItem setToolTip:(@"Yubikey enabled")];
        [statusItem setImage:[NSImage imageNamed:@"ico_enabled"]];
        isEnabled = true;
        [[statusMenu itemAtIndex:0] setTitle:(@"Disable YubiKey")];

    }
}

-(IBAction)quit:(id)sender {
    [yk enable];
    [[NSApplication sharedApplication] terminate:self];
}

@end

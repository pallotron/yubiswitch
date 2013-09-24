//  AppDelegate.m
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

#import "AppDelegate.h"
#import "AboutWindowController.h"

@implementation AppDelegate
@synthesize window;

-(void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    yk = [[YubiKey alloc] init];
    [yk disable];
    notification = [[NSUserNotification alloc] init];
    [self notify:@"YubiKey disabled"];
    aboutwc = [[AboutWindowController alloc]
               initWithWindowNibName:@"AboutWindowController"];
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
    // register cmd-Y global hotkey
    RegisterEventHotKey(16, cmdKey, hotKeyID,
                        GetApplicationEventTarget(), 0,
                        &hotKeyRef);
}

-(void)notify:(NSString *)msg {
    notification.title = msg;
    [[NSUserNotificationCenter defaultUserNotificationCenter]
     deliverNotification:notification];
}

OSStatus hotKeyHandler(EventHandlerCallRef nextHandler,
                       EventRef anEvent, void *userData) {
    AppDelegate *a;
    // convert void pointer to AppDelegate pointer and then use the
    // Objective-C method
    a = (__bridge AppDelegate *) userData;
    [a toggle:NULL];
    return noErr;
}

-(IBAction)toggle:(id)sender {
    BOOL res;
    if (isEnabled == true) {
        res = [yk disable];
        if (res == TRUE) {
            [statusItem setToolTip:(@"YubiKey disabled")];
            [statusItem setImage:[NSImage imageNamed:@"ico_disabled"]];
            isEnabled = false;
            [[statusMenu itemAtIndex:0] setState:0];
            [self notify:@"YubiKey disabled"];
        }
    } else {
        res = [yk enable];
        if (res == TRUE) {
            [statusItem setToolTip:(@"YubiKey enabled")];
            [statusItem setImage:[NSImage imageNamed:@"ico_enabled"]];
            isEnabled = true;
            [[statusMenu itemAtIndex:0] setState:1];
            [self notify:@"YubiKey enabled"];
        }
    }
}

-(IBAction)about:(id)sender {
    [[aboutwc window] makeKeyAndOrderFront:self];
    [[aboutwc window] setOrderedIndex:0];
    [NSApp activateIgnoringOtherApps:YES];
    [aboutwc showWindow:self];
}

-(IBAction)quit:(id)sender {
    [yk enable];
    [self notify:@"YubiKey enabled"];
    [[NSApplication sharedApplication] terminate:self];
}

@end

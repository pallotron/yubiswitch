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
#import <PTHotKey/PTHotKeyCenter.h>
#import <PTHotKey/PTHotKey+ShortcutRecorder.h>

// This is the main class, responsible for the status bar icon and general
// application behavior

@implementation AppDelegate
@synthesize window;

-(id)init {
    self = [super init];
    if (self) {
        // Set default values for preferences, load it from
        // DefaultPreferences.plist file
        NSString *defaultPrefsFile = [[NSBundle mainBundle]
                                     pathForResource:@"DefaultPreferences"
                                     ofType:@"plist"];
        NSDictionary
            *defaultPrefs = [NSDictionary
                             dictionaryWithContentsOfFile:defaultPrefsFile];
        
        [[NSUserDefaults standardUserDefaults] registerDefaults:defaultPrefs];
    }
    return self;
}

-(void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    yk = [[YubiKey alloc] init];
    [yk disable];
    usernotification = [[NSUserNotification alloc] init];
    [self notify:@"YubiKey disabled"];
    aboutwc = [[AboutWindowController alloc]
               initWithWindowNibName:@"AboutWindowController"];
    prefwc = [[PreferencesController alloc]
              initWithWindowNibName:@"PreferencesController"];
}

-(void)awakeFromNib {
    
    statusItem = [[NSStatusBar systemStatusBar]
                  statusItemWithLength:NSVariableStatusItemLength];
    [statusItem setMenu:statusMenu];
    [statusItem setHighlightMode:YES];
    [statusItem setImage:[NSImage imageNamed:@"ico_disabled"]];
    [statusItem setToolTip:@"YubiKey disabled"];
    
    isEnabled = false;

    // setup observer method, when the global hotkey is changed in the
    // preference controller this method gets notified.
    NSUserDefaultsController *defaults = [NSUserDefaultsController
                                          sharedUserDefaultsController];
    [defaults addObserver:self forKeyPath:@"values.hotkey"
                  options:NSKeyValueObservingOptionInitial context:NULL];
}

-(void)observeValueForKeyPath:(NSString *)aKeyPath ofObject:(id)anObject
                        change:(NSDictionary *)aChange context:(void *)aContext
{
    if ([aKeyPath isEqualToString:@"values.hotkey"]) {
        PTHotKeyCenter *hotKeyCenter = [PTHotKeyCenter sharedCenter];
        PTHotKey *oldHotKey = [hotKeyCenter hotKeyWithIdentifier:aKeyPath];
        [hotKeyCenter unregisterHotKey:oldHotKey];
        
        NSDictionary *newShortcut = [anObject valueForKeyPath:aKeyPath];
        
        if (newShortcut && (NSNull *)newShortcut != [NSNull null]) {
            PTHotKey *newHotKey = [PTHotKey hotKeyWithIdentifier:aKeyPath
                                                    keyCombo:newShortcut
                                                    target:self
                                                    action:@selector(toggle:)];
            [hotKeyCenter registerHotKey:newHotKey];
        }
    }
    else
        [super observeValueForKeyPath:aKeyPath ofObject:anObject change:aChange
                              context:aContext];
}

-(void)notify:(NSString *)msg {
    usernotification.title = msg;
    [[NSUserNotificationCenter defaultUserNotificationCenter]
     deliverNotification:usernotification];
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

-(IBAction)pref:(id)sender {
    [[prefwc window] makeKeyAndOrderFront:self];
    [[prefwc window] setOrderedIndex:0];
    [NSApp activateIgnoringOtherApps:YES];
    [prefwc showWindow:self];
}

-(IBAction)quit:(id)sender {
    [yk enable];
    [self notify:@"YubiKey enabled"];
    [[NSApplication sharedApplication] terminate:self];
}

@end

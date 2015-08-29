//  PreferencesController.m
//  yubiswitch

/*
 yubiswitch - enable/disable yubikey
 Copyright (C) 2013-2015  Angelo "pallotron" Failla <pallotron@freaknet.org>

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

#import "PreferencesController.h"

@interface PreferencesController ()

@end

@implementation PreferencesController {
  SRValidator *_validator;
}

- (void)awakeFromNib {
  [super awakeFromNib];
  controller = [NSUserDefaultsController sharedUserDefaultsController];
  NSString *defaultPrefsFile =
      [[NSBundle mainBundle] pathForResource:@"DefaultPreferences"
                                      ofType:@"plist"];
  NSDictionary *defaultPrefs =
      [NSDictionary dictionaryWithContentsOfFile:defaultPrefsFile];
  [controller setInitialValues:defaultPrefs];
  [controller setAppliesImmediately:FALSE];
  BOOL startAtLogin =
      [[NSUserDefaults standardUserDefaults] boolForKey:@"startAtLogin"];
  [buttonOpenAtLogin setState:startAtLogin];
  [self.hotkeyrecorder bind:NSValueBinding
                   toObject:controller
                withKeyPath:@"values.hotkey"
                    options:nil];
}

- (void)addAppAsLoginItem {
  NSString *appPath = [[NSBundle mainBundle] bundlePath];

  // This will retrieve the path for the application
  // For example, /Applications/test.app
  CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:appPath];

  // Create a reference to the shared file list.
  // We are adding it to the current user only.
  // If we want to add it all users, use
  // kLSSharedFileListGlobalLoginItems instead of
  // kLSSharedFileListSessionLoginItems
  LSSharedFileListRef loginItems =
      LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
  if (loginItems) {
    // Insert an item to the list.
    LSSharedFileListItemRef item = LSSharedFileListInsertItemURL(
        loginItems, kLSSharedFileListItemLast, NULL, NULL, url, NULL, NULL);
    if (item) {
      CFRelease(item);
    }
  }

  CFRelease(loginItems);
}

- (void)deleteAppFromLoginItem {
  NSString *appPath = [[NSBundle mainBundle] bundlePath];

  // This will retrieve the path for the application
  // For example, /Applications/test.app
  CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:appPath];

  // Create a reference to the shared file list.
  LSSharedFileListRef loginItems =
      LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);

  if (loginItems) {
    UInt32 seedValue;
    // Retrieve the list of Login Items and cast them to
    // a NSArray so that it will be easier to iterate.
    NSArray *loginItemsArray = (__bridge NSArray *)LSSharedFileListCopySnapshot(
        loginItems, &seedValue);
    for (int i = 0; i < [loginItemsArray count]; i++) {
      LSSharedFileListItemRef itemRef =
          (__bridge LSSharedFileListItemRef)[loginItemsArray objectAtIndex:i];
      // Resolve the item with URL
      if (LSSharedFileListItemResolve(itemRef, 0, (CFURLRef *)&url, NULL) ==
          noErr) {
        NSString *urlPath = [(__bridge NSURL *)url path];
        if ([urlPath compare:appPath] == NSOrderedSame) {
          LSSharedFileListItemRemove(loginItems, itemRef);
        }
      }
    }
  }
}

- (IBAction)SetDefaultsButton:(id)sender {
  NSString *domainName = [[NSBundle mainBundle] bundleIdentifier];
  [[NSUserDefaults standardUserDefaults]
      removePersistentDomainForName:domainName];
  [self.hotkeyrecorder setObjectValue:nil];
  [controller revertToInitialValues:self];
  [controller setValue:nil forKey:@"values.hotkey"];
}

- (IBAction)OKButton:(id)sender {
  [controller save:self];
  [[NSNotificationCenter defaultCenter]
      postNotificationName:@"changeDefaultsPrefs"
                    object:self];
  bool state = [[buttonOpenAtLogin selectedCell] state];
  if (state == YES) {
    [self addAppAsLoginItem];
  } else {
    [self deleteAppFromLoginItem];
  }
  [[NSUserDefaults standardUserDefaults] setBool:state forKey:@"startAtLogin"];
  [[self window] close];
}

- (IBAction)CancelButton:(id)sender {
  [controller revert:self];
  [[self window] close];
}

@end

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

#include <syslog.h>
#include <xpc/xpc.h>
#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/usb/IOUSBLib.h>
#include <IOKit/usb/USBSpec.h>
#include <IOKit/hid/IOHIDManager.h>
#include <IOKit/hid/IOHIDKeys.h>
#include <IOKit/hid/IOHIDDevice.h>
#include <signal.h>
#import <ServiceManagement/ServiceManagement.h>
#import <Security/Authorization.h>


IOHIDManagerRef hidManager;
IOHIDDeviceRef hidDevice;

static void match_set(CFMutableDictionaryRef dict, CFStringRef key, int value) {
    CFNumberRef number =
    CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &value);
    CFDictionarySetValue(dict, key, number);
    CFRelease(number);
}

static void handle_removal_callback(void *context, IOReturn result,
                                    void *sender, IOHIDDeviceRef device) {
    if (hidDevice != NULL) {
        syslog(LOG_NOTICE, "device unplugged");
        IOHIDDeviceClose(hidDevice, kIOHIDOptionsTypeSeizeDevice);
        hidDevice = NULL;
    }
    if (hidManager != NULL) {
        IOHIDManagerClose(hidManager, kIOHIDOptionsTypeNone);
        hidManager = NULL;
    }

    // lock screen
    // In Objective-C land I would do this below but we are in pure C world here
    // NSAppleScript *lockScript = [[NSAppleScript alloc]
    // initWithSource:@"activate application \"ScreenSaverEngine\""];
    // [lockScript executeAndReturnError:nil];
}

static void match_callback(void *context, IOReturn result, void *sender,
                           IOHIDDeviceRef device) {
    IOReturn r = IOHIDDeviceOpen(device, kIOHIDOptionsTypeSeizeDevice);
    if (r == kIOReturnSuccess) {
        syslog(LOG_NOTICE, "Open'ed HID device");
        hidDevice = device;
    } else {
        syslog(LOG_ALERT, "Failed to open HID device");
    }
}

static CFDictionaryRef matching_dictionary_create(int vendorID, int productID,
                                                  int usagePage, int usage) {
    CFMutableDictionaryRef match =
        CFDictionaryCreateMutable(kCFAllocatorDefault,
                                  0,
                                  &kCFTypeDictionaryKeyCallBacks,
                                  &kCFTypeDictionaryValueCallBacks);

    if (vendorID) {
        match_set(match, CFSTR(kIOHIDVendorIDKey), vendorID);
    }
    if (productID) {
        match_set(match, CFSTR(kIOHIDProductIDKey), productID);
    }
    if (usagePage) {
        match_set(match, CFSTR(kIOHIDDeviceUsagePageKey), usagePage);
    }
    if (usage) {
        match_set(match, CFSTR(kIOHIDDeviceUsageKey), usage);
    }

    return match;
}

static void __XPC_Peer_Event_Handler(xpc_connection_t connection,
                                     xpc_object_t event) {
    xpc_type_t type = xpc_get_type(event);

    if (type == XPC_TYPE_ERROR) {
        if (event == XPC_ERROR_CONNECTION_INVALID) {
            // The client process on the other end of the connection has either
            // crashed or cancelled the connection. After receiving this error,
            // the connection is in an invalid state, and you do not need to
            // call xpc_connection_cancel(). Just tear down any associated state
            // here.
        } else if (event == XPC_ERROR_TERMINATION_IMMINENT) {
            // Handle per-connection termination cleanup.
        }

    } else {
        uint64_t idProduct = xpc_dictionary_get_int64(event, "idProduct");
        uint64_t idVendor = xpc_dictionary_get_int64(event, "idVendor");
        uint64_t action = xpc_dictionary_get_int64(event, "request");
        syslog(LOG_NOTICE,
               "Received message. idProduct: %llu, idVendor: %llu, action: %llu",
               idProduct, idVendor, action);
        if (action == 1) {
            // enable
            if (hidDevice != NULL) {
                IOHIDDeviceClose(hidDevice, kIOHIDOptionsTypeSeizeDevice);
                hidDevice = NULL;
            }
            if (hidManager != NULL) {
                IOHIDManagerClose(hidManager, kIOHIDOptionsTypeNone);
                hidManager = NULL;
            }
        } else {
            // disable
            if (hidManager == NULL) {
                hidManager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
                IOHIDManagerRegisterDeviceMatchingCallback(hidManager, match_callback, NULL);
                IOHIDManagerRegisterDeviceRemovalCallback(hidManager, handle_removal_callback, NULL);
            }
            IOHIDManagerScheduleWithRunLoop(hidManager, CFRunLoopGetMain(), kCFRunLoopCommonModes);
            CFDictionaryRef match =
            matching_dictionary_create((int)idVendor, (int)idProduct, 1, 6);
            IOHIDManagerSetDeviceMatching(hidManager, match);
            CFRelease(match);
        }
        xpc_connection_t remote = xpc_dictionary_get_remote_connection(event);
        xpc_object_t reply = xpc_dictionary_create_reply(event);
        xpc_dictionary_set_string(reply, "reply", "OK");
        xpc_connection_send_message(remote, reply);
        xpc_release(reply);
    }
}

static void __XPC_Connection_Handler(xpc_connection_t connection) {
    xpc_connection_set_event_handler(connection, ^(xpc_object_t event) {
        __XPC_Peer_Event_Handler(connection, event);
    });

    xpc_connection_resume(connection);
}

void signalHandler(int signum) {
    syslog(LOG_NOTICE, "Received signal %d. Cleaning up...", signum);
    if (hidDevice != NULL) {
        IOHIDDeviceClose(hidDevice, kIOHIDOptionsTypeSeizeDevice);
        hidDevice = NULL;
    }
    if (hidManager != NULL) {
        IOHIDManagerClose(hidManager, kIOHIDOptionsTypeNone);
        hidManager = NULL;
    }
}

int main(int argc, const char *argv[]) {
    signal(SIGINT, signalHandler);
    signal(SIGTERM, signalHandler);
    xpc_connection_t service = xpc_connection_create_mach_service("com.pallotron.yubiswitch.helper",
                                                                  dispatch_get_main_queue(),
                                                                  XPC_CONNECTION_MACH_SERVICE_LISTENER);
    
    if (!service) {
        syslog(LOG_CRIT, "Failed to create service.");
        exit(EXIT_FAILURE);
    }
    
    syslog(LOG_NOTICE, "Configuring connection event handler for helper");
    xpc_connection_set_event_handler(service, ^(xpc_object_t connection) {
        __XPC_Connection_Handler(connection);
    });
    
    xpc_connection_resume(service);
    CFRunLoopRun();
    dispatch_main();
    return EXIT_SUCCESS;
}

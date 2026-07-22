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
// Set of currently seized IOHIDDeviceRefs. Using a set (instead of a single
// global) lets us seize and, crucially, release every matching key when several
// Yubico devices are plugged in at once. kCFTypeSetCallBacks retains on add and
// releases on remove, and dedups identical device refs.
CFMutableSetRef seizedDevices;

static void match_set(CFMutableDictionaryRef dict, CFStringRef key, int value) {
    CFNumberRef number = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &value);
    CFDictionarySetValue(dict, key, number);
    CFRelease(number);
}

static void close_device_apply(const void *value, void *context) {
    IOHIDDeviceClose((IOHIDDeviceRef)value, kIOHIDOptionsTypeSeizeDevice);
}

// Release every seized device and empty the set.
static void close_all_seized(void) {
    if (seizedDevices != NULL) {
        CFSetApplyFunction(seizedDevices, close_device_apply, NULL);
        CFSetRemoveAllValues(seizedDevices);
    }
}

static void handle_removal_callback(void *context, IOReturn result,
                                    void *sender, IOHIDDeviceRef device) {
    // Only release the device that was actually unplugged. Leave the manager and
    // any other seized devices in place so remaining keys stay seized and a
    // re-plug of the same product still matches.
    if (seizedDevices != NULL && CFSetContainsValue(seizedDevices, device)) {
        syslog(LOG_NOTICE, "device unplugged");
        IOHIDDeviceClose(device, kIOHIDOptionsTypeSeizeDevice);
        CFSetRemoveValue(seizedDevices, device);
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
        if (seizedDevices == NULL) {
            seizedDevices = CFSetCreateMutable(kCFAllocatorDefault, 0,
                                               &kCFTypeSetCallBacks);
        }
        CFSetAddValue(seizedDevices, device);
    } else {
        syslog(LOG_ALERT, "Failed to open HID device, error: %d", r);
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

// Build the array of matching dictionaries handed to
// IOHIDManagerSetDeviceMatchingMultiple (OR semantics across the array).
// count == 0 means "no specific product IDs": match every product for the
// vendor (a single vendor-only dictionary). Otherwise one dictionary per
// product ID.
static CFArrayRef matching_dictionaries_create(int vendorID, const int *productIDs,
                                               size_t count, int usagePage,
                                               int usage) {
    CFMutableArrayRef matches =
        CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
    if (count == 0) {
        CFDictionaryRef match =
            matching_dictionary_create(vendorID, 0, usagePage, usage);
        CFArrayAppendValue(matches, match);
        CFRelease(match);
    } else {
        for (size_t i = 0; i < count; i++) {
            CFDictionaryRef match =
                matching_dictionary_create(vendorID, productIDs[i], usagePage, usage);
            CFArrayAppendValue(matches, match);
            CFRelease(match);
        }
    }
    return matches;
}

static void __XPC_Peer_Event_Handler(xpc_connection_t connection,
                                     xpc_object_t event) {
    xpc_type_t type = xpc_get_type(event);

    if (type == XPC_TYPE_ERROR) {
        const char *description = xpc_dictionary_get_string(event, XPC_ERROR_KEY_DESCRIPTION);
        syslog(LOG_ALERT, "XPC error: %s", description);
    } else {
        uint64_t idVendor = xpc_dictionary_get_int64(event, "idVendor");
        uint64_t action = xpc_dictionary_get_int64(event, "request");

        // Collect the requested product IDs. Prefer the "idProducts" array; fall
        // back to the legacy single "idProduct" key so an older GUI still works.
        // An empty list means "match all products for the vendor".
        int products[256];
        size_t productCount = 0;
        xpc_object_t idProducts = xpc_dictionary_get_value(event, "idProducts");
        if (idProducts != NULL && xpc_get_type(idProducts) == XPC_TYPE_ARRAY) {
            size_t n = xpc_array_get_count(idProducts);
            for (size_t i = 0; i < n && productCount < 256; i++) {
                products[productCount++] =
                    (int)xpc_array_get_int64(idProducts, i);
            }
        } else {
            uint64_t idProduct = xpc_dictionary_get_int64(event, "idProduct");
            if (idProduct != 0) {
                products[productCount++] = (int)idProduct;
            }
        }
        syslog(LOG_NOTICE,
               "Received message. idVendor: %llu, product count: %zu, action: %llu",
               idVendor, productCount, action);
        if (action == 1) {
            // enable: release every seized device and tear down the manager
            close_all_seized();
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
                IOHIDManagerScheduleWithRunLoop(hidManager, CFRunLoopGetMain(), kCFRunLoopCommonModes);
            }
            CFArrayRef matches =
                matching_dictionaries_create((int)idVendor, products, productCount, 1, 6);
            IOHIDManagerSetDeviceMatchingMultiple(hidManager, matches);
            CFRelease(matches);
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
    close_all_seized();
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

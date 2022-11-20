# yubiswitch

# Overview

`yubiswitch` is an OSX status bar application to enable/disable a [Yubikey Nano or Neo](https://www.yubico.com/products/yubikey-hardware/) from Yubico.

Yubico is the producer of the Yubikeys: a hardware authentication device, designed to provide an easy to use and secure compliment to the traditional username and password.

By touching the exposed gold edge, a YubiKey Nano emits a One Time Password (OTP) as if it was typed in from a keyboard. The unique passcode is verified by a YubiKey compliant application.

![Yubikey Nano picture](/images/nano.jpg)

So far all looks great doesn't it? :D

```
flnurfrdjvfrlutthjtjvcbcrlbbnnuu
ejehlrlrclcllukjgehhrttbknnbjdfn
njlvvnherbjvnljdvvvnihrfikufjucr
jhgkhrubrnuchhhbhrugvbenrhkcvich
```

Whooops! You see? I brought my laptop (lid opened) with me for a walk to a meeting room holding it with my right hand touching the golden stripe and this caused the Nano to start sending random OTP passwords to my Vim session, and to the FB chat window I had opened with my wife, and right now she's been asking WTF I've been writing :P

This status bar app allows you to avoid sending those accidental OTP passwords by allowing you to enable or disable the yubikey using a convenient global keyboard hot key that you can configure yourself.

# Download

Download the latest version in DMG format from [github release page here](https://github.com/pallotron/yubiswitch/releases/).

# Running

This application needs to run with escalated privileges in order to exclusively grab the USB HID interface that drives the NANO/NEO-n Yubikey. Running the main app as root is a p.i.t.a. so YubiSwitch installs an helper daemon with root privileges which contains the logic to grab the USB HID interface, the main application talks to this daemon via XPC calls. When you start YubiSwitch for the first time it will ask for your user's password, this is expected to install the helper before mentioned.

If you use your Yubikey as part of [multi-factor authentication for Mac](https://www.yubico.com/wp-content/uploads/2015/04/YubiKey-OSX-Login.pdf) then you might want to make sure that the option "Enable yubikey when system locks/sleeps" is enabled.

If want `yubiswitch` to lock your computer when you unplug the key make sure that your security settings are as follow:

![Security settings for screensaver](/images/screensaver-settings.png)

# Accessibility Access (Catalina and above)

If you are running macOS Catalina (10.15) or later, open System Preferences and go to Security & Privacy, Privacy. Under Accessibility, click the lock to make changes and then use the + button to add `/Applications/yubiswitch.app.`.

![Accessibility settings](/images/screenshot-accessibility.png)

# Integration with shell

The application supports two basic AppleScript commands:

- KeyOn
- KeyOff

You can switch your yubikey on and off using this basic osacript commands:

```
$ osascript -e 'tell application "yubiswitch" to KeyOn'
```

```
$ osascript -e 'tell application "yubiswitch" to KeyOff'
```

# How to find ProductID and VendorID

To find the product and vendor IDs you can use any of the following methods:

1. Use the GUI:
- Open the System Information app (`CMD + Space`) type `System Information`
- On the left sidebar click on USB -> Find your OTP/FIDO/CCID
  ![System Information app Screenshot](/images/screenshot-system-prefs.png)

2. Do the following in the terminal:

```
$ ioreg -p IOUSB -l -w 0 -x | grep -i Yubikey -A10 | grep 'idProduct\|idVendor'
          "idProduct" = 0x116
          "idVendor" = 0x1050
```

> **note:** the `-x` for ioreg is important for displaying the idProduct field in hexadecimal.

3. If you have brew installed and [prefer lsusb-style output](http://stackoverflow.com/questions/17058134/is-there-an-equivalent-of-lsusb-for-os-x):

```
$ brew update && brew tap jlhonora/lsusb && brew install lsusb

$ lsusb | grep -i Yubikey
Bus 020 Device 022: ID 1050:0116 1050 Yubikey NEO OTP+U2F+CCID
```

# Screenshots

Menu items in the status bar:

![Menu items screenshot](/images/screenshot-menuitems.png)

Preference window:

![Menu items screenshot](/images/screenshot-prefs.png)

# Known Issues

- The app's default settings support the Nano. If you have a different model, go into the app's `Preferences` by clicking on the menu icon, then set the the `Product ID` to `0x0114` (or whatever your ProductID is) see: [How to find ProductID and VendorID](#how-to-find-productid-and-vendorid).
- If your YubiKey is not working, you might want to confirm the `Product ID` and `Vendor ID` follow the how to find your ProductID and VendorID steps below
- This app only works with recent version of OSX because it relies on the Notification Centre. OSX 10.8.x and above would do it. Sorry about that.
- If your `Product ID` and `Vendor ID` are correct but the app is not working then please follow the uninstall instructions and update to the latest release version.
- Float value for time in `Switch off Yubikey after __ seconds` (under preferences) causes trouble for `Automatically switch off Yubikey` option. Converting this value to int fixes it. 

# TODO and future plans

- [x] Make hotkey configurable via configuration window, currently it's static and it is cmd-Y. (This is done via ShortcutRecorder now)
- [x] Use NSNotificationCenter to notify other classes (ie AppDelegate and YubiKey) when user preferences are changed
- [x] Add "Start at login" feature
- [x] Support for basic AppleScript comomands: KeyOn/KeyOff
- [x] Feature: lock computer when yubikey is removed (use IOServiceAddMatchingNotification in IOKit?)
- [x] Support more yubikeys nano on multiple USB slots
- [x] Better support for plug and unplug events (fixed with HID interface, dmg not published yet)
- [ ] Feature: support all YubiCo devices without any configuration needed

# How to create DMG for distribution

You need to make sure that you sign all applications and frameworks, also you need to make sure the `dmg` file is signed (the bash script `createdmg.sh` does this for you). You need to sign the app with an official Mac developer profile.

When you want to create a release:

- Tag repo with vx.y, ie `git tag -a -m 'comment that describe the changes' v0.2`
- Compile release app bundle in Xcode
- Run script: `cd dmg/ && bash createdmg.sh`
- Get the file at `/tmp/yubiswitch\_$VERSION.dmg` and attach the binary to the release in the new release in [the github page](https://github.com/pallotron/yubiswitch/releases/)

# Dependencies

`yubiswitch` uses ShortcutRecoder to implement global hot key and shortcuts recording in the the preference window.

- ShortcutRecorder is at : [https://github.com/Kentzo/ShortcutRecorder](https://github.com/Kentzo/ShortcutRecorder)

# How to uninstall

Uninstallation process is pretty manual. Execute this as root:

Kill all processes:

```
# pkill -f com.pallotron.yubiswitch.helper
```

Tell `launchctl` to stop the helper daemon:

```
# launchctl stop com.pallotron.yubiswitch.helper
# launchctl remove com.pallotron.yubiswitch.helper
```

Check that `launchctl` service is no longer there:

```
# launchctl list | grep -i yubi
```

Remove files from filesystem:

```
# sudo rm /Library/PrivilegedHelperTools/com.pallotron.yubiswitch.helper
# sudo rm -r /Applications/yubiswitch.app/
```

Maybe one day I will provide a script to do this.

# Credits

Credits:

- Anton Tolchanov (@knyar), he originally wrote this in Python using PyObjC bridge. I decided to port this into Objective-C to learn the language when I found out that Carbon Event Manager libs have been removed from Python3. See [http://docs.python.org/2/library/carbon.html](http://docs.python.org/2/library/carbon.html)
- @postwait for the USD HID device code

yubiswitch
==========

`yubiswitch` is an OSX status bar application to enable/disable a
[Yubikey Nano](http://www.yubico.com/products/yubikey-hardware/yubikey-nano)
from Yubico.

Yubikey is the producer of the Yubikeys: an hardware  authentication device,
designed to provide an easy to use and secure compliment to the traditional
username and password.

By touching the exposed gold edge, a YubiKey Nano emits a One Time Password
(OTP) as if it was typed in from a keyboard. The unique passcode is verified by
a YubiKey compliant application.

![Yubikey Nano picture](/images/nano.jpg)

So far all looks great doesn't it? :D

```
flnurfrdjvfrlutthjtjvcbcrlbbnnuu
ejehlrlrclcllukjgehhrttbknnbjdfn
njlvvnherbjvnljdvvvnihrfikufjucr
jhgkhrubrnuchhhbhrugvbenrhkcvich
```

Whooops! You see? I brought my laptop (lid opened) with me for a walk to a
meeting room holding it with my right hand right touching the golden stripe and
this caused the Nano to start sending random OTP passwords to my Vim session,
and to the FB chat window I had opened with my wife, and right now she's been
asking WTF I've been writing :P

This status bar app avoid you to send those accidental OTP passwords by allowing
you to enable or disable the yubikey using a convenient global keyboard hot key
that you can configure yourself.

Download
========

Download the latest version in DMG format from
[github release page here](https://github.com/pallotron/yubiswitch/releases/).

Screenshots
===========

Menu items in the status bar:

![Menu items screenshot](/images/screenshot-menuitems.png)

Preference window:

![Menu items screenshot](/images/screenshot-prefs.png)

Known Issues
============

* This applicaiton only works with a single model of yubikey,
the *YubiKey Nano*. There is no need to deal with other yubikeys because their
form factor doesn't encourage the users to leave it always plugged in.
The nano is the only the model that fits cleanly into your usb port. It has
idVendor 0x1050 and idProduct 0x0010.

* This app only works with recent version of OSX because it relies on the
Notification Centre. OSX 10.8.x and above would do it. Sorry about that.

TODO and future plans
=====================

- [x] Make hotkey configurable via configuration window, currently it's static
and it is cmd-Y. (This is done via ShortcutRecorder now)

- [x] Use NSNotificationCenter to notify other classes (ie AppDelegate and
YubiKey) when user preferences are changed

- [ ] Feature: lock computer when yubikey is removed (use
IOServiceAddMatchingNotification in IOKit?)

- [ ] Support more yubikeys nano on multiple USB slots

- [ ] Better support for plug and unplug events

- [ ] Convert release process using [github's Release APIS]
(https://github.com/blog/1645-releases-api-preview)

How to create DMG for distribution
==================================

Note that this will change soon to be integrated with [github's Release APIS]
(https://github.com/blog/1645-releases-api-preview)


When you want to create a release:
* Tag repo with vx.y, ie `git tag -a -m 'comment' v0.2`
* Compile release app bundle in Xcode
* Run script: `cd dmg/ && bash createdmg.sh`
* Get the file at `/tmp/yubiswitch\_$VERSION.dmg` and distribute via release
page as explained in
[the github blog](https://github.com/blog/1547-release-your-software)

Dependencies
============

`yubiswitch` uses ShortcutRecoder to implement global hot key and shortcuts
recording in the the preference window.

* ShortcutRecorder is at : https://github.com/Kentzo/ShortcutRecorder
* I'll need to add it to your `yubiswitch` clone using git submodule using
command:

```
git submodule add git://github.com/Kentzo/ShortcutRecorder.git
```

* See [this helpful page](https://github.com/Kentzo/ShortcutRecorder) for
instructions on how to set up your Xcode environment should you have any
problem.

Credits
=======

Credits to Anton Tolchanov (@knyar), he originally wrote this in Python using
PyObjC bridge. I decided to port this into Objective-C to learn the language
when I found out that Carbon Event Manager libs have been removed from Python3.
See http://docs.python.org/2/library/carbon.html

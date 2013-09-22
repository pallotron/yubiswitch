yubiswitch
==========

Author: Angelo "pallotron" Failla <pallotron@freaknet.org>

`yubiswitch` is an OSX status bar application to enable/disable a Yubikey.

This is particularly useful if you use to keep the yubikey plugged into your
USB slots while carrying your laptop around. It avoids your vim sessions, or
your terminal sessions to be filled with `ejehlrlrclcllukjgehhrttbknnbjdfn` :D

Known Issues
============

This app only works with a single model of yubikey, the *YubiKey Nano*.
That is the small model that fits cleanly into your usb port (idVendor 0x1050
and idProduct 0x0010) and you can enable by touching the golden stripe with
your finger tip.

TODO and future plans
=====================

* Implement notifications windows when yubikey status gets toggled (on and off).
* Support multiple yubikeys
* Support multiple models (not only idVendor 0x1050 and idProduct 0x0010)
* Feature: lock computer when yubikey is removed.

Credits
=======

Credits to Anton Tolchanov, he originally wrote this in Python using PyObjC
bridge. I decided to port this into Objective-C when I found out that Carbon
Event Manager libs have been removed from Python3.
See http://docs.python.org/2/library/carbon.html
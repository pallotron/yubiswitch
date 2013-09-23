#!/bin/bash

VERSION=$(grep CFBundleShortVersionString yubiswitch/yubiswitch-Info.plist -A1 \
  | tail -1 | perl -lne 'print $1 if /<string>(.*)<\/string>/')
SRC_BINARY=$(find ~/Library/Developer/Xcode/DerivedData/ \
  -name "yubiswitch.app" \
  | grep "Build/Products/Release/")
OUTPUT=/tmp/yubiswitch_$VERSION.dmg

tmpdir=$(mktemp -d -t yubiswitch)
echo "Tempdir: $tmpdir"

cp skeleton.dmg $tmpdir/
hdiutil attach -autoopen -readwrite $tmpdir/skeleton.dmg
echo "Copuing $SRC_BINARY to /Volumes/yubiswitch/"
cp -a $SRC_BINARY /Volumes/yubiswitch/
echo "Detach /Volumes/yubiswitch/"
hdiutil detach /Volumes/yubiswitch/
sync
sync

echo "Converting DMG to compressed/ro, and write to $OUTPUT"
rm -f $OUTPUT
hdiutil convert -format UDZO -o $OUTPUT $tmpdir/skeleton.dmg

echo "Removing tmpdir"
rm -rf $tmpdir

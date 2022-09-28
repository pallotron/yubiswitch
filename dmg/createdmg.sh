#!/bin/bash

set -e

if [ ! -e ../yubiswitch/yubiswitch-Info.plist ]; then
  echo "Can't extrapolate bundle version."
  echo "Are you executing this from whiting the dmg/ dir?"
  exit 1
fi

VERSION=$(grep CFBundleShortVersionString ../yubiswitch/yubiswitch-Info.plist \
  -A1 | tail -1 | perl -lne 'print $1 if /<string>(.*)<\/string>/')

echo "Version: $VERSION"
SRC_BINARY=$(find ~/Library/Developer/Xcode/DerivedData/ \
  -name "yubiswitch.app" \
  | grep "Build/Products/Release/")
if [ -z "$SRC_BINARY" ]; then
  echo "Can find yubiswitch.app, make sure you have built a 'release' binary"
  exit 1
fi
OUTPUT=/tmp/yubiswitch_$VERSION.dmg

tmpdir=$(mktemp -d -t yubiswitch)
echo "Tempdir: $tmpdir"

echo "Copying skeleton contents to $tmpdir"
cp -R skeleton $tmpdir

echo "Copying $SRC_BINARY to $tmpdir"
rsync -a $SRC_BINARY/ $tmpdir

echo "Creating new disk image at $OUTPUT"
hdiutil create -volName yubiswitch -srcfolder $tmpdir $OUTPUT
sync
sync

if [ ! $OUTPUT ]; then
  echo "can't find $OUTPUT!"
  exit 1
fi

codesign -s "Apple Development: David Rothera (G54X79V8CR)" $OUTPUT

echo "Removing tmpdir"
rm -rf $tmpdir

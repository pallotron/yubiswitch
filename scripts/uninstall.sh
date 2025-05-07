#!/bin/zsh

# Uninstall script for yubiswitch

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root."
    echo "Please run again with sudo: sudo $0"
    exit 1
fi

echo "Uninstalling yubiswitch..."

echo "Killing yubiswitch and helper processes..."
pkill -f yubiswitch.app > /dev/null 2>&1
pkill -f com.pallotron.yubiswitch.helper > /dev/null 2>&1


# Stop and remove launchctl service
echo "Stopping and removing launchctl service..."
launchctl stop com.pallotron.yubiswitch.helper > /dev/null 2>&1
launchctl remove com.pallotron.yubiswitch.helper > /dev/null 2>&1

# Verify service is gone with retries since it seems to take a little while to
# be removed.
echo "Verifying service removal..."
attempts=0
max_attempts=18  # Try for up to 60 seconds (12 * 5 seconds)

while [ $attempts -lt $max_attempts ]; do
    if launchctl list | grep -i yubi > /dev/null 2>&1; then
        attempts=$((attempts + 1))
        if [ $attempts -lt $max_attempts ]; then
            echo "Service still found, waiting 5 seconds for it to unload... (Attempt $attempts/$max_attempts)"
            sleep 5
        else
            echo "Warning: Yubiswitch service still found in 'launchctl list' after 1 minute."
            echo "Please manually stop and remove it with:"
            echo
            echo "    sudo launchctl stop com.pallotron.yubiswitch.helper"
            echo "    sudo launchctl remove com.pallotron.yubiswitch.helper"
            echo
            echo "and then run this script again."
            exit 1
        fi
    else
        echo "yubiswitch service successfully removed."
        break
    fi
done

# Remove files
echo "Removing yubiswitch files..."
rm -f /Library/PrivilegedHelperTools/com.pallotron.yubiswitch.helper
rm -rf /Applications/yubiswitch.app/

# Check if files were removed successfully
if [ -f "/Library/PrivilegedHelperTools/com.pallotron.yubiswitch.helper" ] || [ -d "/Applications/yubiswitch.app/" ]; then
    echo "Warning: Failed to remove some yubiswitch files. Please try removing them manually with:

    sudo rm -f /Library/PrivilegedHelperTools/com.pallotron.yubiswitch.helper
    sudo rm -rf /Applications/yubiswitch.app/"
    exit 1
else
    echo "yubiswitch files successfully removed."
fi

echo "Uninstallation complete."

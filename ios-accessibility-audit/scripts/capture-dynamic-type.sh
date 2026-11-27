#!/bin/bash
set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 || ! $1 =~ ^[[:xdigit:]]{8}-([[:xdigit:]]{4}-){3}[[:xdigit:]]{12}$ || ( $# == 3 && -z $3 ) ]]; then
    echo "Usage: bash capture-dynamic-type.sh BOOTED_DEVICE_UDID NEW_CAPTURE_DIRECTORY [DISPLAY_ID]" >&2
    exit 2
fi

device=$1
directory=$2
screenshot_options=(--type=png)
if [[ $# == 3 ]]; then
    screenshot_options+=("--display=$3")
fi
size() { xcrun simctl ui "$device" content_size "$@"; }
original=$(size)
case "$original" in
    extra-small|small|medium|large|extra-large|extra-extra-large|extra-extra-extra-large|accessibility-medium|accessibility-large|accessibility-extra-large|accessibility-extra-extra-large|accessibility-extra-extra-extra-large) ;;
    *) echo "Cannot restore unrecognized initial size '$original'. Check the selected simulator." >&2; exit 1 ;;
esac

# Reserve a fresh directory so captures from a previous run cannot be overwritten.
mkdir -- "$directory"
restore() {
    if ! size "$original" || [[ $(size) != "$original" ]]; then
        echo "Restore the original size with: xcrun simctl ui $device content_size $original" >&2
        exit 1
    fi
}
trap restore EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

for category in large accessibility-extra-extra-extra-large; do
    size "$category"
    if [[ $(size) != "$category" ]]; then
        echo "Simulator did not accept $category." >&2
        exit 1
    fi
    # Give the foreground app time to lay out after the settings notification.
    sleep 1
    xcrun simctl io "$device" screenshot "${screenshot_options[@]}" "$directory/$category.png"
done

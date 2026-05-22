#!/usr/bin/env bash

# joycon-repair.sh
# Steam Deck / KDE / BlueZ Joy-Con auto-repair utility

set -e
set -x
JOYCON_NAMES=(
    "Joy-Con (L)"
    "Joy-Con (R)"
)
#   ^^^""Pro Controller"
SCAN_TIME=15

echo "=== Nintendo Joy-Con Recovery Utility ==="

# Ensure bluetooth is powered
bluetoothctl power on > /dev/null
bluetoothctl agent on > /dev/null


# Get paired devices
PAIRED=$(bluetoothctl devices Paired)
NEWDEVICE=0
for NAME in "${JOYCON_NAMES[@]}"; do
    echo ""
    echo "Checking for paired device: $NAME"

    MAC=$(echo "$PAIRED" | grep "$NAME" | awk '{print $2}')

    if [[ -z "$MAC" ]]; then
        echo "No saved pairing for $NAME"
        echo "Scanning for default device name..."

        NEW_DEVICE=1

        timeout 10 bluetoothctl scan on > /dev/null &
        SCAN_PID=$!



        for ((i=0; i<SCAN_TIME; i++)); do
            sleep 1

            DEVICES=$(bluetoothctl devices)

            MAC=$(echo "$DEVICES" | grep "$NAME" | awk '{print $2}' | head -n1)

            if [[ -n "$MAC" ]]; then
                echo "broke at mackin'"
                break
            fi
        done

        echo $$
        bluetoothctl scan off </dev/null || true
        kill $SCAN_PID 2>/dev/null || true


        if [[ -z "$MAC" ]]; then
            echo "Could not find $NAME"
            continue
        fi

        echo "Discovered new device: $MAC"
    fi

    if [[ "$NEW_DEVICE" -eq 1 ]]; then
        echo "Performing first-time pairing..."

        bluetoothctl pair "$MAC"
        bluetoothctl trust "$MAC"
        bluetoothctl connect "$MAC"

        echo "$NAME paired successfully."

        continue
    fi


    echo "Found paired device: $MAC"
    echo "Attempting connection..."

    if bluetoothctl connect "$MAC" | grep -q "Connection successful"; then
        echo "$NAME connected successfully."
        continue
    fi

    echo "Connection failed."
    echo "Removing stale pairing..."

    bluetoothctl remove "$MAC"

    echo "Starting scan for fresh pairing..."
    bluetoothctl agent on > /dev/null
    timeout 10 bluetoothctl scan on > /dev/null & SCAN_PID=$!

    FOUND_MAC=""

    for ((i=0; i<SCAN_TIME; i++)); do
        sleep 1

        DEVICES=$(bluetoothctl devices)

        FOUND_MAC=$(echo "$DEVICES" | grep "$NAME" | awk '{print $2}' | head -n1)

        if [[ -n "$FOUND_MAC" ]]; then
            break
        fi
    done

    bluetoothctl scan off </dev/null || true
    kill $SCAN_PID 2>/dev/null || true


    if [[ -z "$FOUND_MAC" ]]; then
        echo "Could not rediscover $NAME"
        continue
    fi

    echo "Rediscovered device: $FOUND_MAC"

    echo "Pairing..."
    bluetoothctl pair "$FOUND_MAC"

    echo "Trusting..."
    bluetoothctl trust "$FOUND_MAC"

    echo "Connecting..."
    bluetoothctl connect "$FOUND_MAC"

    echo "$NAME recovery sequence complete."
done

echo ""
echo "Done."

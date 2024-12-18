#!/bin/bash

# Function to send notification via awesome-client
send_notification() {
    local message="$1"
    awesome-client "
    local naughty = require('naughty')
    naughty.notify({
        title = 'Caido',
        text = '$message',
        timeout = 5
    })
    "
}

# Function to check if caido-cli is already running
is_caido_running() {
    pgrep -f "caido-cli" > /dev/null
}

# Function to import certificate into a Firefox profile
import_cert_to_profile() {
    local profile_path="$1"
    local cert_path="$2"
    local cert_name="Caido CA"

    # Check if certutil is available
    if command -v certutil &> /dev/null; then
        certutil -A -n "$cert_name" -t "C,," -i "$cert_path" -d "$profile_path" &>/dev/null
    fi
}

# Function to run caido-cli
run_caido_cli() {
    /usr/local/bin/caido-cli "$@" &
    CAIDO_PID=$!
}

# Function to wait for caido-cli to start
wait_for_caido() {
    for i in {1..60}; do  # Wait up to 60 seconds
        if curl -s http://127.0.0.1:8080 &>/dev/null; then
            return 0
        fi
        if ! kill -0 $CAIDO_PID 2>/dev/null; then
            return 1
        fi
        sleep 1
    done
    return 1
}

# Function to download and import certificate
handle_certificate() {
    cert_path="$HOME/.caido_ca.crt"
    if curl -s -o "$cert_path" "http://127.0.0.1:8080/ca.crt" &>/dev/null; then
        firefox_config_dir="$HOME/.mozilla/firefox"
        if [ -d "$firefox_config_dir" ]; then
            profile_count=0
            while IFS= read -r -d '' profile_dir; do
                if [ -d "$profile_dir" ]; then
                    import_cert_to_profile "$profile_dir" "$cert_path"
                    ((profile_count++))
                fi
            done < <(find "$firefox_config_dir" -type d -name "*.default*" -print0)
            
            if [ $profile_count -gt 0 ]; then
                send_notification "Caido certificate imported to Firefox"
            fi
        fi
        rm -f "$cert_path" &>/dev/null
    fi
}

# Function to open a new tab to 127.0.0.1:8080


# Main execution
(
    if is_caido_running; then
        firefox http://127.0.0.1:8080
    else
        run_caido_cli "$@"
        if wait_for_caido; then
            handle_certificate
        else
            send_notification "Failed to start Caido"
        fi
    fi
) &>/dev/null & disown

# Exit immediately
exit 0
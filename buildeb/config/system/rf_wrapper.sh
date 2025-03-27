#!/bin/bash

# Function to send notification via awesome-client
send_notification() {
    local message="$1"
    awesome-client "
    local naughty = require('naughty')
    naughty.notify({
        title = 'RF-Lockpick',
        text = '$message',
        timeout = 5
    })
    "
}

# Main execution
send_notification "Starting RF-Lockpick server..."

# Start server and capture PID
python3 /usr/local/bin/RF-Lockpick/main.py &>/dev/null &
SERVER_PID=$!

# Wait briefly to check if server crashed immediately
sleep 4

# Check if server is still running
if kill -0 $SERVER_PID &>/dev/null; then
    send_notification "RF-Lockpick server started successfully"
else
    send_notification "RF-Lockpick server failed to start (check logs)"
    exit 1
fi

# Disown the process so it keeps running after wrapper exits
disown $SERVER_PID

exit 0

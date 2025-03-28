#!/bin/bash

# Function to send notification via awesome-client
show_help() {
    echo "Usage: rf [option]"
    echo "Options:"
    echo "  (no option)   Start RF-Lockpick server"
    echo "  stop          Stop running RF-Lockpick server"
    echo "  -h, --help    Show this help message"
}

# Function to stop the server
stop_server() {
    local pid=$(pgrep -f "python3 /usr/local/bin/RF-Lockpick/main.py")
    if [ -n "$pid" ]; then
        kill $pid
        send_notification "RF-Lockpick server stopped"
    else
        send_notification "RF-Lockpick server is not running"
    fi
}

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
case "$1" in
    stop)
        stop_server
        exit 0
        ;;
    -h|--help)
        show_help
        exit 0
        ;;
    "")
        # Default behavior - start server
        send_notification "Starting RF-Lockpick server..."
        ;;
    *)
        echo "Invalid option: $1"
        show_help
        exit 1
        ;;
esac


# Start server and capture PID
python3 /usr/local/bin/RF-Lockpick/main.py &>/dev/null &
SERVER_PID=$!

# Wait briefly to check if server crashed immediately
sleep 3

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

#!/bin/bash

PORT_FILE="/run/user/$UID/Proton/VPN/forwarded_port"
WEBUI_URL="http://localhost:8080"
LAST_PORT=""
CHECK_INTERVAL=1

echo "Remember to enable WebUI from qBittorrent!"
echo "Monitoring Proton VPN port file for changes..."
echo "Press Ctrl+C to stop the script."
echo "---------------------------------------------------"

while true; do
    if [[ -f "$PORT_FILE" ]]; then

        NEW_PORT=$(cat "$PORT_FILE")

        if [[ "$NEW_PORT" =~ ^[0-9]+$ ]] && [[ "$NEW_PORT" != "$LAST_PORT" ]]; then

            CURRENT_TIME=$(date '+%H:%M:%S')

            echo "[$CURRENT_TIME] New port detected: $NEW_PORT"
            echo "[$CURRENT_TIME] Attempting to update live qBittorrent port..."

            HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$WEBUI_URL/api/v2/app/setPreferences" --data-urlencode "json={\"listen_port\": $NEW_PORT}")

            if [[ "$HTTP_RESPONSE" == "200" ]]; then
                echo "[$CURRENT_TIME] Success! qBittorrent port updated to $NEW_PORT."
                LAST_PORT="$NEW_PORT"
            elif [[ "$HTTP_RESPONSE" == "403" ]]; then
                echo "[$CURRENT_TIME] Error (403 Forbidden): qBittorrent rejected the request."
                echo "[$CURRENT_TIME] Check 'Bypass authentication for clients on localhost' in Web UI settings."
            elif [[ "$HTTP_RESPONSE" == "000" ]]; then
                echo "[$CURRENT_TIME] Error: Could not connect to qBittorrent WebUI. Is it running?"
            else
                echo "[$CURRENT_TIME] Failed to update port. HTTP Status Code: $HTTP_RESPONSE"
            fi
            echo "---------------------------------------------------"
        fi
    fi

    sleep "$CHECK_INTERVAL"
done

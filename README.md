# What is this?
baqpup (Basic Automatic qBittorrent Port Updater for ProtonVPN), is a bash script that runs in the linux terminal and updates qBittorrent port to the Proton VPN port automatically.

# How to use?
1. Install `curl`
2. Enable WebUI in qBittorrent. <br> (Preferences -> WebUI -> Turn on "Web User Interface (Remote control)" and "Bypass authentication for clients on localhost")
3. Make a file named `baqpup.sh`.
4. Copy the code from [here](#code), paste it in the script file and save it.
5. If you set a different username or password for your WebUI, make sure to edit the script to include it, if you do not want to enter it every time when you run the script. The default (for qBittorrent and baqpup) username is `admin` and the default password is `adminadmin`.
6. Make the script file executable by running `chmod +x baqpup.sh`.
7. Run the script by typing `./baqpup.sh` or `sh baqpup.sh` in the terminal/konsole.
8. Done!

# What is it supported on?
I have tested my script on Arch Linux with KDE Plasma 6.6.4 on qBittorrent 5.1.4-2 and proton-vpn-gtk-app 4.15.2-1. <br>
I did not tested it on other distros and other desktop environments. <br>
If you run into any issues or have feature ideas, report it in [GitHub Issues](https://github.com/syrupderg/baqpup/issues).

> [!IMPORTANT]
> "proton-vpn-cli" and "proton-vpn-qt-app" does not work with this script. <br>
> This might be because of me since they also did not work with the [ProtonVPN guide for maual port forwarding setup](https://protonvpn.com/support/port-forwarding-manual-setup#linux).


# Automatically running the file in the background:
1. [Systemd](#systemd)
2. [OpenRC](#openrc)
3. [KDE Plasma](#kde-plasma)

## Systemd:
1. `mkdir -p ~/.local/bin`
2. `mv baqpup.sh ~/.local/bin/`
3. `chmod +x ~/.local/bin/baqpup.sh`
4. `mkdir -p ~/.config/systemd/user/`
5. Create a file named `baqpup.service` in `~/.config/systemd/user/` and paste the following configuration and save it:
   
```service
[Unit]
Description=Basic Automatic qBittorrent Port Updater for ProtonVPN
After=network.target

[Service]
ExecStart=%h/.local/bin/baqpup.sh
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
```
6. Reload systemctl: `systemctl --user daemon-reload`
7. Make the service run when the system starts: `systemctl --user enable --now baqpup.service`
8. Done!

## OpenRC:
1. `mkdir -p ~/.local/bin`
2. `mv baqpup.sh ~/.local/bin/`
3. `chmod +x ~/.local/bin/baqpup.sh`
4. Create a file named `baqpup` in `/etc/init.d/` and paste the following configuration and save it:

> [!CAUTION]
> Do not forget to change "yourusername" with your username for "command=" and "command_user="!

```service
#!/sbin/openrc-run

description="Basic Automatic qBittorrent Port Updater for ProtonVPN"

# Replace 'yourusername' with your username
command="/home/yourusername/.local/bin/baqpup.sh"
command_user="yourusername"
command_background=true
pidfile="/run/baqpup.pid"

depend() {
    need net
}
```
5. Make the script file executable: `sudo chmod +x /etc/init.d/baqpup`
6. Make the service run when the system start: `sudo rc-update add baqpup default`
7. Start the service: `sudo rc-service baqpup start`
8. Done!

## KDE Plasma:
1. Open System Settings.
2. Scroll all the way down and click on "Autostart"
3. Click on "Add new" -> "Login script..."
4. Pick the `baqpup.sh` file.
5. Done!

# Code
```bash
#!/bin/bash

PORT_FILE="/run/user/$UID/Proton/VPN/forwarded_port"
CONF_FILE="$HOME/.config/qBittorrent/qBittorrent.conf"
COOKIE_FILE="/tmp/qbittorrent_baqpup_cookie.txt"

QB_USERNAME="admin"
QB_PASSWORD="adminadmin"

LAST_PORT=""
LAST_STATUS=""
CHECK_INTERVAL=1

trap 'rm -f "$COOKIE_FILE" /tmp/qb_login_body.txt' EXIT

echo "Monitoring qBittorrent port status..."
echo "Press Ctrl+C to stop."
echo "---------------------------------------------------"

update_status() {
    if [[ "$LAST_STATUS" != "$1" ]]; then
        echo "[$(date '+%H:%M:%S')] $1"
        LAST_STATUS="$1"
    fi
}

check_webui_enabled() {
    if [[ -f "$CONF_FILE" ]]; then
        local enabled=$(grep -E "^WebUI\\\\Enabled=" "$CONF_FILE" | cut -d'=' -f2 | tr -d '\r')
        if [[ "${enabled,,}" == "false" ]]; then
            return 1
        fi
    fi
    return 0
}

get_webui_url() {
    local address="127.0.0.1"
    local port="8080"
    
    if [[ -f "$CONF_FILE" ]]; then
        local conf_address=$(grep -E "^WebUI\\\\Address=" "$CONF_FILE" | cut -d'=' -f2 | tr -d '\r')
        local conf_port=$(grep -E "^WebUI\\\\Port=" "$CONF_FILE" | cut -d'=' -f2 | tr -d '\r')
        
        if [[ -n "$conf_address" && "$conf_address" != "*" && "$conf_address" != "0.0.0.0" ]]; then
            address="$conf_address"
        fi
        
        if [[ "$conf_port" =~ ^[0-9]+$ ]]; then
            port="$conf_port"
        fi
    fi
    echo "http://$address:$port"
}

while true; do
    if ! pgrep -i qbittorrent > /dev/null; then
        update_status "Status: qBittorrent is not running"
        LAST_PORT=""
    elif ! check_webui_enabled; then
        update_status "Status: WebUI is disabled in qBittorrent settings"
        LAST_PORT=""
    elif [[ -f "$PORT_FILE" ]]; then
        NEW_PORT=$(cat "$PORT_FILE")

        if [[ "$NEW_PORT" =~ ^[0-9]+$ ]] && [[ "$NEW_PORT" != "$LAST_PORT" ]]; then
            WEBUI_URL=$(get_webui_url)
            
            HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -b "$COOKIE_FILE" -H "Origin: $WEBUI_URL" -H "Referer: $WEBUI_URL/" -X POST "$WEBUI_URL/api/v2/app/setPreferences" --data-urlencode "json={\"listen_port\": $NEW_PORT}")

            if [[ "$HTTP_RESPONSE" == "200" || "$HTTP_RESPONSE" == "204" ]]; then
                update_status "Status: Port successfully updated to $NEW_PORT"
                LAST_PORT="$NEW_PORT"
            elif [[ "$HTTP_RESPONSE" == "403" ]]; then
                QB_USER="$QB_USERNAME"
                QB_PASS="$QB_PASSWORD"

                if [[ -z "$QB_USER" || -z "$QB_PASS" ]]; then
                    if [ -t 0 ]; then
                        update_status "Status: WebUI requires authentication."
                        read -r -p "qBittorrent Username [admin]: " QB_USER
                        QB_USER=${QB_USER:-admin}
                        read -r -s -p "qBittorrent Password: " QB_PASS
                        echo "" 
                    else
                        update_status "Status: WebUI Auth Error (403). Cannot prompt for password in background mode."
                        LAST_PORT="$NEW_PORT" 
                        sleep "$CHECK_INTERVAL"
                        continue
                    fi
                fi
                
                LOGIN_HTTP=$(curl -s -o /tmp/qb_login_body.txt -w "%{http_code}" -c "$COOKIE_FILE" -H "Origin: $WEBUI_URL" -H "Referer: $WEBUI_URL/" -X POST "$WEBUI_URL/api/v2/auth/login" --data-urlencode "username=$QB_USER" --data-urlencode "password=$QB_PASS")
                LOGIN_BODY=$(cat /tmp/qb_login_body.txt 2>/dev/null)
                
                if [[ "$LOGIN_HTTP" == "204" ]] || [[ "$LOGIN_HTTP" == "200" && "$LOGIN_BODY" == *"Ok."* ]]; then
                    update_status "Status: Login successful! Retrying port update..."
                    
                    RETRY_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -b "$COOKIE_FILE" -H "Origin: $WEBUI_URL" -H "Referer: $WEBUI_URL/" -X POST "$WEBUI_URL/api/v2/app/setPreferences" --data-urlencode "json={\"listen_port\": $NEW_PORT}")
                    
                    if [[ "$RETRY_RESPONSE" == "200" || "$RETRY_RESPONSE" == "204" ]]; then
                        update_status "Status: Port successfully updated to $NEW_PORT"
                        LAST_PORT="$NEW_PORT"
                    else
                        update_status "Status: Failed to update port after login. HTTP $RETRY_RESPONSE"
                    fi
                else
                    update_status "Status: Login failed. Code: $LOGIN_HTTP, Response: $LOGIN_BODY"
                    sleep 2 
                fi
            elif [[ "$HTTP_RESPONSE" == "000" ]]; then
                update_status "Status: Could not connect to WebUI at $WEBUI_URL"
            else
                update_status "Status: HTTP Error $HTTP_RESPONSE"
            fi
        fi
    fi

    sleep "$CHECK_INTERVAL"
done

```

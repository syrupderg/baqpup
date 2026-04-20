# What is this?
baqpup (Basic Automatic qBittorrent Port Updater for ProtonVPN), is a bash script that runs in the linux terminal and updates qBittorrent port to the Proton VPN port automatically.

# How to use?
1. Install `curl`
2. Enable WebUI in qBittorrent. <br> (Preferences -> WebUI -> Turn on "Web User Interface (Remote control)" and "Bypass authentication for clients on localhost")
3. Make a file named `baqpup.sh`.
4. Copy the code from [here](#code), paste it in the script file and save it.
5. Make the script file executable by running `chmod +x baqpup.sh`.
6. Run the script by typing `./baqpup.sh` or `sh baqpup.sh` in the terminal/konsole.
7. Done!

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

```

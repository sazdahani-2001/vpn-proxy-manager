#!/bin/bash

CONFIG_FILE="$HOME/.vpnproxy.conf"
VPN_PID_FILE="/tmp/openconnect.pid"
PROXY_PORT="9080"
ALIAS_FILE="/usr/local/bin/vpnproxymanager"

function welcome_message() {
    clear
    echo "=============================================="
    echo "  Welcome to VPN Proxy Manager (Tinyproxy)   "
    echo "  اتصال امن به VPN و پراکسی سبک با Tinyproxy  "
    echo "=============================================="
    sleep 1
    check_status
}

function check_status() {
    echo ""
    if [ -f "$VPN_PID_FILE" ] && ps -p $(cat "$VPN_PID_FILE") > /dev/null; then
        echo "✅ VPN: Connected"
    else
        echo "❌ VPN: Not Connected"
    fi

    if systemctl is-active --quiet tinyproxy; then
        echo "✅ Proxy: Active"
    else
        echo "❌ Proxy: Inactive"
    fi
    echo ""
}

function menu() {
    welcome_message
    echo "[1] Install Dependencies       نصب ابزارها"
    echo "[2] Uninstall Everything        حذف کامل"
    echo "[3] Set VPN Credentials         اطلاعات VPN"
    echo "[4] Edit VPN Credentials        ویرایش VPN"
    echo "[5] Setup Proxy Port            تنظیم پورت پراکسی"
    echo "[6] Enable Auto-Connect         اتصال خودکار"
    echo "[7] Full Auto Setup             اجرای همه مراحل"
    echo "[8] Test Proxy                  تست اتصال پراکسی"
    echo "[9] Exit                        خروج"
    echo "[10] Connect VPN                روشن کردن VPN"
    echo "[11] Disconnect VPN             خاموش کردن VPN"
    echo "[12] Start Proxy                روشن کردن پراکسی"
    echo "[13] Stop Proxy                 خاموش کردن پراکسی"
    echo ""
    read -p "👉 Your choice: " choice

    case $choice in
        1) install_dependencies ;;
        2) uninstall_all ;;
        3) set_vpn_config ;;
        4) edit_vpn_config ;;
        5) setup_proxy ;;
        6) enable_autostart ;;
        7) full_auto_setup ;;
        8) test_proxy ;;
        9) exit 0 ;;
        10) connect_vpn ;;
        11) disconnect_vpn ;;
        12) start_proxy ;;
        13) stop_proxy ;;
        *) echo "⛔ Invalid choice!" ;;
    esac
}

function install_dependencies() {
    sudo apt update
    sudo apt install -y openconnect tinyproxy
    sudo systemctl enable tinyproxy
    echo "✅ Dependencies installed!"
    sleep 1
}

function uninstall_all() {
    echo "🧹 Cleaning up all components..."

    sudo systemctl stop tinyproxy 2>/dev/null
    sudo systemctl stop vpnproxy 2>/dev/null
    sudo systemctl disable vpnproxy 2>/dev/null
    sudo rm -f /etc/systemd/system/vpnproxy.service
    sudo systemctl daemon-reexec

    sudo apt remove --purge -y openconnect tinyproxy
    sudo apt autoremove -y

    sudo rm -f "$CONFIG_FILE" "$VPN_PID_FILE" "$ALIAS_FILE"
    sudo sed -i "s/^Port .*/Port 8888/" /etc/tinyproxy/tinyproxy.conf 2>/dev/null
    sudo sed -i "s/^Allow .*/Allow 127.0.0.1/" /etc/tinyproxy/tinyproxy.conf 2>/dev/null

    echo "✅ Removed successfully."
    sleep 1
}

function set_vpn_config() {
    read -p "Server Address: " VPN_SERVER
    read -p "Username: " VPN_USERNAME

    while true; do
        read -p "Password: " VPN_PASSWORD
        echo "🔐 You entered: $VPN_PASSWORD"
        read -p "Is this correct? (y/n): " confirm
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
            break
        else
            echo "↩️ Let's try again."
        fi
    done

    echo "VPN_SERVER=$VPN_SERVER" > "$CONFIG_FILE"
    echo "VPN_USERNAME=$VPN_USERNAME" >> "$CONFIG_FILE"
    echo "VPN_PASSWORD=$VPN_PASSWORD" >> "$CONFIG_FILE"
    echo "PROXY_PORT=$PROXY_PORT" >> "$CONFIG_FILE"
    echo "✅ VPN info saved!"
    sleep 1
}

function edit_vpn_config() {
    source "$CONFIG_FILE"
    echo "Current Server: $VPN_SERVER"
    echo "Current Username: $VPN_USERNAME"
    echo "(Password hidden)"
    set_vpn_config
}

function setup_proxy() {
    read -p "Enter proxy port (default $PROXY_PORT): " input_port
    if [[ "$input_port" != "" ]]; then
        PROXY_PORT="$input_port"
    fi

    sudo sed -i "s/^Port .*/Port $PROXY_PORT/" /etc/tinyproxy/tinyproxy.conf
    sudo sed -i "s/^Allow .*/Allow 127.0.0.1/" /etc/tinyproxy/tinyproxy.conf
    echo "PROXY_PORT=$PROXY_PORT" >> "$CONFIG_FILE"
    sudo systemctl restart tinyproxy
    echo "✅ Tinyproxy running at http://127.0.0.1:$PROXY_PORT"
    sleep 1
}

function connect_vpn() {
    source "$CONFIG_FILE"
    echo "$VPN_PASSWORD" | sudo openconnect \
        --no-cert-check \
        --background \
        --pid-file="$VPN_PID_FILE" \
        --user="$VPN_USERNAME" \
        "$VPN_SERVER"
    echo "🔗 VPN connected (SSL check disabled)"
    sleep 1
}

function disconnect_vpn() {
    if [ -f "$VPN_PID_FILE" ]; then
        VPN_PID=$(cat "$VPN_PID_FILE")
        sudo kill "$VPN_PID" && rm "$VPN_PID_FILE"
        echo "🔌 VPN connection terminated."
    else
        echo "ℹ️ VPN was not connected."
    fi
    sleep 1
}

function start_proxy() {
    sudo systemctl start tinyproxy
    echo "🟢 Proxy service started."
    sleep 1
}

function stop_proxy() {
    sudo systemctl stop tinyproxy
    echo "🔴 Proxy service stopped."
    sleep 1
}

function create_system_alias() {
    if [ ! -f "$ALIAS_FILE" ]; then
        sudo cp "$0" "$ALIAS_FILE"
        sudo chmod +x "$ALIAS_FILE"
        echo "🔗 Shortcut created: vpnproxymanager"
    fi
}

function enable_autostart() {
    AUTOSTART_SCRIPT="/etc/systemd/system/vpnproxy.service"
    sudo bash -c "cat > $AUTOSTART_SCRIPT" <<EOF
[Unit]
Description=VPN + Proxy Auto Start
After=network.target

[Service]
ExecStart=/bin/bash $ALIAS_FILE auto_start
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reexec
    sudo systemctl enable vpnproxy
    echo "🔁 Autostart enabled."
    sleep 1
}

function auto_start() {
    source "$CONFIG_FILE"
    connect_vpn
    sudo systemctl restart tinyproxy
}

function full_auto_setup() {
    install_dependencies
    create_system_alias
    set_vpn_config
    setup_proxy
    connect_vpn
    enable_autostart
    echo "🎉 All setup done!"
    sleep 1
}

function test_proxy() {
    source "$CONFIG_FILE"
    echo "🧪 Testing proxy at 127.0.0.1:$PROXY_PORT..."
    curl -x 127.0.0.1:$PROXY_PORT http://ifconfig.me/ip
    echo ""
    sleep 1
}

if [[ "$1" == "auto_start" ]]; then
    auto_start
else
    while true; do
        menu
    done
fi
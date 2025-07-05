#!/bin/bash

# تغییر نکنه: مسیرها و متغیرهای اصلی
CONFIG_FILE="$HOME/.vpnproxy.conf"
VPN_PID_FILE="/tmp/openconnect.pid"
PROXY_PORT="9080"
ALIAS_FILE="/usr/local/bin/vpnproxymanager"

# پیام خوش‌آمدی ساده‌تر
function welcome_message() {
    clear
    echo "============================================="
    echo "  Welcome to VPN Proxy Manager - خوش‌اومدی!  "
    echo "  Manage VPN + Proxy simply and securely     "
    echo "  ابزار ساده برای اتصال امن به VPN و پراکسی     "
    echo "============================================="
    sleep 1
}

# منوی سبک و تمیز
function menu() {
    welcome_message
    echo ""
    echo "🔹 Main Menu / منوی اصلی"
    echo ""
    echo "[1] Install Dependencies       نصب ابزارها"
    echo "[2] Uninstall Everything        حذف کامل"
    echo "[3] Enter VPN Credentials       ورود اطلاعات VPN"
    echo "[4] Edit VPN Credentials        ویرایش اطلاعات VPN"
    echo "[5] Setup Proxy Port            ساخت پراکسی با پورت دلخواه"
    echo "[6] Enable Auto-Connect         فعال‌سازی اتصال خودکار"
    echo "[7] Full Auto Setup             اجرای همه مراحل"
    echo "[8] Exit                        خروج"
    echo ""
    read -p "👉 Your choice (گزینه): " choice

    case $choice in
        1) install_dependencies ;;
        2) uninstall_all ;;
        3) set_vpn_config ;;
        4) edit_vpn_config ;;
        5) setup_proxy ;;
        6) enable_autostart ;;
        7) full_auto_setup ;;
        8) exit 0 ;;
        *) echo "⛔ Invalid choice!" ;;
    esac
}

# تابع‌های اصلی همون قبلیا هستن: نصب، حذف، اتصال، ساخت میانبر
function install_dependencies() {
    sudo apt update
    sudo apt install -y openconnect privoxy
    sudo systemctl enable privoxy
    echo "✅ Dependencies installed!"
    sleep 1
}

function uninstall_all() {
    sudo apt remove --purge -y openconnect privoxy
    sudo rm -f "$CONFIG_FILE" "$VPN_PID_FILE" "$ALIAS_FILE" /etc/systemd/system/vpnproxy.service
    echo "✔ All files removed."
    sleep 1
}

function set_vpn_config() {
    read -p "Server Address (آدرس سرور): " VPN_SERVER
    read -p "Username (نام کاربری): " VPN_USERNAME
    read -s -p "Password (رمز): " VPN_PASSWORD
    echo ""
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
    read -p "Use default port 9080? (y/n): " answer
    if [[ "$answer" == "n" ]]; then
        read -p "Enter desired port: " PROXY_PORT
    fi
    sudo sed -i "/^listen-address/c\listen-address  127.0.0.1:$PROXY_PORT" /etc/privoxy/config
    sudo systemctl restart privoxy
    echo "✅ Proxy running at 127.0.0.1:$PROXY_PORT"
    sleep 1
}

function connect_vpn() {
    source "$CONFIG_FILE"
    echo "$VPN_PASSWORD" | sudo openconnect --background --pid-file="$VPN_PID_FILE" --user="$VPN_USERNAME" "$VPN_SERVER"
    echo "🔗 VPN connected!"
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
    sudo systemctl restart privoxy
}

function full_auto_setup() {
    welcome_message
    install_dependencies
    create_system_alias
    set_vpn_config
    setup_proxy
    connect_vpn
    enable_autostart
    echo "🎉 All steps completed!"
    sleep 1
}

# اجرای خودکار هنگام بوت
if [[ "$1" == "auto_start" ]]; then
    auto_start
else
    while true; do
        menu
    done
fi

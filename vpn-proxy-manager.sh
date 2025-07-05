#!/bin/bash

CONFIG_FILE="$HOME/.vpnproxy.conf"
VPN_PID_FILE="/tmp/openconnect.pid"
PROXY_PORT="9080"
ALIAS_FILE="/usr/local/bin/vpnproxymanager"

# 💾 ذخیره تنظیمات
function save_config() {
    echo "VPN_SERVER=$VPN_SERVER" > "$CONFIG_FILE"
    echo "VPN_USERNAME=$VPN_USERNAME" >> "$CONFIG_FILE"
    echo "VPN_PASSWORD=$VPN_PASSWORD" >> "$CONFIG_FILE"
    echo "PROXY_PORT=$PROXY_PORT" >> "$CONFIG_FILE"
}

# 📤 بارگذاری تنظیمات
function load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
}

# 👋 نمایش پیام خوش‌آمدگویی
function welcome_message() {
    clear
    echo -e "\e[96m╔═════════════════════════════════════════════════╗"
    echo -e "\e[96m║        🎉 خوش‌اومدی به VPN Proxy Manager        ║"
    echo -e "\e[96m║      طراحی‌شده برای اتصال امن و ساده شبکه      ║"
    echo -e "\e[96m╚═════════════════════════════════════════════════╝\e[0m"
    echo ""
    sleep 2
}

# 🏷 ساخت میانبر دائمی
function create_system_alias() {
    if [ ! -f "$ALIAS_FILE" ]; then
        sudo cp "$0" "$ALIAS_FILE"
        sudo chmod +x "$ALIAS_FILE"
        echo -e "\e[95m🔗 میانبر vpnproxymanager ساخته شد. حالا فقط کافیه بنویسی: vpnproxymanager\e[0m"
        sleep 1
    fi
}

# ⬇ نصب ابزارها
function install_dependencies() {
    sudo apt update
    sudo apt install -y openconnect privoxy
    sudo systemctl enable privoxy
}

# 🧹 حذف همه چیز
function uninstall_all() {
    sudo apt remove --purge -y openconnect privoxy
    sudo rm -f "$CONFIG_FILE" "$VPN_PID_FILE" "$ALIAS_FILE" /etc/systemd/system/vpnproxy.service
    echo -e "\e[91m✔ همه چیز پاک شد.\e[0m"
}

# 🖥 ورود مشخصات اتصال
function set_vpn_config() {
    read -p "🖧 آدرس سرور VPN: " VPN_SERVER
    read -p "👤 نام کاربری: " VPN_USERNAME
    read -s -p "🔒 رمز عبور: " VPN_PASSWORD
    echo ""
    save_config
    echo -e "\e[92m💾 اطلاعات ذخیره شد.\e[0m"
}

# 🛠 ویرایش مشخصات
function edit_vpn_config() {
    load_config
    echo -e "\e[96m✅ تنظیمات فعلی:"
    echo "📍 سرور: $VPN_SERVER"
    echo "👤 کاربر: $VPN_USERNAME"
    echo "🔒 رمز: (مخفی شده)\e[0m"
    set_vpn_config
}

# 🌐 تنظیم پراکسی
function setup_proxy() {
    read -p "🌀 استفاده از پورت 9080؟ (y/n): " answer
    if [[ "$answer" == "n" ]]; then
        read -p "🔢 پورت دلخواه رو وارد کن: " PROXY_PORT
    fi
    sudo sed -i "/^listen-address/c\listen-address  127.0.0.1:$PROXY_PORT" /etc/privoxy/config
    save_config
    sudo systemctl restart privoxy
    echo -e "\e[92m✅ پراکسی در 127.0.0.1:$PROXY_PORT فعال شد.\e[0m"
}

# 🔗 اتصال به VPN
function connect_vpn() {
    load_config
    echo "$VPN_PASSWORD" | sudo openconnect --background --pid-file="$VPN_PID_FILE" --user="$VPN_USERNAME" "$VPN_SERVER"
    echo -e "\e[92m🔗 VPN فعال شد.\e[0m"
}

# 🔁 فعال‌سازی بعد ری‌استارت
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
    echo -e "\e[96m🔁 اتصال خودکار فعال شد.\e[0m"
}

# 🔒 اجرای خودکار پس از بوت
function auto_start() {
    load_config
    connect_vpn
    sudo systemctl restart privoxy
}

# ⚡ اجرای کامل همه مراحل
function full_auto_setup() {
    welcome_message
    install_dependencies
    create_system_alias
    set_vpn_config
    setup_proxy
    connect_vpn
    enable_autostart
    echo -e "\e[92m🎉 همه‌چیز آماده‌ست! فقط بنویس vpnproxymanager و شروع کن.\e[0m"
}

# 🎮 منوی رنگی
function menu() {
    welcome_message
    create_system_alias
    echo -e "\e[96m╔══════════════════════════════════════╗"
    echo -e "\e[96m║      🚀 VPN + Proxy Setup Menu       ║"
    echo -e "\e[96m╚══════════════════════════════════════╝\e[0m"
    echo -e "\e[92m1️⃣  نصب ابزارهای Cisco VPN و پراکسی\e[0m"
    echo -e "\e[91m2️⃣  حذف کامل تنظیمات و فایل‌ها\e[0m"
    echo -e "\e[93m3️⃣  ورود اطلاعات اتصال VPN\e[0m"
    echo -e "\e[94m4️⃣  ویرایش اطلاعات اتصال VPN\e[0m"
    echo -e "\e[95m5️⃣  ساخت پراکسی روی پورت دلخواه\e[0m"
    echo -e "\e[96m6️⃣  فعال‌سازی اتصال خودکار بعد ری‌استارت\e[0m"
    echo -e "\e[92m7️⃣  اجرای کامل همه مراحل به‌صورت خودکار\e[0m"
    echo -e "\e[90m8️⃣  خروج از منو\e[0m"
    echo ""

    read -p "🎯 گزینه موردنظر رو وارد کن: " choice
    case $choice in
        1) install_dependencies ;;
        2) uninstall_all ;;
        3) set_vpn_config ;;
        4) edit_vpn_config ;;
        5) setup_proxy ;;
        6) enable_autostart ;;
        7) full_auto_setup ;;
        8) exit 0 ;;
        *) echo -e "\e[91m⛔ گزینه نامعتبره!\e[0m" ;;
    esac
}

# اجرای خودکار در بوت
if [[ "$1" == "auto_start" ]]; then
    auto_start
else
    menu
    while true; do
        read -p "⏎ برای ادامه Enter بزن..." dummy
        menu
    done
fi

#!/data/data/com.termux/files/usr/bin/bash

#================================================================
# V2ray CollecSHΞN™ - نسخه با رابط گرافیکی ترمینال
#
# این اسکریپت کانفیگ‌های V2ray, Vmess و Shadowsocks را جمع‌آوری،
# فیلتر و با یک رابط کاربری پیشرفته در ترمینال تست می‌کند.
#================================================================

# --- تعریف رنگ‌ها ---
C_GREEN='\033[1;32m'
C_WHITE='\033[1;37m'
C_RED='\033[1;31m'
C_YELLOW='\033[1;33m'
C_CYAN='\033[1;36m'
C_MAGENTA='\033[1;35m'
C_BLUE='\033[1;34m'
C_NC='\033[0m' # بدون رنگ

# --- تنظیمات اصلی ---
WORKDIR="$HOME/collector_shen"
ALL_CONFIGS_RAW="$WORKDIR/all_configs_raw.txt"
ALL_CONFIGS_DECODED="$WORKDIR/all_configs_decoded.txt"
FILTERED_CONFIGS="$WORKDIR/filtered_configs.txt"
FINAL_OUTPUT="$WORKDIR/valid_configs_shen.txt"
BIN_PATH="$HOME/.local/bin"
SINGBOX_PATH="$BIN_PATH/sing-box"

# لیست لینک‌های اشتراک
SUBS=(
    "https://raw.githubusercontent.com/MatinGhanbari/v2ray-configs/main/subscriptions/v2ray/subs/sub1.txt"
    "https://raw.githubusercontent.com/liketolivefree/kobabi/main/sub.txt"
    "https://raw.githubusercontent.com/mahsanet/MahsaFreeConfig/main/mci/sub_3.txt"
    "https://raw.githubusercontent.com/Mohammadgb0078/IRV2ray/main/vless.txt"
    "https://raw.githubusercontent.com/NiREvil/vless/main/sub/nekobox-wg.txt"
    "https://v2.alicivil.workers.dev/?list=fi&count=200&shuffle=true&unique=false"
    "https://v2.alicivil.workers.dev/?list=us&count=200&shuffle=true&unique=false"
    "https://v2.alicivil.workers.dev/?list=gb&count=200&shuffle=true&unique=false"
    "https://raw.githubusercontent.com/barry-far/V2ray-config/main/Splitted-By-Protocol/vless.txt"
)

#================================================================
# توابع رابط کاربری (UI Functions)
#================================================================

# متغیرهای سراسری برای رابط کاربری
declare -a RESULTS_WINDOW # آرایه‌ای برای نگهداری خطوط نتایج
RESULTS_MAX_LINES=8       # حداکثر تعداد خطوط در پنجره نتایج

# چاپ متن در یک موقعیت مشخص
print_at() {
    tput cup "$1" "$2"
    echo -ne "$3"
}

# رسم کادر در صفحه
draw_box() {
    local row=$1 col=$2 width=$3 height=$4
    local top_left="╭" bottom_left="╰" top_right="╮" bottom_right="╯"
    local horizontal="─" vertical="│"

    # رسم خط بالا
    print_at "$row" "$col" "${C_CYAN}${top_left}"
    for ((i=0; i<width-2; i++)); do echo -n "$horizontal"; done
    echo -n "${top_right}${C_NC}"

    # رسم خطوط عمودی
    for ((i=1; i<height-1; i++)); do
        print_at $((row+i)) "$col" "${C_CYAN}${vertical}${C_NC}"
        print_at $((row+i)) $((col+width-1)) "${C_CYAN}${vertical}${C_NC}"
    done

    # رسم خط پایین
    print_at $((row+height-1)) "$col" "${C_CYAN}${bottom_left}"
    for ((i=0; i<width-2; i++)); do echo -n "$horizontal"; done
    echo -n "${bottom_right}${C_NC}"
}

# راه‌اندازی و رسم ساختار کلی رابط کاربری
setup_ui() {
    clear
    tput civis # مخفی کردن نشانگر

    local width
    width=$(tput cols)
    ((width--))

    # 1. هدر
    print_at 1 2 "${C_CYAN}V2ray CollecSHΞN™ ${C_WHITE}| ${C_YELLOW}نسخه گرافیکی${C_NC}"
    print_at 2 1 "${C_CYAN}──────────────────────────────────────────────────────────────────${C_NC}"

    # 2. کادر آمار
    draw_box 3 1 40 4
    print_at 3 3 "${C_WHITE}📊 آمار زنده${C_NC}"

    # 3. کادر نتایج
    draw_box 7 1 "$width" $((RESULTS_MAX_LINES + 2))
    print_at 7 3 "${C_WHITE}📡 نتایج تست (کانفیگ‌های سالم)${C_NC}"

    # 4. کادر وضعیت و راهنما
    draw_box $((8 + RESULTS_MAX_LINES + 1)) 1 "$width" 3
    print_at $((8 + RESULTS_MAX_LINES + 2)) 3 "${C_YELLOW}کلیدها: ${C_WHITE}[p] توقف/ادامه ${C_CYAN}| ${C_WHITE}[q] خروج و ذخیره${C_NC}"
}

# به‌روزرسانی پنل آمار
update_status() {
    local checked=$1 valid=$2 total=$3
    local status_text="${C_BLUE}تست شده: ${C_WHITE}$checked${C_NC} / ${C_BLUE}کل: ${C_WHITE}$total ${C_CYAN}| ${C_GREEN}سالم: ${C_WHITE}$valid${C_NC}"
    print_at 5 3 "$status_text\033[K"
}

# افزودن یک خط نتیجه به پنجره نتایج
add_result_line() {
    # اگر پنجره پر است، خط اول را حذف کن
    if ((${#RESULTS_WINDOW[@]} >= RESULTS_MAX_LINES)); then
        RESULTS_WINDOW=("${RESULTS_WINDOW[@]:1}")
    fi
    RESULTS_WINDOW+=("$1")

    # پنجره نتایج را دوباره رسم کن
    for i in "${!RESULTS_WINDOW[@]}"; do
        print_at $((8 + i)) 3 "${RESULTS_WINDOW[$i]}\033[K"
    done
}

# به‌روزرسانی نوار پیشرفت و وضعیت
update_progress() {
    local percent=$1 status_msg=$2 width
    width=$(tput cols)
    
    local bar_width=$((width - 14))
    local filled_len=$((percent * bar_width / 100))
    
    local bar="["
    for ((i=0; i<bar_width; i++)); do
        if ((i < filled_len)); then bar+="${C_GREEN}█${C_NC}"; else bar+="${C_WHITE}·${C_NC}"; fi
    done
    bar+="]"

    print_at $((8 + RESULTS_MAX_LINES)) 3 "${C_WHITE}${percent}% ${bar}${C_NC}\033[K"
    print_at $((8 + RESULTS_MAX_LINES + 2)) 50 "${C_YELLOW}${status_msg}${C_NC}\033[K"
}

#================================================================
# توابع اصلی اسکریپت
#================================================================

# (توابع install_dependencies, install_singbox, create_test_config از اسکریپت قبلی بدون تغییر اینجا کپی می‌شوند)
# ... (برای اختصار، این توابع در اینجا نمایش داده نمی‌شوند اما در فایل نهایی باید وجود داشته باشند) ...
# Function to check and install necessary packages
install_dependencies() {
    echo -e "${C_YELLOW}Checking for required packages...${C_NC}"
    local packages_needed=()
    for pkg in curl jq base64 grep sed awk; do
        if ! command -v "$pkg" &>/dev/null; then
            packages_needed+=("$pkg")
        fi
    done

    if [ ${#packages_needed[@]} -gt 0 ]; then
        echo -e "${C_YELLOW}Installing: ${packages_needed[*]}${C_NC}"
        pkg install -y "${packages_needed[@]}"
    else
        echo -e "${C_GREEN}All packages are already installed.${C_NC}"
    fi
}

# Function to install or update sing-box
install_singbox() {
    echo -e "${C_YELLOW}Checking for sing-box...${C_NC}"
    mkdir -p "$BIN_PATH"
    local arch
    case $(uname -m) in
        "aarch64") arch="arm64" ;;
        "armv7l" | "armv8l") arch="armv7" ;;
        "x86_64") arch="amd64" ;;
        *) echo -e "${C_RED}Unsupported architecture: $(uname -m)${C_NC}"; exit 1 ;;
    esac
    local arch_name="linux-${arch}"
    local latest_version=$(curl -sL "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | jq -r .tag_name)
    if [[ -z "$latest_version" ]]; then echo -e "${C_RED}Could not fetch sing-box version.${C_NC}"; exit 1; fi
    local installed_version=""
    if [[ -f "$SINGBOX_PATH" ]]; then installed_version=$($SINGBOX_PATH version | awk '/sing-box version/ {print "v"$3}'); fi
    if [[ "$installed_version" == "$latest_version" ]]; then echo -e "${C_GREEN}sing-box is up to date (${latest_version}).${C_NC}"; return; fi
    echo -e "${C_YELLOW}Downloading sing-box ${latest_version}...${C_NC}"
    local file_name="sing-box-${latest_version#v}-${arch_name}.tar.gz"
    local download_url="https://github.com/SagerNet/sing-box/releases/download/${latest_version}/${file_name}"
    curl -sL -o "/tmp/sb.tar.gz" "$download_url" && tar -xzf "/tmp/sb.tar.gz" -C "/tmp/" && \
    mv "/tmp/sing-box-${latest_version#v}-${arch_name}/sing-box" "$SINGBOX_PATH" && \
    chmod +x "$SINGBOX_PATH" && rm -rf "/tmp/sb.tar.gz" "/tmp/sing-box-"* && \
    echo -e "${C_GREEN}sing-box installed successfully.${C_NC}" || { echo -e "${C_RED}Failed to install sing-box.${C_NC}"; exit 1; }
}

# Function to create a temporary sing-box config for testing
create_test_config() {
    local config_uri="$1"
    local temp_json_path="$2"
    "$SINGBOX_PATH" parse -j "$config_uri" > "$WORKDIR/proxy.json"
    if [[ ! -s "$WORKDIR/proxy.json" ]]; then return 1; fi
    jq --argfile proxy "$WORKDIR/proxy.json" \
       '{log: {level: "error"}, inbounds: [{type: "tun", tag: "tun-in"}], outbounds: [$proxy, {tag: "urltest", type: "urltest", outbounds: ["proxy"], url: "http://cp.cloudflare.com/"}]}' \
       > "$temp_json_path"
    rm "$WORKDIR/proxy.json"
    return 0
}


# --- نقطه شروع اصلی اسکریپت ---

# 0. آماده‌سازی اولیه
clear
echo -e "${C_CYAN}به V2ray CollecSHΞN خوش آمدید!${C_NC}"
install_dependencies
install_singbox
mkdir -p "$WORKDIR"
: > "$ALL_CONFIGS_RAW"
: > "$FINAL_OUTPUT"
echo -e "${C_YELLOW}برای شروع، Enter را بزنید...${C_NC}"
read -r

# 1. جمع‌آوری کانفیگ‌ها
clear
echo -e "\n${C_CYAN}1. در حال جمع‌آوری کانفیگ‌ها از ${#SUBS[@]} منبع...${C_NC}"
for LINK in "${SUBS[@]}"; do
    echo -e "   -> ${C_YELLOW}$LINK${C_NC}"
    curl -sL --max-time 15 "$LINK" >> "$ALL_CONFIGS_RAW"
    echo "" >> "$ALL_CONFIGS_RAW"
done

# 2. پردازش و فیلتر کردن
echo -e "${C_CYAN}2. در حال پردازش و آماده‌سازی کانفیگ‌ها...${C_NC}"
awk '{if ($0 ~ /^[A-Za-z0-9+/=]{20,}/) {print $0 | "base64 -d 2>/dev/null"} else {print $0}}' "$ALL_CONFIGS_RAW" > "$ALL_CONFIGS_DECODED"
grep -E '^(vless|vmess|ss)://' "$ALL_CONFIGS_DECODED" | sed -e 's/#.*//' -e 's/\r$//' | sort -u > "$FILTERED_CONFIGS"
TOTAL_FOUND=$(wc -l < "$FILTERED_CONFIGS")
echo -e "${C_GREEN}   -> ${TOTAL_FOUND} کانفیگ منحصر به فرد پیدا شد.${C_NC}"

# 3. انتخاب پروتکل توسط کاربر
echo -e "\n${C_CYAN}3. پروتکل مورد نظر برای تست را انتخاب کنید:${C_NC}"
echo -e "   ${C_WHITE}1) vless${C_NC}"
echo -e "   ${C_WHITE}2) vmess${C_NC}"
echo -e "   ${C_WHITE}3) shadowsocks (ss)${C_NC}"
echo -e "   ${C_WHITE}4) همه پروتکل‌ها${C_NC}"
read -p "   انتخاب شما [1-4]: " CHOICE
case $CHOICE in
    1) PATTERN='^vless://';; 2) PATTERN='^vmess://';;
    3) PATTERN='^ss://';; 4) PATTERN='^(vless|vmess|ss)://';;
    *) echo -e "${C_RED}ورودی نامعتبر است.${C_NC}"; exit 1;;
esac
TEMP_SELECTED_CONFIGS="$WORKDIR/selected_for_test.txt"
grep -E "$PATTERN" "$FILTERED_CONFIGS" > "$TEMP_SELECTED_CONFIGS"

# 4. شروع فرآیند تست با رابط گرافیکی
TOTAL_TO_TEST=$(wc -l < "$TEMP_SELECTED_CONFIGS")
VALID_COUNT=0
CHECKED_COUNT=0
STATE="run"

# خواندن ورودی کاربر در پس‌زمینه برای کنترل برنامه
handle_input() {
    while true; do
        read -rsn1 input
        if [[ "$input" == "p" || "$input" == "P" ]]; then
            [[ "$STATE" == "run" ]] && STATE="pause" || STATE="run"
        elif [[ "$input" == "q" || "$input" == "Q" ]]; then
            STATE="quit"
        fi
    done
}
handle_input &
INPUT_PID=$!
trap 'tput cnorm; kill $INPUT_PID &>/dev/null; clear; exit' EXIT

setup_ui

while IFS= read -r CONFIG || [[ -n "$CONFIG" ]]; do
    while [[ "$STATE" == "pause" ]]; do
        update_progress "$PERCENT" "متوقف شده..."
        sleep 0.5
    done
    [[ "$STATE" == "quit" ]] && break

    ((CHECKED_COUNT++))
    PERCENT=$((CHECKED_COUNT * 100 / TOTAL_TO_TEST))
    update_status "$CHECKED_COUNT" "$VALID_COUNT" "$TOTAL_TO_TEST"
    update_progress "$PERCENT" "در حال تست..."

    TMP_JSON="$WORKDIR/test_$(date +%s%N).json"
    create_test_config "$CONFIG" "$TMP_JSON"
    if [[ $? -ne 0 ]]; then
        rm -f "$TMP_JSON"
        continue
    fi
    
    # اجرا تست با sing-box و گرفتن پینگ
    DELAY_MS=$(timeout 8s "$SINGBOX_PATH" urltest -c "$TMP_JSON" -o "proxy" 2>/dev/null | awk '/ms/ {print $2}' | tr -d 'ms')
    rm -f "$TMP_JSON"

    if [[ "$DELAY_MS" =~ ^[0-9]+$ && "$DELAY_MS" -le 2000 ]]; then
        ((VALID_COUNT++))
        HOST=$(echo "$CONFIG" | sed -E 's|.*@([^:/?#]+).*|\1|' | head -n1)
        REMARK="☬SHΞN™-${DELAY_MS}ms"
        REMARK_ENCODED=$(printf %s "$REMARK" | jq -sRr @uri)
        echo "${CONFIG}#${REMARK_ENCODED}" >> "$FINAL_OUTPUT"
        
        # نمایش نتیجه در پنجره نتایج
        RESULT_LINE="${C_GREEN}✓ ${C_WHITE}${HOST} ${C_CYAN}- ${C_YELLOW}${DELAY_MS}ms${C_NC}"
        add_result_line "$RESULT_LINE"
    fi
done < "$TEMP_SELECTED_CONFIGS"

# 5. پایان و نمایش خلاصه
tput cnorm # نمایش دوباره نشانگر
clear
echo -e "\n\n${C_GREEN}===========================================${C_NC}"
echo -e "${C_CYAN}          ✔ فرآیند تست کامل شد ✔          ${C_NC}"
echo -e "${C_GREEN}===========================================${C_NC}\n"
echo -e "  ${C_BLUE}تعداد کل کانفیگ‌های بررسی شده: ${C_WHITE}$CHECKED_COUNT${C_NC}"
echo -e "  ${C_GREEN}تعداد کانفیگ‌های سالم یافت شده: ${C_WHITE}$VALID_COUNT${C_NC}\n"
echo -e "  ${C_WHITE}✔ نتایج در فایل زیر ذخیره شد:${C_NC}"
echo -e "  ${C_YELLOW}$FINAL_OUTPUT${C_NC}\n"

# پاکسازی فایل‌های موقت
rm -f "$ALL_CONFIGS_RAW" "$ALL_CONFIGS_DECODED" "$FILTERED_CONFIGS" "$TEMP_SELECTED_CONFIGS"

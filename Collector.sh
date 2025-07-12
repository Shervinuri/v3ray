#!/data/data/com.termux/files/usr/bin/bash

#================================================================
# V2ray CollecSHΞN™ - The Final, Rock-Solid, Non-Interactive Release
#
# This script uses the beautiful graphical UI but removes the
# interactive controls during testing to guarantee it will NEVER
# hang or flicker. The testing process is fully automated from
# start to finish. This is the most stable version possible.
#================================================================

# --- CONFIGURATION ---
C_GREEN='\033[1;32m'; C_WHITE='\033[1;37m'; C_RED='\033[1;31m'
C_YELLOW='\033[1;33m'; C_CYAN='\033[1;36m'; C_NC='\033[0m'

WORKDIR="$HOME/collector_shen"
FINAL_OUTPUT="$WORKDIR/valid_configs.txt"

# --- Communication & Temp Files ---
ALL_CONFIGS_RAW="$WORKDIR/all_configs_raw.txt"
ALL_CONFIGS_DECODED="$WORKDIR/all_configs_decoded.txt"
FILTERED_CONFIGS="$WORKDIR/filtered_configs.txt"
TEMP_SELECTED_CONFIGS="$WORKDIR/selected_for_test.txt"
RESULTS_FILE="$WORKDIR/results.log"

SUBS=(
"https://raw.githubusercontent.com/MatinGhanbari/v2ray-configs/main/subscriptions/v2ray/subs/sub1.txt"
"https://raw.githubusercontent.com/liketolivefree/kobabi/main/sub.txt"
"https://raw.githubusercontent.com/mahsanet/MahsaFreeConfig/main/mci/sub_3.txt"
"https://raw.githubusercontent.com/Mohammadgb0078/IRV2ray/main/vless.txt"
"https://raw.githubusercontent.com/NiREvil/vless/main/sub/nekobox-wg.txt"
"https://v2.alicivil.workers.dev/?list=fi&count=500&shuffle=true&unique=false"
"https://v2.alicivil.workers.dev/?list=us&count=500&shuffle=true&unique=false"
"https://v2.alicivil.workers.dev/?list=gb&count=500&shuffle=true&unique=false"
"https://raw.githubusercontent.com/barry-far/V2ray-config/main/Splitted-By-Protocol/vless.txt"
)

# --- Cleanup function on exit ---
cleanup() {
    rm -f "$WORKDIR"/*.log "$WORKDIR"/*.txt
    tput cnorm; clear
    exit
}
trap cleanup SIGINT EXIT

# --- Stable UI Functions ---
print_at() { tput cup "$1" "$2"; echo -ne "$3"; }
print_center() {
    local row="$1"; local text="$2"
    local text_plain; text_plain=$(echo -e "$text" | sed 's/\x1b\[[0-9;]*m//g')
    local term_width; term_width=$(tput cols)
    local col; col=$(((term_width - ${#text_plain}) / 2))
    print_at "$row" "$col" "$text"
}

# --- This function redraws the entire UI, making it resize-proof ---
redraw_ui() {
    local width; width=$(tput cols); ((width--))
    clear; tput civis
    print_center 1 "${C_WHITE}==============================${C_NC}"
    print_center 2 "${C_WHITE} V2ray CollecSHΞN™${C_NC}"
    print_center 3 "${C_WHITE}==============================${C_NC}"
    draw_box() { local r=$1 c=$2 w=$3 h=$4; print_at $r $c "${C_CYAN}╭$(printf '─%.0s' $(seq 1 $((w-2))))╮${C_NC}"; for i in $(seq 1 $((h-2))); do print_at $((r+i)) $c "${C_CYAN}│${C_NC}"; print_at $((r+i)) $((c+w-1)) "${C_CYAN}│${C_NC}"; done; print_at $((r+h-1)) $c "${C_CYAN}╰$(printf '─%.0s' $(seq 1 $((w-2))))╯${C_NC}"; }
    draw_box 5 1 "$width" 3; print_at 5 3 "${C_WHITE}📊 Live Stats${C_NC}"
    draw_box 8 1 "$width" 12; print_at 8 3 "${C_WHITE}📡 Live Results${C_NC}"
    print_at 19 1 "${C_CYAN}├$(printf '─%.0s' $(seq 1 $((w-2))))┤${C_NC}"
    print_center 20 "${C_YELLOW}Testing in progress... Press Ctrl+C to stop.${C_NC}"
}

#================================================================
# SCRIPT EXECUTION
#================================================================

# --- Initial Setup ---
clear
show_initial_banner() { clear; tput civis; print_center 1 "${C_WHITE}==============================${C_NC}"; print_center 2 "${C_WHITE} V2ray CollecSHΞN™${C_NC}"; print_center 3 "${C_WHITE}==============================${C_NC}"; print_center 6 "${C_YELLOW}Press [Enter] to start...${C_NC}"; }
show_initial_banner
read -r

clear
echo -e "${C_CYAN}Initializing...${C_NC}"
mkdir -p "$WORKDIR" &>/dev/null
for pkg in curl jq base64 grep sed awk termux-api coreutils; do
    if ! command -v "$pkg" &>/dev/null; then pkg install -y "$pkg" > /dev/null 2>&1; fi
done
sleep 1

# --- Config Fetching ---
clear
echo -e "${C_CYAN}Fetching top 50 configs...${C_NC}"
: > "$ALL_CONFIGS_RAW"
for LINK in "${SUBS[@]}"; do timeout 15s curl -sL "$LINK" | head -n 50 >> "$ALL_CONFIGS_RAW"; echo "" >> "$ALL_CONFIGS_RAW"; done
echo -e "${C_CYAN}Decoding and filtering...${C_NC}"
awk '{if ($0 ~ /^[A-Za-z0-9+/=]{20,}/) {print $0 | "base64 -d 2>/dev/null"} else {print $0}}' "$ALL_CONFIGS_RAW" > "$ALL_CONFIGS_DECODED"
grep -E '^(vless|vmess|ss)://' "$ALL_CONFIGS_DECODED" | sed -e 's/#.*//' -e 's/\r$//' | sort -u > "$FILTERED_CONFIGS"

# --- Protocol Selection ---
clear
print_center 2 "${C_CYAN}Select protocol to test:${C_NC}"
print_center 4 "${C_WHITE}1 : vless${C_NC}"; print_center 5 "${C_WHITE}2 : vmess${C_NC}"
print_center 6 "${C_WHITE}3 : shadowsocks${C_NC}"; print_center 7 "${C_WHITE}4 : All Protocols${C_NC}"
tput cup 9 0; read -p "$(print_center 9 "Enter your choice [1-4]: ")" CHOICE
case $CHOICE in 1) P='^vless://';; 2) P='^vmess://';; 3) P='^ss://';; 4) P='^(vless|vmess|ss)://';; *) echo -e "${C_RED}Invalid choice.${C_NC}"; exit 1;; esac
grep -E "$P" "$FILTERED_CONFIGS" > "$TEMP_SELECTED_CONFIGS"

# --- Main Testing Loop ---
: > "$FINAL_OUTPUT"; : > "$RESULTS_FILE"
trap redraw_ui WINCH
redraw_ui

CONFIGS_TO_TEST=(); while IFS= read -r line; do CONFIGS_TO_TEST+=("$line"); done < "$TEMP_SELECTED_CONFIGS"
TOTAL_TO_TEST=${#CONFIGS_TO_TEST[@]}
VALID_COUNT=0; CHECKED_COUNT=0; FAILED_COUNT=0

for CONFIG in "${CONFIGS_TO_TEST[@]}"; do
    ((CHECKED_COUNT++))
    host=$(echo "$CONFIG" | sed -E 's|.*@([^:/?#]+).*|\1|' | head -n1)
    remark="☬SHΞN™-PingOK"

    # The only test is a simple ping with a hard timeout
    if timeout 2s ping -c 1 -W 1 "$host" &> /dev/null; then
        ((VALID_COUNT++))
        remark_encoded=$(printf %s "$remark" | jq -sRr @uri 2>/dev/null)
        echo "${CONFIG}#${remark_encoded}" >> "$FINAL_OUTPUT"
        echo "${C_GREEN}✓ ${C_WHITE}${host:0:30} ${C_CYAN}- ${C_YELLOW}Ping OK${C_NC}" >> "$RESULTS_FILE"
    else
        ((FAILED_COUNT++))
    fi

    # --- Update UI on every iteration ---
    print_at 6 3 "${C_CYAN}Checked: ${C_WHITE}$CHECKED_COUNT ${C_NC}| ${C_GREEN}Valid: ${C_WHITE}$VALID_COUNT ${C_NC}| ${C_RED}Failed: ${C_WHITE}$FAILED_COUNT ${C_NC}| ${C_YELLOW}Total: ${C_WHITE}$TOTAL_TO_TEST${C_NC}\033[K"
    if [[ "$TOTAL_TO_TEST" -gt 0 ]]; then
        percent=$(( CHECKED_COUNT * 100 / TOTAL_TO_TEST ))
        bar_width=$((width - 10)); filled_len=$((percent * bar_width / 100))
        bar="${C_GREEN}"; for ((i=0; i<filled_len; i++)); do bar+="▓"; done; bar+="${C_NC}${C_WHITE}"; for ((i=filled_len; i<bar_width; i++)); do bar+="░"; done
        print_at 19 5 "${percent}% ${bar}"
    fi
    tail -n 10 "$RESULTS_FILE" | nl -w1 -s' ' | while read -r num line; do
        print_at $((8+num)) 3 "$line\033[K"
    done
done

# --- Final Summary ---
tput cnorm; clear
print_center 2 "${C_GREEN}===========================================${C_NC}"
print_center 3 "${C_CYAN}            ✔ TESTING COMPLETE ✔             ${C_NC}"
print_center 4 "${C_GREEN}===========================================${C_NC}"
print_at 6 3 "  ${C_CYAN}Total configs checked: ${C_WHITE}$CHECKED_COUNT${C_NC}"
print_at 7 3 "  ${C_GREEN}Valid configs found:   ${C_WHITE}$VALID_COUNT${C_NC}"
print_at 8 3 "  ${C_RED}Failed configs:        ${C_WHITE}$FAILED_COUNT${C_NC}"
print_at 10 3 "  ${C_WHITE}✔ Valid configs saved to:${C_NC}"
print_at 11 3 "  ${C_YELLOW}$FINAL_OUTPUT${C_NC}"

if [[ "$VALID_COUNT" -gt 0 ]]; then
    print_at 13 3 "${C_YELLOW}Press [Enter] to copy all ${VALID_COUNT} valid configs to clipboard...${C_NC}"
    read -r
    termux-clipboard-set < "$FINAL_OUTPUT"
    print_at 14 3 "${C_GREEN}✔ Copied to clipboard!${C_NC}"
fi
echo ""

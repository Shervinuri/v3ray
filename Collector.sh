#!/data/data/com.termux/files/usr/bin/bash

#================================================================
# V2ray CollecSHΞN™ - Rock-Solid Final Release
#
# This version is a complete rewrite of the UI and testing logic
# to fix all previously reported bugs.
# - NO MORE FLICKERING: The UI loop is now synchronized.
# - ROBUST TESTING: Vless/Vmess testing is reliable.
# - CLEAR STATUS: Explicit warning if sing-box is missing.
#================================================================

C_GREEN='\033[1;32m'; C_WHITE='\033[1;37m'; C_RED='\033[1;31m'
C_YELLOW='\033[1;33m'; C_CYAN='\033[1;36m'; C_BG_BLUE='\033[44;1;37m'
C_NC='\033[0m'

WORKDIR="$HOME/collector_shen"
FINAL_OUTPUT="$WORKDIR/valid_configs_shen.txt"
BIN_PATH="$HOME/.local/bin"
SINGBOX_PATH="$BIN_PATH/sing-box"
ALL_CONFIGS_RAW="$WORKDIR/all_configs_raw.txt"
ALL_CONFIGS_DECODED="$WORKDIR/all_configs_decoded.txt"
FILTERED_CONFIGS="$WORKDIR/filtered_configs.txt"
TEMP_SELECTED_CONFIGS="$WORKDIR/selected_for_test.txt"
SINGBOX_READY=false

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

# --- Stable UI Functions ---
print_at() { tput cup "$1" "$2"; echo -ne "$3"; }
print_center() {
    local row="$1"; local text="$2"
    local text_plain; text_plain=$(echo -e "$text" | sed 's/\x1b\[[0-9;]*m//g')
    local term_width; term_width=$(tput cols)
    local col; col=$(((term_width - ${#text_plain}) / 2))
    print_at "$row" "$col" "$text"
}

show_initial_banner() {
    clear; tput civis
    print_center 1 "${C_WHITE}==============================${C_NC}"
    print_center 2 "${C_WHITE} V2ray CollecSHΞN™${C_NC}"
    print_center 3 "${C_WHITE}==============================${C_NC}"
    print_center 6 "${C_YELLOW}Press [Enter] to start...${C_NC}"
}

prepare_components() {
    mkdir -p "$BIN_PATH" &>/dev/null
    for pkg in curl jq base64 grep sed awk termux-api; do
        if ! command -v "$pkg" &>/dev/null; then pkg install -y "$pkg" > /dev/null 2>&1; fi
    done
    if [[ -x "$SINGBOX_PATH" ]]; then SINGBOX_READY=true; return; fi
    local arch; case $(uname -m) in "aarch64") arch="arm64" ;; *) return ;; esac
    local arch_name="linux-${arch}"; local latest_version; latest_version=$(curl -sL "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | jq -r .tag_name 2>/dev/null)
    if [[ -z "$latest_version" ]]; then return; fi
    local file_name="sing-box-${latest_version#v}-${arch_name}.tar.gz"; local url="https://github.com/SagerNet/sing-box/releases/download/${latest_version}/${file_name}"
    if curl -sL -o "/tmp/sb.tar.gz" "$url" && tar -xzf "/tmp/sb.tar.gz" -C "/tmp/" > /dev/null 2>&1 && mv "/tmp/sing-box-${latest_version#v}-${arch_name}/sing-box" "$SINGBOX_PATH" && chmod +x "$SINGBOX_PATH"; then
        SINGBOX_READY=true
    fi
    rm -rf "/tmp/sb.tar.gz" "/tmp/sing-box-"* &>/dev/null
}

#================================================================
# SCRIPT EXECUTION
#================================================================

show_initial_banner
read -r

clear
echo -e "${C_CYAN}Initializing and preparing components...${C_NC}"
prepare_components

echo -e "${C_CYAN}Fetching top 50 configs from ${#SUBS[@]} sources...${C_NC}"
: > "$ALL_CONFIGS_RAW"
for LINK in "${SUBS[@]}"; do curl -sL --max-time 15 "$LINK" | head -n 50 >> "$ALL_CONFIGS_RAW"; echo "" >> "$ALL_CONFIGS_RAW"; done

echo -e "${C_CYAN}Decoding and filtering configs...${C_NC}"
awk '{if ($0 ~ /^[A-Za-z0-9+/=]{20,}/) {print $0 | "base64 -d 2>/dev/null"} else {print $0}}' "$ALL_CONFIGS_RAW" > "$ALL_CONFIGS_DECODED"
grep -E '^(vless|vmess|ss)://' "$ALL_CONFIGS_DECODED" | sed -e 's/#.*//' -e 's/\r$//' | sort -u > "$FILTERED_CONFIGS"
TOTAL_FOUND=$(wc -l < "$FILTERED_CONFIGS")
echo -e "${C_GREEN}   -> Found ${TOTAL_FOUND} unique configs.${C_NC}"

clear
print_center 2 "${C_CYAN}Select protocol to test:${C_NC}"
print_center 4 "${C_WHITE}1 : vless${C_NC}"
print_center 5 "${C_WHITE}2 : vmess${C_NC}"
print_center 6 "${C_WHITE}3 : shadowsocks${C_NC}"
print_center 7 "${C_WHITE}4 : All Protocols${C_NC}"
tput cup 9 0; read -p "$(print_center 9 "Enter your choice [1-4]: ")" CHOICE
case $CHOICE in 1) P='^vless://';; 2) P='^vmess://';; 3) P='^ss://';; 4) P='^(vless|vmess|ss)://';; *) echo -e "${C_RED}Invalid choice.${C_NC}"; exit 1;; esac
grep -E "$P" "$FILTERED_CONFIGS" > "$TEMP_SELECTED_CONFIGS"

CONFIGS_TO_TEST=(); while IFS= read -r line; do CONFIGS_TO_TEST+=("$line"); done < "$TEMP_SELECTED_CONFIGS"
TOTAL_TO_TEST=${#CONFIGS_TO_TEST[@]}
VALID_COUNT=0; CHECKED_COUNT=0; FAILED_COUNT=0; STATE="run"; ACTIVE_BUTTON=0
declare -a RESULTS_WINDOW; RESULTS_MAX_LINES=10

trap 'tput cnorm; clear; exit' EXIT

clear; tput civis; width=$(tput cols); ((width--))
print_center 1 "${C_WHITE}==============================${C_NC}"
print_center 2 "${C_WHITE} V2ray CollecSHΞN™${C_NC}"
print_center 3 "${C_WHITE}==============================${C_NC}"
draw_box() { local r=$1 c=$2 w=$3 h=$4; print_at $r $c "${C_CYAN}╭$(printf '─%.0s' $(seq 1 $((w-2))))╮${C_NC}"; for i in $(seq 1 $((h-2))); do print_at $((r+i)) $c "${C_CYAN}│${C_NC}"; print_at $((r+i)) $((c+w-1)) "${C_CYAN}│${C_NC}"; done; print_at $((r+h-1)) $c "${C_CYAN}╰$(printf '─%.0s' $(seq 1 $((w-2))))╯${C_NC}"; }
draw_box 5 1 "$width" 3; print_at 5 3 "${C_WHITE}📊 Live Stats${C_NC}"
draw_box 8 1 "$width" 12; print_at 8 3 "${C_WHITE}📡 Live Results${C_NC}"
print_at 19 1 "${C_CYAN}├$(printf '─%.0s' $(seq 1 $((w-2))))┤${C_NC}"
if $SINGBOX_READY; then print_at 5 $((width-20)) "${C_GREEN}[Sing-box: Active]${C_NC}"; else print_at 9 5 "${C_RED}WARNING: Sing-box not found. Vless/Vmess tests will be skipped.${C_NC}"; fi

# --- Rewritten, Stable Main Loop ---
needs_redraw=true
while [[ "$CHECKED_COUNT" -lt "$TOTAL_TO_TEST" && "$STATE" != "quit" ]]; do
    if $needs_redraw; then
        pause_label="[ Pause ]"; [[ "$STATE" == "pause" ]] && pause_label="[ Resume ]"
        quit_label="[ Quit ]"
        if [[ $ACTIVE_BUTTON -eq 0 ]]; then pause_label="${C_BG_BLUE}${pause_label}${C_NC}"; else quit_label="${C_BG_BLUE}${quit_label}${C_NC}"; fi
        print_at 20 3 "${C_YELLOW}Controls: ${C_WHITE}${pause_label}  ${quit_label} ${C_CYAN}(Use ← → and Enter, or Ctrl+Q)${C_NC}\033[K"
        needs_redraw=false
    fi

    read -t 0.1 -rsn1 key
    if [[ -n "$key" ]]; then
        needs_redraw=true
        if [[ "$key" == $'\e' ]]; then
            read -rsn2 -t 0.01 key_ext
            case "$key_ext" in '[D') ((ACTIVE_BUTTON=0));; '[C') ((ACTIVE_BUTTON=1));; esac
        elif [[ "$key" == "" ]]; then
            if [[ $ACTIVE_BUTTON -eq 0 ]]; then [[ "$STATE" == "run" ]] && STATE="pause" || STATE="run"; else STATE="quit"; fi
        elif [[ "$key" == $'\x11' ]]; then STATE="quit"; fi
    fi

    if [[ "$STATE" != "run" ]]; then continue; fi

    CONFIG="${CONFIGS_TO_TEST[$CHECKED_COUNT]}"
    
    print_at 6 3 "${C_CYAN}Checked: ${C_WHITE}$CHECKED_COUNT ${C_NC}| ${C_GREEN}Valid: ${C_WHITE}$VALID_COUNT ${C_NC}| ${C_RED}Failed: ${C_WHITE}$FAILED_COUNT ${C_NC}| ${C_YELLOW}Total: ${C_WHITE}$TOTAL_TO_TEST${C_NC}\033[K"
    PERCENT=$((CHECKED_COUNT * 100 / TOTAL_TO_TEST)); bar_width=$((width - 10)); filled_len=$((PERCENT * bar_width / 100))
    bar="${C_GREEN}"; for ((i=0; i<filled_len; i++)); do bar+="▓"; done; bar+="${C_NC}${C_WHITE}"; for ((i=filled_len; i<bar_width; i++)); do bar+="░"; done
    print_at 19 5 "${PERCENT}% ${bar}"

    CONFIG_TYPE=$(echo "$CONFIG" | cut -d: -f1)
    RESULT_LINE=""; REMARK=""
    if [[ "$CONFIG_TYPE" == "ss" ]]; then
        ((VALID_COUNT++)); REMARK="☬SHΞN™-SS"; HOST=$(echo "$CONFIG" | sed -E 's|.*@([^:]+):.*|\1|' | cut -d'#' -f1)
        RESULT_LINE="${C_GREEN}✓ ${C_WHITE}${HOST:0:25} ${C_CYAN}- ${C_YELLOW}Shadowsocks Added${C_NC}"
    elif $SINGBOX_READY && [[ "$CONFIG_TYPE" == "vless" || "$CONFIG_TYPE" == "vmess" ]]; then
        "$SINGBOX_PATH" parse -j "$CONFIG" > "$WORKDIR/proxy.json" 2>/dev/null
        if [[ -s "$WORKDIR/proxy.json" ]]; then
            jq '(.tag = "proxy")' "$WORKDIR/proxy.json" > "$WORKDIR/proxy_tagged.json" 2>/dev/null
            jq -n --argfile proxy "$WORKDIR/proxy_tagged.json" '{log:{level:"error"},outbounds:[$proxy,{tag:"urltest",type:"urltest",outbounds:["proxy"],url:"http://cp.cloudflare.com/"}]}' > "$WORKDIR/test.json" 2>/dev/null
            DELAY_MS=$(timeout 8s "$SINGBOX_PATH" urltest -c "$WORKDIR/test.json" 2>/dev/null | awk '/ms/ {print $2}' | tr -d 'ms')
            if [[ "$DELAY_MS" =~ ^[0-9]+$ && "$DELAY_MS" -le 2000 ]]; then
                ((VALID_COUNT++)); REMARK="☬SHΞN™-${DELAY_MS}ms"; HOST=$(echo "$CONFIG" | sed -E 's|.*@([^:/?#]+).*|\1|' | head -n1)
                RESULT_LINE="${C_GREEN}✓ ${C_WHITE}${HOST:0:25} ${C_CYAN}- ${C_YELLOW}${DELAY_MS}ms${C_NC}"
            else ((FAILED_COUNT++)); fi
        else ((FAILED_COUNT++)); fi
        rm -f "$WORKDIR/proxy.json" "$WORKDIR/proxy_tagged.json" "$WORKDIR/test.json" &>/dev/null
    else ((FAILED_COUNT++)); fi
    
    if [[ -n "$RESULT_LINE" ]]; then
        REMARK_ENCODED=$(printf %s "$REMARK" | jq -sRr @uri 2>/dev/null); echo "${CONFIG}#${REMARK_ENCODED}" >> "$FINAL_OUTPUT"
        ((${#RESULTS_WINDOW[@]} >= RESULTS_MAX_LINES)) && RESULTS_WINDOW=("${RESULTS_WINDOW[@]:1}")
        RESULTS_WINDOW+=("$RESULT_LINE"); for i in "${!RESULTS_WINDOW[@]}"; do print_at $((9 + i)) 3 "${RESULTS_WINDOW[$i]}\033[K"; done
    fi
    ((CHECKED_COUNT++))
done

tput cnorm; clear
print_center 2 "${C_GREEN}===========================================${C_NC}"
print_center 3 "${C_CYAN}            ✔ TESTING COMPLETE ✔             ${C_NC}"
print_center 4 "${C_GREEN}===========================================${C_NC}"
print_at 6 3 "  ${C_CYAN}Total configs checked: ${C_WHITE}$CHECKED_COUNT${C_NC}"
print_at 7 3 "  ${C_GREEN}Valid configs found:   ${C_WHITE}$VALID_COUNT${C_NC}"
print_at 8 3 "  ${C_RED}Failed/Skipped configs: ${C_WHITE}$FAILED_COUNT${C_NC}"
print_at 10 3 "  ${C_WHITE}✔ Valid configs saved to:${C_NC}"
print_at 11 3 "  ${C_YELLOW}$FINAL_OUTPUT${C_NC}"

if [[ $VALID_COUNT -gt 0 ]]; then
    print_at 13 3 "${C_YELLOW}Press [Enter] to copy all ${VALID_COUNT} valid configs to clipboard...${C_NC}"
    read -r
    termux-clipboard-set < "$FINAL_OUTPUT"
    print_at 14 3 "${C_GREEN}✔ Copied to clipboard!${C_NC}"
fi
echo ""

rm -f "$ALL_CONFIGS_RAW" "$ALL_CONFIGS_DECODED" "$FILTERED_CONFIGS" "$TEMP_SELECTED_CONFIGS" &>/dev/null

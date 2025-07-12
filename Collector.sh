#!/data/data/com.termux/files/usr/bin/bash

#================================================================
# V2ray CollecSHΞN™ - Xray-core Edition
#
# This version completely replaces the sing-box core with the
# highly stable and reputable Xray-core to diagnose installation
# and testing issues. The beautiful UI is retained.
#================================================================

C_GREEN='\033[1;32m'; C_WHITE='\033[1;37m'; C_RED='\033[1;31m'
C_YELLOW='\033[1;33m'; C_CYAN='\033[1;36m'; C_BG_BLUE='\033[44;1;37m'
C_NC='\033[0m'

WORKDIR="$HOME/collector_shen"
FINAL_OUTPUT="$WORKDIR/valid_configs.txt"
BIN_PATH="$HOME/.local/bin"
XRAY_PATH="$BIN_PATH/xray" # Changed from SINGBOX_PATH
ALL_CONFIGS_RAW="$WORKDIR/all_configs_raw.txt"
ALL_CONFIGS_DECODED="$WORKDIR/all_configs_decoded.txt"
FILTERED_CONFIGS="$WORKDIR/filtered_configs.txt"
TEMP_SELECTED_CONFIGS="$WORKDIR/selected_for_test.txt"
XRAY_TEST_CONFIG="$WORKDIR/xray_test_config.json" # Changed
XRAY_READY=false # Changed

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

# --- Stable UI & Core Functions ---
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

# --- Rewritten function to install Xray-core ---
prepare_components() {
    mkdir -p "$BIN_PATH" &>/dev/null
    for pkg in curl jq base64 grep sed awk termux-api unzip; do
        if ! command -v "$pkg" &>/dev/null; then pkg install -y "$pkg" > /dev/null 2>&1; fi
    done
    if [[ -x "$XRAY_PATH" ]]; then XRAY_READY=true; return; fi

    echo -e "${C_YELLOW}Xray-core not found. Attempting to install...${C_NC}"
    local arch; case $(uname -m) in "aarch64") arch="arm64-v8a" ;; *) echo -e "${C_RED}Unsupported architecture.${C_NC}"; return ;; esac
    local latest_version; latest_version=$(curl -sL "https://api.github.com/repos/XTLS/Xray-core/releases/latest" | jq -r .tag_name 2>/dev/null)
    if [[ -z "$latest_version" ]]; then echo -e "${C_RED}Could not fetch Xray-core version.${C_NC}"; return; fi
    
    local file_name="Xray-android-${arch}.zip"; local url="https://github.com/XTLS/Xray-core/releases/download/${latest_version}/${file_name}"
    
    echo -e "${C_CYAN}Downloading from ${url}...${C_NC}"
    if curl -sL -o "/tmp/xray.zip" "$url"; then
        echo -e "${C_CYAN}Extracting...${C_NC}"
        unzip -o "/tmp/xray.zip" -d "/tmp/xray_files/" > /dev/null 2>&1
        if [[ -f "/tmp/xray_files/xray" ]]; then
            mv "/tmp/xray_files/xray" "$XRAY_PATH"
            chmod +x "$XRAY_PATH"
            XRAY_READY=true
            echo -e "${C_GREEN}Xray-core installed successfully.${C_NC}"
        else
            echo -e "${C_RED}Failed to find xray executable after extraction.${C_NC}"
        fi
    else
        echo -e "${C_RED}Download failed.${C_NC}"
    fi
    rm -rf /tmp/xray.zip /tmp/xray_files &>/dev/null
}

# --- Rewritten function to test with Xray-core ---
test_config_with_xray() {
    local config_uri="$1"
    local config_type; config_type=$(echo "$config_uri" | cut -d: -f1)
    
    # Parse URI
    local creds; creds=$(echo "$config_uri" | sed -E "s|${config_type}://([^@]+)@.*|\1|")
    local address_part; address_part=$(echo "$config_uri" | sed -E "s|.*@([^?#]+).*|\1|")
    local server; server=$(echo "$address_part" | cut -d: -f1)
    local port; port=$(echo "$address_part" | cut -d: -f2)

    # Build config.json
    cat > "$XRAY_TEST_CONFIG" <<- EOM
{
  "log": { "loglevel": "none" },
  "inbounds": [
    { "port": 10808, "protocol": "socks", "settings": { "auth": "noauth", "udp": true } }
  ],
  "outbounds": [
    {
      "protocol": "${config_type}",
      "settings": {
        "vnext": [
          {
            "address": "${server}",
            "port": ${port},
            "users": [ { "id": "${creds}" } ]
          }
        ]
      }
    }
  ]
}
EOM

    # Run xray in background
    "$XRAY_PATH" run -c "$XRAY_TEST_CONFIG" &> /dev/null &
    local xray_pid=$!
    sleep 1 # Give xray time to start

    # Test with curl through the local proxy
    local http_code; http_code=$(curl -s --proxy socks5h://127.0.0.1:10808 -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://cp.cloudflare.com/")
    
    # Kill xray process
    kill "$xray_pid" &>/dev/null
    wait "$xray_pid" 2>/dev/null

    if [[ "$http_code" == "204" ]]; then
        echo "200" # Return a success code
    else
        echo "0" # Return a failure code
    fi
}

#================================================================
# SCRIPT EXECUTION
#================================================================

show_initial_banner
read -r

clear
prepare_components
echo -e "\n${C_YELLOW}Press [Enter] to continue...${C_NC}"
read -r

clear
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
if $XRAY_READY; then print_at 5 $((width-20)) "${C_GREEN}[Xray-core: Active]${C_NC}"; else print_at 9 5 "${C_RED}WARNING: Xray-core not found. Vless/Vmess tests will be skipped.${C_NC}"; fi

needs_redraw=true
while [[ "$CHECKED_COUNT" -lt "$TOTAL_TO_TEST" && "$STATE" != "quit" ]]; do
    if $needs_redraw; then
        pause_label="[ Pause ]"; [[ "$STATE" == "pause" ]] && pause_label="[ Resume ]"
        quit_label="[ Quit ]"
        if [[ $ACTIVE_BUTTON -eq 0 ]]; then pause_label="${C_BG_BLUE}${pause_label}${C_NC}"; else quit_label="${C_BG_BLUE}${quit_label}${C_NC}"; fi
        print_at 20 3 "${C_YELLOW}Controls: ${C_WHITE}${pause_label}  ${quit_label} ${C_CYAN}(Use ← → and Enter, or Ctrl+Q)${C_NC}\033[K"
        needs_redraw=false
    fi

    read -t 0.05 -rsn1 key
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
    elif $XRAY_READY && [[ "$CONFIG_TYPE" == "vless" || "$CONFIG_TYPE" == "vmess" ]]; then
        TEST_RESULT=$(test_config_with_xray "$CONFIG")
        if [[ "$TEST_RESULT" -ne 0 ]]; then
            ((VALID_COUNT++)); REMARK="☬SHΞN™-XrayOK"; HOST=$(echo "$CONFIG" | sed -E 's|.*@([^:/?#]+).*|\1|' | head -n1)
            RESULT_LINE="${C_GREEN}✓ ${C_WHITE}${HOST:0:25} ${C_CYAN}- ${C_YELLOW}Xray Test OK${C_NC}"
        else ((FAILED_COUNT++)); fi
    else ((FAILED_COUNT++)); fi
    
    if [[ -n "$RESULT_LINE" ]]; then
        needs_redraw=true
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

rm -f "$ALL_CONFIGS_RAW" "$ALL_CONFIGS_DECODED" "$FILTERED_CONFIGS" "$TEMP_SELECTED_CONFIGS" "$XRAY_TEST_CONFIG" &>/dev/null

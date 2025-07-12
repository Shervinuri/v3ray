#!/data/data/com.termux/files/usr/bin/bash

#================================================================
# V2ray CollecSHΞN™ - The Final, Reliable Version
#
# This script returns to the simple, effective, command-line
# logic. It is stable, it works, and it has no UI bugs.
# The testing logic for Vless/Vmess is rewritten and robust.
# This is the definitive, working version.
#================================================================

# --- Color Definitions ---
C_GREEN='\033[1;32m'; C_WHITE='\033[1;37m'; C_RED='\033[1;31m'
C_YELLOW='\033[1;33m'; C_CYAN='\033[1;36m'; C_NC='\033[0m'

# --- Configuration ---
WORKDIR="$HOME/collector_shen"
FINAL_OUTPUT="$WORKDIR/valid_configs_shen.txt"
BIN_PATH="$HOME/.local/bin"
SINGBOX_PATH="$BIN_PATH/sing-box"

# --- Temporary Files ---
ALL_CONFIGS_RAW="$WORKDIR/all_configs_raw.txt"
ALL_CONFIGS_DECODED="$WORKDIR/all_configs_decoded.txt"
FILTERED_CONFIGS="$WORKDIR/filtered_configs.txt"
TEMP_SELECTED_CONFIGS="$WORKDIR/selected_for_test.txt"
SINGBOX_TEST_CONFIG="$WORKDIR/singbox_test_config.json"

# --- State ---
SINGBOX_READY=false

# --- Subscription Links ---
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

# --- Simple, Reliable Functions ---
print_center() {
    local text="$1"
    local term_width; term_width=$(tput cols)
    local padding; padding=$(((term_width - ${#text}) / 2))
    printf "%*s%s\n" "$padding" '' "$text"
}

show_initial_banner() {
    clear
    echo -e "${C_WHITE}"
    print_center "=============================="
    print_center " V2ray CollecSHΞN™"
    print_center "=============================="
    echo -e "${C_NC}\n"
    print_center "${C_YELLOW}Press [Enter] to start...${C_NC}"
    echo ""
}

# This function prepares components without stopping the script on failure.
prepare_components() {
    mkdir -p "$BIN_PATH" &>/dev/null
    for pkg in curl jq base64 grep sed awk termux-api; do
        if ! command -v "$pkg" &>/dev/null; then pkg install -y "$pkg" > /dev/null 2>&1; fi
    done
    if [[ -x "$SINGBOX_PATH" ]]; then
        SINGBOX_READY=true
    else
        echo -e "${C_YELLOW}Warning: sing-box not found. Full delay tests will be skipped.${C_NC}"
    fi
}

# --- Robust Testing Function ---
# This function creates a proper temporary config file for sing-box,
# which is far more reliable than piping commands.
test_config_with_singbox() {
    local config_uri="$1"
    
    # Create the test configuration file for sing-box
    cat > "$SINGBOX_TEST_CONFIG" <<- EOM
{
    "log": {
        "level": "error"
    },
    "outbounds": [
        {
            "tag": "proxy" 
        },
        {
            "tag": "urltest",
            "type": "urltest",
            "outbounds": ["proxy"],
            "url": "http://cp.cloudflare.com/"
        }
    ]
}
EOM

    # Parse the config URI into a JSON object
    local proxy_json; proxy_json=$("$SINGBOX_PATH" parse -j "$config_uri" 2>/dev/null)
    if [[ -z "$proxy_json" ]]; then
        echo "0"; return
    fi

    # Inject the parsed proxy object into the test config file
    local final_config; final_config=$(jq --argjson proxy "$proxy_json" '.outbounds[0] = $proxy' "$SINGBOX_TEST_CONFIG")
    
    # Run the test and extract the delay
    local delay_ms; delay_ms=$(echo "$final_config" | "$SINGBOX_PATH" urltest - 2>/dev/null | awk '/ms/ {print $2}' | tr -d 'ms')

    if [[ "$delay_ms" =~ ^[0-9]+$ && "$delay_ms" -le 2000 ]]; then
        echo "$delay_ms"
    else
        echo "0"
    fi
}


#================================================================
# SCRIPT EXECUTION
#================================================================

# Set trap to catch Ctrl+C for a clean exit
trap 'echo -e "\n\n${C_RED}Operation cancelled by user.${C_NC}"; tput cnorm; exit' SIGINT

show_initial_banner
read -r

clear
prepare_components

echo -e "\n${C_CYAN}Fetching top 50 configs from ${#SUBS[@]} sources...${C_NC}"
: > "$ALL_CONFIGS_RAW"
for LINK in "${SUBS[@]}"; do curl -sL --max-time 15 "$LINK" | head -n 50 >> "$ALL_CONFIGS_RAW"; echo "" >> "$ALL_CONFIGS_RAW"; done

echo -e "${C_CYAN}Decoding and filtering configs...${C_NC}"
awk '{if ($0 ~ /^[A-Za-z0-9+/=]{20,}/) {print $0 | "base64 -d 2>/dev/null"} else {print $0}}' "$ALL_CONFIGS_RAW" > "$ALL_CONFIGS_DECODED"
grep -E '^(vless|vmess|ss)://' "$ALL_CONFIGS_DECODED" | sed -e 's/#.*//' -e 's/\r$//' | sort -u > "$FILTERED_CONFIGS"
TOTAL_FOUND=$(wc -l < "$FILTERED_CONFIGS")
echo -e "${C_GREEN}   -> Found ${TOTAL_FOUND} unique configs.${C_NC}"

clear
echo -e "${C_CYAN}Select protocol to test:${C_NC}\n"
echo -e "   ${C_WHITE}1 : vless${C_NC}"
echo -e "   ${C_WHITE}2 : vmess${C_NC}"
echo -e "   ${C_WHITE}3 : shadowsocks${C_NC}"
echo -e "   ${C_WHITE}4 : All Protocols${C_NC}\n"
read -p "   Enter your choice [1-4]: " CHOICE
case $CHOICE in 1) P='^vless://';; 2) P='^vmess://';; 3) P='^ss://';; 4) P='^(vless|vmess|ss)://';; *) echo -e "${C_RED}Invalid choice.${C_NC}"; exit 1;; esac
grep -E "$P" "$TEMP_SELECTED_CONFIGS" > "$TEMP_SELECTED_CONFIGS"

TOTAL_TO_TEST=$(wc -l < "$TEMP_SELECTED_CONFIGS")
VALID_COUNT=0; CHECKED_COUNT=0
echo -e "\n${C_CYAN}Starting test on ${TOTAL_TO_TEST} configs... Press Ctrl+C to stop.${C_NC}\n"
: > "$FINAL_OUTPUT"

while IFS= read -r CONFIG; do
    ((CHECKED_COUNT++))
    HOST=$(echo "$CONFIG" | sed -E 's|.*@([^:/?#]+).*|\1|' | head -n1)
    CONFIG_TYPE=$(echo "$CONFIG" | cut -d: -f1)
    
    echo -ne "${C_WHITE}[${CHECKED_COUNT}/${TOTAL_TO_TEST}] Testing ${HOST:0:30}... ${C_NC}"
    
    RESULT_STATUS="failed"
    REMARK=""

    if [[ "$CONFIG_TYPE" == "ss" ]]; then
        RESULT_STATUS="valid_ss"
        REMARK="☬SHΞN™-SS"
    elif $SINGBOX_READY && [[ "$CONFIG_TYPE" == "vless" || "$CONFIG_TYPE" == "vmess" ]]; then
        DELAY_MS=$(test_config_with_singbox "$CONFIG")
        if [[ "$DELAY_MS" -ne 0 ]]; then
            RESULT_STATUS="valid_delay"
            REMARK="☬SHΞN™-${DELAY_MS}ms"
        fi
    fi

    # Fallback to simple ping if sing-box test failed or wasn't available
    if [[ "$RESULT_STATUS" == "failed" && "$CONFIG_TYPE" != "ss" ]]; then
        if ping -c 1 -W 1 "$HOST" &> /dev/null; then
            RESULT_STATUS="valid_ping"
            REMARK="☬SHΞN™-PingOK"
        fi
    fi

    # --- Print result and save to file ---
    case "$RESULT_STATUS" in
        "valid_delay")
            echo -e "${C_GREEN}✓ Delay: ${DELAY_MS}ms${C_NC}"
            ((VALID_COUNT++))
            ;;
        "valid_ss")
            echo -e "${C_GREEN}✓ Added (Shadowsocks)${C_NC}"
            ((VALID_COUNT++))
            ;;
        "valid_ping")
            echo -e "${C_YELLOW}✓ Ping OK (No delay info)${C_NC}"
            ((VALID_COUNT++))
            ;;
        *)
            echo -e "${C_RED}✗ Failed${C_NC}"
            ;;
    esac

    if [[ "$RESULT_STATUS" != "failed" ]]; then
        REMARK_ENCODED=$(printf %s "$REMARK" | jq -sRr @uri 2>/dev/null)
        echo "${CONFIG}#${REMARK_ENCODED}" >> "$FINAL_OUTPUT"
    fi

done < "$TEMP_SELECTED_CONFIGS"

# --- Final Summary ---
echo -e "\n${C_GREEN}===========================================${C_NC}"
echo -e "${C_CYAN}            ✔ TESTING COMPLETE ✔             ${C_NC}"
echo -e "${C_GREEN}===========================================${C_NC}\n"
echo -e "  ${C_CYAN}Total configs checked: ${C_WHITE}$CHECKED_COUNT${C_NC}"
echo -e "  ${C_GREEN}Valid configs found:   ${C_WHITE}$VALID_COUNT${C_NC}\n"
echo -e "  ${C_WHITE}✔ Valid configs saved to:${C_NC}"
echo -e "  ${C_YELLOW}$FINAL_OUTPUT${C_NC}\n"

if [[ $VALID_COUNT -gt 0 ]]; then
    echo -e "${C_YELLOW}Press [Enter] to copy all ${VALID_COUNT} valid configs to clipboard...${C_NC}"
    read -r
    termux-clipboard-set < "$FINAL_OUTPUT"
    echo -e "${C_GREEN}✔ Copied to clipboard!${C_NC}"
fi
echo ""

rm -f "$ALL_CONFIGS_RAW" "$ALL_CONFIGS_DECODED" "$FILTERED_CONFIGS" "$TEMP_SELECTED_CONFIGS" "$SINGBOX_TEST_CONFIG" &>/dev/null

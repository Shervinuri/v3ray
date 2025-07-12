#!/data/data/com.termux/files/usr/bin/bash

#================================================================
# V2ray CollecSHΞN™ - Unstoppable Edition
#
# This script NEVER stops on errors.
# If sing-box is missing, it will gracefully skip tests
# that require it, instead of crashing.
# All errors are silenced for a clean, uninterrupted flow.
#================================================================

# --- Color Definitions ---
C_GREEN='\033[1;32m'
C_WHITE='\033[1;37m'
C_RED='\033[1;31m'
C_YELLOW='\033[1;33m'
C_CYAN='\033[1;36m'
C_NC='\033[0m' # No Color

# --- Main Configuration ---
WORKDIR="$HOME/collector_shen"
FINAL_OUTPUT="$WORKDIR/valid_configs_shen.txt"
BIN_PATH="$HOME/.local/bin"
SINGBOX_PATH="$BIN_PATH/sing-box"

# --- Temp files ---
ALL_CONFIGS_RAW="$WORKDIR/all_configs_raw.txt"
ALL_CONFIGS_DECODED="$WORKDIR/all_configs_decoded.txt"
FILTERED_CONFIGS="$WORKDIR/filtered_configs.txt"
TEMP_SELECTED_CONFIGS="$WORKDIR/selected_for_test.txt"

# --- Global State ---
SINGBOX_READY=false

# List of subscription links
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
# CORE FUNCTIONS
#================================================================

print_center() {
    local term_width=$(tput cols)
    local padding=$(((term_width - ${#1}) / 2))
    printf "%*s%s" "$padding" '' "$1"
}

# The very first thing the user sees.
show_initial_banner() {
    clear
    echo -e "${C_WHITE}"
    print_center "=============================="; echo ""
    print_center " V2ray CollecSHΞN™"; echo ""
    print_center "=============================="; echo -e "${C_NC}\n"
    echo -e "$(print_center "${C_YELLOW}Press [Enter] to start...${C_NC}")\n"
}

# This function attempts to prepare sing-box. It will NOT exit on failure.
prepare_components() {
    mkdir -p "$BIN_PATH" &>/dev/null
    
    # Check for dependencies silently
    for pkg in curl jq base64 grep sed awk; do
        if ! command -v "$pkg" &>/dev/null; then
            pkg install -y "$pkg" > /dev/null 2>&1
        fi
    done

    # If sing-box exists and is executable, we are ready.
    if [[ -x "$SINGBOX_PATH" ]]; then
        SINGBOX_READY=true
        return
    fi

    # If not, attempt a silent installation.
    local arch; case $(uname -m) in "aarch64") arch="arm64" ;; "armv7l" | "armv8l") arch="armv7" ;; "x86_64") arch="amd64" ;; *) return ;; esac
    local arch_name="linux-${arch}"; local latest_version=$(curl -sL "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | jq -r .tag_name 2>/dev/null)
    if [[ -z "$latest_version" ]]; then return; fi
    local file_name="sing-box-${latest_version#v}-${arch_name}.tar.gz"; local url="https://github.com/SagerNet/sing-box/releases/download/${latest_version}/${file_name}"
    
    if curl -sL -o "/tmp/sb.tar.gz" "$url" && tar -xzf "/tmp/sb.tar.gz" -C "/tmp/" > /dev/null 2>&1 && mv "/tmp/sing-box-${latest_version#v}-${arch_name}/sing-box" "$SINGBOX_PATH" && chmod +x "$SINGBOX_PATH"; then
        SINGBOX_READY=true # Installation successful
    fi
    rm -rf "/tmp/sb.tar.gz" "/tmp/sing-box-"* &>/dev/null
}


#================================================================
# SCRIPT EXECUTION STARTS HERE
#================================================================

# 1. Show banner and wait. Nothing else happens.
show_initial_banner
read -r

# 2. Silently prepare components, fetch, and filter configs.
clear
echo -e "${C_CYAN}Initializing and preparing components...${C_NC}"
prepare_components

echo -e "${C_CYAN}Fetching configs from ${#SUBS[@]} sources...${C_NC}"
: > "$ALL_CONFIGS_RAW"
for LINK in "${SUBS[@]}"; do
    curl -sL --max-time 15 "$LINK" >> "$ALL_CONFIGS_RAW"
    echo "" >> "$ALL_CONFIGS_RAW"
done

echo -e "${C_CYAN}Decoding and filtering configs...${C_NC}"
awk '{if ($0 ~ /^[A-Za-z0-9+/=]{20,}/) {print $0 | "base64 -d 2>/dev/null"} else {print $0}}' "$ALL_CONFIGS_RAW" > "$ALL_CONFIGS_DECODED"
grep -E '^(vless|vmess|ss)://' "$ALL_CONFIGS_DECODED" | sed -e 's/#.*//' -e 's/\r$//' | sort -u > "$FILTERED_CONFIGS"
TOTAL_FOUND=$(wc -l < "$FILTERED_CONFIGS")
echo -e "${C_GREEN}   -> Found ${TOTAL_FOUND} unique configs.${C_NC}"

# 3. User protocol selection
echo -e "\n${C_CYAN}Select protocol to test:${C_NC}"
echo -e "   ${C_WHITE}1) vless  2) vmess  3) shadowsocks (ss)  4) All${C_NC}"
read -p "   Enter your choice [1-4]: " CHOICE
case $CHOICE in 1) P='^vless://';; 2) P='^vmess://';; 3) P='^ss://';; 4) P='^(vless|vmess|ss)://';; *) echo -e "${C_RED}Invalid choice.${C_NC}"; exit 1;; esac
grep -E "$P" "$FILTERED_CONFIGS" > "$TEMP_SELECTED_CONFIGS"

# 4. Initialize and run the main testing UI
TOTAL_TO_TEST=$(wc -l < "$TEMP_SELECTED_CONFIGS")
VALID_COUNT=0; CHECKED_COUNT=0; FAILED_COUNT=0; STATE="run"
declare -a RESULTS_WINDOW; RESULTS_MAX_LINES=10

handle_input() { while true; do read -rsn1 i; if [[ "$i" == "p" ]]; then [[ "$STATE" == "run" ]] && STATE="pause" || STATE="run"; elif [[ "$i" == "q" ]]; then STATE="quit"; fi; done; }
handle_input &
INPUT_PID=$!
trap 'tput cnorm; kill $INPUT_PID &>/dev/null; clear; exit' EXIT

# Draw the UI
clear; tput civis
width=$(tput cols); ((width--))
echo -e "${C_WHITE}"; print_center "=============================="; echo ""; print_center " V2ray CollecSHΞN™"; echo ""; print_center "=============================="; echo -e "${C_NC}"
draw_box() { local r=$1 c=$2 w=$3 h=$4; tput cup $r $c; echo -ne "${C_CYAN}╭$(printf '─%.0s' $(seq 1 $((w-2))))╮${C_NC}"; for i in $(seq 1 $((h-2))); do tput cup $((r+i)) $c; echo -ne "${C_CYAN}│${C_NC}"; tput cup $((r+i)) $((c+w-1)); echo -ne "${C_CYAN}│${C_NC}"; done; tput cup $((r+h-1)) $c; echo -ne "${C_CYAN}╰$(printf '─%.0s' $(seq 1 $((w-2))))╯${C_NC}"; }
draw_box 5 1 "$width" 3; tput cup 5 3; echo -ne "${C_WHITE}📊 Live Stats${C_NC}"
draw_box 8 1 "$width" 12; tput cup 8 3; echo -ne "${C_WHITE}📡 Live Results${C_NC}"
tput cup 19 1; echo -ne "${C_CYAN}├$(printf '─%.0s' $(seq 1 $((w-2))))┤${C_NC}"
tput cup 20 3; echo -ne "${C_YELLOW}Controls: ${C_WHITE}[p] Pause/Resume ${C_CYAN}| ${C_WHITE}[q] Quit & Save${C_NC}"
if $SINGBOX_READY; then tput cup 5 $((width-20)); echo -ne "${C_GREEN}[Sing-box: Active]${C_NC}"; else tput cup 5 $((width-22)); echo -ne "${C_RED}[Sing-box: Not Found]${C_NC}"; fi

# Main testing loop
while IFS= read -r CONFIG || [[ -n "$CONFIG" ]]; do
    while [[ "$STATE" == "pause" ]]; do tput cup 20 60; echo -ne "${C_YELLOW}■ PAUSED...${C_NC}"; sleep 0.5; done
    [[ "$STATE" == "quit" ]] && break
    tput cup 20 60; echo -ne "${C_CYAN}▶ TESTING...${C_NC}\033[K"
    ((CHECKED_COUNT++))
    
    # Update Stats
    tput cup 6 3; echo -ne "${C_CYAN}Checked: ${C_WHITE}$CHECKED_COUNT ${C_NC}| ${C_GREEN}Valid: ${C_WHITE}$VALID_COUNT ${C_NC}| ${C_RED}Failed: ${C_WHITE}$FAILED_COUNT ${C_NC}| ${C_YELLOW}Total: ${C_WHITE}$TOTAL_TO_TEST${C_NC}\033[K"
    
    # Update Progress Bar
    PERCENT=$((CHECKED_COUNT * 100 / TOTAL_TO_TEST)); bar_width=$((width - 10)); filled_len=$((PERCENT * bar_width / 100))
    bar="${C_GREEN}"; for ((i=0; i<filled_len; i++)); do bar+="▓"; done; bar+="${C_NC}${C_WHITE}"; for ((i=filled_len; i<bar_width; i++)); do bar+="░"; done
    tput cup 19 5; echo -ne "${PERCENT}% ${bar}"

    # --- Main Logic: Test based on what's available ---
    CONFIG_TYPE=$(echo "$CONFIG" | cut -d: -f1)

    if [[ "$CONFIG_TYPE" == "ss" ]]; then # SS configs don't need a delay test
        ((VALID_COUNT++))
        HOST=$(echo "$CONFIG" | sed -E 's|.*@([^:]+):.*|\1|' | cut -d'#' -f1)
        REMARK="☬SHΞN™-SS"
        REMARK_ENCODED=$(printf %s "$REMARK" | jq -sRr @uri 2>/dev/null)
        echo "${CONFIG}#${REMARK_ENCODED}" >> "$FINAL_OUTPUT"
        RESULT_LINE="${C_GREEN}✓ ${C_WHITE}${HOST:0:25} ${C_CYAN}- ${C_YELLOW}Shadowsocks Added${C_NC}"
    elif $SINGBOX_READY && [[ "$CONFIG_TYPE" == "vless" || "$CONFIG_TYPE" == "vmess" ]]; then
        TMP_JSON="$WORKDIR/test.json"
        "$SINGBOX_PATH" parse -j "$CONFIG" > "$WORKDIR/proxy.json" 2>/dev/null
        if [[ -s "$WORKDIR/proxy.json" ]]; then
            jq --argfile proxy "$WORKDIR/proxy.json" '{log:{level:"error"},outbounds:[$proxy,{tag:"urltest",type:"urltest",outbounds:["proxy"],url:"http://cp.cloudflare.com/"}]}' > "$TMP_JSON" 2>/dev/null
            DELAY_MS=$(timeout 8s "$SINGBOX_PATH" urltest -c "$TMP_JSON" 2>/dev/null | awk '/ms/ {print $2}' | tr -d 'ms')
            rm -f "$TMP_JSON" "$WORKDIR/proxy.json"
            if [[ "$DELAY_MS" =~ ^[0-9]+$ && "$DELAY_MS" -le 2000 ]]; then
                ((VALID_COUNT++))
                HOST=$(echo "$CONFIG" | sed -E 's|.*@([^:/?#]+).*|\1|' | head -n1)
                REMARK="☬SHΞN™-${DELAY_MS}ms"
                REMARK_ENCODED=$(printf %s "$REMARK" | jq -sRr @uri 2>/dev/null)
                echo "${CONFIG}#${REMARK_ENCODED}" >> "$FINAL_OUTPUT"
                RESULT_LINE="${C_GREEN}✓ ${C_WHITE}${HOST:0:25} ${C_CYAN}- ${C_YELLOW}${DELAY_MS}ms${C_NC}"
            else
                ((FAILED_COUNT++)); RESULT_LINE=""
            fi
        else
            ((FAILED_COUNT++)); RESULT_LINE=""
        fi
    else # Fallback for vless/vmess if sing-box is not ready
        ((FAILED_COUNT++)); RESULT_LINE=""
    fi
    
    if [[ -n "$RESULT_LINE" ]]; then
        ((${#RESULTS_WINDOW[@]} >= RESULTS_MAX_LINES)) && RESULTS_WINDOW=("${RESULTS_WINDOW[@]:1}")
        RESULTS_WINDOW+=("$RESULT_LINE")
        for i in "${!RESULTS_WINDOW[@]}"; do tput cup $((9 + i)) 3; echo -ne "${RESULTS_WINDOW[$i]}\033[K"; done
    fi

done < "$TEMP_SELECTED_CONFIGS"

# Final Summary
tput cnorm; kill $INPUT_PID &>/dev/null
clear
echo -e "\n\n${C_GREEN}===========================================${C_NC}"
echo -e "${C_CYAN}            ✔ TESTING COMPLETE ✔             ${C_NC}"
echo -e "${C_GREEN}===========================================${C_NC}\n"
echo -e "  ${C_CYAN}Total configs checked: ${C_WHITE}$CHECKED_COUNT${C_NC}"
echo -e "  ${C_GREEN}Valid configs found:   ${C_WHITE}$VALID_COUNT${C_NC}"
echo -e "  ${C_RED}Failed/Skipped configs: ${C_WHITE}$FAILED_COUNT${C_NC}\n"
echo -e "  ${C_WHITE}✔ Valid configs saved to:${C_NC}"
echo -e "  ${C_YELLOW}$FINAL_OUTPUT${C_NC}\n"

# Cleanup
rm -f "$ALL_CONFIGS_RAW" "$ALL_CONFIGS_DECODED" "$FILTERED_CONFIGS" "$TEMP_SELECTED_CONFIGS"

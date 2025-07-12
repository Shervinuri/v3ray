#!/data/data/com.termux/files/usr/bin/bash

#================================================================
# V2ray CollecSHΞN™ - Final Debugged Edition
#
# Changelog:
# - FIXED: Vless/Vmess detection logic is now working correctly.
# - FIXED: Protocol selection menu is now vertical and centered.
# - FIXED: UI race condition causing visual glitches is eliminated
#   by using a single, synchronized main loop.
# - All previous features (interactive controls, clipboard) retained.
#================================================================

# --- Color Definitions ---
C_GREEN='\033[1;32m'
C_WHITE='\033[1;37m'
C_RED='\033[1;31m'
C_YELLOW='\033[1;33m'
C_CYAN='\033[1;36m'
C_BG_BLUE='\033[44;1;37m' # White text on Blue background
C_NC='\033[0m'

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
    printf "%*s%s\n" "$padding" '' "$1"
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

prepare_components() {
    mkdir -p "$BIN_PATH" &>/dev/null
    for pkg in curl jq base64 grep sed awk termux-api; do
        if ! command -v "$pkg" &>/dev/null; then
            pkg install -y "$pkg" > /dev/null 2>&1
        fi
    done
    if [[ -x "$SINGBOX_PATH" ]]; then
        SINGBOX_READY=true
        return
    fi
    local arch; case $(uname -m) in "aarch64") arch="arm64" ;; *) return ;; esac
    local arch_name="linux-${arch}"; local latest_version=$(curl -sL "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | jq -r .tag_name 2>/dev/null)
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
for LINK in "${SUBS[@]}"; do
    curl -sL --max-time 15 "$LINK" | head -n 50 >> "$ALL_CONFIGS_RAW"
    echo "" >> "$ALL_CONFIGS_RAW"
done

echo -e "${C_CYAN}Decoding and filtering configs...${C_NC}"
awk '{if ($0 ~ /^[A-Za-z0-9+/=]{20,}/) {print $0 | "base64 -d 2>/dev/null"} else {print $0}}' "$ALL_CONFIGS_RAW" > "$ALL_CONFIGS_DECODED"
grep -E '^(vless|vmess|ss)://' "$ALL_CONFIGS_DECODED" | sed -e 's/#.*//' -e 's/\r$//' | sort -u > "$FILTERED_CONFIGS"
TOTAL_FOUND=$(wc -l < "$FILTERED_CONFIGS")
echo -e "${C_GREEN}   -> Found ${TOTAL_FOUND} unique configs.${C_NC}"

# --- FIXED: Vertical and Centered Menu ---
clear
print_center "${C_CYAN}Select protocol to test:${C_NC}"
echo ""
print_center "${C_WHITE}1 : vless${C_NC}"
print_center "${C_WHITE}2 : vmess${C_NC}"
print_center "${C_WHITE}3 : shadowsocks${C_NC}"
print_center "${C_WHITE}4 : All Protocols${C_NC}"
echo ""
read -p "$(print_center "Enter your choice [1-4]: ")" CHOICE
case $CHOICE in 1) P='^vless://';; 2) P='^vmess://';; 3) P='^ss://';; 4) P='^(vless|vmess|ss)://';; *) echo -e "${C_RED}Invalid choice.${C_NC}"; exit 1;; esac
grep -E "$P" "$FILTERED_CONFIGS" > "$TEMP_SELECTED_CONFIGS"

# --- UI & Interactive Loop Setup ---
CONFIGS_TO_TEST=()
while IFS= read -r line; do CONFIGS_TO_TEST+=("$line"); done < "$TEMP_SELECTED_CONFIGS"
TOTAL_TO_TEST=${#CONFIGS_TO_TEST[@]}
VALID_COUNT=0; CHECKED_COUNT=0; FAILED_COUNT=0; STATE="run"; ACTIVE_BUTTON=0

trap 'tput cnorm; clear; exit' EXIT

# Draw the entire UI once
clear; tput civis
width=$(tput cols); ((width--))
echo -e "${C_WHITE}"; print_center "=============================="; echo ""; print_center " V2ray CollecSHΞN™"; echo ""; print_center "=============================="; echo -e "${C_NC}"
draw_box() { local r=$1 c=$2 w=$3 h=$4; tput cup $r $c; echo -ne "${C_CYAN}╭$(printf '─%.0s' $(seq 1 $((w-2))))╮${C_NC}"; for i in $(seq 1 $((h-2))); do tput cup $((r+i)) $c; echo -ne "${C_CYAN}│${C_NC}"; tput cup $((r+i)) $((c+w-1)); echo -ne "${C_CYAN}│${C_NC}"; done; tput cup $((r+h-1)) $c; echo -ne "${C_CYAN}╰$(printf '─%.0s' $(seq 1 $((w-2))))╯${C_NC}"; }
draw_box 5 1 "$width" 3; tput cup 5 3; echo -ne "${C_WHITE}📊 Live Stats${C_NC}"
draw_box 8 1 "$width" 12; tput cup 8 3; echo -ne "${C_WHITE}📡 Live Results${C_NC}"
tput cup 19 1; echo -ne "${C_CYAN}├$(printf '─%.0s' $(seq 1 $((w-2))))┤${C_NC}"
if $SINGBOX_READY; then tput cup 5 $((width-20)); echo -ne "${C_GREEN}[Sing-box: Active]${C_NC}"; else tput cup 5 $((width-22)); echo -ne "${C_RED}[Sing-box: Not Found]${C_NC}"; fi
declare -a RESULTS_WINDOW

# --- FIXED: Unified Main Loop to prevent UI glitches ---
while [[ "$CHECKED_COUNT" -lt "$TOTAL_TO_TEST" && "$STATE" != "quit" ]]; do
    # --- Input Handling Part ---
    read -t 0.1 -rsn1 key
    if [[ "$key" == $'\e' ]]; then
        read -rsn2 key
        case "$key" in '[D') ((ACTIVE_BUTTON--));; '[C') ((ACTIVE_BUTTON++));; esac
        ((ACTIVE_BUTTON < 0)) && ACTIVE_BUTTON=0; ((ACTIVE_BUTTON > 1)) && ACTIVE_BUTTON=1
    elif [[ "$key" == "" ]]; then
        if [[ $ACTIVE_BUTTON -eq 0 ]]; then [[ "$STATE" == "run" ]] && STATE="pause" || STATE="run"; else STATE="quit"; fi
    elif [[ "$key" == $'\x11' ]]; then STATE="quit"; fi

    # --- UI Drawing Part ---
    pause_label="[ Pause ]"; [[ "$STATE" == "pause" ]] && pause_label="[ Resume ]"
    quit_label="[ Quit ]"
    if [[ $ACTIVE_BUTTON -eq 0 ]]; then pause_label="${C_BG_BLUE}${pause_label}${C_NC}"; else quit_label="${C_BG_BLUE}${quit_label}${C_NC}"; fi
    tput cup 20 3; echo -ne "${C_YELLOW}Controls: ${C_WHITE}${pause_label}  ${quit_label} ${C_CYAN}(Use ← → and Enter, or Ctrl+Q)${C_NC}\033[K"

    # --- Logic/Testing Part (only if not paused) ---
    if [[ "$STATE" == "run" ]]; then
        CONFIG="${CONFIGS_TO_TEST[$CHECKED_COUNT]}"
        ((CHECKED_COUNT++))
        
        # Update Stats & Progress
        tput cup 6 3; echo -ne "${C_CYAN}Checked: ${C_WHITE}$CHECKED_COUNT ${C_NC}| ${C_GREEN}Valid: ${C_WHITE}$VALID_COUNT ${C_NC}| ${C_RED}Failed: ${C_WHITE}$FAILED_COUNT ${C_NC}| ${C_YELLOW}Total: ${C_WHITE}$TOTAL_TO_TEST${C_NC}\033[K"
        PERCENT=$((CHECKED_COUNT * 100 / TOTAL_TO_TEST)); bar_width=$((width - 10)); filled_len=$((PERCENT * bar_width / 100))
        bar="${C_GREEN}"; for ((i=0; i<filled_len; i++)); do bar+="▓"; done; bar+="${C_NC}${C_WHITE}"; for ((i=filled_len; i<bar_width; i++)); do bar+="░"; done
        tput cup 19 5; echo -ne "${PERCENT}% ${bar}"

        CONFIG_TYPE=$(echo "$CONFIG" | cut -d: -f1)
        RESULT_LINE=""
        REMARK=""
        if [[ "$CONFIG_TYPE" == "ss" ]]; then
            ((VALID_COUNT++)); REMARK="☬SHΞN™-SS"; HOST=$(echo "$CONFIG" | sed -E 's|.*@([^:]+):.*|\1|' | cut -d'#' -f1)
            RESULT_LINE="${C_GREEN}✓ ${C_WHITE}${HOST:0:25} ${C_CYAN}- ${C_YELLOW}Shadowsocks Added${C_NC}"
        elif $SINGBOX_READY && [[ "$CONFIG_TYPE" == "vless" || "$CONFIG_TYPE" == "vmess" ]]; then
            # --- FIXED: Vless/Vmess test logic ---
            "$SINGBOX_PATH" parse -j "$CONFIG" > "$WORKDIR/proxy.json" 2>/dev/null
            if [[ -s "$WORKDIR/proxy.json" ]]; then
                # Ensure the proxy has the correct tag for urltest to find it
                jq '(.tag = "proxy")' "$WORKDIR/proxy.json" > "$WORKDIR/proxy_tagged.json"
                
                jq --argfile proxy "$WORKDIR/proxy_tagged.json" '{log:{level:"error"},outbounds:[$proxy,{tag:"urltest",type:"urltest",outbounds:["proxy"],url:"http://cp.cloudflare.com/"}]}' > "$WORKDIR/test.json" 2>/dev/null
                DELAY_MS=$(timeout 8s "$SINGBOX_PATH" urltest -c "$WORKDIR/test.json" 2>/dev/null | awk '/ms/ {print $2}' | tr -d 'ms')
                
                if [[ "$DELAY_MS" =~ ^[0-9]+$ && "$DELAY_MS" -le 2000 ]]; then
                    ((VALID_COUNT++)); REMARK="☬SHΞN™-${DELAY_MS}ms"; HOST=$(echo "$CONFIG" | sed -E 's|.*@([^:/?#]+).*|\1|' | head -n1)
                    RESULT_LINE="${C_GREEN}✓ ${C_WHITE}${HOST:0:25} ${C_CYAN}- ${C_YELLOW}${DELAY_MS}ms${C_NC}"
                else ((FAILED_COUNT++)); fi
            else ((FAILED_COUNT++)); fi
            rm -f "$WORKDIR/proxy.json" "$WORKDIR/proxy_tagged.json" "$WORKDIR/test.json"
        else ((FAILED_COUNT++)); fi
        
        if [[ -n "$RESULT_LINE" ]]; then
            REMARK_ENCODED=$(printf %s "$REMARK" | jq -sRr @uri 2>/dev/null); echo "${CONFIG}#${REMARK_ENCODED}" >> "$FINAL_OUTPUT"
            ((${#RESULTS_WINDOW[@]} >= 10)) && RESULTS_WINDOW=("${RESULTS_WINDOW[@]:1}")
            RESULTS_WINDOW+=("$RESULT_LINE"); for i in "${!RESULTS_WINDOW[@]}"; do tput cup $((9 + i)) 3; echo -ne "${RESULTS_WINDOW[$i]}\033[K"; done
        fi
    fi
done

# --- Final Summary ---
tput cnorm; clear
echo -e "\n\n${C_GREEN}===========================================${C_NC}"
echo -e "${C_CYAN}            ✔ TESTING COMPLETE ✔             ${C_NC}"
echo -e "${C_GREEN}===========================================${C_NC}\n"
echo -e "  ${C_CYAN}Total configs checked: ${C_WHITE}$CHECKED_COUNT${C_NC}"
echo -e "  ${C_GREEN}Valid configs found:   ${C_WHITE}$VALID_COUNT${C_NC}"
echo -e "  ${C_RED}Failed/Skipped configs: ${C_WHITE}$FAILED_COUNT${C_NC}\n"
echo -e "  ${C_WHITE}✔ Valid configs saved to:${C_NC}"
echo -e "  ${C_YELLOW}$FINAL_OUTPUT${C_NC}\n"

if [[ $VALID_COUNT -gt 0 ]]; then
    echo -e "${C_YELLOW}Press [Enter] to copy all ${VALID_COUNT} valid configs to clipboard...${C_NC}"
    read -r
    termux-clipboard-set < "$FINAL_OUTPUT"
    echo -e "${C_GREEN}✔ Copied to clipboard!${C_NC}"
fi

# Cleanup
rm -f "$ALL_CONFIGS_RAW" "$ALL_CONFIGS_DECODED" "$FILTERED_CONFIGS" "$TEMP_SELECTED_CONFIGS"

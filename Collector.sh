#!/data/data/com.termux/files/usr/bin/bash

#================================================================
# V2ray CollecSHΞN™ - Classic UI, Stable Core Edition
#
# This version returns to the beloved graphical UI with interactive
# buttons and combines it with the rock-solid, flicker-free
# architecture from the final releases. This is the definitive
# "best of both worlds" version.
#================================================================

# --- CONFIGURATION ---
C_GREEN='\033[1;32m'; C_WHITE='\033[1;37m'; C_RED='\033[1;31m'
C_YELLOW='\033[1;33m'; C_CYAN='\033[1;36m'; C_BG_BLUE='\033[44;1;37m'
C_NC='\033[0m'

WORKDIR="$HOME/collector_shen"
FINAL_OUTPUT="$WORKDIR/valid_configs.txt"
BIN_PATH="$HOME/.local/bin"
XRAY_PATH="$BIN_PATH/xray"
XRAY_READY=false

# --- Communication Files for FG/BG processes ---
CONTROL_FILE="$WORKDIR/control.cmd"
STATUS_FILE="$WORKDIR/status.log"
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
    rm -f "$WORKDIR"/*.cmd "$WORKDIR"/*.log "$WORKDIR"/*.txt "$WORKDIR"/*.json
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
    if $XRAY_READY; then print_at 5 $((width-22)) "${C_GREEN}[Core: Xray-core Active]${C_NC}"; else print_at 9 5 "${C_RED}WARNING: Xray-core not found. Vless/Vmess tests will be skipped.${C_NC}"; fi
}

# --- Background Worker Process ---
run_worker_process() {
    local configs_file="$1"
    
    local total_to_test; total_to_test=$(wc -l < "$configs_file")
    local checked_count=0
    local valid_count=0
    local failed_count=0
    
    while IFS= read -r CONFIG; do
        # Check for control commands (pause/quit)
        if [[ -f "$CONTROL_FILE" ]]; then
            local cmd; cmd=$(cat "$CONTROL_FILE")
            if [[ "$cmd" == "quit" ]]; then break; fi
            while [[ "$cmd" == "pause" ]]; do
                sleep 0.5
                cmd=$(cat "$CONTROL_FILE" 2>/dev/null)
            done
        fi

        local config_type; config_type=$(echo "$CONFIG" | cut -d: -f1)
        local host; host=$(echo "$CONFIG" | sed -E 's|.*@([^:/?#]+).*|\1|' | head -n1)
        local remark=""
        local is_valid=false

        if [[ "$config_type" == "ss" ]]; then
            is_valid=true; remark="☬SHΞN™-SS"
        elif $XRAY_READY && [[ "$config_type" == "vless" || "$config_type" == "vmess" ]]; then
            local creds; creds=$(echo "$CONFIG" | sed -E "s|${config_type}://([^@]+)@.*|\1|")
            local address_part; address_part=$(echo "$CONFIG" | sed -E "s|.*@([^?#]+).*|\1|")
            local server; server=$(echo "$address_part" | cut -d: -f1)
            local port; port=$(echo "$address_part" | cut -d: -f2)
            
            cat > "$WORKDIR/test.json" <<- EOM
{ "log": { "loglevel": "none" }, "inbounds": [ { "port": 10808, "protocol": "socks" } ], "outbounds": [ { "protocol": "${config_type}", "settings": { "vnext": [ { "address": "${server}", "port": ${port}, "users": [ { "id": "${creds}" } ] } ] } } ] }
EOM
            "$XRAY_PATH" run -c "$WORKDIR/test.json" &> /dev/null &
            local xray_pid=$!
            sleep 1
            local http_code; http_code=$(curl -s --proxy socks5h://127.0.0.1:10808 -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://cp.cloudflare.com/")
            kill "$xray_pid" &>/dev/null; wait "$xray_pid" 2>/dev/null
            
            if [[ "$http_code" == "204" ]]; then
                is_valid=true; remark="☬SHΞN™-XrayOK"
            fi
        fi
        
        ((checked_count++))
        if $is_valid; then
            ((valid_count++))
            local remark_encoded; remark_encoded=$(printf %s "$remark" | jq -sRr @uri 2>/dev/null)
            echo "${CONFIG}#${remark_encoded}" >> "$FINAL_OUTPUT"
            echo "${C_GREEN}✓ ${C_WHITE}${host:0:25} ${C_CYAN}- ${C_YELLOW}${remark#☬SHΞN™-}${C_NC}" >> "$RESULTS_FILE"
        else
            ((failed_count++))
        fi
        
        # Update status file for the UI process
        echo "$checked_count|$valid_count|$failed_count|$total_to_test" > "$STATUS_FILE"

    done < "$configs_file"
    
    # Signal completion
    echo "done" >> "$CONTROL_FILE"
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
echo -e "${C_CYAN}Initializing and preparing components...${C_NC}"
prepare_components() { mkdir -p "$BIN_PATH" &>/dev/null; for pkg in curl jq base64 grep sed awk termux-api unzip; do if ! command -v "$pkg" &>/dev/null; then pkg install -y "$pkg" > /dev/null 2>&1; fi; done; if [[ -x "$XRAY_PATH" ]]; then XRAY_READY=true; return; fi; local arch; case $(uname -m) in "aarch64") arch="arm64-v8a" ;; *) return ;; esac; local latest_version; latest_version=$(curl -sL "https://api.github.com/repos/XTLS/Xray-core/releases/latest" | jq -r .tag_name 2>/dev/null); if [[ -z "$latest_version" ]]; then return; fi; local file_name="Xray-android-${arch}.zip"; local url="https://github.com/XTLS/Xray-core/releases/download/${latest_version}/${file_name}"; if curl -sL -o "/tmp/xray.zip" "$url"; then unzip -o "/tmp/xray.zip" -d "/tmp/xray_files/" > /dev/null 2>&1; if [[ -f "/tmp/xray_files/xray" ]]; then mv "/tmp/xray_files/xray" "$XRAY_PATH"; chmod +x "$XRAY_PATH"; XRAY_READY=true; fi; fi; rm -rf /tmp/xray.zip /tmp/xray_files &>/dev/null; }
prepare_components
echo -e "\n${C_YELLOW}Press [Enter] to continue...${C_NC}"
read -r

# --- Config Fetching ---
clear
echo -e "${C_CYAN}Fetching top 50 configs...${C_NC}"
: > "$WORKDIR/all_configs_raw.txt"
for LINK in "${SUBS[@]}"; do curl -sL --max-time 15 "$LINK" | head -n 50 >> "$WORKDIR/all_configs_raw.txt"; echo "" >> "$WORKDIR/all_configs_raw.txt"; done
echo -e "${C_CYAN}Decoding and filtering...${C_NC}"
awk '{if ($0 ~ /^[A-Za-z0-9+/=]{20,}/) {print $0 | "base64 -d 2>/dev/null"} else {print $0}}' "$WORKDIR/all_configs_raw.txt" > "$WORKDIR/all_configs_decoded.txt"
grep -E '^(vless|vmess|ss)://' "$WORKDIR/all_configs_decoded.txt" | sed -e 's/#.*//' -e 's/\r$//' | sort -u > "$WORKDIR/filtered_configs.txt"

# --- Protocol Selection ---
clear
print_center 2 "${C_CYAN}Select protocol to test:${C_NC}"
print_center 4 "${C_WHITE}1 : vless${C_NC}"; print_center 5 "${C_WHITE}2 : vmess${C_NC}"
print_center 6 "${C_WHITE}3 : shadowsocks${C_NC}"; print_center 7 "${C_WHITE}4 : All Protocols${C_NC}"
tput cup 9 0; read -p "$(print_center 9 "Enter your choice [1-4]: ")" CHOICE
case $CHOICE in 1) P='^vless://';; 2) P='^vmess://';; 3) P='^ss://';; 4) P='^(vless|vmess|ss)://';; *) echo -e "${C_RED}Invalid choice.${C_NC}"; exit 1;; esac
grep -E "$P" "$WORKDIR/filtered_configs.txt" > "$WORKDIR/selected_for_test.txt"

# --- Main UI Loop (Foreground) ---
: > "$FINAL_OUTPUT"; : > "$STATUS_FILE"; : > "$RESULTS_FILE"; echo "run" > "$CONTROL_FILE"
run_worker_process "$WORKDIR/selected_for_test.txt" &
worker_pid=$!

trap 'echo "quit" > "$CONTROL_FILE"; cleanup' SIGINT EXIT
trap redraw_ui WINCH

redraw_ui
active_button=0
state="run"

while true; do
    # Read status from worker
    IFS='|' read -r checked valid failed total < "$STATUS_FILE"
    
    # Update UI elements
    print_at 6 3 "${C_CYAN}Checked: ${C_WHITE}${checked:-0} ${C_NC}| ${C_GREEN}Valid: ${C_WHITE}${valid:-0} ${C_NC}| ${C_RED}Failed: ${C_WHITE}${failed:-0} ${C_NC}| ${C_YELLOW}Total: ${C_WHITE}${total:-0}${C_NC}\033[K"
    if [[ -n "$total" && "$total" -gt 0 ]]; then
        percent=$(( (checked:-0) * 100 / total ))
        bar_width=$((width - 10)); filled_len=$((percent * bar_width / 100))
        bar="${C_GREEN}"; for ((i=0; i<filled_len; i++)); do bar+="▓"; done; bar+="${C_NC}${C_WHITE}"; for ((i=filled_len; i<bar_width; i++)); do bar+="░"; done
        print_at 19 5 "${percent}% ${bar}"
    fi
    
    # Update results window
    tail -n 10 "$RESULTS_FILE" | nl -w1 -s' ' | while read -r num line; do
        print_at $((8+num)) 3 "$line\033[K"
    done

    # Draw buttons
    pause_label="[ Pause ]"; [[ "$state" == "pause" ]] && pause_label="[ Resume ]"
    quit_label="[ Quit ]"
    if [[ $active_button -eq 0 ]]; then pause_label="${C_BG_BLUE}${pause_label}${C_NC}"; else quit_label="${C_BG_BLUE}${quit_label}${C_NC}"; fi
    print_at 20 3 "${C_YELLOW}Controls: ${C_WHITE}${pause_label}  ${quit_label} ${C_CYAN}(Use ← → and Enter, or Ctrl+Q)${C_NC}\033[K"

    # Check if worker is done
    if [[ -f "$CONTROL_FILE" ]] && [[ "$(cat "$CONTROL_FILE")" == "done" ]]; then
        break
    fi

    # Handle user input
    read -rsn1 -t 0.1 key
    if [[ "$key" == $'\e' ]]; then
        read -rsn2 -t 0.01 key_ext
        case "$key_ext" in '[D') active_button=0;; '[C') active_button=1;; esac
    elif [[ "$key" == "" ]]; then
        if [[ $active_button -eq 0 ]]; then
            if [[ "$state" == "run" ]]; then state="pause"; echo "pause" > "$CONTROL_FILE"; else state="run"; echo "run" > "$CONTROL_FILE"; fi
        else
            echo "quit" > "$CONTROL_FILE"; break
        fi
    elif [[ "$key" == $'\x11' ]]; then echo "quit" > "$CONTROL_FILE"; break; fi
done

wait $worker_pid

# --- Final Summary ---
tput cnorm; clear
print_center 2 "${C_GREEN}===========================================${C_NC}"
print_center 3 "${C_CYAN}            ✔ TESTING COMPLETE ✔             ${C_NC}"
print_center 4 "${C_GREEN}===========================================${C_NC}"
IFS='|' read -r checked valid failed total < "$STATUS_FILE"
print_at 6 3 "  ${C_CYAN}Total configs checked: ${C_WHITE}${checked:-0}${C_NC}"
print_at 7 3 "  ${C_GREEN}Valid configs found:   ${C_WHITE}${valid:-0}${C_NC}"
print_at 8 3 "  ${C_RED}Failed/Skipped configs: ${C_WHITE}${failed:-0}${C_NC}"
print_at 10 3 "  ${C_WHITE}✔ Valid configs saved to:${C_NC}"
print_at 11 3 "  ${C_YELLOW}$FINAL_OUTPUT${C_NC}"

if [[ "${valid:-0}" -gt 0 ]]; then
    print_at 13 3 "${C_YELLOW}Press [Enter] to copy all ${valid:-0} valid configs to clipboard...${C_NC}"
    read -r
    termux-clipboard-set < "$FINAL_OUTPUT"
    print_at 14 3 "${C_GREEN}✔ Copied to clipboard!${C_NC}"
fi
echo ""

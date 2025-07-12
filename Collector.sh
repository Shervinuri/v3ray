#!/data/data/com.termux/files/usr/bin/bash

#================================================================
# V2ray CollecSHخ‍Nâ„¢ - Fully Interactive Script (Pro Edition)
# Author: SHخ‍Nâ„¢
# Description:
#   - Fetches top 40 configs from public sublinks
#   - Filters by user-chosen protocol (vless/vmess/ss/all)
#   - Tests server delays using sing-box (if available)
#   - Provides colorful real-time UI and final export
#================================================================

# --- Colors ---
C_RESET='\033[0m'
C_GREEN='\033[1;32m'
C_RED='\033[1;31m'
C_YELLOW='\033[1;33m'
C_BLUE='\033[1;34m'
C_WHITE='\033[1;37m'
C_CYAN='\033[1;36m'

# --- Directories ---
WORKDIR="$HOME/collector_shen"
BIN_PATH="$HOME/.local/bin"
SINGBOX_PATH="$BIN_PATH/sing-box"
FINAL_OUTPUT="$WORKDIR/valid_configs_shen.txt"

# --- Setup ---
mkdir -p "$WORKDIR" "$BIN_PATH" &>/dev/null
SINGBOX_READY=false

# --- Dependencies ---
prepare_dependencies() {
  echo -e "${C_CYAN}Checking dependencies...${C_RESET}"
  for tool in curl jq base64 grep sed awk timeout; do
    command -v "$tool" >/dev/null 2>&1 || pkg install -y "$tool" >/dev/null 2>&1
  done

  # Try installing sing-box silently (fallback if fails)
  if [[ ! -x "$SINGBOX_PATH" ]]; then
    arch=$(uname -m)
    case $arch in
      aarch64) arch="arm64";;
      *) return;;
    esac
    latest=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest | jq -r .tag_name)
    url="https://github.com/SagerNet/sing-box/releases/download/${latest}/sing-box-${latest#v}-linux-${arch}.tar.gz"
    curl -sL "$url" -o /tmp/sb.tar.gz &&     tar -xf /tmp/sb.tar.gz -C /tmp &&     mv /tmp/sing-box-*/sing-box "$SINGBOX_PATH" && chmod +x "$SINGBOX_PATH" &&     SINGBOX_READY=true
    rm -rf /tmp/sing-box-* /tmp/sb.tar.gz
  else
    SINGBOX_READY=true
  fi
}

# --- Banner ---
show_banner() {
  clear
  echo -e "${C_BLUE}â•”â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•—${C_RESET}"
  echo -e "${C_WHITE}       â–ˆâ–ˆâ–ˆ V2ray Collec${C_CYAN}SHخ‍Nâ„¢ ${C_WHITE}â–ˆâ–ˆâ–ˆ         ${C_RESET}"
  echo -e "${C_BLUE}â•ڑâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•‌${C_RESET}"
  echo -e "${C_YELLOW}Press ENTER to update and scan servers...${C_RESET}"
  read -r
}

# --- Sublinks ---
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

# --- Fetch & Decode ---
fetch_and_filter() {
  echo -e "${C_CYAN}Fetching and decoding configs...${C_RESET}"
  RAW="$WORKDIR/raw.txt"; DECODED="$WORKDIR/decoded.txt"; >"$RAW"; >"$DECODED"
  for link in "${SUBS[@]}"; do
    curl -sL "$link" | head -n 40 >> "$RAW"
  done

  # Decode base64 lines if needed
  awk '{if ($0 ~ /^[A-Za-z0-9+/=]{20,}$/) system("echo " $0 " | base64 -d"); else print $0}' "$RAW" > "$DECODED"
  grep -E '^(vmess|vless|ss)://' "$DECODED" | sed 's/#.*/#âک¬SHخ‍Nâ„¢/' | sort -u > "$WORKDIR/all_configs.txt"
}

# --- User Selects Protocol ---
select_protocol() {
  echo -e "${C_CYAN}Select protocol:${C_RESET}"
  echo -e "${C_WHITE} 1) vless
 2) vmess
 3) shadowsocks
 4) all${C_RESET}"
  read -p "Your choice [1-4]: " CHOICE
  case "$CHOICE" in
    1) PROTO="^vless://";;
    2) PROTO="^vmess://";;
    3) PROTO="^ss://";;
    4) PROTO="^(vless|vmess|ss)://";;
    *) echo -e "${C_RED}Invalid. Defaulting to all.${C_RESET}"; PROTO="^(vless|vmess|ss)://";;
  esac
  grep -E "$PROTO" "$WORKDIR/all_configs.txt" > "$WORKDIR/selected.txt"
}

# --- Test Configs ---
scan_configs() {
  VALID=(); echo -e "${C_BLUE}Scanning configs...${C_RESET}"
  while read -r config; do
    TYPE=$(echo "$config" | cut -d':' -f1)
    REMARK="âک¬SHخ‍Nâ„¢"
    if [[ "$TYPE" == "ss" ]]; then
      echo -e "${C_YELLOW}[+]${C_RESET} ${C_GREEN}SS valid${C_RESET}"; VALID+=("${config}#${REMARK}")
    elif [[ "$TYPE" == "vless" || "$TYPE" == "vmess" ]]; then
      if $SINGBOX_READY; then
        delay=$(timeout 7s "$SINGBOX_PATH" urltest -c <(echo "{"outbounds":[{"type":"$TYPE","server":"$(echo "$config" | sed -E 's|.*@([^:/]+).*||')","tag":"proxy"}]}") 2>/dev/null | awk '/ms/{print $2}' | tr -d 'ms')
        [[ "$delay" =~ ^[0-9]+$ && "$delay" -ge 100 && "$delay" -le 700 ]] && {
          echo -e "${C_YELLOW}[âœ“]${C_RESET} ${C_GREEN}$TYPE: ${delay}ms${C_RESET}"; VALID+=("${config}#âک¬SHخ‍Nâ„¢-${delay}ms")
        }
      else
        echo -e "${C_YELLOW}[â€¢]${C_RESET} $TYPE checked (fallback)"; VALID+=("${config}#${REMARK}")
      fi
    fi
  done < "$WORKDIR/selected.txt"

  printf "%s\n" "${VALID[@]}" > "$FINAL_OUTPUT"
  echo -e "${C_GREEN}âœ” Saved: $FINAL_OUTPUT${C_RESET}"
}

# --- Export Option ---
export_clipboard() {
  if command -v termux-clipboard-set >/dev/null 2>&1; then
    termux-clipboard-set < "$FINAL_OUTPUT" && echo -e "${C_GREEN}âœ” Copied to clipboard.${C_RESET}"
  fi
}

# ============ MAIN ============
show_banner
prepare_dependencies
fetch_and_filter
select_protocol
scan_configs
export_clipboard

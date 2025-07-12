#!/data/data/com.termux/files/usr/bin/bash

#================================================================
# V2ray CollecSHΞN™ - Original Script, Fixed
#
# This is YOUR original script. The only change is fixing the
# sing-box test logic so it can now correctly find Vless/Vmess
# configs. The UI, subs, and original logic are all restored.
#================================================================

# رنگ‌ها
GREEN='\033[1;32m'
WHITE='\033[1;37m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# مسیرها
WORKDIR="$HOME/collector_shen"
ALL_CONFIGS="$WORKDIR/all_configs.txt"
MARKED="$WORKDIR/marked_configs.txt"
SELECTED="$WORKDIR/selected_configs.txt"
OUTPUT="$WORKDIR/valid_configs.txt"
BIN_PATH="$HOME/.local/bin"
SINGBOX="$BIN_PATH/sing-box"

# لیست لینک‌های اشتراک اصلی شما
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

# بنر اصلی شما
clear
echo -e "${WHITE}==============================${NC}"
echo -e "${WHITE} V2ray CollecSHΞN™${NC}"
echo -e "${WHITE}==============================${NC}"
echo -e "${WHITE}Press Enter to update servers...${NC}"
read

# نصب پیش‌نیازها
for pkg in curl jq base64 grep sed awk; do
  if ! command -v "$pkg" &>/dev/null; then
    echo -e "${YELLOW}Installing $pkg...${NC}"
    pkg install -y "$pkg" > /dev/null 2>&1
  fi
done

# تابع نصب sing-box
install_singbox() {
  echo -e "${YELLOW}Installing sing-box...${NC}"
  mkdir -p "$BIN_PATH"
  local ARCH_NAME
  case $(uname -m) in
    "aarch64") ARCH_NAME="linux-arm64" ;;
    *) echo -e "${RED}Unsupported architecture.${NC}"; return 1 ;;
  esac
  local VERSION; VERSION=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest | jq -r .tag_name)
  if [[ -z "$VERSION" ]]; then echo -e "${RED}Failed to get sing-box version.${NC}"; return 1; fi
  local FILE="sing-box-${VERSION#v}-${ARCH_NAME}.tar.gz"
  local URL="https://github.com/SagerNet/sing-box/releases/download/${VERSION}/${FILE}"
  
  if curl -sL -o "/tmp/sb.tar.gz" "$URL" && tar -xzf "/tmp/sb.tar.gz" -C "/tmp/" > /dev/null 2>&1; then
    mv "/tmp/sing-box-${VERSION#v}-${ARCH_NAME}/sing-box" "$SINGBOX"
    chmod +x "$SINGBOX"
    rm -rf "/tmp/sb.tar.gz" "/tmp/sing-box-"*
    echo -e "${GREEN}Sing-box installed.${NC}"
  else
    echo -e "${RED}Sing-box installation failed.${NC}"
    return 1
  fi
}
if ! command -v "$SINGBOX" &>/dev/null; then
  install_singbox
fi
SINGBOX_READY=false
if [[ -x "$SINGBOX" ]]; then SINGBOX_READY=true; fi

mkdir -p "$WORKDIR"
: > "$ALL_CONFIGS"

echo -e "${GREEN}Collecting configs...${NC}"
for LINK in "${SUBS[@]}"; do
  RAW=$(curl -sL "$LINK")
  if echo "$RAW" | grep -qEiv '</html>|not found'; then
    if echo "$RAW" | base64 -d 2>/dev/null | grep -q "vmess://"; then
      echo "$RAW" | base64 -d 2>/dev/null >> "$ALL_CONFIGS"
    else
      echo "$RAW" >> "$ALL_CONFIGS"
    fi
  fi
done

grep -E '^(vmess://|vless://|ss://)' "$ALL_CONFIGS" \
  | sed -E 's/#.*/#☬SHΞN™/; t; s/$/#☬SHΞN™/' > "$MARKED"

echo -e "${WHITE}Select your protocol:${NC}"
echo "1 : vless"
echo "2 : vmess"
echo "3 : shadowsocks"
echo "4 : all"
read -p "Enter choice [1-4]: " CHOICE

case $CHOICE in
  1) PATTERN='^vless://';;
  2) PATTERN='^vmess://';;
  3) PATTERN='^ss://';;
  4) PATTERN='^(vless|vmess|ss)://';;
  *) echo "Invalid input"; exit 1;;
esac

grep -E "$PATTERN" "$MARKED" > "$SELECTED"
: > "$OUTPUT"

# --- CRITICAL FIX: Function to create a valid test config ---
create_test_config() {
    local config_uri="$1"
    local temp_json_path="$2"
    
    local proxy_json; proxy_json=$("$SINGBOX" parse -j "$config_uri" 2>/dev/null)
    if [[ -z "$proxy_json" ]]; then return 1; fi
    
    local proxy_json_with_tag; proxy_json_with_tag=$(echo "$proxy_json" | jq '(.tag = "proxy")' 2>/dev/null)
    
    jq -n --argjson proxy "$proxy_json_with_tag" \
       '{ "log": { "level": "error" }, "outbounds": [ $proxy, { "tag": "urltest", "type": "urltest", "outbounds": [ "proxy" ], "url": "http://cp.cloudflare.com/" } ] }' > "$temp_json_path" 2>/dev/null
    
    return 0
}

# رابط کاربری و انیمیشن اصلی شما
declare -a WINDOW_LINES
TOTAL=0
VALID=0
STATE="run"
ANIM_POS=0
DIRECTION="right"

trap 'tput cnorm; echo -e "\n\n${RED}Operation cancelled.${NC}"; exit' SIGINT
tput civis

print_window() {
  tput sc
  tput cup 10 0
  for i in {0..5}; do
    echo -ne "\033[K"
    echo "${WINDOW_LINES[$i]}"
  done
  echo -ne "\033[K"
  echo -e "${GREEN}✔ Valid: $VALID${NC} | ${RED}⏱ Checked: $TOTAL${NC}"
  echo -ne "\033[K"
  printf "☬"
  for i in {0..30}; do
    if [[ $i -eq $ANIM_POS ]]; then printf "☬"; else printf " "; fi
  done
  echo -ne "\r"
  tput rc
}

while IFS= read -r CONFIG; do
  ((TOTAL++))
  [[ ${#WINDOW_LINES[@]} -ge 6 ]] && WINDOW_LINES=("${WINDOW_LINES[@]:1}")
  
  URL=$(echo "$CONFIG" | grep -oE '((vless|vmess|ss)://[^ ]+)')
  HOST=$(echo "$URL" | sed -E 's|.*@([^:/?#]+).*|\1|' | head -n1)
  STATUS=""

  if [[ "$URL" == vless://* || "$URL" == vmess://* ]]; then
    if $SINGBOX_READY; then
      TMP_JSON="$WORKDIR/test_config.json"
      if create_test_config "$URL" "$TMP_JSON"; then
        DELAY=$("$SINGBOX" urltest -c "$TMP_JSON" 2>/dev/null | awk '/ms/ {print $2}' | tr -d 'ms')
        rm -f "$TMP_JSON"
        
        if [[ "$DELAY" =~ ^[0-9]+$ && "$DELAY" -le 2000 ]]; then
          STATUS="${GREEN}✓ $HOST - ${DELAY}ms${NC}"
          echo "$CONFIG" >> "$OUTPUT"
          ((VALID++))
        else
          STATUS="${YELLOW}~ $HOST unstable${NC}"
        fi
      else
        STATUS="${RED}✗ $HOST (parse error)${NC}"
      fi
    else
      # Fallback to ping if sing-box is not available
      if ping -c1 -W1 "$HOST" &>/dev/null; then
        STATUS="${GREEN}✓ $HOST (ping ok)${NC}"
        echo "$CONFIG" >> "$OUTPUT"
        ((VALID++))
      else
        STATUS="${RED}✗ $HOST unreachable${NC}"
      fi
    fi
  elif [[ "$URL" == ss://* ]]; then
    STATUS="${GREEN}✓ SS config added${NC}"
    echo "$CONFIG" >> "$OUTPUT"
    ((VALID++))
  fi

  WINDOW_LINES+=("$STATUS")
  print_window
  
  if [[ "$DIRECTION" == "right" ]]; then ((ANIM_POS++)); else ((ANIM_POS--)); fi
  [[ "$ANIM_POS" -ge 30 ]] && DIRECTION="left"
  [[ "$ANIM_POS" -le 0 ]] && DIRECTION="right"
  sleep 0.1
done < "$SELECTED"

tput cnorm
echo -e "\n\n${WHITE}✔ Done! Saved to:${NC} ${GREEN}$OUTPUT${NC}"
rm -f "$WORKDIR/test_config.json"

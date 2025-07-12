#!/data/data/com.termux/files/usr/bin/bash

# رنگ‌ها
GREEN='\033[1;32m'
WHITE='\033[1;37m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

WORKDIR="$HOME/collector_shen"
ALL_CONFIGS="$WORKDIR/all_configs.txt"
MARKED="$WORKDIR/marked_configs.txt"
SELECTED="$WORKDIR/selected_configs.txt"
OUTPUT="$WORKDIR/valid_configs.txt"
BIN_PATH="$HOME/.local/bin"
SINGBOX="$BIN_PATH/sing-box"

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

# بنر ساده
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
    pkg install -y "$pkg"
  fi
done

# نصب سایلنت sing-box
install_singbox() {
  mkdir -p "$BIN_PATH"
  ARCH_NAME="linux-arm64"
  VERSION=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest | jq -r .tag_name)
  FILE="sing-box-${VERSION}-${ARCH_NAME}.tar.gz"
  URL="https://github.com/SagerNet/sing-box/releases/download/${VERSION}/${FILE}"
  cd "$BIN_PATH" || return 1
  curl -sL -o sb.tar.gz "$URL" || return 1
  tar -xzf sb.tar.gz || return 1
  mv sing-box*/sing-box sing-box
  chmod +x sing-box
  rm -rf sing-box*
}
if ! command -v "$SINGBOX" &>/dev/null; then
  install_singbox
fi

mkdir -p "$WORKDIR"
: > "$ALL_CONFIGS"

echo -e "${GREEN}Collecting configs...${NC}"
for LINK in "${SUBS[@]}"; do
  RAW=$(curl -sL "$LINK")
  if echo "$RAW" | grep -qEi '^[A-Za-z0-9+/=]{20,}$'; then
    echo "$RAW" | base64 -d 2>/dev/null | head -n 40 >> "$ALL_CONFIGS"
  else
    echo "$RAW" | head -n 40 >> "$ALL_CONFIGS"
  fi
done

grep -Ei '^(vmess://|vless://|ss://)' "$ALL_CONFIGS" \
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

grep -Ei "$PATTERN" "$MARKED" > "$SELECTED"
: > "$OUTPUT"

# اسکن حرفه‌ای با باکس و انیمیشن
declare -a WINDOW_LINES
TOTAL=0
VALID=0
STATE="run"
ANIM_POS=0
DIRECTION="right"

trap '' SIGINT

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
  ID=$(date +%s%N | cut -c1-13)
  TMP_JSON="$WORKDIR/tmp_$ID.json"
  HOST=$(echo "$URL" | sed -E 's|.*@([^:/?#]+).*|\1|' | head -n1)
  STATUS=""

  if [[ "$URL" == vless://* || "$URL" == vmess://* ]]; then
    if command -v "$SINGBOX" &>/dev/null; then
      DELAY=$($SINGBOX run -c "$TMP_JSON" --test 2>/dev/null | grep -oE '[0-9]+ms' | head -n1 | tr -d 'ms')
      [[ "$DELAY" =~ ^[0-9]+$ && "$DELAY" -ge 100 && "$DELAY" -le 700 ]] && {
        STATUS="${GREEN}✓ $HOST - ${DELAY}ms${NC}"
        echo "$CONFIG" >> "$OUTPUT"
        ((VALID++))
      } || STATUS="${YELLOW}~ $HOST unstable${NC}"
    else
      ping -c1 -W1 "$HOST" &>/dev/null && {
        STATUS="${GREEN}✓ $HOST (ping ok)${NC}"
        echo "$CONFIG" >> "$OUTPUT"
        ((VALID++))
      } || STATUS="${RED}✗ $HOST unreachable${NC}"
    fi
  else
    STATUS="${GREEN}✓ SS config added${NC}"
    echo "$CONFIG" >> "$OUTPUT"
    ((VALID++))
  fi

  WINDOW_LINES+=("$STATUS")
  [[ "$STATE" == "stop" ]] && {
    echo -e "\n${YELLOW}Paused. Enter 2 to resume or 3 to export and exit:${NC}"
    read -r ACTION
    [[ "$ACTION" == "2" ]] && STATE="run"
    [[ "$ACTION" == "3" ]] && break
  }
  print_window
  [[ "$DIRECTION" == "right" ]] && ((ANIM_POS++)) || ((ANIM_POS--))
  [[ "$ANIM_POS" -ge 30 ]] && DIRECTION="left"
  [[ "$ANIM_POS" -le 0 ]] && DIRECTION="right"
done < "$SELECTED"

echo -e "\n${WHITE}✔ Done! Saved to:${NC} ${GREEN}$OUTPUT${NC}"

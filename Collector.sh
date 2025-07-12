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

clear
echo -e "${WHITE}Collector ☬SHΞN™"
echo -e "${WHITE}Press Enter to update servers...${NC}"
read

# نصب ابزارهای پایه
for pkg in curl jq base64 grep sed awk; do
  if ! command -v "$pkg" &>/dev/null; then
    echo -e "${YELLOW}Installing $pkg...${NC}"
    pkg install -y "$pkg"
  fi
done

install_singbox() {
  echo -e "${WHITE}Installing sing-box...${NC}"
  mkdir -p "$BIN_PATH"
  ARCH=$(uname -m)
  ARCH_NAME="linux-arm64"
  VERSION=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest | jq -r .tag_name)
  FILE="sing-box-${VERSION}-${ARCH_NAME}.tar.gz"
  URL="https://github.com/SagerNet/sing-box/releases/download/${VERSION}/${FILE}"
  cd "$BIN_PATH" || return 1
  curl -L -o sb.tar.gz "$URL" || return 1
  tar -xzf sb.tar.gz || return 1
  mv sing-box*/sing-box sing-box
  chmod +x sing-box
  rm -rf sing-box*
  echo -e "${GREEN}sing-box installed.${NC}"
}

if ! command -v "$SINGBOX" &>/dev/null; then
  install_singbox || echo -e "${YELLOW}sing-box installation failed, fallback will be used.${NC}"
fi

mkdir -p "$WORKDIR"
: > "$ALL_CONFIGS"

echo -e "${GREEN}Collecting configs...${NC}"
for LINK in "${SUBS[@]}"; do
  RAW=$(curl -sL "$LINK")
  if echo "$RAW" | grep -qEi '^[A-Za-z0-9+/=]{20,}$'; then
    echo "$RAW" | base64 -d 2>/dev/null >> "$ALL_CONFIGS"
  else
    echo "$RAW" >> "$ALL_CONFIGS"
  fi
done

grep -Ei '^(vmess://|vless://|ss://)' "$ALL_CONFIGS" | sed 's/$/ #☬SHΞN™/' > "$MARKED"

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

echo -e "${WHITE}Scanning configs...${NC}"
while IFS= read -r CONFIG; do
  URL=$(echo "$CONFIG" | grep -oE '((vless|vmess|ss)://[^ ]+)')
  ID=$(date +%s%N | cut -c1-13)
  TMP_JSON="$WORKDIR/tmp_$ID.json"

  if [[ "$URL" == vless://* ]]; then
    HOST=$(echo "$URL" | sed -E 's|.*@([^:/?#]+).*|\1|' | head -n1)
    echo "{\"outbounds\":[{\"type\":\"vless\",\"server\":\"$HOST\",\"port\":443,\"uuid\":\"uuid-placeholder\",\"tls\":{}}]}" > "$TMP_JSON"
  elif [[ "$URL" == vmess://* ]]; then
    echo "$URL" | cut -d// -f2 | base64 -d 2>/dev/null > "$TMP_JSON"
  else
    echo "$CONFIG" >> "$OUTPUT"
    continue
  fi

  if command -v "$SINGBOX" &>/dev/null; then
    DELAY=$($SINGBOX run -c "$TMP_JSON" --test | grep -oE '[0-9]+ms' | head -n1 | tr -d 'ms')
    if [ -n "$DELAY" ] && [ "$DELAY" -ge 100 ] && [ "$DELAY" -le 700 ]; then
      echo "$CONFIG" >> "$OUTPUT"
      echo -e "${GREEN}✓ $HOST - $DELAY ms${NC}"
    else
      echo -e "${YELLOW}~ $HOST - Unstable${NC}"
    fi
  else
    if ping -c1 -W1 "$HOST" &>/dev/null; then
      echo "$CONFIG" >> "$OUTPUT"
      echo -e "${GREEN}✓ $HOST (ping ok)${NC}"
    else
      echo -e "${RED}✗ $HOST unreachable${NC}"
    fi
  fi
done < "$SELECTED"

echo -e "${WHITE}✔ Done! Saved to:${NC} ${GREEN}$OUTPUT${NC}"

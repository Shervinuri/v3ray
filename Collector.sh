#!/data/data/com.termux/files/usr/bin/bash

# رنگ‌ها
GREEN='\033[1;32m'
WHITE='\033[1;37m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

clear
echo -e "${WHITE}Collector ☬SHΞN™${NC}"
echo -e "${WHITE}Press Enter to update servers...${NC}"
read

# چک و نصب پیش‌نیازها
REQUIRED_CMDS=(curl jq base64 grep sed awk)
for cmd in "${REQUIRED_CMDS[@]}"; do
  if ! command -v $cmd &>/dev/null; then
    echo -e "${YELLOW}Installing: $cmd${NC}"
    pkg install -y $cmd
  fi
done

# لینک‌های سابسکریپشن
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

WORKDIR="$HOME/collector_shen"
mkdir -p "$WORKDIR"
ALL_CONFIGS="$WORKDIR/all_configs.txt"
: > "$ALL_CONFIGS"

echo -e "${GREEN}Downloading configs...${NC}"
for LINK in "${SUBS[@]}"; do
  echo -e "${YELLOW}Fetching: $LINK${NC}"
  RAW=$(curl -sL "$LINK")
  if echo "$RAW" | grep -qEi '^[A-Za-z0-9+/=]{20,}$'; then
    echo "$RAW" | base64 -d 2>/dev/null >> "$ALL_CONFIGS"
  else
    echo "$RAW" >> "$ALL_CONFIGS"
  fi
done

grep -Ei '^(vmess://|vless://|ss://)' "$ALL_CONFIGS" | sed 's/$/ #☬SHΞN™/' > "$WORKDIR/marked_configs.txt"

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

SELECTED="$WORKDIR/selected_configs.txt"
: > "$SELECTED"
grep -Ei "$PATTERN" "$WORKDIR/marked_configs.txt" > "$SELECTED"

OUTPUT="$WORKDIR/valid_configs.txt"
: > "$OUTPUT"

echo -e "${WHITE}Scanning...${NC}"
while IFS= read -r CONFIG; do
  URL=$(echo "$CONFIG" | grep -oE '((vless|vmess|ss)://[^ ]+)')
  HOST=$(echo "$URL" | sed -E 's|.*//([^@:/]+).*|\1|' | head -n1)
  if [ -z "$HOST" ]; then continue; fi
  # check connectivity with delay
  START=$(date +%s)
  curl -s --connect-timeout 3 --max-time 5 -o /dev/null http://www.google.com/generate_204
  END=$(date +%s)
  DELAY=$(( (END - START) * 1000 ))
  if [ "$DELAY" -ge 100 ] && [ "$DELAY" -le 700 ]; then
    echo "$CONFIG" >> "$OUTPUT"
    echo -e "${GREEN}✓ $HOST (${DELAY}ms)${NC}"
  else
    echo -e "${YELLOW}- $HOST (Slow or unstable)${NC}"
  fi
done < "$SELECTED"

echo -e "${WHITE}✔ Finished! File saved to:${NC} ${GREEN}$OUTPUT${NC}"

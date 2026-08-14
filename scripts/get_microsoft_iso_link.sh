#!/bin/bash
# ============================================================
# get_microsoft_iso_link.sh — 从微软官方服务器生成 Windows ISO 直链
# 复刻 Fido (github.com/pbatard/Fido) 的 API 流程，2026-08 实测可用
#
# 用法:
#   bash get_microsoft_iso_link.sh                            # Win10 22H2 多版本 简体中文
#   bash get_microsoft_iso_link.sh <EditionId> [Locale] [download]
#     2378 = Win10 Home China | 2618 = Win10 多版本
#     3321/3322/3323 = Win11 (多架构自动尝试)
#     Locale: zh-CN(默认) en-us zh-tw ja-jp ko-kr de-de fr-fr
#     download: 额外参数，自动下载 x64 ISO 到当前目录
# 依赖: curl, python3
# ============================================================

ORG_ID="y6jn8c31"
PROFILE_ID="606624d44113"
INSTANCE_ID="560dc9f3-1aa5-4a2f-b63c-9e18f8d0e175"
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
REFERER="https://www.microsoft.com/software-download/windows10ISO"
MAX_ATTEMPTS=3

# ---------- 参数 ----------
EDITION_IDS="${1:-2618}"          # 支持逗号分隔多个 ID（Win11 多架构）
LOCALE="${2:-zh-CN}"
DO_DOWNLOAD="${3:-}"

# Locale -> 语言显示名（用于匹配 SKU）
case "$LOCALE" in
  zh-CN) LANG_NAME="Chinese (Simplified)" ;;
  zh-TW|zh-tw) LANG_NAME="Chinese (Traditional)" ;;
  en-US|en-us) LANG_NAME="English (United States)" ;;
  ja-JP|ja-jp) LANG_NAME="Japanese" ;;
  ko-KR|ko-kr) LANG_NAME="Korean" ;;
  de-DE|de-de) LANG_NAME="German" ;;
  fr-FR|fr-fr) LANG_NAME="French" ;;
  *) LANG_NAME="$LOCALE" ;;
esac

# ---------- 核心：单次完整会话 ----------
run_once() {
  SID=$(python -c "import uuid;print(uuid.uuid4())")
  echo "  [会话] sessionId: $SID"

  # 1. 白名单 sessionId
  curl -s -A "$UA" "https://vlscppe.microsoft.com/tags?org_id=$ORG_ID&session_id=$SID" --max-time 20 -o /dev/null

  # 2. ov-df 验证数据
  M=$(curl -s -A "$UA" "https://ov-df.microsoft.com/mdt.js?instanceId=$INSTANCE_ID&PageId=si&session_id=$SID" --max-time 20)
  W=$(echo "$M" | grep -oE '[?&]w=([A-F0-9]+)' | head -1 | sed 's/.*w=//')
  RTICKS=$(echo "$M" | grep -oE 'rticks="\+?[0-9]+' | head -1 | grep -oE '[0-9]+')
  if [ -z "$W" ] || [ -z "$RTICKS" ]; then
    echo "  [错误] ov-df 验证数据获取失败" >&2
    return 1
  fi
  MDT=$(date +%s%3N)
  curl -s -A "$UA" "https://ov-df.microsoft.com/?session_id=$SID&CustomerId=$INSTANCE_ID&PageId=si&w=$W&mdt=$MDT&rticks=$RTICKS" --max-time 20 -o /dev/null

  # 3. 获取语言 SKU
  FOUND=0
  IFS=',' read -ra IDS <<< "$EDITION_IDS"
  for EID in "${IDS[@]}"; do
    SKUS=$(curl -s -A "$UA" "https://www.microsoft.com/software-download-connector/api/getskuinformationbyproductedition?profile=$PROFILE_ID&productEditionId=$EID&SKU=undefined&friendlyFileName=undefined&Locale=$LOCALE&sessionID=$SID" --max-time 30)
    SKU_ID=$(echo "$SKUS" | python -c "
import json,sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(1)
for s in d.get('Skus', []):
    if s.get('Language') == '$LANG_NAME':
        print(s['Id']); break
" 2>/dev/null)
    if [ -n "$SKU_ID" ]; then
      echo "  [SKU] EditionId=$EID 语言 '$LANG_NAME' -> SKU=$SKU_ID"
      FOUND=1
      break
    fi
  done
  if [ "$FOUND" -ne 1 ]; then
    echo "  [错误] 未找到语言 '$LANG_NAME' 的 SKU（检查 EditionId 或 Locale）" >&2
    return 1
  fi

  # 4. 获取下载链接（必须带 Referer）
  RESP=$(curl -s -A "$UA" -e "$REFERER" "https://www.microsoft.com/software-download-connector/api/GetProductDownloadLinksBySku?profile=$PROFILE_ID&productEditionId=undefined&SKU=$SKU_ID&friendlyFileName=undefined&Locale=$LOCALE&sessionID=$SID" --max-time 30)

  # 5. 解析并输出（数据经 stdin 传递，避免跨平台 /tmp 路径差异）
  python -c "
import json,sys
d = json.load(sys.stdin)
if d.get('Errors'):
    for e in d['Errors']:
        if e.get('Type') == 8:
            print('__SENTINEL_REJECT__', file=sys.stderr); raise SystemExit(2)
    print('__API_ERROR__', d['Errors'], file=sys.stderr); raise SystemExit(1)
opts = d.get('ProductDownloadOptions', [])
if not opts:
    print('__API_ERROR__ no options', file=sys.stderr); raise SystemExit(1)
def sort_key(o):
    name = (o.get('FileNames') or o.get('Uri', '')).lower()
    size = 0
    try: size = int(o.get('SizeInBytes') or 0)
    except (TypeError, ValueError): pass
    return (0 if 'x64' in name else 1, size)
opts.sort(key=sort_key)
for i, o in enumerate(opts):
    name = o.get('FileNames') or o.get('Uri', '').split('/')[-1].split('?')[0]
    size = 0
    try: size = int(o.get('SizeInBytes') or 0) / 1024 / 1024 / 1024
    except (TypeError, ValueError): pass
    print(f'[{i}] {name}  {size:.2f} GB')
    print(f'    {o.get(\"Uri\", \"\")}')
open('.ms_iso_link.txt', 'w').write(opts[0].get('Uri', ''))
" <<< "$RESP"
  RC=$?
  if [ "$RC" -eq 2 ]; then rm -f .ms_iso_link.txt; return 2; fi   # 风控拒绝 -> 外层重试
  if [ "$RC" -ne 0 ]; then rm -f .ms_iso_link.txt; return 1; fi
  return 0
}

# ---------- 主流程：带重试 ----------
echo "[1/1] 微软官方 ISO 直链生成（最多尝试 $MAX_ATTEMPTS 次）"
for ATTEMPT in $(seq 1 $MAX_ATTEMPTS); do
  if [ "$ATTEMPT" -gt 1 ]; then
    SLEEP=$((ATTEMPT * 5))
    echo "  等待 ${SLEEP}s 后重试（第 $ATTEMPT 次）..."
    sleep $SLEEP
  fi
  run_once
  RC=$?
  if [ "$RC" -eq 0 ]; then break; fi
  if [ "$RC" -eq 2 ]; then echo "  微软风控拒绝（SentinelReject），将自动重试" >&2; continue; fi
  exit 1
done
if [ "$RC" -ne 0 ]; then
  echo "[错误] 多次尝试均失败。可能原因：微软改版/网络限制。可拉取 Fido 最新常量更新脚本：https://raw.githubusercontent.com/pbatard/Fido/master/Fido.ps1" >&2
  exit 1
fi

LINK=$(cat .ms_iso_link.txt 2>/dev/null); rm -f .ms_iso_link.txt

# ---------- 可选：自动下载 x64 ----------
if [ "$DO_DOWNLOAD" = "download" ]; then
  FNAME=$(echo "$LINK" | grep -oE '[^/]+\?t=' | sed 's/?t=//')
  [ -z "$FNAME" ] && FNAME="Win_ISO.iso"
  echo "开始下载 $FNAME（断点续传 + 自动重试）..."
  curl -L -C - --retry 5 --retry-delay 3 -A "$UA" -o "$FNAME" "$LINK"
  echo "下载完成: $(du -h "$FNAME" | cut -f1)"
else
  echo "完成。复制上方链接到 IDM/迅雷/浏览器下载（24h 内有效）"
fi

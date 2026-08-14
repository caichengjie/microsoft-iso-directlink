#!/bin/bash
# ============================================================
# get_microsoft_iso_link.sh — 从微软官方服务器生成 Windows ISO 直链
# 复刻 Fido (github.com/pbatard/Fido) 的 API 流程，2026-08 实测可用
#
# 用法:
#   bash get_microsoft_iso_link.sh                                # 默认: Win10 22H2 多版本 简体中文
#   bash get_microsoft_iso_link.sh list                           # 列出所有支持的版本
#   bash get_microsoft_iso_link.sh langs <EditionId>              # 列出某版本的全部语言
#   bash get_microsoft_iso_link.sh <EditionId> [语言] [download]  # 指定版本+语言，输出全部架构直链
#   bash get_microsoft_iso_link.sh auto [EditionId] [语言]        # AI 全自动: 下载 x64 + 校验大小
#
#   EditionId: 见 `list` 输出（如 2618/2378/3321/3322/3323）
#   语言: 支持模糊匹配（zh-CN / chinese / 简体 / English / ja 等），默认简体中文
#   download: 自动下载 x64 ISO 到当前目录（断点续传）
#   auto: 全自动模式（供 AI 调用）——生成直链 + 下载 x64 + 校验文件大小
#
# 依赖: curl, python3
# ============================================================

ORG_ID="y6jn8c31"
PROFILE_ID="606624d44113"
INSTANCE_ID="560dc9f3-1aa5-4a2f-b63c-9e18f8d0e175"
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
REFERER="https://www.microsoft.com/software-download/windows10ISO"
MAX_ATTEMPTS=3
DEFAULT_LANG_QUERY="Chinese (Simplified)"

# 支持版本矩阵（微软对非 Windows 平台暴露的全部 Windows ISO）
VERSIONS=(
  "Windows 10 22H2 v1 (Build 19045.2965 - 2023.05)"
  "  Home/Pro/Edu 多版本      EditionId=2618"
  "  Home China 中国家庭版     EditionId=2378"
  "Windows 11 25H2 v2 (Build 26200.8037 - 2026.03)"
  "  Home/Pro/Edu 多版本      EditionId=3321,3324"
  "  Home China 中国家庭版     EditionId=3322,3325"
  "  Pro China 中国专业版      EditionId=3323,3326"
)

# ---------- 参数 ----------
CMD="${1:-}"
EDITION_IDS="${2:-2618}"
LANG_QUERY="${3:-$DEFAULT_LANG_QUERY}"
DO_DOWNLOAD=""

case "$CMD" in
  list)
    echo "支持的全部 Windows 版本（微软官方）:"
    for line in "${VERSIONS[@]}"; do echo "$line"; done
    echo
    echo "提示: 使用 'bash get_microsoft_iso_link.sh langs <EditionId>' 查看某版本的全部语言"
    exit 0
    ;;
  langs)
    EID="${2:-2618}"
    echo "正在获取 EditionId=$EID 的全部语言列表..."
    bash "$0" "$EID" "__LANGS_ONLY__"
    exit 0
    ;;
  auto)
    DO_DOWNLOAD="download"
    ;;
  *)
    if [ -z "$CMD" ]; then
      # 无参数: 默认 Win10 22H2 多版本 简体中文
      EDITION_IDS="2618"; LANG_QUERY="$DEFAULT_LANG_QUERY"
    elif [[ "$CMD" =~ ^[0-9,]+$ ]]; then
      EDITION_IDS="$CMD"; LANG_QUERY="${2:-$DEFAULT_LANG_QUERY}"; DO_DOWNLOAD="${3:-}"
    else
      echo "[错误] 无法识别的参数 '$CMD'。用法见脚本头部注释。" >&2
      exit 1
    fi
    ;;
esac

# 语言查询归一化（常见别名 -> API 语言名）
case "${LANG_QUERY,,}" in
  zh-cn|zh|chinese|chinese-simplified|简体|简体中文|中文) LANG_QUERY="Chinese (Simplified)" ;;
  zh-tw|zh-hk|traditional|繁体|繁體) LANG_QUERY="Chinese (Traditional)" ;;
  en|en-us|english|英语|英文) LANG_QUERY="English (United States)" ;;
  ja|ja-jp|japanese|日语|日文) LANG_QUERY="Japanese" ;;
  ko|ko-kr|korean|韩语|韩文) LANG_QUERY="Korean" ;;
  de|de-de|german|德语|德文) LANG_QUERY="German" ;;
  fr|fr-fr|french|法语|法文) LANG_QUERY="French" ;;
esac

# ---------- 核心：单次完整会话 ----------
run_once() {
  SID=$(python -c "import uuid;print(uuid.uuid4())")
  echo "  [会话] sessionId: $SID"

  curl -s -A "$UA" "https://vlscppe.microsoft.com/tags?org_id=$ORG_ID&session_id=$SID" --max-time 20 -o /dev/null

  M=$(curl -s -A "$UA" "https://ov-df.microsoft.com/mdt.js?instanceId=$INSTANCE_ID&PageId=si&session_id=$SID" --max-time 20)
  W=$(echo "$M" | grep -oE '[?&]w=([A-F0-9]+)' | head -1 | sed 's/.*w=//')
  RTICKS=$(echo "$M" | grep -oE 'rticks="\+?[0-9]+' | head -1 | grep -oE '[0-9]+')
  if [ -z "$W" ] || [ -z "$RTICKS" ]; then
    echo "  [错误] ov-df 验证数据获取失败" >&2
    return 1
  fi
  MDT=$(date +%s%3N)
  curl -s -A "$UA" "https://ov-df.microsoft.com/?session_id=$SID&CustomerId=$INSTANCE_ID&PageId=si&w=$W&mdt=$MDT&rticks=$RTICKS" --max-time 20 -o /dev/null

  # 逐个 EditionId 尝试，模糊匹配语言
  FOUND=0
  IFS=',' read -ra IDS <<< "$EDITION_IDS"
  for EID in "${IDS[@]}"; do
    SKUS=$(curl -s -A "$UA" "https://www.microsoft.com/software-download-connector/api/getskuinformationbyproductedition?profile=$PROFILE_ID&productEditionId=$EID&SKU=undefined&friendlyFileName=undefined&Locale=zh-CN&sessionID=$SID" --max-time 30)

    # __LANGS_ONLY__ 模式：打印全部语言
    if [ "$LANG_QUERY" = "__LANGS_ONLY__" ]; then
      echo "$SKUS" | python -c "
import json,sys
d = json.load(sys.stdin)
print(f'EditionId={$EID} 全部可用语言:')
for s in d.get('Skus', []):
    print(f\"  {s['Id']:>6}  {s['Language']}\")
" 2>/dev/null
      return 0
    fi

    SKU_ID=$(echo "$SKUS" | python -c "
import json,sys
d = json.load(sys.stdin)
q = '''$LANG_QUERY'''.strip().lower()
skus = d.get('Skus', [])
def match(s):
    return s['Language'].lower()
# 1 精确 2 包含 3 反向包含
for s in skus:
    if match(s) == q: print(s['Id']); break
else:
    for s in skus:
        if q in match(s): print(s['Id']); break
    else:
        for s in skus:
            if match(s) in q: print(s['Id']); break
" 2>/dev/null)
    if [ -n "$SKU_ID" ]; then
      echo "  [SKU] EditionId=$EID 语言 '$LANG_QUERY' -> SKU=$SKU_ID"
      FOUND=1
      break
    fi
  done
  if [ "$FOUND" -ne 1 ]; then
    echo "  [错误] 未匹配到语言 '$LANG_QUERY'。可用 'bash get_microsoft_iso_link.sh langs $EDITION_IDS' 查看全部语言" >&2
    return 1
  fi

  # 获取下载链接（必须带 Referer）
  RESP=$(curl -s -A "$UA" -e "$REFERER" "https://www.microsoft.com/software-download-connector/api/GetProductDownloadLinksBySku?profile=$PROFILE_ID&productEditionId=undefined&SKU=$SKU_ID&friendlyFileName=undefined&Locale=zh-CN&sessionID=$SID" --max-time 30)

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
# 保存 x64 直链 + 期望大小（供 auto 下载校验）
first = opts[0]
open('.ms_iso_link.txt', 'w').write(first.get('Uri', ''))
open('.ms_iso_size.txt', 'w').write(str(first.get('SizeInBytes') or 0))
" <<< "$RESP"
  RC=$?
  if [ "$RC" -eq 2 ]; then rm -f .ms_iso_link.txt .ms_iso_size.txt; return 2; fi
  if [ "$RC" -ne 0 ]; then rm -f .ms_iso_link.txt .ms_iso_size.txt; return 1; fi
  return 0
}

# ---------- 主流程：带重试 ----------
echo "[1/1] 微软官方 ISO 直链生成（最多尝试 $MAX_ATTEMPTS 次）"
RC=1
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

LINK=$(cat .ms_iso_link.txt 2>/dev/null); EXPECT_SIZE=$(cat .ms_iso_size.txt 2>/dev/null)
rm -f .ms_iso_link.txt .ms_iso_size.txt

# ---------- 可选：自动下载 x64 + 校验 ----------
if [ "$DO_DOWNLOAD" = "download" ]; then
  FNAME=$(echo "$LINK" | grep -oE '[^/]+\?t=' | sed 's/?t=//')
  [ -z "$FNAME" ] && FNAME="Win_ISO.iso"
  echo "开始下载 $FNAME（断点续传 + 自动重试）..."
  curl -L -C - --retry 5 --retry-delay 3 -A "$UA" -o "$FNAME" "$LINK"
  RC=$?
  if [ $RC -ne 0 ]; then
    echo "[警告] 下载中断（退出码 $RC），可用同一命令重跑续传" >&2
    exit 1
  fi
  ACTUAL=$(du -b "$FNAME" 2>/dev/null | cut -f1)
  if [ -n "$EXPECT_SIZE" ] && [ "$EXPECT_SIZE" != "0" ] && [ "$ACTUAL" = "$EXPECT_SIZE" ]; then
    echo "✅ 校验通过: $FNAME = $ACTUAL 字节（与服务器完全一致）"
  else
    echo "⚠️  大小校验: 实际=$ACTUAL 期望=$EXPECT_SIZE（不一致请重跑续传）"
  fi
  echo "下载完成: $(du -h "$FNAME" | cut -f1)"
else
  echo "完成。复制上方链接到 IDM/迅雷/浏览器下载（24h 内有效）"
fi

#!/usr/bin/env bash
# fetch-mdpro3.sh —— 通过 GitLab API 按需拉取 MDPro3 仓库文件
#
# 背景：MDPro3 仓库（code.moenext.com/sherry_chaos/MDPro3）体积大且 git clone 不稳定
#       （服务端不支持 --filter=blob:none，全量 clone 极慢）。此脚本用 GitLab REST API
#       按需取单个文件或整个目录，速度快很多。
#
# 用法：
#   ./fetch-mdpro3.sh file  Assets/Scripts/MDPro3/Servant/SoloSelector.cs
#   ./fetch-mdpro3.sh dir   Assets/Scripts/Windbot/Game/AI/Decks
#   ./fetch-mdpro3.sh list  Assets/Scripts/Windbot          # 只列路径，不下载
#   ./fetch-mdpro3.sh tree                                  # 列整个仓库文件树
#
# 输出目录：默认 ./mdpro3-download ，可用环境变量 OUT_DIR 覆盖。
#
# 依赖：bash + curl。无鉴权（该仓库公开可读）。

set -uo pipefail

HOST="https://code.moenext.com"
PROJECT="sherry_chaos%2FMDPro3"
API="$HOST/api/v4/projects/$PROJECT/repository"
REF="${REF:-master}"
OUT_DIR="${OUT_DIR:-./mdpro3-download}"
PER_PAGE=100

need_curl() { command -v curl >/dev/null 2>&1 || { echo "错误：未找到 curl" >&2; exit 1; }; }

# 列出某个目录（递归）下的所有文件路径
list_paths() {
  local path="$1" page=1 json
  while :; do
    if [ -n "$path" ]; then
      json=$(curl -s --max-time 60 "$API/tree?path=$(urlenc "$path")&recursive=true&per_page=$PER_PAGE&page=$page&ref=$REF")
    else
      json=$(curl -s --max-time 60 "$API/tree?recursive=true&per_page=$PER_PAGE&page=$page&ref=$REF")
    fi
    [ "${#json}" -lt 5 ] && break
    local out
    out=$(printf '%s' "$json" | tr ',' '\n' | grep -o '"path":"[^"]*"' | sed 's/"path":"//;s/"$//')
    [ -z "$out" ] && break
    printf '%s\n' "$out" | grep -v '\.meta$'
    [ "$(printf '%s\n' "$out" | wc -l)" -lt "$PER_PAGE" ] && break
    page=$((page + 1))
  done | sort -u
}

urlenc() {
  local s="$1" out="" c
  local i
  for (( i=0; i<${#s}; i++ )); do
    c="${s:i:1}"
    case "$c" in
      [a-zA-Z0-9.~_-]) out+="$c" ;;
      *) out+=$(printf '%%%02X' "'$c") ;;
    esac
  done
  printf '%s' "$out"
}

fetch_file() {
  local path="$1"
  local dest="$OUT_DIR/$path"
  mkdir -p "$(dirname "$dest")"
  local code
  code=$(curl -s --max-time 90 -o "$dest" -w '%{http_code}' \
    "$API/files/$(urlenc "$path")/raw?ref=$REF")
  if [ "$code" = "200" ]; then
    printf '  ok   %s\n' "$path"
  else
    printf '  FAIL(%s) %s\n' "$code" "$path"
    rm -f "$dest"
  fi
}

need_curl
cmd="${1:-}"
case "$cmd" in
  file)
    [ $# -ge 2 ] || { echo "用法: $0 file <仓库内路径>" >&2; exit 1; }
    fetch_file "$2"
    ;;
  dir)
    [ $# -ge 2 ] || { echo "用法: $0 dir <仓库内目录>" >&2; exit 1; }
    echo "列出 $2 下的文件..."
    list_paths "$2" | while read -r p; do
      [ -n "$p" ] && fetch_file "$p"
    done
    ;;
  list)
    [ $# -ge 2 ] || { echo "用法: $0 list <仓库内目录>" >&2; exit 1; }
    list_paths "$2"
    ;;
  tree)
    list_paths ""
    ;;
  *)
    sed -n '2,20p' "$0"
    exit 1
    ;;
esac

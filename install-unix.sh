#!/usr/bin/env bash
# Neovim 配置一键安装（macOS / Linux，离线全量版）
# 用法：chmod +x install-unix.sh && ./install-unix.sh
# 可选：SKIP_FONTS=1 ./install-unix.sh   跳过字体

set -eu
STAMP="$(date +%Y%m%d-%H%M%S)"
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/nvim"
SRC_LAZY="$HERE/nvim-data/lazy"
SRC_SITE="$HERE/nvim-data/site"
SRC_FONTS="$HERE/fonts"

say()  { printf '\033[36m[nvim]\033[0m %s\n' "$1"; }
warn() { printf '\033[33m[nvim]\033[0m %s\n' "$1"; }
die()  { printf '\033[31m[nvim]\033[0m %s\n' "$1"; exit 1; }

[ -d "$SRC" ] || die "找不到 nvim 配置目录：$SRC"

command -v nvim >/dev/null 2>&1 || die "没有 nvim。macOS: brew install neovim / Linux: 用官方 tarball"
say "Neovim: $(nvim --version | head -1)"

# 目录一律以 nvim 自己报的为准
nvim_path() {
  nvim --headless --clean "+lua io.write(vim.fn.stdpath('$1'))" +qa 2>/dev/null | tr -d '\r'
}
CONFIG_DIR="$(nvim_path config)"
DATA_DIR="$(nvim_path data)"
[ -n "$CONFIG_DIR" ] || CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
[ -n "$DATA_DIR" ]   || DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"
say "配置目录: $CONFIG_DIR"
say "数据目录: $DATA_DIR"

# 1) 配置
if [ -e "$CONFIG_DIR" ]; then
  say "备份旧配置 -> ${CONFIG_DIR}.bak-$STAMP"
  cp -R "$CONFIG_DIR" "${CONFIG_DIR}.bak-$STAMP"
fi
say "写入配置..."
mkdir -p "$CONFIG_DIR"
cp -R "$SRC"/. "$CONFIG_DIR"/

# 2) 插件
mkdir -p "$DATA_DIR"
if [ -d "$SRC_LAZY" ]; then
  if [ -d "$DATA_DIR/lazy" ]; then
    say "备份旧插件目录 -> $DATA_DIR/lazy.bak-$STAMP"
    mv "$DATA_DIR/lazy" "$DATA_DIR/lazy.bak-$STAMP"
  fi
  say "拷贝插件（约 70 MB）…"
  cp -R "$SRC_LAZY" "$DATA_DIR/lazy"
else
  warn "包内没有 nvim-data/lazy，改为联网安装"
  nvim --headless "+Lazy! sync" +qa || true
fi

if [ -d "$SRC_SITE" ]; then
  say "拷贝 treesitter 解析器…"
  rm -rf "$DATA_DIR/site"
  cp -R "$SRC_SITE" "$DATA_DIR/site"
fi

# 3) 字体
if [ "${SKIP_FONTS:-0}" != "1" ] && [ -d "$SRC_FONTS" ]; then
  case "$(uname -s)" in
    Darwin) FONT_DIR="$HOME/Library/Fonts" ;;
    *)      FONT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fonts" ;;
  esac
  mkdir -p "$FONT_DIR"
  cp "$SRC_FONTS"/*.ttf "$FONT_DIR"/ 2>/dev/null || true
  if [ "$(uname -s)" != "Darwin" ] && command -v fc-cache >/dev/null 2>&1; then
    fc-cache -f >/dev/null 2>&1 || true
  fi
  say "字体已装到 $FONT_DIR（终端里把字体设成 Maple Mono NF CN）"
else
  say "已跳过字体安装"
fi

# 4) 自检
say "自检…"
CHECK_OUT="$(mktemp)"
nvim --headless "+lua io.write('NVIM_CHECK plugins=' .. tostring(#require('lazy').plugins()) .. ' colors=' .. tostring(vim.g.colors_name) .. ' compile=' .. vim.fn.exists(':Compile') .. '\n')" +qa >"$CHECK_OUT" 2>&1 || true
grep -o 'NVIM_CHECK[^[:cntrl:]]*' "$CHECK_OUT" | head -1 | while read -r line; do say "$line"; done
rm -f "$CHECK_OUT"

# 插件数量核对
if [ -f "$SRC/lazy-lock.json" ] && [ -d "$DATA_DIR/lazy" ]; then
  want=$(grep -c '":' "$SRC/lazy-lock.json" || echo 0)
  got=$(find "$DATA_DIR/lazy" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')
  if [ "$got" -ge "$want" ]; then say "插件数量核对：$got / $want ✓"; else warn "插件数量核对：$got / $want，有插件没拷全"; fi
fi

echo
say "搞定，直接运行 nvim。"
echo "旧配置备份：${CONFIG_DIR}.bak-$STAMP"

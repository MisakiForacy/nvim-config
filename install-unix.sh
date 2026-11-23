#!/usr/bin/env bash
# Neovim 配置一键安装（macOS / Linux，离线全量版）
# 用法：chmod +x install-unix.sh && ./install-unix.sh

set -eu
STAMP="$(date +%Y%m%d-%H%M%S)"
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/nvim"
SRC_LAZY="$HERE/nvim-data/lazy"
SRC_SITE="$HERE/nvim-data/site"
SRC_FONTS="$HERE/fonts"

say()  { printf '\033[36m[nvim]\033[0m %s\n' "$1"; }
warn() { printf '\033[33m[nvim]\033[0m %s\n' "$1"; }

command -v nvim >/dev/null 2>&1 || {
  echo "没有 nvim，先装："
  echo "  macOS:  brew install neovim"
  echo "  Linux:  sudo snap install nvim --classic    # 或官方 tarball"
  exit 1
}
say "Neovim: $(nvim --version | head -1)"

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"
DEST="$CONFIG_DIR/nvim"

# 1) 配置
if [ -e "$DEST" ]; then
  say "备份旧配置 -> ${DEST}.bak-$STAMP"
  cp -R "$DEST" "${DEST}.bak-$STAMP"
fi
say "写入配置 -> $DEST"
mkdir -p "$DEST"
cp -R "$SRC"/. "$DEST"/

# 2) 插件（离线拷贝）
if [ -d "$SRC_LAZY" ]; then
  if [ -d "$DATA_DIR/lazy" ]; then
    say "备份旧插件目录 -> $DATA_DIR/lazy.bak-$STAMP"
    mv "$DATA_DIR/lazy" "$DATA_DIR/lazy.bak-$STAMP"
  fi
  say "拷贝插件（约 70 MB）…"
  mkdir -p "$DATA_DIR"
  cp -R "$SRC_LAZY" "$DATA_DIR/lazy"
else
  warn "包里没有 nvim-data/lazy，改为联网安装"
  nvim --headless "+Lazy! sync" +qa || true
fi

if [ -d "$SRC_SITE" ]; then
  say "拷贝 treesitter 解析器…"
  cp -R "$SRC_SITE" "$DATA_DIR/site"
fi

# 3) 字体（复制到用户字体目录；macOS 用 ~/Library/Fonts，Linux 用 ~/.local/share/fonts）
if [ -d "$SRC_FONTS" ]; then
  case "$(uname -s)" in
    Darwin) FONT_DIR="$HOME/Library/Fonts" ;;
    *)      FONT_DIR="$HOME/.local/share/fonts" ;;
  esac
  mkdir -p "$FONT_DIR"
  cp "$SRC_FONTS"/*.ttf "$FONT_DIR"/ 2>/dev/null || true
  case "$(uname -s)" in
    Darwin) ;;
    *) command -v fc-cache >/dev/null 2>&1 && fc-cache -f >/dev/null 2>&1 || true ;;
  esac
  say "字体已装到 $FONT_DIR（终端里把字体设成 Maple Mono NF CN）"
fi

# 4) 自检
say "自检…"
nvim --headless "+lua io.write('NVIM_CHECK plugins=' .. tostring(#require('lazy').plugins()) .. ' colors=' .. tostring(vim.g.colors_name) .. '\n')" +qa 2>&1 |
  grep NVIM_CHECK | while read -r line; do say "$line"; done

echo
say "搞定，直接运行 nvim。"
echo "旧配置备份：${DEST}.bak-$STAMP"

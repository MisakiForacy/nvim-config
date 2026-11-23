#!/usr/bin/env bash
# Neovim 配置一键安装（macOS / Linux，离线全量版）
# 用法：chmod +x install-unix.sh && ./install-unix.sh
# 可选：SKIP_FONTS=1 ./install-unix.sh   跳过字体
#
# 没装 Neovim 也没关系：脚本会优先用 vendor/ 里的包，没有就联网下载官方稳定版，
# 解压到 ~/.local/opt/nvim，并在 ~/.local/bin/nvim 建软链接（不需要 root）。

set -eu
STAMP="$(date +%Y%m%d-%H%M%S)"
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/nvim"
SRC_LAZY="$HERE/nvim-data/lazy"
SRC_SITE="$HERE/nvim-data/site"
SRC_FONTS="$HERE/fonts"
VENDOR="$HERE/vendor"

say()  { printf '\033[36m[nvim]\033[0m %s\n' "$1"; }
warn() { printf '\033[33m[nvim]\033[0m %s\n' "$1"; }
die()  { printf '\033[31m[nvim]\033[0m %s\n' "$1"; exit 1; }

[ -d "$SRC" ] || die "找不到 nvim 配置目录：$SRC"

# ---------- 0. 找到或装好 Neovim ----------
NVIM=""
if command -v nvim >/dev/null 2>&1; then
  NVIM="$(command -v nvim)"
  say "已有 Neovim: $("$NVIM" --version | head -1)"
else
  say "本机没有 Neovim，开始安装便携版"
  case "$(uname -s)-$(uname -m)" in
    Linux-x86_64)        PKG="nvim-linux-x86_64"; ASSET="nvim-linux-x86_64.tar.gz" ;;
    Linux-aarch64|Linux-arm64) PKG="nvim-linux-arm64"; ASSET="nvim-linux-arm64.tar.gz" ;;
    Darwin-arm64)        PKG="nvim-macos-arm64"; ASSET="nvim-macos-arm64.tar.gz" ;;
    Darwin-x86_64)       PKG="nvim-macos-x86_64"; ASSET="nvim-macos-x86_64.tar.gz" ;;
    *) die "这个平台暂不支持自动装 Neovim（$(uname -s)-$(uname -m)），请手动装：https://github.com/neovim/neovim/releases" ;;
  esac

  OPT_DIR="$HOME/.local/opt"
  mkdir -p "$OPT_DIR"

  # 1) 包内自带
  LOCAL_TGZ=""
  for cand in "$VENDOR/$ASSET" "$VENDOR/nvim.tar.gz"; do
    [ -f "$cand" ] && LOCAL_TGZ="$cand" && break
  done
  if [ -n "$LOCAL_TGZ" ]; then
    say "使用包内自带包：$LOCAL_TGZ"
    TARBALL="$LOCAL_TGZ"
  else
    # 2) 联网下载
    TARBALL="$(mktemp -d)/$ASSET"
    URL="https://github.com/neovim/neovim/releases/download/stable/$ASSET"
    say "下载 Neovim：$URL"
    if command -v curl >/dev/null 2>&1; then
      curl -fL --retry 3 -o "$TARBALL" "$URL" || die "下载失败。可手动下载后放到 vendor/$ASSET 再跑一遍"
    elif command -v wget >/dev/null 2>&1; then
      wget -O "$TARBALL" "$URL" || die "下载失败。可手动下载后放到 vendor/$ASSET 再跑一遍"
    else
      die "既没有 curl 也没有 wget，没法下载 Neovim"
    fi
  fi

  say "解压到 $OPT_DIR ..."
  rm -rf "$OPT_DIR/$PKG"
  tar -xzf "$TARBALL" -C "$OPT_DIR"
  NVIM="$OPT_DIR/$PKG/bin/nvim"
  [ -x "$NVIM" ] || die "解压后没找到可执行文件：$NVIM"

  mkdir -p "$HOME/.local/bin"
  ln -sf "$NVIM" "$HOME/.local/bin/nvim"
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
  esac
  say "Neovim 已装好：$("$NVIM" --version | head -1)"
  say "软链接：$HOME/.local/bin/nvim（$HOME/.local/bin 不在 PATH 的话，加一下）"
fi

# 目录一律以 nvim 自己报的为准
nvim_path() {
  "$NVIM" --headless --clean "+lua io.write(vim.fn.stdpath('$1'))" +qa 2>/dev/null | tr -d '\r'
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
  "$NVIM" --headless "+Lazy! sync" +qa || true
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
"$NVIM" --headless "+lua io.write('NVIM_CHECK plugins=' .. tostring(#require('lazy').plugins()) .. ' colors=' .. tostring(vim.g.colors_name) .. ' compile=' .. vim.fn.exists(':Compile') .. ' exe=' .. vim.v.progpath .. '\n')" +qa >"$CHECK_OUT" 2>&1 || true
grep -o 'NVIM_CHECK[^[:cntrl:]]*' "$CHECK_OUT" | head -1 | while read -r line; do say "$line"; done
rm -f "$CHECK_OUT"

# 插件数量核对
if [ -f "$SRC/lazy-lock.json" ] && [ -d "$DATA_DIR/lazy" ]; then
  want=$(grep -c '":' "$SRC/lazy-lock.json" || echo 0)
  got=$(find "$DATA_DIR/lazy" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')
  if [ "$got" -ge "$want" ]; then say "插件数量核对：$got / $want ✓"; else warn "插件数量核对：$got / $want，有插件没拷全"; fi
fi

echo
say "完成。"
if [ -n "${found_nvim:-}" ]; then :; fi
echo "旧配置备份：${CONFIG_DIR}.bak-$STAMP"

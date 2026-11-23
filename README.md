# Neovim 全量配置（离线可用）

一台电脑克隆下来、跑一个脚本，就能得到跟我本机一样的 Neovim：**插件、配色、快捷键、字体全都在里面，不用联网装插件。**

- 底座：LazyVim（`lazy-lock.json` 锁版本）
- 主题：tokyonight，全透明背景
- 37 个插件（`nvim-data/lazy` 已随仓库带上，约 70 MB）
- treesitter 解析器（`nvim-data/site`，约 16 MB）
- 字体：Maple Mono NF CN 六个字重（`fonts/`，约 121 MB）

仓库比较大（~210 MB），克隆时会慢一些，但换来的是装完就能用、不依赖 GitHub 能不能连上。

## 三步装好

```bash
git clone https://github.com/MisakiForacy/nvim-config.git
cd nvim-config
```

**Windows**（PowerShell）：

```powershell
powershell -ExecutionPolicy Bypass -File .\install-windows.ps1
```

**macOS / Linux**：

```bash
chmod +x install-unix.sh && ./install-unix.sh
```

脚本会做这几件事：

1. 备份你现在的配置（`nvim.bak-时间戳`），不会直接覆盖丢东西
2. 复制 `nvim/` 到配置目录（Windows: `%LOCALAPPDATA%\nvim`，其它: `~/.config/nvim`）
3. 把 `nvim-data/lazy` 和 `nvim-data/site` 拷到数据目录 —— **这一步不联网**
4. Windows 额外把 `fonts/*.ttf` 装到用户字体目录并写注册表；macOS 装到 `~/Library/Fonts`；Linux 装到 `~/.local/share/fonts`
5. 跑一次自检，打印识别到的插件数和配色

装完在终端里把字体设成 **Maple Mono NF CN**（Windows Terminal：设置 → 配置文件 → 外观 → 字体），图标才不会变方块。

## 目录

```
nvim-config/
├─ nvim/                配置本体（init.lua / lua/config / lua/plugins）
│  └─ local/            自带的两个插件：musicode、quickrun.nvim
├─ nvim-data/
│  ├─ lazy/             37 个插件（已去掉 .git，省一半体积）
│  └─ site/             treesitter 解析器
├─ fonts/               Maple Mono NF CN（Regular / Bold / Italic / BoldItalic / Medium / MediumItalic）
├─ install-windows.ps1
├─ install-unix.sh
└─ THIRD-PARTY-NOTICES.md
```

## 这台机器配置的要点

- 缩进 4 空格、expandtab、不写 swapfile
- C/C++：clangd + clangd_extensions，开行内提示（`<leader>uh` 开关）
- 括号彩虹：rainbow-delimiters 按层上色
- 标签栏：bufferline 细线风格，去掉关闭按钮
- Markdown：`<leader>mp` 预览
- 编译运行：`<leader>cc` 编译、`<leader>cr` 编译并运行、`<leader>cR` 运行
- 音乐：musicode，flow 模式，RPC 音频后端，曲库在 `stdpath("data")/musicode/library`
- 启动页：snacks dashboard，自定义 ASCII 头

## 几个说明

- **插件没有 `.git`**：所以 `:Lazy update` 会失败。要更新插件就删掉 `nvim-data/lazy` 让 lazy 重新克隆，或者在 nvim 里手动 `:Lazy sync`。
- **musicode 的音频守护进程**：仓库里带了 Windows 版 `musicode-daemon.exe`；macOS/Linux 需要在 `nvim/local/musicode/daemon` 里 `cargo build --release`。
- **LSP 服务器（clangd 等）没打包**：那是平台相关的二进制，第一次打开 C/C++ 文件时 mason 会自动下载，或者 `:Mason` 手动装。
- **告警**：透明背景依赖终端本身支持透明；不支持的话把 `lua/config/autocmds.lua` 里 `user_transparent_bg` 那段删掉。

## 授权

- 配置本身：随你取用，不用署名
- 打包进来的第三方插件各自遵循自己的许可证，见 `THIRD-PARTY-NOTICES.md`
- Maple Mono 字体：SIL OFL 1.1

# Neovim 配置一键安装（Windows，离线全量版）
# 用法：右键「使用 PowerShell 运行」本脚本，或
#       powershell -ExecutionPolicy Bypass -File .\install-windows.ps1

$ErrorActionPreference = "Stop"
$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$Here  = Split-Path -Parent $MyInvocation.MyCommand.Path
$SrcNvim  = Join-Path $Here "nvim"
$SrcLazy  = Join-Path $Here "nvim-data\lazy"
$SrcSite  = Join-Path $Here "nvim-data\site"
$SrcFonts = Join-Path $Here "fonts"

function Say($m)  { Write-Host "[nvim] $m" -ForegroundColor Cyan }
function Warn($m) { Write-Host "[nvim] $m" -ForegroundColor Yellow }

# ---------- 0. 依赖 ----------
if (-not (Get-Command nvim -ErrorAction SilentlyContinue)) {
  Write-Host "没找到 nvim，先装：" -ForegroundColor Red
  Write-Host "  winget install Neovim.Neovim"
  exit 1
}
Say "Neovim: $(& nvim --version | Select-Object -First 1)"

# ---------- 1. 备份并写入配置 ----------
$Dest = Join-Path $env:LOCALAPPDATA "nvim"
if (Test-Path $Dest) {
  $Bak = Join-Path $env:LOCALAPPDATA "nvim.bak-$Stamp"
  Say "备份旧配置 -> $Bak"
  Copy-Item $Dest $Bak -Recurse -Force
}
Say "写入配置 -> $Dest"
New-Item -ItemType Directory -Path $Dest -Force | Out-Null
Copy-Item (Join-Path $SrcNvim "*") $Dest -Recurse -Force

# ---------- 2. 插件（离线拷贝，不联网） ----------
$DataDir = Join-Path $env:LOCALAPPDATA "nvim-data"
if (Test-Path $SrcLazy) {
  $LazyDst = Join-Path $DataDir "lazy"
  if (Test-Path $LazyDst) {
    $LazyBak = Join-Path $env:LOCALAPPDATA "nvim-data\lazy.bak-$Stamp"
    Say "备份旧插件目录 -> $LazyBak"
    Move-Item $LazyDst $LazyBak
  }
  Say "拷贝插件（约 70 MB，慢一点）…"
  New-Item -ItemType Directory -Path $DataDir -Force | Out-Null
  Copy-Item $SrcLazy $LazyDst -Recurse -Force
} else {
  Warn "包里没有 nvim-data/lazy，改为联网安装"
  & nvim --headless "+Lazy! sync" +qa
}

if (Test-Path $SrcSite) {
  Say "拷贝 treesitter 解析器…"
  Copy-Item $SrcSite (Join-Path $DataDir "site") -Recurse -Force
}

# ---------- 3. 字体 ----------
if (Test-Path $SrcFonts) {
  $FontDst = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
  New-Item -ItemType Directory -Path $FontDst -Force | Out-Null
  $regPath = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
  if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
  Get-ChildItem $SrcFonts -Filter *.ttf | ForEach-Object {
    $target = Join-Path $FontDst $_.Name
    Copy-Item $_.FullName $target -Force
    $regName = ($_.BaseName + " (TrueType)")
    New-ItemProperty -Path $regPath -Name $regName -Value $_.Name -PropertyType String -Force | Out-Null
    Say "字体已装: $($_.Name)"
  }
  Add-Type -Namespace Win32 -Name Font -MemberDefinition @'
[DllImport("gdi32.dll")] public static extern int AddFontResourceW(string path);
'@ -ErrorAction SilentlyContinue
}

# ---------- 4. 自检 ----------
Say "自检…"
& nvim --headless "+lua io.write('NVIM_CHECK plugins=' .. tostring(#require('lazy').plugins()) .. ' colors=' .. tostring(vim.g.colors_name) .. '\n')" +qa 2>&1 |
  Select-String "NVIM_CHECK" | ForEach-Object { Say $_.Line }

Write-Host ""
Say "搞定，直接运行 nvim。"
Write-Host "把终端字体设成 Maple Mono NF CN，图标才正常："
Write-Host "  Windows Terminal -> 设置 -> 配置文件 -> 外观 -> 字体 -> Maple Mono NF CN"
Write-Host "旧配置备份：$env:LOCALAPPDATA\nvim.bak-$Stamp"

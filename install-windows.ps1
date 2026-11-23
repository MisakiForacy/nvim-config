# Neovim 配置一键安装（Windows，离线全量版）
# 用法：右键「使用 PowerShell 运行」本脚本，或
#       powershell -ExecutionPolicy Bypass -File .\install-windows.ps1
# 可选：-SkipFonts  只装配置和插件，不装字体

[CmdletBinding()]
param(
  [switch]$SkipFonts
)

$ErrorActionPreference = "Stop"

function Say  { param($m) Write-Host "[nvim] $m" -ForegroundColor Cyan }
function Warn { param($m) Write-Host "[nvim] $m" -ForegroundColor Yellow }
function Die  { param($m) Write-Host "[nvim] $m" -ForegroundColor Red; exit 1 }

$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
if ($PSScriptRoot) { $Here = $PSScriptRoot } else { $Here = Split-Path -Parent $MyInvocation.MyCommand.Path }

$SrcNvim  = Join-Path $Here "nvim"
$SrcLazy  = Join-Path $Here "nvim-data\lazy"
$SrcSite  = Join-Path $Here "nvim-data\site"
$SrcFonts = Join-Path $Here "fonts"

if (-not (Test-Path $SrcNvim)) { Die "找不到 nvim 配置目录：$SrcNvim" }

# ---------- 0. 依赖 ----------
if (-not (Get-Command nvim -ErrorAction SilentlyContinue)) {
  Die "没找到 nvim。先装：winget install Neovim.Neovim"
}
Say "Neovim: $(& nvim --version | Select-Object -First 1)"

# 目录以 nvim 自己报的为准（这样 XDG / 自定义环境也能装对）
function Get-NvimPath {
  param($kind, $fallback)
  try {
    $v = & nvim --headless --clean "+lua io.write(vim.fn.stdpath('$kind'))" +qa 2>$null
    if ($v) {
      $v = $v.Trim()
      if ($v -and (Test-Path $v)) { return $v }
      if ($v) { return $v }
    }
  } catch {}
  return $fallback
}
$ConfigDir = Get-NvimPath "config" (Join-Path $env:LOCALAPPDATA "nvim")
$DataDir   = Get-NvimPath "data"   (Join-Path $env:LOCALAPPDATA "nvim-data")
Say "配置目录: $ConfigDir"
Say "数据目录: $DataDir"

# ---------- 1. 配置 ----------
if (Test-Path $ConfigDir) {
  $Bak = "$ConfigDir.bak-$Stamp"
  Say "备份旧配置 -> $Bak"
  Copy-Item $ConfigDir $Bak -Recurse -Force
}
Say "写入配置..."
New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
Copy-Item (Join-Path $SrcNvim "*") $ConfigDir -Recurse -Force

# ---------- 2. 插件 ----------
New-Item -ItemType Directory -Path $DataDir -Force | Out-Null
if (Test-Path $SrcLazy) {
  $LazyDst = Join-Path $DataDir "lazy"
  if (Test-Path $LazyDst) {
    $LazyBak = Join-Path $DataDir "lazy.bak-$Stamp"
    Say "备份旧插件目录 -> $LazyBak"
    Move-Item $LazyDst $LazyBak
  }
  Say "拷贝插件（约 70 MB，会慢一点）..."
  Copy-Item $SrcLazy $LazyDst -Recurse -Force
} else {
  Warn "包内没有 nvim-data/lazy，改为联网安装"
  & nvim --headless "+Lazy! sync" +qa
}

if (Test-Path $SrcSite) {
  Say "拷贝 treesitter 解析器..."
  $SiteDst = Join-Path $DataDir "site"
  if (Test-Path $SiteDst) { Remove-Item $SiteDst -Recurse -Force -ErrorAction SilentlyContinue }
  Copy-Item $SrcSite $SiteDst -Recurse -Force
}

# ---------- 3. 字体 ----------
if (-not $SkipFonts -and (Test-Path $SrcFonts)) {
  $FontDst = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
  New-Item -ItemType Directory -Path $FontDst -Force | Out-Null
  $regPath = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
  if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }

  $ttfs = @(Get-ChildItem $SrcFonts -Filter *.ttf -ErrorAction SilentlyContinue)
  if ($ttfs.Count -gt 0) {
    Say "安装字体（$($ttfs.Count) 个）..."
    foreach ($f in $ttfs) {
      $target = Join-Path $FontDst $f.Name
      Copy-Item $f.FullName $target -Force
      $regName = $f.BaseName + " (TrueType)"
      New-ItemProperty -Path $regPath -Name $regName -Value $target -PropertyType String -Force | Out-Null
      Say "  已装 $($f.Name)"
    }
    try {
      $signature = @"
using System;
using System.Runtime.InteropServices;
public class FontReload {
  [DllImport("user32.dll", CharSet = CharSet.Auto)]
  public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, IntPtr wParam,
      IntPtr lParam, uint fuFlags, uint uTimeout, out IntPtr lpdwResult);
  public static void Broadcast() {
    IntPtr result;
    SendMessageTimeout(new IntPtr(0xffff), 0x001D, IntPtr.Zero, IntPtr.Zero, 0x2, 1000, out result);
  }
}
"@
      Add-Type -TypeDefinition $signature -ErrorAction Stop
      [FontReload]::Broadcast()
    } catch {
      Warn "字体已写入注册表，重启一次终端或系统后生效"
    }
  }
} elseif ($SkipFonts) {
  Say "已跳过字体安装"
}

# ---------- 4. 自检 ----------
Say "自检..."
$checkFile = Join-Path $env:TEMP ("nvim-check-" + $Stamp + ".log")
& nvim --headless "+lua io.write('NVIM_CHECK plugins=' .. tostring(#require('lazy').plugins()) .. ' colors=' .. tostring(vim.g.colors_name) .. ' compile=' .. vim.fn.exists(':Compile') .. '\n')" +qa *> $checkFile
$line = Select-String -Path $checkFile -Pattern "NVIM_CHECK" | Select-Object -First 1
if ($line) { Say $line.Line } else { Warn "自检没拿到结果，打开 nvim 手动看一眼" }

# 插件数量核对：锁文件里有几个，目录里就该有几个
$lockPath = Join-Path $SrcNvim "lazy-lock.json"
if ((Test-Path $lockPath) -and (Test-Path (Join-Path $DataDir "lazy"))) {
  $lock = Get-Content $lockPath -Raw | ConvertFrom-Json
  $want = ($lock.PSObject.Properties | Measure-Object).Count
  $got  = @(Get-ChildItem (Join-Path $DataDir "lazy") -Directory -ErrorAction SilentlyContinue).Count
  if ($got -ge $want) { Say "插件数量核对：$got / $want ✓" }
  else { Warn "插件数量核对：$got / $want，有插件没拷全" }
}

Remove-Item $checkFile -ErrorAction SilentlyContinue

Write-Host ""
Say "完成，直接运行 nvim。"
Write-Host "把终端字体设成 Maple Mono NF CN，图标才正常："
Write-Host "  Windows Terminal -> 设置 -> 配置文件 -> 外观 -> 字体 -> Maple Mono NF CN"
Write-Host "旧配置备份：$ConfigDir.bak-$Stamp"

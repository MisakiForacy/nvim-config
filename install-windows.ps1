# Neovim 配置一键安装（Windows，离线全量版）
# 用法：右键「使用 PowerShell 运行」本脚本，或
#       powershell -ExecutionPolicy Bypass -File .\install-windows.ps1
#
# 参数：
#   -SkipFonts        只装配置和插件，不装字体
#   -Proxy <url>      没直连时用代理下载 Neovim，如 http://127.0.0.1:7890
#
# 如果本机没有 Neovim，脚本会自动装一份便携版到 %LOCALAPPDATA%\Programs\Neovim，
# 并加进用户 PATH（不需要管理员权限）。优先用包内 vendor\ 下的文件。

[CmdletBinding()]
param(
  [switch]$SkipFonts,
  [string]$Proxy
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
$Vendor   = Join-Path $Here "vendor"

if (-not (Test-Path $SrcNvim)) { Die "找不到 nvim 配置目录：$SrcNvim" }

# ---------- 0. 找到或装好 Neovim ----------
function Install-NvimFromZip {
  param($ZipPath, $DestRoot)
  Say "解压 Neovim 到 $DestRoot ..."
  New-Item -ItemType Directory -Path $DestRoot -Force | Out-Null
  Expand-Archive -Path $ZipPath -DestinationPath $DestRoot -Force
  $exe = Get-ChildItem $DestRoot -Recurse -Filter nvim.exe -ErrorAction SilentlyContinue |
         Select-Object -First 1
  if ($exe) { return $exe.FullName }
  return $null
}

function Add-ToUserPath {
  param($Dir)
  $cur = [Environment]::GetEnvironmentVariable("Path", "User")
  if (-not $cur) { $cur = "" }
  $parts = $cur -split ';' | Where-Object { $_ -and $_.Trim() -ne "" }
  if ($parts -contains $Dir) { return }
  $new = (@($parts) + $Dir) -join ';'
  [Environment]::SetEnvironmentVariable("Path", $new, "User")
  $env:PATH = "$Dir;$env:PATH"
  Say "已加入用户 PATH：$Dir（新开终端生效）"
}

$NvimExe = $null
$found = Get-Command nvim -ErrorAction SilentlyContinue
if ($found) {
  $NvimExe = $found.Source
  Say "已有 Neovim: $(& $NvimExe --version | Select-Object -First 1)"
} else {
  Say "本机没有 Neovim，开始安装便携版"
  $installRoot = Join-Path $env:LOCALAPPDATA "Programs\Neovim"

  # 1) 包内直接带 exe
  $vendoredExe = @(
    (Join-Path $Vendor "nvim\nvim.exe"),
    (Join-Path $Vendor "nvim.exe")
  ) | Where-Object { Test-Path $_ } | Select-Object -First 1
  if ($vendoredExe) {
    $NvimExe = $vendoredExe
    Say "使用包内自带的 Neovim：$NvimExe"
    Add-ToUserPath (Split-Path -Parent $NvimExe)
  }

  # 2) 包内带 zip
  if (-not $NvimExe) {
    $vendorZip = Join-Path $Vendor "nvim-win64.zip"
    if (Test-Path $vendorZip) {
      $NvimExe = Install-NvimFromZip $vendorZip $installRoot
      Say "使用包内的 nvim-win64.zip"
    }
  }

  # 3) 联网下载
  if (-not $NvimExe) {
    $zip = Join-Path $env:TEMP "nvim-win64.zip"
    $url = "https://github.com/neovim/neovim/releases/download/stable/nvim-win64.zip"
    Say "下载 Neovim（约 30 MB）：$url"
    $params = @{ Uri = $url; OutFile = $zip; UseBasicParsing = $true }
    if ($Proxy) { $params["Proxy"] = $Proxy }
    try {
      Invoke-WebRequest @params
    } catch {
      Die "下载失败：$($_.Exception.Message)`n可以手动下载 $url，放到 `vendor\nvim-win64.zip` 再跑一遍；或者加 -Proxy http://127.0.0.1:7890"
    }
    $NvimExe = Install-NvimFromZip $zip $installRoot
  }

  if (-not $NvimExe -or -not (Test-Path $NvimExe)) { Die "Neovim 安装失败，没找到 nvim.exe" }

  $binDir = Split-Path -Parent $NvimExe
  if ($env:PATH -notlike "*$binDir*") { $env:PATH = "$binDir;$env:PATH" }
  Add-ToUserPath $binDir
  Say "Neovim 已装好：$(& $NvimExe --version | Select-Object -First 1)"
}

# 安装目录以 nvim 自己报的为准
function Get-NvimPath {
  param($kind, $fallback)
  try {
    $v = & $NvimExe --headless --clean "+lua io.write(vim.fn.stdpath('$kind'))" +qa 2>$null
    if ($v) {
      $v = ($v | Out-String).Trim()
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
  & $NvimExe --headless "+Lazy! sync" +qa
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
& $NvimExe --headless "+lua io.write('NVIM_CHECK plugins=' .. tostring(#require('lazy').plugins()) .. ' colors=' .. tostring(vim.g.colors_name) .. ' compile=' .. vim.fn.exists(':Compile') .. ' exe=' .. vim.v.progpath .. '\n')" +qa *> $checkFile
$line = Select-String -Path $checkFile -Pattern "NVIM_CHECK" | Select-Object -First 1
if ($line) { Say $line.Line } else { Warn "自检没拿到结果，打开 nvim 手动看一眼" }

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
Say "完成。"
if ($found) {
  Write-Host "直接运行 nvim 就能用"
} else {
  Write-Host "Neovim 装在：$(Split-Path -Parent $NvimExe)"
  Write-Host "新开一个终端后直接敲 nvim 即可（当前窗口可先用完整路径 $NvimExe）"
}
Write-Host "把终端字体设成 Maple Mono NF CN，图标才正常："
Write-Host "  Windows Terminal -> 设置 -> 配置文件 -> 外观 -> 字体 -> Maple Mono NF CN"
Write-Host "旧配置备份：$ConfigDir.bak-$Stamp"

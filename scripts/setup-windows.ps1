<#
.SYNOPSIS
  Checks and installs the prerequisites for building Live Game Translator on Windows.

.DESCRIPTION
  Idempotent: safe to re-run. Installs only what is missing, using winget.
  Run from PowerShell:
    Set-ExecutionPolicy -Scope Process Bypass -Force; .\scripts\setup-windows.ps1

  Installs (if missing):
    - Rust toolchain (rustup, stable-msvc)
    - Claude Code CLI
  Verifies (does not install):
    - Git, CMake, MSVC C++ build tools, Windows SDK, CUDA Toolkit
#>

$ErrorActionPreference = 'Stop'

function Test-Cmd($name) { $null -ne (Get-Command $name -ErrorAction SilentlyContinue) }

function Write-Status($label, $ok, $detail) {
    $mark = if ($ok) { '[OK]  ' } else { '[MISS]' }
    Write-Host "$mark $label" -NoNewline
    if ($detail) { Write-Host "  ($detail)" } else { Write-Host '' }
}

if (-not (Test-Cmd winget)) {
    Write-Error 'winget is not available. Install "App Installer" from the Microsoft Store, then re-run.'
}

Write-Host "`n== Installing missing tools ==" -ForegroundColor Cyan

# --- Rust ---
if (-not (Test-Cmd rustup)) {
    Write-Host 'Installing Rust (rustup)...'
    winget install --id Rustlang.Rustup -e --accept-source-agreements --accept-package-agreements
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}
if (Test-Cmd rustup) {
    rustup toolchain install stable-msvc --profile default | Out-Null
    rustup default stable-msvc | Out-Null
    rustup component add clippy rustfmt | Out-Null
}

# --- Claude Code ---
if (-not (Test-Cmd claude)) {
    Write-Host 'Installing Claude Code...'
    winget install --id Anthropic.ClaudeCode -e --accept-source-agreements --accept-package-agreements
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}

Write-Host "`n== Verification ==" -ForegroundColor Cyan

Write-Status 'Git'        (Test-Cmd git)    $(if (Test-Cmd git)   { (git --version) })
Write-Status 'CMake'      (Test-Cmd cmake)  $(if (Test-Cmd cmake) { (cmake --version | Select-Object -First 1) })
Write-Status 'rustc'      (Test-Cmd rustc)  $(if (Test-Cmd rustc) { (rustc --version) })
Write-Status 'cargo'      (Test-Cmd cargo)  $(if (Test-Cmd cargo) { (cargo --version) })
Write-Status 'Claude Code' (Test-Cmd claude) $(if (Test-Cmd claude) { (claude --version) })

# MSVC + Windows SDK via vswhere
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$msvcOk = $false
if (Test-Path $vswhere) {
    $vsPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    $msvcOk = -not [string]::IsNullOrWhiteSpace($vsPath)
}
Write-Status 'MSVC C++ build tools' $msvcOk $vsPath

$sdkRoot = "${env:ProgramFiles(x86)}\Windows Kits\10\Include"
$sdkVer = if (Test-Path $sdkRoot) { (Get-ChildItem $sdkRoot -Directory | Sort-Object Name -Descending | Select-Object -First 1).Name }
Write-Status 'Windows SDK' ($null -ne $sdkVer) $sdkVer

$cudaRoot = "$env:ProgramFiles\NVIDIA GPU Computing Toolkit\CUDA"
$cudaVer = if (Test-Path $cudaRoot) { (Get-ChildItem $cudaRoot -Directory | Sort-Object Name -Descending | Select-Object -First 1).Name }
Write-Status 'CUDA Toolkit (optional)' ($null -ne $cudaVer) $cudaVer

Write-Host "`nIf any tool shows [MISS] after installation, open a NEW terminal (PATH updates need a fresh shell) and re-run this script." -ForegroundColor Yellow

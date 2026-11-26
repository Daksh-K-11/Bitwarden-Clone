<#
.SYNOPSIS
  Build & run Citadel on your phone. Prefers wireless debugging, falls back to USB.

.EXAMPLE
  .\scripts\run_device.ps1                       # debug, auto-select device
  .\scripts\run_device.ps1 -Wireless 192.168.29.19:41099
  .\scripts\run_device.ps1 -Release
  .\scripts\run_device.ps1 -ApiUrl http://192.168.29.10:8000   # local R2 broker
  .\scripts\run_device.ps1 -Tests                # run the test suite on the phone

.NOTES
  libsodium is compiled from source by the `sodium` package's build hook and
  needs Git Bash + GNU make. `make` is taken from the Android NDK.
  Wireless debugging ports change whenever it is toggled on the phone:
  Settings > Developer options > Wireless debugging shows the current ip:port.
#>
param(
  [string]$Wireless = $env:CITADEL_WIRELESS_DEVICE,
  [string]$Usb = 'RZCX10S32WJ',
  [string]$ApiUrl = '',
  [switch]$Release,
  [switch]$Tests
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

# --- toolchain for native build hooks ---------------------------------------
$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { "$env:LOCALAPPDATA\Android\Sdk" }
$ndk = Get-ChildItem "$sdk\ndk" -Directory | Sort-Object Name -Descending | Select-Object -First 1
$env:Path = "C:\Program Files\Git\bin;$($ndk.FullName)\prebuilt\windows-x86_64\bin;" + $env:Path
$env:GRADLE_OPTS = '-Djava.net.preferIPv4Stack=true'

# --- pick a device: wireless first, then USB --------------------------------
function Get-AdbDevices { (adb devices) -split "`n" | Where-Object { $_ -match "`tdevice" } | ForEach-Object { ($_ -split "`t")[0] } }

$device = $null
if ($Wireless) {
  adb connect $Wireless | Out-Null
  Start-Sleep -Seconds 2
  if ((Get-AdbDevices) -contains $Wireless) { $device = $Wireless }
}
if (-not $device) {
  $wifi = Get-AdbDevices | Where-Object { $_ -match ':\d+$' } | Select-Object -First 1
  if ($wifi) { $device = $wifi }
}
if (-not $device -and (Get-AdbDevices) -contains $Usb) {
  Write-Host "Wireless device not reachable - falling back to USB ($Usb)" -ForegroundColor Yellow
  $device = $Usb
}
if (-not $device) { throw 'No device found. Enable wireless debugging (or plug in USB) and retry.' }
Write-Host "Using device $device" -ForegroundColor Cyan

Push-Location "$root\frontend"
try {
  $flutterArgs = @('run', '-d', $device)
  if ($Tests) { $flutterArgs += @('-t', 'integration_test/all_tests.dart', '--no-hot') }
  if ($Release) { $flutterArgs += '--release' }
  if ($ApiUrl) { $flutterArgs += "--dart-define=CITADEL_API_URL=$ApiUrl" }
  flutter @flutterArgs
} finally {
  Pop-Location
}

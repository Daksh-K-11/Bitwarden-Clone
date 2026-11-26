<#
.SYNOPSIS
  Start the R2 presign broker (FastAPI) from the project venv, reachable from
  your phone on the LAN. Configure backend/.env first (see backend/.env.example).
#>
param([int]$Port = 8000)
$root = Split-Path -Parent $PSScriptRoot
Push-Location "$root\backend"
try {
  $ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -like '192.168.*' } | Select-Object -First 1).IPAddress
  Write-Host "Broker on http://${ip}:$Port  ->  run the app with -ApiUrl http://${ip}:$Port" -ForegroundColor Cyan
  & "$root\venv\Scripts\python.exe" -m uvicorn app.main:app --host 0.0.0.0 --port $Port
} finally {
  Pop-Location
}

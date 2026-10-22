# Cài ConAn Web API thành Windows service "WebAPI_DoHongAnhDuy" bằng NSSM. Service tự chạy khi bật máy và tự khởi động lại khi crash.
# Chạy bằng PowerShell "Run as Administrator":  powershell -ExecutionPolicy Bypass -File deploy\install-service.ps1
param([switch]$Force)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

Assert-Admin
# Bước 1: kiểm tra phần mềm cần có (không tự tải file lạ)
Assert-Command 'node' 'Tải Node.js LTS tại https://nodejs.org rồi mở lại PowerShell.'
Assert-Command 'npm'  'npm đi kèm Node.js — cài lại Node.js LTS.'
Assert-Command 'nssm' 'Tải NSSM tại https://nssm.cc/download, giải nén, chép nssm.exe (bản win64) vào C:\Windows\System32 rồi chạy lại.'
Write-Host "Node $(node -v) · NSSM sẵn sàng" -ForegroundColor Cyan

# Bước 2: service đã tồn tại?
$existing = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($existing -and -not $Force) {
    Write-Host "Service $ServiceName đã có. Muốn cập nhật code: chạy deploy\update.ps1. Muốn cài lại: thêm -Force." -ForegroundColor Yellow
    exit 0
}
if ($existing) {
    Write-Host 'Gỡ service cũ...' -ForegroundColor Yellow
    nssm stop $ServiceName | Out-Null
    nssm remove $ServiceName confirm | Out-Null
}

# Bước 3: chép code sang C:\WebAPI_DoHongAnhDuy\app và cài thư viện production
Write-Host "Chép Web API sang $AppDir ..." -ForegroundColor Cyan
Sync-AppFiles
Write-Host 'Cài thư viện (npm ci --omit=dev)...' -ForegroundColor Cyan
Install-Packages

# Bước 4: tạo service
$nodeExe = (Get-Command node).Source
Write-Host "Tạo service $ServiceName ..." -ForegroundColor Cyan
nssm install $ServiceName $nodeExe '--env-file-if-exists=.env src/server.js' | Out-Null
nssm set $ServiceName AppDirectory $AppDir | Out-Null
nssm set $ServiceName AppEnvironmentExtra 'NODE_ENV=production' | Out-Null
nssm set $ServiceName DisplayName 'WebAPI_DoHongAnhDuy (ConAn Web API)' | Out-Null
nssm set $ServiceName Description 'ConAn Web API - Do Hong Anh Duy - cong 3000 - database ConAnDB_DoHongAnhDuy' | Out-Null
nssm set $ServiceName Start SERVICE_AUTO_START | Out-Null
# Log ra file, xoay vòng theo ngày
nssm set $ServiceName AppStdout (Join-Path $LogDir 'webapi.log') | Out-Null
nssm set $ServiceName AppStderr (Join-Path $LogDir 'webapi-error.log') | Out-Null
nssm set $ServiceName AppRotateFiles 1 | Out-Null
nssm set $ServiceName AppRotateOnline 1 | Out-Null
nssm set $ServiceName AppRotateSeconds 86400 | Out-Null
# Crash thì đợi 5 giây rồi chạy lại
nssm set $ServiceName AppExit Default Restart | Out-Null
nssm set $ServiceName AppRestartDelay 5000 | Out-Null

nssm start $ServiceName | Out-Null
Write-Host 'Đợi server khởi động...' -ForegroundColor Cyan
if (Wait-Health) {
    Test-Health "http://localhost:$Port/health" | Out-Null
    Write-Host "✓ Đã cài xong. Tiếp theo: chạy deploy\start-funnel.ps1 để mở ra Internet." -ForegroundColor Green
} else {
    Write-Host "Server chưa phản hồi. Xem log: $LogDir\webapi-error.log" -ForegroundColor Red
}

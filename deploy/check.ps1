# Kiểm tra server production: có chạy ở cổng 3000 không, Tailscale Funnel, /health (local và public), cấu hình nguồn điện.
# Chạy:  powershell -ExecutionPolicy Bypass -File deploy\check.ps1   (không cần quyền Administrator)
. (Join-Path $PSScriptRoot 'common.ps1')

Write-Host "== Server cổng $Port ==" -ForegroundColor Cyan
$listen = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
if ($listen) {
    $proc = Get-Process -Id $listen.OwningProcess -ErrorAction SilentlyContinue
    Write-Host "  Đang chạy: $($proc.ProcessName) (PID $($listen.OwningProcess))" -ForegroundColor Green
} else {
    Write-Host "  Chưa có server ở cổng $Port. Mở PowerShell rồi chạy: cd webapi_dohonganhduy; npm start" -ForegroundColor Red
}

Write-Host '== /health local ==' -ForegroundColor Cyan
Test-Health "http://localhost:$Port/health" | Out-Null

Write-Host '== Tailscale Funnel ==' -ForegroundColor Cyan
if (Get-Command tailscale -ErrorAction SilentlyContinue) {
    $ts = tailscale status --json | ConvertFrom-Json
    $dnsName = $ts.Self.DNSName.TrimEnd('.')
    Write-Host "  Tailscale: $($ts.BackendState) · máy: $dnsName"
    tailscale funnel status
    Write-Host '== /health public ==' -ForegroundColor Cyan
    Test-Health "https://$dnsName/health" | Out-Null
} else {
    Write-Host '  Chưa cài Tailscale' -ForegroundColor Red
}

Write-Host '== Nguồn điện (khi cắm sạc) ==' -ForegroundColor Cyan
$sleep = powercfg /query SCHEME_CURRENT SUB_SLEEP STANDBYIDLE | Select-String 'Current AC Power Setting Index'
$hiber = powercfg /query SCHEME_CURRENT SUB_SLEEP HIBERNATEIDLE | Select-String 'Current AC Power Setting Index'
foreach ($line in @($sleep, $hiber)) {
    if ($line -and $line.ToString() -notmatch '0x00000000') {
        Write-Host "  ⚠ Máy vẫn tự Sleep/Hibernate khi cắm sạc: $line → đặt 'Never' trong Settings → System → Power" -ForegroundColor Yellow
    }
}
$lid = powercfg /query SCHEME_CURRENT SUB_BUTTONS LIDACTION | Select-String 'Current AC Power Setting Index'
if ($lid -and $lid.ToString() -notmatch '0x00000000') {
    Write-Host '  ⚠ Gập màn hình laptop đang làm máy ngủ → Control Panel → Power Options → "When I close the lid" = Do nothing' -ForegroundColor Yellow
}
Write-Host '  (không có cảnh báo ở trên = OK)'

Write-Host '== 20 dòng log cuối ==' -ForegroundColor Cyan
foreach ($f in @('webapi.log', 'webapi-error.log')) {
    $path = Join-Path $LogDir $f
    if (Test-Path $path) {
        Write-Host "-- $f" -ForegroundColor DarkGray
        Get-Content $path -Tail 20
    }
}

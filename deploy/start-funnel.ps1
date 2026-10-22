# Mở Web API (cổng 3000) ra Internet bằng Tailscale Funnel → URL HTTPS cố định https://webapi-dohonganhduy.<tailnet>.ts.net
# Chạy bằng PowerShell "Run as Administrator":  powershell -ExecutionPolicy Bypass -File deploy\start-funnel.ps1
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

Assert-Admin
Assert-Command 'tailscale' 'Cài Tailscale cho Windows tại https://tailscale.com/download rồi đăng nhập.'

# Bước 1: Tailscale đã đăng nhập chưa
$status = tailscale status --json | ConvertFrom-Json
if ($status.BackendState -ne 'Running') {
    Write-Host 'Tailscale chưa đăng nhập / chưa chạy. Mở Tailscale từ khay hệ thống và đăng nhập.' -ForegroundColor Red
    exit 1
}
$dnsName = $status.Self.DNSName.TrimEnd('.')
if ($dnsName -notlike 'webapi-dohonganhduy.*') {
    Write-Host "Tên máy hiện là '$dnsName'. Hãy đổi tên máy thành 'webapi-dohonganhduy' trong https://login.tailscale.com/admin/machines (Edit machine name) để URL có tên cá nhân." -ForegroundColor Yellow
}

# Bước 2: bật Funnel chạy nền (cấu hình được giữ qua các lần khởi động lại)
Write-Host 'Bật Tailscale Funnel cho cổng 3000...' -ForegroundColor Cyan
tailscale funnel --bg $Port
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Bật Funnel thất bại. Kiểm tra: tailnet đã bật HTTPS + Funnel trong trang admin (Access controls → nodeAttrs "funnel").' -ForegroundColor Red
    exit 1
}
tailscale funnel status

$url = "https://$dnsName"
Write-Host ''
Write-Host "URL public của Web API: $url" -ForegroundColor Green
Write-Host "Build app cho nhóm: flutter build apk --release --dart-define=API_BASE_URL=$url" -ForegroundColor Green
Start-Sleep -Seconds 3
Test-Health "$url/health" | Out-Null

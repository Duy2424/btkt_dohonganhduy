# Cập nhật server production: git pull → chép code sang C:\WebAPI_DoHongAnhDuy\app → npm ci → restart service → kiểm tra /health.
# Chạy bằng PowerShell "Run as Administrator":  powershell -ExecutionPolicy Bypass -File deploy\update.ps1
param([switch]$NoPull)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

Assert-Admin
Assert-Command 'nssm' 'Chạy deploy\install-service.ps1 trước.'

if (-not $NoPull) {
    Write-Host 'git pull...' -ForegroundColor Cyan
    git -C $RepoRoot pull --ff-only
    if ($LASTEXITCODE -ne 0) { Write-Host 'git pull thất bại — xử lý xung đột rồi chạy lại (hoặc thêm -NoPull).' -ForegroundColor Red; exit 1 }
}

Write-Host 'Chép code mới...' -ForegroundColor Cyan
Sync-AppFiles
Write-Host 'npm ci --omit=dev...' -ForegroundColor Cyan
Install-Packages

Write-Host "Khởi động lại $ServiceName ..." -ForegroundColor Cyan
nssm restart $ServiceName | Out-Null
if (Wait-Health) {
    Test-Health "http://localhost:$Port/health" | Out-Null
    Write-Host '✓ Cập nhật xong.' -ForegroundColor Green
} else {
    Write-Host "Server chưa phản hồi sau khi restart. Xem log: $LogDir\webapi-error.log" -ForegroundColor Red
    exit 1
}

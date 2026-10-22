# Hàm và đường dẫn dùng chung cho các script deploy ConAn Web API (Đỗ Hồng Anh Duy).
# Production chạy từ bản sao riêng ở C:\WebAPI_DoHongAnhDuy\app để việc dev trong repo không ảnh hưởng server thật.

$ServiceName = 'WebAPI_DoHongAnhDuy'
$RepoRoot    = Resolve-Path (Join-Path $PSScriptRoot '..')
$ApiSource   = Join-Path $RepoRoot 'webapi_dohonganhduy'
$DeployRoot  = 'C:\WebAPI_DoHongAnhDuy'
$AppDir      = Join-Path $DeployRoot 'app'
$LogDir      = Join-Path $DeployRoot 'logs'
$Port        = 3000

function Assert-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($id)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host 'Hãy mở PowerShell bằng "Run as Administrator" rồi chạy lại script.' -ForegroundColor Red
        exit 1
    }
}

function Assert-Command($name, $hint) {
    if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
        Write-Host "Chưa cài $name. $hint" -ForegroundColor Red
        exit 1
    }
}

# Chép mã nguồn Web API sang thư mục production (bỏ node_modules, test, file .env dev)
function Sync-AppFiles {
    New-Item -ItemType Directory -Force -Path $AppDir, $LogDir | Out-Null
    robocopy $ApiSource $AppDir /MIR /XD node_modules tests coverage logs /XF .env.development .env.test /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { Write-Host 'Chép file thất bại (robocopy).' -ForegroundColor Red; exit 1 }
    $global:LASTEXITCODE = 0
    if (-not (Test-Path (Join-Path $AppDir '.env'))) {
        Write-Host "Thiếu file $ApiSource\.env (copy từ .env.example rồi điền Atlas URI, Gmail App Password...)." -ForegroundColor Red
        exit 1
    }
}

function Install-Packages {
    Push-Location $AppDir
    try {
        npm ci --omit=dev --no-audit --no-fund
        if ($LASTEXITCODE -ne 0) { Write-Host 'npm ci thất bại.' -ForegroundColor Red; exit 1 }
    } finally { Pop-Location }
}

function Test-Health($url) {
    try {
        $res = Invoke-RestMethod -Uri $url -TimeoutSec 10
        Write-Host ("  {0} → status={1}, db={2}, database={3}, student={4}" -f $url, $res.status, $res.db, $res.database, $res.student) -ForegroundColor Green
        return $true
    } catch {
        Write-Host "  $url → KHÔNG phản hồi ($($_.Exception.Message))" -ForegroundColor Red
        return $false
    }
}

function Wait-Health {
    for ($i = 0; $i -lt 20; $i++) {
        Start-Sleep -Seconds 2
        try { Invoke-RestMethod -Uri "http://localhost:$Port/health" -TimeoutSec 3 | Out-Null; return $true } catch { }
    }
    return $false
}

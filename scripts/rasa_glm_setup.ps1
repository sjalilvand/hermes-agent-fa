<#
─────────────────────────────────────────────────────────────────────────────
 ماه‌افزار هوشمند رسا (Rasa) — راه‌اندازی سریع روی مدل GLM (Z.AI)
 نسخهٔ ویندوز (PowerShell 5.1+)

 استفاده:
   .\scripts\rasa_glm_setup.ps1                      # کلید را می‌پرسد
   .\scripts\rasa_glm_setup.ps1 -ApiKey "کلید-شما"   # کلید به‌صورت پارامتر
   $env:GLM_API_KEY="کلید-شما"; .\scripts\rasa_glm_setup.ps1

 اگر پیام خطای اجرای اسکریپت دیدید:
   powershell -ExecutionPolicy Bypass -File .\scripts\rasa_glm_setup.ps1

 این اسکریپت:
   1) کلید GLM_API_KEY را از پارامتر یا متغیر محیطی می‌خواند (وگرنه می‌پرسد)
   2) آن را در ~\.hermes\.env ذخیره می‌کند
   3) ~\.hermes\config.yaml را روی ارائه‌دهندهٔ zai + مدل GLM تنظیم می‌کند
   4) زبان رابط را فارسی می‌کند
─────────────────────────────────────────────────────────────────────────────
#>
param(
    [string]$ApiKey = $env:GLM_API_KEY,
    [string]$Model,
    [string]$HermesHome
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

if (-not $Model) {
    if ($env:RASA_GLM_MODEL) { $Model = $env:RASA_GLM_MODEL } else { $Model = 'glm-5.3' }
}
if (-not $HermesHome) {
    if ($env:HERMES_HOME) { $HermesHome = $env:HERMES_HOME } else { $HermesHome = Join-Path $env:USERPROFILE '.hermes' }
}
$EnvFile = Join-Path $HermesHome '.env'
$CfgFile = Join-Path $HermesHome 'config.yaml'

Write-Host ''
Write-Host '🌙 ماه‌افزار هوشمند رسا — راه‌اندازی مدل GLM (Z.AI)' -ForegroundColor Cyan
Write-Host ('─' * 49)

# ── 1) دریافت کلید ──────────────────────────────────────────────────────────
if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    $ApiKey = Read-Host 'کلید API خود را از z.ai وارد کنید'
}
if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    Write-Host '✗ کلید خالی است.' -ForegroundColor Red
    Write-Host '  راهنمای دریافت کلید: api-key-guide.html (در ریشهٔ پروژه)' -ForegroundColor Yellow
    exit 1
}

New-Item -ItemType Directory -Force -Path $HermesHome | Out-Null

# ── 2) ذخیرهٔ کلید در .env (بدون BOM تا پارسر خراب نشود) ────────────────────
$KeyLine = "GLM_API_KEY=$ApiKey"
if (Test-Path $EnvFile) {
    $Lines = @(Get-Content -Path $EnvFile -Encoding UTF8 | Where-Object { $_ -notmatch '^\s*$' })
    if ($Lines -match '^GLM_API_KEY=') {
        $Lines = $Lines -replace '^GLM_API_KEY=.*', $KeyLine
        [System.IO.File]::WriteAllText($EnvFile, (($Lines -join "`n") + "`n"))
        Write-Host "✓ GLM_API_KEY به‌روزرسانی شد → $EnvFile" -ForegroundColor Green
    }
    else {
        [System.IO.File]::WriteAllText($EnvFile, (($Lines -join "`n") + "`n" + $KeyLine + "`n"))
        Write-Host "✓ GLM_API_KEY ذخیره شد → $EnvFile" -ForegroundColor Green
    }
}
else {
    [System.IO.File]::WriteAllText($EnvFile, $KeyLine + "`n")
    Write-Host "✓ GLM_API_KEY ذخیره شد → $EnvFile" -ForegroundColor Green
}

# ── 3) پیکربندی مدل ─────────────────────────────────────────────────────────
$HermesCmd = Get-Command hermes -ErrorAction SilentlyContinue
if ($HermesCmd) {
    # اگر CLI نصب است، ویزارد رسمی تنظیمات را انجام می‌دهد
    hermes config set model.provider zai 2>$null | Out-Null
    hermes config set model.default $Model 2>$null | Out-Null
    hermes config set display.language fa 2>$null | Out-Null
    Write-Host '✓ پیکربندی با hermes config اعمال شد.' -ForegroundColor Green
}
else {
    # CLI هنوز نصب نیست → نوشتن مستقیم config.yaml
    $Block = @"
# rasa-glm-managed
model:
  provider: "zai"
  default: "$Model"
  streaming: true

agent:
  reasoning_effort: "medium"

display:
  language: "fa"
"@
    $Existing = ''
    if (Test-Path $CfgFile) {
        $Existing = [System.IO.File]::ReadAllText($CfgFile)
    }
    if ($Existing -match 'rasa-glm-managed') {
        $Updated = [regex]::Replace($Existing, '(?s)# rasa-glm-managed.*?(?=\r?\n\S|\z)', ($Block + "`n"))
        [System.IO.File]::WriteAllText($CfgFile, $Updated)
        Write-Host "✓ پیکربندی به‌روزرسانی شد → $CfgFile" -ForegroundColor Green
    }
    else {
        if (Test-Path $CfgFile) {
            $Stamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            Copy-Item $CfgFile "$CfgFile.bak.$Stamp"
            Write-Host '! config.yaml موجود بود؛ نسخهٔ پشتیبان ساخته شد.' -ForegroundColor Yellow
            [System.IO.File]::WriteAllText($CfgFile, $Block + "`n" + $Existing)
        }
        else {
            [System.IO.File]::WriteAllText($CfgFile, $Block + "`n")
        }
        Write-Host "✓ پیکربندی نوشته شد → $CfgFile" -ForegroundColor Green
    }
}

Write-Host ''
Write-Host '✅ تمام شد! حالا اجرا کنید:  rasa   (یا: hermes)' -ForegroundColor Green
Write-Host '   برای تغییر مدل:            hermes model'
Write-Host '   برای بررسی سلامت:          hermes doctor'
Write-Host '   اگر rasa شناخته نشد:       pip install -e .   (داخل پوشهٔ پروژه)'

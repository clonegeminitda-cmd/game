param([switch]$SkipTests)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
function Check-Exit($Action) {
    if ($LASTEXITCODE -ne 0) { throw "$Action failed with exit code $LASTEXITCODE" }
}
python -m pip install -r requirements-dev.txt
Check-Exit 'Install dependencies'
if (-not $SkipTests) {
    $env:QT_QPA_PLATFORM = 'offscreen'
    python -m pytest -q --durations=10 --junitxml=work/test-results.xml
    Check-Exit 'Tests'
    Remove-Item Env:QT_QPA_PLATFORM -ErrorAction SilentlyContinue
}
python -m PyInstaller --noconfirm --clean --onefile --windowed --name EmailCheckExcel --collect-data googleapiclient --exclude-module PySide6.QtWebEngineCore --exclude-module PySide6.QtWebEngineWidgets --exclude-module PySide6.QtQml --exclude-module PySide6.QtQuick --exclude-module tkinter main.py
Check-Exit 'Windows executable build'
New-Item -ItemType Directory -Force -Path work | Out-Null
$smoke = Join-Path (Get-Location) 'work\exe-smoke'
$process = Start-Process -FilePath 'dist\EmailCheckExcel.exe' -ArgumentList @('--self-test', ('"' + $smoke + '"')) -PassThru
if (-not $process.WaitForExit(180000)) {
    $process.Kill()
    throw 'Executable smoke test timed out'
}
if ($process.ExitCode -ne 0) { throw "Executable smoke test failed: $($process.ExitCode)" }
$report = Get-Content "$smoke\smoke-report.json" -Raw | ConvertFrom-Json
if (-not $report.ok) { throw 'Executable smoke test report is not successful' }
New-Item -ItemType Directory -Force -Path release | Out-Null
Copy-Item 'dist\EmailCheckExcel.exe' 'release\EmailCheckExcel.exe' -Force
Copy-Item 'README-VI.md' 'release\HUONG-DAN.md' -Force
Copy-Item 'THIRD-PARTY.md' 'release\THIRD-PARTY.md' -Force
Copy-Item 'work\exe-smoke\smoke-report.json' 'release\KIEM-THU-WINDOWS.json' -Force
python tools/make_sample.py release/sample
Check-Exit 'Sample generation'
python tools/collect_licenses.py release/LICENSES
Check-Exit 'Collect third-party notices'
Get-FileHash release\EmailCheckExcel.exe -Algorithm SHA256 | Format-List | Out-File release\SHA256.txt
Compress-Archive -Path release\* -DestinationPath EmailCheckExcel-Windows-x64.zip -Force
Write-Output 'Windows x64 build and executable smoke test completed.'

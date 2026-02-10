$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$projectDir = Split-Path -Parent $scriptDir
$casesDir = Join-Path $scriptDir 'cases'
$expectedDir = Join-Path $scriptDir 'expected'
$py2v = Join-Path $projectDir 'py2v.exe'

# Build if needed
if (-not (Test-Path $py2v)) {
    Write-Host "Building py2v..."
    Push-Location $projectDir
    v . -o py2v.exe
    Pop-Location
    if (-not (Test-Path $py2v)) {
        Write-Host "ERROR: Failed to build py2v" -ForegroundColor Red
        exit 1
    }
}

$passed = 0
$failed = 0
$skipped = 0
$failures = @()

foreach ($f in Get-ChildItem $casesDir -Filter '*.py' | Sort-Object Name) {
    $name = $f.BaseName
    $expFile = Join-Path $expectedDir ($name + '.v')

    if (-not (Test-Path $expFile)) {
        $skipped++
        Write-Host "SKIP $name" -ForegroundColor Yellow
        continue
    }

    $output = & $py2v $f.FullName 2>&1
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        $failed++
        $errMsg = ($output | Out-String).Trim()
        $failures += "FAIL $name (transpile error)"
        Write-Host "FAIL $name (transpile error)" -ForegroundColor Red
        continue
    }

    $generated = ($output | Out-String).TrimEnd("`r", "`n", " ")
    $expected = (Get-Content $expFile -Raw).TrimEnd("`r", "`n", " ")

    if ($generated -eq $expected) {
        $passed++
        Write-Host "PASS $name" -ForegroundColor Green
    } else {
        $failed++
        $failures += "FAIL $name (output mismatch)"
        Write-Host "FAIL $name (output mismatch)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "================================================"
Write-Host "Results: $passed passed, $failed failed, $skipped skipped"
Write-Host "================================================"

if ($failures.Count -gt 0) {
    Write-Host ""
    Write-Host "Failures:"
    foreach ($fl in $failures) {
        Write-Host "  $fl"
    }
    exit 1
}

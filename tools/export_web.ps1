# CI passes -SkipFixtures because its sharded fixtures job runs tests/run.tscn against the baseline.
# -NetworkSeason forwards test_network.ps1 -Season while CI only packs the summer berlin_1 bundles.
param([Parameter(Mandatory = $true)][string]$Godot, [switch]$SkipFixtures, [string]$NetworkSeason = '')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$Godot = (Get-Command $Godot -ErrorAction Stop).Source
$outputRoot = Join-Path $projectRoot 'build/web'
$logRoot = Join-Path $projectRoot 'build/logs'
New-Item -ItemType Directory -Force $outputRoot, $logRoot | Out-Null
New-Item -ItemType File -Force (Join-Path $projectRoot 'build/.gdignore') | Out-Null

function Invoke-GodotCheck([string]$Name, [string[]]$Arguments, [string]$Marker = '', [int]$Timeout = 300000) {
    $stdout = Join-Path $logRoot "$Name.log"
    $stderr = Join-Path $logRoot "$Name-errors.log"
    # Start-Process joins arguments into one Windows command line.
    $quoted = $Arguments | ForEach-Object { '"' + $_ + '"' }
    $process = Start-Process -FilePath $Godot -ArgumentList $quoted -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    try {
        if (-not $process.WaitForExit($Timeout)) { throw "$Name timed out; see $logRoot" }
        $process.WaitForExit()
        $output = (Get-Content $stdout -Raw) + (Get-Content $stderr -Raw)
        if ($process.ExitCode -ne 0 -or $output -match '(?m)^(SCRIPT ERROR:|ERROR:)' -or ($Marker -and $output -notmatch $Marker)) {
            Write-Output $output
            throw "$Name failed; see $logRoot"
        }
        Write-Output "$Name passed"
    } finally {
        if (-not $process.HasExited) { Stop-Process -Id $process.Id }
    }
}

Invoke-GodotCheck 'import' @('--headless', '--path', $projectRoot, '--editor', '--import')
# Seasonal native worlds load hundreds of megabytes per match. Fixtures compare MultiMesh
# and texture buffers, which the headless renderer discards; ANGLE also runs on GPU-less CI.
if (-not $SkipFixtures) { Invoke-GodotCheck 'fixtures' @('--path', $projectRoot, '--rendering-method', 'gl_compatibility', '--rendering-driver', 'opengl3_angle', '--audio-driver', 'Dummy', '--position', '-32000,-32000', '--resolution', '64x64', 'res://tests/run.tscn') 'TEST_PASS' 1800000 }
Invoke-GodotCheck 'smoke' @('--headless', '--path', $projectRoot, '--', '--smoke') 'SMOKE_PASS' 600000
& (Join-Path $PSScriptRoot 'test_network.ps1') -Godot $Godot -Season $NetworkSeason
Invoke-GodotCheck 'export' @('--headless', '--path', $projectRoot, '--export-release', 'Web', (Join-Path $outputRoot 'index.html'))
foreach ($file in @('index.html', 'index.js', 'index.wasm', 'index.pck')) {
    if (-not (Test-Path (Join-Path $outputRoot $file)) -or (Get-Item (Join-Path $outputRoot $file)).Length -eq 0) {
        throw "Missing Web export: $file"
    }
}
New-Item -ItemType File -Force (Join-Path $outputRoot '.nojekyll') | Out-Null
Write-Output "Web build ready: $outputRoot"

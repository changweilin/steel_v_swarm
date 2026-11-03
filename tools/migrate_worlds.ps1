param(
    [Parameter(Mandatory = $true)][string]$Godot,
    [string]$Node = 'node',
    [ValidatePattern('^[a-zA-Z0-9_]+$')][string[]]$Bundle = @(),
    [ValidatePattern('^[a-zA-Z0-9_]+$')][string[]]$Map = @(),
    [ValidateRange(60,86400)][int]$TimeoutSeconds = 3600
)
$ErrorActionPreference = 'Stop'
$migrationRoot = Split-Path $PSScriptRoot -Parent
$migrationGodot = (Get-Command $Godot -ErrorAction Stop).Source
$migrationNode = (Get-Command $Node -ErrorAction Stop).Source
$migrationStamp = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss-fff')
$migrationLogs = Join-Path $migrationRoot "artifacts/world-generation/$migrationStamp"
New-Item -ItemType Directory -Path $migrationLogs -Force | Out-Null

function Invoke-WorldTool([string]$Name, [string]$Executable, [string[]]$Arguments, [string]$Marker = '') {
    $stdout = Join-Path $migrationLogs "$Name.log"
    $stderr = Join-Path $migrationLogs "$Name-errors.log"
    $quoted = $Arguments | ForEach-Object { '"' + $_ + '"' }
    $process = Start-Process -FilePath $Executable -ArgumentList $quoted -WorkingDirectory $migrationRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $null = $process.Handle
    Write-Output "WORLD_STEP_STARTED step=$Name owned_pid=$($process.Id) log=$stdout"
    $started = [DateTime]::UtcNow
    try {
        while (-not $process.WaitForExit(1000)) {
            if (([DateTime]::UtcNow - $started).TotalSeconds -ge $TimeoutSeconds) {
                throw "World migration timed out: $Name owned_pid=$($process.Id)"
            }
        }
        $process.WaitForExit()
        $output = (Get-Content -LiteralPath $stdout -Raw) + (Get-Content -LiteralPath $stderr -Raw)
        if ($process.ExitCode -ne 0 -or $output -match '(?m)^(SCRIPT ERROR:|ERROR:)' -or ($Marker -and $output -notmatch $Marker)) {
            throw "World migration failed: $Name exit=$($process.ExitCode); see $stdout and $stderr"
        }
        Write-Output "WORLD_STEP_PASS step=$Name seconds=$([math]::Round(([DateTime]::UtcNow - $started).TotalSeconds,2)) stderr_bytes=$((Get-Item -LiteralPath $stderr).Length)"
    } finally {
        if (-not $process.HasExited) {
            # Stop only this owned tool and its browser descendants on cancellation/timeout.
            & taskkill.exe /PID $process.Id /T /F | Out-Null
        }
    }
}

$selection = @($Map) + @($Bundle | ForEach-Object { "--bundle=$_" })
$manifestFile = Join-Path $migrationLogs 'manifest.json'
$manifestErrors = Join-Path $migrationLogs 'manifest-errors.log'
$manifestArguments = @((Join-Path $PSScriptRoot 'bake_worlds.mjs'), '--list-bundles') + $selection
$quotedManifest = $manifestArguments | ForEach-Object { '"' + $_ + '"' }
$manifestProcess = Start-Process -FilePath $migrationNode -ArgumentList $quotedManifest -WorkingDirectory $migrationRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput $manifestFile -RedirectStandardError $manifestErrors
$null = $manifestProcess.Handle
try {
    if (-not $manifestProcess.WaitForExit(60000)) { throw 'Source world manifest enumeration timed out' }
    $manifestProcess.WaitForExit()
    if ($manifestProcess.ExitCode -ne 0) { throw "Source world selection failed; see $manifestErrors" }
} finally {
    if (-not $manifestProcess.HasExited) { Stop-Process -Id $manifestProcess.Id -Force }
}
$worldBundles = @(Get-Content -LiteralPath $manifestFile -Raw | ConvertFrom-Json)
if ($worldBundles.Count -eq 0) { throw 'Original world manifest is empty' }
Write-Output "WORLD_MIGRATION_BEGIN bundles=$($worldBundles.Count) logs=$migrationLogs"
$completed = 0
foreach ($worldBundle in $worldBundles) {
    if ($worldBundle -notmatch '^[a-zA-Z0-9_]+$') { throw 'Invalid source world bundle identity' }
    Invoke-WorldTool "$worldBundle-capture" $migrationNode @('--max-old-space-size=8192', (Join-Path $PSScriptRoot 'bake_worlds.mjs'), '--reuse', "--bundle=$worldBundle") '(source geometry reused| meshes, \d+ decks, \d+ tunnels)'
    Invoke-WorldTool "$worldBundle-storage" $migrationNode @((Join-Path $PSScriptRoot 'verify_world_source.mjs'), $worldBundle) 'WORLD_SOURCE_STORAGE_PASS '
    Invoke-WorldTool "$worldBundle-provenance" $migrationNode @((Join-Path $PSScriptRoot 'verify_world_provenance.mjs'), $worldBundle) 'WORLD_SOURCE_PROVENANCE_PASS '
    Invoke-WorldTool "$worldBundle-references" $migrationNode @((Join-Path $PSScriptRoot 'world_references.mjs'), $worldBundle) 'Source layered-deck query references generated'
    Invoke-WorldTool "$worldBundle-reference-inputs" $migrationNode @((Join-Path $PSScriptRoot 'verify_world_provenance.mjs'), $worldBundle) 'WORLD_SOURCE_PROVENANCE_PASS '
    Invoke-WorldTool "$worldBundle-native" $migrationGodot @('--path', $migrationRoot, '--rendering-method', 'gl_compatibility', '--rendering-driver', 'opengl3', '--disable-render-loop', '--audio-driver', 'Dummy', '--position', '-32000,-32000', '--resolution', '1x1', 'res://tools/import_worlds.tscn', '--', "--bundle=$worldBundle") "WORLD_IMPORTED $([regex]::Escape($worldBundle))"
    $completed++
    Write-Output "WORLD_BUNDLE_COMPLETE bundle=$worldBundle completed=$completed total=$($worldBundles.Count)"
}
Write-Output "WORLD_MIGRATION_COMPLETE bundles=$completed"

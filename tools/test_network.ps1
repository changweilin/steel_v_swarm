param([Parameter(Mandatory = $true)][string]$Godot, [switch]$LobControl, [switch]$KineticShots, [switch]$MissileShots, [switch]$Reachability, [switch]$Footprints, [switch]$Cockpits, [switch]$Cameras, [switch]$Bursts, [switch]$Projectiles, [switch]$Aiming, [switch]$MissileDefenses, [switch]$Bots, [switch]$Bosses, [switch]$Campaign, [switch]$Super, [switch]$Controls, [switch]$Mobile, [switch]$View, [switch]$Bodies, [switch]$Tps, [switch]$Deaths, [switch]$Blasts, [switch]$Rooms, [switch]$Loading, [switch]$Roster, [switch]$Members, [switch]$Spectators, [switch]$LateSpectators, [switch]$Rematch, [switch]$Recovery, [switch]$RecoveryQueue, [switch]$SnapshotEvents, [switch]$QuickRestart, [switch]$Fatal, [switch]$Pips, [switch]$HeadMarks, [switch]$VitalBars, [switch]$Minimap, [switch]$Balance, [switch]$LobbyLatency, [ValidateSet("enet", "websocket")][string[]]$Transport = @("enet", "websocket"))
$ErrorActionPreference = 'Stop'
if (@($LobControl, $KineticShots, $MissileShots, $Reachability, $Footprints, $Cockpits, $Cameras, $Bursts, $Projectiles, $Aiming, $MissileDefenses, $Bots, $Bosses, $Campaign, $Super, $Controls, $Mobile, $View, $Bodies, $Tps, $Deaths, $Blasts, $Rooms, $Loading, $Roster, $Members, $Spectators, $LateSpectators, $Rematch, $Recovery, $RecoveryQueue, $SnapshotEvents, $QuickRestart, $Fatal, $Pips, $HeadMarks, $VitalBars, $Minimap, $Balance, $LobbyLatency).Where({ $_ }).Count -gt 1) { throw 'Choose one gameplay transport fixture per run' }
$projectRoot = Split-Path $PSScriptRoot -Parent
$processes = @()
$recoveryStores = @()
$recoveryRunId = [Guid]::NewGuid().ToString('N')
try {
    foreach ($mode in $Transport) {
        $listenPort = if ($mode -eq 'enet') { 18762 } else { 18763 }
        if ($RecoveryQueue -or $SnapshotEvents) {
            # Isolated real peers exercise delivery; no authored-world or combat parity is implied.
            $isolatedScene = if ($SnapshotEvents) { 'res://tests/snapshot_events_transport.tscn' } else { 'res://tests/room_recovery_transport.tscn' }
            $isolatedMarker = if ($SnapshotEvents) { 'SNAPSHOT_EVENTS_TRANSPORT_RESULT' } else { 'RECOVERY_TRANSPORT_RESULT' }
            $isolatedName = if ($SnapshotEvents) { 'snapshot-events' } else { 'recovery-queue' }
            $queueArguments = @('--headless', '--path', $projectRoot, $isolatedScene, '--', "--port=$listenPort")
            if ($mode -eq 'websocket') { $queueArguments += '--websocket' }
            $queue = Start-Process -FilePath $Godot -ArgumentList $queueArguments -WindowStyle Hidden -PassThru -RedirectStandardOutput "$projectRoot/tests/$mode-$isolatedName.log" -RedirectStandardError "$projectRoot/tests/$mode-$isolatedName-errors.log"
            $null = $queue.Handle
            $processes += $queue
            $isolatedTimeout = if ($SnapshotEvents) { 90000 } else { 40000 }
            if (-not $queue.WaitForExit($isolatedTimeout)) { throw "$mode $isolatedName test timed out" }
            $queueLog = [string](Get-Content -LiteralPath "$projectRoot/tests/$mode-$isolatedName.log" -Raw)
            $queueErrors = [string](Get-Content -LiteralPath "$projectRoot/tests/$mode-$isolatedName-errors.log" -Raw)
            if ($queue.ExitCode -ne 0 -or $queueLog -notmatch "$isolatedMarker transport=$mode assertions=\d+ failures=0" -or -not [string]::IsNullOrWhiteSpace($queueErrors) -or $queueLog -match 'ERROR|above the MTU') {
                throw "$mode $isolatedName failed: $queueLog $queueErrors"
            }
            Write-Output $queueLog.Trim()
            continue
        }
        $serverArguments = @('--headless', '--path', $projectRoot, '--', '--server', '--port', $listenPort)
        if ($MissileShots) { $serverArguments = @('--headless', '--path', $projectRoot, 'res://tests/missile_network.tscn', '--', '--server', '--port', $listenPort) }
        if ($Reachability) { $serverArguments = @('--headless', '--path', $projectRoot, 'res://tests/reachability_network.tscn', '--', '--server', '--port', $listenPort) }
        if ($Footprints) { $serverArguments = @('--headless', '--path', $projectRoot, 'res://tests/footprint_network.tscn', '--', '--server', '--port', $listenPort) }
        if ($Cockpits) { $serverArguments = @('--headless', '--path', $projectRoot, 'res://tests/cockpit_network.tscn', '--', '--server', '--port', $listenPort) }
        if ($Cameras) { $serverArguments = @('--headless', '--path', $projectRoot, 'res://tests/camera_network.tscn', '--', '--server', '--port', $listenPort) }
        if ($Bursts) { $serverArguments = @('--headless', '--path', $projectRoot, 'res://tests/burst_network.tscn', '--', '--server', '--port', $listenPort) }
        if ($Projectiles) { $serverArguments = @('--headless', '--path', $projectRoot, 'res://tests/projectile_visual_network.tscn', '--', '--server', '--port', $listenPort) }
        if ($Aiming) { $serverArguments = @('--headless', '--path', $projectRoot, 'res://tests/aiming_network.tscn', '--', '--server', '--port', $listenPort) }
        if ($MissileDefenses) { $serverArguments = @('--headless', '--path', $projectRoot, 'res://tests/missile_defense_network.tscn', '--', '--server', '--port', $listenPort) }
        if ($Bots) { $serverArguments = @('--headless', '--path', $projectRoot, 'res://tests/bot_network.tscn', '--', '--server', '--port', $listenPort) }
        if ($Bosses) { $serverArguments = @('--headless', '--path', $projectRoot, 'res://tests/boss_network.tscn', '--', '--server', '--port', $listenPort) }
        if ($Campaign) { $serverArguments = @('--headless', '--path', $projectRoot, 'res://tests/campaign_network.tscn', '--', '--server', '--campaign', 'ch1', '--side', 'STEEL', '--character', 't06', '--port', $listenPort) }
        if ($Super) { $serverArguments = @('--headless', '--path', $projectRoot, 'res://tests/super_network.tscn', '--', '--server', '--super', '--port', $listenPort) }
        if ($Controls) { $serverArguments = @('--headless', '--path', $projectRoot, 'res://tests/controls_network.tscn', '--', '--server', '--port', $listenPort) }
        if ($Mobile) { $serverArguments = @('--headless', '--path', $projectRoot, 'res://tests/mobile_network.tscn', '--', '--server', '--ctrl', 'pad', '--port', $listenPort) }
        if ($View) { $serverArguments = @('--headless', '--path', $projectRoot, 'res://tests/view_network.tscn', '--', '--server', '--ctrl', 'pad', '--port', $listenPort) }
        if ($Bodies) { $serverArguments = @('--headless', '--path', $projectRoot, 'res://tests/body_network.tscn', '--', '--server', '--port', $listenPort) }
        if ($Tps) { $serverArguments = @('--headless', '--path', $projectRoot, 'res://tests/tps_network.tscn', '--', '--server', '--port', $listenPort) }
        if ($Deaths) { $serverArguments = @('--headless', '--path', $projectRoot, 'res://tests/death_network.tscn', '--', '--server', '--port', $listenPort) }
        if ($Blasts) { $serverArguments = @('--headless', '--path', $projectRoot, 'res://tests/blast_network.tscn', '--', '--server', '--port', $listenPort) }
        if ($Rooms) { $serverArguments = @('--headless', '--path', $projectRoot, 'res://tests/room_network.tscn', '--', '--server', '--port', $listenPort) }
        if ($Loading) { $serverArguments = @('--headless', '--path', $projectRoot, 'res://tests/room_loading_network.tscn', '--', '--server', '--port', $listenPort) }
        if ($Roster) { $serverArguments = @('--headless', '--path', $projectRoot, 'res://tests/room_roster_network.tscn', '--', '--server', '--port', $listenPort) }
        if ($Members) { $serverArguments = @('--headless', '--path', $projectRoot, 'res://tests/room_member_network.tscn', '--', '--server', '--port', $listenPort) }
        if ($Spectators -or $LateSpectators) { $serverArguments = @('--headless', '--path', $projectRoot, 'res://tests/spectator_network.tscn', '--', '--server', '--port', $listenPort) }
        if ($LateSpectators) { $serverArguments += @('--late') }
        if ($Rematch) { $serverArguments = @('--headless', '--path', $projectRoot, 'res://tests/room_rematch_network.tscn', '--', '--server', '--port', $listenPort) }
        if ($Recovery) { $serverArguments = @('--headless', '--path', $projectRoot, 'res://tests/room_recovery_network.tscn', '--', '--server', '--port', $listenPort) }
        if ($QuickRestart) { $serverArguments = @('--headless', '--path', $projectRoot, 'res://tests/quick_restart_network.tscn', '--', '--quick-restart', '--listen', $mode, '--port', $listenPort) }
        if ($Fatal) { $serverArguments = @('--headless', '--path', $projectRoot, 'res://tests/fatal_network.tscn', '--', '--server', '--port', $listenPort) }
        if ($Pips) { $serverArguments = @('--headless', '--path', $projectRoot, 'res://tests/pip_network.tscn', '--', '--server', '--port', $listenPort) }
        if ($HeadMarks) { $serverArguments = @('--headless', '--path', $projectRoot, 'res://tests/head_mark_network.tscn', '--', '--server', '--port', $listenPort) }
        if ($VitalBars) { $serverArguments = @('--headless', '--path', $projectRoot, 'res://tests/vital_bar_network.tscn', '--', '--server', '--port', $listenPort) }
        if ($Minimap) { $serverArguments = @('--headless', '--path', $projectRoot, 'res://tests/minimap_network.tscn', '--', '--server', '--port', $listenPort) }
        if ($Balance) { $serverArguments = @('--headless', '--path', $projectRoot, 'res://tests/balance_network.tscn', '--', '--server', '--port', $listenPort) }
        if ($LobbyLatency) { $serverArguments = @('--headless', '--path', $projectRoot, 'res://tests/lobby_latency_network.tscn', '--', '--server', '--port', $listenPort) }
        $serverArguments += @('--view', $(if ($Tps) { 'tps' } else { 'fpv' }))
        if ($mode -eq 'websocket') { $serverArguments += '--websocket' }
        $server = Start-Process -FilePath $Godot -ArgumentList $serverArguments -WindowStyle Hidden -PassThru -RedirectStandardOutput "$projectRoot/tests/$mode-server.log" -RedirectStandardError "$projectRoot/tests/$mode-server-errors.log"
        $null = $server.Handle
        $processes += $server
        if ($QuickRestart) {
            $quickDeadline = [DateTime]::UtcNow.AddSeconds(45)
            do {
                $server.Refresh()
                if ($server.HasExited) { throw "$mode quick-restart authority exited before launching the saved match" }
                $quickLog = "$(Get-Content -LiteralPath "$projectRoot/tests/$mode-server.log" -Raw -ErrorAction SilentlyContinue)"
                if ($quickLog.Contains('QUICK_RESTART_READY')) { break }
                if ([DateTime]::UtcNow -ge $quickDeadline) { throw "$mode saved match did not finish authority preparation" }
                Start-Sleep -Milliseconds 100
            } while ($true)
        }
        $target = if ($mode -eq 'enet') { '127.0.0.1' } else { "ws://127.0.0.1:$listenPort" }
        $clientArguments = @('--headless', '--path', $projectRoot, '--', '--connect', $target, '--port', $listenPort, '--network-test')
        if ($MissileShots) { $clientArguments = @('--headless', '--path', $projectRoot, 'res://tests/missile_network.tscn', '--', '--connect', $target, '--port', $listenPort, '--character', 't08', '--side', 'STEEL') }
        if ($Reachability) { $clientArguments = @('--headless', '--path', $projectRoot, 'res://tests/reachability_network.tscn', '--', '--connect', $target, '--port', $listenPort, '--character', 't09', '--side', 'STEEL') }
        if ($Footprints) { $clientArguments = @('--headless', '--path', $projectRoot, 'res://tests/footprint_network.tscn', '--', '--connect', $target, '--port', $listenPort, '--character', 't09', '--side', 'STEEL') }
        if ($Cockpits) { $clientArguments = @('--headless', '--path', $projectRoot, 'res://tests/cockpit_network.tscn', '--', '--connect', $target, '--port', $listenPort, '--character', 't03', '--side', 'STEEL') }
        if ($Cameras) { $clientArguments = @('--headless', '--path', $projectRoot, 'res://tests/camera_network.tscn', '--', '--connect', $target, '--port', $listenPort, '--character', 'm01', '--side', 'STEEL') }
        if ($Bursts) { $clientArguments = @('--headless', '--path', $projectRoot, 'res://tests/burst_network.tscn', '--', '--connect', $target, '--port', $listenPort, '--character', 't06', '--side', 'STEEL') }
        if ($Projectiles) { $clientArguments = @('--headless', '--path', $projectRoot, 'res://tests/projectile_visual_network.tscn', '--', '--connect', $target, '--port', $listenPort, '--character', 't09', '--side', 'STEEL') }
        if ($Aiming) { $clientArguments = @('--headless', '--path', $projectRoot, 'res://tests/aiming_network.tscn', '--', '--connect', $target, '--port', $listenPort, '--character', 't09', '--side', 'STEEL') }
        if ($MissileDefenses) { $clientArguments = @('--headless', '--path', $projectRoot, 'res://tests/missile_defense_network.tscn', '--', '--connect', $target, '--port', $listenPort, '--character', 't04', '--side', 'STEEL') }
        if ($Bots) { $clientArguments = @('--headless', '--path', $projectRoot, 'res://tests/bot_network.tscn', '--', '--connect', $target, '--port', $listenPort, '--character', 't01', '--side', 'STEEL') }
        if ($Bosses) { $clientArguments = @('--headless', '--path', $projectRoot, 'res://tests/boss_network.tscn', '--', '--connect', $target, '--port', $listenPort, '--character', 't01', '--side', 'STEEL') }
        if ($Campaign) { $clientArguments = @('--headless', '--path', $projectRoot, 'res://tests/campaign_network.tscn', '--', '--connect', $target, '--port', $listenPort, '--character', 't06', '--side', 'STEEL') }
        if ($Super) { $clientArguments = @('--headless', '--path', $projectRoot, 'res://tests/super_network.tscn', '--', '--connect', $target, '--port', $listenPort, '--character', 's09', '--side', 'SUPER') }
        if ($Controls) { $clientArguments = @('--headless', '--path', $projectRoot, 'res://tests/controls_network.tscn', '--', '--connect', $target, '--port', $listenPort, '--character', 't01', '--side', 'STEEL') }
        if ($Mobile) { $clientArguments = @('--headless', '--path', $projectRoot, 'res://tests/mobile_network.tscn', '--', '--connect', $target, '--ctrl', 'pad', '--port', $listenPort, '--character', 't01', '--side', 'STEEL') }
        if ($View) { $clientArguments = @('--headless', '--path', $projectRoot, 'res://tests/view_network.tscn', '--', '--connect', $target, '--ctrl', 'pad', '--port', $listenPort, '--character', 't01', '--side', 'STEEL') }
        if ($Bodies) { $clientArguments = @('--headless', '--path', $projectRoot, 'res://tests/body_network.tscn', '--', '--connect', $target, '--port', $listenPort, '--character', 't01', '--side', 'STEEL') }
        if ($Tps) { $clientArguments = @('--headless', '--path', $projectRoot, 'res://tests/tps_network.tscn', '--', '--connect', $target, '--port', $listenPort, '--character', 't01', '--side', 'STEEL') }
        if ($Deaths) { $clientArguments = @('--headless', '--path', $projectRoot, 'res://tests/death_network.tscn', '--', '--connect', $target, '--port', $listenPort, '--character', 't06', '--side', 'STEEL') }
        if ($Blasts) { $clientArguments = @('--headless', '--path', $projectRoot, 'res://tests/blast_network.tscn', '--', '--connect', $target, '--port', $listenPort, '--character', 't06', '--side', 'STEEL') }
        if ($LobControl) { $clientArguments += @('--character', 't03', '--side', 'STEEL', '--network-lob-test') }
        if ($KineticShots) { $clientArguments += @('--character', 't04', '--side', 'STEEL', '--network-kinetic-test') }
        if ($Rooms) { $clientArguments = @('--headless', '--path', $projectRoot, 'res://tests/room_network.tscn', '--', '--connect', $target, '--port', $listenPort, '--character', 't01', '--side', 'STEEL') }
        if ($Loading) { $clientArguments = @('--headless', '--path', $projectRoot, 'res://tests/room_loading_network.tscn', '--', '--connect', $target, '--port', $listenPort, '--character', 't01', '--side', 'STEEL') }
        if ($Roster) { $clientArguments = @('--headless', '--path', $projectRoot, 'res://tests/room_roster_network.tscn', '--', '--connect', $target, '--port', $listenPort, '--character', 't01', '--side', 'STEEL') }
        if ($Members) { $clientArguments = @('--headless', '--path', $projectRoot, 'res://tests/room_member_network.tscn', '--', '--connect', $target, '--port', $listenPort, '--character', 't01', '--side', 'STEEL') }
        if ($Spectators -or $LateSpectators) { $clientArguments = @('--headless', '--path', $projectRoot, 'res://tests/spectator_network.tscn', '--', '--connect', $target, '--port', $listenPort, '--character', 't01', '--side', 'STEEL') }
        if ($LateSpectators) { $clientArguments += @('--late') }
        if ($Rematch) { $clientArguments = @('--headless', '--path', $projectRoot, 'res://tests/room_rematch_network.tscn', '--', '--connect', $target, '--port', $listenPort, '--character', 't01', '--side', 'STEEL') }
        if ($Recovery) { $clientArguments = @('--headless', '--path', $projectRoot, 'res://tests/room_recovery_network.tscn', '--', '--connect', $target, '--port', $listenPort, '--character', 't01', '--side', 'STEEL') }
        if ($QuickRestart) { $clientArguments = @('--headless', '--path', $projectRoot, 'res://tests/quick_restart_network.tscn', '--', '--connect', $target, '--port', $listenPort, '--spectator') }
        if ($Fatal) { $clientArguments = @('--headless', '--path', $projectRoot, 'res://tests/fatal_network.tscn', '--', '--connect', $target, '--port', $listenPort, '--character', 't01', '--side', 'STEEL') }
        if ($Pips) { $clientArguments = @('--headless', '--path', $projectRoot, 'res://tests/pip_network.tscn', '--', '--connect', $target, '--port', $listenPort, '--character', 't01', '--side', 'STEEL') }
        if ($HeadMarks) { $clientArguments = @('--headless', '--path', $projectRoot, 'res://tests/head_mark_network.tscn', '--', '--connect', $target, '--port', $listenPort, '--character', 't01', '--side', 'STEEL') }
        if ($VitalBars) { $clientArguments = @('--headless', '--path', $projectRoot, 'res://tests/vital_bar_network.tscn', '--', '--connect', $target, '--port', $listenPort, '--character', 't01', '--side', 'STEEL') }
        if ($Minimap) { $clientArguments = @('--headless', '--path', $projectRoot, 'res://tests/minimap_network.tscn', '--', '--connect', $target, '--port', $listenPort, '--character', 't01', '--side', 'STEEL') }
        if ($Balance) { $clientArguments = @('--headless', '--path', $projectRoot, 'res://tests/balance_network.tscn', '--', '--connect', $target, '--port', $listenPort, '--character', 't01', '--side', 'STEEL') }
        if ($LobbyLatency) { $clientArguments = @('--headless', '--path', $projectRoot, 'res://tests/lobby_latency_network.tscn', '--', '--connect', $target, '--port', $listenPort, '--character', 't01', '--side', 'STEEL') }
        $clientArguments += @('--view', $(if ($Tps) { 'tps' } else { 'fpv' }), '--ready-start')
        if ($Rooms) { $clientArguments += @('--name', 'RoomClient_01') }
        if ($Recovery) {
            $storeResource = "res://tests/$mode-recovery-$recoveryRunId.cfg"
            $recoveryStores += Join-Path $projectRoot "tests/$mode-recovery-$recoveryRunId.cfg"
            $clientArguments += @('--session-store', $storeResource)
            $firstClient = Start-Process -FilePath $Godot -ArgumentList $clientArguments -WindowStyle Hidden -PassThru -RedirectStandardOutput "$projectRoot/tests/$mode-recovery-first.log" -RedirectStandardError "$projectRoot/tests/$mode-recovery-first-errors.log"
            $null = $firstClient.Handle
            $processes += $firstClient
            if (-not $firstClient.WaitForExit(30000)) { throw "$mode initial recovery client timed out" }
            $firstLog = Get-Content -LiteralPath "$projectRoot/tests/$mode-recovery-first.log" -Raw
            $firstErrors = Get-Content -LiteralPath "$projectRoot/tests/$mode-recovery-first-errors.log" -Raw
            if ($firstClient.ExitCode -ne 0 -or $firstLog -notmatch 'NETWORK_RECOVERY_FIRST_PASS' -or "$firstErrors".Trim()) { throw "$mode initial recovery client failed: $firstLog $firstErrors" }
            $heldDeadline = [DateTime]::UtcNow.AddSeconds(15)
            do {
                $server.Refresh()
                if ($server.HasExited) { throw "$mode recovery authority exited before retaining the seat" }
                $heldLog = Get-Content -LiteralPath "$projectRoot/tests/$mode-server.log" -Raw -ErrorAction SilentlyContinue
                if ($heldLog -match 'NETWORK_RECOVERY_HELD') { break }
                if ([DateTime]::UtcNow -ge $heldDeadline) { throw "$mode authority did not retain the closed client's seat" }
                Start-Sleep -Milliseconds 100
            } while ($true)
            $clientArguments = @('--headless', '--path', $projectRoot, 'res://tests/room_recovery_network.tscn', '--', '--resume', '--session-store', $storeResource)
        }
        $client = Start-Process -FilePath $Godot -ArgumentList $clientArguments -WindowStyle Hidden -PassThru -RedirectStandardOutput "$projectRoot/tests/$mode-client.log" -RedirectStandardError "$projectRoot/tests/$mode-client-errors.log"
        $null = $client.Handle
        $processes += $client
        if ($LateSpectators) {
            $lateDeadline = [DateTime]::UtcNow.AddSeconds(20)
            do {
                if ($client.HasExited) { throw "$mode player exited before late observer admission" }
                $lateLog = "$(Get-Content -LiteralPath "$projectRoot/tests/$mode-client.log" -Raw -ErrorAction SilentlyContinue)"
                if ($lateLog.Contains('LATE_SPECTATOR_READY')) { break }
                if ([DateTime]::UtcNow -ge $lateDeadline) { throw "$mode did not reach the active match before observer admission" }
                Start-Sleep -Milliseconds 100
            } while ($true)
        }
        if ($Spectators -or $LateSpectators) {
            $observerArguments = @('--headless', '--path', $projectRoot, 'res://tests/spectator_network.tscn', '--', '--connect', $target, '--port', $listenPort, '--character', 's01', '--side', 'SWARM', '--observer', '--ready-start')
            if ($LateSpectators) { $observerArguments += @('--spectator', '--late') }
            $observer = Start-Process -FilePath $Godot -ArgumentList $observerArguments -WindowStyle Hidden -PassThru -RedirectStandardOutput "$projectRoot/tests/$mode-observer.log" -RedirectStandardError "$projectRoot/tests/$mode-observer-errors.log"
            $null = $observer.Handle
            $processes += $observer
        }
        if (-not $client.WaitForExit($(if ($Rematch) { 40000 } elseif ($Recovery -or $QuickRestart) { 35000 } else { 60000 }))) { throw "$mode connection test timed out" }
        $log = Get-Content -LiteralPath "$projectRoot/tests/$mode-client.log" -Raw
        $errors = Get-Content -LiteralPath "$projectRoot/tests/$mode-client-errors.log" -Raw
        $serverErrors = Get-Content -LiteralPath "$projectRoot/tests/$mode-server-errors.log" -Raw
        $serverLog = Get-Content -LiteralPath "$projectRoot/tests/$mode-server.log" -Raw
        if ($Bursts -and $log -notmatch 'NETWORK_BURST_PASS') { throw "$mode burst fixture failed: $log $errors $serverErrors" }
        if ($Projectiles -and $log -notmatch 'NETWORK_PROJECTILE_VISUAL_PASS') { throw "$mode projectile fixture failed: $log $errors $serverErrors" }
        if ($Aiming -and $log -notmatch 'NETWORK_AIMING_PASS') { throw "$mode aiming fixture failed: $log $errors $serverErrors" }
        if ($MissileDefenses -and $log -notmatch 'NETWORK_MISSILE_DEFENSE_PASS') { throw "$mode missile defense fixture failed: $log $errors $serverErrors" }
        if ($Bots -and $log -notmatch 'NETWORK_BOT_PASS') { throw "$mode bot fixture failed: $log $errors $serverErrors" }
        if ($Bosses -and $log -notmatch 'NETWORK_BOSS_PASS') { throw "$mode boss fixture failed: $log $errors $serverErrors" }
        if ($Campaign -and $log -notmatch 'NETWORK_CAMPAIGN_PASS') { throw "$mode campaign fixture failed: $log $errors $serverErrors" }
        if ($Super -and $log -notmatch 'NETWORK_SUPER_PASS') { throw "$mode super fixture failed: $log $errors $serverErrors" }
        if ($Controls -and $log -notmatch 'NETWORK_CONTROLS_PASS') { throw "$mode controls fixture failed: $log $errors $serverErrors" }
        if ($Mobile -and $log -notmatch 'NETWORK_MOBILE_PASS') { throw "$mode mobile fixture failed: $log $errors $serverErrors" }
        if ($View -and $log -notmatch 'NETWORK_VIEW_PASS') { throw "$mode view fixture failed: $log $errors $serverErrors" }
        if ($Bodies -and $log -notmatch 'NETWORK_BODY_PASS') { throw "$mode body fixture failed: $log $errors $serverErrors" }
        if ($Tps -and $log -notmatch 'NETWORK_TPS_PASS') { throw "$mode TPS fixture failed: $log $errors $serverErrors" }
        if ($Deaths -and $log -notmatch 'NETWORK_DEATH_PASS') { throw "$mode death fixture failed: $log $errors $serverErrors" }
        if ($Blasts -and $log -notmatch 'NETWORK_BLAST_PASS') { throw "$mode blast fixture failed: $log $errors $serverErrors" }
        if ($LobbyLatency -and $log -notmatch 'NETWORK_LOBBY_LATENCY_PASS') { throw "$mode lobby latency fixture failed: $log $errors $serverErrors" }
        if ($Rooms -and ($log -notmatch 'NETWORK_ROOM_PASS' -or $serverLog -notmatch 'NETWORK_ROOM_SERVER_CLEARED')) { throw "$mode room fixture failed: $log $serverLog $errors $serverErrors" }
        if ($Loading -and $log -notmatch 'NETWORK_ROOM_LOADING_PASS') { throw "$mode loading fixture failed: $log $errors $serverErrors" }
        if ($Roster -and $log -notmatch 'NETWORK_ROOM_ROSTER_PASS') { throw "$mode roster fixture failed: $log $errors $serverErrors" }
        if ($Members -and $log -notmatch 'NETWORK_ROOM_MEMBER_PASS') { throw "$mode member fixture failed: $log $errors $serverErrors" }
        if ($Rematch -and ($log -notmatch 'NETWORK_REMATCH_PASS' -or $serverLog -notmatch 'NETWORK_REMATCH_SERVER_PASS')) { throw "$mode rematch fixture failed: $log $serverLog $errors $serverErrors" }
        if ($Recovery -and ($log -notmatch 'NETWORK_RECOVERY_PASS' -or $serverLog -notmatch 'NETWORK_RECOVERY_SERVER_PASS')) { throw "$mode process recovery fixture failed: $log $serverLog $errors $serverErrors" }
        if ($QuickRestart -and ($log -notmatch 'NETWORK_QUICK_RESTART_PASS' -or $serverLog -notmatch 'NETWORK_QUICK_RESTART_SERVER_PASS')) { throw "$mode quick-restart fixture failed: $log $serverLog $errors $serverErrors" }
        if ($Fatal -and ($log -notmatch 'NETWORK_FATAL_PASS' -or $serverLog -notmatch 'NETWORK_FATAL_SERVER_PASS')) { throw "$mode fatal-recovery fixture failed: $log $serverLog $errors $serverErrors" }
        if ($Pips -and ($log -notmatch 'NETWORK_PIP_PASS' -or $serverLog -notmatch 'NETWORK_PIP_SERVER_PASS')) { throw "$mode PiP fixture failed: $log $serverLog $errors $serverErrors" }
        if ($HeadMarks -and ($log -notmatch 'NETWORK_HEAD_MARK_PASS' -or $serverLog -notmatch 'NETWORK_HEAD_MARK_SERVER_PASS')) { throw "$mode head-marker fixture failed: $log $serverLog $errors $serverErrors" }
        if ($VitalBars -and ($log -notmatch 'NETWORK_VITAL_BAR_PASS' -or $serverLog -notmatch 'NETWORK_VITAL_BAR_SERVER_PASS')) { throw "$mode vital-bar fixture failed: $log $serverLog $errors $serverErrors" }
        if ($Minimap -and ($log -notmatch 'NETWORK_MINIMAP_PASS' -or $serverLog -notmatch 'NETWORK_MINIMAP_SERVER_PASS')) { throw "$mode minimap fixture failed: $log $serverLog $errors $serverErrors" }
        if ($Balance -and ($log -notmatch 'NETWORK_BALANCE_PASS' -or $serverLog -notmatch 'NETWORK_BALANCE_SERVER_PASS')) { throw "$mode balance fixture failed: $log $serverLog $errors $serverErrors" }
        if ($Spectators -or $LateSpectators) {
            if (-not $observer.WaitForExit(20000)) { throw "$mode observer fixture timed out" }
            $observerLog = Get-Content -LiteralPath "$projectRoot/tests/$mode-observer.log" -Raw
            $observerErrors = Get-Content -LiteralPath "$projectRoot/tests/$mode-observer-errors.log" -Raw
            if ($observer.ExitCode -ne 0 -or $log -notmatch 'NETWORK_SPECTATOR_PASS' -or $observerLog -notmatch 'NETWORK_SPECTATOR_PASS' -or "$observerErrors".Trim()) { throw "$mode spectator fixture failed: $log $observerLog $observerErrors $errors $serverErrors" }
        }
        if ($client.ExitCode -ne 0 -or $log -notmatch 'NETWORK_PASS' -or ($LobControl -and $log -notmatch 'NETWORK_LOB_PASS') -or ($KineticShots -and $log -notmatch 'NETWORK_KINETIC_PASS') -or ($MissileShots -and $log -notmatch 'NETWORK_MISSILE_PASS') -or ($Reachability -and $log -notmatch 'NETWORK_REACHABILITY_PASS') -or ($Footprints -and $log -notmatch 'NETWORK_FOOTPRINT_PASS') -or ($Cockpits -and $log -notmatch 'NETWORK_COCKPIT_PASS') -or ($Cameras -and $log -notmatch 'NETWORK_CAMERA_PASS') -or $errors -match 'ERROR|above the MTU' -or $serverErrors -match 'ERROR|above the MTU') {
            throw "$mode failed: $log $errors $serverErrors"
        }
        Write-Output "$mode $($log.Trim())"
        if (-not $server.HasExited) { Stop-Process -Id $server.Id }
    }
} finally {
    foreach ($process in $processes) {
        if (-not $process.HasExited) { Stop-Process -Id $process.Id }
    }
    foreach ($storePath in $recoveryStores) {
        if (Test-Path -LiteralPath $storePath) { Remove-Item -LiteralPath $storePath }
    }
}

<#
.SYNOPSIS
    Runs the Flutter app and automatically re-enables the PocketPilot Accessibility Service.

.DESCRIPTION
    Android forces Accessibility Services to "Off" whenever an app is reinstalled or force-stopped during development.
    This script runs `flutter run` and monitors the log output. As soon as the app successfully syncs to the device
    and launches, it executes an adb shell command to bypass the Settings UI and securely flip the Accessibility
    Service back to "On".

.EXAMPLE
    .\scripts\run_with_a11y.ps1
#>

$packageName = "com.sumanth.pocketpilot"
$serviceName = "com.sumanth.pocketpilot.PilotAccessibilityService"
$fullServicePath = "$packageName/$serviceName"

Write-Host "Starting PocketPilot with Auto-A11y enabled..." -ForegroundColor Cyan

# Start flutter run and pipe output
$flutterProcess = Start-Process -FilePath "flutter" -ArgumentList "run" -PassThru -NoNewWindow -RedirectStandardOutput "flutter_out.log" -RedirectStandardError "flutter_err.log"

$appLaunched = $false

Write-Host "Waiting for app to launch on device..." -ForegroundColor Yellow

# Monitor the log file for the launch trigger
try {
    # small delay to ensure file is created
    Start-Sleep -Seconds 2
    
    # Read the log file dynamically like 'tail -f'
    Get-Content "flutter_out.log" -Wait -Tail 10 | ForEach-Object {
        Write-Host $_
        
        # When flutter says it's syncing files or launching the activity, it's installed.
        if ($_ -match "Syncing files to device" -or $_ -match "Built build\\app\\outputs\\flutter-apk\\app-debug.apk") {
            Write-Host "Build complete, waiting for launch..." -ForegroundColor Green
        }

        # The definitive signal that the app is alive on the phone
        if ($_ -match "Observing current UI" -or $_ -match "I/flutter" -or $_ -match "W/AccessibilityService") {
            if (-not $appLaunched) {
                $appLaunched = $true
                Write-Host "`n[Auto-A11y] App is running! Re-enabling Accessibility Service via ADB..." -ForegroundColor Magenta
                
                # Fetch currently enabled services so we don't overwrite others
                $currentServices = (adb shell settings get secure enabled_accessibility_services).Trim()
                
                if ($currentServices -eq "null" -or [string]::IsNullOrWhiteSpace($currentServices)) {
                    $newServices = $fullServicePath
                }
                elseif ($currentServices -notmatch $fullServicePath) {
                    $newServices = "$currentServices`:$fullServicePath"
                }
                else {
                    $newServices = $currentServices
                }

                # Put the new settings
                adb shell settings put secure enabled_accessibility_services $newServices
                # Ensure the accessibility feature itself is toggled on globally
                adb shell settings put secure accessibility_enabled 1
                
                Write-Host "[Auto-A11y] Accessibility Service re-enabled successfully.`n" -ForegroundColor Green
            }
        }
    }
}
catch {
    Write-Host "Process interrupted." -ForegroundColor Red
}
finally {
    # Clean up logs and process if script exits
    if (-not $flutterProcess.HasExited) {
        Write-Host "Stopping flutter run..." -ForegroundColor Yellow
        Stop-Process -Id $flutterProcess.Id -Force
        Start-Sleep -Seconds 2
    }
    
    # Try multiple times to clean up logs in case locks linger
    foreach ($logFile in @("flutter_out.log", "flutter_err.log")) {
        if (Test-Path $logFile) {
            try {
                Remove-Item $logFile -Force -ErrorAction Stop
            }
            catch {
                Write-Host "Could not remove $logFile immediately, will retry once..." -ForegroundColor DarkGray
                Start-Sleep -Seconds 2
                try { Remove-Item $logFile -Force -ErrorAction Ignore } catch {}
            }
        }
    }
}

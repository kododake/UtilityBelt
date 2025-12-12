<# : batch script section
@echo off
cd /d "%~dp0"

REM --- Admin Check & Elevation ---
openfiles > nul
if errorlevel 1 (
    echo Requesting admin privileges...
    PowerShell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

REM --- Load PowerShell Script ---
powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Expression (Get-Content '%~f0' -Raw)"
exit /b
: end batch / begin powershell #>

# --- PowerShell Logic ---

$baseDir = Get-Location
$logPrefix = 'symlink_created_list_'

function Show-Menu {
    Clear-Host
    Write-Host '=== Symbolic Link Manager (No Extension) ===' -ForegroundColor Cyan
    Write-Host "Work Dir: $baseDir" -ForegroundColor DarkGray
    Write-Host '-----------------------------------------------------'
    Write-Host '1. Create Links (Make symlinks for .exe)' -ForegroundColor Green
    Write-Host '2. Delete Links (Remove created symlinks)' -ForegroundColor Yellow
    Write-Host 'Q. Quit'
    Write-Host '-----------------------------------------------------'
    return Read-Host 'Input Number'
}

function Create-Links {
    $recursiveInput = Read-Host 'Search subfolders? (y/n)'
    $isRecursive = ($recursiveInput -eq 'y')
    
    $timeStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $logFileName = $logPrefix + $timeStamp + '.txt'
    $logPath = Join-Path $baseDir $logFileName
    
    Write-Host 'Searching...' -ForegroundColor Cyan
    
    if ($isRecursive) {
        $files = Get-ChildItem -Path $baseDir -Filter *.exe -Recurse
    } else {
        $files = Get-ChildItem -Path $baseDir -Filter *.exe
    }
    
    $count = 0
    $createdLinks = @()

    foreach ($file in $files) {
        $linkName = $file.BaseName
        $linkPath = Join-Path $file.DirectoryName $linkName
        
        if (Test-Path $linkPath) {
            Write-Host ('Skip (Exists): {0}' -f $linkName) -ForegroundColor DarkGray
            continue
        }
        
        try {
            New-Item -ItemType SymbolicLink -Path $linkPath -Value $file.FullName -Force | Out-Null
            Write-Host ('Created: {0} -> {1}' -f $linkName, $file.Name)
            $createdLinks += $linkPath
            $count++
        } catch {
            Write-Host ('Error: {0}' -f $_.Exception.Message) -ForegroundColor Red
        }
    }
    
    if ($count -gt 0) {
        $createdLinks | Out-File -FilePath $logPath -Encoding utf8
        Write-Host ('Done: Created {0} links.' -f $count) -ForegroundColor Green
        Write-Host ('Log saved: {0}' -f $logFileName) -ForegroundColor Gray
    } else {
        Write-Host 'No target .exe files found.' -ForegroundColor Yellow
    }
}

function Delete-Links {
    Write-Host 'Deleting links from logs...' -ForegroundColor Cyan
    
    $logFiles = Get-ChildItem -Path $baseDir -Filter ($logPrefix + '*.txt') -Recurse
    
    if ($logFiles.Count -eq 0) {
        Write-Host 'No log files found.' -ForegroundColor Yellow
        return
    }
    
    foreach ($log in $logFiles) {
        Write-Host ('Reading log: {0}' -f $log.Name) -ForegroundColor Magenta
        if ((Get-Item $log.FullName).Length -eq 0) {
            Write-Host "  -> Empty file, skipping." -ForegroundColor DarkGray
            continue
        }

        $paths = Get-Content -Path $log.FullName
        
        foreach ($path in $paths) {
            if ([string]::IsNullOrWhiteSpace($path)) { continue }

            if (Test-Path $path) {
                try {
                    Remove-Item -Path $path -Force -ErrorAction Stop
                    Write-Host ('Deleted: {0}' -f $path)
                } catch {
                    Write-Host ('Failed: {0} ({1})' -f $path, $_.Exception.Message) -ForegroundColor Red
                }
            } else {
                Write-Host ('Not found: {0}' -f $path) -ForegroundColor DarkGray
            }
        }
        
        Remove-Item -Path $log.FullName
        Write-Host ('Log deleted: {0}' -f $log.Name) -ForegroundColor Gray
        Write-Host '-------------------'
    }
    Write-Host 'All deletion tasks completed.' -ForegroundColor Green
}

# --- Main Loop ---
do {
    $selection = Show-Menu
    if ($selection -eq '1') { Create-Links }
    elseif ($selection -eq '2') { Delete-Links }
    elseif ($selection -in 'q', 'Q') { exit }
    else { Write-Host 'Invalid input' -ForegroundColor Red }
    
    Write-Host ''
    Read-Host "Press Enter to return to menu..."
} until ($selection -in 'q', 'Q')
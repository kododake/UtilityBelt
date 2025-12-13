<# : batch script section
@echo off

REM --- Admin Re-launch Handling ---
if not "%~1"=="" (
    cd /d "%~1"
)

REM --- Admin Check & Elevation ---
openfiles > nul
if errorlevel 1 (
    echo Requesting admin privileges...
    powershell -Command "Start-Process cmd -ArgumentList '/c \"\"%~f0\" \"%cd%\"\"' -Verb RunAs"
    exit /b
)

REM --- Load PowerShell Script ---
powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Expression (Get-Content -LiteralPath '%~f0' -Raw)"

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] PowerShell script exited abnormally.
    pause
)
exit /b
: end batch / begin powershell #>

# --- PowerShell Logic ---

$baseDir = Get-Location
$logPrefix = 'Log_WslCompatLinks_created_list_'

function Show-Menu {
    Clear-Host
    Write-Host '=== Symbolic Link Manager (No Extension) by github.com/kododake ===' -ForegroundColor Cyan
    Write-Host "Work Dir: $baseDir" -ForegroundColor DarkGray
    Write-Host '-----------------------------------------------------'
    Write-Host '1. Create Links (Make symlinks for .exe)' -ForegroundColor Green
    Write-Host '2. Delete Links (Remove created symlinks)' -ForegroundColor Yellow
    Write-Host 'Q. Quit'
    Write-Host '-----------------------------------------------------'
    return Read-Host 'Input Number'
}

function Create-Links {
    $recursiveInput = Read-Host 'Search subfolders? (y/[N])'
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
        Write-Host "  (NOTE: Do not delete this file. It is needed for 'Delete Links'.)" -ForegroundColor DarkYellow
        Write-Host "  (      Logs are searched recursively, so moving this file to a subfolder is OK.)" -ForegroundColor DarkYellow
    } else {
        Write-Host 'No target .exe files found.' -ForegroundColor Yellow
    }
}

function Delete-Links {
    Write-Host 'Scanning logs for links to delete...' -ForegroundColor Cyan
    
    $logFiles = Get-ChildItem -Path $baseDir -Filter ($logPrefix + '*.txt') -Recurse
    
    if ($logFiles.Count -eq 0) {
        Write-Host 'No log files found.' -ForegroundColor Yellow
        return
    }

    $targets = @()

    foreach ($log in $logFiles) {
        if ((Get-Item $log.FullName).Length -eq 0) { continue }
        $paths = Get-Content -Path $log.FullName
        foreach ($path in $paths) {
            if (-not [string]::IsNullOrWhiteSpace($path)) {
                $targets += $path
            }
        }
    }

    if ($targets.Count -eq 0) {
        Write-Host 'No deletion targets found in logs.' -ForegroundColor Yellow
        return
    }

    Write-Host '--- Links to be deleted ---' -ForegroundColor Magenta
    foreach ($t in $targets) {
        if (Test-Path $t) {
            Write-Host $t -ForegroundColor White
        } else {
            Write-Host "$t (Not Found)" -ForegroundColor DarkGray
        }
    }
    Write-Host '---------------------------' -ForegroundColor Magenta

    $confirm = Read-Host "Are you sure you want to delete these $($targets.Count) items? (y/[N])"
    if ($confirm -ne 'y') {
        Write-Host 'Operation cancelled.' -ForegroundColor Yellow
        return
    }
    
    foreach ($t in $targets) {
        if (Test-Path $t) {
            try {
                Remove-Item -Path $t -Force -ErrorAction Stop
                Write-Host ('Deleted: {0}' -f $t)
            } catch {
                Write-Host ('Failed: {0} ({1})' -f $t, $_.Exception.Message) -ForegroundColor Red
            }
        }
    }
    
    foreach ($log in $logFiles) {
        try {
            Remove-Item -Path $log.FullName -Force
            Write-Host ('Log deleted: {0}' -f $log.Name) -ForegroundColor Gray
        } catch {
            Write-Host ('Failed to delete log: {0}' -f $log.Name) -ForegroundColor Red
        }
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

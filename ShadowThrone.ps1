<#
.SYNOPSIS
    Shadow Throne - HTML Command Interface for Shadow Suite with Kingdom Reports Page.
.DESCRIPTION
    Preserve-mode command interface. Launches original Shadow Suite tools in isolated PowerShell processes.
    Original tool scripts are not modified or imported.
#>

[CmdletBinding()]
param(
    [int]$Port = 8787
)

$ErrorActionPreference = 'Stop'
$Script:RootPath = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$Script:WebPath = Join-Path $Script:RootPath 'Web'
$Script:AssetPath = Join-Path $Script:RootPath 'Assets'
$Script:LogPath = Join-Path $Script:RootPath 'Logs'
$Script:ReportPath = Join-Path $Script:RootPath 'Reports'
$Script:ExportPath = Join-Path $Script:RootPath 'Exports'
$Script:ConfigPath = Join-Path $Script:RootPath 'Config'
$Script:DistributionPath = Join-Path $Script:RootPath 'Distributions'
$Script:ImportPath = Join-Path $Script:RootPath 'Imports'
$Script:ImportReportPath = Join-Path $Script:ImportPath 'Reports'
$Script:IntelligencePath = Join-Path $Script:RootPath 'Intelligence'
$Script:RunningTools = @{}
foreach ($p in @($Script:LogPath,$Script:ReportPath,$Script:ExportPath,$Script:ConfigPath,$Script:DistributionPath,$Script:ImportPath,$Script:ImportReportPath,$Script:IntelligencePath)) { if (-not (Test-Path $p)) { New-Item -Path $p -ItemType Directory -Force | Out-Null } }
$Script:LogFile = Join-Path $Script:LogPath ('ShadowThrone-{0}.log' -f (Get-Date -Format 'yyyyMMdd'))
$Script:StartTime = Get-Date

$Script:Tools = @(
    [ordered]@{ Id='mde'; Name='Shadow Deploy MDE'; Folder=(Join-Path $Script:RootPath 'Tools\ShadowDeploy-MDE'); Script=(Join-Path $Script:RootPath 'Tools\ShadowDeploy-MDE\ShadowDeployv1.0.ps1') },
    [ordered]@{ Id='dfo365'; Name='Shadow Deploy DFO365'; Folder=(Join-Path $Script:RootPath 'Tools\ShadowDeploy-DFO365'); Script=(Join-Path $Script:RootPath 'Tools\ShadowDeploy-DFO365\scripts\ShadowDeploy-DFO365-Community-EditionV1.0.ps1') },
    [ordered]@{ Id='verify'; Name='Shadow Verify'; Folder=(Join-Path $Script:RootPath 'Tools\ShadowVerify'); Script=(Join-Path $Script:RootPath 'Tools\ShadowVerify\Invoke-ShadowVerify.ps1') },
    [ordered]@{ Id='traceops'; Name='Shadow Trace Ops'; Folder=(Join-Path $Script:RootPath 'Tools\ShadowTraceOps'); Script=(Join-Path $Script:RootPath 'Tools\ShadowTraceOps\Toolkit\Shadow-Trace-Ops.ps1') },
    [ordered]@{ Id='ca'; Name='Shadow CA'; Folder=(Join-Path $Script:RootPath 'Tools\ShadowCA'); Script=(Join-Path $Script:RootPath 'Tools\ShadowCA\ShadowCA.ps1') }
)

function Write-ThroneLog {
    param([string]$Message, [string]$Level = 'INFO')
    $entry = '[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Add-Content -Path $Script:LogFile -Value $entry
    Write-Host $entry
}

function Get-PowerShellExecutable {
    $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwsh) { return $pwsh.Source }
    $powershell = Get-Command powershell.exe -ErrorAction SilentlyContinue
    if ($powershell) { return $powershell.Source }
    return 'powershell.exe'
}


function Initialize-WindowFocusHelper {
    if (-not ('ShadowThrone.NativeMethods' -as [type])) {
        Add-Type -TypeDefinition @"
using System;
using System.Text;
using System.Runtime.InteropServices;
namespace ShadowThrone {
    public static class NativeMethods {
        public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
        [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
        [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
        [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
        [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
        [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
        [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
        [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
        [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll")] public static extern uint GetCurrentThreadId();
        [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
        [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hWnd);
    }
}
"@ -ErrorAction SilentlyContinue | Out-Null
    }
}

function Get-WindowHandlesForProcessId {
    param([int]$ProcessId)
    Initialize-WindowFocusHelper
    $handles = New-Object System.Collections.Generic.List[object]
    $callback = [ShadowThrone.NativeMethods+EnumWindowsProc]{
        param([IntPtr]$hWnd, [IntPtr]$lParam)
        $pid = 0
        [void][ShadowThrone.NativeMethods]::GetWindowThreadProcessId($hWnd, [ref]$pid)
        if ($pid -eq $ProcessId -and [ShadowThrone.NativeMethods]::IsWindowVisible($hWnd)) {
            $titleBuilder = New-Object System.Text.StringBuilder 512
            [void][ShadowThrone.NativeMethods]::GetWindowText($hWnd, $titleBuilder, $titleBuilder.Capacity)
            $handles.Add([pscustomobject]@{ Handle=$hWnd; Title=$titleBuilder.ToString() }) | Out-Null
        }
        return $true
    }
    [void][ShadowThrone.NativeMethods]::EnumWindows($callback, [IntPtr]::Zero)
    return @($handles)
}

function Invoke-BringWindowHandleToFront {
    param([IntPtr]$Handle)
    Initialize-WindowFocusHelper
    if (-not $Handle -or $Handle -eq [IntPtr]::Zero) { return $false }
    try {
        if ([ShadowThrone.NativeMethods]::IsIconic($Handle)) {
            [ShadowThrone.NativeMethods]::ShowWindowAsync($Handle, 9) | Out-Null
        } else {
            [ShadowThrone.NativeMethods]::ShowWindowAsync($Handle, 5) | Out-Null
        }
        Start-Sleep -Milliseconds 150
        $foreground = [ShadowThrone.NativeMethods]::GetForegroundWindow()
        $targetThread = 0
        [void][ShadowThrone.NativeMethods]::GetWindowThreadProcessId($Handle, [ref]$targetThread)
        $foregroundThread = 0
        if ($foreground -and $foreground -ne [IntPtr]::Zero) { [void][ShadowThrone.NativeMethods]::GetWindowThreadProcessId($foreground, [ref]$foregroundThread) }
        $currentThread = [ShadowThrone.NativeMethods]::GetCurrentThreadId()
        if ($foregroundThread -ne 0) { [ShadowThrone.NativeMethods]::AttachThreadInput($currentThread, $foregroundThread, $true) | Out-Null }
        if ($targetThread -ne 0) { [ShadowThrone.NativeMethods]::AttachThreadInput($currentThread, $targetThread, $true) | Out-Null }
        [ShadowThrone.NativeMethods]::BringWindowToTop($Handle) | Out-Null
        [ShadowThrone.NativeMethods]::SetForegroundWindow($Handle) | Out-Null
        if ($targetThread -ne 0) { [ShadowThrone.NativeMethods]::AttachThreadInput($currentThread, $targetThread, $false) | Out-Null }
        if ($foregroundThread -ne 0) { [ShadowThrone.NativeMethods]::AttachThreadInput($currentThread, $foregroundThread, $false) | Out-Null }
        return $true
    } catch { return $false }
}

function Invoke-BringProcessToFront {
    param(
        [Parameter(Mandatory=$true)]
        [System.Diagnostics.Process]$Process,
        [int]$WaitSeconds = 8
    )

    Initialize-WindowFocusHelper
    try {
        $deadline = (Get-Date).AddSeconds($WaitSeconds)
        do {
            try { $Process.Refresh() } catch {}
            if ($Process.HasExited) { return $false }
            $windows = @(Get-WindowHandlesForProcessId -ProcessId $Process.Id)
            $candidate = @($windows | Where-Object { $_.Title -and $_.Title.Trim().Length -gt 0 } | Select-Object -First 1)[0]
            if (-not $candidate -and $Process.MainWindowHandle -and $Process.MainWindowHandle -ne [IntPtr]::Zero) {
                $candidate = [pscustomobject]@{ Handle=$Process.MainWindowHandle; Title=$Process.MainWindowTitle }
            }
            if ($candidate) {
                if (Invoke-BringWindowHandleToFront -Handle $candidate.Handle) { return $true }
            }
            Start-Sleep -Milliseconds 350
        } while ((Get-Date) -lt $deadline)
    }
    catch {
        Write-ThroneLog "Bring-to-front failed for process $($Process.Id): $($_.Exception.Message)" 'WARN'
    }
    return $false
}

function Find-TrackedOrExistingToolProcess {
    param($Tool, [string]$Id)

    # First use the process that Shadow Throne launched during this session.
    if ($Script:RunningTools.ContainsKey($Id)) {
        try {
            $proc = Get-Process -Id ([int]$Script:RunningTools[$Id]) -ErrorAction Stop
            if (-not $proc.HasExited) { return $proc }
        }
        catch {
            $Script:RunningTools.Remove($Id)
        }
    }

    # If the page was refreshed or Shadow Throne lost the runtime reference,
    # find an already-running PowerShell process that was launched from this tool folder/script.
    # This is read-only discovery. It does not start a new PowerShell window.
    try {
        $folder = [System.IO.Path]::GetFullPath([string]$Tool.Folder)
        $scriptCandidates = New-Object System.Collections.Generic.List[string]
        if ($Tool.Script) { $scriptCandidates.Add([System.IO.Path]::GetFullPath([string]$Tool.Script)) | Out-Null }
        $manifest = Get-ToolManifest -Tool $Tool
        if ($manifest -and $manifest.LaunchScript) {
            $manifestScript = Join-Path ([string]$Tool.Folder) ([string]$manifest.LaunchScript)
            if (Test-Path -LiteralPath $manifestScript) { $scriptCandidates.Add([System.IO.Path]::GetFullPath($manifestScript)) | Out-Null }
        }
        $escapedFolder = [Regex]::Escape($folder)
        $escapedScripts = @($scriptCandidates | Select-Object -Unique | ForEach-Object { [Regex]::Escape($_) })
        $matches = @(Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe' OR Name = 'pwsh.exe'" -ErrorAction SilentlyContinue |
            Where-Object {
                if (-not $_.CommandLine) { return $false }
                if ($_.CommandLine -match $escapedFolder) { return $true }
                foreach ($es in $escapedScripts) { if ($_.CommandLine -match $es) { return $true } }
                return $false
            } |
            Sort-Object CreationDate -Descending)
        foreach ($m in $matches) {
            try {
                $proc = Get-Process -Id ([int]$m.ProcessId) -ErrorAction Stop
                if (-not $proc.HasExited) {
                    $Script:RunningTools[$Id] = $proc.Id
                    return $proc
                }
            }
            catch {}
        }
    }
    catch {
        Write-ThroneLog "Process discovery failed for $($Tool.Name): $($_.Exception.Message)" 'WARN'
    }
    return $null
}

function Focus-Tool {
    param([string]$Id)
    $tool = Get-ToolById -Id $Id
    if (-not $tool) { throw "Unknown tool id: $Id" }

    $proc = Find-TrackedOrExistingToolProcess -Tool $tool -Id $Id
    if (-not $proc) {
        Write-ThroneLog "No running process is currently tracked for $($tool.Name). Launch the tool first, then use Front." 'WARN'
        return [ordered]@{ ok=$false; message="No running window found for $($tool.Name). Launch the tool first." }
    }

    try {
        $focused = Invoke-BringProcessToFront -Process $proc -WaitSeconds 5
        if ($focused) {
            Write-ThroneLog "Brought $($tool.Name) to the foreground." 'SUCCESS'
            return [ordered]@{ ok=$true; message="Brought $($tool.Name) to front." }
        }
        Write-ThroneLog "$($tool.Name) is running but no foreground window was found yet. It may still be loading or using a child/browser authentication window." 'WARN'
        return [ordered]@{ ok=$false; message="$($tool.Name) is running but no foreground window was found yet." }
    }
    catch {
        $Script:RunningTools.Remove($Id)
        Write-ThroneLog "Tracked process for $($tool.Name) could not be focused: $($_.Exception.Message)" 'WARN'
        return [ordered]@{ ok=$false; message="Tracked process could not be focused." }
    }
}

function New-ShadowVerifyEndpointPackage {
    $tool = Get-ToolById -Id 'verify'
    if (-not $tool) { throw 'Shadow Verify tool entry is missing.' }
    if (-not (Test-Path -LiteralPath ([string]$tool.Folder))) { throw "Shadow Verify folder missing: $($tool.Folder)" }

    if (-not (Test-Path -LiteralPath $Script:DistributionPath)) {
        New-Item -Path $Script:DistributionPath -ItemType Directory -Force | Out-Null
    }

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $staging = Join-Path $Script:DistributionPath "ShadowVerify-EndpointPackage-$timestamp"
    $zipPath = "$staging.zip"

    if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging -Recurse -Force }
    New-Item -Path $staging -ItemType Directory -Force | Out-Null

    $dest = Join-Path $staging 'ShadowVerify'
    Copy-Item -LiteralPath ([string]$tool.Folder) -Destination $dest -Recurse -Force

    $runFile = Join-Path $staging 'Run-ShadowVerify.ps1'
    @'
# Shadow Verify Endpoint Package Launcher
# Run this on the endpoint you want to validate.
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Tool = Join-Path $Root "ShadowVerify\Invoke-ShadowVerify.ps1"
if (-not (Test-Path -LiteralPath $Tool)) {
    Write-Error "Invoke-ShadowVerify.ps1 was not found at $Tool"
    exit 1
}
$pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
$exe = if ($pwsh) { $pwsh.Source } else { 'powershell.exe' }
Start-Process -FilePath $exe -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$Tool) -WorkingDirectory (Split-Path -Parent $Tool)
'@ | Out-File -FilePath $runFile -Encoding UTF8

    $readme = Join-Path $staging 'README-ENDPOINT-PACKAGE.txt'
    @'
Shadow Verify Endpoint Package

Purpose:
Run Shadow Verify locally on the endpoint being validated.

Instructions:
1. Copy this folder or ZIP to the target endpoint.
2. Extract the ZIP if needed.
3. Run Run-ShadowVerify.ps1 as appropriate for the validation scenario.
4. Return generated reports/logs to the Shadow Throne operator for indexing and review.

Preserve Mode:
This package does not modify Shadow Verify internals. It packages the existing tool folder for endpoint-local execution.
'@ | Out-File -FilePath $readme -Encoding UTF8

    if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
    Compress-Archive -Path (Join-Path $staging '*') -DestinationPath $zipPath -Force
    Write-ThroneLog "Built Shadow Verify endpoint distribution package: $zipPath" 'SUCCESS'
    Start-Process -FilePath $Script:DistributionPath | Out-Null
    return [ordered]@{ ok=$true; package=$zipPath; folder=$Script:DistributionPath; name=[System.IO.Path]::GetFileName($zipPath) }
}

function Get-ToolById {
    param([string]$Id)
    return @($Script:Tools | Where-Object { $_.Id -eq $Id } | Select-Object -First 1)[0]
}

function Get-RecentActivity {
    if (-not (Test-Path $Script:LogFile)) { return @() }
    $lines = @(Get-Content -Path $Script:LogFile -Tail 8 -ErrorAction SilentlyContinue)
    $items = foreach ($line in $lines) {
        $time = ''
        $message = $line
        if ($line -match '^\[(?<ts>[^\]]+)\]\s+\[(?<lvl>[^\]]+)\]\s+(?<msg>.*)$') {
            $time = ([datetime]$Matches.ts).ToString('HH:mm')
            $message = $Matches.msg
        }
        [ordered]@{ time=$time; message=$message }
    }
    return @($items)
}

function Get-ToolManifest {
    param($Tool)
    $manifestPath = Join-Path ([string]$Tool.Folder) 'manifest.json'
    if (Test-Path -LiteralPath $manifestPath) {
        try { return (Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json) }
        catch { Write-ThroneLog "Manifest could not be read for $($Tool.Name): $($_.Exception.Message)" 'WARN' }
    }
    return $null
}

function Get-ToolPath {
    param($Tool, [string]$RelativePath)
    if ([string]::IsNullOrWhiteSpace($RelativePath)) { return $null }
    return Join-Path ([string]$Tool.Folder) $RelativePath
}

function Get-ReportSearchFolders {
    $folders = @($Script:ReportPath,$Script:ExportPath,$Script:ImportReportPath)

    foreach ($tool in $Script:Tools) {
        $manifest = Get-ToolManifest -Tool $tool
        $candidateFolders = @()
        if ($manifest) {
            $candidateFolders += Get-ToolPath -Tool $tool -RelativePath $manifest.Reports
            $candidateFolders += Get-ToolPath -Tool $tool -RelativePath $manifest.Exports
        }
        $candidateFolders += Join-Path ([string]$tool.Folder) 'Reports'
        $candidateFolders += Join-Path ([string]$tool.Folder) 'reports'
        $candidateFolders += Join-Path ([string]$tool.Folder) 'Exports'
        $candidateFolders += Join-Path ([string]$tool.Folder) 'exports'
        foreach ($candidate in $candidateFolders) {
            if ($candidate -and (Test-Path -LiteralPath $candidate)) { $folders += $candidate }
        }
    }

    return @($folders | Where-Object { $_ } | Select-Object -Unique)
}

function Get-ReportFiles {
    $items = @()
    foreach ($folder in Get-ReportSearchFolders) {
        if (Test-Path -LiteralPath $folder) {
            $items += @(Get-ChildItem -LiteralPath $folder -File -Recurse -Include *.html,*.htm,*.json,*.csv,*.txt -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 25)
        }
    }
    return @($items | Sort-Object LastWriteTime -Descending | Select-Object -First 30 | ForEach-Object {
        $toolName = 'Shadow Throne'
        foreach ($tool in $Script:Tools) {
            if ($_.FullName.StartsWith([string]$tool.Folder, [System.StringComparison]::OrdinalIgnoreCase)) { $toolName = $tool.Name; break }
        }
        $ext = [System.IO.Path]::GetExtension($_.FullName).ToLowerInvariant()
        $kind = if ($ext -in @('.html','.htm')) { 'HumanReport' } elseif ($ext -eq '.json') { 'IntelligenceJson' } else { 'EvidenceFile' }
        [ordered]@{ name=$_.Name; path=$_.FullName; modified=$_.LastWriteTime.ToString('yyyy-MM-dd HH:mm'); tool=$toolName; toolId=(Get-ToolIdForPath -Path $_.FullName); extension=$ext; kind=$kind }
    })
}

function Get-LatestHumanReport {
    param($Reports)
    $human = @($Reports | Where-Object { $_.extension -in @('.html','.htm') -or $_.kind -eq 'HumanReport' } | Select-Object -First 1)
    if ($human.Count -gt 0) { return $human[0] }
    if ($Reports.Count -gt 0) { return $Reports[0] }
    return $null
}

function Get-LatestIntelligenceJson {
    param($Reports)
    $json = @($Reports | Where-Object { $_.extension -eq '.json' -or $_.kind -eq 'IntelligenceJson' } | Select-Object -First 1)
    if ($json.Count -gt 0) { return $json[0] }
    return $null
}

function Resolve-HumanReportPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $Path }
    if (-not (Test-Path -LiteralPath $Path)) { return $Path }
    $ext = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    if ($ext -in @('.html','.htm')) { return $Path }

    $dir = Split-Path -Parent $Path
    $base = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    $sameBase = @(Get-ChildItem -LiteralPath $dir -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -in @(("$base.html"),("$base.htm")) } | Sort-Object LastWriteTime -Descending)
    if ($sameBase.Count -gt 0) { return $sameBase[0].FullName }

    $nearbyHtml = @(Get-ChildItem -LiteralPath $dir -File -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Extension.ToLowerInvariant() -in @('.html','.htm') } | Sort-Object LastWriteTime -Descending | Select-Object -First 1)
    if ($nearbyHtml.Count -gt 0) { return $nearbyHtml[0].FullName }

    return $Path
}



function Get-ToolRoleMetadata {
    param([string]$Id)
    switch ($Id) {
        'mde'      { return [ordered]@{ Role='Warrior'; Area='Endpoint Protection'; Icon='🛡'; Domain='Deploy' } }
        'dfo365'   { return [ordered]@{ Role='Gatekeeper'; Area='Email Protection'; Icon='✉'; Domain='Deploy' } }
        'verify'   { return [ordered]@{ Role='Trial Master'; Area='Validation Readiness'; Icon='◎'; Domain='Validate' } }
        'traceops' { return [ordered]@{ Role='Hunter'; Area='Investigation Signals'; Icon='🦅'; Domain='Investigate' } }
        'ca'       { return [ordered]@{ Role='Sentinel'; Area='Access Governance'; Icon='🗝'; Domain='Govern' } }
        default    { return [ordered]@{ Role='Defender'; Area='Shadow Suite'; Icon='◆'; Domain='Operate' } }
    }
}

function Get-LogSearchFolders {
    $folders = @($Script:LogPath)
    foreach ($tool in $Script:Tools) {
        $manifest = Get-ToolManifest -Tool $tool
        $candidateFolders = @()
        if ($manifest) {
            $candidateFolders += Get-ToolPath -Tool $tool -RelativePath $manifest.Logs
            $candidateFolders += Get-ToolPath -Tool $tool -RelativePath $manifest.LogFolder
        }
        $candidateFolders += Join-Path ([string]$tool.Folder) 'Logs'
        $candidateFolders += Join-Path ([string]$tool.Folder) 'logs'
        foreach ($candidate in $candidateFolders) {
            if ($candidate -and (Test-Path -LiteralPath $candidate)) { $folders += $candidate }
        }
    }
    return @($folders | Where-Object { $_ } | Select-Object -Unique)
}

function Get-ToolNameForPath {
    param([string]$Path)
    foreach ($tool in $Script:Tools) {
        if ($Path.StartsWith([string]$tool.Folder, [System.StringComparison]::OrdinalIgnoreCase)) { return $tool.Name }
    }
    if ($Path.StartsWith($Script:ImportReportPath, [System.StringComparison]::OrdinalIgnoreCase)) { return 'Imported Report' }
    return 'Shadow Throne'
}

function Get-ToolIdForPath {
    param([string]$Path)
    foreach ($tool in $Script:Tools) {
        if ($Path.StartsWith([string]$tool.Folder, [System.StringComparison]::OrdinalIgnoreCase)) { return [string]$tool.Id }
    }
    return 'imported'
}

function Get-LogFiles {
    $items = @()
    foreach ($folder in Get-LogSearchFolders) {
        if (Test-Path -LiteralPath $folder) {
            $items += @(Get-ChildItem -LiteralPath $folder -File -Recurse -Include *.log,*.txt -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 25)
        }
    }
    return @($items | Sort-Object LastWriteTime -Descending | Select-Object -First 30 | ForEach-Object {
        [ordered]@{ name=$_.Name; path=$_.FullName; modified=$_.LastWriteTime.ToString('yyyy-MM-dd HH:mm'); tool=(Get-ToolNameForPath -Path $_.FullName); toolId=(Get-ToolIdForPath -Path $_.FullName) }
    })
}

function Read-ShadowEvidenceText {
    param([string]$Path, [int]$MaxChars = 45000)
    try {
        if (-not (Test-Path -LiteralPath $Path)) { return '' }
        $ext = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
        $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction SilentlyContinue
        if ($null -eq $raw) { return '' }
        if ($raw.Length -gt $MaxChars) { $raw = $raw.Substring(0, $MaxChars) }
        if ($ext -eq '.html' -or $ext -eq '.htm') {
            $raw = [regex]::Replace($raw, '<script[\s\S]*?</script>', ' ', 'IgnoreCase')
            $raw = [regex]::Replace($raw, '<style[\s\S]*?</style>', ' ', 'IgnoreCase')
            $raw = [regex]::Replace($raw, '<[^>]+>', ' ')
            $raw = [System.Net.WebUtility]::HtmlDecode($raw)
        }
        return [regex]::Replace($raw, '\s+', ' ').Trim()
    }
    catch { return '' }
}

function Get-ShadowAttentionFromText {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return [ordered]@{ Level='Unknown'; Score=0; Summary='No readable evidence extracted yet.'; Signals=@() }
    }
    $rules = @(
        [ordered]@{ Level='Critical'; Weight=40; Pattern='(?i)\bcritical\b|\bcompromise\b|\bconfirmed\s+breach\b|\bmalware\b|\bhigh\s+risk\b|\bsevere\b' },
        [ordered]@{ Level='High';     Weight=24; Pattern='(?i)\bhigh\b|\bfailed\b|\bfailure\b|\berror\b|\brisky\b|\bsuspicious\b|\bnot\s+enabled\b|\bmissing\b' },
        [ordered]@{ Level='Review';   Weight=12; Pattern='(?i)\bwarning\b|\breview\b|\battention\b|\bgap\b|\brecommendation\b|\bmanual\b|\bverify\b|\bpartial\b' },
        [ordered]@{ Level='Healthy';  Weight=-6; Pattern='(?i)\bpassed\b|\bsuccess\b|\bhealthy\b|\bcomplete\b|\bcompleted\b|\benabled\b|\bready\b' }
    )
    $score = 0
    $signals = New-Object System.Collections.Generic.List[string]
    foreach ($rule in $rules) {
        $matches = [regex]::Matches($Text, [string]$rule.Pattern)
        if ($matches.Count -gt 0) {
            $score += ([int]$rule.Weight * [Math]::Min($matches.Count, 5))
            $signals.Add(('{0}: {1}' -f $rule.Level, $matches.Count)) | Out-Null
        }
    }
    $level = if ($score -ge 90) { 'Critical' } elseif ($score -ge 45) { 'High' } elseif ($score -ge 12) { 'Review' } elseif ($score -lt 0) { 'Healthy' } else { 'Review' }
    $summary = switch ($level) {
        'Critical' { 'Critical terms found in recent evidence. Open source report for confirmation.' }
        'High' { 'High-attention terms found in recent evidence. Review recommended.' }
        'Review' { 'Review signals or recommendations detected.' }
        'Healthy' { 'Recent evidence trends healthy or successful.' }
        default { 'Evidence indexed.' }
    }
    return [ordered]@{ Level=$level; Score=$score; Summary=$summary; Signals=@($signals) }
}

function Get-ShadowIntelligenceSummary {
    $reports = @(Get-ReportFiles)
    $logs = @(Get-LogFiles)
    $byTool = @()
    $attentionCounts = [ordered]@{ Critical=0; High=0; Review=0; Healthy=0; Unknown=0 }

    foreach ($tool in $Script:Tools) {
        $role = Get-ToolRoleMetadata -Id ([string]$tool.Id)
        $manifest = Get-ToolManifest -Tool $tool
        $scriptPath = [string]$tool.Script
        if ($manifest -and $manifest.LaunchScript) {
            $candidateScript = Join-Path ([string]$tool.Folder) ([string]$manifest.LaunchScript)
            if (Test-Path -LiteralPath $candidateScript) { $scriptPath = $candidateScript }
        }
        $exists = Test-Path -LiteralPath $scriptPath
        $toolReports = @($reports | Where-Object { $_.tool -eq $tool.Name })
        $toolLogs = @($logs | Where-Object { $_.tool -eq $tool.Name })
        $latestReport = Get-LatestHumanReport -Reports $toolReports
        $latestJson = Get-LatestIntelligenceJson -Reports $toolReports
        $latestLog = if ($toolLogs.Count -gt 0) { $toolLogs[0] } else { $null }
        $evidenceText = ''
        if ($latestJson) { $evidenceText += ' ' + (Read-ShadowEvidenceText -Path $latestJson.path) }
        if ($latestReport) { $evidenceText += ' ' + (Read-ShadowEvidenceText -Path $latestReport.path) }
        if ($latestLog) { $evidenceText += ' ' + (Read-ShadowEvidenceText -Path $latestLog.path -MaxChars 12000) }
        $attention = if ($exists) { Get-ShadowAttentionFromText -Text $evidenceText } else { [ordered]@{ Level='Unknown'; Score=0; Summary='Workspace not installed yet.'; Signals=@() } }
        if ($attentionCounts.Contains($attention.Level)) { $attentionCounts[$attention.Level]++ } else { $attentionCounts.Unknown++ }
        $brief = if (-not $exists) { 'Awaiting installation.' }
                 elseif ($latestReport) { '{0} latest report indexed: {1}' -f $role.Role, $latestReport.name }
                 elseif ($latestLog) { '{0} latest log indexed: {1}' -f $role.Role, $latestLog.name }
                 else { '{0} ready; no evidence indexed yet.' -f $role.Role }
        $byTool += [ordered]@{
            id=$tool.Id; name=$tool.Name; role=$role.Role; area=$role.Area; icon=$role.Icon; domain=$role.Domain; exists=$exists;
            reportCount=$toolReports.Count; logCount=$toolLogs.Count;
            latestReport=$(if($latestReport){$latestReport.name}else{''}); latestReportPath=$(if($latestReport){$latestReport.path}else{''}); latestReportModified=$(if($latestReport){$latestReport.modified}else{''});
            latestIntelligence=$(if($latestJson){$latestJson.name}else{''}); latestIntelligencePath=$(if($latestJson){$latestJson.path}else{''}); latestIntelligenceModified=$(if($latestJson){$latestJson.modified}else{''});
            latestLog=$(if($latestLog){$latestLog.name}else{''}); latestLogPath=$(if($latestLog){$latestLog.path}else{''}); latestLogModified=$(if($latestLog){$latestLog.modified}else{''});
            attention=$attention.Level; attentionScore=$attention.Score; summary=$attention.Summary; signals=@($attention.Signals); briefing=$brief
        }
    }

    $readyTools = @($byTool | Where-Object { $_.exists }).Count
    $withReports = @($byTool | Where-Object { $_.reportCount -gt 0 }).Count
    $healthScore = if ($Script:Tools.Count -gt 0) { [Math]::Round((($readyTools / $Script:Tools.Count) * 70) + (($withReports / $Script:Tools.Count) * 30)) } else { 0 }
    $attentionLevel = if ($attentionCounts.Critical -gt 0) { 'Critical' } elseif ($attentionCounts.High -gt 0) { 'High' } elseif ($attentionCounts.Review -gt 0) { 'Review' } elseif ($attentionCounts.Healthy -gt 0) { 'Healthy' } else { 'Unknown' }
    $briefing = @($byTool | ForEach-Object { [ordered]@{ role=$_.role; icon=$_.icon; area=$_.area; attention=$_.attention; text=$_.briefing; report=$_.latestReport; log=$_.latestLog } })
    $topFindings = @($byTool | Where-Object { $_.attention -in @('Critical','High','Review') } | Sort-Object @{Expression='attentionScore';Descending=$true} | Select-Object -First 5 | ForEach-Object { [ordered]@{ tool=$_.name; role=$_.role; attention=$_.attention; summary=$_.summary; latestReport=$_.latestReport } })

    $snapshot = [ordered]@{
        generated=(Get-Date).ToString('s'); healthScore=$healthScore; attentionLevel=$attentionLevel; attentionCounts=$attentionCounts;
        reportCount=$reports.Count; logCount=$logs.Count; readyCount=$readyTools; totalCount=$Script:Tools.Count;
        tools=@($byTool); briefing=@($briefing); topFindings=@($topFindings)
    }
    try {
        $snapshotPath = Join-Path $Script:IntelligencePath 'ShadowThrone-IntelligenceSnapshot.json'
        ($snapshot | ConvertTo-Json -Depth 12) | Out-File -LiteralPath $snapshotPath -Encoding UTF8
    } catch {}
    return $snapshot
}

function Get-StatusObject {
    $intel = Get-ShadowIntelligenceSummary
    $toolStatus = foreach ($tool in $Script:Tools) {
        $manifest = Get-ToolManifest -Tool $tool
        $scriptPath = [string]$tool.Script
        if ($manifest -and $manifest.LaunchScript) {
            $candidateScript = Join-Path ([string]$tool.Folder) ([string]$manifest.LaunchScript)
            if (Test-Path -LiteralPath $candidateScript) { $scriptPath = $candidateScript }
        }
        $exists = Test-Path -LiteralPath $scriptPath
        $intelTool = @($intel.tools | Where-Object { $_.id -eq $tool.Id } | Select-Object -First 1)[0]
        $version = ''
        $codeName = ''
        if ($manifest) {
            if ($manifest.Version) { $version = [string]$manifest.Version }
            if ($manifest.CodeName) { $codeName = [string]$manifest.CodeName }
        }
        [ordered]@{
            id=$tool.Id; name=$tool.Name; exists=$exists; script=$scriptPath; folder=$tool.Folder; version=$version; codeName=$codeName;
            reportCount=$(if($intelTool){$intelTool.reportCount}else{0}); logCount=$(if($intelTool){$intelTool.logCount}else{0});
            latestReport=$(if($intelTool){$intelTool.latestReport}else{''}); latestLog=$(if($intelTool){$intelTool.latestLog}else{''});
            attention=$(if($intelTool){$intelTool.attention}else{'Unknown'}); area=$(if($intelTool){$intelTool.area}else{''}); role=$(if($intelTool){$intelTool.role}else{''}); briefing=$(if($intelTool){$intelTool.briefing}else{''})
        }
    }
    $ready = @($toolStatus | Where-Object { $_.exists }).Count
    $reports = @(Get-ReportFiles)
    $logs = @(Get-LogFiles)
    $recent = @(Get-RecentActivity)
    $last = if ($recent.Count -gt 0) { $recent[-1].message } else { 'Shadow Throne active' }
    [ordered]@{
        name='Shadow Throne'
        mode='Preserve'
        readyCount=$ready
        totalCount=$Script:Tools.Count
        reportCount=$reports.Count
        logCount=$logs.Count
        health=$(if ($intel.attentionLevel -in @('Critical','High')) { 'REVIEW' } elseif ($ready -ge 4) { 'READY' } else { 'REVIEW' })
        attentionLevel=$intel.attentionLevel
        healthScore=$intel.healthScore
        lastActivity=$last
        lastActivityAgo='Now'
        root=$Script:RootPath
        tools=@($toolStatus)
        recent=@($recent)
        intelligence=$intel
    }
}

function Send-Bytes {
    param($Response, [byte[]]$Bytes, [string]$ContentType = 'application/octet-stream')
    $Response.ContentType = $ContentType
    $Response.ContentLength64 = $Bytes.Length
    $Response.OutputStream.Write($Bytes,0,$Bytes.Length)
    $Response.OutputStream.Close()
}

function Send-Text {
    param($Response, [string]$Text, [string]$ContentType = 'text/plain; charset=utf-8')
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    Send-Bytes -Response $Response -Bytes $bytes -ContentType $ContentType
}

function Send-Json {
    param($Response, $Object)
    $json = $Object | ConvertTo-Json -Depth 8
    Send-Text -Response $Response -Text $json -ContentType 'application/json; charset=utf-8'
}

function Get-ContentType {
    param([string]$Path)
    switch ([System.IO.Path]::GetExtension($Path).ToLowerInvariant()) {
        '.html' { 'text/html; charset=utf-8' }
        '.css'  { 'text/css; charset=utf-8' }
        '.js'   { 'application/javascript; charset=utf-8' }
        '.png'  { 'image/png' }
        '.jpg'  { 'image/jpeg' }
        '.jpeg' { 'image/jpeg' }
        '.svg'  { 'image/svg+xml' }
        default { 'application/octet-stream' }
    }
}

function Resolve-StaticPath {
    param([string]$UrlPath)
    $decoded = [System.Web.HttpUtility]::UrlDecode($UrlPath)
    if ($decoded -eq '/' -or [string]::IsNullOrWhiteSpace($decoded)) { return Join-Path $Script:WebPath 'index.html' }
    if ($decoded.StartsWith('/web/')) { return Join-Path $Script:RootPath ($decoded.TrimStart('/') -replace '/', [System.IO.Path]::DirectorySeparatorChar) }
    if ($decoded.StartsWith('/assets/')) { return Join-Path $Script:RootPath ($decoded.TrimStart('/') -replace '/', [System.IO.Path]::DirectorySeparatorChar) }
    return $null
}

function Open-FolderTarget {
    param([string]$Target)
    $path = switch ($Target) {
        'root' { $Script:RootPath }
        'logs' { $Script:LogPath }
        'reports' { $Script:ReportPath }
        'exports' { $Script:ExportPath }
        'config' { $Script:ConfigPath }
        default {
            $tool = Get-ToolById -Id $Target
            if ($tool) { $tool.Folder } else { $Script:RootPath }
        }
    }
    if (-not (Test-Path $path)) { New-Item -Path $path -ItemType Directory -Force | Out-Null }
    Start-Process -FilePath $path | Out-Null
    Write-ThroneLog "Opened folder: $path" 'INFO'
}


function Open-IndexedReport {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { throw 'Report path was empty.' }
    $decoded = [System.Web.HttpUtility]::UrlDecode($Path)
    $full = [System.IO.Path]::GetFullPath($decoded)
    $allowedRoots = @($Script:RootPath,$Script:ImportReportPath,$Script:ReportPath,$Script:ExportPath)
    $isAllowed = $false
    foreach ($root in $allowedRoots) {
        if ($full.StartsWith([System.IO.Path]::GetFullPath($root), [System.StringComparison]::OrdinalIgnoreCase)) { $isAllowed = $true; break }
    }
    if (-not $isAllowed) { throw "Report path is outside the Shadow Throne workspace: $full" }
    if (-not (Test-Path -LiteralPath $full)) { throw "Report not found: $full" }
    $openPath = Resolve-HumanReportPath -Path $full
    Start-Process -FilePath $openPath | Out-Null
    if ($openPath -ne $full) {
        Write-ThroneLog "Resolved intelligence/evidence file to human HTML report: $openPath" 'INFO'
    }
    Write-ThroneLog "Opened indexed report: $openPath" 'INFO'
    return [ordered]@{ ok=$true; requested=$full; path=$openPath }
}

function Launch-Tool {
    param([string]$Id)
    $tool = Get-ToolById -Id $Id
    if (-not $tool) { throw "Unknown tool id: $Id" }
    $manifest = Get-ToolManifest -Tool $tool
    $scriptPath = [string]$tool.Script
    if ($manifest -and $manifest.LaunchScript) {
        $candidateScript = Join-Path ([string]$tool.Folder) ([string]$manifest.LaunchScript)
        if (Test-Path -LiteralPath $candidateScript) { $scriptPath = $candidateScript }
    }
    if (-not (Test-Path -LiteralPath $scriptPath)) { throw "Tool script missing: $scriptPath" }
    $exe = Get-PowerShellExecutable
    $toolTitle = "Shadow Throne - $($tool.Name)"
    $escapedScript = $scriptPath.Replace("'", "''")
    $command = "`$Host.UI.RawUI.WindowTitle = '$($toolTitle.Replace("'", "''"))'; & '$escapedScript'"
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $exe
    $psi.WorkingDirectory = [string]$tool.Folder
    $psi.UseShellExecute = $false
    $psi.Arguments = '-NoProfile -ExecutionPolicy Bypass -Command "' + $command.Replace('"','\"') + '"'
    $psi.EnvironmentVariables['SHADOW_THRONE_ROOT'] = $Script:RootPath
    $psi.EnvironmentVariables['SHADOW_THRONE_TOOL_ID'] = $Id
    $psi.EnvironmentVariables['SHADOW_THRONE_TOOL_NAME'] = [string]$tool.Name
    $psi.EnvironmentVariables['SHADOW_THRONE_TOOL_ROOT'] = [string]$tool.Folder
    $proc = [System.Diagnostics.Process]::Start($psi)
    $Script:RunningTools[$Id] = $proc.Id
    Write-ThroneLog "Launched $($tool.Name) in isolated process. Original script unchanged: $scriptPath" 'SUCCESS'
    Start-Sleep -Milliseconds 900
    $focused = Invoke-BringProcessToFront -Process $proc -WaitSeconds 7
    if ($focused) {
        Write-ThroneLog "Focus requested for $($tool.Name) after launch." 'INFO'
    }
    else {
        Write-ThroneLog "$($tool.Name) launched, but its window may still appear behind Shadow Throne or may still be loading. Use Bring To Front if needed." 'WARN'
    }
}


function Test-ShadowVerifyPackageHealth {
    $tool = Get-ToolById -Id 'verify'
    if (-not $tool) { return [ordered]@{ ok=$false; message='Shadow Verify tool entry missing.' } }
    $folder = [string]$tool.Folder
    $checks = [ordered]@{
        Folder = (Test-Path -LiteralPath $folder)
        Script = (Test-Path -LiteralPath ([string]$tool.Script))
        Module = (Test-Path -LiteralPath (Join-Path $folder 'MDETestFramework.psm1'))
        Logs = (Test-Path -LiteralPath (Join-Path $folder 'logs'))
        ResultsJson = (Test-Path -LiteralPath (Join-Path $folder 'logs\results.json'))
        ResultsHtml = (Test-Path -LiteralPath (Join-Path $folder 'logs\results.html'))
        KqlFolder = (Test-Path -LiteralPath (Join-Path $folder 'KQL'))
        ConfigKqlFolder = (Test-Path -LiteralPath (Join-Path $folder 'Config\KQL'))
        Docs = (Test-Path -LiteralPath (Join-Path $folder 'docs'))
        Images = (Test-Path -LiteralPath (Join-Path $folder 'images'))
    }
    return [ordered]@{ ok=$true; folder=$folder; checks=$checks }
}

Add-Type -AssemblyName System.Web
Write-ThroneLog 'Shadow Throne HTML command interface starting.' 'INFO'
Write-ThroneLog 'Preserve mode active. Original tool scripts launch in isolated PowerShell processes.' 'INFO'

$listener = [System.Net.HttpListener]::new()
$prefix = "http://127.0.0.1:$Port/"
$listener.Prefixes.Add($prefix)
try { $listener.Start() }
catch {
    Write-ThroneLog "Could not start HTTP listener on $prefix. $($_.Exception.Message)" 'ERROR'
    throw
}
Write-ThroneLog "Shadow Throne listening at $prefix" 'SUCCESS'
Start-Process $prefix | Out-Null

try {
    while ($listener.IsListening) {
        $ctx = $listener.GetContext()
        $req = $ctx.Request
        $res = $ctx.Response
        try {
            $path = $req.Url.AbsolutePath
            if ($path -eq '/api/status') { Send-Json -Response $res -Object (Get-StatusObject); continue }
            if ($path -eq '/api/reports') { Send-Json -Response $res -Object ([ordered]@{ files=@(Get-ReportFiles); intelligence=(Get-ShadowIntelligenceSummary) }); continue }
            if ($path -eq '/api/intelligence') { Send-Json -Response $res -Object (Get-ShadowIntelligenceSummary); continue }
            if ($path -eq '/api/logs') {
                $text = if (Test-Path $Script:LogFile) { (Get-Content $Script:LogFile -Raw) } else { '' }
                Send-Text -Response $res -Text $text; continue
            }
            if ($path -eq '/api/nav') {
                $view = $req.QueryString['view']
                Write-ThroneLog "Navigation selected: $view" 'INFO'
                Send-Json -Response $res -Object (Get-StatusObject); continue
            }
            if ($path -eq '/api/openReport') {
                $targetPath = $req.QueryString['path']
                $result = Open-IndexedReport -Path $targetPath
                Send-Json -Response $res -Object ([ordered]@{ ok=$true; result=$result; status=(Get-StatusObject) }); continue
            }
            if ($path -eq '/api/open') {
                $target = $req.QueryString['target']
                Open-FolderTarget -Target $target
                Send-Json -Response $res -Object (Get-StatusObject); continue
            }
            if ($path -eq '/api/launch') {
                $id = $req.QueryString['id']
                Launch-Tool -Id $id
                Send-Json -Response $res -Object (Get-StatusObject); continue
            }
            if ($path -eq '/api/focus') {
                $id = $req.QueryString['id']
                $result = Focus-Tool -Id $id
                Send-Json -Response $res -Object ([ordered]@{ ok=$result.ok; message=$result.message; status=(Get-StatusObject) }); continue
            }
            if ($path -eq '/api/packageVerify') {
                $result = New-ShadowVerifyEndpointPackage
                Send-Json -Response $res -Object (Get-StatusObject); continue
            }
            if ($path -eq '/api/verifyHealth') {
                Send-Json -Response $res -Object (Test-ShadowVerifyPackageHealth); continue
            }
            if ($path -eq '/api/exit') {
                Write-ThroneLog 'Shutdown requested from UI.' 'INFO'
                Send-Json -Response $res -Object ([ordered]@{ ok=$true })
                break
            }

            $file = Resolve-StaticPath -UrlPath $path
            if ($file -and (Test-Path -LiteralPath $file)) {
                $bytes = [System.IO.File]::ReadAllBytes($file)
                Send-Bytes -Response $res -Bytes $bytes -ContentType (Get-ContentType -Path $file)
                continue
            }
            $res.StatusCode = 404
            Send-Text -Response $res -Text 'Not found'
        }
        catch {
            Write-ThroneLog "Request failed: $($_.Exception.Message)" 'ERROR'
            $res.StatusCode = 500
            Send-Json -Response $res -Object ([ordered]@{ ok=$false; error=$_.Exception.Message })
        }
    }
}
finally {
    if ($listener.IsListening) { $listener.Stop() }
    $listener.Close()
    Write-ThroneLog 'Shadow Throne stopped.' 'INFO'
}

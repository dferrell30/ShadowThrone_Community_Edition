#requires -Version 5.1
Set-StrictMode -Version Latest

$script:Results = @()
$script:BasePath = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$script:LogDir = Join-Path $script:BasePath 'logs'
$script:LogFile = $null

$script:TestMetadata = @{
    'Defender Sensor' = @{
        Category          = 'Platform Health'
        ExpectedBehavior  = 'Microsoft Defender for Endpoint sensor service should be running.'
        ExpectedTelemetry = 'Endpoint sensor state available locally.'
        AlertExpectation  = 'No alert expected.'
        Verify            = 'Local service status / Defender portal device health'
    }
    'AV Status' = @{
        Category          = 'Platform Health'
        ExpectedBehavior  = 'Realtime protection and antivirus should be enabled.'
        ExpectedTelemetry = 'Local Defender AV health state available.'
        AlertExpectation  = 'No alert expected.'
        Verify            = 'Get-MpComputerStatus / Defender portal'
    }
    'ASR Configuration' = @{
        Category          = 'Prevention Validation'
        ExpectedBehavior  = 'ASR rules should be present and configured.'
        ExpectedTelemetry = 'Configuration visible on endpoint.'
        AlertExpectation  = 'No alert expected (configuration validation only).'
        Verify            = 'Get-MpPreference / Intune / Defender portal'
    }
    'EICAR Test' = @{
        Category          = 'Prevention Validation'
        ExpectedBehavior  = 'EICAR test file should be blocked, quarantined, or removed by Defender AV.'
        ExpectedTelemetry = 'Malware detection event should be logged.'
        AlertExpectation  = 'Alert may be generated depending on policy and environment tuning.'
        Verify            = 'Defender portal device timeline / Incidents & alerts'
    }
    'EDR Simulation' = @{
        Category          = 'Detection & Telemetry'
        ExpectedBehavior  = 'Benign encoded PowerShell should execute successfully in most environments.'
        ExpectedTelemetry = 'Process creation and command-line activity should be visible.'
        AlertExpectation  = 'Environment dependent; may or may not generate an alert.'
        Verify            = 'Device timeline / Advanced Hunting'
    }
    'Graph Module' = @{
        Category          = 'Cloud Visibility'
        ExpectedBehavior  = 'Microsoft Graph PowerShell module should be installed for cloud validation.'
        ExpectedTelemetry = 'Local module availability can be confirmed.'
        AlertExpectation  = 'No alert expected.'
        Verify            = 'Get-Module -ListAvailable'
    }
    'Graph Connection' = @{
        Category          = 'Cloud Visibility'
        ExpectedBehavior  = 'An active Graph connection should be present when cloud validation is used.'
        ExpectedTelemetry = 'Graph context should show authenticated account details.'
        AlertExpectation  = 'No alert expected.'
        Verify            = 'Get-MgContext'
    }
    'Alert Retrieval' = @{
        Category          = 'Cloud Visibility'
        ExpectedBehavior  = 'Recent alerts should be retrievable through Microsoft Graph if accessible.'
        ExpectedTelemetry = 'Alert metadata should be returned from the Graph API.'
        AlertExpectation  = 'Existing alerts should be visible if present.'
        Verify            = 'Defender portal / Microsoft Graph API'
    }
    'ASR Guided Validation - Office Child Process' = @{
        Category          = 'Prevention Validation'
        ExpectedBehavior  = 'Office child process creation should be blocked in Block mode, allowed but logged in Audit mode, or warn the user in Warn mode.'
        ExpectedTelemetry = 'ASR activity should be visible in Microsoft Defender ASR reporting, device timeline, or Advanced Hunting.'
        AlertExpectation  = 'Alerting depends on environment configuration; analyst should confirm visibility in security.microsoft.com.'
        Verify            = 'security.microsoft.com → Reports → Attack surface reduction rules / Device timeline / Advanced Hunting'
    }

    'ASR Guided Validation - Credential Theft Protection' = @{
        Category          = 'Prevention Validation'
        ExpectedBehavior  = 'LSASS credential access should be blocked in Block mode, allowed but logged in Audit mode, or warn where supported.'
        ExpectedTelemetry = 'ASR activity should be visible in Microsoft Defender ASR reporting, device timeline, or Advanced Hunting.'
        AlertExpectation  = 'Alerting depends on environment configuration; analyst should confirm visibility in security.microsoft.com.'
        Verify            = 'security.microsoft.com → Reports → Attack surface reduction rules / Device timeline / Advanced Hunting'
    }
    'ASR Guided Validation - Executable Content' = @{
        Category          = 'Prevention Validation'
        ExpectedBehavior  = 'Executable content from email client or webmail should be blocked or audited depending on configured mode.'
        ExpectedTelemetry = 'ASR activity should be visible in Microsoft Defender ASR reporting, device timeline, or Advanced Hunting.'
        AlertExpectation  = 'Alerting depends on environment configuration; analyst should confirm visibility in security.microsoft.com.'
        Verify            = 'security.microsoft.com → Reports → Attack surface reduction rules / Device timeline / Advanced Hunting'
    }
    'ASR Guided Validation - Obfuscated Scripts' = @{
        Category          = 'Prevention Validation'
        ExpectedBehavior  = 'Potentially obfuscated script behavior should be blocked, audited, or warned depending on configured mode.'
        ExpectedTelemetry = 'ASR activity should be visible in Microsoft Defender ASR reporting, device timeline, or Advanced Hunting.'
        AlertExpectation  = 'Alerting depends on environment configuration; analyst should confirm visibility in security.microsoft.com.'
        Verify            = 'security.microsoft.com → Reports → Attack surface reduction rules / Device timeline / Advanced Hunting'
    }
    'ASR Guided Validation - Office Process Injection' = @{
        Category          = 'Prevention Validation'
        ExpectedBehavior  = 'Office application process injection behavior should be blocked or audited depending on configured mode.'
        ExpectedTelemetry = 'ASR activity should be visible in Microsoft Defender ASR reporting, device timeline, or Advanced Hunting.'
        AlertExpectation  = 'Alerting depends on environment configuration; analyst should confirm visibility in security.microsoft.com.'
        Verify            = 'security.microsoft.com → Reports → Attack surface reduction rules / Device timeline / Advanced Hunting'
    }

}

function Initialize-MDEFramework {
    if (-not (Test-Path -LiteralPath $script:LogDir)) {
        New-Item -ItemType Directory -Path $script:LogDir -Force | Out-Null
    }

    if (-not $script:LogFile) {
        $script:LogFile = Join-Path $script:LogDir ("MDE-TestLog_{0}.log" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
        New-Item -ItemType File -Path $script:LogFile -Force | Out-Null
    }
}

function Write-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet('INFO','WARN','ERROR','PASS')]
        [string]$Level = 'INFO'
    )

    Initialize-MDEFramework

    $line = "{0} [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Add-Content -Path $script:LogFile -Value $line
}

function Get-TestMetadata {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    if ($script:TestMetadata.ContainsKey($Name)) {
        return $script:TestMetadata[$Name]
    }

    return @{
        Category          = 'General'
        ExpectedBehavior  = 'Review test details.'
        ExpectedTelemetry = 'Review test details.'
        AlertExpectation  = 'Review test details.'
        Verify            = 'Review test details.'
    }
}

function Add-Result {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Status,

        [Parameter(Mandatory)]
        [string]$Details
    )

    $meta = Get-TestMetadata -Name $Name

    $item = [PSCustomObject]@{
        TestName          = $Name
        Category          = [string]$meta.Category
        Status            = $Status
        Details           = $Details
        ExpectedBehavior  = [string]$meta.ExpectedBehavior
        ExpectedTelemetry = [string]$meta.ExpectedTelemetry
        AlertExpectation  = [string]$meta.AlertExpectation
        Verify            = [string]$meta.Verify
        Time              = Get-Date
    }

    $script:Results += $item

    $level = switch ($Status) {
        'Passed'  { 'PASS' }
        'Warning' { 'WARN' }
        'Failed'  { 'ERROR' }
        default   { 'INFO' }
    }

    Write-Log -Message "$Name | $Status | $Details" -Level $level
}

function ConvertTo-HtmlEncoded {
    param(
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return ''
    }

    return [System.Net.WebUtility]::HtmlEncode([string]$Value)
}

function Get-CategorySummary {
    $categories = 'Platform Health', 'Prevention Validation', 'Detection & Telemetry', 'Cloud Visibility'

    foreach ($category in $categories) {
        $items = @($script:Results | Where-Object { $_.Category -eq $category })

        if ($items.Count -eq 0) {
            [PSCustomObject]@{
                Category = $category
                Result   = 'Not Run'
            }
            continue
        }

        if ($items.Status -contains 'Failed') {
            $result = 'Failed'
        }
        elseif ($items.Status -contains 'Warning') {
            $result = 'Needs Review'
        }
        elseif ($items.Status -contains 'Executed') {
            $result = 'Needs Review'
        }
        else {
            $result = 'Passed'
        }

        [PSCustomObject]@{
            Category = $category
            Result   = $result
        }
    }
}

function Test-DefenderService {
    try {
        $svc = Get-Service -Name 'Sense' -ErrorAction Stop
        if ($svc.Status -eq 'Running') {
            Add-Result 'Defender Sensor' 'Passed' 'Microsoft Defender for Endpoint sensor service is running.'
        }
        else {
            Add-Result 'Defender Sensor' 'Failed' "Sense service found, but status is $($svc.Status)."
        }
    }
    catch {
        Add-Result 'Defender Sensor' 'Failed' $_.Exception.Message
    }
}

function Test-AVStatus {
    try {
        $status = Get-MpComputerStatus -ErrorAction Stop

        $details = "RealtimeProtection={0}; AntivirusEnabled={1}; AMServiceEnabled={2}" -f `
            $status.RealTimeProtectionEnabled,
            $status.AntivirusEnabled,
            $status.AMServiceEnabled

        if ($status.RealTimeProtectionEnabled -and $status.AntivirusEnabled) {
            Add-Result 'AV Status' 'Passed' $details
        }
        else {
            Add-Result 'AV Status' 'Warning' $details
        }
    }
    catch {
        Add-Result 'AV Status' 'Failed' $_.Exception.Message
    }
}

function Test-ASR {
    try {
        $pref = Get-MpPreference -ErrorAction Stop
        $rules = @($pref.AttackSurfaceReductionRules_Ids)

        if ($null -ne $rules -and $rules.Count -gt 0) {
            Add-Result 'ASR Configuration' 'Passed' "$($rules.Count) ASR rule(s) configured."
        }
        else {
            Add-Result 'ASR Configuration' 'Warning' 'No ASR rules configured on this endpoint.'
        }
    }
    catch {
        Add-Result 'ASR Configuration' 'Failed' $_.Exception.Message
    }
}

function Test-EICAR {
    $file = Join-Path $env:TEMP 'eicar.com.txt'

    try {
        if (Test-Path -LiteralPath $file) {
            Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue
        }

        Invoke-WebRequest -Uri 'https://secure.eicar.org/eicar.com.txt' -OutFile $file -ErrorAction Stop

        Start-Sleep -Seconds 5

        $threat = $null
        try {
            $threat = Get-MpThreatDetection -ErrorAction Stop | Where-Object {
                $_.Resources -match 'eicar' -or $_.ThreatName -match 'eicar'
            }
        }
        catch {
        }

        if ($threat) {
            Add-Result 'EICAR Test' 'Passed' 'Defender detected EICAR.'
        }
        elseif (-not (Test-Path -LiteralPath $file)) {
            Add-Result 'EICAR Test' 'Passed' 'EICAR file was removed or quarantined.'
        }
        else {
            Add-Result 'EICAR Test' 'Warning' 'EICAR file still exists. Check Defender policy, exclusions, or delayed remediation.'
        }
    }
    catch {
        $msg = $_.Exception.Message
        if ($msg -match 'virus|malware|threat|denied|forbidden') {
            Add-Result 'EICAR Test' 'Passed' "Download blocked as expected: $msg"
        }
        else {
            Add-Result 'EICAR Test' 'Warning' $msg
        }
    }
    finally {
        if (Test-Path -LiteralPath $file) {
            Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue
        }
    }
}

function Test-EDR {
    try {
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes('Write-Output "MDE test simulation"'))
        Start-Process -FilePath 'powershell.exe' -ArgumentList "-NoProfile -WindowStyle Hidden -EncodedCommand $encoded" -WindowStyle Hidden -ErrorAction Stop | Out-Null
        Add-Result 'EDR Simulation' 'Executed' 'Benign encoded PowerShell executed. Validate process execution, command-line visibility, and any related alerts in the Defender portal.'
    }
    catch {
        Add-Result 'EDR Simulation' 'Failed' $_.Exception.Message
    }
}

function Test-GraphModule {
    try {
        $mod = Get-Module -ListAvailable -Name Microsoft.Graph.Authentication | Select-Object -First 1
        if ($mod) {
            Add-Result 'Graph Module' 'Passed' "Microsoft.Graph available. Version: $($mod.Version)"
        }
        else {
            Add-Result 'Graph Module' 'Warning' 'Microsoft.Graph PowerShell module not installed.'
        }
    }
    catch {
        Add-Result 'Graph Module' 'Warning' $_.Exception.Message
    }
}

function Test-GraphConnection {
    try {
        $ctx = Get-MgContext -ErrorAction Stop
        if ($ctx -and $ctx.Account) {
            Add-Result 'Graph Connection' 'Passed' "Connected as $($ctx.Account)"
        }
        else {
            Add-Result 'Graph Connection' 'Warning' 'Graph module present, but no active connection found.'
        }
    }
    catch {
        Add-Result 'Graph Connection' 'Warning' 'No active Graph connection found.'
    }
}

function Get-MDEAlerts {
    try {
        $ctx = Get-MgContext -ErrorAction Stop
        if (-not $ctx -or -not $ctx.Account) {
            Add-Result 'Alert Retrieval' 'Warning' 'Skipped because no Graph connection is active.'
            return
        }

        $uri = 'https://graph.microsoft.com/v1.0/security/alerts?$top=5'
        $alerts = Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction Stop

        if ($alerts.value -and $alerts.value.Count -gt 0) {
            $sampleTitles = @()

            foreach ($alert in ($alerts.value | Select-Object -First 3)) {
                if ($alert -is [System.Collections.IDictionary]) {
                    if ($alert.Contains('title') -and $alert['title']) {
                        $sampleTitles += [string]$alert['title']
                    }
                    elseif ($alert.Contains('Title') -and $alert['Title']) {
                        $sampleTitles += [string]$alert['Title']
                    }
                    elseif ($alert.Contains('id') -and $alert['id']) {
                        $sampleTitles += "Alert ID: $($alert['id'])"
                    }
                    else {
                        $sampleTitles += 'Alert returned without title field'
                    }
                }
                else {
                    if ($alert.PSObject.Properties['title'] -and $alert.title) {
                        $sampleTitles += [string]$alert.title
                    }
                    elseif ($alert.PSObject.Properties['Title'] -and $alert.Title) {
                        $sampleTitles += [string]$alert.Title
                    }
                    elseif ($alert.PSObject.Properties['id'] -and $alert.id) {
                        $sampleTitles += "Alert ID: $($alert.id)"
                    }
                    else {
                        $sampleTitles += 'Alert returned without title field'
                    }
                }
            }

            $sample = $sampleTitles -join '; '
            Add-Result 'Alert Retrieval' 'Passed' "Retrieved $($alerts.value.Count) alert(s). Sample: $sample"
        }
        else {
            Add-Result 'Alert Retrieval' 'Warning' 'Query succeeded but returned no alerts.'
        }
    }
    catch {
        Add-Result 'Alert Retrieval' 'Warning' $_.Exception.Message
    }
}

function Get-ASRRuleActionName {
    param([int]$Action)

    switch ($Action) {
        0 { 'Disabled' }
        1 { 'Block' }
        2 { 'Audit' }
        6 { 'Warn' }
        default { "Unknown ($Action)" }
    }
}

function Get-ASRRuleState {
    param(
        [Parameter(Mandatory)]
        [string]$RuleId
    )

    try {
        $pref = Get-MpPreference -ErrorAction Stop
        $ids = @($pref.AttackSurfaceReductionRules_Ids)
        $actions = @($pref.AttackSurfaceReductionRules_Actions)

        for ($i = 0; $i -lt $ids.Count; $i++) {
            if ([string]$ids[$i] -eq $RuleId) {
                return [PSCustomObject]@{
                    RuleId     = $RuleId
                    Configured = $true
                    ActionCode = [int]$actions[$i]
                    ActionName = Get-ASRRuleActionName -Action ([int]$actions[$i])
                }
            }
        }

        return [PSCustomObject]@{
            RuleId     = $RuleId
            Configured = $false
            ActionCode = $null
            ActionName = 'Not Configured'
        }
    }
    catch {
        return [PSCustomObject]@{
            RuleId     = $RuleId
            Configured = $false
            ActionCode = $null
            ActionName = "Error: $($_.Exception.Message)"
        }
    }
}

function Get-ShadowVerifyGuidedAsrRules {
    return @(
        [PSCustomObject]@{
            Id = 'asr-office-child'
            Title = 'ASR Office Child Process Validation'
            ShortTitle = 'Office Child Process'
            ResultName = 'ASR Guided Validation - Office Child Process'
            RuleName = 'Block all Office applications from creating child processes'
            RuleId = 'D4F940AB-401B-4EFC-AADC-AD5F3C50688A'
            Purpose = 'Validate the ASR rule that prevents Office applications from launching child processes such as cmd.exe or powershell.exe.'
            Details = 'Office child process creation should be blocked in Block mode, logged in Audit mode, or warn the user in Warn mode.'
            Kql = 'DeviceEvents
| where Timestamp > ago(1h)
| where ActionType startswith "Asr"
| project Timestamp, DeviceName, ActionType, FileName, InitiatingProcessFileName, AdditionalFields
| order by Timestamp desc'
        }
        [PSCustomObject]@{
            Id = 'asr-lsass'
            Title = 'ASR Credential Theft Protection Validation'
            ShortTitle = 'Credential Theft / LSASS'
            ResultName = 'ASR Guided Validation - Credential Theft Protection'
            RuleName = 'Block credential stealing from the Windows local security authority subsystem'
            RuleId = '9E6C4E1F-7D60-472F-BA1A-A39EF669E4B2'
            Purpose = 'Validate that LSASS credential access protection is configured and that ASR telemetry is available for credential theft protection events.'
            Details = 'LSASS access attempts should be blocked in Block mode or logged in Audit mode. This rule can be noisy and should be validated carefully before broad enforcement.'
            Kql = 'DeviceEvents
| where Timestamp > ago(24h)
| where ActionType startswith "Asr"
| where AdditionalFields has "9e6c4e1f" or ActionType has "Lsass" or ActionType has "Credential"
| project Timestamp, DeviceName, ActionType, FileName, InitiatingProcessFileName, AdditionalFields
| order by Timestamp desc'
        }
        [PSCustomObject]@{
            Id = 'asr-executable-content'
            Title = 'ASR Executable Content Validation'
            ShortTitle = 'Executable Content'
            ResultName = 'ASR Guided Validation - Executable Content'
            RuleName = 'Block executable content from email client and webmail'
            RuleId = 'BE9BA2D9-53EA-4CDC-84E5-9B1EEEE46550'
            Purpose = 'Validate the ASR rule that blocks executable or script content launched from email client or webmail contexts.'
            Details = 'Executable content from email or webmail should be blocked in Block mode or logged in Audit mode. Use controlled Microsoft demo scenarios or known-safe internal test artifacts only.'
            Kql = 'DeviceEvents
| where Timestamp > ago(24h)
| where ActionType startswith "Asr"
| where AdditionalFields has "be9ba2d9" or FileName has_any (".exe", ".dll", ".scr", ".ps1", ".vbs", ".js")
| project Timestamp, DeviceName, ActionType, FileName, InitiatingProcessFileName, AdditionalFields
| order by Timestamp desc'
        }
        [PSCustomObject]@{
            Id = 'asr-obfuscated-scripts'
            Title = 'ASR Obfuscated Script Validation'
            ShortTitle = 'Obfuscated Scripts'
            ResultName = 'ASR Guided Validation - Obfuscated Scripts'
            RuleName = 'Block execution of potentially obfuscated scripts'
            RuleId = '5BEB7EFE-FD9A-4556-801D-275E5FFC04CC'
            Purpose = 'Validate that potentially obfuscated script activity is controlled and visible in Defender reporting.'
            Details = 'Potentially obfuscated scripts should be blocked in Block mode or logged in Audit mode. Prefer Microsoft demonstration scenarios or approved internal validation scripts.'
            Kql = 'DeviceEvents
| where Timestamp > ago(24h)
| where ActionType startswith "Asr"
| where AdditionalFields has "5beb7efe" or ActionType has "Obfuscated"
| project Timestamp, DeviceName, ActionType, FileName, InitiatingProcessFileName, AdditionalFields
| order by Timestamp desc'
        }
        [PSCustomObject]@{
            Id = 'asr-office-injection'
            Title = 'ASR Office Process Injection Validation'
            ShortTitle = 'Office Process Injection'
            ResultName = 'ASR Guided Validation - Office Process Injection'
            RuleName = 'Block Office applications from injecting code into other processes'
            RuleId = '75668C1F-73B5-4CF0-BB93-3ECF5CB7CC84'
            Purpose = 'Validate the ASR rule that blocks Office applications from injecting code into other processes.'
            Details = 'Office process injection should be blocked in Block mode or logged in Audit mode. This is a guided validation item and should not run aggressive automated simulation from Shadow Verify.'
            Kql = 'DeviceEvents
| where Timestamp > ago(24h)
| where ActionType startswith "Asr"
| where AdditionalFields has "75668c1f" or ActionType has "Office"
| project Timestamp, DeviceName, ActionType, FileName, InitiatingProcessFileName, AdditionalFields
| order by Timestamp desc'
        }
    )
}

function Test-ASRGuidedOfficeChildProcess {
    $rules = @(Get-ShadowVerifyGuidedAsrRules)

    foreach ($rule in $rules) {
        $state = Get-ASRRuleState -RuleId $rule.RuleId

        if (-not $state.Configured) {
            Add-Result $rule.ResultName 'Warning' (
                "Rule not configured. Rule: $($rule.RuleName). GUID: $($rule.RuleId). Configure the rule in Audit, Warn, or Block mode, then use the Guided Testing Experiences blade in the HTML report to validate behavior and telemetry in security.microsoft.com."
            )
            continue
        }

        $expected = switch ($state.ActionName) {
            'Block' { 'Expected: behavior should be blocked and visible in Defender reporting where telemetry is available.' }
            'Audit' { 'Expected: behavior may be allowed, but ASR telemetry should be logged for analyst review.' }
            'Warn'  { 'Expected: user warning should be shown where supported and telemetry should be available for review.' }
            'Disabled' { 'Expected: no ASR enforcement. Treat as a validation gap unless intentionally disabled.' }
            default { "Expected behavior could not be determined because rule mode is $($state.ActionName)." }
        }

        Add-Result $rule.ResultName 'Executed' (
            "Guided ASR validation prepared. Rule: $($rule.RuleName). Mode: $($state.ActionName). $expected Open the HTML report Guided Testing Experiences blade for step-by-step validation and confirm telemetry or alerting in security.microsoft.com."
        )
    }
}

function Export-ResultsJson {
    Initialize-MDEFramework
    $jsonPath = Join-Path $script:LogDir 'results.json'
    $script:Results | ConvertTo-Json -Depth 6 | Set-Content -Path $jsonPath -Encoding UTF8
    Write-Log -Message "Results exported to $jsonPath" -Level INFO
    return $jsonPath
}

function Export-ResultsHtml {
    Initialize-MDEFramework
    $htmlPath = Join-Path $script:LogDir 'results.html'

    $logoPath = Join-Path $script:BasePath 'shadowverify.png'
    $logoHtml = ''
    if (Test-Path -LiteralPath $logoPath) {
        try {
            $logoBytes = [System.IO.File]::ReadAllBytes($logoPath)
            $logoBase64 = [Convert]::ToBase64String($logoBytes)
            $logoHtml = "<img class='tool-logo' src='data:image/png;base64,$logoBase64' alt='Shadow Verify Logo' />"
        }
        catch { }
    }

    $total = @($script:Results).Count
    $passed = @($script:Results | Where-Object { $_.Status -eq 'Passed' }).Count
    $verify = @($script:Results | Where-Object { $_.Status -in @('Warning','Executed') }).Count
    $failed = @($script:Results | Where-Object { $_.Status -eq 'Failed' }).Count

    $score = 0
    if ($total -gt 0) {
        $score = [math]::Round((($passed + ($verify * 0.5)) / $total) * 100)
    }

    $categories = 'Platform Health', 'Prevention Validation', 'Detection & Telemetry', 'Cloud Visibility', 'General'

    $sections = foreach ($category in $categories) {
        $items = @($script:Results | Where-Object { $_.Category -eq $category })
        if ($items.Count -eq 0) { continue }

        $cards = foreach ($r in $items) {
            $statusClass = switch ($r.Status) {
                'Passed'   { 'pass' }
                'Warning'  { 'verify' }
                'Executed' { 'verify' }
                'Failed'   { 'fail' }
                default    { 'default' }
            }

            $pillText = switch ($r.Status) {
                'Passed'   { 'PASS' }
                'Warning'  { 'VERIFY' }
                'Executed' { 'VERIFY' }
                'Failed'   { 'FAILED' }
                default    { $r.Status }
            }

@"
<div class="result-card">
    <div class="result-main">
        <div class="test-title">$(ConvertTo-HtmlEncoded $r.TestName)</div>
        <div class="test-detail">$(ConvertTo-HtmlEncoded $r.Details)</div>
    </div>
    <div class="pill $statusClass">$pillText</div>
    <div class="verify-location">$(ConvertTo-HtmlEncoded $r.Verify)</div>
    <div class="time">$(Get-Date $r.Time -Format 'HH:mm:ss')</div>
</div>
"@
        }

@"
<section class="section">
    <h2>$category</h2>
    $($cards -join "`n")
</section>
"@
    }

    $asrRules = @(Get-ShadowVerifyGuidedAsrRules)

    $asrReadinessCards = foreach ($rule in $asrRules) {
        $state = Get-ASRRuleState -RuleId $rule.RuleId
        $modeClass = switch ($state.ActionName) {
            'Block' { 'mode-block' }
            'Audit' { 'mode-audit' }
            'Warn' { 'mode-warn' }
            'Disabled' { 'mode-disabled' }
            'Not Configured' { 'mode-missing' }
            default { 'mode-missing' }
        }

@"
<div class="readiness-card">
  <div class="readiness-title">$(ConvertTo-HtmlEncoded $rule.ShortTitle)</div>
  <div class="readiness-rule">$(ConvertTo-HtmlEncoded $rule.RuleName)</div>
  <div class="readiness-footer"><span class="mode-pill $modeClass">$(ConvertTo-HtmlEncoded $state.ActionName)</span><button class="mini-open" onclick="openGuideBlade('$($rule.Id)')">Open Guide</button></div>
</div>
"@
    }

    $guideCards = foreach ($rule in $asrRules) {
        $state = Get-ASRRuleState -RuleId $rule.RuleId
@"
<button class="guide-card" onclick="openGuideBlade('$($rule.Id)')">
  <span class="guide-title">$(ConvertTo-HtmlEncoded $rule.Title)</span>
  <span class="guide-pill">VERIFY</span>
  <span class="guide-mode">Current mode: $(ConvertTo-HtmlEncoded $state.ActionName)</span>
  <small>$(ConvertTo-HtmlEncoded $rule.Purpose)</small>
</button>
"@
    }


    $edrGuideCard = @"
<button class="guide-card" onclick="openGuideBlade('edr-telemetry-validation')">
  <span class="guide-title">EDR Telemetry & Alert Validation</span>
  <span class="guide-pill">VERIFY</span>
  <span class="guide-mode">Current mode: Analyst confirmation required</span>
  <small>Confirm benign PowerShell simulation telemetry, command-line visibility, timeline evidence, and related alert visibility in Microsoft Defender.</small>
</button>
"@

    $edrGuideBlade = @"
<div id="edr-telemetry-validation" class="guide-content">
  <div class="drawer-header">
    <span class="drawer-severity">Guided Validation</span>
    <h2>EDR Telemetry & Alert Validation</h2>
    <p>Validate that the benign EDR simulation created endpoint telemetry and that security teams can confirm visibility in Microsoft Defender.</p>
  </div>

  <div class="drawer-section">
    <h4>Purpose</h4>
    <p>This validation confirms that process execution telemetry from the Shadow Verify EDR simulation is visible to analysts. It does not guarantee that an alert will always be generated because alerting depends on policy, detection logic, licensing, and environment tuning.</p>
  </div>

  <div class="drawer-section">
    <h4>Expected Behavior</h4>
    <ul>
      <li><strong>Process telemetry:</strong> PowerShell execution should be visible in the device timeline or Advanced Hunting.</li>
      <li><strong>Command line visibility:</strong> Encoded command or PowerShell command-line details should be available where telemetry is collected.</li>
      <li><strong>Alert visibility:</strong> A related alert may appear depending on Defender configuration and detection logic.</li>
      <li><strong>Analyst confirmation:</strong> Security teams should confirm the event in security.microsoft.com.</li>
    </ul>
  </div>

  <div class="drawer-section">
    <h4>Step-by-Step Validation Workflow</h4>
    <ol class="drawer-steps">
      <li><span>1</span><p><strong>Run Shadow Verify.</strong><br/>Execute the validation workflow and note the timestamp of the EDR Simulation result.</p></li>
      <li><span>2</span><p><strong>Open Microsoft Defender.</strong><br/>Navigate to <code>security.microsoft.com</code> and open the target device from Assets → Devices.</p></li>
      <li><span>3</span><p><strong>Review the device timeline.</strong><br/>Search around the test timestamp for <code>powershell.exe</code>, encoded command activity, or related process execution events.</p></li>
      <li><span>4</span><p><strong>Run Advanced Hunting.</strong><br/>Use the included KQL queries to confirm process creation telemetry and command-line visibility.</p></li>
      <li><span>5</span><p><strong>Review incidents and alerts.</strong><br/>Check Incidents & alerts for any alert generated around the test time. Alert generation is environment dependent.</p></li>
      <li><span>6</span><p><strong>Record validation evidence.</strong><br/>Capture timestamp, device name, process evidence, command-line visibility, hunting results, and whether an alert was present.</p></li>
    </ol>
  </div>

  <div class="drawer-section">
    <h4>Where To Verify</h4>
    <p>security.microsoft.com → Assets → Devices → Device timeline</p>
    <p>security.microsoft.com → Hunting → Advanced Hunting</p>
    <p>security.microsoft.com → Incidents & alerts</p>
  </div>

  <div class="drawer-section">
    <h4>Primary Advanced Hunting Query</h4>
    <pre>DeviceProcessEvents
| where Timestamp &gt; ago(2h)
| where FileName in~ ("powershell.exe", "pwsh.exe")
| where ProcessCommandLine has_any ("EncodedCommand", "-enc", "FromBase64String")
| project Timestamp, DeviceName, FileName, ProcessCommandLine, InitiatingProcessFileName, InitiatingProcessCommandLine, AccountName, ReportId
| order by Timestamp desc</pre>
  </div>

  <div class="drawer-section">
    <h4>Timeline Correlation Query</h4>
    <pre>DeviceEvents
| where Timestamp &gt; ago(2h)
| where ActionType has_any ("Process", "PowerShell", "Script") or AdditionalFields has_any ("EncodedCommand", "powershell", "pwsh")
| project Timestamp, DeviceName, ActionType, FileName, InitiatingProcessFileName, AdditionalFields
| order by Timestamp desc</pre>
  </div>

  <div class="drawer-section">
    <h4>Alert Correlation Query</h4>
    <pre>AlertEvidence
| where Timestamp &gt; ago(24h)
| where DeviceName has_any (DeviceName) or EntityType has_any ("Process", "File")
| where EvidenceDirection == "Related" or FileName has_any ("powershell.exe", "pwsh.exe")
| project Timestamp, AlertId, Title, DeviceName, EntityType, FileName, ProcessCommandLine
| order by Timestamp desc</pre>
  </div>

  <div class="drawer-section">
    <h4>Validation Outcome Guide</h4>
    <ul>
      <li><strong>Pass:</strong> Process execution and command-line telemetry are visible in timeline or Advanced Hunting.</li>
      <li><strong>Verify:</strong> Simulation ran, but analyst must confirm portal visibility.</li>
      <li><strong>Investigate:</strong> No telemetry appears after a reasonable delay; review onboarding, licensing, sensor health, and hunting table availability.</li>
    </ul>
  </div>
</div>
"@

    $guideBlades = foreach ($rule in $asrRules) {
        $state = Get-ASRRuleState -RuleId $rule.RuleId
        $safeTitle = ConvertTo-HtmlEncoded $rule.Title
        $safePurpose = ConvertTo-HtmlEncoded $rule.Purpose
        $safeRuleName = ConvertTo-HtmlEncoded $rule.RuleName
        $safeRuleId = ConvertTo-HtmlEncoded $rule.RuleId
        $safeMode = ConvertTo-HtmlEncoded $state.ActionName
        $safeDetails = ConvertTo-HtmlEncoded $rule.Details
        $safeKql = ConvertTo-HtmlEncoded $rule.Kql

        $workflowHtml = switch ($rule.Id) {
            'asr-office-child' {
@"
<ol class="drawer-steps">
  <li><span>1</span><p><strong>Confirm rule configuration.</strong><br/>Run <code>Get-MpPreference</code> or check Intune Endpoint Security → Attack Surface Reduction. Confirm the rule is Audit, Warn, or Block.</p></li>
  <li><span>2</span><p><strong>Prepare a controlled Office macro test.</strong><br/>In a lab or approved test device, create a macro-enabled Word document. Open Visual Basic Editor with ALT+F11, insert a module, and use this benign test macro:<br/><code>Sub TestASR()<br/>    Shell "cmd.exe"<br/>End Sub</code></p></li>
  <li><span>3</span><p><strong>Run the test and observe behavior.</strong><br/>Block mode should prevent cmd.exe from launching. Audit mode may allow execution but should log ASR telemetry. Warn mode should display a prompt where supported.</p></li>
  <li><span>4</span><p><strong>Verify in Microsoft Defender.</strong><br/>Open security.microsoft.com and review ASR reports, the device timeline, incidents/alerts, and Advanced Hunting.</p></li>
  <li><span>5</span><p><strong>Record outcome.</strong><br/>Document rule mode, observed endpoint behavior, timeline evidence, hunting results, and whether the result matched expectations.</p></li>
</ol>
"@
            }
            'asr-lsass' {
@"
<ol class="drawer-steps">
  <li><span>1</span><p><strong>Confirm rule mode.</strong><br/>Validate the LSASS credential theft protection rule is configured in Audit, Warn, or Block mode.</p></li>
  <li><span>2</span><p><strong>Use a controlled validation source.</strong><br/>Do not run credential-dumping tools from Shadow Verify. Use Microsoft demonstration guidance, approved internal validation, or existing ASR audit telemetry from normal software behavior.</p></li>
  <li><span>3</span><p><strong>Review expected behavior.</strong><br/>Block mode should deny suspicious LSASS access attempts. Audit mode should generate telemetry without blocking.</p></li>
  <li><span>4</span><p><strong>Verify in the portal.</strong><br/>Review security.microsoft.com ASR reports, device timeline, and Advanced Hunting for LSASS-related ASR events.</p></li>
  <li><span>5</span><p><strong>Validate noise and exclusions.</strong><br/>This rule can generate legitimate audit events. Review source process, signer, path, and business need before considering exclusions.</p></li>
</ol>
"@
            }
            'asr-executable-content' {
@"
<ol class="drawer-steps">
  <li><span>1</span><p><strong>Confirm rule configuration.</strong><br/>Verify the executable content from email and webmail rule is configured and applied to the endpoint.</p></li>
  <li><span>2</span><p><strong>Use a safe test method.</strong><br/>Use a Microsoft demo scenario or an approved internal non-malicious test file from an email/webmail context. Do not use live malware or untrusted payloads.</p></li>
  <li><span>3</span><p><strong>Attempt controlled launch.</strong><br/>In Block mode, executable/script content should be blocked. In Audit mode, the action may complete but telemetry should be recorded.</p></li>
  <li><span>4</span><p><strong>Verify ASR telemetry.</strong><br/>Review security.microsoft.com ASR reports, device timeline, and Advanced Hunting for the test window.</p></li>
  <li><span>5</span><p><strong>Document the result.</strong><br/>Record mode, source, observed behavior, evidence location, and whether alerting or reporting matched expectations.</p></li>
</ol>
"@
            }
            'asr-obfuscated-scripts' {
@"
<ol class="drawer-steps">
  <li><span>1</span><p><strong>Confirm rule mode.</strong><br/>Validate that the obfuscated script ASR rule is configured in Audit, Warn, or Block mode.</p></li>
  <li><span>2</span><p><strong>Choose an approved validation scenario.</strong><br/>Use Microsoft demonstration guidance or a pre-approved internal validation script. Avoid publishing or running evasive obfuscation patterns from the tool itself.</p></li>
  <li><span>3</span><p><strong>Run the controlled validation.</strong><br/>Block mode should prevent suspicious script execution. Audit mode should allow observation without enforcement.</p></li>
  <li><span>4</span><p><strong>Review Defender evidence.</strong><br/>Check ASR reporting, device timeline, and Advanced Hunting around the exact test timestamp.</p></li>
  <li><span>5</span><p><strong>Confirm expected outcome.</strong><br/>Document whether the endpoint response matched the configured mode and whether telemetry was visible.</p></li>
</ol>
"@
            }
            'asr-office-injection' {
@"
<ol class="drawer-steps">
  <li><span>1</span><p><strong>Confirm rule configuration.</strong><br/>Verify Office process injection prevention is configured in Audit, Warn, or Block mode.</p></li>
  <li><span>2</span><p><strong>Use Microsoft or approved demonstration guidance.</strong><br/>Do not generate process injection attempts from Shadow Verify. Use controlled demonstrations or existing ASR telemetry.</p></li>
  <li><span>3</span><p><strong>Observe rule behavior.</strong><br/>Block mode should prevent Office process injection behavior. Audit mode should record telemetry for analyst review.</p></li>
  <li><span>4</span><p><strong>Verify visibility.</strong><br/>Review device timeline, ASR reports, and Advanced Hunting for Office-related ASR events.</p></li>
  <li><span>5</span><p><strong>Record validation evidence.</strong><br/>Capture mode, source application, action type, timestamp, and portal evidence.</p></li>
</ol>
"@
            }
        }

@"
<div id="$($rule.Id)" class="guide-content">
  <div class="drawer-header">
    <span class="drawer-severity">Guided Validation</span>
    <h2>$safeTitle</h2>
    <p>$safePurpose</p>
  </div>
  <div class="drawer-section"><h4>Rule</h4><p><strong>$safeRuleName</strong></p><p><code>$safeRuleId</code></p><p><strong>Current Mode:</strong> $safeMode</p></div>
  <div class="drawer-section"><h4>Expected Behavior</h4><p>$safeDetails</p><ul><li><strong>Block:</strong> behavior should be blocked.</li><li><strong>Audit:</strong> behavior may be allowed, but telemetry should be logged.</li><li><strong>Warn:</strong> user warning should be shown where supported.</li><li><strong>Disabled / Not Configured:</strong> no enforcement is expected.</li></ul></div>
  <div class="drawer-section"><h4>Step-by-Step Validation Workflow</h4>$workflowHtml</div>
  <div class="drawer-section"><h4>Where To Verify</h4><p>security.microsoft.com → Reports → Attack surface reduction rules</p><p>security.microsoft.com → Assets → Devices → Device timeline</p><p>security.microsoft.com → Hunting → Advanced Hunting</p><p>security.microsoft.com → Incidents & alerts</p></div>
  <div class="drawer-section"><h4>Suggested Advanced Hunting</h4><pre>$safeKql</pre></div>
</div>
"@
    }

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Shadow Verify Report</title>
<style>
body { margin:0; padding:28px; font-family:Segoe UI,Arial,sans-serif; background:radial-gradient(circle at top left,rgba(130,45,230,.24),transparent 34%),radial-gradient(circle at top right,rgba(78,18,150,.20),transparent 36%),#05070c; color:#f5f7fa; }
.shell { max-width:1450px; margin:0 auto; }
.header,.section,.guided-section { background:linear-gradient(180deg,rgba(16,21,32,.96),rgba(5,7,12,.98)); border:1px solid #4e1296; border-radius:18px; box-shadow:0 0 28px rgba(130,45,230,.16); }
.header { display:grid; grid-template-columns:420px 1fr 360px; gap:24px; align-items:center; padding:24px; border-left:6px solid #822de6; }
.tool-logo { max-width:400px; max-height:150px; object-fit:contain; filter:drop-shadow(0 0 18px rgba(130,45,230,.45)); }
.brand-fallback { font-size:34px; font-weight:900; }
.subtitle h1 { margin:0; font-size:32px; }
.subtitle p,.meta,.section-subtitle { color:#bec3cd; }
.summary { background:#101520; border:1px solid #4e1296; border-radius:14px; padding:16px; }
.summary-title { color:#c27cff; font-weight:900; font-size:13px; margin-bottom:10px; }
.metrics { display:grid; grid-template-columns:repeat(4,1fr); gap:8px; }
.metric { background:#181e2c; border:1px solid #3b284d; border-radius:12px; padding:10px; text-align:center; }
.metric .value { font-size:22px; font-weight:900; }
.metric .label { font-size:11px; color:#bec3cd; }
.score { color:#c27cff; }.passText { color:#6ee7a0; }.verifyText { color:#d8b4fe; }.failText { color:#ff8d8d; }
.note { margin-top:20px; background:rgba(255,255,255,.035); border:1px solid #4e1296; border-left:5px solid #822de6; border-radius:14px; padding:14px; color:#bec3cd; }
.section,.guided-section { margin-top:22px; padding:18px; }
.section h2,.guided-section h2 { margin:0 0 14px 0; color:#c27cff; text-transform:uppercase; font-size:18px; }
.result-card { display:grid; grid-template-columns:1fr 110px 320px 80px; gap:12px; align-items:center; background:rgba(255,255,255,.035); border:1px solid #3b284d; border-left:4px solid #822de6; border-radius:12px; padding:12px; margin-bottom:10px; }
.test-title { font-weight:800; }.test-detail,.verify-location,.time { color:#bec3cd; font-size:12px; }
.pill { text-align:center; padding:7px 10px; border-radius:999px; font-weight:900; font-size:12px; border:1px solid #444a58; }.pass { background:#108040; }.verify { background:#4e1296; }.fail { background:#b91c1c; }.default { background:#181e2c; }
.readiness-grid { display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); gap:12px; margin-top:12px; }
.readiness-card { border:1px solid #3b284d; border-left:4px solid #822de6; border-radius:14px; background:rgba(255,255,255,.035); padding:14px; }
.readiness-title { color:#fff; font-weight:900; margin-bottom:6px; }.readiness-rule { color:#bec3cd; font-size:12px; line-height:1.35; }
.readiness-footer { display:flex; justify-content:space-between; gap:10px; align-items:center; margin-top:12px; }
.mode-pill { border-radius:999px; padding:4px 10px; font-size:11px; font-weight:900; border:1px solid #3b284d; }.mode-block { background:#108040; }.mode-audit { background:#4e1296; }.mode-warn { background:#842c08; }.mode-disabled,.mode-missing { background:#3b1111; }
.mini-open { border:1px solid #822de6; background:#281536; color:#fff; border-radius:999px; padding:6px 10px; cursor:pointer; font-weight:800; }
.guide-grid { display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); gap:12px; margin-top:12px; }
.guide-card { width:100%; text-align:left; border:1px solid #4e1296; border-left:5px solid #822de6; border-radius:14px; background:rgba(255,255,255,.035); color:#fff; padding:16px; cursor:pointer; font-family:Segoe UI,Arial,sans-serif; }
.guide-card:hover { background:rgba(130,45,230,.16); box-shadow:0 0 22px rgba(130,45,230,.25); }
.guide-title { display:block; font-size:16px; font-weight:900; margin-bottom:8px; }.guide-pill { display:inline-block; background:#4e1296; border:1px solid #822de6; border-radius:999px; padding:4px 10px; color:#fff; font-size:11px; font-weight:900; margin-right:8px; margin-bottom:8px; }.guide-mode { display:inline-block; color:#d8b4fe; font-size:12px; font-weight:800; }.guide-card small { display:block; color:#bec3cd; line-height:1.35; }
.guide-overlay { position:fixed; inset:0; background:rgba(0,0,0,.55); opacity:0; pointer-events:none; transition:opacity .18s ease; z-index:9998; }.guide-overlay.open { opacity:1; pointer-events:auto; }
.guide-drawer { position:fixed; top:0; right:-620px; width:600px; max-width:92vw; height:100vh; background:linear-gradient(180deg,#17131f,#05070c); border-left:1px solid #822de6; box-shadow:-18px 0 38px rgba(0,0,0,.45); z-index:9999; transition:right .2s ease; padding:22px; overflow-y:auto; box-sizing:border-box; }.guide-drawer.open { right:0; }
.drawer-close { float:right; border:1px solid #822de6; background:#281536; color:#fff; border-radius:999px; padding:7px 12px; cursor:pointer; }
.drawer-header { margin-top:28px; border-bottom:1px solid #3b284d; padding-bottom:16px; }.drawer-severity { display:inline-block; color:#d8b4fe; border:1px solid #822de6; background:rgba(130,45,230,.18); border-radius:999px; padding:4px 10px; font-size:12px; font-weight:900; text-transform:uppercase; }.drawer-header h2 { color:#fff; margin:12px 0 4px 0; font-size:24px; }.drawer-header p { color:#bec3cd; }
.drawer-section { border:1px solid #3b284d; border-radius:14px; background:rgba(255,255,255,.035); margin-top:14px; padding:14px; }.drawer-section h4 { margin:0 0 8px 0; color:#c27cff; text-transform:uppercase; font-size:13px; }.drawer-section p,.drawer-section li { color:#f5f7fa; line-height:1.45; }.drawer-section code { color:#e8ddff; }
.drawer-steps { list-style:none; padding:0; margin:0; display:grid; gap:10px; }.drawer-steps li { display:grid; grid-template-columns:30px 1fr; gap:10px; }.drawer-steps li span { width:26px; height:26px; display:grid; place-items:center; border-radius:999px; background:#321846; border:1px solid #822de6; color:#fff; font-weight:900; font-size:12px; }.drawer-steps p { margin:0; }
.drawer-section pre { white-space:pre-wrap; word-break:break-word; background:#06070d; border:1px solid #3b284d; border-radius:12px; padding:12px; color:#e8ddff; font-size:12px; }
.footer { margin-top:24px; text-align:center; color:#bec3cd; font-size:12px; letter-spacing:2px; }
@media(max-width:1100px){.header,.readiness-grid,.guide-grid,.result-card{grid-template-columns:1fr}.summary{margin-top:10px}}
</style>
</head>
<body>
<div class="shell">
<div class="header"><div>$(if ($logoHtml) { $logoHtml } else { "<div class='brand-fallback'>SHADOW VERIFY</div>" })</div><div class="subtitle"><h1>Defender for Endpoint Validation Report</h1><p>Control validation, telemetry verification, Graph visibility checks, and analyst reporting.</p><p class="meta">Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Host: $(ConvertTo-HtmlEncoded $env:COMPUTERNAME)</p></div><div class="summary"><div class="summary-title">VALIDATION SUMMARY</div><div class="metrics"><div class="metric"><div class="value score">$score%</div><div class="label">SCORE</div></div><div class="metric"><div class="value passText">$passed</div><div class="label">PASS</div></div><div class="metric"><div class="value verifyText">$verify</div><div class="label">VERIFY</div></div><div class="metric"><div class="value failText">$failed</div><div class="label">FAIL</div></div></div></div></div>
<div class="note">VERIFY indicates analyst confirmation is required. The simulation or guided validation completed, but telemetry or alert visibility should be confirmed in security.microsoft.com.</div>
$($sections -join "`n")
<section class="guided-section"><h2>ASR Validation Readiness</h2><p class="section-subtitle">Current endpoint ASR mode discovery for guided validation scenarios.</p><div class="readiness-grid">$($asrReadinessCards -join "`n")</div></section>
<section class="guided-section"><h2>Guided Testing Experiences</h2><p class="section-subtitle">Open guided validation blades for analyst confirmation steps, expected behavior, and verification locations.</p><div class="guide-grid">$edrGuideCard`n$($guideCards -join "`n")</div></section>
<div id="guideOverlay" class="guide-overlay" onclick="closeGuideBlade()"></div>
<aside id="guideDrawer" class="guide-drawer"><button class="drawer-close" onclick="closeGuideBlade()">Close</button>$edrGuideBlade`n$($guideBlades -join "`n")</aside>
<div class="footer">VALIDATE . VERIFY . DEFEND .<br>SHADOW INTELLIGENCE. REAL-WORLD IMPACT.</div>
</div>
<script>
function openGuideBlade(id) { var overlay=document.getElementById('guideOverlay'); var drawer=document.getElementById('guideDrawer'); document.querySelectorAll('.guide-content').forEach(function(item){ item.style.display='none'; }); var selected=document.getElementById(id); if(selected){ selected.style.display='block'; } overlay.classList.add('open'); drawer.classList.add('open'); }
function closeGuideBlade() { var overlay=document.getElementById('guideOverlay'); var drawer=document.getElementById('guideDrawer'); overlay.classList.remove('open'); drawer.classList.remove('open'); }
document.addEventListener('keydown', function(e) { if (e.key === 'Escape') { closeGuideBlade(); } });
</script>
</body>
</html>
"@

    Set-Content -Path $htmlPath -Value $html -Encoding UTF8
    Write-Log -Message "HTML report exported to $htmlPath" -Level INFO
    return $htmlPath
}

function Invoke-MDETests {
    param(
        [switch]$SkipEICAR,
        [switch]$SkipGraph,
        [switch]$RunASRGuidedValidation
    )

    Initialize-MDEFramework
    $script:Results = @()

    Write-Log -Message 'Starting test run.' -Level INFO

    Test-DefenderService
    Test-AVStatus
    Test-ASR

    if ($RunASRGuidedValidation) {
        Test-ASRGuidedOfficeChildProcess
    }

    if (-not $SkipEICAR) {
        Test-EICAR
    }

    Test-EDR
    Test-GraphModule

    if (-not $SkipGraph) {
        Test-GraphConnection
        Get-MDEAlerts
    }

    $null = Export-ResultsJson
    $null = Export-ResultsHtml

    return $script:Results
}

Export-ModuleMember -Function Initialize-MDEFramework,Write-Log,Invoke-MDETests,Export-ResultsJson,Export-ResultsHtml,Get-ASRRuleActionName,Get-ASRRuleState,Get-ShadowVerifyGuidedAsrRules,Test-ASRGuidedOfficeChildProcess

#requires -Version 5.1

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic

$PolicyPrefix = "MDE"
$script:LastResults = @()

function New-MDEPolicyResult {
    param([string]$Name,[string]$Status,[string]$Details)
    [pscustomobject]@{ Name=$Name; Status=$Status; Details=$Details; Time=Get-Date }
}

function Get-MDEPolicyName {
    param([string]$Name)
    "$PolicyPrefix - $Name"
}

function Assert-Mg {
    if (-not (Get-MgContext)) {
        throw "Not connected to Microsoft Graph. Click Initialize Graph first."
    }
}

function Get-MDELogFolder {
    $path = Join-Path $PSScriptRoot "Logs"
    if (-not (Test-Path -LiteralPath $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
    return $path
}

function Get-MDEReportFolder {
    $path = Join-Path $PSScriptRoot "Reports"
    if (-not (Test-Path -LiteralPath $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
    return $path
}

function Get-MDEBackupFolderRoot {
    $path = Join-Path $PSScriptRoot "Backups"
    if (-not (Test-Path -LiteralPath $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
    return $path
}

function Write-MDELogFile {
    param([string]$Message)

    try {
        $logPath = Join-Path (Get-MDELogFolder) "deployment.log"
        Add-Content -LiteralPath $logPath -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    }
    catch { }
}

function Get-MDEJsonBody {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "JSON file not found: $Path"
    }

    $raw = Get-Content -LiteralPath $Path -Raw

    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw "JSON file is empty: $Path"
    }

    $raw | ConvertFrom-Json
}

function Test-MDEJsonPolicyFile {
    param([string]$JsonPath)

    $name = Split-Path $JsonPath -Leaf

    try {
        $json = Get-MDEJsonBody -Path $JsonPath

        if (-not ($json.PSObject.Properties.Name -contains "settings")) {
            return New-MDEPolicyResult $name "Invalid" "Missing settings array"
        }

        if (-not $json.settings -or $json.settings.Count -lt 1) {
            return New-MDEPolicyResult $name "Invalid" "Settings array is empty"
        }

        return New-MDEPolicyResult $name "Valid" "JSON passed basic validation"
    }
    catch {
        return New-MDEPolicyResult $name "Invalid" $_.Exception.Message
    }
}

function Find-MDEConfigPolicyByName {
    param([string]$PolicyName)

    Assert-Mg

    $escaped = $PolicyName.Replace("'","''")
    $uri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies?`$filter=name eq '$escaped'"

    $result = Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType PSObject

    if ($result.value -and $result.value.Count -gt 0) {
        return $result.value[0]
    }

    return $null
}

function Test-MDEConfigPolicyExists {
    param([string]$Name)

    $displayName = Get-MDEPolicyName $Name

    try {
        $policy = Find-MDEConfigPolicyByName -PolicyName $displayName
        return [bool]$policy
    }
    catch {
        return $false
    }
}

function Get-MDEConfigPolicyId {
    param([string]$PolicyDisplayName)

    $policy = Find-MDEConfigPolicyByName -PolicyName $PolicyDisplayName

    if (-not $policy) {
        throw "Policy not found: $PolicyDisplayName"
    }

    return $policy.id
}

function Get-MDEGroupIdByName {
    param([string]$GroupName)

    Assert-Mg

    $escaped = $GroupName.Replace("'","''")
    $uri = "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq '$escaped'"

    $result = Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType PSObject

    if (-not $result.value -or $result.value.Count -eq 0) {
        throw "Group not found: $GroupName"
    }

    if ($result.value.Count -gt 1) {
        throw "Multiple groups found with name: $GroupName"
    }

    return $result.value[0].id
}

function Add-MDEConfigPolicyAssignment {
    param(
        [string]$PolicyDisplayName,
        [string]$GroupName
    )

    Assert-Mg

    try {
        $policyId = Get-MDEConfigPolicyId -PolicyDisplayName $PolicyDisplayName
        $groupId = Get-MDEGroupIdByName -GroupName $GroupName

        $body = @{
            assignments = @(
                @{
                    target = @{
                        "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
                        groupId = $groupId
                    }
                }
            )
        } | ConvertTo-Json -Depth 20 -Compress

        $uri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$policyId/assign"

        Invoke-MgGraphRequest `
            -Method POST `
            -Uri $uri `
            -Body $body `
            -ContentType "application/json" | Out-Null

        return New-MDEPolicyResult $PolicyDisplayName "Assigned" "Assigned to group: $GroupName"
    }
    catch {
        return New-MDEPolicyResult $PolicyDisplayName "Failed" $_.Exception.Message
    }
}

function New-MDEConfigPolicyFromJson {
    param(
        [string]$Name,
        [string]$JsonPath,
        [switch]$WhatIf
    )

    Assert-Mg

    $displayName = Get-MDEPolicyName $Name

    try {
        if (Test-MDEConfigPolicyExists -Name $Name) {
            return New-MDEPolicyResult $displayName "Skipped" "Policy already exists"
        }

        $body = Get-MDEJsonBody -Path $JsonPath
        $body.name = $displayName

        $json = $body | ConvertTo-Json -Depth 100 -Compress

        if ($WhatIf) {
            return New-MDEPolicyResult $displayName "WhatIf" "Validated JSON only: $JsonPath"
        }

        Invoke-MgGraphRequest `
            -Method POST `
            -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies" `
            -Body $json `
            -ContentType "application/json" | Out-Null

        return New-MDEPolicyResult $displayName "Success" "Created configuration policy"
    }
    catch {
        return New-MDEPolicyResult $displayName "Failed" $_.Exception.Message
    }
}

function Export-MDEConfigPolicyJson {
    param(
        [string]$PolicyName,
        [string]$OutputPath
    )

    Assert-Mg

    try {
        $policy = Find-MDEConfigPolicyByName -PolicyName $PolicyName

        if (-not $policy) {
            throw "Policy not found: $PolicyName"
        }

        $settingsUri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$($policy.id)/settings"
        $settings = Invoke-MgGraphRequest -Method GET -Uri $settingsUri -OutputType PSObject

        if (-not $settings.value -or $settings.value.Count -eq 0) {
            throw "Policy found, but no settings were returned: $PolicyName"
        }

        $body = [ordered]@{
            name            = $policy.name
            description     = $policy.description
            platforms       = $policy.platforms
            technologies    = $policy.technologies
            roleScopeTagIds = @($policy.roleScopeTagIds)
            settings        = @($settings.value)
        }

        if ($policy.PSObject.Properties.Name -contains "templateReference" -and $policy.templateReference) {
            $body.templateReference = $policy.templateReference
        }

        $folder = Split-Path $OutputPath -Parent
        if ($folder -and -not (Test-Path -LiteralPath $folder)) {
            New-Item -ItemType Directory -Path $folder -Force | Out-Null
        }

        $body | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $OutputPath -Encoding UTF8

        return New-MDEPolicyResult $PolicyName "Success" "Exported to $OutputPath"
    }
    catch {
        return New-MDEPolicyResult $PolicyName "Failed" $_.Exception.Message
    }
}

function Get-MDEFriendlyPolicyNameFromFile {
    param([string]$FileName)

    switch ($FileName.ToLower()) {
        "antivirus.json"                   { return "Antivirus" }
        "firewall.json"                    { return "Firewall" }
        "asr.json"                         { return "ASR" }
        "edr.json"                         { return "EDR" }
        "windows-security-experience.json" { return "Windows Security Experience" }
        "avc-update-controls.json"         { return "AVC Update Controls" }
        default {
            $base = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
            return (($base -replace '-', ' ') -replace '_', ' ')
        }
    }
}

function Get-MDEJsonPolicyCatalog {
    $folder = Join-Path $PSScriptRoot "Config\SettingsCatalog"

    if (-not (Test-Path -LiteralPath $folder)) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }

    Get-ChildItem -Path $folder -Filter "*.json" | Sort-Object Name | ForEach-Object {
        [pscustomobject]@{
            Name     = Get-MDEFriendlyPolicyNameFromFile -FileName $_.Name
            Category = "Settings Catalog"
            JsonPath = $_.FullName
        }
    }
}

function Get-MDESettingValue {
    param($Setting)

    $instance = $Setting.settingInstance

    if (-not $instance) {
        return ""
    }

    if ($instance.PSObject.Properties.Name -contains "choiceSettingValue") {
        return [string]$instance.choiceSettingValue.value
    }

    if ($instance.PSObject.Properties.Name -contains "simpleSettingValue") {
        return [string]$instance.simpleSettingValue.value
    }

    if ($instance.PSObject.Properties.Name -contains "simpleSettingCollectionValue") {
        return ($instance.simpleSettingCollectionValue | ConvertTo-Json -Depth 20 -Compress)
    }

    return ""
}

function Get-MDESettingsInventory {
    $inventory = @()

    foreach ($policy in Get-MDEJsonPolicyCatalog) {
        if (-not (Test-Path -LiteralPath $policy.JsonPath)) {
            continue
        }

        try {
            $json = Get-MDEJsonBody -Path $policy.JsonPath

            foreach ($setting in $json.settings) {
                $instance = $setting.settingInstance

                if (-not $instance) {
                    continue
                }

                $inventory += [pscustomobject]@{
                    Policy    = $policy.Name
                    SettingId = $instance.settingDefinitionId
                    Type      = $instance.'@odata.type'
                    Value     = Get-MDESettingValue -Setting $setting
                }
            }
        }
        catch {
            $inventory += [pscustomobject]@{
                Policy    = $policy.Name
                SettingId = "Inventory Error"
                Type      = "Error"
                Value     = $_.Exception.Message
            }
        }
    }

    return $inventory
}

function Get-MDEZeroTrustChecks {
    return @(
        @{
            Policy = "Firewall"
            Label = "Firewall policy exists in repo"
            Type = "FileExists"
            JsonPath = "Config\SettingsCatalog\firewall.json"
        },
        @{
            Policy = "Firewall"
            Label = "Firewall contains settings"
            Type = "HasSettings"
            JsonPath = "Config\SettingsCatalog\firewall.json"
        },
        @{
            Policy = "Firewall"
            Label = "Firewall has default inbound block settings"
            Type = "ContainsAnySetting"
            JsonPath = "Config\SettingsCatalog\firewall.json"
            Match = @("defaultinboundaction", "default_inbound", "inbound")
        },
        @{
            Policy = "Firewall"
            Label = "Firewall has logging visibility settings"
            Type = "ContainsAnySetting"
            JsonPath = "Config\SettingsCatalog\firewall.json"
            Match = @("log", "logging", "dropped")
        },
        @{
            Policy = "ASR"
            Label = "ASR policy exists in repo"
            Type = "FileExists"
            JsonPath = "Config\SettingsCatalog\asr.json"
        },
        @{
            Policy = "ASR"
            Label = "ASR contains configured rules"
            Type = "HasSettings"
            JsonPath = "Config\SettingsCatalog\asr.json"
        },
        @{
            Policy = "ASR"
            Label = "ASR contains attack surface reduction configuration"
            Type = "ContainsAnySetting"
            JsonPath = "Config\SettingsCatalog\asr.json"
            Match = @("attacksurfacereduction", "asr", "defender")
        },
        @{
            Policy = "EDR"
            Label = "EDR policy exists in repo"
            Type = "FileExists"
            JsonPath = "Config\SettingsCatalog\edr.json"
        },
        @{
            Policy = "EDR"
            Label = "EDR excludes connector onboarding secret"
            Type = "DoesNotContainSetting"
            JsonPath = "Config\SettingsCatalog\edr.json"
            Match = @("device_vendor_msft_windowsadvancedthreatprotection_onboarding_fromconnector")
        },
        @{
            Policy = "Windows Security Experience"
            Label = "Windows Security Experience policy exists in repo"
            Type = "FileExists"
            JsonPath = "Config\SettingsCatalog\windows-security-experience.json"
        },
        @{
            Policy = "AVC Update Controls"
            Label = "AVC Update Controls policy exists in repo"
            Type = "FileExists"
            JsonPath = "Config\SettingsCatalog\avc-update-controls.json"
        }
    )
}

function Test-MDEZeroTrustAlignment {
    $results = @()

    foreach ($check in Get-MDEZeroTrustChecks) {
        $fullPath = Join-Path $PSScriptRoot $check.JsonPath
        $passed = $false
        $found = ""
        $details = ""

        try {
            switch ($check.Type) {
                "FileExists" {
                    $passed = Test-Path -LiteralPath $fullPath
                    $found = if ($passed) { "File found" } else { "Missing file" }
                    $details = $fullPath
                }

                "HasSettings" {
                    if (Test-Path -LiteralPath $fullPath) {
                        $json = Get-MDEJsonBody -Path $fullPath
                        $passed = [bool]($json.settings -and $json.settings.Count -gt 0)
                        $found = "$($json.settings.Count) settings"
                    }
                    else {
                        $found = "Missing file"
                    }
                    $details = $fullPath
                }

                "ContainsAnySetting" {
                    if (Test-Path -LiteralPath $fullPath) {
                        $raw = (Get-Content -LiteralPath $fullPath -Raw).ToLower()
                        foreach ($term in $check.Match) {
                            if ($raw -like "*$($term.ToLower())*") {
                                $passed = $true
                                $found = "Matched: $term"
                                break
                            }
                        }

                        if (-not $passed) {
                            $found = "No matching setting found"
                        }
                    }
                    else {
                        $found = "Missing file"
                    }
                    $details = "Expected one of: $($check.Match -join ', ')"
                }

                "DoesNotContainSetting" {
                    if (Test-Path -LiteralPath $fullPath) {
                        $raw = (Get-Content -LiteralPath $fullPath -Raw).ToLower()
                        $passed = $true

                        foreach ($term in $check.Match) {
                            if ($raw -like "*$($term.ToLower())*") {
                                $passed = $false
                                $found = "Found blocked setting: $term"
                                break
                            }
                        }

                        if ($passed) {
                            $found = "Blocked setting not found"
                        }
                    }
                    else {
                        $found = "Missing file"
                    }
                    $details = "Must not contain: $($check.Match -join ', ')"
                }
            }
        }
        catch {
            $passed = $false
            $found = "Error"
            $details = $_.Exception.Message
        }

        $results += [pscustomobject]@{
            Policy  = $check.Policy
            Control = $check.Label
            Result  = if ($passed) { "Pass" } else { "Review" }
            Found   = $found
            Details = $details
        }
    }

    return $results
}

function ConvertTo-HtmlEncoded {
    param([string]$Text)

    if ($null -eq $Text) {
        return ""
    }

    return [System.Net.WebUtility]::HtmlEncode($Text)
}

function New-MDEDeploymentReport {
    param([array]$Results)

    $reportFolder = Get-MDEReportFolder
    $reportPath = Join-Path $reportFolder "deployment-report.html"
    $generated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $inventory = Get-MDESettingsInventory
    $ztChecks = Test-MDEZeroTrustAlignment

    $totalResults = @($Results).Count
    $successCount = @($Results | Where-Object { $_.Status -in @("Success","Assigned","Valid") }).Count
    $reviewCount = @($Results | Where-Object { $_.Status -in @("WhatIf","Skipped","Missing") }).Count
    $failedCount = @($Results | Where-Object { $_.Status -in @("Failed","Invalid") }).Count
    $assignedCount = @($Results | Where-Object { $_.Status -eq "Assigned" }).Count
    $inventoryCount = @($inventory).Count
    $ztTotal = @($ztChecks).Count
    $ztPass = @($ztChecks | Where-Object { $_.Result -eq "Pass" }).Count
    $ztReview = @($ztChecks | Where-Object { $_.Result -ne "Pass" }).Count

    if ($ztTotal -gt 0) {
        $ztScore = [math]::Round(($ztPass / $ztTotal) * 100)
    }
    else {
        $ztScore = 0
    }

    if ($failedCount -gt 0) {
        $overallClass = "bad"
        $overallLabel = "Action Required"
    }
    elseif ($reviewCount -gt 0 -or $ztReview -gt 0) {
        $overallClass = "warn"
        $overallLabel = "Review"
    }
    else {
        $overallClass = "good"
        $overallLabel = "Ready"
    }

    function Get-MDEReportPillClass {
        param([string]$Status)
        switch ($Status) {
            "Success"  { return "good" }
            "Assigned" { return "good" }
            "Valid"    { return "good" }
            "Pass"     { return "good" }
            "WhatIf"   { return "warn" }
            "Skipped"  { return "warn" }
            "Missing"  { return "warn" }
            "Review"   { return "warn" }
            "Failed"   { return "bad" }
            "Invalid"  { return "bad" }
            default     { return "neutral" }
        }
    }

    $bladeData = @{}
    $bladeIndex = 0

    $deploymentRows = foreach ($r in $Results) {
        $bladeIndex++
        $bladeKey = "result_$bladeIndex"
        $pillClass = Get-MDEReportPillClass -Status $r.Status
        $safeTime = ConvertTo-HtmlEncoded $r.Time
        $safeName = ConvertTo-HtmlEncoded $r.Name
        $safeStatus = ConvertTo-HtmlEncoded $r.Status
        $safeDetails = ConvertTo-HtmlEncoded $r.Details

        $bladeHtml = @"
<div class='blade-kv'><span>Time</span><strong>$safeTime</strong></div>
<div class='blade-kv'><span>Name</span><strong>$safeName</strong></div>
<div class='blade-kv'><span>Status</span><strong>$safeStatus</strong></div>
<div class='blade-block'><span>Details</span><pre>$safeDetails</pre></div>
"@
        $bladeData[$bladeKey] = @{ title = "Deployment Result"; html = $bladeHtml }

        "<tr><td>$safeTime</td><td>$safeName</td><td><span class='pill $pillClass'>$safeStatus</span></td><td>$safeDetails</td><td><button class='blade-btn' data-blade='$bladeKey'>Details</button></td></tr>"
    }

    $ztRows = foreach ($z in $ztChecks) {
        $bladeIndex++
        $bladeKey = "zt_$bladeIndex"
        $pillClass = Get-MDEReportPillClass -Status $z.Result
        $checked = if ($z.Result -eq "Pass") { "checked" } else { "" }
        $safePolicy = ConvertTo-HtmlEncoded $z.Policy
        $safeControl = ConvertTo-HtmlEncoded $z.Control
        $safeResult = ConvertTo-HtmlEncoded $z.Result
        $safeFound = ConvertTo-HtmlEncoded $z.Found
        $safeDetails = ConvertTo-HtmlEncoded $z.Details

        $bladeHtml = @"
<div class='blade-kv'><span>Policy</span><strong>$safePolicy</strong></div>
<div class='blade-kv'><span>Control</span><strong>$safeControl</strong></div>
<div class='blade-kv'><span>Result</span><strong>$safeResult</strong></div>
<div class='blade-kv'><span>Found</span><strong>$safeFound</strong></div>
<div class='blade-block'><span>Details</span><pre>$safeDetails</pre></div>
"@
        $bladeData[$bladeKey] = @{ title = "Zero Trust Check"; html = $bladeHtml }

        "<tr><td><input type='checkbox' disabled $checked></td><td>$safePolicy</td><td>$safeControl</td><td><span class='pill $pillClass'>$safeResult</span></td><td>$safeFound</td><td><button class='blade-btn' data-blade='$bladeKey'>Review</button></td></tr>"
    }

    $inventoryRows = foreach ($i in $inventory) {
        $safePolicy = ConvertTo-HtmlEncoded $i.Policy
        $safeSettingId = ConvertTo-HtmlEncoded $i.SettingId
        $safeType = ConvertTo-HtmlEncoded $i.Type
        $safeValue = ConvertTo-HtmlEncoded $i.Value
        "<tr><td>$safePolicy</td><td><code>$safeSettingId</code></td><td>$safeType</td><td><code>$safeValue</code></td></tr>"
    }

    $policyCards = foreach ($group in ($inventory | Group-Object Policy | Sort-Object Name)) {
        $bladeIndex++
        $bladeKey = "policy_$bladeIndex"
        $safePolicyName = ConvertTo-HtmlEncoded $group.Name
        $settingCount = @($group.Group).Count

        $settingsRows = foreach ($setting in $group.Group) {
            $sid = ConvertTo-HtmlEncoded $setting.SettingId
            $stype = ConvertTo-HtmlEncoded $setting.Type
            $svalue = ConvertTo-HtmlEncoded $setting.Value
            "<tr><td><code>$sid</code></td><td>$stype</td><td><code>$svalue</code></td></tr>"
        }

        $bladeHtml = @"
<div class='blade-kv'><span>Policy</span><strong>$safePolicyName</strong></div>
<div class='blade-kv'><span>Total Settings</span><strong>$settingCount</strong></div>
<table class='blade-table'><thead><tr><th>Setting ID</th><th>Type</th><th>Value</th></tr></thead><tbody>$($settingsRows -join "`n")</tbody></table>
"@
        $bladeData[$bladeKey] = @{ title = "Policy Settings Inventory"; html = $bladeHtml }

        "<div class='mini-card'><div><span>Policy</span><strong>$safePolicyName</strong></div><div class='mini-value'>$settingCount settings</div><button class='blade-btn' data-blade='$bladeKey'>View Settings</button></div>"
    }

    $failedRows = foreach ($r in ($Results | Where-Object { $_.Status -in @("Failed","Invalid") })) {
        "<tr><td>$(ConvertTo-HtmlEncoded $r.Time)</td><td>$(ConvertTo-HtmlEncoded $r.Name)</td><td><span class='pill bad'>$(ConvertTo-HtmlEncoded $r.Status)</span></td><td>$(ConvertTo-HtmlEncoded $r.Details)</td></tr>"
    }
    if (-not $failedRows -or @($failedRows).Count -eq 0) {
        $failedRows = @("<tr><td colspan='4'>No failed deployment results were recorded in this report.</td></tr>")
    }

    $opsCards = @(
        "<div class='note'><strong>Scope</strong><br>Defender for Endpoint Settings Catalog deployment module.</div>",
        "<div class='note'><strong>Preserved Logic</strong><br>Graph authentication, deployment execution, JSON validation, assignment, export, backup, and report actions remain tied to the original tool functions.</div>",
        "<div class='note'><strong>Review Guidance</strong><br>Investigate failed or invalid results before broad assignment. WhatIf and skipped results should be reviewed before production rollout.</div>",
        "<div class='note'><strong>Shadow Suite Standard</strong><br>Dark dashboard presentation aligned with Shadow Trace Ops and Shadow Verify reporting style.</div>"
    )

    $bladeJson = ($bladeData | ConvertTo-Json -Depth 20 -Compress).Replace('</script>','<\/script>')

    $html = @"
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Shadow Deploy | Defender for Endpoint</title>
<style>
:root {
  --bg:#090a0f;
  --surface:#12141d;
  --surface2:#191c27;
  --border:#3a4052;
  --text:#f5f7fa;
  --muted:#a8b0be;
  --accent:#7c3aed;
  --accent2:#2563eb;
  --good:#15803d;
  --warn:#b45309;
  --bad:#b91c1c;
  --neutral:#475569;
}
* { box-sizing:border-box; }
html { scroll-behavior:smooth; }
body {
  margin:0;
  background:radial-gradient(circle at top left, rgba(124,58,237,.25), transparent 34%), radial-gradient(circle at bottom right, rgba(37,99,235,.16), transparent 30%), var(--bg);
  color:var(--text);
  font-family:"Segoe UI", Arial, sans-serif;
}
.layout { display:grid; grid-template-columns:280px 1fr; min-height:100vh; }
aside {
  border-right:1px solid var(--border);
  background:rgba(18,20,29,.96);
  padding:26px 20px;
  position:sticky;
  top:0;
  height:100vh;
}
.brand { color:var(--muted); font-size:12px; letter-spacing:.18em; font-weight:800; text-transform:uppercase; }
h1 { margin:8px 0 8px; font-size:30px; line-height:1.1; }
.subtitle { color:var(--muted); font-size:13px; line-height:1.5; }
.nav { margin-top:28px; display:grid; gap:10px; }
.nav a { color:var(--text); text-decoration:none; border:1px solid var(--border); background:var(--surface2); border-radius:14px; padding:11px 12px; font-size:13px; transition:.16s ease; }
.nav a:hover { border-color:rgba(124,58,237,.75); transform:translateX(2px); }
main { padding:30px; }
.hero {
  border:1px solid var(--border);
  border-radius:24px;
  background:linear-gradient(135deg, rgba(124,58,237,.26), rgba(37,99,235,.10)), var(--surface);
  padding:26px;
  box-shadow:0 22px 60px rgba(0,0,0,.32);
}
.hero-top { display:flex; align-items:flex-start; justify-content:space-between; gap:20px; }
.badge { display:inline-flex; align-items:center; border:1px solid var(--border); border-radius:999px; padding:8px 12px; color:var(--muted); background:rgba(9,10,15,.48); font-size:12px; font-weight:800; }
.state.good { color:#bbf7d0; border-color:rgba(21,128,61,.65); }
.state.warn { color:#fed7aa; border-color:rgba(180,83,9,.65); }
.state.bad { color:#fecaca; border-color:rgba(185,28,28,.65); }
.cards { display:grid; grid-template-columns:repeat(6,minmax(0,1fr)); gap:14px; margin:22px 0 0; }
.card { border:1px solid var(--border); border-radius:20px; background:rgba(18,20,29,.86); padding:18px; }
.card .label { color:var(--muted); font-size:11px; text-transform:uppercase; letter-spacing:.08em; }
.card .value { font-size:28px; margin-top:8px; font-weight:800; }
section { margin-top:22px; border:1px solid var(--border); border-radius:22px; background:rgba(18,20,29,.88); padding:22px; box-shadow:0 14px 40px rgba(0,0,0,.18); }
.section-head { display:flex; align-items:center; justify-content:space-between; gap:14px; margin-bottom:14px; }
h2 { margin:0; font-size:18px; }
table { width:100%; border-collapse:collapse; overflow:hidden; border-radius:14px; }
th,td { text-align:left; padding:12px 14px; border-bottom:1px solid rgba(58,64,82,.7); vertical-align:top; font-size:13px; }
th { color:var(--muted); background:rgba(25,28,39,.92); font-size:12px; letter-spacing:.07em; text-transform:uppercase; }
tr:hover td { background:rgba(124,58,237,.08); }
code { color:#bfdbfe; word-break:break-all; }
.pill { display:inline-flex; min-width:78px; justify-content:center; border-radius:999px; padding:5px 9px; font-weight:800; font-size:12px; border:1px solid transparent; }
.pill.good { background:rgba(21,128,61,.22); color:#bbf7d0; border-color:rgba(21,128,61,.52); }
.pill.warn { background:rgba(180,83,9,.22); color:#fed7aa; border-color:rgba(180,83,9,.52); }
.pill.bad { background:rgba(185,28,28,.22); color:#fecaca; border-color:rgba(185,28,28,.52); }
.pill.neutral { background:rgba(71,85,105,.22); color:#e2e8f0; border-color:rgba(71,85,105,.52); }
.note-grid { display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); gap:14px; }
.note { border:1px solid var(--border); background:var(--surface2); border-radius:16px; padding:15px; color:var(--muted); line-height:1.5; }
.policy-grid { display:grid; grid-template-columns:repeat(3,minmax(0,1fr)); gap:14px; }
.mini-card { border:1px solid var(--border); background:var(--surface2); border-radius:16px; padding:16px; display:grid; gap:10px; }
.mini-card span { color:var(--muted); font-size:11px; text-transform:uppercase; letter-spacing:.08em; }
.mini-card strong { display:block; margin-top:4px; }
.mini-value { color:#bfdbfe; font-weight:700; }
.blade-btn { cursor:pointer; border:1px solid rgba(124,58,237,.72); background:rgba(124,58,237,.18); color:#ddd6fe; border-radius:999px; padding:6px 10px; font-weight:800; font-size:12px; }
.blade-btn:hover { background:rgba(124,58,237,.32); }
.drawer-overlay { position:fixed; inset:0; background:rgba(0,0,0,.58); opacity:0; pointer-events:none; transition:.18s ease; z-index:50; }
.drawer-overlay.open { opacity:1; pointer-events:auto; }
.drawer { position:fixed; top:0; right:-560px; width:min(560px, 94vw); height:100vh; background:#0f111a; border-left:1px solid var(--border); box-shadow:-20px 0 60px rgba(0,0,0,.45); transition:.22s ease; z-index:60; padding:22px; overflow:auto; }
.drawer.open { right:0; }
.drawer-head { display:flex; align-items:flex-start; justify-content:space-between; gap:14px; margin-bottom:18px; }
.drawer h2 { font-size:22px; }
.close-btn { border:1px solid var(--border); background:var(--surface2); color:var(--text); border-radius:12px; padding:8px 10px; cursor:pointer; }
.blade-kv { border:1px solid var(--border); border-radius:14px; background:var(--surface2); padding:12px; margin-bottom:10px; }
.blade-kv span, .blade-block span { display:block; color:var(--muted); font-size:11px; text-transform:uppercase; letter-spacing:.08em; margin-bottom:6px; }
.blade-kv strong { color:var(--text); }
.blade-block { border:1px solid var(--border); border-radius:14px; background:var(--surface2); padding:12px; margin-top:10px; }
pre { white-space:pre-wrap; word-break:break-word; color:#bfdbfe; margin:0; font-family:Consolas, monospace; }
.blade-table { margin-top:12px; }
.footer { color:var(--muted); margin-top:22px; font-size:12px; }
@media(max-width:1180px){ .cards{grid-template-columns:repeat(3,1fr);} .policy-grid{grid-template-columns:repeat(2,1fr);} }
@media(max-width:960px){ .layout{grid-template-columns:1fr;} aside{position:relative;height:auto;} .cards{grid-template-columns:repeat(2,1fr);} .note-grid{grid-template-columns:1fr;} .policy-grid{grid-template-columns:1fr;} }
</style>
</head>
<body>
<div class="layout">
<aside>
  <div class="brand">Shadow Suite</div>
  <h1>Shadow Deploy</h1>
  <div class="subtitle">Defender for Endpoint deployment dashboard. Modern report presentation while preserving the original deployment engine.</div>
  <div class="nav">
    <a href="#summary">Executive Summary</a>
    <a href="#results">Deployment Results</a>
    <a href="#zt">Zero Trust Alignment</a>
    <a href="#policies">Policy Blades</a>
    <a href="#inventory">Settings Inventory</a>
    <a href="#failures">Failures / Review</a>
    <a href="#ops">Operational Notes</a>
  </div>
</aside>
<main>
  <div class="hero" id="summary">
    <div class="hero-top">
      <div>
        <div class="brand">Defender for Endpoint Deployment Module</div>
        <h1>Deployment Execution Report</h1>
        <div class="subtitle">Generated: $generated</div>
      </div>
      <span class="badge state $overallClass">$overallLabel</span>
    </div>
    <div class="cards">
      <div class="card"><div class="label">Total Results</div><div class="value">$totalResults</div></div>
      <div class="card"><div class="label">Successful</div><div class="value">$successCount</div></div>
      <div class="card"><div class="label">Review</div><div class="value">$reviewCount</div></div>
      <div class="card"><div class="label">Failed</div><div class="value">$failedCount</div></div>
      <div class="card"><div class="label">Assigned</div><div class="value">$assignedCount</div></div>
      <div class="card"><div class="label">Zero Trust Score</div><div class="value">$ztScore%</div></div>
    </div>
  </div>

  <section id="results">
    <div class="section-head"><h2>Deployment Results</h2><span class="badge">Execution History</span></div>
    <table>
      <thead><tr><th>Time</th><th>Name</th><th>Status</th><th>Details</th><th>Blade</th></tr></thead>
      <tbody>
      $($deploymentRows -join "`n")
      </tbody>
    </table>
  </section>

  <section id="zt">
    <div class="section-head"><h2>Zero Trust Alignment Checklist</h2><span class="badge">$ztPass / $ztTotal passed</span></div>
    <table>
      <thead><tr><th>Aligned</th><th>Policy</th><th>Control</th><th>Result</th><th>Found</th><th>Blade</th></tr></thead>
      <tbody>
      $($ztRows -join "`n")
      </tbody>
    </table>
  </section>

  <section id="policies">
    <div class="section-head"><h2>Policy Settings Blades</h2><span class="badge">$inventoryCount settings inventoried</span></div>
    <div class="policy-grid">
      $($policyCards -join "`n")
    </div>
  </section>

  <section id="inventory">
    <div class="section-head"><h2>Settings Inventory</h2><span class="badge">Raw Setting Detail</span></div>
    <table>
      <thead><tr><th>Policy</th><th>Setting ID</th><th>Type</th><th>Value</th></tr></thead>
      <tbody>
      $($inventoryRows -join "`n")
      </tbody>
    </table>
  </section>

  <section id="failures">
    <div class="section-head"><h2>Failures / Manual Review</h2><span class="badge state $overallClass">$overallLabel</span></div>
    <table>
      <thead><tr><th>Time</th><th>Name</th><th>Status</th><th>Details</th></tr></thead>
      <tbody>
      $($failedRows -join "`n")
      </tbody>
    </table>
  </section>

  <section id="ops">
    <div class="section-head"><h2>Operational Notes</h2><span class="badge">Guidance</span></div>
    <div class="note-grid">
      $($opsCards -join "`n")
    </div>
  </section>

  <div class="footer">Shadow Deploy | Defender for Endpoint Module | Generated locally by the deployment toolkit.</div>
</main>
</div>

<div class="drawer-overlay" id="drawerOverlay"></div>
<div class="drawer" id="drawer">
  <div class="drawer-head">
    <div>
      <div class="brand">Shadow Deploy Blade</div>
      <h2 id="drawerTitle">Details</h2>
    </div>
    <button class="close-btn" id="drawerClose">Close</button>
  </div>
  <div id="drawerBody"></div>
</div>

<script>
const bladeData = $bladeJson;
const drawer = document.getElementById('drawer');
const overlay = document.getElementById('drawerOverlay');
const drawerTitle = document.getElementById('drawerTitle');
const drawerBody = document.getElementById('drawerBody');
function openBlade(key) {
  const data = bladeData[key];
  if (!data) { return; }
  drawerTitle.textContent = data.title || 'Details';
  drawerBody.innerHTML = data.html || '';
  drawer.classList.add('open');
  overlay.classList.add('open');
}
function closeBlade() {
  drawer.classList.remove('open');
  overlay.classList.remove('open');
}
document.querySelectorAll('.blade-btn').forEach(function(btn) {
  btn.addEventListener('click', function() { openBlade(btn.getAttribute('data-blade')); });
});
document.getElementById('drawerClose').addEventListener('click', closeBlade);
overlay.addEventListener('click', closeBlade);
document.addEventListener('keydown', function(event) { if (event.key === 'Escape') { closeBlade(); } });
</script>
</body>
</html>
"@

    $html | Set-Content -LiteralPath $reportPath -Encoding UTF8
    return $reportPath
}

function Backup-MDEAllPolicies {
    Assert-Mg

    try {
        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
        $backupRoot = Get-MDEBackupFolderRoot
        $backupFolder = Join-Path $backupRoot $timestamp

        if (-not (Test-Path -LiteralPath $backupFolder)) {
            New-Item -ItemType Directory -Path $backupFolder -Force | Out-Null
        }

        $summaryPath = Join-Path $backupFolder "backup-summary.txt"
        Set-Content -LiteralPath $summaryPath -Value "MDE Backup Summary - $timestamp" -Encoding UTF8
        Add-Content -LiteralPath $summaryPath -Value "Backup Folder: $backupFolder"
        Add-Content -LiteralPath $summaryPath -Value ""

        foreach ($policy in Get-MDEJsonPolicyCatalog) {
            $safeName = $policy.Name.ToLower() -replace '\s+','-' -replace '[\\/:*?""<>|]',''
            $outputPath = Join-Path $backupFolder "$safeName.json"

            $candidateNames = @()
            $candidateNames += Get-MDEPolicyName $policy.Name
            $candidateNames += $policy.Name

            try {
                $json = Get-MDEJsonBody -Path $policy.JsonPath

                if ($json.PSObject.Properties.Name -contains "name") {
                    if (-not [string]::IsNullOrWhiteSpace($json.name)) {
                        if ($json.name -ne "__POLICY_NAME__") {
                            $candidateNames += $json.name
                        }
                    }
                }
            }
            catch { }

            $candidateNames = $candidateNames |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                Select-Object -Unique

            $backedUp = $false
            $lastError = ""

            foreach ($candidate in $candidateNames) {
                try {
                    $found = Find-MDEConfigPolicyByName -PolicyName $candidate

                    if ($found) {
                        $result = Export-MDEConfigPolicyJson `
                            -PolicyName $candidate `
                            -OutputPath $outputPath

                        Add-Result $candidate $result.Status "Backed up to $outputPath"
                        Add-Content -LiteralPath $summaryPath -Value "SUCCESS: $candidate -> $outputPath"

                        $backedUp = $true
                        break
                    }
                }
                catch {
                    $lastError = $_.Exception.Message
                }
            }

            if (-not $backedUp) {
                $tried = $candidateNames -join " | "
                $message = "No matching Intune policy found. Tried: $tried"

                if (-not [string]::IsNullOrWhiteSpace($lastError)) {
                    $message = "$message. Last error: $lastError"
                }

                Add-Result $policy.Name "Skipped" $message
                Add-Content -LiteralPath $summaryPath -Value "SKIPPED: $($policy.Name) - $message"
            }
        }

        Add-Content -LiteralPath $summaryPath -Value ""
        Add-Content -LiteralPath $summaryPath -Value "Completed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

        Add-Log "Backup complete: $backupFolder"
        Start-Process $backupFolder
    }
    catch {
        Add-Result "Backup All" "Failed" $_.Exception.Message
    }
}


# =============================
# Shadow Deploy UI - Shadow Suite Style
# UI/branding updated only. Backend deployment, Graph, export, backup, validation, and report functions above are preserved.
# Logo expected in the same folder as this script: shadowdeploy.png
# =============================

$ShadowTheme = [ordered]@{
    Back        = [System.Drawing.Color]::FromArgb(5, 7, 12)
    Surface     = [System.Drawing.Color]::FromArgb(10, 14, 23)
    SurfaceAlt  = [System.Drawing.Color]::FromArgb(16, 21, 32)
    SurfaceSoft = [System.Drawing.Color]::FromArgb(24, 30, 44)
    Border      = [System.Drawing.Color]::FromArgb(68, 74, 88)
    Purple      = [System.Drawing.Color]::FromArgb(130, 45, 230)
    PurpleSoft  = [System.Drawing.Color]::FromArgb(78, 18, 150)
    Text        = [System.Drawing.Color]::FromArgb(245, 247, 250)
    Muted       = [System.Drawing.Color]::FromArgb(190, 195, 205)
    Blue        = [System.Drawing.Color]::FromArgb(24, 48, 86)
    Green       = [System.Drawing.Color]::FromArgb(16, 128, 64)
    Orange      = [System.Drawing.Color]::FromArgb(198, 76, 0)
    Red         = [System.Drawing.Color]::FromArgb(185, 28, 28)
    Console     = [System.Drawing.Color]::FromArgb(1, 3, 7)
}

function New-ShadowFont {
    param(
        [float]$Size = 9,
        [string]$Weight = "Regular"
    )
    $style = [System.Drawing.FontStyle]::Regular
    if ($Weight -eq "Bold") { $style = [System.Drawing.FontStyle]::Bold }
    return New-Object System.Drawing.Font("Segoe UI", $Size, $style)
}

function New-ShadowLabel {
    param(
        [string]$Text,
        [int]$X,
        [int]$Y,
        [int]$W,
        [int]$H = 22,
        [float]$Size = 9,
        [switch]$Bold,
        [switch]$Muted,
        [System.Drawing.Color]$BackColor = $ShadowTheme.Back
    )

    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Location = New-Object System.Drawing.Point($X, $Y)
    $label.Size = New-Object System.Drawing.Size($W, $H)
    $label.Font = New-ShadowFont -Size $Size -Weight $(if ($Bold) { "Bold" } else { "Regular" })
    $label.ForeColor = $(if ($Muted) { $ShadowTheme.Muted } else { $ShadowTheme.Text })
    $label.BackColor = $BackColor
    return $label
}

function New-ShadowPanel {
    param(
        [int]$X,
        [int]$Y,
        [int]$W,
        [int]$H,
        [string]$Title = "",
        [string]$Icon = ""
    )

    $panel = New-Object System.Windows.Forms.Panel
    $panel.Location = New-Object System.Drawing.Point($X, $Y)
    $panel.Size = New-Object System.Drawing.Size($W, $H)
    $panel.BackColor = $ShadowTheme.Surface
    $panel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle

    if (-not [string]::IsNullOrWhiteSpace($Title)) {
        $label = New-Object System.Windows.Forms.Label
        $label.Text = if ($Icon) { "$Icon  $Title" } else { $Title }
        $label.Location = New-Object System.Drawing.Point(16, 14)
        $label.Size = New-Object System.Drawing.Size(($W - 32), 26)
        $label.Font = New-ShadowFont -Size 11 -Weight Bold
        $label.ForeColor = $ShadowTheme.Text
        $label.BackColor = $ShadowTheme.Surface
        $panel.Controls.Add($label)
    }

    return $panel
}

function New-ShadowButton {
    param(
        [string]$Text,
        [int]$W = 126,
        [int]$H = 36,
        [ValidateSet("Primary","Secondary","Success","Warning","Danger")]
        [string]$Style = "Secondary"
    )

    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Size = New-Object System.Drawing.Size($W, $H)
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.Font = New-ShadowFont -Size 8.5 -Weight Bold
    $button.ForeColor = $ShadowTheme.Text
    $button.Cursor = [System.Windows.Forms.Cursors]::Hand
    $button.FlatAppearance.BorderSize = 1
    $button.FlatAppearance.BorderColor = $ShadowTheme.Border

    switch ($Style) {
        "Primary"   { $button.BackColor = $ShadowTheme.Purple }
        "Success"   { $button.BackColor = $ShadowTheme.Green }
        "Warning"   { $button.BackColor = $ShadowTheme.Orange }
        "Danger"    { $button.BackColor = $ShadowTheme.Red }
        default     { $button.BackColor = $ShadowTheme.SurfaceSoft }
    }

    return $button
}

function New-ShadowStatusPill {
    param(
        [string]$Text,
        [int]$X,
        [int]$Y,
        [int]$W,
        [ValidateSet("Neutral","Good","Warning","Bad")]
        [string]$State = "Neutral"
    )

    $pill = New-Object System.Windows.Forms.Label
    $pill.Text = "  $Text"
    $pill.Location = New-Object System.Drawing.Point($X, $Y)
    $pill.Size = New-Object System.Drawing.Size($W, 34)
    $pill.Font = New-ShadowFont -Size 9 -Weight Bold
    $pill.ForeColor = $ShadowTheme.Text
    $pill.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $pill.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle

    switch ($State) {
        "Good"    { $pill.BackColor = $ShadowTheme.Green }
        "Warning" { $pill.BackColor = [System.Drawing.Color]::FromArgb(132, 44, 8) }
        "Bad"     { $pill.BackColor = $ShadowTheme.Red }
        default   { $pill.BackColor = $ShadowTheme.SurfaceSoft }
    }

    return $pill
}

function Set-ShadowGridStyle {
    param([System.Windows.Forms.DataGridView]$Grid)

    $Grid.BackgroundColor = $ShadowTheme.Surface
    $Grid.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $Grid.GridColor = [System.Drawing.Color]::FromArgb(36, 43, 59)
    $Grid.DefaultCellStyle.BackColor = $ShadowTheme.SurfaceAlt
    $Grid.DefaultCellStyle.ForeColor = $ShadowTheme.Text
    $Grid.DefaultCellStyle.SelectionBackColor = $ShadowTheme.PurpleSoft
    $Grid.DefaultCellStyle.SelectionForeColor = $ShadowTheme.Text
    $Grid.DefaultCellStyle.Font = New-ShadowFont -Size 9
    $Grid.ColumnHeadersDefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(8, 10, 16)
    $Grid.ColumnHeadersDefaultCellStyle.ForeColor = $ShadowTheme.Text
    $Grid.ColumnHeadersDefaultCellStyle.Font = New-ShadowFont -Size 9 -Weight Bold
    $Grid.EnableHeadersVisualStyles = $false
    $Grid.RowHeadersVisible = $false
    $Grid.AllowUserToAddRows = $false
    $Grid.SelectionMode = "FullRowSelect"
    $Grid.MultiSelect = $true
    $Grid.AutoSizeColumnsMode = "Fill"
}

function New-ShadowActionItem {
    param(
        [System.Windows.Forms.FlowLayoutPanel]$Parent,
        [string]$ButtonText,
        [string]$Description,
        [ValidateSet("Primary","Secondary","Success","Warning","Danger")]
        [string]$Style = "Secondary"
    )

    $container = New-Object System.Windows.Forms.Panel
    $container.Size = New-Object System.Drawing.Size(138, 94)
    $container.BackColor = $ShadowTheme.Surface
    $container.Margin = New-Object System.Windows.Forms.Padding(6, 4, 6, 4)

    $button = New-ShadowButton -Text $ButtonText -W 126 -H 36 -Style $Style
    $button.Location = New-Object System.Drawing.Point(6, 0)
    $container.Controls.Add($button)

    $desc = New-Object System.Windows.Forms.Label
    $desc.Text = $Description
    $desc.Location = New-Object System.Drawing.Point(0, 44)
    $desc.Size = New-Object System.Drawing.Size(138, 46)
    $desc.TextAlign = [System.Drawing.ContentAlignment]::TopCenter
    $desc.Font = New-ShadowFont -Size 7.5
    $desc.ForeColor = $ShadowTheme.Muted
    $desc.BackColor = $ShadowTheme.Surface
    $container.Controls.Add($desc)

    $Parent.Controls.Add($container)
    return $button
}


function Update-ShadowMetrics {
    try {
        if ($lblRunStats) {
            $total = @($script:LastResults).Count
            $success = @($script:LastResults | Where-Object { $_.Status -in @("Success","Assigned","Valid") }).Count
            $review = @($script:LastResults | Where-Object { $_.Status -in @("Skipped","Missing","WhatIf") }).Count
            $failed = @($script:LastResults | Where-Object { $_.Status -in @("Failed","Invalid") }).Count
            $lblRunStats.Text = "Results: $total | Success: $success | Review: $review | Failed: $failed"
        }
    }
    catch { }
}

function Set-ShadowGraphIdentity {
    try {
        $ctx = Get-MgContext
        if ($ctx) {
            if ($lblSignedIn) { $lblSignedIn.Text = "Signed in: $($ctx.Account)" }
            if ($lblTenant) { $lblTenant.Text = "Tenant ID: $($ctx.TenantId)" }
            if ($lblLastAction) { $lblLastAction.Text = "Last action: Graph connected $(Get-Date -Format 'HH:mm:ss')" }

            try {
                $org = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/organization" -OutputType PSObject
                if ($org.value -and $org.value.Count -gt 0 -and $org.value[0].displayName) {
                    if ($lblTenant) { $lblTenant.Text = "Tenant: $($org.value[0].displayName)" }
                }
            }
            catch { }
        }
    }
    catch { }
}

function Add-Log {
    param([string]$Message)

    if ($txtLog) {
        $txtLog.AppendText("[$(Get-Date -Format 'HH:mm:ss')] $Message`r`n")
        $txtLog.SelectionStart = $txtLog.Text.Length
        $txtLog.ScrollToCaret()
    }

    Write-MDELogFile -Message $Message
}

function Add-Result {
    param([string]$Name,[string]$Status,[string]$Details)

    $resultObject = New-MDEPolicyResult -Name $Name -Status $Status -Details $Details
    $script:LastResults += $resultObject

    $row = $gridResults.Rows.Add($Name,$Status,$Details)

    switch ($Status) {
        "Success"  { $gridResults.Rows[$row].DefaultCellStyle.BackColor = $ShadowTheme.Green }
        "Assigned" { $gridResults.Rows[$row].DefaultCellStyle.BackColor = $ShadowTheme.Green }
        "Valid"    { $gridResults.Rows[$row].DefaultCellStyle.BackColor = $ShadowTheme.Green }
        "WhatIf"   { $gridResults.Rows[$row].DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(30,64,175) }
        "Skipped"  { $gridResults.Rows[$row].DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(113,63,18) }
        "Missing"  { $gridResults.Rows[$row].DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(113,63,18) }
        "Failed"   { $gridResults.Rows[$row].DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(127,29,29) }
        "Invalid"  { $gridResults.Rows[$row].DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(127,29,29) }
        default     { $gridResults.Rows[$row].DefaultCellStyle.BackColor = $ShadowTheme.SurfaceAlt }
    }

    $gridResults.Rows[$row].DefaultCellStyle.ForeColor = $ShadowTheme.Text
    Add-Log "${Name}: $Status - $Details"
    Update-ShadowMetrics
    if ($lblLastAction) { $lblLastAction.Text = "Last: $Status - $Name" }
}

# =============================
# Main Form
# =============================

$form = New-Object System.Windows.Forms.Form
$form.Text = "Shadow Deploy | Defender for Endpoint"
$form.Size = New-Object System.Drawing.Size(1450, 1085)
$form.MinimumSize = New-Object System.Drawing.Size(1450, 1085)
$form.StartPosition = "CenterScreen"
$form.BackColor = $ShadowTheme.Back
$form.ForeColor = $ShadowTheme.Text
$form.Font = New-ShadowFont -Size 9

# Header logo
$logoPath = Join-Path $PSScriptRoot "shadowdeploy.png"
if (Test-Path -LiteralPath $logoPath) {
    try {
        $picLogo = New-Object System.Windows.Forms.PictureBox
        $picLogo.Location = New-Object System.Drawing.Point(28, 34)
        $picLogo.Size = New-Object System.Drawing.Size(590, 170)
        $picLogo.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
        $picLogo.BackColor = $ShadowTheme.Back
        $picLogo.Image = [System.Drawing.Image]::FromFile($logoPath)
        $form.Controls.Add($picLogo)
    }
    catch {
        $form.Controls.Add((New-ShadowLabel -Text "SHADOW DEPLOY" -X 28 -Y 60 -W 560 -H 56 -Size 26 -Bold))
    }
}
else {
    $form.Controls.Add((New-ShadowLabel -Text "SHADOW DEPLOY" -X 28 -Y 60 -W 560 -H 56 -Size 26 -Bold))
}

$form.Controls.Add((New-ShadowLabel -Text "Defender for Endpoint`r`nDeployment Module" -X 620 -Y 82 -W 330 -H 64 -Size 17 -Bold))
$form.Controls.Add((New-ShadowLabel -Text "JSON-driven Settings Catalog deployment,`r`nvalidation, export, backup, assignment, and reporting." -X 622 -Y 150 -W 360 -H 46 -Size 9 -Muted))

$modulePill = New-ShadowStatusPill -Text "MDE MODULE" -X 1020 -Y 64 -W 165 -State Neutral
$form.Controls.Add($modulePill)
$graphPill = New-ShadowStatusPill -Text "GRAPH: NOT CONNECTED" -X 1200 -Y 64 -W 195 -State Warning
$form.Controls.Add($graphPill)

# Top-right operational summary card
$summaryPanel = New-Object System.Windows.Forms.Panel
$summaryPanel.Location = New-Object System.Drawing.Point(1010, 98)
$summaryPanel.Size = New-Object System.Drawing.Size(376, 108)
$summaryPanel.BackColor = $ShadowTheme.Back
$summaryPanel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$form.Controls.Add($summaryPanel)

$lblSummaryTitle = New-Object System.Windows.Forms.Label
$lblSummaryTitle.Text = "SESSION SUMMARY"
$lblSummaryTitle.Location = New-Object System.Drawing.Point(12, 8)
$lblSummaryTitle.Size = New-Object System.Drawing.Size(340, 18)
$lblSummaryTitle.Font = New-ShadowFont -Size 8 -Weight Bold
$lblSummaryTitle.ForeColor = $ShadowTheme.Purple
$lblSummaryTitle.BackColor = $ShadowTheme.Back
$summaryPanel.Controls.Add($lblSummaryTitle)

$lblSignedIn = New-ShadowLabel -Text "Signed in: Not connected" -X 12 -Y 30 -W 350 -H 18 -Size 8 -Muted
$summaryPanel.Controls.Add($lblSignedIn)
$lblTenant = New-ShadowLabel -Text "Tenant: Not connected" -X 12 -Y 48 -W 350 -H 18 -Size 8 -Muted
$summaryPanel.Controls.Add($lblTenant)
$lblPolicyCount = New-ShadowLabel -Text "Policies: 0" -X 12 -Y 66 -W 350 -H 18 -Size 8 -Muted
$summaryPanel.Controls.Add($lblPolicyCount)
$lblRunStats = New-ShadowLabel -Text "Results: 0 | Success: 0 | Review: 0 | Failed: 0" -X 12 -Y 84 -W 350 -H 18 -Size 8 -Muted
$summaryPanel.Controls.Add($lblRunStats)
$lblLastAction = New-ShadowLabel -Text "Last: Ready" -X 662 -Y 196 -W 330 -H 20 -Size 8 -Muted
$form.Controls.Add($lblLastAction)

# Deployment options
$optionsPanel = New-ShadowPanel -X 26 -Y 220 -W 1390 -H 86 -Title "Deployment Options"
$form.Controls.Add($optionsPanel)

$chkWhatIf = New-Object System.Windows.Forms.CheckBox
$chkWhatIf.Text = "Validate only / WhatIf"
$chkWhatIf.Location = New-Object System.Drawing.Point(22, 44)
$chkWhatIf.Size = New-Object System.Drawing.Size(190, 24)
$chkWhatIf.ForeColor = $ShadowTheme.Text
$chkWhatIf.BackColor = $ShadowTheme.Surface
$optionsPanel.Controls.Add($chkWhatIf)

$chkAssignAfterDeploy = New-Object System.Windows.Forms.CheckBox
$chkAssignAfterDeploy.Text = "Assign after deploy"
$chkAssignAfterDeploy.Location = New-Object System.Drawing.Point(240, 44)
$chkAssignAfterDeploy.Size = New-Object System.Drawing.Size(190, 24)
$chkAssignAfterDeploy.ForeColor = $ShadowTheme.Text
$chkAssignAfterDeploy.BackColor = $ShadowTheme.Surface
$optionsPanel.Controls.Add($chkAssignAfterDeploy)

$targetLabel = New-Object System.Windows.Forms.Label
$targetLabel.Text = "Target group"
$targetLabel.Location = New-Object System.Drawing.Point(500, 45)
$targetLabel.Size = New-Object System.Drawing.Size(90, 22)
$targetLabel.ForeColor = $ShadowTheme.Text
$targetLabel.BackColor = $ShadowTheme.Surface
$optionsPanel.Controls.Add($targetLabel)

$txtGroupName = New-Object System.Windows.Forms.TextBox
$txtGroupName.Location = New-Object System.Drawing.Point(595, 42)
$txtGroupName.Size = New-Object System.Drawing.Size(340, 24)
$txtGroupName.BackColor = $ShadowTheme.SurfaceAlt
$txtGroupName.ForeColor = $ShadowTheme.Text
$txtGroupName.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$txtGroupName.Text = "MDE Pilot Devices"
$optionsPanel.Controls.Add($txtGroupName)

$btnInit = New-ShadowButton -Text "Connect Graph" -W 150 -H 44 -Style Primary
$btnInit.Location = New-Object System.Drawing.Point(995, 30)
$optionsPanel.Controls.Add($btnInit)

$btnDisconnect = New-ShadowButton -Text "Disconnect Graph" -W 190 -H 44 -Style Danger
$btnDisconnect.Location = New-Object System.Drawing.Point(1165, 30)
$optionsPanel.Controls.Add($btnDisconnect)

# Catalog / Results
$catalogPanel = New-ShadowPanel -X 26 -Y 322 -W 805 -H 350 -Title "Policy Catalog" -Icon "▣"
$form.Controls.Add($catalogPanel)

$gridPolicies = New-Object System.Windows.Forms.DataGridView
$gridPolicies.Location = New-Object System.Drawing.Point(16, 52)
$gridPolicies.Size = New-Object System.Drawing.Size(770, 280)
Set-ShadowGridStyle -Grid $gridPolicies
[void]$gridPolicies.Columns.Add("Name","Policy")
[void]$gridPolicies.Columns.Add("Category","Category")
[void]$gridPolicies.Columns.Add("JsonPath","JSON Path")
[void]$gridPolicies.Columns.Add("Exists","JSON Exists")
$catalogPanel.Controls.Add($gridPolicies)

$resultsPanel = New-ShadowPanel -X 848 -Y 322 -W 568 -H 350 -Title "Execution Results" -Icon "▣"
$form.Controls.Add($resultsPanel)

$gridResults = New-Object System.Windows.Forms.DataGridView
$gridResults.Location = New-Object System.Drawing.Point(16, 52)
$gridResults.Size = New-Object System.Drawing.Size(535, 280)
Set-ShadowGridStyle -Grid $gridResults
[void]$gridResults.Columns.Add("Name","Name")
[void]$gridResults.Columns.Add("Status","Status")
[void]$gridResults.Columns.Add("Details","Details")
$resultsPanel.Controls.Add($gridResults)

# Actions panel
$actionsPanel = New-ShadowPanel -X 26 -Y 690 -W 1390 -H 166 -Title "Actions" -Icon "⚡"
$actionsPanel.BackColor = $ShadowTheme.Surface
$form.Controls.Add($actionsPanel)

$buttonPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$buttonPanel.Location = New-Object System.Drawing.Point(14, 54)
$buttonPanel.Size = New-Object System.Drawing.Size(1360, 100)
$buttonPanel.BackColor = $ShadowTheme.Surface
$buttonPanel.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight
$buttonPanel.WrapContents = $false
$buttonPanel.AutoScroll = $false
$buttonPanel.Padding = New-Object System.Windows.Forms.Padding(0)
$actionsPanel.Controls.Add($buttonPanel)

$btnRefresh = New-ShadowActionItem -Parent $buttonPanel -ButtonText "⟳ Refresh JSON" -Description "Reload policy catalog`r`nfrom Config folder" -Style Secondary
$btnValidate = New-ShadowActionItem -Parent $buttonPanel -ButtonText "✓ Validate JSON" -Description "Validate all JSON files`r`nin the catalog" -Style Secondary
$btnDeploy = New-ShadowActionItem -Parent $buttonPanel -ButtonText "▷ Deploy Selected" -Description "Deploy selected policies`r`n(respecting options)" -Style Success
$btnReport = New-ShadowActionItem -Parent $buttonPanel -ButtonText "▤ Generate Report" -Description "Generate HTML report`r`nof last execution" -Style Primary
$btnBackupAll = New-ShadowActionItem -Parent $buttonPanel -ButtonText "▧ Backup All" -Description "Backup all existing MDE`r`nconfiguration policies" -Style Warning
$btnExport = New-ShadowActionItem -Parent $buttonPanel -ButtonText "⇧ Export Existing" -Description "Export all existing policies`r`nto JSON" -Style Secondary
$btnOpenConfig = New-ShadowActionItem -Parent $buttonPanel -ButtonText "▭ Open Config" -Description "Open Config folder`r`nin File Explorer" -Style Secondary
$btnOpenReports = New-ShadowActionItem -Parent $buttonPanel -ButtonText "▥ Open Reports" -Description "Open Reports folder`r`nin File Explorer" -Style Secondary
$btnOpenLogs = New-ShadowActionItem -Parent $buttonPanel -ButtonText "▣ Open Logs" -Description "Open Logs folder`r`nin File Explorer" -Style Secondary
$btnClearResults = New-ShadowActionItem -Parent $buttonPanel -ButtonText "⌧ Clear Log" -Description "Clear operational`r`nlog window" -Style Danger

# Operational Log
$logPanel = New-ShadowPanel -X 26 -Y 876 -W 1390 -H 146 -Title "Operational Log" -Icon "▸"
$form.Controls.Add($logPanel)

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Location = New-Object System.Drawing.Point(16, 52)
$txtLog.Size = New-Object System.Drawing.Size(1355, 76)
$txtLog.Multiline = $true
$txtLog.ScrollBars = "Vertical"
$txtLog.BackColor = $ShadowTheme.Console
$txtLog.ForeColor = $ShadowTheme.Text
$txtLog.Font = New-Object System.Drawing.Font("Consolas",9)
$txtLog.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$logPanel.Controls.Add($txtLog)

# Footer
$form.Controls.Add((New-ShadowLabel -Text "INVESTIGATE . CORRELATE . DEFEND ." -X 150 -Y 1030 -W 360 -H 26 -Size 9 -Muted))
$form.Controls.Add((New-ShadowLabel -Text "🦇  SHADOW DEPLOY" -X 535 -Y 1027 -W 320 -H 30 -Size 14 -Bold))
$form.Controls.Add((New-ShadowLabel -Text "SHADOW INTELLIGENCE. REAL-WORLD IMPACT." -X 890 -Y 1030 -W 380 -H 26 -Size 9 -Muted))
$form.Controls.Add((New-ShadowLabel -Text "v1.0" -X 1365 -Y 1030 -W 52 -H 26 -Size 9 -Muted))

# =============================
# Event Bindings - preserved behavior
# =============================

function Load-PolicyGrid {
    $gridPolicies.Rows.Clear()
    $count = 0

    foreach ($p in Get-MDEJsonPolicyCatalog) {
        $exists = Test-Path -LiteralPath $p.JsonPath
        [void]$gridPolicies.Rows.Add($p.Name,$p.Category,$p.JsonPath,$exists)
        $count++
    }

    if ($lblPolicyCount) { $lblPolicyCount.Text = "Policies: $count" }
    if ($lblLastAction) { $lblLastAction.Text = "Last action: Catalog refreshed $(Get-Date -Format 'HH:mm:ss')" }
    Add-Log "Loaded policy catalog."
    Add-Log "Found $count JSON policy file(s)."
    Add-Log "Ready."
}

$btnInit.Add_Click({
    try {
        # Force a fresh interactive Graph connection each time.
        # MFA is enforced by Conditional Access / tenant policy when the sign-in occurs.
        Disconnect-MgGraph -ErrorAction SilentlyContinue

        if ($graphPill) {
            $graphPill.Text = "  GRAPH: CONNECTING"
            $graphPill.BackColor = [System.Drawing.Color]::FromArgb(30, 64, 175)
        }
        if ($lblSignedIn) { $lblSignedIn.Text = "Signed in: Authentication required" }
        if ($lblTenant) { $lblTenant.Text = "Tenant ID: Pending authentication" }
        if ($lblLastAction) { $lblLastAction.Text = "Last action: Graph connection started $(Get-Date -Format 'HH:mm:ss')" }

        Add-Log "Starting fresh Microsoft Graph sign-in. Complete MFA if prompted."

        Connect-MgGraph -Scopes @(
            "DeviceManagementConfiguration.ReadWrite.All",
            "DeviceManagementManagedDevices.Read.All",
            "Directory.Read.All",
            "Group.Read.All"
        ) -NoWelcome

        $graphPill.Text = "  GRAPH: CONNECTED"
        $graphPill.BackColor = $ShadowTheme.Green
        Set-ShadowGraphIdentity
        Add-Log "Connected to Microsoft Graph."
    }
    catch {
        $graphPill.Text = "  GRAPH: FAILED"
        $graphPill.BackColor = $ShadowTheme.Red
        Add-Result "Graph" "Failed" $_.Exception.Message
    }
})

$btnDisconnect.Add_Click({
    try {
        Disconnect-MgGraph -ErrorAction Stop

        $graphPill.Text = "  GRAPH: DISCONNECTED"
        $graphPill.BackColor = [System.Drawing.Color]::FromArgb(132, 44, 8)

        if ($lblSignedIn) { $lblSignedIn.Text = "Signed in: Not connected" }
        if ($lblTenant) { $lblTenant.Text = "Tenant ID: Not connected" }
        if ($lblLastAction) { $lblLastAction.Text = "Last action: Graph disconnected $(Get-Date -Format 'HH:mm:ss')" }

        Add-Log "Disconnected from Microsoft Graph."
        Add-Result "Graph" "Success" "Disconnected from Microsoft Graph"
    }
    catch {
        $graphPill.Text = "  GRAPH: DISCONNECT FAILED"
        $graphPill.BackColor = $ShadowTheme.Red
        Add-Result "Graph" "Failed" $_.Exception.Message
    }
})

$btnClearResults.Add_Click({
    $gridResults.Rows.Clear()
    $txtLog.Clear()
    $script:LastResults = @()
    Update-ShadowMetrics
    if ($lblLastAction) { $lblLastAction.Text = "Last action: Results cleared $(Get-Date -Format 'HH:mm:ss')" }
    Add-Log "Results and operational log cleared."
})

$btnRefresh.Add_Click({ Load-PolicyGrid })

$btnValidate.Add_Click({
    $gridResults.Rows.Clear()
    $script:LastResults = @()
    Update-ShadowMetrics
    if ($lblLastAction) { $lblLastAction.Text = "Last action: Validation started $(Get-Date -Format 'HH:mm:ss')" }

    foreach ($p in Get-MDEJsonPolicyCatalog) {
        $result = Test-MDEJsonPolicyFile -JsonPath $p.JsonPath
        Add-Result $result.Name $result.Status $result.Details
    }
    if ($lblLastAction) { $lblLastAction.Text = "Last action: Validation completed $(Get-Date -Format 'HH:mm:ss')" }
})

$btnDeploy.Add_Click({
    $gridResults.Rows.Clear()
    $script:LastResults = @()
    Update-ShadowMetrics
    if ($lblLastAction) { $lblLastAction.Text = "Last action: Deployment started $(Get-Date -Format 'HH:mm:ss')" }

    foreach ($row in $gridPolicies.SelectedRows) {
        $name = $row.Cells["Name"].Value
        $path = $row.Cells["JsonPath"].Value

        $result = New-MDEConfigPolicyFromJson `
            -Name $name `
            -JsonPath $path `
            -WhatIf:$chkWhatIf.Checked

        Add-Result $result.Name $result.Status $result.Details

        if ($chkAssignAfterDeploy.Checked -and -not $chkWhatIf.Checked) {
            if ($result.Status -in @("Success","Skipped")) {
                $groupName = $txtGroupName.Text

                if ([string]::IsNullOrWhiteSpace($groupName)) {
                    Add-Result $result.Name "Failed" "Assign after deploy selected, but group name is blank."
                }
                else {
                    $assignResult = Add-MDEConfigPolicyAssignment `
                        -PolicyDisplayName (Get-MDEPolicyName $name) `
                        -GroupName $groupName

                    Add-Result $assignResult.Name $assignResult.Status $assignResult.Details
                }
            }
        }
    }

    if ($script:LastResults.Count -gt 0) {
        $reportPath = New-MDEDeploymentReport -Results $script:LastResults
        Add-Log "Deployment report generated: $reportPath"
    }
    Update-ShadowMetrics
    if ($lblLastAction) { $lblLastAction.Text = "Last action: Deployment completed $(Get-Date -Format 'HH:mm:ss')" }
})

$btnBackupAll.Add_Click({
    $gridResults.Rows.Clear()
    $script:LastResults = @()
    Backup-MDEAllPolicies
})

$btnExport.Add_Click({
    try {
        Assert-Mg

        $policyName = [Microsoft.VisualBasic.Interaction]::InputBox(
            "Enter the exact existing Intune Settings Catalog policy name:",
            "Export Policy JSON",
            ""
        )

        if ([string]::IsNullOrWhiteSpace($policyName)) {
            Add-Log "Export cancelled."
            return
        }

        $safeName = ($policyName -replace '^MDE - ','') -replace '^SOURCE - ',''
        $safeName = $safeName.ToLower() -replace '\s+','-' -replace '[\\/:*?""<>|]',''

        $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
        $saveDialog.Filter = "JSON files (*.json)|*.json"
        $saveDialog.InitialDirectory = Join-Path $PSScriptRoot "Config\SettingsCatalog"
        $saveDialog.FileName = "$safeName.json"

        if ($saveDialog.ShowDialog() -eq "OK") {
            $result = Export-MDEConfigPolicyJson `
                -PolicyName $policyName `
                -OutputPath $saveDialog.FileName

            Add-Result $result.Name $result.Status $result.Details
            Load-PolicyGrid
        }
    }
    catch {
        Add-Result "Export" "Failed" $_.Exception.Message
    }
})

$btnOpenConfig.Add_Click({
    $path = Join-Path $PSScriptRoot "Config"
    if (-not (Test-Path -LiteralPath $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
    Start-Process $path
})

$btnOpenLogs.Add_Click({
    $path = Get-MDELogFolder
    Start-Process $path
})

$btnReport.Add_Click({
    if ($script:LastResults.Count -eq 0) {
        Add-Result "Report" "Skipped" "No results available to report."
        return
    }

    $reportPath = New-MDEDeploymentReport -Results $script:LastResults
    Add-Result "Report" "Success" "Generated: $reportPath"
    if ($lblLastAction) { $lblLastAction.Text = "Last action: Report generated $(Get-Date -Format 'HH:mm:ss')" }
})

$btnOpenReports.Add_Click({
    $path = Get-MDEReportFolder
    Start-Process $path
})

Load-PolicyGrid
[void]$form.ShowDialog()

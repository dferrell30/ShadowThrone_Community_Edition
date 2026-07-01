#requires -Version 5.1
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$BasePath = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$ModulePath = Join-Path $BasePath "MDETestFramework.psm1"
$LogPath = Join-Path $BasePath "logs"
$HtmlReportPath = Join-Path $LogPath "results.html"
$JsonReportPath = Join-Path $LogPath "results.json"

if (-not (Test-Path -LiteralPath $ModulePath)) {
    [System.Windows.Forms.MessageBox]::Show("Unable to find MDETestFramework.psm1 in:`n$BasePath","Shadow Verify","OK","Error")
    exit
}

Import-Module $ModulePath -Force

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
    Green       = [System.Drawing.Color]::FromArgb(16, 128, 64)
    Orange      = [System.Drawing.Color]::FromArgb(198, 76, 0)
    Red         = [System.Drawing.Color]::FromArgb(185, 28, 28)
    Blue        = [System.Drawing.Color]::FromArgb(30, 64, 175)
    Console     = [System.Drawing.Color]::FromArgb(1, 3, 7)
}

$script:LastResults = @()

function New-ShadowFont {
    param([float]$Size = 9,[string]$Weight = "Regular")
    $style = [System.Drawing.FontStyle]::Regular
    if ($Weight -eq "Bold") { $style = [System.Drawing.FontStyle]::Bold }
    return New-Object System.Drawing.Font("Segoe UI", $Size, $style)
}

function New-ShadowLabel {
    param(
        [string]$Text,[int]$X,[int]$Y,[int]$W,[int]$H = 22,
        [float]$Size = 9,[switch]$Bold,[switch]$Muted,
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
    param([int]$X,[int]$Y,[int]$W,[int]$H,[string]$Title = "",[string]$Icon = "")
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
        [string]$Text,[int]$W = 126,[int]$H = 36,
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
        "Primary" { $button.BackColor = $ShadowTheme.Purple }
        "Success" { $button.BackColor = $ShadowTheme.Green }
        "Warning" { $button.BackColor = $ShadowTheme.Orange }
        "Danger"  { $button.BackColor = $ShadowTheme.Red }
        default   { $button.BackColor = $ShadowTheme.SurfaceSoft }
    }
    return $button
}

function New-ShadowMetricCard {
    param([string]$Value,[string]$Label,[int]$X,[int]$Y,[int]$W = 82,[System.Drawing.Color]$Accent = $ShadowTheme.Purple)
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Location = New-Object System.Drawing.Point($X, $Y)
    $panel.Size = New-Object System.Drawing.Size($W, 58)
    $panel.BackColor = $ShadowTheme.SurfaceAlt
    $panel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $valueLabel = New-ShadowLabel -Text $Value -X 0 -Y 8 -W $W -H 24 -Size 14 -Bold -BackColor $ShadowTheme.SurfaceAlt
    $valueLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $valueLabel.ForeColor = $Accent
    $panel.Controls.Add($valueLabel)
    $textLabel = New-ShadowLabel -Text $Label -X 0 -Y 34 -W $W -H 18 -Size 7.5 -Muted -BackColor $ShadowTheme.SurfaceAlt
    $textLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $panel.Controls.Add($textLabel)
    return @{ Panel = $panel; Value = $valueLabel; Label = $textLabel }
}

function New-ShadowStatusPill {
    param([string]$Text,[ValidateSet("Passed","Warning","Failed","Executed","Default")][string]$State = "Default")
    $pill = New-Object System.Windows.Forms.Label
    $pill.AutoSize = $false
    $pill.Size = New-Object System.Drawing.Size(92, 24)
    $pill.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $pill.Font = New-ShadowFont -Size 8 -Weight Bold
    $pill.ForeColor = $ShadowTheme.Text
    $pill.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    switch ($State) {
        "Passed"   { $pill.Text = "PASS"; $pill.BackColor = $ShadowTheme.Green }
        "Warning"  { $pill.Text = "VERIFY"; $pill.BackColor = $ShadowTheme.PurpleSoft }
        "Executed" { $pill.Text = "VERIFY"; $pill.BackColor = $ShadowTheme.PurpleSoft }
        "Failed"   { $pill.Text = "FAILED"; $pill.BackColor = $ShadowTheme.Red }
        default    { $pill.Text = $Text; $pill.BackColor = $ShadowTheme.SurfaceSoft }
    }
    return $pill
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
    $container.Size = New-Object System.Drawing.Size(156, 112)
    $container.BackColor = $ShadowTheme.Surface
    $container.Margin = New-Object System.Windows.Forms.Padding(6, 4, 6, 4)
    $button = New-ShadowButton -Text $ButtonText -W 144 -H 36 -Style $Style
    $button.Location = New-Object System.Drawing.Point(6, 0)
    $container.Controls.Add($button)
    $desc = New-Object System.Windows.Forms.Label
    $desc.Text = $Description
    $desc.Location = New-Object System.Drawing.Point(0, 46)
    $desc.Size = New-Object System.Drawing.Size(156, 62)
    $desc.TextAlign = [System.Drawing.ContentAlignment]::TopCenter
    $desc.Font = New-ShadowFont -Size 7.5
    $desc.ForeColor = $ShadowTheme.Muted
    $desc.BackColor = $ShadowTheme.Surface
    $container.Controls.Add($desc)
    $Parent.Controls.Add($container)
    return $button
}

function Add-Log {
    param([string]$Message)
    if ($txtLog) {
        $txtLog.AppendText("[$(Get-Date -Format 'HH:mm:ss')] $Message`r`n")
        $txtLog.SelectionStart = $txtLog.Text.Length
        $txtLog.ScrollToCaret()
    }
}

function Update-ShadowMetrics {
    $total = @($script:LastResults).Count
    $passed = @($script:LastResults | Where-Object { $_.Status -eq "Passed" }).Count
    $verify = @($script:LastResults | Where-Object { $_.Status -in @("Warning","Executed") }).Count
    $failed = @($script:LastResults | Where-Object { $_.Status -eq "Failed" }).Count
    $score = 0
    if ($total -gt 0) { $score = [math]::Round((($passed + ($verify * 0.5)) / $total) * 100) }
    $metricScore.Value.Text = if ($total -gt 0) { "$score%" } else { "--" }
    $metricPassed.Value.Text = "$passed"
    $metricReview.Value.Text = "$verify"
    $metricFailed.Value.Text = "$failed"
    if ($lblSignedInCompact) {
        try {
            $ctx = Get-MgContext -ErrorAction Stop
            if ($ctx -and $ctx.Account) { $lblSignedInCompact.Text = "Signed in: $($ctx.Account)" }
        } catch { $lblSignedInCompact.Text = "Signed in: Not connected" }
    }
    if ($statusBar) {
        if ($total -eq 0) { $statusBar.BackColor = $ShadowTheme.SurfaceSoft; $statusBar.Text = "STATUS: READY" }
        elseif ($failed -gt 0) { $statusBar.BackColor = $ShadowTheme.Red; $statusBar.Text = "STATUS: FAILED" }
        elseif ($verify -gt 0) { $statusBar.BackColor = $ShadowTheme.PurpleSoft; $statusBar.Text = "STATUS: VERIFY" }
        else { $statusBar.BackColor = $ShadowTheme.Green; $statusBar.Text = "STATUS: PASSED" }
    }
}

function Set-ShadowGraphIdentity {
    try {
        $ctx = Get-MgContext -ErrorAction Stop
        if ($ctx -and $ctx.Account) {
            $graphPill.Text = "GRAPH CONNECTED"
            $graphPill.BackColor = $ShadowTheme.Green
            $lblSignedInCompact.Text = "Signed in: $($ctx.Account)"
            $lblLastAction.Text = "Last: Graph connected $(Get-Date -Format 'HH:mm:ss')"
        }
    }
    catch {
        $graphPill.Text = "GRAPH NOT CONNECTED"
        $graphPill.BackColor = [System.Drawing.Color]::FromArgb(132, 44, 8)
        $lblSignedInCompact.Text = "Signed in: Not connected"
    }
}

function Add-ResultCards {
    param([array]$Results)
    $resultsFlow.Controls.Clear()
    $script:LastResults = @($Results)
    $grouped = $Results | Group-Object Category
    foreach ($group in $grouped) {
        $categoryPanel = New-Object System.Windows.Forms.Panel
        $categoryPanel.Width = 1320
        $categoryPanel.Height = 42 + (@($group.Group).Count * 58)
        $categoryPanel.BackColor = $ShadowTheme.SurfaceAlt
        $categoryPanel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
        $categoryPanel.Margin = New-Object System.Windows.Forms.Padding(8)
        $title = New-ShadowLabel -Text $group.Name -X 16 -Y 12 -W 700 -H 24 -Size 11 -Bold -BackColor $ShadowTheme.SurfaceAlt
        $categoryPanel.Controls.Add($title)
        $y = 44
        foreach ($r in $group.Group) {
            $rowPanel = New-Object System.Windows.Forms.Panel
            $rowPanel.Location = New-Object System.Drawing.Point(16, $y)
            $rowPanel.Size = New-Object System.Drawing.Size(1288, 48)
            $rowPanel.BackColor = $ShadowTheme.Surface
            $rowPanel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
            $categoryPanel.Controls.Add($rowPanel)
            $test = New-ShadowLabel -Text $r.TestName -X 14 -Y 6 -W 260 -H 18 -Size 9 -Bold -BackColor $ShadowTheme.Surface
            $rowPanel.Controls.Add($test)
            $details = New-ShadowLabel -Text $r.Details -X 14 -Y 25 -W 690 -H 18 -Size 7.8 -Muted -BackColor $ShadowTheme.Surface
            $rowPanel.Controls.Add($details)
            $pill = New-ShadowStatusPill -Text $r.Status -State $r.Status
            $pill.Location = New-Object System.Drawing.Point(740, 12)
            $rowPanel.Controls.Add($pill)
            $verifyText = if ($r.PSObject.Properties["Verify"]) { [string]$r.Verify } else { "" }
            $verify = New-ShadowLabel -Text $verifyText -X 850 -Y 8 -W 310 -H 34 -Size 7.6 -Muted -BackColor $ShadowTheme.Surface
            $rowPanel.Controls.Add($verify)
            $timeText = ""
            try { $timeText = Get-Date $r.Time -Format "HH:mm:ss" } catch {}
            $time = New-ShadowLabel -Text $timeText -X 1180 -Y 14 -W 85 -H 20 -Size 8 -Muted -BackColor $ShadowTheme.Surface
            $time.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
            $rowPanel.Controls.Add($time)
            $y += 56
        }
        $resultsFlow.Controls.Add($categoryPanel)
    }
    Update-ShadowMetrics
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Shadow Verify | Defender for Endpoint"
$form.Size = New-Object System.Drawing.Size(1450, 1085)
$form.MinimumSize = New-Object System.Drawing.Size(1450, 1085)
$form.StartPosition = "CenterScreen"
$form.BackColor = $ShadowTheme.Back
$form.ForeColor = $ShadowTheme.Text
$form.Font = New-ShadowFont -Size 9

$headerPanel = New-ShadowPanel -X 20 -Y 18 -W 1398 -H 214
$form.Controls.Add($headerPanel)

$logoPath = Join-Path $PSScriptRoot "shadowverify.png"
if (Test-Path -LiteralPath $logoPath) {
    try {
        $picLogo = New-Object System.Windows.Forms.PictureBox
        $picLogo.Location = New-Object System.Drawing.Point(18, 18)
        $picLogo.Size = New-Object System.Drawing.Size(420, 155)
        $picLogo.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
        $picLogo.BackColor = $ShadowTheme.Surface
        $picLogo.Image = [System.Drawing.Image]::FromFile($logoPath)
        $headerPanel.Controls.Add($picLogo)
    } catch {
        $headerPanel.Controls.Add((New-ShadowLabel -Text "SHADOW VERIFY" -X 24 -Y 64 -W 390 -H 52 -Size 25 -Bold -BackColor $ShadowTheme.Surface))
    }
} else {
    $headerPanel.Controls.Add((New-ShadowLabel -Text "SHADOW VERIFY" -X 24 -Y 64 -W 390 -H 52 -Size 25 -Bold -BackColor $ShadowTheme.Surface))
}

$headerPanel.Controls.Add((New-ShadowLabel -Text "Defender for Endpoint`r`nValidation Module" -X 465 -Y 52 -W 360 -H 64 -Size 18 -Bold -BackColor $ShadowTheme.Surface))
$headerPanel.Controls.Add((New-ShadowLabel -Text "Control validation, telemetry verification, Graph visibility checks, and analyst reporting." -X 468 -Y 122 -W 430 -H 38 -Size 9 -Muted -BackColor $ShadowTheme.Surface))
$lblLastAction = New-ShadowLabel -Text "Last: Ready" -X 468 -Y 164 -W 430 -H 20 -Size 8 -Muted -BackColor $ShadowTheme.Surface
$headerPanel.Controls.Add($lblLastAction)

$graphPill = New-ShadowStatusPill -Text "GRAPH NOT CONNECTED" -State Default
$graphPill.Location = New-Object System.Drawing.Point(1180, 22)
$graphPill.Size = New-Object System.Drawing.Size(170, 32)
$graphPill.BackColor = [System.Drawing.Color]::FromArgb(132, 44, 8)
$headerPanel.Controls.Add($graphPill)

$modulePill = New-ShadowStatusPill -Text "VERIFY MODULE" -State Default
$modulePill.Location = New-Object System.Drawing.Point(995, 22)
$modulePill.Size = New-Object System.Drawing.Size(170, 32)
$headerPanel.Controls.Add($modulePill)

$summaryMini = New-Object System.Windows.Forms.Panel
$summaryMini.Location = New-Object System.Drawing.Point(995, 66)
$summaryMini.Size = New-Object System.Drawing.Size(355, 118)
$summaryMini.BackColor = $ShadowTheme.SurfaceAlt
$summaryMini.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$headerPanel.Controls.Add($summaryMini)
$summaryMini.Controls.Add((New-ShadowLabel -Text "VALIDATION SUMMARY" -X 12 -Y 8 -W 330 -H 18 -Size 8 -Bold -BackColor $ShadowTheme.SurfaceAlt))
$lblSignedInCompact = New-ShadowLabel -Text "Signed in: Not connected" -X 12 -Y 28 -W 330 -H 18 -Size 7.5 -Muted -BackColor $ShadowTheme.SurfaceAlt
$summaryMini.Controls.Add($lblSignedInCompact)
$metricScore = New-ShadowMetricCard -Value "--" -Label "SCORE" -X 12 -Y 52 -W 76 -Accent $ShadowTheme.Purple
$metricPassed = New-ShadowMetricCard -Value "0" -Label "PASS" -X 96 -Y 52 -W 76 -Accent $ShadowTheme.Green
$metricReview = New-ShadowMetricCard -Value "0" -Label "VERIFY" -X 180 -Y 52 -W 76 -Accent $ShadowTheme.Purple
$metricFailed = New-ShadowMetricCard -Value "0" -Label "FAIL" -X 264 -Y 52 -W 76 -Accent $ShadowTheme.Red
$summaryMini.Controls.Add($metricScore.Panel)
$summaryMini.Controls.Add($metricPassed.Panel)
$summaryMini.Controls.Add($metricReview.Panel)
$summaryMini.Controls.Add($metricFailed.Panel)

$statusBar = New-Object System.Windows.Forms.Label
$statusBar.Location = New-Object System.Drawing.Point(995, 188)
$statusBar.Size = New-Object System.Drawing.Size(355, 18)
$statusBar.Text = "STATUS: READY"
$statusBar.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$statusBar.Font = New-ShadowFont -Size 8 -Weight Bold
$statusBar.ForeColor = $ShadowTheme.Text
$statusBar.BackColor = $ShadowTheme.SurfaceSoft
$headerPanel.Controls.Add($statusBar)

$optionsPanel = New-ShadowPanel -X 20 -Y 250 -W 1398 -H 82 -Title "Validation Options"
$form.Controls.Add($optionsPanel)

$chkEicar = New-Object System.Windows.Forms.CheckBox
$chkEicar.Text = "Include EICAR AV validation"
$chkEicar.Checked = $true
$chkEicar.Location = New-Object System.Drawing.Point(22, 44)
$chkEicar.Size = New-Object System.Drawing.Size(260, 24)
$chkEicar.ForeColor = $ShadowTheme.Text
$chkEicar.BackColor = $ShadowTheme.Surface
$optionsPanel.Controls.Add($chkEicar)

$chkGraph = New-Object System.Windows.Forms.CheckBox
$chkGraph.Text = "Include Graph alert visibility checks"
$chkGraph.Checked = $true
$chkGraph.Location = New-Object System.Drawing.Point(310, 44)
$chkGraph.Size = New-Object System.Drawing.Size(310, 24)
$chkGraph.ForeColor = $ShadowTheme.Text
$chkGraph.BackColor = $ShadowTheme.Surface
$optionsPanel.Controls.Add($chkGraph)

$chkASRGuided = New-Object System.Windows.Forms.CheckBox
$chkASRGuided.Text = "Include guided ASR validation"
$chkASRGuided.Checked = $false
$chkASRGuided.Location = New-Object System.Drawing.Point(650, 44)
$chkASRGuided.Size = New-Object System.Drawing.Size(280, 24)
$chkASRGuided.ForeColor = $ShadowTheme.Text
$chkASRGuided.BackColor = $ShadowTheme.Surface
$optionsPanel.Controls.Add($chkASRGuided)

$optionsPanel.Controls.Add((New-ShadowLabel -Text "Guided ASR adds report guidance and verification steps without unsafe simulations." -X 950 -Y 46 -W 390 -H 22 -Size 8 -Muted -BackColor $ShadowTheme.Surface))

$resultsPanel = New-ShadowPanel -X 20 -Y 350 -W 1398 -H 390 -Title "Validation Results" -Icon "▣"
$form.Controls.Add($resultsPanel)
$resultsFlow = New-Object System.Windows.Forms.FlowLayoutPanel
$resultsFlow.Location = New-Object System.Drawing.Point(16, 50)
$resultsFlow.Size = New-Object System.Drawing.Size(1366, 322)
$resultsFlow.BackColor = $ShadowTheme.Surface
$resultsFlow.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
$resultsFlow.WrapContents = $false
$resultsFlow.AutoScroll = $true
$resultsPanel.Controls.Add($resultsFlow)

$actionsPanel = New-ShadowPanel -X 20 -Y 760 -W 1398 -H 156 -Title "Actions" -Icon "⚡"
$form.Controls.Add($actionsPanel)
$buttonPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$buttonPanel.Location = New-Object System.Drawing.Point(14, 46)
$buttonPanel.Size = New-Object System.Drawing.Size(1360, 104)
$buttonPanel.BackColor = $ShadowTheme.Surface
$buttonPanel.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight
$buttonPanel.WrapContents = $false
$buttonPanel.AutoScroll = $false
$buttonPanel.Padding = New-Object System.Windows.Forms.Padding(0)
$actionsPanel.Controls.Add($buttonPanel)

$btnRun = New-ShadowActionItem -Parent $buttonPanel -ButtonText "▷ Run Verify" -Description "Run selected endpoint`r`nvalidation checks" -Style Success
$btnConnect = New-ShadowActionItem -Parent $buttonPanel -ButtonText "🔗 Connect Graph" -Description "Authenticate for cloud`r`nvisibility checks" -Style Primary
$btnDisconnect = New-ShadowActionItem -Parent $buttonPanel -ButtonText "⛓ Disconnect" -Description "Disconnect current`r`nGraph session" -Style Secondary
$btnOpenReport = New-ShadowActionItem -Parent $buttonPanel -ButtonText "▤ Open Report" -Description "Open generated`r`nHTML report" -Style Primary
$btnOpenJson = New-ShadowActionItem -Parent $buttonPanel -ButtonText "{ } Open JSON" -Description "Open generated`r`nJSON output" -Style Secondary
$btnOpenLogs = New-ShadowActionItem -Parent $buttonPanel -ButtonText "▣ Open Logs" -Description "Open validation`r`nlogs folder" -Style Secondary
$btnClear = New-ShadowActionItem -Parent $buttonPanel -ButtonText "⌧ Clear" -Description "Clear displayed`r`nresults and log" -Style Danger
$btnExit = New-ShadowActionItem -Parent $buttonPanel -ButtonText "Exit" -Description "Close Shadow`r`nVerify" -Style Secondary

$logPanel = New-ShadowPanel -X 20 -Y 934 -W 1398 -H 90 -Title "Operational Log" -Icon "▸"
$form.Controls.Add($logPanel)
$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Location = New-Object System.Drawing.Point(16, 48)
$txtLog.Size = New-Object System.Drawing.Size(1365, 30)
$txtLog.Multiline = $true
$txtLog.ScrollBars = "Vertical"
$txtLog.BackColor = $ShadowTheme.Console
$txtLog.ForeColor = $ShadowTheme.Text
$txtLog.Font = New-Object System.Drawing.Font("Consolas",9)
$txtLog.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$logPanel.Controls.Add($txtLog)

$form.Controls.Add((New-ShadowLabel -Text "VALIDATE . VERIFY . DEFEND ." -X 150 -Y 1030 -W 360 -H 26 -Size 9 -Muted))
$form.Controls.Add((New-ShadowLabel -Text "🦇  SHADOW VERIFY" -X 535 -Y 1027 -W 320 -H 30 -Size 14 -Bold))
$form.Controls.Add((New-ShadowLabel -Text "SHADOW INTELLIGENCE. REAL-WORLD IMPACT." -X 890 -Y 1030 -W 380 -H 26 -Size 9 -Muted))
$form.Controls.Add((New-ShadowLabel -Text "v2.4" -X 1365 -Y 1030 -W 52 -H 26 -Size 9 -Muted))

$btnRun.Add_Click({
    try {
        $resultsFlow.Controls.Clear()
        $script:LastResults = @()
        Update-ShadowMetrics
        Add-Log "Shadow Verify validation started."
        Add-Log "EICAR Enabled: $($chkEicar.Checked)"
        Add-Log "Graph Enabled: $($chkGraph.Checked)"
        Add-Log "Guided ASR Enabled: $($chkASRGuided.Checked)"
        $params = @{}
        if (-not $chkEicar.Checked) { $params.SkipEICAR = $true }
        if (-not $chkGraph.Checked) { $params.SkipGraph = $true }
        if ($chkASRGuided.Checked) {
            $params.RunASRGuidedValidation = $true
            Add-Log "Guided ASR validation enabled."
        }
        $btnRun.Enabled = $false
        $results = Invoke-MDETests @params
        Add-ResultCards -Results $results
        Add-Log "Validation completed."
        Add-Log "HTML report: $HtmlReportPath"
        Add-Log "JSON report: $JsonReportPath"
        $lblLastAction.Text = "Last: Validation completed $(Get-Date -Format 'HH:mm:ss')"
    }
    catch {
        Add-Log "Validation failed: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message,"Shadow Verify Error","OK","Error")
    }
    finally { $btnRun.Enabled = $true }
})

$btnConnect.Add_Click({
    try {
        Add-Log "Connecting to Microsoft Graph..."
        if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
            [System.Windows.Forms.MessageBox]::Show("Microsoft.Graph.Authentication module is not installed.","Shadow Verify","OK","Warning")
            Add-Log "Microsoft.Graph.Authentication module not installed."
            return
        }
        Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
        Connect-MgGraph -Scopes @("SecurityEvents.Read.All","SecurityAlert.Read.All") -NoWelcome
        Set-ShadowGraphIdentity
        Add-Log "Connected to Microsoft Graph."
    }
    catch {
        $graphPill.Text = "GRAPH FAILED"
        $graphPill.BackColor = $ShadowTheme.Red
        Add-Log "Graph connection failed: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message,"Graph Connection Failed","OK","Warning")
    }
})

$btnDisconnect.Add_Click({
    try {
        Disconnect-MgGraph -ErrorAction SilentlyContinue
        $graphPill.Text = "GRAPH NOT CONNECTED"
        $graphPill.BackColor = [System.Drawing.Color]::FromArgb(132, 44, 8)
        $lblSignedInCompact.Text = "Signed in: Not connected"
        $lblLastAction.Text = "Last: Graph disconnected $(Get-Date -Format 'HH:mm:ss')"
        Add-Log "Disconnected from Microsoft Graph."
    }
    catch { Add-Log "Graph disconnect completed with warnings." }
})

$btnOpenReport.Add_Click({
    if (Test-Path -LiteralPath $HtmlReportPath) { Start-Process $HtmlReportPath; Add-Log "Opened HTML report." }
    else { [System.Windows.Forms.MessageBox]::Show("No HTML report found yet. Run verification first.","Shadow Verify","OK","Information") }
})
$btnOpenJson.Add_Click({
    if (Test-Path -LiteralPath $JsonReportPath) { Start-Process notepad.exe $JsonReportPath; Add-Log "Opened JSON output." }
    else { [System.Windows.Forms.MessageBox]::Show("No JSON output found yet. Run verification first.","Shadow Verify","OK","Information") }
})
$btnOpenLogs.Add_Click({
    if (-not (Test-Path -LiteralPath $LogPath)) { New-Item -ItemType Directory -Path $LogPath -Force | Out-Null }
    Start-Process explorer.exe $LogPath
    Add-Log "Opened logs folder."
})
$btnClear.Add_Click({
    $resultsFlow.Controls.Clear()
    $txtLog.Clear()
    $script:LastResults = @()
    Update-ShadowMetrics
    $lblLastAction.Text = "Last: Results cleared $(Get-Date -Format 'HH:mm:ss')"
    Add-Log "Results and operational log cleared."
})
$btnExit.Add_Click({ $form.Close() })

Add-Log "Shadow Verify ready."
Set-ShadowGraphIdentity
Update-ShadowMetrics
[void]$form.ShowDialog()

param(
    [string]$BuildPath = (Join-Path $PSScriptRoot "build_pipeline"),
    [switch]$Package
)

$ErrorActionPreference = "Stop"

$utilizationPath = Join-Path $BuildPath "utilization.rpt"
$timingPath = Join-Path $BuildPath "timing_summary.rpt"
$methodologyPath = Join-Path $BuildPath "methodology.rpt"
$summaryPath = Join-Path $BuildPath "report_summary.txt"
$archivePath = Join-Path $PSScriptRoot "pipeline_reports.zip"

$requiredReports = @(
    $utilizationPath,
    $timingPath,
    $methodologyPath
)

foreach ($report in $requiredReports) {
    if (!(Test-Path -LiteralPath $report)) {
        throw "Missing report: $report. Run pipeline synthesis first."
    }
}

$timingLines = Get-Content -LiteralPath $timingPath
$utilizationLines = Get-Content -LiteralPath $utilizationPath
$methodologyLines = Get-Content -LiteralPath $methodologyPath

$summary = [System.Collections.Generic.List[string]]::new()

function Add-SummaryLine {
    param([string]$Line = "")

    $script:summary.Add($Line)
    Write-Host $Line
}

Add-SummaryLine "OOOP-RISCV cached pipeline synthesis summary"
Add-SummaryLine "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Add-SummaryLine ""

Add-SummaryLine "Timing"
$timingMatches = $timingLines | Where-Object {
    $_ -match "WNS\(ns\)|TNS\(ns\)|Timing constraints are|Slack \(|Source:|Destination:|Data Path Delay:|Logic Levels:"
} | Select-Object -First 40

foreach ($line in $timingMatches) {
    Add-SummaryLine $line
}

Add-SummaryLine ""
Add-SummaryLine "Utilization"
$utilizationMatches = $utilizationLines | Where-Object {
    $_ -match "\| (Slice LUTs|Slice Registers|Block RAM Tile|DSPs|CLB LUTs|CLB Registers|RAMB18|RAMB36|DSP48)"
} | Select-Object -First 30

foreach ($line in $utilizationMatches) {
    Add-SummaryLine $line
}

$criticalCount = @($methodologyLines | Where-Object {
    $_ -match "CRITICAL WARNING"
}).Count
$warningCount = @($methodologyLines | Where-Object {
    ($_ -match "WARNING") -and ($_ -notmatch "CRITICAL WARNING")
}).Count

Add-SummaryLine ""
Add-SummaryLine "Methodology"
Add-SummaryLine "Critical warnings: $criticalCount"
Add-SummaryLine "Warnings: $warningCount"

$summary | Set-Content -LiteralPath $summaryPath
Write-Host ""
Write-Host "Summary written to: $summaryPath"

if ($Package) {
    if (Test-Path -LiteralPath $archivePath) {
        Remove-Item -LiteralPath $archivePath -Force
    }

    Compress-Archive -LiteralPath @(
        $utilizationPath,
        $timingPath,
        $methodologyPath,
        $summaryPath
    ) -DestinationPath $archivePath

    Write-Host "Report package: $archivePath"
}

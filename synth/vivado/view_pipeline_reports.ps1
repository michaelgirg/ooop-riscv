param(
    [string]$BuildPath = (Join-Path $PSScriptRoot "build_pipeline"),
    [switch]$Package
)

$ErrorActionPreference = "Stop"

$utilizationPath = Join-Path $BuildPath "utilization.rpt"
$timingPath = Join-Path $BuildPath "timing_summary.rpt"
$methodologyPath = Join-Path $BuildPath "methodology.rpt"
$routeStatusPath = Join-Path $BuildPath "route_status.rpt"
$summaryPath = Join-Path $BuildPath "report_summary.txt"
$archivePath = Join-Path $PSScriptRoot "pipeline_reports.zip"

$requiredReports = @(
    $utilizationPath,
    $timingPath,
    $methodologyPath,
    $routeStatusPath
)

foreach ($report in $requiredReports) {
    if (!(Test-Path -LiteralPath $report)) {
        throw "Missing report: $report. Run pipeline synthesis first."
    }
}

$timingLines = Get-Content -LiteralPath $timingPath
$utilizationLines = Get-Content -LiteralPath $utilizationPath
$methodologyLines = Get-Content -LiteralPath $methodologyPath
$routeStatusLines = Get-Content -LiteralPath $routeStatusPath

$summary = [System.Collections.Generic.List[string]]::new()

function Add-SummaryLine {
    param([string]$Line = "")

    $script:summary.Add($Line)
    Write-Host $Line
}

Add-SummaryLine "OOOP-RISCV cached pipeline post-route summary"
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
Add-SummaryLine "Hierarchy utilization"
$utilizationMatches = $utilizationLines | Where-Object {
    $_ -match "^\|\s+(core_pipeline|u_dcache|u_dmem|u_icache|u_imem|u_muldiv_unit)\s+\|"
} | Select-Object -First 20

foreach ($line in $utilizationMatches) {
    Add-SummaryLine $line
}

$criticalCount = 0
$warningCount = 0

# Sum the message counts in Vivado's methodology summary table. Counting raw
# occurrences of "WARNING" also counts headings and detailed message text.
foreach ($line in $methodologyLines) {
    if ($line -match '^\|\s*[^|]+\|\s*(Critical Warning|Warning)\s*\|.*\|\s*(\d+)\s*\|\s*$') {
        $count = [int]$Matches[2]

        if ($Matches[1] -eq "Critical Warning") {
            $criticalCount += $count
        }
        else {
            $warningCount += $count
        }
    }
}

Add-SummaryLine ""
Add-SummaryLine "Methodology"
Add-SummaryLine "Critical warnings: $criticalCount"
Add-SummaryLine "Warnings: $warningCount"

Add-SummaryLine ""
Add-SummaryLine "Routing"
$routeMatches = $routeStatusLines | Where-Object {
    $_ -match "Design Route Status|Fully Routed|Unrouted Nets|Routing Errors"
} | Select-Object -First 20

foreach ($line in $routeMatches) {
    Add-SummaryLine $line
}

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
        $routeStatusPath,
        $summaryPath
    ) -DestinationPath $archivePath

    Write-Host "Report package: $archivePath"
}

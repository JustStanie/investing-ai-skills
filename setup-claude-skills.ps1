$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$canonical = Join-Path $root '.agents\skills'
$claudeDir = Join-Path $root '.claude'
$link = Join-Path $claudeDir 'skills'

if (-not (Test-Path -LiteralPath $canonical -PathType Container)) {
    throw "Missing canonical Skills directory: $canonical"
}
New-Item -ItemType Directory -Force -Path $claudeDir | Out-Null

$existing = Get-Item -LiteralPath $link -Force -ErrorAction SilentlyContinue
if ($null -ne $existing) {
    if ($existing.LinkType -in @('Junction', 'SymbolicLink')) {
        $currentTarget = $existing.Target
        if ($currentTarget -is [array]) { $currentTarget = $currentTarget[0] }
        $resolvedTarget = [System.IO.Path]::GetFullPath([string]$currentTarget)
        if ($resolvedTarget.TrimEnd('\') -ieq [System.IO.Path]::GetFullPath($canonical).TrimEnd('\')) {
            Write-Host 'Claude Skills link already configured.'
            exit 0
        }
        throw "Existing link points elsewhere: $currentTarget. Nothing was changed."
    }
    throw "Path already exists and is not a junction/symlink: $link. Move it manually before retrying."
}
New-Item -ItemType Junction -Path $link -Target $canonical | Out-Null
Write-Host "Created junction: $link -> $canonical"

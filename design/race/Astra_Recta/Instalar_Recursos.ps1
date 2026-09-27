$ErrorActionPreference = 'Stop'
$sourceAssets = Join-Path $PSScriptRoot 'Roblox_LocalAssets'
if (-not (Test-Path -LiteralPath $sourceAssets)) { throw 'Falta Roblox_LocalAssets junto al instalador.' }
$versions = Join-Path $env:LOCALAPPDATA 'Roblox/Versions'
$studios = Get-ChildItem -LiteralPath $versions -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'RobloxStudioBeta.exe') }
if (-not $studios) { throw 'No se encontro Roblox Studio.' }
foreach ($studio in $studios) {
    $destinationAssets = Join-Path $studio.FullName 'content/raceastra_straight_20260925'
    New-Item -ItemType Directory -Force -Path $destinationAssets | Out-Null
    Get-ChildItem -LiteralPath $sourceAssets -File | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $destinationAssets -Force }
}
Write-Host 'Listo. Abre RaceArena_Recta.rbxl en Studio.'

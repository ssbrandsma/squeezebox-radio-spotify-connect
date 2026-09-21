[CmdletBinding()]
param(
    [string]$BaseUrl,
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
$VersionFile = Join-Path $Root 'VERSION'

if (-not (Test-Path -LiteralPath $VersionFile -PathType Leaf)) {
    throw "Missing version file: $VersionFile"
}
$Version = (Get-Content -LiteralPath $VersionFile -Raw).Trim()
if ($Version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+(?:[-+][0-9A-Za-z.-]+)?$') {
    throw "VERSION must contain a semantic version; found '$Version'"
}

if (-not $BaseUrl) {
    $BaseUrl = 'http://49.12.198.91/sbspotifyconnect'
}
try { $RepositoryUri = [Uri]$BaseUrl } catch { throw "BaseUrl is not a valid URL: $BaseUrl" }
if (-not $RepositoryUri.IsAbsoluteUri -or $RepositoryUri.Scheme -notin @('http', 'https')) {
    throw "BaseUrl must use HTTP or HTTPS: $BaseUrl"
}
$BaseUrl = $BaseUrl.TrimEnd('/')

if (-not $OutputDirectory) { $OutputDirectory = Join-Path $Root 'dist' }
$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)

& "$PSScriptRoot/build-applet.ps1"
$Stage = Join-Path $PSScriptRoot 'out/applet/SpotifyConnect'
$RequiredEntries = @(
    'librespot',
    'ogg-http-bridge',
    'qrencode.lua',
    'spotify-logo.jpg',
    'spotify-metadata',
    'spotify-metadata-event',
    'spotify-supervisor',
    'SpotifyArtwork.lua',
    'SpotifyConnectApplet.lua',
    'SpotifyConnectMeta.lua',
    'SpotifyConnectState.lua',
    'SpotifyNowPlaying.lua',
    'SpotifyPlayback.lua',
    'SpotifyService.lua',
    'strings.txt'
)
foreach ($Entry in $RequiredEntries) {
    if (-not (Test-Path -LiteralPath (Join-Path $Stage $Entry) -PathType Leaf)) {
        throw "Required package file is missing: $Entry"
    }
}

New-Item -ItemType Directory -Force $OutputDirectory | Out-Null
$ZipName = "SpotifyConnect-$Version.zip"
$ZipPath = Join-Path $OutputDirectory $ZipName
Remove-Item -LiteralPath $ZipPath -Force -ErrorAction SilentlyContinue
Push-Location $Stage
try {
    Compress-Archive -Path $RequiredEntries -DestinationPath $ZipPath -CompressionLevel Optimal
}
finally {
    Pop-Location
}

$Archive = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
try {
    $ZipEntries = @($Archive.Entries | Where-Object { -not $_.FullName.EndsWith('/') } | ForEach-Object { $_.FullName.Replace('\', '/') })
}
finally {
    $Archive.Dispose()
}
$Unexpected = @($ZipEntries | Where-Object { $_ -notin $RequiredEntries })
$Missing = @($RequiredEntries | Where-Object { $_ -notin $ZipEntries })
if ($Unexpected.Count -gt 0) { throw "ZIP contains unexpected files: $($Unexpected -join ', ')" }
if ($Missing.Count -gt 0) { throw "ZIP is missing files: $($Missing -join ', ')" }
if ($ZipEntries | Where-Object { $_ -match '^(SpotifyConnect/|applet/)' }) {
    throw 'ZIP has an enclosing directory; Applet Installer requires runtime files at the archive root'
}

$ZipSha1 = (Get-FileHash -LiteralPath $ZipPath -Algorithm SHA1).Hash.ToLowerInvariant()
$ZipUrl = "$BaseUrl/$ZipName"
$Escape = { param([string]$Value) [System.Security.SecurityElement]::Escape($Value) }
$Xml = @"
<?xml version="1.0" encoding="UTF-8"?>
<extensions>
  <details>
    <title lang="EN">Squeezebox Radio Spotify Connect Repository</title>
  </details>
  <applets>
    <applet name="SpotifyConnect" version="$(& $Escape $Version)" target="baby" minTarget="7.7" maxTarget="*">
      <title lang="EN">Spotify Connect</title>
      <desc lang="EN">Standalone Spotify Connect playback for Logitech Squeezebox Radio. LMS is only needed to install the applet.</desc>
      <changes lang="EN">Responsive playback controls, remote volume, pairing QR code, and redesigned Now Playing screen.</changes>
      <creator>Sjoerd Brandsma</creator>
      <url>$(& $Escape $ZipUrl)</url>
      <sha>$ZipSha1</sha>
    </applet>
  </applets>
</extensions>
"@
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$XmlPath = Join-Path $OutputDirectory 'extensions.xml'
[System.IO.File]::WriteAllText($XmlPath, $Xml, $Utf8NoBom)
$XmlSha1 = (Get-FileHash -LiteralPath $XmlPath -Algorithm SHA1).Hash.ToLowerInvariant()
[System.IO.File]::WriteAllText((Join-Path $OutputDirectory 'extensions.xml.sha1'), $XmlSha1, $Utf8NoBom)

[xml]$Parsed = Get-Content -LiteralPath $XmlPath -Raw
$Applet = $Parsed.extensions.applets.applet
if ($Applet.name -ne 'SpotifyConnect' -or $Applet.version -ne $Version -or $Applet.target -ne 'baby' -or $Applet.url -ne $ZipUrl -or $Applet.sha -ne $ZipSha1) {
    throw 'Generated extensions.xml did not round-trip with the expected package metadata'
}

Write-Host 'Built Spotify Connect Applet Installer package'
Write-Host "Version:        $Version"
Write-Host "ZIP:            $ZipPath"
Write-Host "ZIP size:       $((Get-Item -LiteralPath $ZipPath).Length) bytes"
Write-Host "ZIP SHA-1:      $ZipSha1"
Write-Host "Repository XML: $XmlPath"
Write-Host "XML SHA-1:      $XmlSha1"
Write-Host "ZIP URL:        $ZipUrl"
Write-Host 'Archive entries:'
$ZipEntries | ForEach-Object { Write-Host "  $_" }

param(
    [string]$Runtime = 'win-x64',
    [string]$PublishDir = $(Join-Path (Resolve-Path '.') 'publish\win-x64'),
    [string]$OutDir = $(Join-Path (Resolve-Path '.') 'dist'),
    [string]$Version = '',
    [string]$SignCertPath = '',
    [string]$SignCertPassword = '',
    [string]$TimestampUrl = 'http://timestamp.digicert.com'
)

$ErrorActionPreference = 'Stop'

Write-Host '=== WindowsDCRC - Build Installer ==='

# Ensure output directories
New-Item -ItemType Directory -Force -Path $PublishDir | Out-Null
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# Ensure dotnet tools path on PATH (for wix)
$dotnetTools = Join-Path $env:USERPROFILE '.dotnet\tools'
if (-not ($env:PATH -split ';' | Where-Object { $_ -eq $dotnetTools })) { $env:PATH = "$dotnetTools;$env:PATH" }

# Install/Update wix v4 if missing
try {
    $wixVersion = (wix --version) 2>$null
    if (-not $wixVersion) { throw 'wix not found' }
}
catch {
    Write-Host 'Installing WiX Toolset v4 as dotnet tool...'
    dotnet tool update -g wix | Out-Null
}

# Publish self-contained single-file
Write-Host 'Publishing app (Release, self-contained, single-file)...'
dotnet publish 'WindowsDCRC.csproj' -c Release -r $Runtime -o $PublishDir `
    -p:PublishSingleFile=true -p:SelfContained=true -p:PublishTrimmed=false -p:IncludeNativeLibrariesForSelfExtract=true | Out-Null

$exePath = Join-Path $PublishDir 'Windows DCRC.exe'
if (-not (Test-Path $exePath)) { throw "Publish output not found: $exePath" }

# Derive version if not passed
if (-not $Version) {
    try {
        $dllPath = Join-Path $PublishDir 'Windows DCRC.dll'
        if (Test-Path $dllPath) {
            $fvi = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($dllPath)
            $Version = $fvi.FileVersion
        }
        if (-not $Version) {
            $fvi2 = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($exePath)
            $Version = $fvi2.FileVersion
        }
    }
    catch {}
}
if (-not $Version) { $Version = '1.0.0.0' }
Write-Host "Using Version: $Version"

# Optional code signing
function Get-SignToolPath {
    try {
        $cmd = (Get-Command 'signtool.exe' -ErrorAction Stop).Source
        if ($cmd) { return $cmd }
    }
    catch {}

    $pf86 = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
    $pf = [Environment]::GetEnvironmentVariable('ProgramFiles')
    $candidateRoots = @()
    if ($pf86) {
        $candidateRoots += (Join-Path $pf86 'Windows Kits\10\bin')
        $candidateRoots += (Join-Path $pf86 'Windows Kits\8.1\bin')
        $candidateRoots += 'C:\Program Files (x86)\Microsoft SDKs\ClickOnce\SignTool'
    }
    if ($pf) {
        $candidateRoots += (Join-Path $pf 'Windows Kits\10\bin')
        $candidateRoots += (Join-Path $pf 'Windows Kits\8.1\bin')
    }
    $candidateRoots = $candidateRoots | Where-Object { $_ -and (Test-Path $_) }

    $all = @()
    foreach ($root in $candidateRoots) {
        $all += Get-ChildItem -Path $root -Recurse -Filter 'signtool.exe' -ErrorAction SilentlyContinue
    }
    if (-not $all -or $all.Count -eq 0) { return '' }

    $is64 = [Environment]::Is64BitOperatingSystem
    $preferred = if ($is64) { '\\x64\\' } else { '\\x86\\' }

    $picked = $all | Where-Object { $_.FullName -match [regex]::Escape($preferred) } | Select-Object -First 1
    if (-not $picked) { $picked = $all | Where-Object { $_.FullName -notmatch '\\arm(64)?\\' } | Select-Object -First 1 }
    if (-not $picked) { $picked = $all | Select-Object -First 1 }
    return $picked.FullName
}

if ($SignCertPath -and (Test-Path $SignCertPath)) {
    $signtool = Get-SignToolPath
    if ($signtool) {
        Write-Host 'Code-signing executable...'
        & $signtool sign /f "$SignCertPath" /p "$SignCertPassword" /fd SHA256 /tr "$TimestampUrl" /td SHA256 "$exePath"
    }
    else {
        Write-Warning 'signtool.exe not found; skipping signing.'
    }
}
else {
    Write-Host 'No certificate provided. Skipping code signing.'
}

# Build MSI with WiX 3 (robust UI checkbox wiring)
$msiName = "WindowsDCRC_${Version}.msi"
$msiPath = Join-Path $OutDir $msiName
Write-Host 'Building MSI with WiX 3 (candle/light)...'
$iconPath = Join-Path (Resolve-Path '.') 'Assets\app.ico'

# Download WiX 3 if not available (portable binaries)
$wix3Dir = Join-Path $env:TEMP 'wix3bin'
if (-not (Test-Path $wix3Dir)) { New-Item -ItemType Directory -Force -Path $wix3Dir | Out-Null }
$candle = Join-Path $wix3Dir 'candle.exe'
$light = Join-Path $wix3Dir 'light.exe'
if (-not (Test-Path $candle) -or -not (Test-Path $light)) {
    Write-Host 'Fetching WiX 3 binaries...'
    $zip = Join-Path $wix3Dir 'wix311-binaries.zip'
    Invoke-WebRequest -Uri 'https://github.com/wixtoolset/wix3/releases/download/wix3112rtm/wix311-binaries.zip' -OutFile $zip -UseBasicParsing
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $wix3Dir)
}

$wxs = 'installer/Product.v3.wxs'
& $candle -nologo -ext WixUIExtension -ext WixUtilExtension -dPublishDir="$PublishDir" -dVersion="$Version" -dAppIconPath="$iconPath" -out (Join-Path $wix3Dir 'product.wixobj') $wxs
& $light -nologo -ext WixUIExtension -ext WixUtilExtension -out $msiPath (Join-Path $wix3Dir 'product.wixobj')

if ($SignCertPath -and (Test-Path $SignCertPath)) {
    $signtool = Get-SignToolPath
    if ($signtool -and (Test-Path $msiPath)) {
        Write-Host 'Code-signing MSI...'
        & $signtool sign /f "$SignCertPath" /p "$SignCertPassword" /fd SHA256 /tr "$TimestampUrl" /td SHA256 "$msiPath"
    }
}

Write-Host "MSI created: $msiPath"


param(
    [string]$Runtime = 'win-x64',
    [string]$PublishDir = $(Join-Path (Resolve-Path '.') 'publish\win-x64'),
    [string]$OutDir = $(Join-Path (Resolve-Path '.') 'installer'),
    [string]$Version = '',
    [string]$SignCertPath = '',
    [string]$SignCertPassword = '',
    [string]$TimestampUrl = 'http://timestamp.digicert.com'
)

$ErrorActionPreference = 'Stop'

Write-Host '=== WindowsDCRC - Build Installer (WiX 3) ==='

New-Item -ItemType Directory -Force -Path $PublishDir | Out-Null
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

Write-Host 'Publishing app (Release, self-contained, single-file)...'
dotnet publish 'WindowsDCRC.csproj' -c Release -r $Runtime -o $PublishDir `
    -p:PublishSingleFile=true -p:SelfContained=true -p:PublishTrimmed=false -p:IncludeNativeLibrariesForSelfExtract=true | Out-Null

$exePath = Join-Path $PublishDir 'Windows DCRC.exe'
if (-not (Test-Path $exePath)) { throw "Publish output not found: $exePath" }

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

# WiX 3 binaries (portable)
$wix3Dir = Join-Path $env:TEMP 'wix3bin'
New-Item -ItemType Directory -Force -Path $wix3Dir | Out-Null
$candle = Join-Path $wix3Dir 'candle.exe'
$light = Join-Path $wix3Dir 'light.exe'
if (-not (Test-Path $candle) -or -not (Test-Path $light)) {
    Write-Host 'Downloading WiX 3 binaries...'
    $zip = Join-Path $wix3Dir 'wix311-binaries.zip'
    Invoke-WebRequest -Uri 'https://github.com/wixtoolset/wix3/releases/download/wix3112rtm/wix311-binaries.zip' -OutFile $zip -UseBasicParsing
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $wix3Dir)
}

$iconPath = Join-Path (Resolve-Path '.') 'Assets\app.ico'
$objPath = Join-Path $wix3Dir 'product.wixobj'
$msiPath = Join-Path $OutDir ("WindowsDCRC_" + $Version + ".msi")

Write-Host 'Building MSI with WiX 3...'
& $candle -nologo -ext WixUIExtension -ext WixUtilExtension -dPublishDir="$PublishDir" -dVersion="$Version" -dAppIconPath="$iconPath" -out $objPath 'installer/Product.v3.wxs'
& $light -nologo -ext WixUIExtension -ext WixUtilExtension -out $msiPath $objPath

if ($SignCertPath -and (Test-Path $SignCertPath)) {
    $sec = if ($SignCertPassword -is [securestring]) { $SignCertPassword } else { ConvertTo-SecureString -String $SignCertPassword -AsPlainText -Force }
    $signtool = (Get-Command 'signtool.exe' -ErrorAction SilentlyContinue).Source
    if ($signtool) {
        & $signtool sign /f "$SignCertPath" /p $SignCertPassword /fd SHA256 /tr "$TimestampUrl" /td SHA256 "$msiPath"
    }
}

Write-Host "MSI created: $msiPath"


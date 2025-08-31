Param(
    [string]$AssetsDir = "..\Assets",
    [string]$OutputIcon = "..\Assets\app.ico"
)

# Combine existing PNGs in Assets (named like AppImage_16x16.png, AppImage_256x256.png) into a multi-size .ico
Add-Type -AssemblyName System.Drawing

function Convert-ImagesToIco {
    param(
        [byte[][]]$PngImages,
        [int[]]$Sizes,
        [string]$Path
    )

    $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
    $bw = New-Object System.IO.BinaryWriter($fs)

    # ICONDIR
    $bw.Write([UInt16]0)
    $bw.Write([UInt16]1)
    $bw.Write([UInt16]$PngImages.Length)

    $dirEntrySize = 16
    $offset = 6 + ($dirEntrySize * $PngImages.Length)

    for ($i = 0; $i -lt $PngImages.Length; $i++) {
        $sz = $Sizes[$i]
        $data = $PngImages[$i]
        $bw.Write([Byte]($(if ($sz -ge 256) { 0 } else { $sz })))
        $bw.Write([Byte]($(if ($sz -ge 256) { 0 } else { $sz })))
        $bw.Write([Byte]0)
        $bw.Write([Byte]0)
        $bw.Write([UInt16]1)
        $bw.Write([UInt16]32)
        $bw.Write([UInt32]$data.Length)
        $bw.Write([UInt32]$offset)
        $offset += $data.Length
    }

    for ($i = 0; $i -lt $PngImages.Length; $i++) {
        $bw.Write($PngImages[$i])
    }

    $bw.Flush(); $bw.Dispose(); $fs.Dispose()
}

$assetsFull = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot $AssetsDir))
$outFull = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot $OutputIcon))

$files = Get-ChildItem -Path $assetsFull -Filter "AppImage_*x*.png" | Sort-Object Name
if (-not $files) {
    Write-Error "No AppImage_*x*.png files found in $assetsFull"
    exit 1
}

$sizes = New-Object System.Collections.Generic.List[int]
$pngs = New-Object System.Collections.Generic.List[byte[]]

foreach ($f in $files) {
    if ($f.BaseName -match 'AppImage_(\d+)x\1') {
        $s = [int]$Matches[1]
        $sizes.Add($s)
        $pngs.Add([System.IO.File]::ReadAllBytes($f.FullName))
    }
}

# Ensure the canonical sizes are included
$preferred = @(16, 24, 32, 48, 64, 128, 256)
$have = $sizes.ToArray()
$missing = $preferred | Where-Object { $_ -notin $have }
if ($missing.Count -gt 0) {
    Write-Warning ("Missing sizes: " + ($missing -join ", "))
}

Convert-ImagesToIco -PngImages $pngs.ToArray() -Sizes $sizes.ToArray() -Path $outFull
Write-Host "Icon built from PNGs:" $outFull



Param(
    [string]$OutputIcon = "..\Assets\app.ico"
)

# Generates a multi-size ICO showing multiple monitors with a cleaning brush overlay
# Sizes included: 16, 20, 24, 32, 48, 64, 128, 256

Add-Type -AssemblyName System.Drawing

function New-MonitorAndBrushBitmap {
    param(
        [int]$Size
    )

    $bmp = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

    # Colors
    $frame = [System.Drawing.Color]::FromArgb(255, 40, 40, 40)
    $screen1 = [System.Drawing.Color]::FromArgb(255, 66, 133, 244)  # blue
    $screen2 = [System.Drawing.Color]::FromArgb(255, 52, 168, 83)   # green
    $stand = [System.Drawing.Color]::FromArgb(255, 70, 70, 70)
    $brushHandle = [System.Drawing.Color]::FromArgb(255, 160, 82, 45) # brown
    $brushFerrule = [System.Drawing.Color]::FromArgb(255, 180, 180, 180) # metal
    $brushBristle = [System.Drawing.Color]::FromArgb(255, 240, 200, 60)

    $penFrame = New-Object System.Drawing.Pen($frame, [Math]::Max(1, [int]($Size * 0.04)))
    $brScreen1 = New-Object System.Drawing.SolidBrush($screen1)
    $brScreen2 = New-Object System.Drawing.SolidBrush($screen2)
    $brStand = New-Object System.Drawing.SolidBrush($stand)
    $brHandle = New-Object System.Drawing.SolidBrush($brushHandle)
    $brFerrule = New-Object System.Drawing.SolidBrush($brushFerrule)
    $brBristle = New-Object System.Drawing.SolidBrush($brushBristle)

    # Layout metrics
    $pad = [int]([Math]::Max(1, $Size * 0.07))
    $monitorW = [int]($Size * 0.55)
    $monitorH = [int]($Size * 0.38)
    $offset = [int]($Size * 0.18)

    # Back monitor (left)
    $rectBack = New-Object System.Drawing.Rectangle($pad, $pad + $offset, $monitorW, $monitorH)
    $g.FillRectangle($brScreen2, $rectBack)
    $g.DrawRectangle($penFrame, $rectBack)
    # Back stand
    $standW = [int]($monitorW * 0.18)
    $standH = [int]($monitorH * 0.18)
    $standRectBack = New-Object System.Drawing.Rectangle($rectBack.X + [int](($rectBack.Width - $standW) / 2), $rectBack.Bottom, $standW, [int]($standH * 0.6))
    $baseRectBack = New-Object System.Drawing.Rectangle($standRectBack.X - [int]($standW * 0.3), $standRectBack.Bottom, [int]($standW * 1.6), [int]($standH * 0.4))
    $g.FillRectangle($brStand, $standRectBack)
    $g.FillRectangle($brStand, $baseRectBack)

    # Front monitor (right, overlapping)
    $rectFront = New-Object System.Drawing.Rectangle($pad + $offset, $pad, $monitorW, $monitorH)
    $g.FillRectangle($brScreen1, $rectFront)
    $g.DrawRectangle($penFrame, $rectFront)
    # Front stand
    $standRect = New-Object System.Drawing.Rectangle($rectFront.X + [int](($rectFront.Width - $standW) / 2), $rectFront.Bottom, $standW, [int]($standH * 0.6))
    $baseRect = New-Object System.Drawing.Rectangle($standRect.X - [int]($standW * 0.3), $standRect.Bottom, [int]($standW * 1.6), [int]($standH * 0.4))
    $g.FillRectangle($brStand, $standRect)
    $g.FillRectangle($brStand, $baseRect)

    # Cleaning brush overlay (diagonal)
    $cx = [int]($Size * 0.62)
    $cy = [int]($Size * 0.70)
    $handleLen = [int]($Size * 0.55)
    $handleWidth = [int]([Math]::Max(2, $Size * 0.10))
    $angle = -35

    $state = $g.Save()
    $g.TranslateTransform($cx, $cy)
    $g.RotateTransform($angle)
    # Handle (rounded rectangle approximation with two circles)
    $handleRect = New-Object System.Drawing.Rectangle( - [int]($handleLen * 0.6), - [int]($handleWidth / 2), $handleLen, $handleWidth)
    $g.FillRectangle($brHandle, $handleRect)
    $capR = [int]($handleWidth / 2)
    $leftCap = New-Object System.Drawing.Rectangle($handleRect.X - $capR, - $capR, $handleWidth, $handleWidth)
    $rightCap = New-Object System.Drawing.Rectangle($handleRect.Right - $capR, - $capR, $handleWidth, $handleWidth)
    $g.FillEllipse($brHandle, $leftCap)
    $g.FillEllipse($brHandle, $rightCap)
    # Ferrule
    $ferruleRect = New-Object System.Drawing.Rectangle($handleRect.Right - [int]($handleWidth * 0.2), - [int]($handleWidth * 0.65), [int]($handleWidth * 0.35), [int]($handleWidth * 1.3))
    $g.FillRectangle($brFerrule, $ferruleRect)
    # Bristles (triangle)
    $bW = [int]($handleWidth * 1.2)
    $bH = [int]($handleWidth * 0.9)
    $p1 = New-Object System.Drawing.Point($ferruleRect.Right, 0)
    $p2 = New-Object System.Drawing.Point($ferruleRect.Right + $bW, - [int]($bH / 2))
    $p3 = New-Object System.Drawing.Point($ferruleRect.Right + $bW, [int]($bH / 2))
    $g.FillPolygon($brBristle, @($p1, $p2, $p3))
    $g.Restore($state)

    $g.Dispose()
    return $bmp
}

function Convert-ImagesToIco {
    param(
        [byte[][]]$PngImages,
        [int[]]$Sizes,
        [string]$Path
    )

    $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
    $bw = New-Object System.IO.BinaryWriter($fs)

    # ICONDIR
    $bw.Write([UInt16]0)      # reserved
    $bw.Write([UInt16]1)      # type = icon
    $bw.Write([UInt16]$PngImages.Length)

    $dirEntrySize = 16
    $offset = 6 + ($dirEntrySize * $PngImages.Length)

    for ($i = 0; $i -lt $PngImages.Length; $i++) {
        $sz = $Sizes[$i]
        $data = $PngImages[$i]
        $bw.Write([Byte]($(if ($sz -ge 256) { 0 } else { $sz }))) # width (0 means 256)
        $bw.Write([Byte]($(if ($sz -ge 256) { 0 } else { $sz }))) # height
        $bw.Write([Byte]0)   # color count
        $bw.Write([Byte]0)   # reserved
        $bw.Write([UInt16]1) # planes
        $bw.Write([UInt16]32) # bit count
        $bw.Write([UInt32]$data.Length) # size of image data
        $bw.Write([UInt32]$offset)      # offset of image data
        $offset += $data.Length
    }

    # Write image data blocks
    for ($i = 0; $i -lt $PngImages.Length; $i++) {
        $bw.Write($PngImages[$i])
    }

    $bw.Flush(); $bw.Dispose(); $fs.Dispose()
}

# Ensure output directory exists
$outFull = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot $OutputIcon))
$outDir = [System.IO.Path]::GetDirectoryName($outFull)
if (!(Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

$sizes = @(16, 20, 24, 32, 48, 64, 128, 256)
$pngBytes = New-Object System.Collections.Generic.List[byte[]]

foreach ($s in $sizes) {
    $bmp = New-MonitorAndBrushBitmap -Size $s
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $pngBytes.Add($ms.ToArray())
    $bmp.Dispose(); $ms.Dispose()
}

Convert-ImagesToIco -PngImages $pngBytes.ToArray() -Sizes $sizes -Path $outFull
Write-Host "Icon generated:" $outFull



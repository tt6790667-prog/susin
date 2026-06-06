Add-Type -AssemblyName System.Drawing

$inputPath = "c:\Users\T.DINESH\Desktop\APP\assets\susin-logo-padded.png"
$outputPath = "c:\Users\T.DINESH\Desktop\APP\assets\susin-logo-centered.png"

$img = [System.Drawing.Bitmap]::FromFile($inputPath)
$width = $img.Width
$height = $img.Height

Write-Output "Image size: $width x $height"

# Find the green line (searching from bottom to top)
$greenY = -1
for ($y = $height - 1; $y -ge 0; $y--) {
    # Sample a few pixels in the middle to find the green line
    $greenCount = 0
    for ($x = [int]($width * 0.3); $x -lt [int]($width * 0.7); $x++) {
        $pixel = $img.GetPixel($x, $y)
        # Green line detection: high G, lower R and B
        if ($pixel.G -gt 130 -and $pixel.R -lt 100 -and $pixel.B -lt 100) {
            $greenCount++
        }
    }
    # If we found a horizontal line with mostly green pixels
    if ($greenCount -gt ($width * 0.2)) {
        $greenY = $y
        break
    }
}

if ($greenY -eq -1) {
    Write-Output "Could not detect green line, defaulting to 80% height"
    $greenY = [int]($height * 0.8)
} else {
    Write-Output "Detected green line at Y = $greenY"
}

# Find the top of the red box (searching from top to bottom)
$redTopY = 0
for ($y = 0; $y -lt $height; $y++) {
    $redCount = 0
    for ($x = [int]($width * 0.3); $x -lt [int]($width * 0.7); $x++) {
        $pixel = $img.GetPixel($x, $y)
        if ($pixel.R -gt 150 -and $pixel.G -lt 100 -and $pixel.B -lt 100) {
            $redCount++
        }
    }
    if ($redCount -gt ($width * 0.2)) {
        $redTopY = $y
        break
    }
}
Write-Output "Detected red top at Y = $redTopY"

# Find the left and right boundaries of the red box
$redLeftX = 0
for ($x = 0; $x -lt $width; $x++) {
    $redCount = 0
    for ($y = $redTopY + 10; $y -lt $greenY; $y++) {
        $pixel = $img.GetPixel($x, $y)
        if ($pixel.R -gt 150 -and $pixel.G -lt 100 -and $pixel.B -lt 100) {
            $redCount++
        }
    }
    if ($redCount -gt 5) {
        $redLeftX = $x
        break
    }
}

$redRightX = $width - 1
for ($x = $width - 1; $x -ge 0; $x--) {
    $redCount = 0
    for ($y = $redTopY + 10; $y -lt $greenY; $y++) {
        $pixel = $img.GetPixel($x, $y)
        if ($pixel.R -gt 150 -and $pixel.G -lt 100 -and $pixel.B -lt 100) {
            $redCount++
        }
    }
    if ($redCount -gt 5) {
        $redRightX = $x
        break
    }
}

Write-Output "Detected red boundaries: X = $redLeftX to $redRightX"

# Crop boundaries
# We include the red top down to the green line plus a small margin (e.g. 5 pixels)
$cropTop = $redTopY - 10
if ($cropTop -lt 0) { $cropTop = 0 }

$cropBottom = $greenY + 8
if ($cropBottom -ge $height) { $cropBottom = $height - 1 }

$cropHeight = $cropBottom - $cropTop
$cropLeft = $redLeftX - 10
if ($cropLeft -lt 0) { $cropLeft = 0 }

$cropRight = $redRightX + 10
if ($cropRight -ge $width) { $cropRight = $width - 1 }

$cropWidth = $cropRight - $cropLeft

Write-Output "Cropping region: X=$cropLeft, Y=$cropTop, Width=$cropWidth, Height=$cropHeight"

# Create cropped image
$cropRect = New-Object System.Drawing.Rectangle($cropLeft, $cropTop, $cropWidth, $cropHeight)
$croppedImg = $img.Clone($cropRect, $img.PixelFormat)

# Create a new square bitmap to center the cropped image
# Standard size for launcher icon foreground/source is 512x512
$targetSize = [Math]::Max($cropWidth, $cropHeight) + 80 # Add padding
$newImg = New-Object System.Drawing.Bitmap($targetSize, $targetSize)
$g = [System.Drawing.Graphics]::FromImage($newImg)

# Fill background with white
$g.Clear([System.Drawing.Color]::White)

# Draw cropped image centered
$destX = [int](($targetSize - $cropWidth) / 2)
$destY = [int](($targetSize - $cropHeight) / 2)
$g.DrawImage($croppedImg, $destX, $destY)

# Save the centered image
$newImg.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)

# Clean up
$g.Dispose()
$newImg.Dispose()
$croppedImg.Dispose()
$img.Dispose()

Write-Output "Successfully saved centered image to $outputPath"

Add-Type -AssemblyName System.Drawing

$inputPath = "assets/susin-logo-hkea57kH.png"
$outputPath = "assets/susin-logo-padded.png"

if (-not (Test-Path $inputPath)) {
    Write-Output "Error: $inputPath not found"
    exit 1
}

$img = [System.Drawing.Bitmap]::FromFile($inputPath)
$width = $img.Width
$height = $img.Height

Write-Output "Original Image Size: $width x $height"

# We want the logo to fit within a 310x310 box inside a 512x512 canvas (Safe Zone is 324x324)
$targetCanvasSize = 512
$maxContentSize = 310

# Calculate scale factor
$scale = $maxContentSize / [Math]::Max($width, $height)
# Ensure we don't scale up if it is already smaller (though for 512x512 we want it to be exactly maxContentSize for consistency)
$newWidth = [int]($width * $scale)
$newHeight = [int]($height * $scale)

Write-Output "Resized Logo Size: $newWidth x $newHeight"

# Create a new transparent 512x512 bitmap
$newImg = New-Object System.Drawing.Bitmap($targetCanvasSize, $targetCanvasSize)
$g = [System.Drawing.Graphics]::FromImage($newImg)

# Enable high quality rendering
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

# Clear with transparent background
$g.Clear([System.Drawing.Color]::Transparent)

# Draw the resized logo centered
$destX = [int](($targetCanvasSize - $newWidth) / 2)
$destY = [int](($targetCanvasSize - $newHeight) / 2)

$g.DrawImage($img, $destX, $destY, $newWidth, $newHeight)

# Save the padded image
$newImg.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)

# Clean up
$g.Dispose()
$newImg.Dispose()
$img.Dispose()

Write-Output "Successfully generated transparent padded logo at $outputPath"

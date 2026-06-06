Add-Type -AssemblyName System.Drawing
$imagePath = Resolve-Path "assets/susin-logo-padded.png"
$img = [System.Drawing.Image]::FromFile($imagePath)
Write-Output "Width: $($img.Width)"
Write-Output "Height: $($img.Height)"
$img.Dispose()

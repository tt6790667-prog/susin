Add-Type -AssemblyName System.Drawing

function Inspect-Image($path) {
    if (Test-Path $path) {
        $img = [System.Drawing.Image]::FromFile($path)
        Write-Output "$path : $($img.Width) x $($img.Height)"
        $img.Dispose()
    } else {
        Write-Output "$path does not exist"
    }
}

Inspect-Image "assets/susin-logo-hkea57kH.png"
Inspect-Image "assets/susin-logo-padded.png"
Inspect-Image "assets/susin-logo-centered.png"
Inspect-Image "assets/s.png"

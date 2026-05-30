Set-Location C:\crazyflie

# Allow this venv activation only for this PowerShell window
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# Activate Crazyflie virtual environment
.\.venv\Scripts\Activate.ps1

# Make sure libusb DLL can be found
$env:PATH = "C:\crazyflie\.venv\Scripts;" + $env:PATH

Write-Host ""
Write-Host "Crazyflie environment ready." -ForegroundColor Green
Write-Host "You can now run:" -ForegroundColor Cyan
Write-Host "  python -m cfclient.gui"
Write-Host "  python hover_test.py"
Write-Host ""
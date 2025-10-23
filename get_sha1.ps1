# Get SHA-1 Fingerprint Script
# Run this in PowerShell to get your debug SHA-1 fingerprint

Write-Host "Getting SHA-1 Fingerprint for Debug Keystore..." -ForegroundColor Green
Write-Host ""

$debugKeystore = "$env:USERPROFILE\.android\debug.keystore"

if (Test-Path $debugKeystore) {
    Write-Host "Found debug keystore at: $debugKeystore" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "SHA-1 Fingerprint:" -ForegroundColor Cyan
    Write-Host ""
    
    & keytool -list -v -alias androiddebugkey -keystore $debugKeystore -storepass android -keypass android | Select-String -Pattern "SHA1|SHA256"
    
    Write-Host ""
    Write-Host "Copy the SHA1 fingerprint above and add it to Google Cloud Console:" -ForegroundColor Green
    Write-Host "1. Go to: https://console.cloud.google.com/apis/credentials" -ForegroundColor White
    Write-Host "2. Click on your API key" -ForegroundColor White
    Write-Host "3. Under 'Application restrictions', select 'Android apps'" -ForegroundColor White
    Write-Host "4. Click 'Add an item'" -ForegroundColor White
    Write-Host "5. Package name: com.example.scalp_mobile_app" -ForegroundColor White
    Write-Host "6. Paste the SHA-1 fingerprint" -ForegroundColor White
    Write-Host "7. Click 'Done' then 'Save'" -ForegroundColor White
    
} else {
    Write-Host "ERROR: Debug keystore not found!" -ForegroundColor Red
    Write-Host "Expected location: $debugKeystore" -ForegroundColor Red
    Write-Host ""
    Write-Host "The keystore will be created when you run 'flutter run' for the first time." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

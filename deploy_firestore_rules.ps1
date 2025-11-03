# Quick Deploy Firestore Rules Script
# Run this in PowerShell from project root

Write-Host "=== Firestore Rules Deployment ===" -ForegroundColor Cyan
Write-Host ""

# Check if firebase-tools is installed
$firebaseInstalled = Get-Command firebase -ErrorAction SilentlyContinue

if (-not $firebaseInstalled) {
    Write-Host "Firebase CLI not found. Installing..." -ForegroundColor Yellow
    npm install -g firebase-tools
} else {
    Write-Host "✓ Firebase CLI found" -ForegroundColor Green
}

Write-Host ""
Write-Host "Deploying Firestore rules to project: scalp-18928" -ForegroundColor Cyan
Write-Host ""

# Deploy rules
firebase deploy --only firestore:rules --project scalp-18928

Write-Host ""
Write-Host "=== Deployment Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Run: flutter clean && flutter pub get" -ForegroundColor White
Write-Host "2. Run: flutter run --uninstall-first" -ForegroundColor White
Write-Host "3. Test adding items to wishlist" -ForegroundColor White
Write-Host ""

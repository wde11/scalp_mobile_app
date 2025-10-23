# 🚀 Quick Start: Fix Google Maps Display

## Problem
Map screen shows blank/grey area instead of Google Maps.

## Root Cause
Google Maps API not properly configured in Google Cloud Console.

## ✅ What's Already Fixed
1. ✅ Android permissions added (INTERNET, ACCESS_FINE_LOCATION, etc.)
2. ✅ minSdk set to 21 (Google Maps requirement)
3. ✅ API key configured in AndroidManifest.xml
4. ✅ google_maps_flutter package installed

## ⚠️ What You MUST Do Now

### 🔴 CRITICAL: Enable APIs in Google Cloud (10 minutes)

#### Step 1: Enable Maps SDK for Android
1. Go to: https://console.cloud.google.com/apis/library
2. In the search box, type: **Maps SDK for Android**
3. Click on it
4. Click the blue **ENABLE** button
5. Wait 2-3 minutes for it to activate

#### Step 2: Enable Geocoding API
1. Go back to: https://console.cloud.google.com/apis/library
2. Search for: **Geocoding API**
3. Click **ENABLE**

#### Step 3: Check API Key Settings
1. Go to: https://console.cloud.google.com/apis/credentials
2. Find your API key: `AIzaSyDyqD1EGcOyf4Ypl3Cg3OUdpI70rYMo6QQ`
3. Click on it

**Option A: Quick Test (Unrestricted)**
- Set **Application restrictions** to: **None**
- Set **API restrictions** to: **Don't restrict key**
- Click **SAVE**
- ⚠️ This is ONLY for testing! Add restrictions after confirming it works.

**Option B: Secure (Recommended for production)**
- Continue to Step 4 below

### Step 4: Get SHA-1 Fingerprint (Optional but recommended)

Run this command in PowerShell from your project directory:
```powershell
.\get_sha1.ps1
```

Or manually:
```powershell
cd $env:USERPROFILE\.android
keytool -list -v -alias androiddebugkey -keystore debug.keystore -storepass android -keypass android
```

If "keystore not found":
1. Run `flutter run` once (even if map doesn't show)
2. Then try the command again
3. Copy the SHA1 fingerprint

### Step 5: Add SHA-1 to API Key
1. In Google Cloud Console → Credentials → Your API Key
2. Under **Application restrictions**:
   - Select: **Android apps**
   - Click **Add an item**
   - Package name: `com.example.scalp_mobile_app`
   - SHA-1 certificate fingerprint: (paste from Step 4)
   - Click **Done**
3. Under **API restrictions**:
   - Select: **Restrict key**
   - Check: **Maps SDK for Android**
   - Check: **Geocoding API**
4. Click **SAVE**

### Step 6: Test the App
```powershell
# Clean rebuild
flutter clean
flutter pub get

# Run on device
flutter run
```

## ⏱️ Expected Timeline
- API enablement: 2-5 minutes
- Changes to propagate: 5-10 minutes
- Total: ~15 minutes

## 🔍 Verification

After enabling APIs and waiting 5-10 minutes:

1. Run the app
2. Navigate to Map screen
3. You should see:
   - ✅ Google Maps tiles loading
   - ✅ Your location marker (blue dot)
   - ✅ Scavenger hunt item markers
   - ✅ Zoom controls working

If map is still blank:
1. Wait 10 more minutes (API changes can be slow)
2. Try with unrestricted API key temporarily
3. Check logs: `flutter logs` for error messages

## 📱 Device Requirements
- Android device/emulator with Google Play Services
- Location services enabled
- Internet connection

## 🆘 Still Not Working?

### Check API Status
Go to: https://console.cloud.google.com/apis/dashboard
- Should show "Maps SDK for Android" as enabled
- Check for any quota/billing issues

### Check Logs
```powershell
flutter run -v
```
Look for errors containing:
- "Authorization failure" → API key issue
- "API not enabled" → Wait longer or re-enable
- "Google Play Services" → Update Play Services on device

### Try Unrestricted Key
Temporarily remove ALL restrictions from your API key in Google Cloud Console to confirm it's a restriction issue.

## 📞 Support Resources
- [Google Maps Platform Support](https://developers.google.com/maps/support)
- [API Key Troubleshooting](https://developers.google.com/maps/documentation/android-sdk/get-api-key)
- See full guide: `GOOGLE_MAPS_SETUP_GUIDE.md`

---

**Next Step:** Go to https://console.cloud.google.com/apis/library and enable "Maps SDK for Android" now! 🚀

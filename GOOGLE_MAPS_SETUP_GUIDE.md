# Google Maps API Setup Guide

## ⚠️ Current Issues Fixed

1. ✅ Added required permissions to AndroidManifest.xml
2. ✅ Set minSdk to 21 (Google Maps requirement)
3. ✅ Google Maps API key configured in AndroidManifest.xml

## 🔧 Google Cloud Console Setup (REQUIRED)

### Step 1: Enable Required APIs

Your API key needs to have the following APIs enabled:

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project or create a new one
3. Navigate to **APIs & Services** → **Library**
4. Enable these APIs:
   - ✅ **Maps SDK for Android** (MOST IMPORTANT)
   - ✅ **Geocoding API** (for address lookups)
   - ✅ **Geolocation API** (for location services)
   - ✅ **Places API** (if using places features)

### Step 2: Verify API Key Restrictions

1. Go to **APIs & Services** → **Credentials**
2. Find your API key: `AIzaSyDyqD1EGcOyf4Ypl3Cg3OUdpI70rYMo6QQ`
3. Click on the key to edit it

#### Application Restrictions (Recommended)
- Select **Android apps**
- Add your package name: `com.example.scalp_mobile_app`
- Add your SHA-1 fingerprint (see below how to get it)

#### API Restrictions
- Select **Restrict key**
- Add these APIs:
  - Maps SDK for Android
  - Geocoding API
  - Geolocation API

### Step 3: Get SHA-1 Fingerprint

#### For Debug Build:
```powershell
# Windows (PowerShell)
cd $env:USERPROFILE\.android
keytool -list -v -alias androiddebugkey -keystore debug.keystore -storepass android -keypass android
```

#### For Release Build:
```powershell
keytool -list -v -alias YOUR_KEY_ALIAS -keystore PATH_TO_YOUR_KEYSTORE
```

Look for the line starting with `SHA1:` and copy that fingerprint.

### Step 4: Add SHA-1 to Google Cloud Console

1. In Google Cloud Console → **APIs & Services** → **Credentials**
2. Click on your API key
3. Under **Application restrictions**, add:
   - Package name: `com.example.scalp_mobile_app`
   - SHA-1 certificate fingerprint: (paste from previous step)

## 📱 Android Configuration Checklist

### ✅ AndroidManifest.xml
Located at: `android/app/src/main/AndroidManifest.xml`

```xml
<!-- These permissions are now added -->
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>

<!-- API Key is configured -->
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="AIzaSyDyqD1EGcOyf4Ypl3Cg3OUdpI70rYMo6QQ" />
```

### ✅ build.gradle.kts
Located at: `android/app/build.gradle.kts`

```kotlin
minSdk = 21  // Required for Google Maps
```

## 🔍 Common Issues & Solutions

### Issue 1: Blank/Grey Map Display
**Cause:** API key not enabled or restricted incorrectly

**Solutions:**
1. Ensure **Maps SDK for Android** is enabled in Google Cloud Console
2. Check if API key has correct restrictions (package name + SHA-1)
3. Wait 5-10 minutes after enabling APIs for changes to propagate

### Issue 2: "Authorization Failure" Error
**Cause:** API key restrictions don't match your app

**Solutions:**
1. Add your app's SHA-1 fingerprint to the API key
2. Verify package name matches: `com.example.scalp_mobile_app`
3. Try using an unrestricted key temporarily for testing

### Issue 3: Map Not Loading on Physical Device
**Cause:** Different SHA-1 for debug vs release builds

**Solutions:**
1. Get SHA-1 for your debug keystore (see above)
2. Add both debug AND release SHA-1 fingerprints to Google Cloud Console
3. Rebuild the app: `flutter clean && flutter run`

### Issue 4: Location Not Working
**Cause:** Runtime permissions not granted

**Solution:**
The app should request permissions at runtime. If not appearing:
1. Check device Settings → Apps → Your App → Permissions
2. Manually grant Location permissions
3. Restart the app

## 🚀 Testing Steps

### Step 1: Clean Build
```powershell
flutter clean
flutter pub get
```

### Step 2: Run on Device
```powershell
# Connect Android device via USB with USB debugging enabled
flutter run
```

### Step 3: Check Logs
```powershell
flutter logs
```

Look for errors like:
- "Authorization failure" → API key issue
- "Failed to load map" → API not enabled
- "Google Play Services not available" → Update Play Services on device

## 📋 Quick Verification Checklist

- [ ] Maps SDK for Android enabled in Google Cloud Console
- [ ] Geocoding API enabled
- [ ] API key has no restrictions OR has correct package name + SHA-1
- [ ] AndroidManifest.xml has all 4 permissions
- [ ] minSdk set to 21 or higher
- [ ] Google Play Services updated on test device
- [ ] Location permissions granted in device settings

## 🔐 API Key Security

### Current Key Location:
- `android/app/src/main/AndroidManifest.xml`

### For Production:
Consider moving the API key to:
1. `android/local.properties` (not committed to git)
2. Environment variables
3. Build config with different keys for debug/release

### Example (local.properties):
```properties
MAPS_API_KEY=AIzaSyDyqD1EGcOyf4Ypl3Cg3OUdpI70rYMo6QQ
```

Then in `build.gradle.kts`:
```kotlin
android {
    defaultConfig {
        val properties = Properties()
        properties.load(project.rootProject.file("local.properties").inputStream())
        manifestPlaceholders["MAPS_API_KEY"] = properties.getProperty("MAPS_API_KEY")
    }
}
```

## 📞 Getting Help

If the map still doesn't display after following all steps:

1. Check Google Cloud Console → **APIs & Services** → **Dashboard**
   - Look for API usage/errors
   
2. Run with verbose logging:
   ```powershell
   flutter run -v
   ```

3. Check Android Logcat for Google Maps errors:
   ```powershell
   adb logcat | Select-String "Google"
   ```

## 🔗 Useful Links

- [Google Maps Platform](https://console.cloud.google.com/google/maps-apis/)
- [Maps SDK for Android Documentation](https://developers.google.com/maps/documentation/android-sdk/overview)
- [API Key Best Practices](https://developers.google.com/maps/api-security-best-practices)
- [Flutter google_maps_flutter Package](https://pub.dev/packages/google_maps_flutter)

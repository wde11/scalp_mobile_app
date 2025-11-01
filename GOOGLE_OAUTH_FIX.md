# Google OAuth Sign-In Troubleshooting Guide

## Current Configuration

### From google-services.json:
- **Project ID**: scalp-18928
- **Package Name**: com.example.scalp_mobile_app
- **SHA-1 Certificate Hash**: b2c02ee2122d798a4c52e34db72f732609b95979
- **OAuth Client ID**: 819509773689-dabq1802ptvlnq4ml8erkbm7fursq685.apps.googleusercontent.com

## Common Issues & Solutions

### Issue 1: SHA-1 Fingerprint Mismatch
**Symptom**: Sign-In screen appears but immediately closes without error

**Root Cause**: The SHA-1 in google-services.json doesn't match your debug keystore

**Solution**:

#### Step 1: Get Your Current SHA-1
```powershell
# Find Java installation (needed for keytool)
$javaPath = (Get-Command java -ErrorAction SilentlyContinue).Source
if ($javaPath) {
    $javaHome = Split-Path (Split-Path $javaPath)
    $keytool = Join-Path $javaHome "bin\keytool.exe"
    
    if (Test-Path $keytool) {
        & $keytool -list -v -alias androiddebugkey -keystore "$env:USERPROFILE\.android\debug.keystore" -storepass android -keypass android
    }
}
```

#### Step 2: Add SHA-1 to Firebase
1. Copy the SHA1 fingerprint from the output above
2. Go to [Firebase Console](https://console.firebase.google.com/)
3. Select project: **scalp-18928**
4. Go to **Project Settings** (gear icon)
5. Scroll down to "Your apps" section
6. Find your Android app: `com.example.scalp_mobile_app`
7. Click **Add fingerprint**
8. Paste your SHA-1
9. Click **Save**
10. Download the NEW `google-services.json`
11. Replace `android/app/google-services.json` with the new file
12. Run: `flutter clean && flutter run`

### Issue 2: OAuth Client Not Configured in Google Cloud
**Symptom**: "Developer Error" or "Error 10" in sign-in screen

**Solution**:

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select project (should auto-select scalp-18928)
3. Navigate to **APIs & Services** → **Credentials**
4. Look for OAuth 2.0 Client IDs
5. You should see an Android client with:
   - Package name: `com.example.scalp_mobile_app`
   - SHA-1: `b2c02ee2122d798a4c52e34db72f732609b95979`

If not found, create one:
1. Click **+ CREATE CREDENTIALS** → **OAuth 2.0 Client ID**
2. Application type: **Android**
3. Name: "Android client (auto created by Google Service)"
4. Package name: `com.example.scalp_mobile_app`
5. SHA-1 certificate fingerprint: (paste from Step 1 above)
6. Click **CREATE**

### Issue 3: OAuth Consent Screen Not Configured
**Symptom**: Error about consent screen

**Solution**:
1. Go to **APIs & Services** → **OAuth consent screen**
2. If not configured:
   - User Type: **External**
   - App name: **Scalp Mobile App**
   - User support email: (your email)
   - Developer contact: (your email)
   - Click **SAVE AND CONTINUE**
3. Scopes: Skip this section (click **SAVE AND CONTINUE**)
4. Test users: Add your Google account email
5. Click **SAVE AND CONTINUE**

### Issue 4: Google Sign-In Plugin Issues
**Symptom**: SignInHubActivity appears then closes

**Solutions**:

#### A. Check google_sign_in version
In `pubspec.yaml`, ensure you have:
```yaml
google_sign_in: ^7.2.0
```

#### B. Clear app data
```powershell
# Uninstall and reinstall
flutter clean
flutter run --uninstall-first
```

#### C. Check for multiple Google accounts
- The device might have multiple Google accounts
- Sign-In might be failing silently
- Try signing out of all Google accounts on device first

### Issue 5: Firebase Auth Not Linked
**Symptom**: Google sign-in works but Firebase auth fails

**Solution**:
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select **scalp-18928**
3. Go to **Authentication** → **Sign-in method**
4. Ensure **Google** is enabled
5. Web SDK configuration should show your Web client ID

## Enhanced Debug Logs

The code now includes detailed logging. Run the app and watch for:

```
Starting Google Sign-In...
Using Android/iOS sign-in method
Attempting to sign in...
```

Then one of:
- `User cancelled sign-in` - User backed out
- `Google user obtained: [email]` - Got Google account
- `ERROR in _signInWithGoogle: [error]` - See specific error

## Testing Steps

### 1. Run with Verbose Logging
```powershell
flutter run -v
```

### 2. Watch for These Logs
```
Starting Google Sign-In...
Using Android/iOS sign-in method
Attempting to sign in...
Google user obtained: user@gmail.com
Getting authentication...
Got authentication - accessToken: true, idToken: true
Signing in with credential...
Sign-in successful! User: user@gmail.com
User document created/updated
```

### 3. Check for Errors
```powershell
# In another terminal while app is running
adb logcat | findstr "GoogleSignIn"
adb logcat | findstr "FirebaseAuth"
```

## Quick Fix Checklist

- [ ] Run `flutter clean && flutter pub get`
- [ ] Ensure Google Sign-In is enabled in Firebase Console → Authentication
- [ ] Verify SHA-1 matches between your keystore and Firebase/Google Cloud
- [ ] Download latest google-services.json from Firebase
- [ ] Check OAuth consent screen is configured
- [ ] Test with only one Google account on device
- [ ] Try `flutter run --uninstall-first`

## Getting Your SHA-1 (Alternative Methods)

### Method 1: Using Gradle (Easiest)
```powershell
cd android
.\gradlew signingReport
```
Look for SHA1 under "Variant: debug"

### Method 2: Using Android Studio
1. Open project in Android Studio
2. Click **Gradle** tab (right side)
3. Expand **android** → **Tasks** → **android**
4. Double-click **signingReport**
5. Check **Run** window for SHA1

### Method 3: Using JDK directly
Find where Java is installed:
```powershell
where java
# Output: C:\Program Files\Java\jdk-17\bin\java.exe

# Use that path to find keytool
& "C:\Program Files\Java\jdk-17\bin\keytool.exe" -list -v -alias androiddebugkey -keystore "$env:USERPROFILE\.android\debug.keystore" -storepass android -keypass android
```

## Expected OAuth Flow

1. User taps "Sign in with Google"
2. Loading indicator shows
3. SignInHubActivity (Google's UI) appears
4. User selects Google account
5. SignInHubActivity closes
6. App shows loading
7. Firebase auth completes
8. User redirected to Dashboard

If any step fails, check logs for errors.

## Web Client ID (if needed)

Sometimes you need to explicitly provide the Web Client ID:

```dart
final GoogleSignIn googleSignIn = GoogleSignIn(
  serverClientId: '819509773689-8kttj4knkgtcjb06m44itd89u0uuet9v.apps.googleusercontent.com',
  scopes: [
    'email',
    'https://www.googleapis.com/auth/userinfo.profile',
  ],
);
```

The Web Client ID from your google-services.json is:
`819509773689-8kttj4knkgtcjb06m44itd89u0uuet9v.apps.googleusercontent.com`

## Support Resources

- [Firebase Auth Troubleshooting](https://firebase.google.com/docs/auth/android/google-signin#troubleshooting)
- [Google Sign-In for Android](https://developers.google.com/identity/sign-in/android/start)
- [Flutter google_sign_in Package](https://pub.dev/packages/google_sign_in)

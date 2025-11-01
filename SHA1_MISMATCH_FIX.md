# 🔴 URGENT: Google OAuth SHA-1 Mismatch Fix

## ⚠️ Problem Identified

Your Google OAuth is failing because of a **SHA-1 certificate mismatch**:

**Your actual SHA-1 (from debug.keystore):**
```
5E:44:A5:45:3E:7B:BF:EA:C6:6D:1B:94:CB:6D:3B:E3:96:58:F9:86
```

**SHA-1 in google-services.json:**
```
B2:C0:2E:E2:12:2D:79:8A:4C:52:E3:4D:B7:2F:73:26:09:B9:59:79
```

❌ **These don't match! This is why Google Sign-In opens but doesn't complete.**

## 🔧 Fix (5 minutes)

### Step 1: Add Correct SHA-1 to Firebase

1. Go to: https://console.firebase.google.com/
2. Select project: **scalp-18928**
3. Click ⚙️ **Project Settings**
4. Scroll to "Your apps" → Find **com.example.scalp_mobile_app** (Android)
5. Under "SHA certificate fingerprints", click **Add fingerprint**
6. Paste this SHA-1:
   ```
   5E:44:A5:45:3E:7B:BF:EA:C6:6D:1B:94:CB:6D:3B:E3:96:58:F9:86
   ```
7. Click **Save**

### Step 2: Download Updated google-services.json

1. Still in Firebase Console → Project Settings
2. Scroll down to your Android app
3. Click **google-services.json** download button
4. Replace the file at: `android/app/google-services.json`

### Step 3: Clean and Rebuild

```powershell
flutter clean
flutter pub get
flutter run --uninstall-first
```

### Step 4: Test Google Sign-In

1. Open the app
2. Click "Sign in with Google"
3. Select your Google account
4. Should now successfully sign in! ✅

## 🔍 Why This Happened

The `google-services.json` file was generated with a different debug keystore SHA-1 than the one currently on your machine. This commonly happens when:
- Developing on multiple machines
- Reinstalling Android SDK
- Using a different user account

## ✅ Verification

After following the steps above, you should see these logs:

```
I/flutter: Starting Google Sign-In...
I/flutter: Using Android/iOS sign-in method
I/flutter: Attempting to sign in...
I/flutter: Google user obtained: user@gmail.com
I/flutter: Getting authentication...
I/flutter: Got authentication - accessToken: true, idToken: true
I/flutter: Signing in with credential...
I/flutter: Sign-in successful! User: user@gmail.com
I/flutter: User document created/updated
```

## 🚀 Alternative: Quick Test with Google Cloud Console

If you want to test immediately without downloading new google-services.json:

1. Go to: https://console.cloud.google.com/apis/credentials
2. Find OAuth 2.0 Client ID for Android (or create one)
3. Edit it
4. Under "SHA-1 certificate fingerprints", add:
   ```
   5E:44:A5:45:3E:7B:BF:EA:C6:6D:1B:94:CB:6D:3B:E3:96:58:F9:86
   ```
5. Click **Save**
6. Wait 5 minutes for changes to propagate
7. Run: `flutter run --uninstall-first`

## 📝 For Future Reference

Keep this SHA-1 saved:
```
Debug SHA-1: 5E:44:A5:45:3E:7B:BF:EA:C6:6D:1B:94:CB:6D:3B:E3:96:58:F9:86
SHA-256: 9B:8E:39:19:7E:B7:9F:3E:9C:C4:A0:7B:66:4F:36:2E:DB:BB:06:C9:D3:50:BD:88:81:78:1B:36:1D:20:BD:72
Keystore: C:\Users\Administrator\.android\debug.keystore
Valid until: October 25, 2055
```

To get SHA-1 again anytime:
```powershell
cd android
.\gradlew signingReport
```

---

**Next Action**: Add the SHA-1 `5E:44:A5:45:3E:7B:BF:EA:C6:6D:1B:94:CB:6D:3B:E3:96:58:F9:86` to Firebase Console NOW! 🔥

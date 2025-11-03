# Google Maps Not Displaying - Fix Guide

## Error Analysis

### Error Message:
```
W/ImageReader_JNI: Unable to acquire a buffer item, very likely client tried to acquire more than maxImages buffers
```

### What This Means:
- The Google Maps widget is trying to render but fails
- Map tiles cannot be loaded
- The Maps SDK for Android API is **NOT enabled** in Google Cloud Console

## Root Cause

Your Android manifest has the API key configured correctly:
```xml
<meta-data android:name="com.google.android.geo.API_KEY"
    android:value="AIzaSyDyqD1EGcOyf4Ypl3Cg3OUdpI70rYMo6QQ"/>
```

However, this API key doesn't have access to the Maps SDK for Android API because **the API is not enabled** in Google Cloud Console.

## Solution: Enable Maps SDK for Android

### Step 1: Go to Google Cloud Console
1. Visit: https://console.cloud.google.com/
2. Select your project (should be linked to your Firebase project `scalp-18928`)

### Step 2: Enable Maps SDK for Android
1. Go to: https://console.cloud.google.com/apis/library
2. Search for: **"Maps SDK for Android"**
3. Click on **"Maps SDK for Android"**
4. Click the blue **"ENABLE"** button
5. Wait for confirmation (usually instant)

### Step 3: Verify API Key Restrictions (Optional but Recommended)

**Important:** Your API key should have proper restrictions to prevent unauthorized use.

1. Go to: https://console.cloud.google.com/apis/credentials
2. Find your API key: `AIzaSyDyqD1EGcOyf4Ypl3Cg3OUdpI70rYMo6QQ`
3. Click on the key name
4. Under "API restrictions":
   - Select **"Restrict key"**
   - Enable the following APIs:
     - ✅ Maps SDK for Android
     - ✅ Directions API (for route drawing)
     - ✅ Geocoding API (for address lookup)
     - ✅ Places API (if you use place search)
5. Under "Application restrictions":
   - Select **"Android apps"**
   - Add your package name: `com.example.scalp_mobile_app`
   - Add SHA-1 fingerprint: `5E:44:A5:45:3E:7B:BF:EA:C6:6D:1B:94:CB:6D:3B:E3:96:58:F9:86`
6. Click **"Save"**

### Step 4: Hot Restart the App

After enabling the API, restart your app:

```bash
# In your terminal where the app is running, press:
R
```

(Capital R for full restart)

## Verification Steps

### 1. Check Console Output
After hot restart, you should **NOT** see:
```
W/ImageReader_JNI: Unable to acquire a buffer item
```

### 2. Visual Verification
- Map should display properly with tiles
- You should see streets, buildings, etc.
- Scavenger hunt markers should appear (orange pins)
- Your current location marker should show

### 3. Test Map Interactions
- ✅ Pan around the map
- ✅ Zoom in/out
- ✅ Tap on scavenger hunt markers
- ✅ View marker details in bottom sheet

## If Map Still Doesn't Show

### Check 1: Wait for API Propagation
- Sometimes it takes 1-2 minutes for the API to be fully enabled
- Close and restart the app completely

### Check 2: Verify Billing is Enabled
1. Go to: https://console.cloud.google.com/billing
2. Make sure billing is enabled for your project
3. Google Maps requires billing to be enabled (has free tier)

**Free Tier Limits:**
- 28,000 map loads per month (FREE)
- $200 monthly credit
- More than enough for development and testing

### Check 3: Check API Key in Console
1. Go to: https://console.cloud.google.com/apis/credentials
2. Verify API key exists and is not restricted incorrectly
3. Make sure "Maps SDK for Android" is in the enabled APIs list

### Check 4: Logcat for Specific Errors
If map still doesn't show, check logcat for specific error messages:

```bash
# In Android Studio or terminal
adb logcat | grep -i "maps\|google"
```

Look for error messages like:
- "API key not valid"
- "This API key is not authorized"
- "Billing must be enabled"

## Additional Configuration

### Enable Other Useful APIs (Optional)

While you're in the API Library, consider enabling:

1. **Directions API**
   - For route drawing between locations
   - Used in your transaction tracking feature

2. **Geocoding API**
   - For converting coordinates to addresses
   - Used to show street names

3. **Places API**
   - For location search
   - If you want to add place autocomplete

## Map Features in Your App

Your map screen includes:

1. **Current Location Tracking**
   - Blue marker shows your position
   - Auto-updates as you move

2. **Scavenger Hunt Items**
   - Orange markers for available items
   - Green markers for items you claimed
   - Red markers for items claimed by others
   - Tap marker to see details

3. **Transaction Tracking**
   - Shows seller location
   - Draws route with blue polyline
   - Shows distance and duration

4. **Location Sharing**
   - Share your location in chat
   - Receiver sees your location on map

## Testing Checklist

After enabling the API:

- [ ] Hot restart app (Press R)
- [ ] Map displays with tiles
- [ ] No "ImageReader_JNI" error in console
- [ ] Can see streets and buildings
- [ ] Can pan and zoom
- [ ] Scavenger hunt markers appear
- [ ] Can tap markers to see details
- [ ] Current location shows correctly

## Cost Considerations

**Don't worry about costs during development:**

- First $200 per month is FREE (Google Cloud credit)
- 28,000 map loads per month are FREE
- Additional usage is very cheap ($7 per 1,000 loads after free tier)
- Development usage typically stays well within free tier

**To monitor usage:**
1. Go to: https://console.cloud.google.com/apis/dashboard
2. Select "Maps SDK for Android"
3. View usage charts and quota

## Summary

**Main Issue:** Maps SDK for Android API is not enabled

**Solution Steps:**
1. ✅ Go to https://console.cloud.google.com/apis/library
2. ✅ Search "Maps SDK for Android"
3. ✅ Click ENABLE
4. ✅ Hot restart app (Press R)

**Expected Result:** Map displays properly with no errors

This is the same issue mentioned in your TODO list - now you know exactly why it's needed! 🗺️

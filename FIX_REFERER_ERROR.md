# Fixing Google Maps RefererNotAllowedMapError

## Problem
```
Google Maps JavaScript API error: RefererNotAllowedMapError
Your site URL to be authorized: http://localhost:56117/
```

This error occurs because your API key is restricted, and the localhost URL where your Flutter web app is running is not authorized.

## Solution: Add Localhost to API Key Restrictions

### Step 1: Go to Google Cloud Console
1. Visit https://console.cloud.google.com
2. Select your project
3. Go to **Credentials** in the left sidebar

### Step 2: Find Your API Key
1. Look for the API key you created (the one used in your app: `AIzaSyDyqD1EGcOyf4Ypl3Cg3OUdpI70rYMo6QQ`)
2. Click on it to edit

### Step 3: Update Application Restrictions
1. Find the **Application restrictions** section
2. Select **HTTP referrers (web sites)**
3. Add the following URLs to the list:
   - `http://localhost/*`
   - `http://localhost:*/*`
   - `http://127.0.0.1/*`
   - `http://127.0.0.1:*/*`

### Step 4: Save Changes
1. Click **Save** at the bottom
2. Wait 1-2 minutes for changes to propagate

## Alternative: Remove Restrictions (Development Only)
If you're in early development, you can temporarily remove restrictions:
1. In Application restrictions, select **None. Don't restrict key**
2. Save changes

⚠️ **Warning**: This allows anyone with your API key to use Google Maps. Only do this for development. Add proper restrictions before deploying to production.

## Test Again
1. Stop the running app: `Ctrl+C`
2. Run the app again: `flutter run -d chrome`
3. The map should now load without the RefererNotAllowedMapError

## Why This Happens
- Your API key is set to restrict which websites can use it
- Flutter web runs on a local development server (localhost)
- Each time you run the app, it can use a different port (56117, 56118, etc.)
- The API key doesn't recognize localhost as an authorized referrer

## Permanent Solution for Production
When deploying to production:
1. Replace localhost restrictions with your actual domain (e.g., `example.com/*`)
2. Use SSL/HTTPS (recommended)
3. Use separate API keys for development and production

---

For more information: https://developers.google.com/maps/documentation/javascript/error-messages#referer-not-allowed-map-error

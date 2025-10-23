# Firestore Security Rules Setup

## Deploying the Rules

### Option 1: Using Firebase Console (Recommended for beginners)
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **scalp-18928**
3. Navigate to **Firestore Database** → **Rules**
4. Copy the contents of `firestore.rules` and paste it into the editor
5. Click **Publish**

### Option 2: Using Firebase CLI
```bash
# Install Firebase CLI if you haven't already
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase in your project (if not done already)
firebase init firestore

# Deploy the rules
firebase deploy --only firestore:rules
```

## Setting Up Admin Users

To allow certain users to create/update/delete scavenger hunt items, you need to set custom claims:

### Using Firebase Admin SDK (Node.js example):
```javascript
const admin = require('firebase-admin');
admin.initializeApp();

// Set admin claim for a user
admin.auth().setCustomUserClaims('USER_UID_HERE', { admin: true })
  .then(() => {
    console.log('Admin claim set successfully');
  });
```

### Using Firebase Console (Manual):
1. Go to Firebase Console → Authentication
2. Find the user you want to make admin
3. Click on the user
4. Scroll down to "Custom claims"
5. Add: `{"admin": true}`

**Note:** Users need to sign out and sign back in for custom claims to take effect.

## Security Rules Explained

### Users Collection
- **Read**: Any authenticated user can read user profiles
- **Create**: Users can only create their own profile
- **Update/Delete**: Users can only modify their own profile, or admins can modify any

### Listings Collection
- **Read**: Anyone can view listings (public)
- **Create**: Authenticated users can create listings
- **Update/Delete**: Only the listing owner or admins can modify/delete

### Scavenger Hunt Items Collection
- **Read**: Anyone can view items (public)
- **Create/Update/Delete**: Only users with admin custom claim

### User Claims Collection
- **Read**: Users can only read their own claimed items
- **Create/Update/Delete**: Users can only manage their own claims

### Chats Collection
- **Read/Write**: Only participants in the chat can access it
- Messages are accessible only to chat participants

### Carts Collection
- **Read/Write**: Users can only access their own cart and cart items

## Testing the Rules

You can test the rules in the Firebase Console:
1. Go to Firestore Database → Rules
2. Click on the **Rules Playground** tab
3. Select authentication status and simulate read/write operations

## Google Maps Setup

The Google Maps API key is already configured in `android/app/src/main/AndroidManifest.xml`:
```xml
<meta-data 
    android:name="com.google.android.geo.API_KEY" 
    android:value="AIzaSyDyqD1EGcOyf4Ypl3Cg3OUdpI70rYMo6QQ" />
```

### For iOS (if needed):
Add to `ios/Runner/AppDelegate.swift`:
```swift
import GoogleMaps

GMSServices.provideAPIKey("AIzaSyDyqD1EGcOyf4Ypl3Cg3OUdpI70rYMo6QQ")
```

## Package Requirements

The following packages are installed for Google Maps:
- `google_maps_flutter: ^2.7.8` - Google Maps widget
- `geolocator: ^13.0.1` - Location services
- `geocoding: ^2.1.1` - Address geocoding

Run `flutter pub get` after any changes to `pubspec.yaml`.

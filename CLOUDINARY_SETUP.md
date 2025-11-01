# Cloudinary Setup Guide

## Current Configuration
- Cloud Name: `dp5mqhd9w`
- Upload Preset: `unsigned_preset`

## Setup Steps

### 1. Create an Unsigned Upload Preset

1. Go to [Cloudinary Console](https://console.cloudinary.com/)
2. Navigate to **Settings** → **Upload**
3. Scroll down to **Upload presets**
4. Click **Add upload preset**
5. Set the following:
   - **Preset name**: `unsigned_preset`
   - **Signing mode**: Select **Unsigned**
   - **Folder**: `listings` (optional but recommended)
   - **Access mode**: Public
   - Click **Save**

### 2. Alternative: Use an Existing Preset

If you want to use a different preset:
1. Go to Upload presets in Cloudinary dashboard
2. Find an existing unsigned preset
3. Copy its name
4. Update the code in `listing_screen.dart`:
   ```dart
   final cloudinary = CloudinaryPublic('dp5mqhd9w', 'YOUR_PRESET_NAME', cache: false);
   ```

### 3. Verify CORS Settings

1. In Cloudinary Console, go to **Settings** → **Security**
2. Under **Allowed fetch domains**, ensure your domain is listed
3. For local development, you may need to add `localhost`

## Current Behavior

The app has been updated to:
- ✅ Continue creating listings even if image upload fails
- ✅ Use a placeholder image if Cloudinary upload fails
- ✅ Show a helpful error message about Cloudinary configuration
- ✅ Support both web and mobile platforms
- ✅ Check user authentication before creating listings

## Testing

1. **Test without image**: Create a listing without selecting an image
2. **Test with image**: 
   - After configuring the upload preset
   - Select an image and create a listing
   - If it fails, check the error message in the console

## Firestore Security Rules

Make sure your Firestore rules allow authenticated users to write:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /listings/{listing} {
      allow read: if true;
      allow create: if request.auth != null;
      allow update, delete: if request.auth != null && request.auth.uid == resource.data.userId;
    }
  }
}
```

## Troubleshooting

### Error: 400 Bad Request
- The upload preset doesn't exist or is not configured correctly
- Solution: Create the unsigned preset as described above

### Error: Permission Denied
- Firestore security rules are blocking the write
- Solution: Update rules in Firebase Console

### Image not uploading
- Check that the preset name matches exactly
- Verify the preset is set to "Unsigned"
- Check browser console for detailed errors

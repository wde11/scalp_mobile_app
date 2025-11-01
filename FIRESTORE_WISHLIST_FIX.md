# Firestore Wishlist Permission Fix

## Error Details
```
Status{code=PERMISSION_DENIED, description=Missing or insufficient permissions.}
Query(wishlists/huxD2yRwFiM6p2mV9Poh9rUXunR2/items/vd3ePUUl8OAZFzuKiv5j)
```

## Root Cause
The Firestore security rules require that the `userId` in the path matches the authenticated user's ID. The current rules are correct, but we need to ensure they're properly deployed.

## Fix Steps

### Step 1: Update Firestore Rules (CRITICAL)

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **scalp-18928**
3. Click on **Firestore Database** in the left menu
4. Click on the **Rules** tab
5. **Replace ALL the rules** with the content from your local `firestore.rules` file:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Users collection - users can read/write their own data
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }

    // Wishlists collection
    match /wishlists/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;

      // Items subcollection within a user's wishlist
      match /items/{wishlistItemId} {
        allow read, create, update, delete: if request.auth != null && request.auth.uid == userId;
      }
    }
    
    // Listings collection
    match /listings/{listing} {
      // Anyone can read listings
      allow read: if true;
      
      // Only authenticated users can create listings
      allow create: if request.auth != null && 
                      request.resource.data.userId == request.auth.uid;
      
      // Only the owner can update or delete their listings
      allow update, delete: if request.auth != null && 
                               resource.data.userId == request.auth.uid;
    }
    
    // Chats collection
    match /chats/{chatId} {
      // Users can read chats they are part of
      allow read: if request.auth != null && 
                     (request.auth.uid in resource.data.participants ||
                      chatId.matches('.*' + request.auth.uid + '.*'));
      
      // Users can create chats if they are one of the participants
      allow create: if request.auth != null && 
                       request.auth.uid in request.resource.data.participants;
      
      // Users can update chats they are part of
      allow update: if request.auth != null && 
                       request.auth.uid in resource.data.participants;
      
      // Messages subcollection
      match /messages/{messageId} {
        // Users can read messages in chats they are part of
        allow read: if request.auth != null && 
                       request.auth.uid in get(/databases/$(database)/documents/chats/$(chatId)).data.participants;
        
        // Users can create messages in chats they are part of
        allow create: if request.auth != null && 
                         request.auth.uid in get(/databases/$(database)/documents/chats/$(chatId)).data.participants &&
                         request.resource.data.senderId == request.auth.uid;
        
        // Users can update/delete their own messages
        allow update, delete: if request.auth != null && 
                                 resource.data.senderId == request.auth.uid;
      }
    }

    // Scavenger Hunt Items collection
    match /scavenger_hunt_items/{itemId} {
      // Anyone can read scavenger hunt items
      allow read: if true;
      
      // Only admins can create, update, or delete items
      allow create, update, delete: if request.auth != null && 
                                      request.auth.token.get('admin', false) == true;
    }
    
    // User claims/collected items tracking
    match /user_claims/{claimId} {
      // Users can only read their own claims
      allow read: if request.auth != null && 
                     resource.data.userId == request.auth.uid;
      
      // Users can create claims for themselves
      allow create: if request.auth != null && 
                      request.resource.data.userId == request.auth.uid;
      
      // Users can update/delete their own claims
      allow update, delete: if request.auth != null && 
                              resource.data.userId == request.auth.uid;
    }
  }
}
```

6. Click **Publish** button

### Step 2: Verify Authentication

Make sure you're signed in to the app:

1. Open the app
2. Go to Login screen
3. Sign in with Google or email/password
4. Verify you see your profile in the app

### Step 3: Test Wishlist

1. Go to Listing screen
2. Click on any listing to open details
3. Click "Add to Wishlist"
4. Should see success message: "[Item name] added to wishlist!"
5. Go to "My Wishlist" screen to verify item was added

### Step 4: Debugging (If still not working)

Check the actual user ID being used:

1. Run the app with: `flutter run`
2. Watch the console/logs
3. You should see print statements showing the user ID and operations

The error message shows:
- User ID: `huxD2yRwFiM6p2mV9Poh9rUXunR2`
- Listing ID: `vd3ePUUl8OAZFzuKiv5j`

Make sure this user ID matches your authenticated user in Firebase Console:
1. Go to Firebase Console → Authentication
2. Find your user account
3. Check if the UID matches `huxD2yRwFiM6p2mV9Poh9rUXunR2`

## Common Issues

### Issue 1: Rules Not Published
**Solution**: Make sure you clicked "Publish" in Firestore Rules tab

### Issue 2: Wrong User ID
**Solution**: 
- Sign out and sign back in
- Check Firebase Authentication console for correct UID
- Verify `FirebaseAuth.instance.currentUser?.uid` matches the path

### Issue 3: Not Authenticated
**Solution**: 
- Ensure you're logged in
- Check if `FirebaseAuth.instance.currentUser` is not null
- Try signing out and signing back in

### Issue 4: Indexes Not Created
If you get "index required" error:
1. Click the link in the error message
2. It will auto-create the required index
3. Wait 2-3 minutes for index to build

## Testing Checklist

- [ ] Firestore Rules published in Firebase Console
- [ ] User is authenticated (can see profile)
- [ ] User UID matches the path in error message
- [ ] Can add items to wishlist without error
- [ ] Can view wishlist items
- [ ] Can remove items from wishlist
- [ ] Can contact seller from wishlist

## Firebase Console URLs

- **Firestore Rules**: https://console.firebase.google.com/project/scalp-18928/firestore/rules
- **Authentication**: https://console.firebase.google.com/project/scalp-18928/authentication/users
- **Firestore Data**: https://console.firebase.google.com/project/scalp-18928/firestore/data

## Need More Help?

If the issue persists:
1. Take a screenshot of the full error in the console
2. Check Firebase Console → Firestore → Data to see if the document was created
3. Verify the rules are actually published (check the "Last published" timestamp)

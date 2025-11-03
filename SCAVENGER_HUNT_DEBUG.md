# Scavenger Hunt Items Not Showing - Debugging Guide

## Issue
Created scavenger hunt items are not appearing in the "Manage Scavenger Hunt Items" dialog.

## Changes Made

### 1. Added Error Handling in Dashboard (`dashboard_screen.dart`)
Added error handling to the StreamBuilder to catch and display any errors:

```dart
if (snapshot.hasError) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24.0),
      child: Text(
        'Error loading items: ${snapshot.error}',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.red),
      ),
    ),
  );
}
```

### 2. Added Debug Logging in Service (`scavenger_hunt_service.dart`)

**In `createScavengerHuntItem()`:**
- Logs item details before creation
- Logs document ID after creation
- Logs notification status

**In `getAllItems()`:**
- Logs total items retrieved
- Logs each item's ID and title
- Logs final count of mapped items

## How to Debug

### Step 1: Test Creation
1. Run the app: `flutter run`
2. Navigate to Dashboard
3. Click "Create" button in Scavenger Hunt card
4. Fill in all fields and click "Create & Notify Users"
5. Watch the console for these logs:

```
=== CREATING SCAVENGER HUNT ITEM ===
Title: [your title]
Price: [your price]
Quantity: [quantity]
Event Duration: [duration] minutes
Event End Time: [timestamp]
Item created with ID: [document-id]
Notifications sent to all users
```

### Step 2: Test Retrieval
1. Click "Manage" button
2. Watch console for:

```
=== SCAVENGER HUNT DEBUG ===
Total items retrieved: [number]
Item: [id] - [title]
Item: [id] - [title]
...
Items mapped: [number]
```

### Step 3: Check for Errors
If you see an error message in the manage dialog, check console for:
- Firestore permission errors
- Index creation requirements
- Network connectivity issues

## Common Issues & Solutions

### Issue 1: Firestore Index Required
**Symptom:** Error message mentions "requires an index"

**Solution:**
1. Click the link in the error message (or go to Firebase Console)
2. Go to Firestore Database → Indexes
3. Click "Create Index" or use the auto-generated link
4. Wait for index to be created (can take a few minutes)

### Issue 2: Permission Denied
**Symptom:** Error message shows "permission-denied"

**Solution:**
1. Go to Firebase Console → Firestore Database → Rules
2. Copy rules from `firestore.rules` file
3. Click "Publish"
4. Wait 1-2 minutes for rules to propagate

**Verify rules include:**
```javascript
match /scavenger_hunt_items/{itemId} {
  allow read: if request.auth != null;
  allow create: if request.auth != null && ...
  ...
}
```

### Issue 3: Items Created But Not Showing
**Symptom:** Console shows "Item created with ID" but "Total items retrieved: 0"

**Possible causes:**
1. **Index not created:** Check if you need to create an index for `createdAt` field
2. **Timing issue:** Try closing and reopening the manage dialog
3. **Authentication issue:** Verify user is logged in (`request.auth != null`)

**Solution:**
- Wait a few seconds and reopen the manage dialog
- Check Firebase Console → Firestore Database → Data to verify items exist
- Check that items have `createdAt` timestamp

### Issue 4: StreamBuilder Not Updating
**Symptom:** Items appear in Firebase Console but not in app

**Solution:**
1. Close the manage dialog completely
2. Reopen it to trigger a fresh stream subscription
3. Check if app is in foreground (Firestore may throttle background queries)

## Verification Checklist

- [ ] User is authenticated (logged in)
- [ ] Firebase rules deployed (see `firestore.rules`)
- [ ] Firestore index created for `scavenger_hunt_items` collection with `createdAt` field
- [ ] Item creation logs show success
- [ ] Item retrieval logs show items being fetched
- [ ] No error message displayed in manage dialog
- [ ] Items visible in Firebase Console → Firestore Database

## Testing Steps

1. **Create a test item:**
   ```
   Title: Test Item
   Price: 100
   Description: Test description
   Quantity: 1
   Event Duration: 60
   Location: Set current location
   ```

2. **Check Firebase Console:**
   - Go to Firestore Database
   - Navigate to `scavenger_hunt_items` collection
   - Verify document exists with all fields

3. **Check App:**
   - Click "Manage" button
   - Should see the test item
   - If not, check console logs

4. **Test StreamBuilder:**
   - Leave manage dialog open
   - Create another item
   - New item should appear automatically in the list

## Firestore Structure

Each scavenger hunt item should have:
```javascript
{
  title: string,
  price: number,
  description: string,
  imageUrl: string,
  latitude: number,
  longitude: number,
  quantity: number,
  isActive: boolean,
  createdAt: timestamp (server),
  claimedBy: null,
  claimedAt: null,
  eventEndTime: timestamp (optional)
}
```

## Next Steps

1. **Run the app and test creation**
2. **Check console logs for debug output**
3. **If index error appears, create the index**
4. **If permission error appears, deploy firestore rules**
5. **Verify items appear in both Firebase Console and app**

## Remove Debug Logs (Production)

Once everything is working, remove debug logs from:
- `lib/services/scavenger_hunt_service.dart` (lines with `print()`)
- Keep error handling in `dashboard_screen.dart`

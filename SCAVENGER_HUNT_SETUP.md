# Scavenger Hunt Feature Setup Guide

## Overview
The scavenger hunt feature allows users to find and claim items at specific locations on a map. Items are marked with colored indicators showing their status.

## Firestore Collection Structure

### Collection: `scavenger_hunt_items`

Each document in this collection represents a scavenger hunt item:

```json
{
  "title": "Gaming Laptop",
  "price": 2500,
  "description": "High-performance gaming laptop at the lowest price!",
  "imageUrl": "https://example.com/image.jpg",
  "latitude": 10.3165,
  "longitude": 123.8889,
  "quantity": 1,
  "isActive": true,
  "createdAt": "2025-10-22T12:00:00Z",
  "claimedBy": "userId",  // null if not claimed
  "claimedAt": "2025-10-22T12:30:00Z"  // null if not claimed
}
```

### Field Descriptions:
- **title** (String): Name of the item
- **price** (Number): Price in Philippine Pesos (₱)
- **description** (String): Item description
- **imageUrl** (String): URL to the item's image from Cloudinary
- **latitude** (Number): Latitude coordinate
- **longitude** (Number): Longitude coordinate
- **quantity** (Number): Number of items available (currently supports 1 per location)
- **isActive** (Boolean): Whether the item is currently available
- **createdAt** (Timestamp): When the item was created
- **claimedBy** (String): UID of the user who claimed it (null if unclaimed)
- **claimedAt** (Timestamp): When the item was claimed

## Firestore Security Rules

Add this to your `firestore.rules`:

```
// Scavenger Hunt Items
match /scavenger_hunt_items/{itemId} {
  // Anyone can read active scavenger hunt items
  allow read: if resource.data.isActive == true;
  
  // Only admin can create items (you can modify this later)
  allow create: if false; // Set via Firebase console or admin SDK
  
  // Only owner/admin can update
  allow update: if request.auth != null;
  
  // Only admin can delete
  allow delete: if false;
}
```

## Adding Items via Firebase Console

1. Go to Firebase Console → Firestore Database
2. Create a new collection called `scavenger_hunt_items`
3. Add documents with the structure above

**Example Item 1:**
- Title: "RTX 4060 Graphics Card"
- Price: 12000
- Description: "Brand new RTX 4060, first come first serve!"
- Latitude: 10.3160
- Longitude: 123.8850
- imageUrl: (upload to Cloudinary)
- isActive: true
- claimedBy: null

**Example Item 2:**
- Title: "16GB DDR5 RAM"
- Price: 4500
- Description: "High-speed DDR5 memory"
- Latitude: 10.3170
- Longitude: 123.8900
- imageUrl: (upload to Cloudinary)
- isActive: true
- claimedBy: null

## Map Marker Colors

- **Blue** 🔵: User's current location
- **Orange** 🟠: Available scavenger hunt item
- **Red** 🔴: Claimed item (taken)
- **Green** 🟢: Item claimed by the current user

## Features

### User-Side Features:
1. **Real Location Tracking**: Shows user's actual GPS location
2. **Item Discovery**: See all available scavenger hunt items on the map
3. **Quick Claim**: Tap any marker to see item details and claim it
4. **First-Come-First-Serve**: Items are marked as claimed immediately
5. **Status Indicator**: See which items are available, claimed by others, or claimed by you

### Admin-Side Features (To Implement):
- Create/Edit scavenger hunt items
- Set item locations on map
- View claimed history
- End scavenger hunt events

## How to Use

### For Testing:
1. Allow location permission when prompted
2. Map will center on your current location
3. Tap any marker to see item details
4. Click "Claim Item" to claim it
5. Item will show as green with checkmark

### For Production:
1. Create scavenger hunt items in Firestore before event
2. Users receive notification on homepage
3. Notification takes them to map
4. Map shows all available items
5. Users race to claim items

## Future Enhancements

- Add admin panel to create scavenger hunts
- Add notifications when items are claimed nearby
- Add distance calculations to nearest items
- Add leaderboard
- Add time-limited events
- Add difficulty levels
- Add rewards system

## Troubleshooting

### Location not updating:
- Check if location permission is granted
- Try clicking the refresh button again
- Ensure GPS is enabled on device

### Items not showing:
- Verify items exist in Firestore with `isActive: true`
- Check coordinates are in the same region
- Ensure imageUrl is accessible

### Claim button not working:
- Make sure you're logged in
- Check Firestore security rules
- Verify the item's `claimedBy` field is null

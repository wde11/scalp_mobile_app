# Scavenger Hunt Firestore Security Rules

## Overview
This document explains the Firestore security rules for the scavenger hunt feature in the Scalp mobile app.

## Collection: `scavenger_hunt_items`

### Read Access
```
allow read: if request.auth != null;
```
- **Who**: Any authenticated user
- **Purpose**: All users can view available scavenger hunt items to participate in the treasure hunt

### Create Access
```javascript
allow create: if request.auth != null &&
  request.resource.data.keys().hasAll(['title', 'price', 'description', 'imageUrl', 
                                       'latitude', 'longitude', 'quantity', 'isActive', 'createdAt']) &&
  request.resource.data.title is string &&
  request.resource.data.title.size() > 0 &&
  request.resource.data.price is number &&
  request.resource.data.price >= 0 &&
  request.resource.data.quantity is int &&
  request.resource.data.quantity > 0 &&
  request.resource.data.isActive is bool &&
  request.resource.data.latitude is number &&
  request.resource.data.longitude is number;
```

**Validations:**
- User must be authenticated
- Required fields: `title`, `price`, `description`, `imageUrl`, `latitude`, `longitude`, `quantity`, `isActive`, `createdAt`
- `title` must be a non-empty string
- `price` must be a non-negative number
- `quantity` must be a positive integer
- `isActive` must be a boolean
- `latitude` and `longitude` must be numbers

### Update Access
Two scenarios are allowed:

#### 1. Claiming an Item
```javascript
(resource.data.claimedBy == null && 
 resource.data.isActive == true &&
 request.resource.data.claimedBy == request.auth.uid &&
 request.resource.data.keys().hasAll(['claimedBy', 'claimedAt']) &&
 request.resource.data.diff(resource.data).affectedKeys().hasOnly(['claimedBy', 'claimedAt']))
```

**Conditions:**
- Item must not already be claimed (`claimedBy == null`)
- Item must be active (`isActive == true`)
- User can only claim for themselves (`claimedBy == request.auth.uid`)
- Only `claimedBy` and `claimedAt` fields can be modified

#### 2. Managing Item Details (Admin Function)
```javascript
(request.resource.data.diff(resource.data).affectedKeys()
  .hasAny(['isActive', 'title', 'description', 'price', 'quantity', 'eventEndTime']))
```

**Allowed modifications:**
- `isActive` - Toggle item availability
- `title` - Update item title
- `description` - Update item description
- `price` - Update prize amount
- `quantity` - Update available quantity
- `eventEndTime` - Update event timer

> **Note:** In production, you should add role-based access control (admin checking) for management operations.

### Delete Access
```
allow delete: if request.auth != null;
```
- **Who**: Any authenticated user
- **Purpose**: Remove scavenger hunt items

> **Security Note:** In production, restrict deletion to admin users only by adding role checking.

## Data Structure

### Required Fields
```dart
{
  'title': String,           // Item name
  'price': Number,          // Prize amount in pesos
  'description': String,    // Item description
  'imageUrl': String,       // Image URL
  'latitude': Number,       // Location latitude
  'longitude': Number,      // Location longitude
  'quantity': Int,          // Available quantity
  'isActive': Boolean,      // Item availability status
  'createdAt': Timestamp,   // Creation timestamp
}
```

### Optional Fields
```dart
{
  'claimedBy': String,      // User ID who claimed the item
  'claimedAt': Timestamp,   // Claim timestamp
  'eventEndTime': Timestamp // Global event end time
}
```

## Deployment Instructions

1. **Go to Firebase Console**
   - Navigate to: https://console.firebase.google.com/
   - Select project: `scalp-18928`

2. **Open Firestore Database**
   - Click on "Firestore Database" in the left sidebar
   - Click on the "Rules" tab

3. **Deploy Rules**
   - Copy the contents of `firestore.rules` file
   - Paste into the rules editor
   - Click "Publish" button

4. **Verify Deployment**
   - Test creating a scavenger hunt item
   - Test claiming an item
   - Verify unauthorized access is blocked

## Security Best Practices

### Recommended Enhancements for Production

1. **Add Admin Role Checking**
```javascript
// Create custom claims for admin users
allow create, delete: if request.auth != null && 
                          request.auth.token.admin == true;
```

2. **Rate Limiting**
   - Implement Cloud Functions to limit creation frequency
   - Prevent spam and abuse

3. **Location Validation**
   - Validate latitude range: -90 to 90
   - Validate longitude range: -180 to 180

4. **Event Timer Validation**
```javascript
request.resource.data.eventEndTime > request.time
```

5. **Quantity Tracking**
   - Use transactions to prevent race conditions
   - Implement proper inventory management

## Testing

### Test Cases

1. **Create Item (Should Succeed)**
   - Authenticated user with all required fields
   
2. **Create Item (Should Fail)**
   - Unauthenticated user
   - Missing required fields
   - Invalid data types

3. **Claim Item (Should Succeed)**
   - Active, unclaimed item
   - Authenticated user

4. **Claim Item (Should Fail)**
   - Already claimed item
   - Inactive item
   - Unauthenticated user

5. **Update Item Details (Should Succeed)**
   - Authenticated user updating allowed fields

6. **Delete Item (Should Succeed)**
   - Authenticated user (consider restricting to admin only)

## Related Files
- `lib/models/scavenger_hunt_item.dart` - Data model
- `lib/services/scavenger_hunt_service.dart` - Business logic
- `lib/screens/dashboard_screen.dart` - UI implementation
- `lib/helpers/scavenger_hunt_helper.dart` - Helper functions

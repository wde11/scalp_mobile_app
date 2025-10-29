import 'package:scalp_mobile_app/models/location_data.dart';
import 'package:flutter/material.dart';

// Global key for accessing HomeScreen state
final GlobalKey<NavigatorState> homeScreenNavigatorKey = GlobalKey<NavigatorState>();

// Global navigation state for shared locations
class SharedLocationState {
  static LocationData? sharedLocation;
  static String? sharedByUserName;
  static String? sharedByUserAvatar;
  static bool shouldNavigateToMap = false;
  static VoidCallback? onNavigateToMap; // Callback to trigger navigation
  
  static void setSharedLocation(LocationData location, {String? userName, String? userAvatar}) {
    sharedLocation = location;
    sharedByUserName = userName;
    sharedByUserAvatar = userAvatar;
    shouldNavigateToMap = true;
    // Trigger the callback if set
    if (onNavigateToMap != null) {
      onNavigateToMap!();
    }
  }
  
  static void clearSharedLocation() {
    sharedLocation = null;
    sharedByUserName = null;
    sharedByUserAvatar = null;
    shouldNavigateToMap = false;
  }
}

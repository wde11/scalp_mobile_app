import 'package:scalp_mobile_app/models/location_data.dart';

// Global navigation state for shared locations
class SharedLocationState {
  static LocationData? sharedLocation;
  static String? sharedByUserName;
  static String? sharedByUserAvatar;
  static bool shouldNavigateToMap = false;
  
  static void setSharedLocation(LocationData location, {String? userName, String? userAvatar}) {
    sharedLocation = location;
    sharedByUserName = userName;
    sharedByUserAvatar = userAvatar;
    shouldNavigateToMap = true;
  }
  
  static void clearSharedLocation() {
    sharedLocation = null;
    sharedByUserName = null;
    sharedByUserAvatar = null;
    shouldNavigateToMap = false;
  }
}

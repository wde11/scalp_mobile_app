import 'package:scalp_mobile_app/models/location_data.dart';

// Global navigation state for shared locations
class SharedLocationState {
  static LocationData? sharedLocation;
  static bool shouldNavigateToMap = false;
  
  static void setSharedLocation(LocationData location) {
    sharedLocation = location;
    shouldNavigateToMap = true;
  }
  
  static void clearSharedLocation() {
    sharedLocation = null;
    shouldNavigateToMap = false;
  }
}

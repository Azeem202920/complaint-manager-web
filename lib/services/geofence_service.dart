import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

Future<bool> isTechnicianWithinAnyBuilding() async {
  try {
    // 1. Check and request location permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    // 2. Get current position
    Position currentPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    // 3. Fetch all buildings from Firestore
    QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('buildings').get();
    
    if (snapshot.docs.isEmpty) {
      // If no buildings are registered, decide whether to allow or block access
      return false; 
    }

    // 4. Check if within range of ANY building
    for (var doc in snapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      double targetLat = (data['latitude'] as num).toDouble();
      double targetLng = (data['longitude'] as num).toDouble();
      double radius = (data['allowedRadiusMeters'] as num?)?.toDouble() ?? 200.0;

      double distanceInMeters = Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        targetLat,
        targetLng,
      );

      // If the technician is inside the radius of this building, return true immediately
      if (distanceInMeters <= radius) {
        return true;
      }
    }

    // If the loop finishes without matching any building, they are out of bounds
    return false;
  } catch (e) {
    print("Error checking location geofence: $e");
    return false; // Fail securely by denying access if an error occurs
  }
}
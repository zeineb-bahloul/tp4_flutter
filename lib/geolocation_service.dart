import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class GeolocationService {
  Future<Position?> getCurrentPosition() async {
    try {
      // 1. Vérifier et demander la permission
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return null;
      }

      // 2. Vérifier que le GPS est activé
      if (!(await Geolocator.isLocationServiceEnabled())) {
        return null;
      }

      // 3. Obtenir la position
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (e) {
      debugPrint('Geolocation error: $e');
      return null;
    }
  }
}

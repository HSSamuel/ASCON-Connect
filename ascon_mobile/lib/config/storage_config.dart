import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageConfig {
  // ✅ Define the Android Options once.
  // encryptedSharedPreferences: true is CRITICAL for your app to work on Android.
  static const AndroidOptions androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );

  // ✅ Create a single, reusable instance with the correct options.
  static const FlutterSecureStorage storage = FlutterSecureStorage(
    aOptions: androidOptions,
  );
}
class AppConstants {
  static const bool allowImageUpload = false;
  static const String placeholderImageUrl = 'https://cdn.pixabay.com/photo/2020/05/30/09/51/news-5238316_1280.jpg';

  // AI Backend URLs
  static const String backendBaseUrlLocal = 'http://127.0.0.1:8000'; // Default for iOS Simulator & Web
  static const String backendBaseUrlAndroidEmulator = 'http://192.168.1.12:8000'; // Default for Android Emulator
  
  // Note: For physical devices, replace the above with your computer's local IP address
  // e.g., static const String backendBaseUrlPhysical = 'http://192.168.1.5:8000';
}

// lib/main.dart - FIXED VERSION TO HANDLE FIREBASE FAILURES

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:phoenician_face_auth/onboarding/onboarding_screen.dart';
import 'package:phoenician_face_auth/pin_entry/pin_entry_view.dart';
import 'package:phoenician_face_auth/pin_entry/app_password_entry_view.dart';
import 'package:phoenician_face_auth/dashboard/dashboard_view.dart';
import 'package:phoenician_face_auth/constants/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:phoenician_face_auth/services/service_locator.dart';
import 'package:phoenician_face_auth/model/enhanced_face_features.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Import the services for offline functionality
import 'package:phoenician_face_auth/services/sync_service.dart';
import 'package:phoenician_face_auth/services/connectivity_service.dart';
import 'package:phoenician_face_auth/services/secure_face_storage_service.dart';
import 'package:phoenician_face_auth/services/face_data_migration_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// Add these imports for permissions
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:phoenician_face_auth/repositories/polygon_location_repository.dart';
import 'package:phoenician_face_auth/admin/polygon_map_view.dart';
import 'package:phoenician_face_auth/admin/geojson_importer_view.dart';

// Global flag to track Firebase status
bool _isFirebaseInitialized = false;
bool _hasFirebaseError = false;
String _firebaseError = '';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (_isFirebaseInitialized) {
    print("Handling a background message: ${message.messageId}");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ STEP 1: Initialize Firebase with PROPER error handling
  await initializeFirebaseWithFallback();

  // ✅ STEP 2: Set up notifications only if Firebase works
  await setupNotifications();

  // ✅ STEP 3: Initialize Firestore offline mode only if Firebase works
  if (_isFirebaseInitialized) {
    await _initializeFirestoreOfflineMode();
  }

  // ✅ STEP 4: Request permissions
  await requestAppPermissions();

  // ✅ STEP 5: Setup service locator with fallback
  await setupServiceLocatorWithFallback();

  // ✅ STEP 6: Initialize app data
  await initializeAppData();

  // ✅ STEP 7: Run the app
  runApp(const MyApp());
}

/// ✅ FIXED: Initialize Firebase with proper fallback
Future<void> initializeFirebaseWithFallback() async {
  try {
    print("🔥 Attempting Firebase initialization...");
    
    // Try to initialize Firebase
    await Firebase.initializeApp();
    
    _isFirebaseInitialized = true;
    _hasFirebaseError = false;
    print("✅ Firebase initialized successfully");
    
    // Test Firebase connection
    try {
      await FirebaseFirestore.instance
          .collection('test')
          .doc('connection')
          .get()
          .timeout(Duration(seconds: 5));
      print("✅ Firebase connection test successful");
    } catch (e) {
      print("⚠️ Firebase connection test failed: $e");
      // Continue anyway - Firebase might be working but network is slow
    }
    
  } catch (e) {
    _isFirebaseInitialized = false;
    _hasFirebaseError = true;
    _firebaseError = e.toString();
    
    print("❌ Firebase initialization failed: $e");
    print("📱 App will continue in OFFLINE MODE");
    print("💡 Check your Firebase configuration files:");
    print("   - ios/Runner/GoogleService-Info.plist");
    print("   - android/app/google-services.json");
  }
}

/// ✅ FIXED: Setup notifications with Firebase check
Future<void> setupNotifications() async {
  try {
    // Only set up Firebase notifications if Firebase is working
    if (_isFirebaseInitialized) {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    }

    // Set up local notifications regardless
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    print("✅ Local notifications initialized");
    
  } catch (e) {
    print("⚠️ Notification setup failed: $e");
    // Continue - app should work without notifications
  }
}

/// ✅ FIXED: Setup service locator with fallback
Future<void> setupServiceLocatorWithFallback() async {
  try {
    print("🔧 Setting up service locator...");
    
    // Setup services - they will handle Firebase failures internally
    await setupServiceLocator();
    
    print("✅ Service locator setup completed");
    
    // Validate critical services
    bool isValid = validateServiceLocator();
    if (!isValid) {
      print("⚠️ Some services failed to initialize but app will continue");
    }
    
  } catch (e) {
    print("❌ Service locator setup failed: $e");
    print("📱 App will continue with limited functionality");
    // Don't stop the app - continue with basic functionality
  }
}

/// ✅ FIXED: Initialize app data with error handling
Future<void> initializeAppData() async {
  try {
    // Check and migrate existing face data
    if (isServiceRegistered<SecureFaceStorageService>()) {
      final storageService = getIt<SecureFaceStorageService>();
      final migrationService = FaceDataMigrationService(storageService);
      await migrationService.migrateExistingData();
    }

    // Initialize sync service if available
    if (isServiceRegistered<SyncService>()) {
      final syncService = getIt<SyncService>();
      print("✅ Sync service initialized");
    }

    // Load default GeoJSON data if services are available
    if (_isFirebaseInitialized && isServiceRegistered<PolygonLocationRepository>()) {
      await _loadDefaultGeoJsonData();
    }

  } catch (e) {
    print("⚠️ App data initialization failed: $e");
    // Continue - basic app should still work
  }
}

/// ✅ ENHANCED: Request app permissions with better error handling
Future<void> requestAppPermissions() async {
  if (Platform.isAndroid) {
    try {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;

      print("📱 Requesting permissions for Android SDK: ${androidInfo.version.sdkInt}");

      // Request different permissions based on Android version
      if (androidInfo.version.sdkInt >= 33) {
        await Permission.photos.request();
        await Permission.mediaLibrary.request();
      } else if (androidInfo.version.sdkInt >= 30) {
        await Permission.storage.request();
      } else {
        await Permission.storage.request();
      }

      await Permission.notification.request();
      await Permission.camera.request();
      await Permission.location.request();

      print("✅ Permissions requested successfully");

    } catch (e) {
      print("⚠️ Error requesting permissions: $e");
    }
  }
}

/// Configure Firestore for offline persistence
Future<void> _initializeFirestoreOfflineMode() async {
  try {
    FirebaseFirestore.instance.settings = Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    print("✅ Firestore offline mode configured");
  } catch (e) {
    print("❌ Error configuring Firestore offline mode: $e");
  }
}

Future<void> _loadDefaultGeoJsonData() async {
  try {
    final polygonRepository = getIt<PolygonLocationRepository>();
    final existingLocations = await polygonRepository.getActivePolygonLocations();

    if (existingLocations.isEmpty) {
      // Your GeoJSON data here
      final String santoriniGeoJson = '''
      {
          "type": "FeatureCollection", 
          "features": [
              {
                  "type": "Feature", 
                  "geometry": {
                      "type": "Polygon", 
                      "coordinates": [
                          [
                              [55.2318760, 25.0134952, 0], 
                              [55.2353092, 25.0080894, 0], 
                              [55.2318760, 25.0134952, 0]  
                          ]
                      ]
                  }, 
                  "properties": {
                      "name": "SANTORINI", 
                      "description": "DAMAC LAGOONS SANTORINI (PHOENICIAN TECHNICAL SERVICES)DUBAI,UAE"
                  }
              }
          ]
      }
      ''';

      final locations = await polygonRepository.loadFromGeoJson(santoriniGeoJson);
      if (locations.isNotEmpty) {
        await polygonRepository.savePolygonLocations(locations);
        print("✅ Default location data loaded");
      }
    }
  } catch (e) {
    print("⚠️ Error loading default location data: $e");
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool? _showOnboarding;
  String? _loggedInEmployeeId;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  /// ✅ FIXED: Initialize app state with error handling
  Future<void> _initializeApp() async {
    try {
      await _checkLoginStatus();
    } catch (e) {
      print("❌ Error initializing app: $e");
      // Set default state to prevent white screen
      if (mounted) {
        setState(() {
          _showOnboarding = true; // Default to onboarding if error
        });
      }
    }
  }

  Future<void> _checkLoginStatus() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool onboardingComplete = prefs.getBool('onboardingComplete') ?? false;

      if (!onboardingComplete) {
        setState(() {
          _showOnboarding = true;
        });
        return;
      }

      // Check for complete registration
      String? authenticatedUserId = prefs.getString('authenticated_user_id');
      bool isAuthenticated = prefs.getBool('is_authenticated') ?? false;
      int? authTimestamp = prefs.getInt('authentication_timestamp');

      if (isAuthenticated && authenticatedUserId != null) {
        if (authTimestamp != null) {
          DateTime authDate = DateTime.fromMillisecondsSinceEpoch(authTimestamp);
          DateTime now = DateTime.now();
          int daysSinceAuth = now.difference(authDate).inDays;

          if (daysSinceAuth > 30) {
            await _clearAuthenticationData();
            setState(() {
              _showOnboarding = false;
              _loggedInEmployeeId = null;
            });
            return;
          }
        }

        bool hasCompleteRegistration = await _checkCompleteRegistration(authenticatedUserId);

        if (hasCompleteRegistration) {
          setState(() {
            _loggedInEmployeeId = authenticatedUserId;
            _showOnboarding = false;
          });
          return;
        }
      }

      // Default to PIN entry
      setState(() {
        _showOnboarding = false;
        _loggedInEmployeeId = null;
      });

    } catch (e) {
      print("❌ Error checking login status: $e");
      // Default to onboarding to prevent white screen
      setState(() {
        _showOnboarding = true;
      });
    }
  }

  Future<bool> _checkCompleteRegistration(String employeeId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // Check local registration first
      bool localFaceRegistered = prefs.getBool('face_registered_$employeeId') ?? false;
      String? storedImage = prefs.getString('employee_image_$employeeId');
      bool hasLocalImage = storedImage != null && storedImage.isNotEmpty;
      String? userData = prefs.getString('user_data_$employeeId');
      bool hasLocalData = userData != null;

      if (localFaceRegistered && hasLocalImage && hasLocalData) {
        try {
          Map<String, dynamic> data = jsonDecode(userData);
          bool profileCompleted = data['profileCompleted'] ?? false;
          bool registrationCompleted = data['registrationCompleted'] ?? false;
          bool faceRegistered = data['faceRegistered'] ?? false;
          bool enhancedRegistration = data['enhancedRegistration'] ?? false;

          bool isCompletelyRegistered = profileCompleted &&
              registrationCompleted &&
              (faceRegistered || enhancedRegistration || localFaceRegistered);

          if (isCompletelyRegistered) {
            return true;
          }
        } catch (e) {
          print("⚠️ Error parsing local user data: $e");
        }
      }

      // Check online only if Firebase is working
      if (_isFirebaseInitialized && 
          isServiceRegistered<ConnectivityService>() &&
          getIt<ConnectivityService>().currentStatus == ConnectionStatus.online) {
        try {
          DocumentSnapshot doc = await FirebaseFirestore.instance
              .collection('employees')
              .doc(employeeId)
              .get()
              .timeout(Duration(seconds: 10));

          if (doc.exists) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            bool profileCompleted = data['profileCompleted'] ?? false;
            bool registrationCompleted = data['registrationCompleted'] ?? false;
            bool faceRegistered = data['faceRegistered'] ?? false;
            bool enhancedRegistration = data['enhancedRegistration'] ?? false;
            bool hasImage = data.containsKey('image') && data['image'] != null;

            bool isCompletelyRegistered = profileCompleted &&
                registrationCompleted &&
                (faceRegistered || enhancedRegistration) &&
                hasImage;

            if (isCompletelyRegistered) {
              // Update local storage
              await prefs.setBool('face_registered_$employeeId', true);
              await prefs.setString('user_data_$employeeId', jsonEncode(data));
              if (data['image'] != null) {
                await prefs.setString('employee_image_$employeeId', data['image']);
              }
              return true;
            }
          }
        } catch (e) {
          print("⚠️ Error checking online registration: $e");
        }
      }

      return false;

    } catch (e) {
      print("❌ Error checking complete registration: $e");
      return false;
    }
  }

  Future<void> _clearAuthenticationData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('authenticated_user_id');
      await prefs.remove('authenticated_employee_pin');
      await prefs.setBool('is_authenticated', false);
      await prefs.remove('authentication_timestamp');
      await prefs.remove('firebase_uid');
    } catch (e) {
      print("❌ Error clearing authentication data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PHOENICIAN',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSwatch(accentColor: accentColor),
        inputDecorationTheme: InputDecorationTheme(
          contentPadding: const EdgeInsets.all(20),
          filled: true,
          fillColor: primaryWhite,
          hintStyle: TextStyle(
            color: primaryBlack.withOpacity(0.6),
            fontWeight: FontWeight.w500,
          ),
          errorStyle: const TextStyle(
            letterSpacing: 0.8,
            color: Colors.redAccent,
            fontWeight: FontWeight.w500,
          ),
          border: OutlineInputBorder(
            borderSide: BorderSide.none,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: _getInitialScreen(),
      routes: {
        '/polygon_map_view': (context) => const PolygonMapView(),
        '/geojson_importer_view': (context) => const GeoJsonImporterView(),
      },
    );
  }

  Widget _getInitialScreen() {
    // Show loading screen while determining state
    if (_showOnboarding == null) {
      return SplashScreen(
        hasFirebaseError: _hasFirebaseError,
        firebaseError: _firebaseError,
      );
    }

    if (_showOnboarding!) {
      return const OnboardingScreen();
    }

    if (_loggedInEmployeeId != null) {
      return DashboardView(employeeId: _loggedInEmployeeId!);
    }

    return const AppPasswordEntryView();
  }
}

class SplashScreen extends StatelessWidget {
  final bool hasFirebaseError;
  final String firebaseError;

  const SplashScreen({
    Key? key,
    this.hasFirebaseError = false,
    this.firebaseError = '',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scaffoldTopGradientClr,
              scaffoldBottomGradientClr,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "PHOENICIAN",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 16),
              
              if (hasFirebaseError) ...[
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  "Running in Offline Mode",
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    "Firebase initialization failed. App will work with limited functionality.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ),
              ] else ...[
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 16),
                const Text(
                  "Initializing Authentication...",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
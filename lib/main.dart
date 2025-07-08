// lib/main.dart - FIXED VERSION

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
import 'package:phoenician_face_auth/services/simple_firebase_auth_service.dart'; // ✅ FIXED IMPORT
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

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ ENHANCED: Initialize Firebase with proper error handling
  try {
    await Firebase.initializeApp();
    print("✅ Firebase initialized successfully");
  } catch (e) {
    print("❌ Firebase initialization failed: $e");
    // Continue without Firebase for offline functionality
  }

  // Set the background messaging handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize local notifications
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

  // Initialize Firestore for offline persistence
  await _initializeFirestoreOfflineMode();
  await requestAppPermissions();

  // Setup service locator
  setupServiceLocator();
  listRegisteredServices();

  // Check and migrate existing face data
  final storageService = getIt<SecureFaceStorageService>();
  final migrationService = FaceDataMigrationService(storageService);
  await migrationService.migrateExistingData();

  // Initialize sync service after service locator is setup
  final syncService = getIt<SyncService>();
  print("Main: Sync service initialized");

  runApp(const MyApp());
}

// ✅ ENHANCED: Request app permissions with better error handling
Future<void> requestAppPermissions() async {
  if (Platform.isAndroid) {
    try {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;

      print("Requesting app permissions for Android SDK: ${androidInfo.version.sdkInt}");

      // Request different permissions based on Android version
      if (androidInfo.version.sdkInt >= 33) {
        // Android 13+
        await Permission.photos.request();
        await Permission.mediaLibrary.request();
      } else if (androidInfo.version.sdkInt >= 30) {
        // Android 11-12
        await Permission.storage.request();
      } else {
        // Android 10 and below
        await Permission.storage.request();
      }

      // ✅ NEW: Request notification permissions for real-time updates
      await Permission.notification.request();

      print("✅ Permissions requested successfully");

    } catch (e) {
      print("Error requesting app permissions: $e");
    }
  }
}

// Configure Firestore for offline persistence
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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool? _showOnboarding;
  String? _loggedInEmployeeId;

  // GeoJSON data for default locations
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
                        [55.2368435, 25.0083714, 0], 
                        [55.2370969, 25.0090520, 0], 
                        [55.2378332, 25.0101409, 0], 
                        [55.2383441, 25.0110403, 0], 
                        [55.2389409, 25.0118910, 0], 
                        [55.2391769, 25.0128535, 0], 
                        [55.2392647, 25.0134477, 0], 
                        [55.2392921, 25.0136687, 0], 
                        [55.2393135, 25.0137949, 0], 
                        [55.2393294, 25.0140339, 0], 
                        [55.2393613, 25.0143344, 0], 
                        [55.2394062, 25.0150764, 0], 
                        [55.2395175, 25.0152234, 0], 
                        [55.2396060, 25.0153182, 0], 
                        [55.2396731, 25.0154373, 0], 
                        [55.2396700, 25.0155436, 0], 
                        [55.2396240, 25.0156620, 0], 
                        [55.2395212, 25.0158844, 0], 
                        [55.2395800, 25.0159326, 0], 
                        [55.2396005, 25.0159852, 0], 
                        [55.2395947, 25.0160282, 0], 
                        [55.2395860, 25.0160808, 0], 
                        [55.2395525, 25.0161160, 0], 
                        [55.2394955, 25.0161552, 0], 
                        [55.2394438, 25.0161670, 0], 
                        [55.2393580, 25.0161564, 0], 
                        [55.2393419, 25.0161482, 0], 
                        [55.2389771, 25.0166726, 0], 
                        [55.2387022, 25.0172347, 0], 
                        [55.2364036, 25.0159842, 0], 
                        [55.2318760, 25.0134952, 0]  
                    ]
                ]
            }, 
            "properties": {
                "name": "SANTORINI", 
                "description": "DAMAC LAGOONS SANTORINI (PHOENICIAN TECHNICAL SERVICES)DUBAI,UAE", 
                "styleUrl": "#poly-C2185B-1200-77", 
                "fill-opacity": 0.30196078431372547, 
                "fill": "#c2185b", 
                "stroke-opacity": 1, 
                "stroke": "#c2185b", 
                "stroke-width": 1.2
            }
        }
    ]
}
''';

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _initializeLocationData();
    _initializeAdminAccount();
    _loadDefaultGeoJsonData();
    _setupAuthStateListener();

    // ✅ NEW: Listen for Firebase Auth state changes
    _setupAuthStateListener();
  }

  // ✅ NEW: Setup authentication state listener
  void _setupAuthStateListener() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        print("🔐 User authenticated: ${user.uid}");
      } else {
        print("🔓 User signed out");
      }
    });
  }

  Future<void> _loadDefaultGeoJsonData() async {
    try {
      final polygonRepository = getIt<PolygonLocationRepository>();
      final existingLocations = await polygonRepository.getActivePolygonLocations();

      if (existingLocations.isEmpty) {
        print("No polygon locations found. Importing default SANTORINI project boundaries...");

        final locations = await polygonRepository.loadFromGeoJson(santoriniGeoJson);

        if (locations.isNotEmpty) {
          await polygonRepository.savePolygonLocations(locations);
          print("Successfully imported ${locations.length} polygon locations");

          for (var location in locations) {
            print("Imported: ${location.name} with ${location.coordinates.length} boundary points");
          }
        }
      } else {
        print("Found ${existingLocations.length} existing polygon locations, skipping import");
      }
    } catch (e) {
      print("Error importing default GeoJSON data: $e");
    }
  }

  // ✅ ENHANCED: Check login status with better authentication handling
  Future<void> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool onboardingComplete = prefs.getBool('onboardingComplete') ?? false;

    if (!onboardingComplete) {
      setState(() {
        _showOnboarding = true;
      });
      return;
    }

    // ✅ ENHANCED: Check for COMPLETE registration before auto-login
    String? authenticatedUserId = prefs.getString('authenticated_user_id');
    bool isAuthenticated = prefs.getBool('is_authenticated') ?? false;
    int? authTimestamp = prefs.getInt('authentication_timestamp');

    debugPrint("🔍 Checking authentication status...");
    debugPrint("   - User ID: $authenticatedUserId");
    debugPrint("   - Is Authenticated: $isAuthenticated");
    debugPrint("   - Auth Timestamp: $authTimestamp");

    if (isAuthenticated && authenticatedUserId != null) {
      // ✅ Check if authentication is recent (within 30 days)
      if (authTimestamp != null) {
        DateTime authDate = DateTime.fromMillisecondsSinceEpoch(authTimestamp);
        DateTime now = DateTime.now();
        int daysSinceAuth = now.difference(authDate).inDays;

        debugPrint("   - Days since auth: $daysSinceAuth");

        if (daysSinceAuth > 30) {
          debugPrint("⚠️ Authentication expired (30+ days), requiring re-login");
          await _clearAuthenticationData();
          setState(() {
            _showOnboarding = false;
            _loggedInEmployeeId = null;
          });
          return;
        }
      }

      // ✅ NEW: Check if user has COMPLETE registration (including face)
      bool hasCompleteRegistration = await _checkCompleteRegistration(authenticatedUserId);

      if (hasCompleteRegistration) {
        debugPrint("✅ Complete registration found, auto-login to dashboard");
        setState(() {
          _loggedInEmployeeId = authenticatedUserId;
          _showOnboarding = false;
        });
        return;
      } else {
        debugPrint("❌ Incomplete registration, requiring PIN entry");
        setState(() {
          _showOnboarding = false;
          _loggedInEmployeeId = null;
        });
        return;
      }
    }

    // No valid authentication found
    debugPrint("❌ No valid authentication found, showing PIN entry");
    setState(() {
      _showOnboarding = false;
      _loggedInEmployeeId = null;
    });
  }


  Future<bool> _checkCompleteRegistration(String employeeId) async {
    try {
      debugPrint("🔍 Checking complete registration for: $employeeId");

      // Check local storage first
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // Check local registration flags
      bool localFaceRegistered = prefs.getBool('face_registered_$employeeId') ?? false;
      String? storedImage = prefs.getString('employee_image_$employeeId');
      bool hasLocalImage = storedImage != null && storedImage.isNotEmpty;

      // Check if we have complete local registration data
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
            debugPrint("✅ Complete registration confirmed locally");

            // ✅ NEW: Additional face data validation
            try {
              final secureFaceStorage = getIt<SecureFaceStorageService>();
              bool faceDataValid = await secureFaceStorage.validateLocalFaceData(employeeId);

              if (!faceDataValid) {
                debugPrint("⚠️ Registration exists but face data invalid, attempting recovery...");

                // Try to recover face data from cloud
                bool recovered = await secureFaceStorage.ensureFaceDataAvailable(employeeId);

                if (recovered) {
                  debugPrint("✅ Face data recovered during registration check");
                  return true;
                } else {
                  debugPrint("❌ Could not recover face data, registration incomplete");
                  return false;
                }
              }
            } catch (e) {
              debugPrint("⚠️ Error validating face data: $e");
              // Continue with existing logic if face validation fails
            }

            return true;
          }
        } catch (e) {
          debugPrint("⚠️ Error parsing local user data: $e");
        }
      }

      // Check online if we're connected
      if (getIt<ConnectivityService>().currentStatus == ConnectionStatus.online) {
        try {
          debugPrint("🌐 Checking complete registration online...");

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

            debugPrint("📋 Online Registration Status:");
            debugPrint("   - profileCompleted: $profileCompleted");
            debugPrint("   - registrationCompleted: $registrationCompleted");
            debugPrint("   - faceRegistered: $faceRegistered");
            debugPrint("   - enhancedRegistration: $enhancedRegistration");
            debugPrint("   - hasImage: $hasImage");

            bool isCompletelyRegistered = profileCompleted &&
                registrationCompleted &&
                (faceRegistered || enhancedRegistration) &&
                hasImage;

            if (isCompletelyRegistered) {
              debugPrint("✅ Complete registration confirmed online");

              // Update local storage
              await prefs.setBool('face_registered_$employeeId', true);
              await prefs.setString('user_data_$employeeId', jsonEncode(data));

              if (data['image'] != null) {
                await prefs.setString('employee_image_$employeeId', data['image']);
              }

              // ✅ NEW: Ensure face data is properly stored locally
              try {
                final secureFaceStorage = getIt<SecureFaceStorageService>();

                // Save face image to secure storage
                if (data['image'] != null) {
                  await secureFaceStorage.saveFaceImage(employeeId, data['image']);
                }

                // Save enhanced features if available
                if (data['enhancedFaceFeatures'] != null) {
                  try {
                    EnhancedFaceFeatures features = EnhancedFaceFeatures.fromJson(data['enhancedFaceFeatures']);
                    await secureFaceStorage.saveEnhancedFaceFeatures(employeeId, features);
                    await secureFaceStorage.setEnhancedFaceRegistered(employeeId, true);
                  } catch (e) {
                    debugPrint("⚠️ Error saving enhanced features: $e");
                  }
                }

                await secureFaceStorage.setFaceRegistered(employeeId, true);
                debugPrint("✅ Face data saved to secure storage during registration check");

              } catch (e) {
                debugPrint("⚠️ Error saving face data to secure storage: $e");
                // Continue - registration is still valid
              }

              return true;
            } else {
              debugPrint("❌ Registration incomplete online");
              return false;
            }
          }
        } catch (e) {
          debugPrint("⚠️ Error checking online registration: $e");
        }
      }

      debugPrint("❌ Complete registration not found");
      return false;

    } catch (e) {
      debugPrint("❌ Error checking complete registration: $e");
      return false;
    }
  }

  // Check if user exists in local storage
  Future<void> _clearAuthenticationData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // Clear all authentication-related data
      await prefs.remove('authenticated_user_id');
      await prefs.remove('authenticated_employee_pin');
      await prefs.setBool('is_authenticated', false);
      await prefs.remove('authentication_timestamp');
      await prefs.remove('firebase_uid');

      debugPrint("🧹 Authentication data cleared");
    } catch (e) {
      debugPrint("❌ Error clearing authentication data: $e");
    }
  }

// ✅ ADD: Method to mark registration as complete (call this after successful face registration)
  Future<void> markRegistrationComplete(String employeeId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // Mark as fully authenticated
      await prefs.setBool('is_authenticated', true);
      await prefs.setInt('authentication_timestamp', DateTime.now().millisecondsSinceEpoch);

      debugPrint("✅ Registration marked as complete for: $employeeId");
    } catch (e) {
      debugPrint("❌ Error marking registration complete: $e");
    }
  }

// ✅ IMPROVED: Check if user exists locally with better validation
  Future<bool> _checkUserExistsLocally(String userId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // Check for user data
      String? userData = prefs.getString('user_data_$userId');
      if (userData != null && userData.isNotEmpty) {
        try {
          // Validate that the JSON can be parsed
          Map<String, dynamic> data = jsonDecode(userData);
          if (data.isNotEmpty && data.containsKey('name')) {
            debugPrint("✅ Valid local user data found for: $userId");
            return true;
          }
        } catch (e) {
          debugPrint("⚠️ Corrupted user data for $userId: $e");
          // Remove corrupted data
          await prefs.remove('user_data_$userId');
        }
      }

      // Check existence flag
      bool exists = prefs.getBool('user_exists_$userId') ?? false;
      if (exists) {
        debugPrint("✅ User existence flag found for: $userId");
        return true;
      }

      debugPrint("❌ No local user data found for: $userId");
      return false;
    } catch (e) {
      debugPrint("❌ Error checking local user data: $e");
      return false;
    }
  }




  // Check if there are any registered users locally
  Future<bool> _checkRegisteredUsersLocally() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      Set<String> keys = prefs.getKeys();

      // Look for any user existence flags or user data
      bool hasUsers = keys.any((key) =>
      key.startsWith('user_exists_') ||
          key.startsWith('user_data_'));

      debugPrint("📊 Local users check: ${hasUsers ? 'Found' : 'None'} registered users");
      return hasUsers;
    } catch (e) {
      debugPrint("❌ Error checking registered users locally: $e");
      return false;
    }
  }

  ConnectivityService get _connectivityService {
    try {
      return getIt<ConnectivityService>();
    } catch (e) {
      debugPrint("⚠️ ConnectivityService not available, assuming offline");
      // Create a temporary service instance (don't try to set currentStatus)
      return ConnectivityService();
    }
  }

  Future<void> _initializeLocationData() async {
    if (getIt<ConnectivityService>().currentStatus == ConnectionStatus.offline) {
      return;
    }

    try {
      QuerySnapshot locationsSnapshot = await FirebaseFirestore.instance
          .collection('locations')
          .limit(1)
          .get();

      if (locationsSnapshot.docs.isEmpty) {
        await FirebaseFirestore.instance.collection('locations').add({
          'name': 'Central Plaza',
          'address': 'DIP 1, Street 72, Dubai',
          'latitude': 24.985454,
          'longitude': 55.175509,
          'radius': 200.0,
          'isActive': true,
        });

        print('Default location created');
      }
    } catch (e) {
      print('Error initializing location data: $e');
    }
  }

  Future<void> _initializeAdminAccount() async {
    if (getIt<ConnectivityService>().currentStatus == ConnectionStatus.offline) {
      return;
    }

    try {
      final adminSnapshot = await FirebaseFirestore.instance
          .collection('admins')
          .limit(1)
          .get();

      if (adminSnapshot.docs.isEmpty) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: "admin@pts",
          password: "pts123",
        ).then((userCredential) async {
          await FirebaseFirestore.instance
              .collection('admins')
              .doc(userCredential.user!.uid)
              .set({
            'email': "admin@pts",
            'isAdmin': true,
            'createdAt': FieldValue.serverTimestamp(),
          });

          print('Default admin account created');
        });
      }
    } catch (e) {
      print('Error creating admin account: $e');
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
    if (_showOnboarding == null) {
      return const SplashScreen();
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
  const SplashScreen({Key? key}) : super(key: key);

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
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "PHOENICIAN",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(height: 16),
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                "Initializing Authentication...",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
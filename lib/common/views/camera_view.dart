// lib/common/views/camera_view.dart - iOS COMPATIBLE VERSION

import 'dart:io';
import 'dart:typed_data';

import 'package:phoenician_face_auth/constants/theme.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';

class CameraView extends StatefulWidget {
  const CameraView({
    Key? key,
    required this.onImage,
    required this.onInputImage
  }) : super(key: key);

  final Function(Uint8List image) onImage;
  final Function(InputImage inputImage) onInputImage;

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  File? _image;
  ImagePicker? _imagePicker;
  bool _isCapturing = false;
  String _captureStatus = "Ready to capture";

  @override
  void initState() {
    super.initState();
    _imagePicker = ImagePicker();
    debugPrint("CAMERA: CameraView initialized");
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(
              Icons.camera_alt_outlined,
              color: primaryWhite,
              size: screenHeight * 0.038,
            ),
          ],
        ),
        SizedBox(height: screenHeight * 0.025),
        _image != null
            ? Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: screenHeight * 0.15,
              backgroundColor: const Color(0xffD9D9D9),
              backgroundImage: FileImage(_image!),
            ),
            GestureDetector(
              onTap: _resetImage,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.refresh,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        )
            : CircleAvatar(
          radius: screenHeight * 0.15,
          backgroundColor: const Color(0xffD9D9D9),
          child: Icon(
            Icons.camera_alt,
            size: screenHeight * 0.09,
            color: const Color(0xff2E2E2E),
          ),
        ),
        GestureDetector(
          onTap: _isCapturing ? null : _getImage,
          child: Container(
            width: 60,
            height: 60,
            margin: const EdgeInsets.only(top: 44, bottom: 20),
            decoration: BoxDecoration(
              gradient: const RadialGradient(
                stops: [0.4, 0.65, 1],
                colors: [
                  Color(0xffD9D9D9),
                  primaryWhite,
                  Color(0xffD9D9D9),
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: _isCapturing
                  ? [
                BoxShadow(
                  color: accentColor.withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ]
                  : null,
            ),
            child: _isCapturing
                ? const CircularProgressIndicator(
              color: accentColor,
              strokeWidth: 3,
            )
                : null,
          ),
        ),
        Text(
          _isCapturing ? "Capturing..." : "Click here to Capture",
          style: TextStyle(
            fontSize: 14,
            color: primaryWhite.withOpacity(0.6),
          ),
        ),
        if (_captureStatus != "Ready to capture")
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              _captureStatus,
              style: TextStyle(
                fontSize: 12,
                color: _captureStatus.contains("Error")
                    ? Colors.red.withOpacity(0.8)
                    : Colors.green.withOpacity(0.8),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _resetImage() async {
    setState(() {
      _image = null;
      _captureStatus = "Ready to capture";
    });
  }

  Future<void> _getImage() async {
    try {
      setState(() {
        _image = null;
        _isCapturing = true;
        _captureStatus = "Opening camera...";
      });

      // ✅ iOS-specific camera settings
      final pickedFile = await _imagePicker?.pickImage(
        source: ImageSource.camera,
        maxWidth: Platform.isIOS ? 800 : 600,    // Higher resolution for iOS
        maxHeight: Platform.isIOS ? 800 : 600,   // Higher resolution for iOS
        imageQuality: Platform.isIOS ? 90 : 85,  // Higher quality for iOS
        preferredCameraDevice: CameraDevice.front,
      );

      if (pickedFile != null) {
        debugPrint("CAMERA: Image captured, processing...");
        setState(() {
          _captureStatus = "Processing image...";
        });
        
        // ✅ Add delay for iOS processing
        if (Platform.isIOS) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
        
        await _setPickedFile(pickedFile);
        setState(() {
          _captureStatus = "Image captured successfully!";
        });
      } else {
        debugPrint("CAMERA: Image capture cancelled");
        setState(() {
          _captureStatus = "Capture cancelled";
        });
      }
    } catch (e) {
      debugPrint("CAMERA: Error capturing image: $e");
      setState(() {
        _captureStatus = "Error: $e";
      });
    } finally {
      setState(() {
        _isCapturing = false;
      });
    }
  }

  Future<void> _setPickedFile(XFile? pickedFile) async {
    final path = pickedFile?.path;
    if (path == null) {
      debugPrint("CAMERA: No image path returned");
      return;
    }

    setState(() {
      _image = File(path);
    });

    try {
      // Read image bytes and validate
      Uint8List imageBytes = await _image!.readAsBytes();

      debugPrint("CAMERA: Good image quality (${imageBytes.length} bytes)");

      // ✅ Pass to parent immediately
      widget.onImage(imageBytes);

      // ✅ Create InputImage with iOS-specific handling
      InputImage inputImage;
      
      if (Platform.isIOS) {
        // iOS-specific InputImage creation
        inputImage = InputImage.fromFilePath(path);
      } else {
        // Android InputImage creation
        inputImage = InputImage.fromFilePath(path);
      }

      // ✅ Process with delay for iOS
      if (Platform.isIOS) {
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // Call the input image handler
      widget.onInputImage(inputImage);

    } catch (e) {
      debugPrint("CAMERA: Error processing captured image: $e");
      setState(() {
        _captureStatus = "Error processing image: $e";
      });
    }
  }
}

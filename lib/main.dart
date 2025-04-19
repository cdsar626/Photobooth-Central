// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:image/image.dart' as img;
import 'dart:io';

void main() {
runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: CameraApp());
  }
}

class CameraApp extends StatefulWidget {
  const CameraApp({super.key});

  @override
  CameraAppState createState() => CameraAppState();
}

class CameraAppState extends State<CameraApp> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (await Permission.camera.request().isGranted) {
      final cameras = await availableCameras();
      final firstCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _controller = CameraController(firstCamera, ResolutionPreset.medium);
      _initializeControllerFuture = _controller!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } else {
      // Handle the case where camera permission is not granted
      print("Camera permission not granted");
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 64, 224, 208),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              _isCameraInitialized) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  CameraScreen(controller: _controller!),
                        ),
                      );
                    },
                    child: const Text("Open Camera"),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      final pickedFile = await ImagePicker().pickImage(
                        source: ImageSource.gallery,
                      );
                      if (pickedFile != null) {
                        // Handle the picked image, e.g., display it or upload it.
                        print("Image selected: ${pickedFile.path}");
                      } else {
                        print("No image selected.");
                      }
                    },
                    child: const Text("Open Gallery"),
                  ),
                ],
              ),
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}

class CameraScreen extends StatefulWidget {
  final CameraController controller;

  const CameraScreen({super.key, required this.controller});

  @override
  CameraScreenState createState() => CameraScreenState();
}

class CameraScreenState extends State<CameraScreen> {
  int _countdown = 3;
  List<String> _imagePaths = [];
  int _pictureCount = 0;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    if (_pictureCount < 4) {
      _countdown = 3; // Reset countdown before taking the next picture
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _countdown--;
        });
        if (_countdown <= 0) {
          timer.cancel();
          _takePicture();
        }
      });
    }
  }

  Timer? _timer;
  Future<void> _combineImages() async {
    if (_imagePaths.length != 4) {
      print('Error: Need 4 images to combine.');
      return;
    }

    print('Combining images...');
    final combinedImagePath =
        '${(await getApplicationDocumentsDirectory()).path}/combined_image.png';

    try {
      List<img.Image?> images = [];
      for (var path in _imagePaths) {
        images.add(img.decodeImage(File(path).readAsBytesSync()));
      }

      if (images.any((image) => image == null)) {
        print('Error: Could not decode one or more images.');
        return;
      }

      List<img.Image> resizedImages = images.map((image) => img.copyResize(image!, width: 600, height: 900)).toList();

      img.Image combinedImage = img.Image(width: 1200, height: 1800);

      img.compositeImage(combinedImage, resizedImages[0], dstX: 0, dstY: 0);
      img.compositeImage(combinedImage, resizedImages[1], dstX: 600, dstY: 0);
      img.compositeImage(combinedImage, resizedImages[2], dstX: 0, dstY: 900);
      img.compositeImage(combinedImage, resizedImages[3], dstX: 600, dstY: 900);

      List<int> png = img.encodePng(combinedImage);
      File(combinedImagePath).writeAsBytesSync(png);

      await Gal.putImage(combinedImagePath);
      print('Combined image saved to gallery!');

      _imagePaths.clear();
      _pictureCount = 0;
    } catch (e) {
      print("Error combining images: $e");
    }
  }

  Future<void> _takePicture() async {
    try {
      final XFile file = await widget.controller.takePicture();
      final imageFile = File(file.path);
      _imagePaths.add(imageFile.path);
      _pictureCount++;
      if (_pictureCount == 4) {
        _combineImages();
      }
       _startCountdown();
    } catch (e) {
      print(e);
    }
  }

  

  @override
  Widget build(BuildContext context) {
    return _isCameraInitialized
        ? Scaffold(
          body: Stack(
            children: [
              SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: CameraPreview(widget.controller),
              ),
              Center(
                child: Text(
                  _countdown.toString(),
                  style: const TextStyle(fontSize: 100, color: Colors.white),
                ),
              ),
            ],
          ),
        )
        : const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
  bool get _isCameraInitialized => widget.controller.value.isInitialized;
}

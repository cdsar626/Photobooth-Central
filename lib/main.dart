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
  runApp(const MyApp());
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 64, 224, 208),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const CameraScreen(),
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
      ),
    );
  }
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  CameraScreenState createState() => CameraScreenState();
}

class CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  int _countdown = 3;
  final List<String> _imagePaths = [];
  int _pictureCount = 0;
  bool _isFlashing = false;
  Timer? _timer;

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
      _initializeControllerFuture!.then((_) {
        if (mounted) {
          setState(() {});
          _startCountdown();
        }
      });
    } else {
      print("Camera permission not granted");
    }
  }

  void _startCountdown() {
    if (_pictureCount < 4) {
      _countdown = 3; // Reset countdown before taking the next picture
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _countdown--;
          });
        }
        if (_countdown <= 0) {
          timer.cancel();
          _takePicture();
        }
      });
    }
  }

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

      List<img.Image> resizedImages = images
          .map((image) => img.copyResize(image!, width: 600, height: 900))
          .toList();

      img.Image combinedImage = img.Image(width: 1200, height: 1800);

      img.compositeImage(combinedImage, resizedImages[0], dstX: 0, dstY: 0);
      img.compositeImage(combinedImage, resizedImages[1], dstX: 600, dstY: 0);
      img.compositeImage(combinedImage, resizedImages[2], dstX: 0, dstY: 900);
      img.compositeImage(combinedImage, resizedImages[3],
          dstX: 600, dstY: 900);

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
      final XFile file = await _controller!.takePicture();
      final imageFile = File(file.path);
      await Gal.putImage(file.path);
      _imagePaths.add(imageFile.path);
      _pictureCount++;
      if (_pictureCount == 4) {
        if (mounted) Navigator.of(context).pop();
        _combineImages();
      } else {
        _startCountdown();
      }
      _flashScreen();
    } catch (e) {
      print(e);
    }
  }

  Future<void> _flashScreen() async {
    setState(() {
      _isFlashing = true;
    });
    await Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _isFlashing = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initializeControllerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return Scaffold(
            body: Stack(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: CameraPreview(_controller!),
                ),
                Center(
                  child: Text(
                    _countdown > 0 ? _countdown.toString() : "",
                    style: const TextStyle(fontSize: 100, color: Colors.white),
                  ),
                ),
                if (_isFlashing)
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.white.withOpacity(0.8),
                  )
                else
                  Container(),
              ],
            ),
          );
        } else {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: CameraApp());
  }
}

class CameraApp extends StatefulWidget {
  @override
  _CameraAppState createState() => _CameraAppState();
}

class _CameraAppState extends State<CameraApp> {
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
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder:
                          (context) => CameraScreen(controller: _controller!),
                    ),
                  );
                },
                child: const Text("Open Camera"),
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
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  int _countdown = 3;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() {
          _countdown--;
        });
      } else {
        timer.cancel();
        _takePicture();
      }
    });
  }

  Future<void> _takePicture() async {
    try {
      await widget.controller.takePicture();
      Navigator.of(context).pop();
    } catch (e) {
      print(e);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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
    ;
  }

  bool get _isCameraInitialized => widget.controller.value.isInitialized;
}

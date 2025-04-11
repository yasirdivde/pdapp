import 'package:flutter/material.dart';
import 'package:flutter_vision/flutter_vision.dart';
import 'package:camera/camera.dart';

late List<CameraDescription> camerass;

class YoloVideo extends StatefulWidget {
  const YoloVideo({super.key});

  @override
  State<YoloVideo> createState() => _YoloVideoState();
}

class _YoloVideoState extends State<YoloVideo> {
  late CameraController controller;
  late FlutterVision vision;
  late List<Map<String, dynamic>> yoloResults;

  CameraImage? cameraImage;
  bool isLoaded = false;
  bool isDetecting = false;

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    camerass = await availableCameras();
    vision = FlutterVision();
    controller = CameraController(camerass[0], ResolutionPreset.high);
    await controller.initialize();
    await loadYoloModel();
    setState(() {
      isLoaded = true;
      isDetecting = false;
      yoloResults = [];
    });
  }

  Future<void> loadYoloModel() async {
    await vision.loadYoloModel(
      labels: 'assets/potholes.txt',
      modelPath: 'assets/yolov8.tflite',
      modelVersion: "yolov8",
      numThreads: 1,
      useGpu: true,
    );
  }

  Future<void> yoloOnFrame(CameraImage image) async {
    final result = await vision.yoloOnFrame(
      bytesList: image.planes.map((plane) => plane.bytes).toList(),
      imageHeight: image.height,
      imageWidth: image.width,
      iouThreshold: 0.5,
      confThreshold: 0.5, // You can tune this
      classThreshold: 0.5,
    );
    if (result.isNotEmpty) {
      setState(() {
        yoloResults = result;
      });
    }
  }

  Future<void> startDetection() async {
    setState(() {
      isDetecting = true;
    });
    if (controller.value.isStreamingImages) return;
    await controller.startImageStream((image) async {
      if (isDetecting) {
        cameraImage = image;
        await yoloOnFrame(image);
      }
    });
  }

  Future<void> stopDetection() async {
    setState(() {
      isDetecting = false;
      yoloResults.clear();
    });
    await controller.stopImageStream();
  }

  List<Widget> displayBoxesAroundRecognizedObjects(Size screen) {
    if (yoloResults.isEmpty || cameraImage == null) return [];

    double factorX = screen.width / cameraImage!.height;
    double factorY = screen.height / cameraImage!.width;

    return yoloResults.map((result) {
      double x = result["box"][0] * factorX;
      double y = result["box"][1] * factorY;
      double width = (result["box"][2] - result["box"][0]) * factorX;
      double height = (result["box"][3] - result["box"][1]) * factorY;

      return Positioned(
        left: x,
        top: y,
        width: width,
        height: height,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.greenAccent, width: 2),
          ),
          child: Text(
            "${result['tag']} ${(result['box'][4] * 100).toStringAsFixed(0)}%",
            style: TextStyle(
              backgroundColor: Colors.greenAccent,
              color: Colors.black,
              fontSize: 16.0,
            ),
          ),
        ),
      );
    }).toList();
  }

  @override
  void dispose() {
    controller.dispose();
    vision.closeYoloModel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    if (!isLoaded) {
      return const Scaffold(
        body: Center(
          child: Text("Loading model, please wait..."),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: CameraPreview(controller),
          ),
          ...displayBoxesAroundRecognizedObjects(size),
          Positioned(
            bottom: 75,
            width: MediaQuery.of(context).size.width,
            child: Center(
              child: Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(width: 5, color: Colors.white),
                ),
                child: IconButton(
                  onPressed: isDetecting ? stopDetection : startDetection,
                  icon: Icon(
                    isDetecting ? Icons.stop : Icons.play_arrow,
                    color: isDetecting ? Colors.red : Colors.white,
                    size: 50,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

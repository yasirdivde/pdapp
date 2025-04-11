import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'yolo_video.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await requestCameraPermission(); // 👈 Important

  runApp(const MaterialApp(
    home: YoloVideo(),
    debugShowCheckedModeBanner: false,
  ));
}

Future<void> requestCameraPermission() async {
  var status = await Permission.camera.status;
  if (!status.isGranted) {
    await Permission.camera.request();
  }
}

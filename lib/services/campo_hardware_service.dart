import 'dart:async';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class GpsPosition {
  final double latitude;
  final double longitude;
  final double accuracy;

  const GpsPosition({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
  });

  /// Formatted as "lat,lng" with max 6 decimal places (S3 / S5)
  String get coordenadas =>
      '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}';
}

class GpsResult {
  final bool success;
  final GpsPosition? position;
  final String? error;

  const GpsResult.success(this.position)
      : success = true,
        error = null;

  const GpsResult.failure(this.error)
      : success = false,
        position = null;
}

abstract class CampoLocationService {
  Future<GpsResult> getCurrentPosition();
}

class GeolocatorCampoLocationService implements CampoLocationService {
  @override
  Future<GpsResult> getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const GpsResult.failure(
          'El servicio de ubicación (GPS) está desactivado. Por favor actívelo.',
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return const GpsResult.failure(
            'Permiso de ubicación denegado por el usuario.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return const GpsResult.failure(
          'Permiso de ubicación denegado permanentemente. Habilítelo en los ajustes del dispositivo.',
        );
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      return GpsResult.success(
        GpsPosition(
          latitude: pos.latitude,
          longitude: pos.longitude,
          accuracy: pos.accuracy,
        ),
      );
    } on TimeoutException {
      return const GpsResult.failure(
        'Tiempo de espera agotado al obtener la ubicación GPS.',
      );
    } catch (e) {
      return GpsResult.failure(
        'Error al obtener ubicación GPS: ${e.toString()}',
      );
    }
  }
}

class CameraPhotoResult {
  final bool success;
  final List<int>? bytes;
  final String? filename;
  final String? error;
  final bool isCancelled;

  const CameraPhotoResult.success({
    required this.bytes,
    required this.filename,
  })  : success = true,
        error = null,
        isCancelled = false;

  const CameraPhotoResult.failure(this.error)
      : success = false,
        bytes = null,
        filename = null,
        isCancelled = false;

  const CameraPhotoResult.cancelled()
      : success = false,
        bytes = null,
        filename = null,
        error = null,
        isCancelled = true;
}

abstract class CampoCameraService {
  Future<CameraPhotoResult> capturePhoto(BuildContext context);
}

class DefaultCampoCameraService implements CampoCameraService {
  @override
  Future<CameraPhotoResult> capturePhoto(BuildContext context) async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        return const CameraPhotoResult.failure(
          'No se encontraron cámaras disponibles en el dispositivo.',
        );
      }

      if (!context.mounted) return const CameraPhotoResult.cancelled();

      final bytes = await Navigator.push<List<int>>(
        context,
        MaterialPageRoute(
          builder: (_) => CampoCameraScreen(cameras: cameras),
        ),
      );

      if (bytes == null || bytes.isEmpty) {
        return const CameraPhotoResult.cancelled();
      }

      // Ensure photo is <= 5MB
      List<int> processedBytes = bytes;
      var extension = 'jpg';
      if (processedBytes.length > 5 * 1024 * 1024) {
        final downscaled = await _downscaleImage(processedBytes);
        if (downscaled != null) {
          // The downscaled image is PNG-encoded; its name drives the upload content type.
          processedBytes = downscaled;
          extension = 'png';
        }
      }

      if (processedBytes.length > 5 * 1024 * 1024) {
        return const CameraPhotoResult.failure(
          'La fotografía excede el tamaño máximo permitido de 5 MB.',
        );
      }

      final filename =
          'campo_${DateTime.now().millisecondsSinceEpoch}.$extension';
      return CameraPhotoResult.success(
        bytes: processedBytes,
        filename: filename,
      );
    } catch (e) {
      return CameraPhotoResult.failure(
        'Error al capturar fotografía con la cámara: $e',
      );
    }
  }

  Future<Uint8List?> _downscaleImage(List<int> bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(
        Uint8List.fromList(bytes),
        targetWidth: 1280,
      );
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }
}

class CampoCameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CampoCameraScreen({super.key, required this.cameras});

  @override
  State<CampoCameraScreen> createState() => _CampoCameraScreenState();
}

class _CampoCameraScreenState extends State<CampoCameraScreen> {
  CameraController? _controller;
  bool _initializing = true;
  bool _takingPicture = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final camera = widget.cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => widget.cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error al inicializar cámara: $e';
        _initializing = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized || _takingPicture) {
      return;
    }
    setState(() => _takingPicture = true);
    try {
      final xfile = await _controller!.takePicture();
      final bytes = await xfile.readAsBytes();
      if (!mounted) return;
      Navigator.pop(context, bytes);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _takingPicture = false;
        _error = 'Error al tomar fotografía: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (_error != null || _controller == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _error ?? 'No se pudo iniciar la cámara',
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Capturar Fotografía',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton(
                key: const Key('camera_shutter_btn'),
                backgroundColor: Colors.white,
                onPressed: _takingPicture ? null : _takePicture,
                child: _takingPicture
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Icon(Icons.camera_alt, color: Colors.black, size: 30),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

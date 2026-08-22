import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../services/gemini_service.dart';

/// Result handed back to the caller (TranslatorScreen) when the user
/// accepts recognized text — so it can be dropped straight into the
/// translation input instead of the user retyping it.
class CameraTranslateResult {
  final String recognizedText;
  CameraTranslateResult(this.recognizedText);
}

class CameraTranslateScreen extends StatefulWidget {
  const CameraTranslateScreen({super.key});

  @override
  State<CameraTranslateScreen> createState() => _CameraTranslateScreenState();
}

enum _ScanState { live, processing, result }

class _CameraTranslateScreenState extends State<CameraTranslateScreen> {
  CameraController? _controller;
  Future<void>? _initFuture;
  final GeminiService _gemini = GeminiService();
  final TextRecognizer _latinRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final TextRecognizer _devanagariRecognizer = TextRecognizer(script: TextRecognitionScript.devanagiri);

  _ScanState _state = _ScanState.live;
  String? _recognizedText;
  String? _statusMessage;
  bool _usedVisionFallback = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _errorMessage = 'No camera found on this device.');
        return;
      }
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _controller = CameraController(backCamera, ResolutionPreset.high, enableAudio: false);
      _initFuture = _controller!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      setState(() => _errorMessage = 'Could not start the camera: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _latinRecognizer.close();
    _devanagariRecognizer.close();
    super.dispose();
  }

  Future<void> _captureAndRecognize() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    setState(() {
      _state = _ScanState.processing;
      _statusMessage = 'Reading text...';
      _usedVisionFallback = false;
    });

    try {
      final photo = await controller.takePicture();

      // 1. Try on-device ML Kit first — instant, free, works offline.
      // Try Latin (English) then Devanagari (Hindi/Marathi). ML Kit
      // does NOT support Telugu or Tamil at all — step 2 covers those.
      final inputImage = InputImage.fromFilePath(photo.path);
      final latinResult = await _latinRecognizer.processImage(inputImage);
      String? text = latinResult.text.trim().isEmpty ? null : latinResult.text.trim();

      if (text == null) {
        final devanagariResult = await _devanagariRecognizer.processImage(inputImage);
        text = devanagariResult.text.trim().isEmpty ? null : devanagariResult.text.trim();
      }

      // 2. Fall back to Gemini vision if ML Kit found nothing — this
      // is what covers Telugu/Tamil signage, and also catches cases
      // where ML Kit just failed on messy real-world signage (angle,
      // lighting, handwriting, stylized fonts).
      if (text == null) {
        setState(() => _statusMessage = 'No Latin/Hindi text found — trying AI vision for regional scripts...');
        final bytes = await File(photo.path).readAsBytes();
        final visionText = await _gemini.readTextFromImage(bytes);
        if (visionText != null) {
          text = visionText;
          _usedVisionFallback = true;
        }
      }

      if (!mounted) return;

      if (text == null) {
        setState(() {
          _state = _ScanState.live;
          _errorMessage = 'Couldn\'t find readable text in that photo. Try getting closer or reducing glare.';
        });
      } else {
        setState(() {
          _recognizedText = text;
          _state = _ScanState.result;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _ScanState.live;
        _errorMessage = 'Something went wrong capturing that photo. Try again.';
      });
    }
  }

  void _retake() {
    setState(() {
      _state = _ScanState.live;
      _recognizedText = null;
      _errorMessage = null;
    });
  }

  void _useText() {
    if (_recognizedText == null) return;
    Navigator.pop(context, CameraTranslateResult(_recognizedText!));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan text to translate'),
      ),
      body: _errorMessage != null && _state == _ScanState.live && _controller == null
          ? _buildFatalError()
          : _buildBody(),
    );
  }

  Widget _buildFatalError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 48),
            const SizedBox(height: 12),
            Text(_errorMessage!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_state == _ScanState.result) {
      return _buildResultView();
    }
    return _buildCameraView();
  }

  Widget _buildCameraView() {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_initFuture != null)
          FutureBuilder(
            future: _initFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done || _controller == null) {
                return const Center(child: CircularProgressIndicator(color: Colors.white));
              }
              return CameraPreview(_controller!);
            },
          )
        else
          const Center(child: CircularProgressIndicator(color: Colors.white)),

        // Framing guide so users know where to aim — mirrors the
        // "point at the sign" affordance from Google Translate's
        // camera mode.
        if (_state == _ScanState.live)
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.82,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white70, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

        if (_errorMessage != null && _state == _ScanState.live)
          Positioned(
            top: 16, left: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.shade900, borderRadius: BorderRadius.circular(10)),
              child: Text(_errorMessage!, style: const TextStyle(color: Colors.white, fontSize: 13)),
            ),
          ),

        if (_state == _ScanState.processing)
          Container(
            color: Colors.black54,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 14),
                  Text(_statusMessage ?? 'Reading text...',
                      style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
                ],
              ),
            ),
          ),

        Positioned(
          bottom: 32, left: 0, right: 0,
          child: Center(
            child: GestureDetector(
              onTap: _state == _ScanState.live ? _captureAndRecognize : null,
              child: Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: Colors.white38, width: 4),
                ),
                child: const Icon(Icons.camera_alt_rounded, color: Colors.black87, size: 30),
              ),
            ),
          ),
        ),

        Positioned(
          bottom: 44, left: 24,
          child: Text(
            'Point at a sign or menu, then tap to scan',
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildResultView() {
    return Container(
      color: const Color(0xFF0D9488),
      padding: const EdgeInsets.all(20),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.text_snippet_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 8),
                const Text('Recognized text', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                if (_usedVisionFallback) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                    child: const Text('via AI vision', style: TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: SingleChildScrollView(
                  child: TextField(
                    controller: TextEditingController(text: _recognizedText),
                    maxLines: null,
                    style: const TextStyle(color: Color(0xFF1E1B4B), fontSize: 15, height: 1.4),
                    decoration: const InputDecoration(border: InputBorder.none),
                    onChanged: (v) => _recognizedText = v,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _retake,
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('Retake'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0D9488),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _useText,
                    icon: const Icon(Icons.translate_rounded),
                    label: const Text('Translate this'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

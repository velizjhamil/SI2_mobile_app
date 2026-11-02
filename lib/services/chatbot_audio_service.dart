import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Short dictation and explicit response playback for Castor.
class ChatbotAudioService {
  ChatbotAudioService({SpeechToText? speech, FlutterTts? tts})
      : _speech = speech ?? SpeechToText(),
        _tts = tts ?? FlutterTts() {
    _tts.setErrorHandler((_) => onPlaybackError?.call());
    _tts.setCompletionHandler(() => onPlaybackComplete?.call());
  }

  final SpeechToText _speech;
  final FlutterTts _tts;
  void Function(String text)? onTranscript;
  void Function(String error)? onSpeechError;
  void Function(bool listening)? onSpeechStatus;
  void Function()? onPlaybackError;
  void Function()? onPlaybackComplete;

  bool get isListening => _speech.isListening;

  Future<bool> startDictation() async {
    try {
      final available = await _speech.initialize(
        onError: (error) => onSpeechError?.call(error.errorMsg),
        onStatus: (status) {
          onSpeechStatus?.call(status == 'listening');
        },
      );
      if (!available) return false;
      final locales = await _speech.locales();
      final spanish = locales
          .where((locale) => locale.localeId.toLowerCase().startsWith('es'))
          .map((locale) => locale.localeId)
          .toList();
      await _speech.listen(
        listenOptions: SpeechListenOptions(
          localeId: spanish.isEmpty ? 'es-ES' : spanish.first,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
          partialResults: true,
        ),
        onResult: (SpeechRecognitionResult result) {
          if (result.recognizedWords.isNotEmpty) {
            onTranscript?.call(result.recognizedWords);
          }
        },
      );
      return _speech.isListening;
    } catch (error) {
      onSpeechError?.call(error.toString());
      return false;
    }
  }

  Future<void> stopDictation() async {
    try {
      await _speech.stop();
    } catch (error) {
      onSpeechError?.call(error.toString());
    }
  }

  Future<void> cancelDictation() async {
    try {
      await _speech.cancel();
    } catch (error) {
      onSpeechError?.call(error.toString());
    }
  }

  Future<void> speak(String text) async {
    try {
      final languages = ((await _tts.getLanguages) as List?) ?? const [];
      final spanish = languages
          .whereType<String>()
          .where((language) => language.toLowerCase().startsWith('es'))
          .toList();
      await _tts.setLanguage(spanish.isEmpty ? 'es-ES' : spanish.first);
      await _tts.speak(text);
    } catch (_) {
      onPlaybackError?.call();
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {
      onPlaybackError?.call();
    }
  }
}

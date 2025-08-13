// main.dart
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vad/vad.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text("VAD Example")),
        body: const MyHomePage(),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _vadHandler = VadHandler.create(isDebug: true);
  bool isListening = false;
  final List<String> receivedEvents = [];

  @override
  void initState() {
    super.initState();
    _setupVadHandler();
  }

  void _setupVadHandler() {
    _vadHandler.onSpeechStart.listen((_) {
      debugPrint('Speech detected.');
      setState(() {
        receivedEvents.add('Speech detected.');
      });
    });

    _vadHandler.onRealSpeechStart.listen((_) {
      debugPrint('Real speech start detected (not a misfire).');
      setState(() {
        receivedEvents.add('Real speech start detected (not a misfire).');
      });
    });

    _vadHandler.onSpeechEnd.listen((List<double> samples) {
      debugPrint('Speech ended, first 10 samples: ${samples.take(10).toList()}');
      setState(() {
        receivedEvents.add('Speech ended, first 10 samples: ${samples.take(10).toList()}');
      });
    });

    _vadHandler.onFrameProcessed.listen((frameData) {
      final isSpeech = frameData.isSpeech;
      final notSpeech = frameData.notSpeech;
      final firstFewSamples = frameData.frame.take(5).toList();

      debugPrint('Frame processed - Speech probability: $isSpeech, Not speech: $notSpeech');
      debugPrint('First few audio samples: $firstFewSamples');

      // You can use this for real-time audio processing
    });

    _vadHandler.onVADMisfire.listen((_) {
      debugPrint('VAD misfire detected.');
      setState(() {
        receivedEvents.add('VAD misfire detected.');
      });
    });

    _vadHandler.onError.listen((String message) {
      debugPrint('Error: $message');
      setState(() {
        receivedEvents.add('Error: $message');
      });
    });
  }

  @override
  void dispose() {
    _vadHandler.dispose(); // Note: dispose() is called without await in Widget.dispose()
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton.icon(
            onPressed: () async {
              if (isListening) {
                await _vadHandler.stopListening();
              } else {
                await _vadHandler.startListening();
              }
              setState(() {
                isListening = !isListening;
              });
            },
            icon: Icon(isListening ? Icons.stop : Icons.mic),
            label: Text(isListening ? "Stop Listening" : "Start Listening"),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () async {
              final status = await Permission.microphone.request();
              debugPrint("Microphone permission status: $status");
            },
            icon: const Icon(Icons.settings_voice),
            label: const Text("Request Microphone Permission"),
            style: TextButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: receivedEvents.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(receivedEvents[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'accessibility_service.dart';
import 'gemini_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print("Could not load .env file: $e");
  }
  runApp(const PocketPilotApp());
}

class PocketPilotApp extends StatelessWidget {
  const PocketPilotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PocketPilot',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.teal,
        colorScheme: const ColorScheme.dark(primary: Colors.teal, secondary: Colors.tealAccent),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool _isAccessibilityEnabled = false;
  final TextEditingController _taskController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final List<String> _logs = [];

  bool _isRunning = false;
  bool _isPaused = false;
  
  GeminiService? _geminiService;

  @override
  void initState() {
    super.initState();
    _apiKeyController.text = dotenv.env['GEMINI_API_KEY'] ?? '';
    _checkAccessibility();
  }

  void _checkAccessibility() async {
    final enabled = await AccessibilityService.isServiceEnabled();
    setState(() {
      _isAccessibilityEnabled = enabled;
    });
  }

  void _log(String message) {
    final logText = '${DateTime.now().toLocal().toString().split(".")[0]}: $message';
    debugPrint(logText);
    setState(() {
      _logs.add(logText);
    });
  }

  Future<void> _agentLoop() async {
    if (_geminiService == null) return;
    
    while (_isRunning && !_isPaused) {
      _log("Observing current UI...");
      final tree = await AccessibilityService.getUITree();
      if (tree == null) {
        _log("Failed to get UI tree. Retrying in 2s...");
        await Future.delayed(const Duration(seconds: 2));
        continue;
      }
      
      _log("Planning next step...");
      final stepResult = await _geminiService!.step(tree);
      
      _log("Action: $stepResult");

      if (stepResult.contains('Task completed!') || stepResult.contains('Need help:')) {
        _isRunning = false;
        break;
      }
      
      // Wait a moment between actions for screen to update
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  void _startTask() {
    if (!_isAccessibilityEnabled) {
      _log("Please enable Accessibility Service first.");
      return;
    }
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      _log("Please enter a Gemini API Key.");
      return;
    }
    final task = _taskController.text.trim();
    if (task.isEmpty) {
      _log("Please enter a task.");
      return;
    }
    
    setState(() {
      _isRunning = true;
      _isPaused = false;
      _geminiService = GeminiService(apiKey);
    });
    
    _geminiService!.startNewTask(task);
    _log("Started task: $task");
    
    _agentLoop();
  }

  void _stopTask() {
    setState(() {
      _isRunning = false;
      _isPaused = false;
    });
    _log("Task stopped by user.");
  }

  void _pauseTask() {
    setState(() {
      _isPaused = true;
    });
    _log("Task paused by user.");
  }

  void _resumeTask() {
    setState(() {
      _isPaused = false;
    });
    _log("Task resumed by user.");
    _agentLoop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PocketPilot AI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _checkAccessibility();
              _log("Checked accessibility status.");
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  _isAccessibilityEnabled ? Icons.check_circle : Icons.error,
                  color: _isAccessibilityEnabled ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isAccessibilityEnabled
                        ? "Accessibility Service Active"
                        : "Inactive (Toggle OFF then ON in settings)",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (!_isAccessibilityEnabled)
                  ElevatedButton(
                    onPressed: () => AccessibilityService.openSettings(),
                    child: const Text('ENABLE'),
                  )
              ],
            ),
            const Divider(),
            TextField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                labelText: 'Gemini API Key',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _taskController,
              decoration: const InputDecoration(
                labelText: 'What do you want to automate?',
                hintText: 'e.g., Open calculator and type 5 + 5',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (!_isRunning)
                  ElevatedButton.icon(
                    onPressed: _startTask,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                if (_isRunning && !_isPaused)
                  ElevatedButton.icon(
                    onPressed: _pauseTask,
                    icon: const Icon(Icons.pause),
                    label: const Text('Pause'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  ),
                if (_isRunning && _isPaused)
                  ElevatedButton.icon(
                    onPressed: _resumeTask,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Resume'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                if (_isRunning)
                  ElevatedButton.icon(
                    onPressed: _stopTask,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text("Execution Logs:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey),
                ),
                child: ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    return Text(
                      _logs[index],
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

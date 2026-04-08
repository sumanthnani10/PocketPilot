import 'dart:async';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_page.dart';
import 'accessibility_service.dart';
import 'gemini_service.dart';
import 'assistive_touch_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Could not load .env file: \$e");
  }
  final initialRoute = PlatformDispatcher.instance.defaultRouteName;
  runApp(const PocketPilotApp());
}

@pragma('vm:entry-point')
void overlayMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Could not load .env file: \$e");
  }
  
  String imagePath = '';
  try {
    const channel = MethodChannel('pocketpilot/accessibility');
    imagePath = await channel.invokeMethod('getInitialImagePath');
  } catch (e) {
    debugPrint("Could not get initial image path: \$e");
  }

  runApp(OverlayApp(imagePath: imagePath));
}

class OverlayApp extends StatelessWidget {
  final String imagePath;
  const OverlayApp({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return ShadApp(
      debugShowCheckedModeBanner: false,
      home: OverlayRootScreen(imagePath: imagePath),
    );
  }
}

class OverlayRootScreen extends StatefulWidget {
  final String imagePath;
  const OverlayRootScreen({super.key, required this.imagePath});
  @override
  State<OverlayRootScreen> createState() => _OverlayRootScreenState();
}

class _OverlayRootScreenState extends State<OverlayRootScreen> {
  GeminiService? _geminiService;
  late String _currentImagePath;
  Key _screenKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _currentImagePath = widget.imagePath;
    _initService();

    AccessibilityService.initialize((newImagePath) {
      if (mounted) {
        setState(() {
          _currentImagePath = newImagePath;
          // Removed UniqueKey reset to preserve chat history
        });
      }
    });
  }

  Future<void> _initService() async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('GEMINI_API_KEY') ?? dotenv.env['GEMINI_API_KEY'] ?? '';
    if (apiKey.isNotEmpty) {
      if (mounted) {
        setState(() {
          _geminiService = GeminiService(apiKey);
        });
      }
    } else {
      AccessibilityService.showGlobalToast("Cannot open overlay: API Key missing.");
      AccessibilityService.closeOverlay();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_geminiService == null) {
      return const Scaffold(backgroundColor: Colors.transparent);
    }
    return AssistiveTouchScreen(
      imagePath: _currentImagePath,
      geminiService: _geminiService!,
      onDismiss: () => AccessibilityService.closeOverlay(),
      onTaskProceed: (task) {
        AccessibilityService.closeOverlay();
        AccessibilityService.startTaskLoop(task);
      },
    );
  }
}

class PocketPilotApp extends StatelessWidget {
  const PocketPilotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ShadApp(
      navigatorKey: navigatorKey,
      title: 'PocketPilot',
      debugShowCheckedModeBanner: false,
      theme: ShadThemeData(
        brightness: Brightness.light,
        colorScheme: const ShadZincColorScheme.light(
          primary: Color(0xFF4F46E5), // Indigo 600
        ),
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

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _isAccessibilityEnabled = true; // Defaulting to true for demo but checked realistically
  final TextEditingController _taskController = TextEditingController();
  String _apiKey = '';
  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();

  bool _isRunning = false;
  bool _isPaused = false;
  bool _isOverlayActive = false;
  
  GeminiService? _geminiService;
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    _loadSettings();
    _checkAccessibility();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    ));

    AccessibilityService.initialize((imagePath) {
      // Note: This trigger is historically caught by the main dashboard.
      // But now, the service natively launches the overlay separate app.
    });

    AccessibilityService.onStartTask = (task) async {
      // Delay so the Android OS has enough time to switch away from the dying Overlay
      // and bring the background application (e.g. YouTube) fully into front focus.
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        setState(() {
          _taskController.text = task;
        });
        _startTask(); // Starts Agent loop
      }
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animController.dispose();
    _taskController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isAccessibilityEnabled) {
      _checkAccessibility();
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString('GEMINI_API_KEY');
    if (savedKey != null && savedKey.isNotEmpty) {
      if (mounted) {
        setState(() {
          _apiKey = savedKey;
        });
      }
    }
  }

  void _openSettings() async {
    final newKey = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsPage(initialApiKey: _apiKey),
      ),
    );
    if (newKey != null && newKey is String && mounted) {
      setState(() {
        _apiKey = newKey;
      });
    }
  }

  void _checkAccessibility() async {
    final enabled = await AccessibilityService.isServiceEnabled();
    if (mounted) {
      setState(() {
        _isAccessibilityEnabled = enabled;
      });
    }
  }

  void _log(String message) {
    final time = DateTime.now().toLocal().toString().split(" ")[1].substring(0, 8);
    final logText = '[$time] $message';
    debugPrint(logText);
    AccessibilityService.showGlobalToast(logText);
    if (mounted) {
      setState(() {
        _logs.add(logText);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
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
        if (mounted) {
          setState(() {
            _isRunning = false;
          });
        }
        break;
      }
      
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  void _startTask() {
    if (!_isAccessibilityEnabled) {
      _log("Please enable Accessibility Service first.");
      _showSettingsDialog();
      return;
    }
    final apiKey = _apiKey.trim();
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

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Accessibility Required"),
          content: const Text("PocketPilot needs accessibility permissions to observe and interact with apps on your behalf."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                AccessibilityService.openSettings();
              },
              child: const Text("Open Settings"),
            ),
          ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8), // Very light bright grayish blue tech background
      body: Stack(
        children: [
          // Background Techy Animated Blobs / Gradients
          Positioned(
            top: -100,
            left: -100,
            child: ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 400,
                height: 400,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0xFF00C9FF), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -100,
            child: ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 500,
                height: 500,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0xFFFF92FE), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          // Glassmorphism effect
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(color: const Color(0x4DFFFFFF)), // White at ~30% alpha
            ),
          ),
          // App Content
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildStatusBanner(),
                        const SizedBox(height: 24),
                        _buildTaskCard(),
                        const SizedBox(height: 24),
                        _buildControls(),
                        const SizedBox(height: 32),
                        _buildLogsSection(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(color: Color(0x66000000), blurRadius: 4, offset: Offset(0, 2)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'PocketPilot',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: -0.5, color: Color(0xFF1E293B)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: ShadButton(
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.white,
                  onPressed: () {
                    _checkAccessibility();
                    _log("Status refreshed.");
                  },
                  child: const Icon(Icons.refresh, size: 20, color: Color(0xFF1E293B)),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                height: 40,
                child: ShadButton(
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.white,
                  onPressed: _openSettings,
                  child: const Icon(Icons.settings, size: 20, color: Color(0xFF1E293B)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _isAccessibilityEnabled 
          ? const Color(0x1A10B981) // Green at 10%
          : const Color(0x1AEF4444), // Red at 10%
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isAccessibilityEnabled ? const Color(0xFF10B981) : const Color(0xFFEF4444),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isAccessibilityEnabled ? Icons.check_circle : Icons.error,
            color: _isAccessibilityEnabled ? const Color(0xFF10B981) : const Color(0xFFEF4444),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isAccessibilityEnabled ? "Service is Active & Ready" : "Accessibility Service Offline",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _isAccessibilityEnabled ? const Color(0xFF047857) : const Color(0xFFB91C1C),
              ),
            ),
          ),
          if (!_isAccessibilityEnabled)
            ShadButton(
              onPressed: _showSettingsDialog,
              backgroundColor: const Color(0xFFEF4444),
              child: const Text('Resolve'),
            ),
        ],
      ),
    );
  }


  Widget _buildTaskCard() {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.terminal, size: 20, color: Color(0xFFEC4899)),
              SizedBox(width: 8),
              Text("Task Prompt", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            ],
          ),
          const SizedBox(height: 16),
          ShadInput(
            controller: _taskController,
            placeholder: const Text('e.g., Post a sunset photo on Instagram'),
            minLines: 3,
            maxLines: 5,
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!_isRunning)
          _glowingButton(
            label: "Initialize Run",
            icon: LucideIcons.play,
            gradient: const LinearGradient(colors: [Color(0xFF00C9FF), Color(0xFF92FE9D)]),
            onTap: _startTask,
          ),
        if (_isRunning && !_isPaused) ...[
          _glowingButton(
            label: "Pause",
            icon: LucideIcons.pause,
            gradient: const LinearGradient(colors: [Color(0xFFF5AF19), Color(0xFFF12711)]),
            onTap: _pauseTask,
          ),
          const SizedBox(width: 16),
        ],
        if (_isRunning && _isPaused) ...[
          _glowingButton(
            label: "Resume",
            icon: LucideIcons.play,
            gradient: const LinearGradient(colors: [Color(0xFF00C9FF), Color(0xFF92FE9D)]),
            onTap: _resumeTask,
          ),
          const SizedBox(width: 16),
        ],
        if (_isRunning)
          _glowingButton(
            label: "Halt",
            icon: LucideIcons.square,
            gradient: const LinearGradient(colors: [Color(0xFFED213A), Color(0xFF93291E)]),
            onTap: _stopTask,
          ),
      ],
    );
  }

  Widget _buildLogsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(LucideIcons.scrollText, size: 20, color: Color(0xFF64748B)),
            SizedBox(width: 8),
            Text("Execution Telemetry", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 250,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A), // Dark techy box for logs fits perfectly
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155), width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000), // Black at ~10%
                blurRadius: 20,
                offset: Offset(0, 10),
              )
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: _logs.isEmpty 
              ? const Center(
                  child: Text(
                    "Awaiting instructions...",
                    style: TextStyle(color: Color(0xFF475569), fontFamily: 'monospace', fontSize: 13),
                  ),
                )
              : ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _logs.length,
                  separatorBuilder: (context, index) => const Divider(color: Color(0xFF1E293B)),
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    Color logColor = const Color(0xFF10B981); // Bright green
                    if (log.contains("Failed") || log.contains("Error")) logColor = const Color(0xFFEF4444);
                    if (log.contains("Action:")) logColor = const Color(0xFF38BDF8); // Bright blue
                    
                    return Text(
                      log,
                      style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: logColor),
                    );
                  },
              ),
          ),
        ),
      ],
    );
  }

  // Helpers

  Widget _glassCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xB3FFFFFF), // White at ~70%
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2694A3B8), // Slate 400 at ~15%
            blurRadius: 24,
            offset: Offset(0, 8),
          )
        ],
      ),
      child: child,
    );
  }

  Widget _glowingButton({required String label, required IconData icon, required Gradient gradient, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(30),
          // We can't easily grab gradient.colors.first as an opaque color here for the BoxShadow
          // if it's dynamic, but since we supply solid gradients, we can use a generic shadow.
          boxShadow: const [
             BoxShadow(
              color: Color(0x33000000), // Black 20%
              blurRadius: 16,
              offset: Offset(0, 8),
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5),
            )
          ],
        ),
      ),
    );
  }
}

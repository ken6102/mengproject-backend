import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kBackendBaseUrl = 'http://192.168.1.131:8000';

void main() => runApp(const MEngProjectApp());

class MEngProjectApp extends StatefulWidget {
  const MEngProjectApp({super.key});

  @override
  State<MEngProjectApp> createState() => _MEngProjectAppState();
}

class _MEngProjectAppState extends State<MEngProjectApp> {
  ThemeMode _themeMode = ThemeMode.system;

  bool _isLoadingPrefs = true;
  bool _pinEnabled = false;
  bool _isUnlocked = false;
  String? _savedPin;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final pinEnabled = prefs.getBool('pin_enabled') ?? false;
    final savedPin = prefs.getString('pin_code');

    setState(() {
      _pinEnabled = pinEnabled && savedPin != null && savedPin.isNotEmpty;
      _savedPin = savedPin;
      _isUnlocked = !_pinEnabled;
      _isLoadingPrefs = false;
    });
  }

  void _setThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
  }

  Future<void> _enablePin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pin_code', pin);
    await prefs.setBool('pin_enabled', true);

    setState(() {
      _savedPin = pin;
      _pinEnabled = true;
      _isUnlocked = true;
    });
  }

  Future<void> _changePin(String newPin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pin_code', newPin);

    setState(() {
      _savedPin = newPin;
    });
  }

  Future<void> _disablePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pin_code');
    await prefs.setBool('pin_enabled', false);

    setState(() {
      _savedPin = null;
      _pinEnabled = false;
      _isUnlocked = true;
    });
  }

  void _unlockWithPin(String enteredPin) {
    if (_savedPin != null && enteredPin == _savedPin) {
      setState(() {
        _isUnlocked = true;
      });
    }
  }

  void _lockAppNow() {
    if (_pinEnabled) {
      setState(() {
        _isUnlocked = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingPrefs) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'MEng Project',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        scaffoldBackgroundColor: const Color(0xFFF4F7FB),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0D1117),
      ),
      home: _pinEnabled && !_isUnlocked
          ? PinUnlockPage(
              onUnlock: _unlockWithPin,
            )
          : RootShell(
              themeMode: _themeMode,
              onThemeChanged: _setThemeMode,
              pinEnabled: _pinEnabled,
              onEnablePin: _enablePin,
              onChangePin: _changePin,
              onDisablePin: _disablePin,
              onLockNow: _lockAppNow,
              currentPin: _savedPin,
            ),
    );
  }
}

class RootShell extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  final bool pinEnabled;
  final Future<void> Function(String pin) onEnablePin;
  final Future<void> Function(String newPin) onChangePin;
  final Future<void> Function() onDisablePin;
  final VoidCallback onLockNow;
  final String? currentPin;

  const RootShell({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
    required this.pinEnabled,
    required this.onEnablePin,
    required this.onChangePin,
    required this.onDisablePin,
    required this.onLockNow,
    required this.currentPin,
  });

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomePage(),
      const ScanPage(),
      const HistoryPage(),
      SettingsPage(
        themeMode: widget.themeMode,
        onThemeChanged: widget.onThemeChanged,
        pinEnabled: widget.pinEnabled,
        onEnablePin: widget.onEnablePin,
        onChangePin: widget.onChangePin,
        onDisablePin: widget.onDisablePin,
        onLockNow: widget.onLockNow,
        currentPin: widget.currentPin,
      ),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.document_scanner_outlined),
            selectedIcon: Icon(Icons.document_scanner),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({
    required this.text,
    required this.isUser,
  });
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<ChatMessage> _messages = [
    ChatMessage(
      text:
          'Hello, I’m the App Assistant. I can help with questions about using the app, the Scan page, History, Settings, and current prototype features.',
      isUser: false,
    ),
  ];

  String _generateBotReply(String userMessage) {
    final message = userMessage.toLowerCase().trim();

    if (message.contains('scan') ||
        message.contains('analyse') ||
        message.contains('analyze') ||
        message.contains('image') ||
        message.contains('photo') ||
        message.contains('camera') ||
        message.contains('upload')) {
      return 'To use the Scan page, go to the Scan tab, upload an image from the gallery or capture one using the camera, then press Analyse Image. The current version supports image selection and a prototype analysis flow.';
    }

    if (message.contains('history') ||
        message.contains('previous') ||
        message.contains('recent result') ||
        message.contains('past result')) {
      return 'The History section is intended to show previous scan results. It currently displays placeholder entries, but later it will store analysed cases along with result details and patient-linked information.';
    }

    if (message.contains('about') ||
        message.contains('credits') ||
        message.contains('version')) {
      return 'The About page contains the app version, intended user group, prototype purpose, disclaimer, and project credits.';
    }

    if (message.contains('diagnosis') ||
        message.contains('diagnostic') ||
        message.contains('medical advice') ||
        message.contains('doctor') ||
        message.contains('cancer')) {
      return 'This prototype is not a medical diagnosis tool. It is intended as a clinical decision-support demonstration and should not replace GP judgement or formal clinical assessment.';
    }

    if (message.contains('explainability') ||
        message.contains('xai') ||
        message.contains('heatmap') ||
        message.contains('feature')) {
      return 'A later version is planned to include explainability features such as highlighted image regions, feature-based outputs, and supporting information to make model behaviour easier to interpret.';
    }

    if (message.contains('settings') ||
        message.contains('theme') ||
        message.contains('pin') ||
        message.contains('password') ||
        message.contains('lock')) {
      return 'The Settings page currently supports theme selection, PIN-based access, and an About section. The PIN feature can be used to protect app access locally on the device.';
    }

    if (message.contains('chatbot') ||
        message.contains('assistant') ||
        message.contains('help')) {
      return 'I am currently a local prototype assistant built to answer questions about how the app works. Later, this could be replaced with a backend-connected AI assistant.';
    }

    if (message.contains('backend') ||
        message.contains('python') ||
        message.contains('server') ||
        message.contains('api')) {
      return 'Backend integration is planned for a later stage. The expected flow is that the app will send an image to a Python backend, receive the model output, and display the result inside the app.';
    }

    return 'I can currently help with questions about the Scan page, History, Settings, About, explainability, and how this prototype is intended to be used.';
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _messages.add(
        ChatMessage(
          text: _generateBotReply(text),
          isUser: false,
        ),
      );
    });

    _messageController.clear();
    _scrollToBottom();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0EA5E9), Color(0xFF3B82F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(28),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.white24,
                          child: Icon(
                            Icons.health_and_safety,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'MEng Project',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'AI-powered support for skin lesion screening.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, color: Colors.white),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Designed as a clinical decision-support prototype for GP-facing workflows.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate(
              [
                Text(
                  'App Assistant',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: scheme.primaryContainer,
                              child: Icon(
                                Icons.smart_toy_outlined,
                                color: scheme.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Ask questions about the app and current prototype features.',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          height: 260,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: ListView.separated(
                            controller: _scrollController,
                            itemCount: _messages.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final message = _messages[index];
                              return Align(
                                alignment: message.isUser
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  constraints: const BoxConstraints(
                                    maxWidth: 280,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: message.isUser
                                        ? scheme.primary
                                        : scheme.surface,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    message.text,
                                    style: TextStyle(
                                      color: message.isUser
                                          ? Colors.white
                                          : null,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _sendMessage(),
                                decoration: const InputDecoration(
                                  hintText: 'Ask about the app...',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              height: 54,
                              child: FilledButton(
                                onPressed: _sendMessage,
                                child: const Icon(Icons.send),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
  Uint8List? _imageBytes;
  String _status = 'No image selected';
  bool _isAnalysing = false;

  String _resultLabel = 'Awaiting analysis';
  String _resultConfidence = '--';
  String _resultMessage = 'Model output will appear here later.';

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1024,
      );

      if (pickedFile == null) {
        return;
      }

      final bytes = await pickedFile.readAsBytes();

      setState(() {
        _selectedImage = File(pickedFile.path);
        _imageBytes = bytes;
        _status = source == ImageSource.camera
            ? 'Photo captured successfully'
            : 'Image selected successfully';

        _resultLabel = 'Awaiting analysis';
        _resultConfidence = '--';
        _resultMessage = 'Press Analyse Image to send the image to the backend.';
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load image: $e'),
        ),
      );
    }
  }

  Future<void> _analyseImage() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or capture an image first'),
        ),
      );
      return;
    }

    setState(() {
      _isAnalysing = true;
      _status = 'Uploading and analysing...';
      _resultLabel = 'Analysing...';
      _resultConfidence = '--';
      _resultMessage = 'Please wait while the backend processes the image.';
    });

    try {
      final uri = Uri.parse('$kBackendBaseUrl/predict/');
      final request = http.MultipartRequest('POST', uri)
        ..files.add(
          await http.MultipartFile.fromPath(
            'file',
            _selectedImage!.path,
          ),
        );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final confidenceValue = (data['confidence'] as num?)?.toDouble();

        setState(() {
          _isAnalysing = false;
          _status = 'Analysis complete';
          _resultLabel = (data['label'] ?? 'unknown').toString();
          _resultConfidence = confidenceValue != null
              ? '${(confidenceValue * 100).toStringAsFixed(1)}%'
              : '--';
          _resultMessage =
              (data['message'] ?? 'No message returned from backend.').toString();
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Analysis complete')),
        );
      } else {
        setState(() {
          _isAnalysing = false;
          _status = 'Error';
          _resultLabel = 'Error';
          _resultConfidence = '--';
          _resultMessage =
              'Backend returned status code ${response.statusCode}.';
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${response.statusCode} ${response.body}',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isAnalysing = false;
        _status = 'Error';
        _resultLabel = 'Connection error';
        _resultConfidence = '--';
        _resultMessage =
            'Could not connect to backend. Check the server is running.';
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            height: 260,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: scheme.outlineVariant,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: _imageBytes != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(
                        _imageBytes!,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            _status,
                            style: const TextStyle(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 64,
                        color: scheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Image Preview Area',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _status,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Upload'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Camera'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _isAnalysing ? null : _analyseImage,
              child: _isAnalysing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : const Text('Analyse Image'),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Result',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('Classification: $_resultLabel'),
                  const SizedBox(height: 6),
                  Text('Confidence: $_resultConfidence'),
                  const SizedBox(height: 6),
                  Text('Notes: $_resultMessage'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  final List<Map<String, String>> dummyHistory = const [
    {
      'date': '12 Mar 2026',
      'result': 'Benign-like',
      'confidence': '91%',
    },
    {
      'date': '07 Mar 2026',
      'result': 'Needs review',
      'confidence': '78%',
    },
    {
      'date': '01 Mar 2026',
      'result': 'Benign-like',
      'confidence': '88%',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        centerTitle: true,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: dummyHistory.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = dummyHistory[index];
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                child: Text('${index + 1}'),
              ),
              title: Text(item['result']!),
              subtitle: Text(
                '${item['date']} • Confidence: ${item['confidence']}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          );
        },
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  final bool pinEnabled;
  final Future<void> Function(String pin) onEnablePin;
  final Future<void> Function(String newPin) onChangePin;
  final Future<void> Function() onDisablePin;
  final VoidCallback onLockNow;
  final String? currentPin;

  const SettingsPage({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
    required this.pinEnabled,
    required this.onEnablePin,
    required this.onChangePin,
    required this.onDisablePin,
    required this.onLockNow,
    required this.currentPin,
  });

  Future<void> _showCreatePinDialog(BuildContext context) async {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Set PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              decoration: const InputDecoration(
                labelText: 'Enter 4-digit PIN',
              ),
            ),
            TextField(
              controller: confirmController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              decoration: const InputDecoration(
                labelText: 'Confirm PIN',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final pin = pinController.text.trim();
              final confirm = confirmController.text.trim();

              if (pin.length != 4 ||
                  confirm.length != 4 ||
                  int.tryParse(pin) == null ||
                  pin != confirm) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter matching 4-digit PINs'),
                  ),
                );
                return;
              }

              await onEnablePin(pin);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showChangePinDialog(BuildContext context) async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change PIN'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                decoration: const InputDecoration(
                  labelText: 'Current PIN',
                ),
              ),
              TextField(
                controller: newController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                decoration: const InputDecoration(
                  labelText: 'New 4-digit PIN',
                ),
              ),
              TextField(
                controller: confirmController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                decoration: const InputDecoration(
                  labelText: 'Confirm new PIN',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final current = currentController.text.trim();
              final newPin = newController.text.trim();
              final confirm = confirmController.text.trim();

              if (current != currentPin) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Current PIN is incorrect'),
                  ),
                );
                return;
              }

              if (newPin.length != 4 ||
                  confirm.length != 4 ||
                  int.tryParse(newPin) == null ||
                  newPin != confirm) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter matching 4-digit PINs'),
                  ),
                );
                return;
              }

              await onChangePin(newPin);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDisablePinDialog(BuildContext context) async {
    final currentController = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Disable PIN'),
        content: TextField(
          controller: currentController,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 4,
          decoration: const InputDecoration(
            labelText: 'Enter current PIN',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (currentController.text.trim() != currentPin) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Incorrect PIN'),
                  ),
                );
                return;
              }

              await onDisablePin();
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Disable'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Appearance',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode),
                label: Text('Light'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode),
                label: Text('Dark'),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.settings_suggest),
                label: Text('System'),
              ),
            ],
            selected: {themeMode},
            onSelectionChanged: (set) => onThemeChanged(set.first),
          ),
          const SizedBox(height: 18),
          Text(
            'System mode follows the theme of your mobile device.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 28),
          const Text(
            'Security',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          SettingsTile(
            icon: Icons.pin_outlined,
            title: pinEnabled ? 'Change PIN' : 'Set PIN',
            subtitle: pinEnabled
                ? 'Update your current app PIN'
                : 'Create a 4-digit PIN for app access',
            onTap: () {
              if (pinEnabled) {
                _showChangePinDialog(context);
              } else {
                _showCreatePinDialog(context);
              }
            },
          ),
          if (pinEnabled)
            SettingsTile(
              icon: Icons.lock_outline,
              title: 'Lock App Now',
              subtitle: 'Immediately require PIN access',
              onTap: onLockNow,
            ),
          if (pinEnabled)
            SettingsTile(
              icon: Icons.lock_open_outlined,
              title: 'Disable PIN',
              subtitle: 'Turn off PIN protection',
              onTap: () => _showDisablePinDialog(context),
            ),
          const SizedBox(height: 28),
          const Text(
            'Other Settings',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          SettingsTile(
            icon: Icons.info_outline,
            title: 'About',
            subtitle: 'Credits, version, and app details',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AboutPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class PinUnlockPage extends StatefulWidget {
  final ValueChanged<String> onUnlock;

  const PinUnlockPage({
    super.key,
    required this.onUnlock,
  });

  @override
  State<PinUnlockPage> createState() => _PinUnlockPageState();
}

class _PinUnlockPageState extends State<PinUnlockPage> {
  final TextEditingController _pinController = TextEditingController();
  String _errorText = '';

  void _submit() {
    final pin = _pinController.text.trim();

    if (pin.length != 4 || int.tryParse(pin) == null) {
      setState(() {
        _errorText = 'Please enter a valid 4-digit PIN';
      });
      return;
    }

    widget.onUnlock(pin);

    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() {
          _errorText = '';
        });
      }
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock, size: 52),
                    const SizedBox(height: 16),
                    const Text(
                      'Enter PIN',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This app is PIN protected.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 4,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        labelText: '4-digit PIN',
                        errorText: _errorText.isEmpty ? null : _errorText,
                        border: const OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _submit,
                        child: const Text('Unlock'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MEng Project',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'AI support tool for skin lesion screening.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Application Information',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          const InfoCard(
            title: 'Version',
            content: 'Prototype v1.0.0',
          ),
          const InfoCard(
            title: 'Intended Users',
            content:
                'Designed for NHS GP-facing clinical support workflow demonstrations.',
          ),
          const InfoCard(
            title: 'Purpose',
            content:
                'This prototype explores how machine learning and mobile interface design can support skin lesion assessment in a healthcare setting.',
          ),
          const InfoCard(
            title: 'Disclaimer',
            content:
                'This application is a research and demonstration prototype only. It does not provide a medical diagnosis and should not be used as a substitute for clinical judgement.',
          ),
          const SizedBox(height: 18),
          Text(
            'Credits',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kennasa Ahmed'),
                  SizedBox(height: 8),
                  Text('Gurtej Panesar'),
                  SizedBox(height: 8),
                  Text('Jatinder Dhaliwal'),
                  SizedBox(height: 8),
                  Text('Nadia Ismail Mohammad'),
                  SizedBox(height: 8),
                  Text('Emily Speed'),
                  SizedBox(height: 8),
                  Text('Holly Azarinejad'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  final String title;
  final String content;

  const InfoCard({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(content),
          ],
        ),
      ),
    );
  }
}

class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
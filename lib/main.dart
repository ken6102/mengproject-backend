import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kBackendBaseUrl = 'https://mengproject-backend.onrender.com';

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

  bool _unlockWithPin(String enteredPin) {
    if (_savedPin != null && enteredPin == _savedPin) {
      setState(() {
        _isUnlocked = true;
      });
      return true;
    }
    return false;
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

class ScanRecord {
  final String id;
  final String patientName;
  final int age;
  final String fst;
  final String label;
  final double confidence;
  final String notes;
  final String imageBase64;
  final String timestamp;
  final String xaiExplanation;
  final String asymmetryLabel;
  final String borderLabel;
  final String colourLabel;
  final String gradcamBase64;

  const ScanRecord({
    required this.id,
    required this.patientName,
    required this.age,
    required this.fst,
    required this.label,
    required this.confidence,
    required this.notes,
    required this.imageBase64,
    required this.timestamp,
    required this.xaiExplanation,
    required this.asymmetryLabel,
    required this.borderLabel,
    required this.colourLabel,
    required this.gradcamBase64,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientName': patientName,
      'age': age,
      'fst': fst,
      'label': label,
      'confidence': confidence,
      'notes': notes,
      'imageBase64': imageBase64,
      'timestamp': timestamp,
      'xaiExplanation': xaiExplanation,
      'asymmetryLabel': asymmetryLabel,
      'borderLabel': borderLabel,
      'colourLabel': colourLabel,
      'gradcamBase64': gradcamBase64,
    };
  }

  factory ScanRecord.fromJson(Map<String, dynamic> json) {
    return ScanRecord(
      id: json['id'] as String,
      patientName: json['patientName'] as String,
      age: json['age'] as int,
      fst: json['fst'] as String,
      label: json['label'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      notes: json['notes'] as String,
      imageBase64: json['imageBase64'] as String,
      timestamp: json['timestamp'] as String,
      xaiExplanation: (json['xaiExplanation'] ?? 'N/A').toString(),
      asymmetryLabel: (json['asymmetryLabel'] ?? 'N/A').toString(),
      borderLabel: (json['borderLabel'] ?? 'N/A').toString(),
      colourLabel: (json['colourLabel'] ?? 'N/A').toString(),
      gradcamBase64: (json['gradcamBase64'] ?? '').toString(),
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
  final List<ScanRecord> _historyRecords = [];
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('scan_history_records');

    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw) as List<dynamic>;
      _historyRecords
        ..clear()
        ..addAll(
          decoded.map(
            (item) => ScanRecord.fromJson(item as Map<String, dynamic>),
          ),
        );
    }

    setState(() {
      _isLoadingHistory = false;
    });
  }

  Future<void> _persistHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_historyRecords.map((e) => e.toJson()).toList());
    await prefs.setString('scan_history_records', encoded);
  }

  Future<void> _saveRecord(ScanRecord record) async {
    setState(() {
      _historyRecords.insert(0, record);
    });
    await _persistHistory();
  }

  Future<void> _deleteRecord(String id) async {
    setState(() {
      _historyRecords.removeWhere((record) => record.id == id);
    });
    await _persistHistory();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomePage(),
      ScanPage(
        onSaveRecord: _saveRecord,
      ),
      HistoryPage(
        records: _historyRecords,
        isLoading: _isLoadingHistory,
        onDeleteRecord: _deleteRecord,
      ),
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
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
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

class _HomePageState extends State<HomePage>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<ChatMessage> _messages = [
    ChatMessage(
      text:
          'Hello, I’m the App Assistant. I can help with questions about using the app, the Scan page, History, Settings, explainability, and current prototype features.',
      isUser: false,
    ),
  ];

  bool _isSending = false;

  @override
  bool get wantKeepAlive => true;

  Future<String> _sendMessageToBackend(String userMessage) async {
    final uri = Uri.parse('$kBackendBaseUrl/chat/');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'message': userMessage,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['reply'] ?? 'No reply returned.').toString();
    }

    String fallback = 'Sorry, I could not process that request.';
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final detail = data['detail'];
      if (detail != null) {
        fallback = detail.toString();
      }
    } catch (_) {}

    throw Exception(fallback);
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

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isSending = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      final reply = await _sendMessageToBackend(text);

      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(text: reply, isUser: false));
        _isSending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatMessage(
            text:
                'Sorry, the assistant is currently unavailable. Please try again in a moment.',
            isUser: false,
          ),
        );
        _isSending = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chat error: $e')),
      );
    }

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
    super.build(context);
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
                            color:
                                scheme.surfaceContainerHighest.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: ListView.separated(
                            controller: _scrollController,
                            itemCount: _messages.length + (_isSending ? 1 : 0),
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              if (_isSending && index == _messages.length) {
                                return Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    constraints: const BoxConstraints(
                                      maxWidth: 280,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: scheme.surface,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        Text('Thinking...'),
                                      ],
                                    ),
                                  ),
                                );
                              }

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
                                enabled: !_isSending,
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
                                onPressed: _isSending ? null : _sendMessage,
                                child: _isSending
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                        ),
                                      )
                                    : const Icon(Icons.send),
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
  final Future<void> Function(ScanRecord record) onSaveRecord;

  const ScanPage({
    super.key,
    required this.onSaveRecord,
  });

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage>
    with AutomaticKeepAliveClientMixin {
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
  Uint8List? _imageBytes;
  String _status = 'No image selected';
  bool _isAnalysing = false;

  String _resultLabel = 'Awaiting analysis';
  double? _resultConfidenceValue;
  String _resultConfidenceText = '--';
  String _resultMessage = 'Model output will appear here later.';

  String _xaiExplanation = 'No explainability output yet.';
  String _asymmetryLabel = 'N/A';
  String _borderLabel = 'N/A';
  String _colourLabel = 'N/A';
  String _gradcamBase64 = '';

  bool _hasCompletedScan = false;
  bool _hasSavedCurrentScan = false;

  @override
  bool get wantKeepAlive => true;

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
        _resultConfidenceValue = null;
        _resultConfidenceText = '--';
        _resultMessage = 'Model output will appear here later.';
        _xaiExplanation = 'No explainability output yet.';
        _asymmetryLabel = 'N/A';
        _borderLabel = 'N/A';
        _colourLabel = 'N/A';
        _gradcamBase64 = '';
        _hasCompletedScan = false;
        _hasSavedCurrentScan = false;
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

  void _clearArea() {
    setState(() {
      _selectedImage = null;
      _imageBytes = null;
      _status = 'No image selected';
      _resultLabel = 'Awaiting analysis';
      _resultConfidenceValue = null;
      _resultConfidenceText = '--';
      _resultMessage = 'Model output will appear here later.';
      _xaiExplanation = 'No explainability output yet.';
      _asymmetryLabel = 'N/A';
      _borderLabel = 'N/A';
      _colourLabel = 'N/A';
      _gradcamBase64 = '';
      _hasCompletedScan = false;
      _hasSavedCurrentScan = false;
    });
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
      _resultConfidenceValue = null;
      _resultConfidenceText = '--';
      _resultMessage = 'Processing image.';
      _xaiExplanation = 'Generating explainability output...';
      _asymmetryLabel = 'Analysing...';
      _borderLabel = 'Analysing...';
      _colourLabel = 'Analysing...';
      _gradcamBase64 = '';
      _hasCompletedScan = false;
      _hasSavedCurrentScan = false;
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

        final xaiExplanationMap =
            data['xai_explanation'] as Map<String, dynamic>?;
        final abcFeatures = data['abc_features'] as Map<String, dynamic>?;

        final asymmetry = abcFeatures?['asymmetry'] as Map<String, dynamic>?;
        final border = abcFeatures?['border'] as Map<String, dynamic>?;
        final colour = abcFeatures?['colour'] as Map<String, dynamic>?;

        setState(() {
          _isAnalysing = false;
          _status = 'Analysis complete';
          _resultLabel = (data['label'] ?? 'unknown').toString();
          _resultConfidenceValue = confidenceValue;
          _resultConfidenceText = confidenceValue != null
              ? '${(confidenceValue * 100).toStringAsFixed(1)}%'
              : '--';
          _resultMessage =
              (data['message'] ?? 'No message returned from backend.').toString();

          _xaiExplanation =
              (xaiExplanationMap?['rewritten'] ??
                      xaiExplanationMap?['baseline'] ??
                      'No explainability output returned.')
                  .toString();

          _asymmetryLabel =
              (asymmetry?['label'] ?? 'Not available').toString();
          _borderLabel = (border?['label'] ?? 'Not available').toString();
          _colourLabel = (colour?['label'] ?? 'Not available').toString();
          _gradcamBase64 = (data['gradcam_overlay_base64'] ?? '').toString();

          _hasCompletedScan = true;
          _hasSavedCurrentScan = false;
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
          _resultConfidenceValue = null;
          _resultConfidenceText = '--';
          _resultMessage =
              'Backend returned status code ${response.statusCode}.';
          _xaiExplanation = 'Explainability output unavailable.';
          _asymmetryLabel = 'N/A';
          _borderLabel = 'N/A';
          _colourLabel = 'N/A';
          _gradcamBase64 = '';
          _hasCompletedScan = false;
          _hasSavedCurrentScan = false;
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
        _resultConfidenceValue = null;
        _resultConfidenceText = '--';
        _resultMessage =
            'Could not connect to backend. Check the server is running.';
        _xaiExplanation = 'Explainability output unavailable.';
        _asymmetryLabel = 'N/A';
        _borderLabel = 'N/A';
        _colourLabel = 'N/A';
        _gradcamBase64 = '';
        _hasCompletedScan = false;
        _hasSavedCurrentScan = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _promptSaveScan() async {
    if (_imageBytes == null || !_hasCompletedScan || _hasSavedCurrentScan) {
      return;
    }

    final nameController = TextEditingController();
    final ageController = TextEditingController();
    final notesController = TextEditingController();
    String selectedFst = 'I';

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Save Scan'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Enter patient details to save this scan to History.',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: ageController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Age',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedFst,
                      items: const [
                        DropdownMenuItem(value: 'I', child: Text('FST I')),
                        DropdownMenuItem(value: 'II', child: Text('FST II')),
                        DropdownMenuItem(value: 'III', child: Text('FST III')),
                        DropdownMenuItem(value: 'IV', child: Text('FST IV')),
                        DropdownMenuItem(value: 'V', child: Text('FST V')),
                        DropdownMenuItem(value: 'VI', child: Text('FST VI')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedFst = value;
                          });
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'FST',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final age = int.tryParse(ageController.text.trim());

                    if (name.isEmpty || age == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid name and age'),
                        ),
                      );
                      return;
                    }

                    final record = ScanRecord(
                      id: DateTime.now().microsecondsSinceEpoch.toString(),
                      patientName: name,
                      age: age,
                      fst: selectedFst,
                      label: _resultLabel,
                      confidence: _resultConfidenceValue ?? 0,
                      notes: notesController.text.trim().isEmpty
                          ? 'N/A'
                          : notesController.text.trim(),
                      imageBase64: base64Encode(_imageBytes!),
                      timestamp: DateTime.now().toIso8601String(),
                      xaiExplanation: _xaiExplanation,
                      asymmetryLabel: _asymmetryLabel,
                      borderLabel: _borderLabel,
                      colourLabel: _colourLabel,
                      gradcamBase64: _gradcamBase64,
                    );

                    await widget.onSaveRecord(record);

                    if (!mounted) return;
                    setState(() {
                      _hasSavedCurrentScan = true;
                    });

                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldSave == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scan saved to History')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Camera'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _imageBytes == null ? null : _clearArea,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Clear'),
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
          const SizedBox(height: 16),
          if (_isAnalysing)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Loading Status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 12),
                    LinearProgressIndicator(),
                    SizedBox(height: 12),
                    Text(
                      'The selected image is being uploaded and processed by the backend model.',
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 4),
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
                  Text('Confidence: $_resultConfidenceText'),
                  const SizedBox(height: 6),
                  Text('Notes: $_resultMessage'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_hasCompletedScan)
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
                      'Explainability Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text('Asymmetry: $_asymmetryLabel'),
                    const SizedBox(height: 6),
                    Text('Border: $_borderLabel'),
                    const SizedBox(height: 6),
                    Text('Colour: $_colourLabel'),
                    const SizedBox(height: 14),
                    Text(_xaiExplanation),
                    if (_gradcamBase64.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      const Text(
                        'Areas of Concern (Grad-CAM)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Highlighted regions indicate image areas that contributed more strongly to the model output.',
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.memory(
                          base64Decode(_gradcamBase64),
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (_hasCompletedScan && !_hasSavedCurrentScan)
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _promptSaveScan,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Do you want to save this?'),
              ),
            ),
          if (_hasCompletedScan && _hasSavedCurrentScan)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This scan has been saved to History.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
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
  final List<ScanRecord> records;
  final bool isLoading;
  final Future<void> Function(String id) onDeleteRecord;

  const HistoryPage({
    super.key,
    required this.records,
    required this.isLoading,
    required this.onDeleteRecord,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : records.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No saved scans yet. Save a completed scan from the Scan page to view it here.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: records.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = records[index];
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
                        title: Text(item.patientName),
                        subtitle: Text(
                          '${_formatDisplayDate(item.timestamp)} • ${item.label} • ${(item.confidence * 100).toStringAsFixed(1)}%',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => HistoryDetailPage(
                                record: item,
                                onDeleteRecord: onDeleteRecord,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}

class HistoryDetailPage extends StatelessWidget {
  final ScanRecord record;
  final Future<void> Function(String id) onDeleteRecord;

  const HistoryDetailPage({
    super.key,
    required this.record,
    required this.onDeleteRecord,
  });

  @override
  Widget build(BuildContext context) {
    final imageBytes = base64Decode(record.imageBase64);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Scan'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.memory(
              imageBytes,
              height: 240,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 16),
          InfoCard(title: 'Name', content: record.patientName),
          InfoCard(title: 'Age', content: '${record.age}'),
          InfoCard(title: 'FST', content: record.fst),
          InfoCard(title: 'Date', content: _formatDisplayDate(record.timestamp)),
          InfoCard(title: 'Classification', content: record.label),
          InfoCard(
            title: 'Confidence',
            content: '${(record.confidence * 100).toStringAsFixed(1)}%',
          ),
          InfoCard(title: 'Notes', content: record.notes),
          InfoCard(title: 'Asymmetry', content: record.asymmetryLabel),
          InfoCard(title: 'Border', content: record.borderLabel),
          InfoCard(title: 'Colour', content: record.colourLabel),
          InfoCard(title: 'Explainability Summary', content: record.xaiExplanation),
          if (record.gradcamBase64.isNotEmpty)
            Card(
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
                    const Text(
                      'Areas of Concern (Grad-CAM)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Highlighted regions indicate image areas that contributed more strongly to the model output.',
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.memory(
                        base64Decode(record.gradcamBase64),
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () async {
              await onDeleteRecord(record.id);
              if (!context.mounted) return;
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Saved scan deleted')),
              );
            },
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete Saved Scan'),
          ),
        ],
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
            icon: Icons.menu_book_outlined,
            title: 'How to Use',
            subtitle: 'Usage guidance with and without a dermatoscope',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const HowToUsePage(),
                ),
              );
            },
          ),
          SettingsTile(
            icon: Icons.info_outline,
            title: 'About',
            subtitle: 'Credits, version, certifications, and app details',
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
  final bool Function(String) onUnlock;

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

    final success = widget.onUnlock(pin);

    setState(() {
      _errorText = success ? '' : 'Incorrect PIN';
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

class HowToUsePage extends StatelessWidget {
  const HowToUsePage({super.key});

  Widget _buildGuideImage(String path) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.asset(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return Container(
            height: 220,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: Text(
              'Image not found:\n$path',
              textAlign: TextAlign.center,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('How to Use'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Image Guidance',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          const InfoCard(
            title: '',
            content:
                'Use a clear and well-lit image where the lesion is visible and in focus. Avoid motion blur, strong shadows, and heavy obstruction where possible.',
          ),
          const SizedBox(height: 18),
          Text(
            'Without a Dermatoscope',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          const InfoCard(
            title: '',
            content:
                'Open the Scan page, upload an image from the gallery or capture one using the camera, then press Analyse Image to send it to the backend for processing.',
          ),
          const SizedBox(height: 18),
          Text(
            'With a Dermatoscope',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          const InfoCard(
            title: '',
            content:
                'Attach the clamp to the main camera, secure it, attach the magnetic ring, extend the dermatoscope spacer to the 0 mark, and magnetically snap the dermatoscope into place before capturing the image. Consult the images below for a visual guide.',
          ),
          const SizedBox(height: 16),
          _buildGuideImage('assets/how_to_use/equipment.png'),
          const SizedBox(height: 16),
          _buildGuideImage('assets/how_to_use/step1.png'),
          const SizedBox(height: 12),
          _buildGuideImage('assets/how_to_use/step2.png'),
          const SizedBox(height: 12),
          _buildGuideImage('assets/how_to_use/step3.png'),
        ],
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
            title: 'Certification Status',
            content: 'The app is UKCA and CE marked.',
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
    final hasTitle = title.trim().isNotEmpty;

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
            if (hasTitle) ...[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
            ],
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

String _formatDisplayDate(String isoString) {
  final dt = DateTime.tryParse(isoString);
  if (dt == null) return isoString;

  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  final day = dt.day.toString().padLeft(2, '0');
  final month = months[dt.month - 1];
  final year = dt.year;
  final hour = dt.hour.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');

  return '$day $month $year, $hour:$minute';
}
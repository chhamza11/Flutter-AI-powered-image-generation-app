import 'package:flutter/material.dart';
import '../theme/colors.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/typing_indicator.dart';
import 'widgets/avatars.dart';
import '../models/message.dart';
import '../services/gemini_service.dart';
import 'dart:typed_data';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../utils/style_prompts.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // Aspect ratios and styles
  final List<Map<String, dynamic>> aspectRatios = [
    {'label': '1:1', 'value': '1:1', 'icon': Icons.crop_square},
    {'label': '9:16', 'value': '9:16', 'icon': Icons.stay_current_portrait},
    {'label': '16:9', 'value': '16:9', 'icon': Icons.stay_current_landscape},
    {'label': '3:4', 'value': '3:4', 'icon': Icons.crop_3_2},
  ];

  final List<Map<String, dynamic>> imageStyles = stylePrompts;

  String _selectedAspectRatio = '1:1';
  int _selectedAspectIndex = 0;
  int _selectedStyleIndex = 0;

  final List<Message> _messages = [
    Message(
      text: 'Hi! How can I help you today?',
      sender: Sender.ai,
      timestamp: DateTime.now(),
    ),
  ];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  bool _showImageViewer = false;
  Uint8List? _imageToView;
  final FocusNode _inputFocusNode = FocusNode();
  bool _showSelectors = false;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
    _inputFocusNode.addListener(() {
      setState(() {
        _showSelectors = _inputFocusNode.hasFocus;
      });
    });
  }

  Future<void> _loadChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('chat_history');
    if (data != null) {
      final List<dynamic> jsonList = jsonDecode(data);
      setState(() {
        _messages.clear();
        _messages.addAll(jsonList.map((e) => Message(
          text: e['text'],
          base64Image: e['base64Image'],
          sender: e['sender'] == 'user' ? Sender.user : Sender.ai,
          timestamp: DateTime.tryParse(e['timestamp'] ?? '') ?? DateTime.now(),
          isError: e['isError'] ?? false,
          aspectRatio: e['aspectRatio'],
          styleIndex: e['styleIndex'],
        )));
      });
    }
  }

  Future<void> _saveChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _messages.map((m) => {
      'text': m.text,
      'base64Image': m.base64Image,
      'sender': m.sender == Sender.user ? 'user' : 'ai',
      'timestamp': m.timestamp.toIso8601String(),
      'isError': m.isError,
      'aspectRatio': m.aspectRatio,
      'styleIndex': m.styleIndex,
    }).toList();
    await prefs.setString('chat_history', jsonEncode(jsonList));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final prompt = _controller.text.trim();
    if (prompt.isEmpty || _isSending) return;
    final stylePrompt = imageStyles[_selectedStyleIndex]['prompt'] as String;
    final fullPrompt = stylePrompt.isNotEmpty ? '$prompt $stylePrompt' : prompt;
    final aspectRatio = _currentAspectRatio;
    final styleIndex = _selectedStyleIndex;
    setState(() {
      _messages.add(Message(
        text: prompt,
        sender: Sender.user,
        timestamp: DateTime.now(),
        aspectRatio: aspectRatio,
        styleIndex: styleIndex,
      ));
      _isSending = true;
      _controller.clear();
      _showSelectors = false;
    });
    _saveChatHistory();
    _scrollToBottom();
    setState(() {});
    // Show typing indicator
    await Future.delayed(const Duration(milliseconds: 400));
    setState(() {});
    final (String? aiText, String? base64Image) = await GeminiService.generateContent(fullPrompt);
    if (!mounted) return;
    if (aiText != null && aiText.startsWith('Error:')) {
      _messages.add(Message(
        text: aiText,
        sender: Sender.ai,
        timestamp: DateTime.now(),
        isError: true,
        aspectRatio: aspectRatio,
        styleIndex: styleIndex,
      ));
    } else {
      _messages.add(Message(
        text: aiText,
        base64Image: base64Image,
        sender: Sender.ai,
        timestamp: DateTime.now(),
        aspectRatio: aspectRatio,
        styleIndex: styleIndex,
      ));
    }
    setState(() {
      _isSending = false;
    });
    _saveChatHistory();
    _scrollToBottom();
  }

  void _openImageViewer(Uint8List imageBytes) {
    setState(() {
      _showImageViewer = true;
      _imageToView = imageBytes;
    });
  }

  void _closeImageViewer() {
    setState(() {
      _showImageViewer = false;
      _imageToView = null;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Helper to convert string aspect ratio to double
  double get _currentAspectRatio {
    switch (_selectedAspectRatio) {
      case '1:1':
        return 1.0;
      case '9:16':
        return 9 / 16;
      case '16:9':
        return 16 / 9;
      case '3:4':
        return 3 / 4;
      default:
        return 1.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            elevation: 0,
            title: const Text('AI Assistant', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          body: Column(
            children: [
              // Chat list
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: _messages.length,
                  itemBuilder: (context, idx) {
                    final msg = _messages[idx];
                    final isUser = msg.sender == Sender.user;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                        children: [
                          Flexible(
                            child: ChatBubble(
                              text: msg.text,
                              isUser: isUser,
                              time: _formatTime(msg.timestamp),
                              base64Image: msg.base64Image,
                              isError: msg.isError,
                              onImageTap: (bytes) => _openImageViewer(bytes),
                              aspectRatio: msg.aspectRatio ?? 1.0,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (_isSending)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(
                    child: TypingIndicator(),
                  ),
                ),
              // Selectors above input bar, only when focused
              if (_showSelectors)
                Column(
                  children: [
                    // Aspect Ratio Selector
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(aspectRatios.length, (i) {
                          final ar = aspectRatios[i];
                          final selected = i == _selectedAspectIndex;
                          return GestureDetector(
                            onTap: () => setState(() {
                              _selectedAspectIndex = i;
                              _selectedAspectRatio = ar['value'];
                            }),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                border: Border.all(color: selected ? AppColors.primary : AppColors.card, width: 2),
                                borderRadius: BorderRadius.circular(12),
                                color: selected ? AppColors.card : Colors.transparent,
                              ),
                              child: Column(
                                children: [
                                  Icon(ar['icon'], color: selected ? AppColors.primary : Colors.white38, size: 28),
                                  const SizedBox(height: 2),
                                  Text(ar['label'], style: TextStyle(color: selected ? AppColors.primary : Colors.white54, fontSize: 12)),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    // Style Selector (simple UI)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: SizedBox(
                        height: 48,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: imageStyles.length,
                          itemBuilder: (context, i) {
                            final style = imageStyles[i];
                            final selected = i == _selectedStyleIndex;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedStyleIndex = i),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: selected ? AppColors.primary.withOpacity(0.15) : AppColors.card,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: selected ? AppColors.primary : AppColors.card, width: 2),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.style, color: selected ? AppColors.primary : Colors.white38, size: 20),
                                    const SizedBox(width: 4),
                                    Text(style['label'], style: TextStyle(color: selected ? AppColors.primary : Colors.white70, fontSize: 12)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              // Input bar
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 12, top: 10, bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        focusNode: _inputFocusNode,
                        controller: _controller,
                        enabled: !_isSending,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Type your prompt...',
                          hintStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: AppColors.card,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                        onTap: () => setState(() => _showSelectors = true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: !_isSending ? _sendMessage : null,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.secondary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Icon(Icons.send, color: !_isSending ? Colors.white : Colors.white38),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_isSending)
          Container(
            color: Colors.black.withOpacity(0.05),
          ),
        if (_showImageViewer && _imageToView != null)
          GestureDetector(
            onTap: _closeImageViewer,
            child: Stack(
              children: [
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    color: Colors.black.withOpacity(0.25),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
                    child: Material(
                      color: Colors.transparent,
                      child: Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.card.withOpacity(0.98),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.18),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: InteractiveViewer(
                                minScale: 0.5,
                                maxScale: 4.0,
                                child: Image.memory(_imageToView!),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white, size: 28),
                              onPressed: _closeImageViewer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min $ampm';
  }
} 
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'gemini_service.dart';

class AssistiveTouchScreen extends StatefulWidget {
  final String imagePath;
  final GeminiService geminiService;
  final VoidCallback? onDismiss;
  final Function(String)? onTaskProceed;

  const AssistiveTouchScreen({
    super.key,
    required this.imagePath,
    required this.geminiService,
    this.onDismiss,
    this.onTaskProceed,
  });

  @override
  State<AssistiveTouchScreen> createState() => _AssistiveTouchScreenState();
}

class _AssistiveTouchScreenState extends State<AssistiveTouchScreen> {
  final TextEditingController _queryController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  ChatSession? _chatSession;
  
  // List of maps: {'role': 'user' | 'ai', 'text': 'message...'}
  final List<Map<String, String>> _messages = [];
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  Future<void> _analyze() async {
    setState(() {
      _isAnalyzing = true;
      _messages.add({'role': 'ai', 'text': 'Analyzing your screen...'});
    });
    final suggestions = await widget.geminiService.analyzeScreenshot(widget.imagePath);
    if (mounted) {
      final chat = await widget.geminiService.startChatSession(widget.imagePath, suggestions);
      setState(() {
        _chatSession = chat;
        final suggestionText = 'AI Context Suggestions:\n\n$suggestions';
        _messages.last['text'] = suggestionText;
        _isAnalyzing = false;
      });
    }
  }

  Future<void> _onPromptSubmitted() async {
    final query = _queryController.text.trim();
    if (query.isEmpty || _isAnalyzing) return;

    _queryController.clear();
    setState(() {
      _messages.add({'role': 'user', 'text': query});
      _messages.add({'role': 'ai', 'text': 'Thinking...'});
      _isAnalyzing = true;
    });

    _scrollToBottom();

    _scrollToBottom();

    _scrollToBottom();
    
    if (_chatSession != null) {
      try {
        final response = await _chatSession!.sendMessage(Content.text(query));
        if (mounted) {
          setState(() {
            if (response.functionCalls.isNotEmpty) {
              final call = response.functionCalls.first;
              if (call.name == 'propose_task') {
                _messages.last['text'] = call.args['explanation'] as String;
                _messages.last['task'] = call.args['task'] as String;
              } else {
                _messages.last['text'] = 'Function call: ${call.name}';
              }
            } else {
              _messages.last['text'] = response.text ?? 'No response received.';
            }
            _isAnalyzing = false;
          });
          _scrollToBottom();
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _messages.last['text'] = 'Error processing request: $e';
            _isAnalyzing = false;
          });
          _scrollToBottom();
        }
      }
    }
  }

  void _scrollToBottom() {
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

  @override
  void dispose() {
    _queryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(color: Color(0x33000000), blurRadius: 20, offset: Offset(0, 5))
          ],
        ),
        child: Column(
          children: [
            // Close header
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 16),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.black54, size: 28),
                  onPressed: () {
                    if (widget.onDismiss != null) {
                      widget.onDismiss!();
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ),
            ),
            // Screenshot Preview
            Expanded(
              flex: 3,
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 4))
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    File(widget.imagePath),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),

            // Chat Area
            Expanded(
              flex: 5,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
                  boxShadow: [
                    BoxShadow(color: Color(0x1F000000), blurRadius: 20, offset: Offset(0, -5))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ListView.separated(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _messages.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isUser = msg['role'] == 'user';
                          return Align(
                            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isUser ? const Color(0xFF4F46E5) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(4),
                                  bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  MarkdownBody(
                                    data: msg['text'] ?? '',
                                    styleSheet: MarkdownStyleSheet(
                                      p: TextStyle(
                                        fontSize: 15,
                                        color: isUser ? Colors.white : const Color(0xFF334155),
                                        height: 1.4,
                                      ),
                                      strong: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isUser ? Colors.white : const Color(0xFF1E293B),
                                      ),
                                      listBullet: TextStyle(
                                        color: isUser ? Colors.white : const Color(0xFF334155),
                                      ),
                                    ),
                                  ),
                                  if (msg.containsKey('task') && msg['task'] != null) ...[
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ShadButton(
                                        child: const Text('Yes, proceed'),
                                        onPressed: () {
                                          if (widget.onTaskProceed != null) {
                                            widget.onTaskProceed!(msg['task']!);
                                          } else {
                                            Navigator.of(context).pop(msg['task']);
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ShadInput(
                            controller: _queryController,
                            placeholder: const Text('Ask about the screen...'),
                            onSubmitted: (_) => _onPromptSubmitted(),
                            enabled: !_isAnalyzing,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ShadButton(
                          onPressed: _isAnalyzing ? null : _onPromptSubmitted,
                          child: _isAnalyzing 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(LucideIcons.sendHorizontal, size: 20),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import '../utils/message_dialog.dart';

class LiveChatScreen extends StatefulWidget {
  const LiveChatScreen({super.key});

  @override
  State<LiveChatScreen> createState() => _LiveChatScreenState();
}

class _LiveChatScreenState extends State<LiveChatScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  String? _deviceId;
  Stream<Map<String, dynamic>?>? _chatStream;
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    try {
      final deviceId = await _firebaseService.getDeviceId();
      setState(() {
        _deviceId = deviceId;
        _chatStream = _firebaseService.getLiveChatStream(deviceId);
        _isLoading = false;
      });
      
      // Scroll to bottom when new messages arrive
      _chatStream?.listen((chat) {
        if (chat != null && mounted) {
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
      });
    } catch (e) {
      debugPrint('Error initializing chat: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _deviceId == null) {
      return;
    }

    final message = _messageController.text.trim();
    _messageController.clear();

    setState(() {
      _isSending = true;
    });

    try {
      final result = await _firebaseService.sendLiveChatMessage(
        deviceId: _deviceId!,
        message: message,
      );

      if (!result['success']) {
        if (mounted) {
          final errorMsg = result['error'] ?? 'Failed to send message. Please try again.';
          showMessageDialog(
            context,
            message: errorMsg,
            type: MessageType.error,
            title: 'Error',
          );
        }
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
      if (mounted) {
        showMessageDialog(
          context,
          message: 'Failed to send message. Please check your connection.',
          type: MessageType.error,
          title: 'Error',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50;
    final messageBgColor = isDark ? Colors.deepPurple.shade800 : Colors.deepPurple.shade100;
    final adminBgColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;

    return Scaffold(
      resizeToAvoidBottomInset: true, // Prevent keyboard overlay
      appBar: AppBar(
        title: const Text('Live Chat Support'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Device ID Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: cardColor,
                  child: Row(
                    children: [
                      Icon(Icons.phone_android, color: Colors.deepPurple),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your Account ID',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              _deviceId ?? 'Loading...',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Messages List
                Expanded(
                  child: StreamBuilder<Map<String, dynamic>?>(
                    stream: _chatStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data == null) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 64,
                                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No messages yet',
                                style: TextStyle(
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Start a conversation with our support team',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final chat = snapshot.data!;
                      final messages = (chat['messages'] as List<dynamic>?) ?? [];

                      if (messages.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 64,
                                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No messages yet',
                                style: TextStyle(
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index] as Map<String, dynamic>;
                          final isUser = msg['sender'] == 'user';
                          final messageText = msg['message'] as String? ?? '';
                          
                          // Handle timestamp - can be Timestamp, Map, or null
                          Timestamp? timestamp;
                          try {
                            final ts = msg['timestamp'];
                            if (ts is Timestamp) {
                              timestamp = ts;
                            } else if (ts is Map) {
                              // Convert Map to Timestamp if needed
                              final seconds = ts['_seconds'] as int?;
                              final nanoseconds = ts['_nanoseconds'] as int? ?? 0;
                              if (seconds != null) {
                                timestamp = Timestamp(seconds, nanoseconds);
                              }
                            } else if (ts != null) {
                              // Try to parse as DateTime string
                              debugPrint('⚠️ Unexpected timestamp type: ${ts.runtimeType}');
                            }
                          } catch (e) {
                            debugPrint('❌ Error parsing timestamp: $e');
                            timestamp = null;
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              mainAxisAlignment:
                                  isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                              children: [
                                if (!isUser) ...[
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Colors.deepPurple,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.support_agent,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isUser ? messageBgColor : adminBgColor,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          messageText,
                                          style: TextStyle(
                                            color: isUser
                                                ? Colors.white
                                                : textColor,
                                          ),
                                        ),
                                        if (timestamp != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            _formatTimestamp(timestamp),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: isUser
                                                  ? Colors.white70
                                                  : (isDark
                                                      ? Colors.grey.shade400
                                                      : Colors.grey.shade600),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                                if (isUser) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Colors.deepPurple.shade300,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.person,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                // Input Field - Wrapped in SafeArea to prevent keyboard overlay
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          style: TextStyle(color: textColor),
                          maxLength: 500, // Limit to 500 characters
                          maxLines: 4, // Limit to 4 lines
                          decoration: InputDecoration(
                            hintText: 'Type your message...',
                            hintStyle: TextStyle(
                              color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                            ),
                            filled: true,
                            fillColor: isDark ? Colors.grey.shade800 : Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            counterText: '', // Hide character counter
                          ),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.deepPurple,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: _isSending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.send, color: Colors.white),
                          onPressed: _isSending ? null : _sendMessage,
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

  String _formatTimestamp(dynamic timestamp) {
    try {
      if (timestamp == null) return 'Sending...';
      
      DateTime date;
      
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is Map) {
        // Handle Firestore Map structure
        final seconds = timestamp['_seconds'];
        if (seconds != null) {
          date = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
        } else {
          return 'Just now';
        }
      } else {
        return '';
      }
      
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return '';
    }
  }
}


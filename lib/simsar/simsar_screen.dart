import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'simsar_service.dart';
import 'simsar_models.dart';

class SimsarScreen extends StatefulWidget {
  const SimsarScreen({super.key});

  @override
  State<SimsarScreen> createState() => _SimsarScreenState();
}

class _SimsarScreenState extends State<SimsarScreen> {
  final SimsarService _service = SimsarService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  
  bool _isLoading = false;
  bool _isListening = false;
  bool _showHistory = false;
  String _currentResponse = '';

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _loadData();
  }

  Future<void> _initSpeech() async {
    await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
      onError: (error) {
        setState(() => _isListening = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في التعرف على الصوت: ${error.errorMsg}')),
        );
      },
    );
  }

  Future<void> _loadData() async {
    await _service.loadConversations();
    if (_service.conversations.isEmpty) {
      _service.newConversation();
    } else {
      _service.selectConversation(_service.conversations.first);
    }
    setState(() {});
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

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    _controller.clear();
    setState(() {
      _isLoading = true;
      _currentResponse = '';
    });

    _scrollToBottom();

    await for (final chunk in _service.sendMessage(text)) {
      setState(() {
        _currentResponse += chunk;
      });
      _scrollToBottom();
    }

    setState(() {
      _isLoading = false;
      _currentResponse = '';
    });
  }

  Future<void> _regenerate() async {
    final lastContent = _service.getLastUserMessageContent();
    if (lastContent == null) return;

    await _service.regenerateLastMessage();
    setState(() {
      _isLoading = true;
      _currentResponse = '';
    });

    _scrollToBottom();

    await for (final chunk in _service.sendMessage(lastContent)) {
      setState(() {
        _currentResponse += chunk;
      });
      _scrollToBottom();
    }

    setState(() {
      _isLoading = false;
      _currentResponse = '';
    });
  }

  void _startListening() async {
    if (!_speech.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('التعرف على الصوت غير متاح')),
      );
      return;
    }

    setState(() => _isListening = true);
    
    await _speech.listen(
      onResult: (result) {
        setState(() {
          _controller.text = result.recognizedWords;
        });
      },
      localeId: 'ar-SA',
      listenMode: stt.ListenMode.dictation,
    );
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  void _newChat() {
    _service.newConversation();
    setState(() {
      _showHistory = false;
    });
  }

  void _selectConversation(SimsarConversation conversation) {
    _service.selectConversation(conversation);
    setState(() {
      _showHistory = false;
    });
  }

  void _deleteConversation(SimsarConversation conversation) async {
    await _service.deleteConversation(conversation);
    if (_service.conversations.isEmpty) {
      _service.newConversation();
    }
    setState(() {});
  }

  void _copyMessage(String content) {
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم النسخ'), duration: Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1220),
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Text('س', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('سمسار', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text(
                  'مساعدك الذكي للعقارات',
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_showHistory ? Icons.close : Icons.history, color: Colors.white),
            onPressed: () => setState(() => _showHistory = !_showHistory),
            tooltip: 'السجل',
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _newChat,
            tooltip: 'محادثة جديدة',
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 600;
          final sidebarWidth = isWide ? 300.0 : constraints.maxWidth * 0.85;
          
          return Stack(
            children: [
              // Main Chat Area
              Column(
                children: [
                  // Model indicator
                  if (_isLoading || _service.currentConversation?.messages.isNotEmpty == true)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: const Color(0xFF111827),
                      child: Row(
                        children: [
                          Icon(Icons.smart_toy, size: 16, color: Colors.white.withOpacity(0.6)),
                          const SizedBox(width: 8),
                          Text(
                            'النموذج: ${_service.currentModelName}',
                            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                          ),
                          const Spacer(),
                          InkWell(
                            onTap: () async {
                              await _service.refreshPropertyData();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('تم تحديث البيانات'), duration: Duration(seconds: 1)),
                                );
                              }
                            },
                            child: Row(
                              children: [
                                Icon(Icons.refresh, size: 14, color: Colors.white.withOpacity(0.6)),
                                const SizedBox(width: 4),
                                Text(
                                  'تحديث البيانات',
                                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Messages
                  Expanded(
                    child: _service.currentConversation == null || 
                           (_service.currentConversation!.messages.isEmpty && !_isLoading)
                        ? _buildEmptyState()
                        : _buildMessagesList(),
                  ),
                  
                  // Input Area
                  _buildInputArea(),
                ],
              ),
              
              // History Drawer Overlay
              if (_showHistory) ...[
                // Semi-transparent backdrop
                GestureDetector(
                  onTap: () => setState(() => _showHistory = false),
                  child: Container(
                    color: Colors.black.withOpacity(0.5),
                  ),
                ),
                // Sidebar
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: sidebarWidth,
                  child: Material(
                    color: const Color(0xFF111827),
                    elevation: 8,
                    child: SafeArea(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
                            ),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'سجل المحادثات',
                                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white),
                                  onPressed: () => setState(() => _showHistory = false),
                                ),
                              ],
                            ),
                          ),
                          // Conversations List
                          Expanded(
                            child: _service.conversations.isEmpty
                                ? Center(
                                    child: Text(
                                      'لا توجد محادثات',
                                      style: TextStyle(color: Colors.white.withOpacity(0.5)),
                                    ),
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    itemCount: _service.conversations.length,
                                    separatorBuilder: (_, __) => Divider(
                                      color: Colors.white.withOpacity(0.05),
                                      height: 1,
                                    ),
                                    itemBuilder: (context, index) {
                                      final conv = _service.conversations[index];
                                      final isSelected = conv.id == _service.currentConversation?.id;
                                      return InkWell(
                                        onTap: () => _selectConversation(conv),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          color: isSelected ? Colors.white.withOpacity(0.1) : null,
                                          child: Row(
                                            children: [
                                              // Conversation Icon
                                              Container(
                                                width: 40,
                                                height: 40,
                                                decoration: BoxDecoration(
                                                  color: isSelected 
                                                      ? const Color(0xFFF59E0B).withOpacity(0.2)
                                                      : Colors.white.withOpacity(0.05),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Icon(
                                                  Icons.chat_bubble_outline,
                                                  size: 20,
                                                  color: isSelected 
                                                      ? const Color(0xFFF59E0B)
                                                      : Colors.white.withOpacity(0.5),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              // Title and info
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      conv.title,
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                        fontSize: 14,
                                                      ),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      '${conv.messages.length} رسائل',
                                                      style: TextStyle(
                                                        color: Colors.white.withOpacity(0.5),
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              // Delete button
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline, size: 20),
                                                color: Colors.red.withOpacity(0.7),
                                                onPressed: () => _deleteConversation(conv),
                                                tooltip: 'حذف',
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          // New Chat Button
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
                            ),
                            child: ElevatedButton.icon(
                              onPressed: _newChat,
                              icon: const Icon(Icons.add),
                              label: const Text('محادثة جديدة'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF59E0B),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFFF59E0B).withOpacity(0.3), const Color(0xFFEA580C).withOpacity(0.3)],
              ),
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Center(
              child: Text('س', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 36)),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'مرحباً! أنا سمسار',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'مساعدك الذكي لإدارة العقارات',
            style: TextStyle(color: Colors.white.withOpacity(0.6)),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _buildSuggestionChip('كم عدد الوحدات؟'),
                _buildSuggestionChip('ما هي الحجوزات القادمة؟'),
                _buildSuggestionChip('أعطني ملخص الإيرادات'),
                _buildSuggestionChip('ما هي الوحدات المتاحة اليوم؟'),
                _buildSuggestionChip('كم عدد الحجوزات هذا الشهر؟'),
                _buildSuggestionChip('ما هو إجمالي الإيرادات؟'),
                _buildSuggestionChip('أسعار الوحدات'),
                _buildSuggestionChip('الحجوزات الحالية الآن'),
                _buildSuggestionChip('تقرير مالي مختصر'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return ActionChip(
      label: Text(text, style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 12, fontWeight: FontWeight.w500)),
      backgroundColor: const Color(0xFF1A2540),
      side: const BorderSide(color: Color(0xFFF59E0B), width: 1),
      onPressed: () {
        _controller.text = text;
        _sendMessage();
      },
    );
  }

  Widget _buildMessagesList() {
    final messages = _service.currentConversation?.messages ?? [];
    
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length + (_isLoading && _currentResponse.isNotEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messages.length && _isLoading) {
          return _buildMessageBubble(
            SimsarMessage(content: _currentResponse, isUser: false),
            isStreaming: true,
          );
        }
        return _buildMessageBubble(messages[index]);
      },
    );
  }

  Widget _buildMessageBubble(SimsarMessage message, {bool isStreaming = false}) {
    final isUser = message.isUser;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Text('س', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
            const SizedBox(width: 8),
          ],
          
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUser ? const Color(0xFF1E3A5F) : const Color(0xFF1E1E2E),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                  ),
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Copy button
                      if (!isUser && message.content.isNotEmpty)
                        Align(
                          alignment: Alignment.centerRight,
                          child: InkWell(
                            onTap: () => _copyMessage(message.content),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Icon(Icons.copy, size: 16, color: Colors.white.withOpacity(0.5)),
                            ),
                          ),
                        ),
                      SelectableText(
                        message.content.isEmpty && isStreaming ? '...' : message.content,
                        style: const TextStyle(color: Colors.white, height: 1.5),
                      ),
                      if (isStreaming)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Regenerate button for last AI message
                if (!isUser && !isStreaming && message == _service.currentConversation?.messages.last)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: TextButton.icon(
                      onPressed: _isLoading ? null : _regenerate,
                      icon: const Icon(Icons.refresh, size: 14),
                      label: const Text('إعادة التوليد', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white.withOpacity(0.6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 18),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Voice Input Button
            IconButton(
              onPressed: _isListening ? _stopListening : _startListening,
              icon: Icon(
                _isListening ? Icons.stop : Icons.mic,
                color: _isListening ? Colors.red : const Color(0xFF4CAF50),
              ),
              tooltip: _isListening ? 'إيقاف' : 'تسجيل صوتي',
            ),
            
            // Text Input
            Expanded(
              child: TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white),
                maxLines: 4,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: 'اكتب سؤالك هنا...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            
            const SizedBox(width: 8),
            
            // Send Button
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: IconButton(
                onPressed: _isLoading ? null : _sendMessage,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _speech.stop();
    super.dispose();
  }
}

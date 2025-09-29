// lib/src/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // <-- للـ Shortcuts/Actions
import 'models/chat_message.dart';
import 'services/gpt_client.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/typing_indicator.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messages = <ChatMessage>[];
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _client = GptClient();
  final _inputFocus = FocusNode(); // <-- للفوكس على حقل الإدخال
  bool _thinking = false;

  String get _welcome =>
      "أهلاً بك في مصر. كيف يمكنني مساعدتك في التخطيط لرحلة أحلامك إلى مصر؟";
  String get _hint => "اكتب رسالتك هنا";
  String get _sendLabel => 'ارسال';

  String _sanitize(String raw) {
    final lines = raw.split('\n');
    final kept = <String>[];
    for (final line in lines) {
      final t = line.trimLeft();
      if (t.startsWith('lang=')) continue;
      if (t.startsWith('User:')) continue;
      kept.add(line);
    }
    final s = kept.join('\n').trim();
    return s.isEmpty ? raw.trim() : s;
  }

  @override
  void initState() {
    super.initState();
    _messages.add(ChatMessage(text: _welcome, sender: Sender.bot));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _send(String raw) async {
    final text = raw.trim().isEmpty ? _ctrl.text.trim() : raw.trim();
    if (text.isEmpty) return;
    _ctrl.clear();

    setState(() {
      _messages.add(ChatMessage(text: text, sender: Sender.user));
      _thinking = true;
    });
    _scrollToEnd();

    try {
      final ans = await _client.generate(
        prompt: text,
        history: _messages,
      );
      final clean = _sanitize(ans);
      if (!mounted) return;
      setState(() => _messages.add(ChatMessage(text: clean, sender: Sender.bot)));
    } catch (e) {
      setState(() => _messages.add(ChatMessage(text: 'Error: $e', sender: Sender.bot)));
    } finally {
      setState(() => _thinking = false);
      _scrollToEnd();
      _inputFocus.requestFocus(); // <-- رجّع الفوكس بعد الإرسال
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 200,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // إدراج سطر جديد في موضع المؤشر (لـ Shift+Enter)
  void _insertNewline() {
    final v = _ctrl.value;
    final sel = v.selection;
    final start = sel.isValid ? sel.start : v.text.length;
    final end = sel.isValid ? sel.end : v.text.length;
    final newText = v.text.replaceRange(start, end, '\n');
    _ctrl.value = v.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: start + 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFBFA463);

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF111111), Colors.transparent],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      border: Border(
                        bottom: BorderSide(color: Color(0x40BFA463)),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 400,
                          height: 200,
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0x33000000),
                                  offset: Offset(0, 4),
                                  blurRadius: 8)
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Image.asset("assets/logo.png", fit: BoxFit.contain),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "دليلك إلى أسرار مصر",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: gold,
                            fontSize: 25,
                            fontWeight: FontWeight.w500,
                            letterSpacing: .2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Messages
                  Expanded(
                    child: ListView.builder(
                      controller: _scroll,
                      itemCount: _messages.length + (_thinking ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (_thinking && i == _messages.length) {
                          return const Padding(
                            padding: EdgeInsets.all(10.0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: TypingIndicator(),
                            ),
                          );
                        }
                        final m = _messages[i];
                        return ChatBubble(msg: m);
                      },
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Input: Enter=send, Shift+Enter=newline
                  Row(
                    children: [
                      Expanded(
                        child: Shortcuts(
                          shortcuts: <LogicalKeySet, Intent>{
                             LogicalKeySet(LogicalKeyboardKey.enter):
                                const _SubmitIntent(),
                             LogicalKeySet(
                              LogicalKeyboardKey.shift,
                              LogicalKeyboardKey.enter,
                            ): const _InsertNewlineIntent(),
                          },
                          child: Actions(
                            actions: <Type, Action<Intent>>{
                              _SubmitIntent: CallbackAction<_SubmitIntent>(
                                onInvoke: (intent) {
                                  _send('');
                                  return null;
                                },
                              ),
                              _InsertNewlineIntent:
                                  CallbackAction<_InsertNewlineIntent>(
                                onInvoke: (intent) {
                                  _insertNewline();
                                  return null;
                                },
                              ),
                            },
                            child: Focus(
                              autofocus: true,
                              focusNode: _inputFocus,
                              child: TextField(
                                controller: _ctrl,
                                minLines: 1,
                                maxLines: 5,
                                keyboardType: TextInputType.multiline,
                                textInputAction: TextInputAction.send, // زر "إرسال" على الموبايل
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: _hint,
                                  hintStyle:
                                      TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                                  filled: true,
                                  fillColor: const Color(0xFF151515),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                    horizontal: 16,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide:
                                        const BorderSide(color: Color(0x22BFA463)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide:
                                        const BorderSide(color: Color(0x22BFA463)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide:
                                        const BorderSide(color: Color(0x66BFA463)),
                                  ),
                                ),
                                onSubmitted: (_) => _send(''), // IME "Send" (موبايل)
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: gold,
                          foregroundColor: const Color(0xFF1A1A1A),
                          padding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 22),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => _send(''),
                        child: Text(
                          _sendLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: .2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Intents مخصّصة لاختصارات لوحة المفاتيح
class _SubmitIntent extends Intent {
  const _SubmitIntent();
}

class _InsertNewlineIntent extends Intent {
  const _InsertNewlineIntent();
}

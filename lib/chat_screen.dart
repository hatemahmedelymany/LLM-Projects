import 'dart:io';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard
import 'api_service.dart';

// Brand colors
const kBrand = Color.fromARGB(166, 31, 102, 184); // translucent
const kBrandOpaque = Color.fromARGB(255, 31, 102, 184); // solid

class QA {
  final String q;
  final String a;
  QA(this.q, this.a);
}

enum LinkState { disconnected, connecting, connected }

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ngrokCtrl = TextEditingController();
  final _qCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final FocusNode _selectionFocus = FocusNode(); // for SelectableRegion
  ApiService? _api;
  LinkState _state = LinkState.disconnected;
  bool _busy = false;
  bool _hasIndex = false;
  String? _lastPdfName;
  final List<QA> _messages = [];
  final List<String> _events = ['Ready.'];

  @override
  void dispose() {
    _selectionFocus.dispose();
    _ngrokCtrl.dispose();
    _qCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _setEvent(String s) => setState(() => _events.add(s));

  void _connect() async {
    final base = _ngrokCtrl.text.trim();
    if (base.isEmpty) return;
    setState(() {
      _state = LinkState.connecting;
      _api = ApiService(baseUrl: base);
    });
    try {
      final h = await _api!.health();
      setState(() {
        _state = LinkState.connected;
        _hasIndex = (h['has_index'] == true);
      });
      _setEvent('Health: $h');
    } catch (e) {
      setState(() => _state = LinkState.disconnected);
      _setEvent('Health check failed: $e');
    }
  }

  Future<void> _pickAndUploadPdf() async {
    if (_api == null) return;
    setState(() => _busy = true);
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (res == null || res.files.isEmpty) return;
      final path = res.files.single.path;
      final name = res.files.single.name;
      if (path == null) return;
      final file = File(path);
      final data = await _api!.ingestPdf(file);
      setState(() {
        _lastPdfName = name;
        _hasIndex = true;
      });
      _setEvent('PDF ingested ($name): $data');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('PDF "$name" indexed (${data["chunks"]} chunks)')),
      );
    } catch (e) {
      _setEvent('Upload failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _ask() async {
    if (_api == null) return;
    final q = _qCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() => _busy = true);
    try {
      final ans = await _api!.ask(q);
      setState(() {
        _messages.add(QA(q, ans));
        _qCtrl.clear();
      });
      await Future.delayed(const Duration(milliseconds: 50));
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    } catch (e) {
      _setEvent('Ask failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ask failed: $e')),
      );
    } finally {
      setState(() => _busy = false);
    }
  }

  // ------- UI helpers -------
  Widget _buildGradientBackground() {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: const [
              Color(0xFFF6EEE2),
              Color(0xFFFFF9F0),
              Color(0xFFEFE5D5),
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _glass({required Widget child, EdgeInsets? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding ?? const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(.6), width: 1),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(.72),
                Colors.white.withOpacity(.55),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.08),
                blurRadius: 24,
                offset: const Offset(0, 18),
              )
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _statusChip({required bool ok, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: ok ? Colors.green : Colors.red,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: ok ? Colors.green.shade800 : Colors.red.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title, [IconData? icon]) {
    return Row(
      children: [
        if (icon != null) Icon(icon, size: 20, color: kBrandOpaque),
        if (icon != null) const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: kBrandOpaque,
          ),
        ),
      ],
    );
  }

  void _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  Widget _userBubble(String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        padding: const EdgeInsets.all(12),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: kBrand,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(6),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
          boxShadow: [
            BoxShadow(
              color: kBrandOpaque.withOpacity(.18),
              blurRadius: 12,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: SelectableText(
          text,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _assistantBubble(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        padding: const EdgeInsets.all(12),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(color: kBrandOpaque.withOpacity(.12)),
          boxShadow: [
            BoxShadow(
              color: kBrandOpaque.withOpacity(.06),
              blurRadius: 10,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: SelectableText(text)),
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Copy answer',
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () => _copy(text),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: AppBar(
          elevation: 0,
          backgroundColor: const Color.fromARGB(166, 31, 102, 184),
          centerTitle: true,
          title: Column(
            children: [
              Text(
                'PDF Q&A',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: .2,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                'Upload a PDF • Build index • Ask questions',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                    ),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          _buildGradientBackground(),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  children: [
                    // --- Connection Card ---
                    _glass(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _ngrokCtrl,
                                  decoration: const InputDecoration(
                                    labelText:
                                        'Ngrok Base URL (e.g., https://xxxx.ngrok-free.app)',
                                    prefixIcon: Icon(Icons.link),
                                  ),
                                  onSubmitted: (_) => _connect(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              FilledButton.icon(
                                style: ButtonStyle(
                                  backgroundColor: WidgetStateColor.fromMap(
                                    <WidgetStatesConstraint, Color>{
                                      // WidgetState.error: Colors.red,
                                      WidgetState.any: const Color.fromARGB(
                                          166, 31, 102, 184)
                                    },
                                  ),
                                ),
                                onPressed: _state == LinkState.connecting
                                    ? null
                                    : _connect,
                                icon: Icon(_state == LinkState.connected
                                    ? Icons.check_circle
                                    : Icons.link),
                                label: Text(_state == LinkState.connected
                                    ? 'Connected'
                                    : 'Connect'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _statusChip(
                                ok: _state == LinkState.connected,
                                label: _state == LinkState.connected
                                    ? 'API reachable'
                                    : 'Disconnected',
                              ),
                              const SizedBox(width: 16),
                              _statusChip(
                                ok: _hasIndex,
                                label: _hasIndex ? 'Index ready' : 'No index',
                              ),
                              if (_lastPdfName != null) ...[
                                const SizedBox(width: 16),
                                Flexible(
                                  child: Text('PDF: $_lastPdfName',
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // --- Actions Card ---
                    _glass(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.handyman,
                                  size: 20, color: kBrandOpaque),
                              const SizedBox(width: 8),
                              const Text(
                                'Data & Tools',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: kBrandOpaque,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            alignment: WrapAlignment.start,
                            runSpacing: 10,
                            spacing: 12,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: (_busy || _api == null)
                                    ? null
                                    : _pickAndUploadPdf,
                                icon: const Icon(Icons.picture_as_pdf),
                                label: const Text('Upload PDF & Build Index'),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: (_busy || _api == null)
                                    ? null
                                    : () async {
                                        final h = await _api!.health();
                                        setState(() => _hasIndex =
                                            (h['has_index'] == true));
                                        _setEvent('Health: $h');
                                      },
                                icon: const Icon(Icons.monitor_heart),
                                label: const Text('Health'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // --- Chat Card ---
                    Expanded(
                      child: _glass(
                        padding: const EdgeInsets.all(0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding:
                                  const EdgeInsets.fromLTRB(18, 16, 18, 10),
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(20)),
                                color: Colors.white.withOpacity(.85),
                                border: Border(
                                    bottom: BorderSide(
                                        color: Colors.black.withOpacity(.05))),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.chat_bubble_outline,
                                      color: kBrandOpaque),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Conversation',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: kBrandOpaque,
                                    ),
                                  ),
                                  const Spacer(),
                                  Tooltip(
                                    message: 'Debug log',
                                    child: IconButton(
                                      color: const Color.fromARGB(
                                          166, 31, 102, 184),
                                      onPressed: () {
                                        showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          showDragHandle: true,
                                          builder: (ctx) => Container(
                                            padding: const EdgeInsets.all(16),
                                            height: MediaQuery.of(context)
                                                    .size
                                                    .height *
                                                0.6,
                                            child: ListView.separated(
                                              itemCount: _events.length,
                                              separatorBuilder: (_, __) =>
                                                  const Divider(height: 12),
                                              itemBuilder: (_, i) => Text(
                                                _events[i],
                                                style: const TextStyle(
                                                    fontFamily: 'monospace'),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.terminal),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 8, 12, 12),
                                child: SelectableRegion(
                                  focusNode: _selectionFocus,
                                  selectionControls:
                                      materialTextSelectionControls,
                                  child: _messages.isEmpty
                                      ? Center(
                                          child: Text(
                                            'Upload a PDF, then ask a question.\nFor example: "Did the company offer courses?"',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                color: kBrandOpaque),
                                          ),
                                        )
                                      : ListView.builder(
                                          controller: _scrollCtrl,
                                          itemCount: _messages.length,
                                          itemBuilder: (context, i) {
                                            final m = _messages[i];
                                            return Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                _userBubble(m.q),
                                                _assistantBubble(m.a),
                                              ],
                                            );
                                          },
                                        ),
                                ),
                              ),
                            ),
                            // Input bar
                            SafeArea(
                              top: false,
                              child: Container(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 10, 12, 12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(.85),
                                  borderRadius: const BorderRadius.vertical(
                                      bottom: Radius.circular(20)),
                                  border: Border(
                                      top: BorderSide(
                                          color:
                                              Colors.black.withOpacity(.05))),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _qCtrl,
                                        decoration: const InputDecoration(
                                          hintText: 'Ask a question...',
                                          prefixIcon: Icon(Icons.search),
                                        ),
                                        onSubmitted: (_) => _ask(),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    FilledButton.icon(
                                      style: ButtonStyle(
                                        backgroundColor:
                                            WidgetStateColor.fromMap(
                                          <WidgetStatesConstraint, Color>{
                                            // WidgetState.error: Colors.red,
                                            WidgetState.any:
                                                const Color.fromARGB(
                                                    166, 31, 102, 184)
                                          },
                                        ),
                                      ),
                                      onPressed:
                                          (_busy || _api == null) ? null : _ask,
                                      icon: const Icon(Icons.send),
                                      label: const Text('Ask'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_busy)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withOpacity(.06),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

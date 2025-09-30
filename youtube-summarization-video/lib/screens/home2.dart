import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/api_services.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final TextEditingController _urlController = TextEditingController();
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _summarize(BuildContext context) async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please paste a YouTube URL.')),
      );
      return;
    }
    await context.read<ApiService>().summarizeVideo(url);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final api = context.watch<ApiService>();

    return Scaffold(
      body: Stack(
        children: [
          // Soft gradient background + blur circles
          Positioned.fill(
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFEAF2FF), Color(0xFFF7F9FC)],
                ),
              ),
            ),
          ),
          Positioned(top: -120, right: -80,
            child: _BlurCircle(size: 220, color: const Color.fromARGB(255, 72, 113, 165).withOpacity(.5))),
          Positioned(bottom: -100, left: -60,
            child: _BlurCircle(size: 180, color: const Color.fromARGB(255, 40, 65, 87).withOpacity(.55))),

          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      // Header / branding
                      Row(
                        children: [
                          Container(
                            height: 44, width: 44,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                )
                              ],
                            ),
                            child: const Icon(Icons.smart_toy_outlined),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text('YouTube Summarizer',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Hero card: input + button
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text('Turn long videos into quick insights',
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 10),
                              Text(
                                'Paste a YouTube link and get a clean, concise summary.',
                                style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Colors.black54),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _urlController,
                                      textInputAction: TextInputAction.done,
                                      onSubmitted: (_) => _summarize(context),
                                      decoration: const InputDecoration(
                                        hintText: 'https://www.youtube.com/watch?v=…',
                                        labelText: 'YouTube URL',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    height: 56,
                                    child: ElevatedButton.icon(
                                      onPressed: api.isLoading ? null : () => _summarize(context),
                                      icon: const Icon(Icons.summarize_outlined),
                                      label: const Text('Summarize'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.info_outline, size: 18),
                                  const SizedBox(width: 6),
                                  Text('UI-only changes • existing logic preserved',
                                    style: Theme.of(context).textTheme.bodySmall!.copyWith(color: Colors.black54)),
                                ],
                              )
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Results area
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          child: api.isLoading
                              ? _LoadingCard(animation: _pulse)
                              : api.error.isNotEmpty
                                  ? _ErrorCard(
                                      message: api.error,
                                      onClear: context.read<ApiService>().clearResults,
                                    )
                                  : api.summary.isEmpty
                                      ? _EmptyState(onPaste: () async {
                                          final data = await Clipboard.getData('text/plain');
                                          if (data?.text != null) {
                                            setState(() => _urlController.text = data!.text!);
                                          }
                                        })
                                      : _SummaryCard(
                                          text: api.summary,
                                          onCopy: () async {
                                            await Clipboard.setData(ClipboardData(text: api.summary));
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
                                            }
                                          },
                                          onClear: context.read<ApiService>().clearResults,
                                        ),
                        ),
                      ),

                      const SizedBox(height: 8),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Made with Hatem Ahmed',
                            style: Theme.of(context).textTheme.bodySmall!.copyWith(color: Colors.black45),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String text;
  final VoidCallback onCopy;
  final VoidCallback onClear;
  const _SummaryCard({required this.text, required this.onCopy, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('Summary', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.check_circle, size: 18),
                const Spacer(),
                IconButton(tooltip: 'Copy', onPressed: onCopy, icon: const Icon(Icons.copy_outlined)),
                IconButton(tooltip: 'Clear', onPressed: onClear, icon: const Icon(Icons.delete_outline)),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(text, style: const TextStyle(height: 1.5, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onClear;
  const _ErrorCard({required this.message, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3F3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('Error', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.error_outline, size: 18),
                const Spacer(),
                IconButton(tooltip: 'Clear', onPressed: onClear, icon: const Icon(Icons.delete_outline)),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Text(message, style: const TextStyle(height: 1.5, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  final Animation<double> animation;
  const _LoadingCard({required this.animation});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 12),
            ScaleTransition(
              scale: Tween<double>(begin: .97, end: 1.03).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
              child: const Icon(Icons.hourglass_top_outlined, size: 42),
            ),
            const SizedBox(height: 12),
            const Text('Summarizing…', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            const LinearProgressIndicator(minHeight: 6),
            const SizedBox(height: 12),
            Text(
              'This usually takes a few seconds. You can paste another link meanwhile.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall!.copyWith(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onPaste;
  const _EmptyState({required this.onPaste});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.play_circle_outline, size: 56),
            const SizedBox(height: 12),
            const Text('Paste a YouTube URL', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'Then press Summarize to get a clean overview of the video.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall!.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onPaste,
              icon: const Icon(Icons.paste_outlined),
              label: const Text('Paste from clipboard'),
            )
          ],
        ),
      ),
    );
  }
}

class _BlurCircle extends StatelessWidget {
  final double size;
  final Color color;
  const _BlurCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      ),
    );
  }
}

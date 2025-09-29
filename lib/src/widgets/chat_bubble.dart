import 'package:flutter/material.dart';
import '../models/chat_message.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage msg;
  const ChatBubble({super.key, required this.msg});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.sender == Sender.user;

    final gradient = isUser
        ? const LinearGradient(
            colors: [Color(0xFFBFA463), Color(0xFF8B7355)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : null;

    final radius = isUser
        ? const BorderRadius.only(
            topLeft: Radius.circular(15),
            topRight: Radius.circular(15),
            bottomLeft: Radius.circular(15),
            bottomRight: Radius.circular(0),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(15),
            topRight: Radius.circular(15),
            bottomLeft: Radius.circular(0),
            bottomRight: Radius.circular(15),
          );

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: gradient,
          color: isUser ? null : const Color(0xFF222222),
          borderRadius: radius,
          border: isUser
              ? null
              : Border.all(color: const Color(0x40BFA463), width: 1),
        ),
        child: isUser
            ? const _UserText()
            : const _BotText(),
      ),
    );
  }
}

class _UserText extends StatelessWidget {
  const _UserText();

  @override
  Widget build(BuildContext context) {
    // You can make this SelectableText too if you want
    final text = (context.findAncestorWidgetOfExactType<ChatBubble>()!).msg.text;
    return Text(
      text,
      style: const TextStyle(color: Colors.black),
    );
  }
}

class _BotText extends StatelessWidget {
  const _BotText();

  @override
  Widget build(BuildContext context) {
    final text = (context.findAncestorWidgetOfExactType<ChatBubble>()!).msg.text;
    return SelectableText(
      text,
      style: const TextStyle(color: Colors.white),
    );
  }
}

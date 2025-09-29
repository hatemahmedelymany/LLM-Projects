
import 'package:flutter/material.dart';

class QuickActions extends StatelessWidget {
  final void Function(String) onSend;
  final String lang;
  const QuickActions({super.key, required this.onSend, required this.lang});

  @override
  Widget build(BuildContext context) {
    String t(String key) {
      final es = {
        'show': 'Ver Programas',
        'gold': 'Categoría Gold',
        '8d': 'Viaje de 8 días',
        'book': 'Reservar Ahora',
      };
      final en = {
        'show': 'Show Programs',
        'gold': 'Gold Category',
        '8d': '8-Day Trip',
        'book': 'Book Now',
      };
      final map = lang == 'es' ? es : en;
      return map[key] ?? key;
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _chip(t('show'), () => onSend(lang == 'es' ? 'ver opciones' : 'show options')),
        _chip(t('gold'), () => onSend(lang == 'es' ? 'categoría Gold' : 'Gold category')),
        _chip(t('8d'), () => onSend(lang == 'es' ? 'viaje de 8 días' : '8-day trip')),
        _chip(t('book'), () => onSend('/lead')),
      ],
    );
  }

  Widget _chip(String label, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0x40BFA463)),
        foregroundColor: const Color(0xFFBFA463),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: Text(label),
    );
  }
}

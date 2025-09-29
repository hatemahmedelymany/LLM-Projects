
import 'package:flutter/material.dart';

class LeadDialog extends StatefulWidget {
  const LeadDialog({super.key});

  @override
  State<LeadDialog> createState() => _LeadDialogState();
}

class _LeadDialogState extends State<LeadDialog> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  String _method = 'whatsapp';
  final _notes = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: const Text('Contactar a un Experto', style: TextStyle(color: Color(0xFFBFA463))),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _name, decoration: const InputDecoration(hintText: 'Nombre Completo / Full Name')),
            const SizedBox(height: 8),
            TextField(controller: _email, decoration: const InputDecoration(hintText: 'Correo Electrónico / Email')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _method,
              items: const [
                DropdownMenuItem(value: 'whatsapp', child: Text('WhatsApp')),
                DropdownMenuItem(value: 'email', child: Text('Email')),
                DropdownMenuItem(value: 'call', child: Text('Llamada / Call')),
              ],
              onChanged: (v) => setState(() => _method = v ?? 'whatsapp'),
            ),
            const SizedBox(height: 8),
            TextField(controller: _phone, decoration: const InputDecoration(hintText: 'Número de Teléfono / Phone')),
            const SizedBox(height: 8),
            TextField(controller: _notes, decoration: const InputDecoration(hintText: 'Notas / Notes'), maxLines: 3),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context, {
              'name': _name.text.trim(),
              'email': _email.text.trim(),
              'method': _method,
              'phone': _phone.text.trim(),
              'notes': _notes.text.trim(),
            });
          },
          child: const Text('Enviar Solicitud'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegistroLavaderoScreen extends StatefulWidget {
  const RegistroLavaderoScreen({super.key});

  @override
  State<RegistroLavaderoScreen> createState() => _RegistroLavaderoScreenState();
}

class _RegistroLavaderoScreenState extends State<RegistroLavaderoScreen> {
  final _nombreController = TextEditingController();
  final _direccionController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final supabase = Supabase.instance.client;

  Future<void> _registrar() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      await supabase.from('lavaderos').insert({
        'dueño_id': user.id,
        'razon_social': _nombreController.text,
        'direccion': _direccionController.text,
        'latitud': double.parse(_latController.text),
        'longitud': double.parse(_lngController.text),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Lavadero registrado con éxito")),
        );
        Navigator.pop(context); // Volver atrás
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Registrar Lavadero")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _nombreController, decoration: const InputDecoration(labelText: "Nombre Comercial")),
            TextField(controller: _direccionController, decoration: const InputDecoration(labelText: "Dirección")),
            TextField(controller: _latController, decoration: const InputDecoration(labelText: "Latitud (ej: -34.09)")),
            TextField(controller: _lngController, decoration: const InputDecoration(labelText: "Longitud (ej: -59.02)")),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _registrar, child: const Text("GUARDAR LAVADERO")),
          ],
        ),
      ),
    );
  }
}
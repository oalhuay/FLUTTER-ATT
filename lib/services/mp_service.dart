import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class MPService {
  // IP para emulador de Android. Si usas celular real, pon la IP de tu PC (ej: 192.168.1.XX)
  final String serverUrl = "http://localhost:3001";

  Future<String?> crearPreferencia({
    required String titulo,
    required double precio,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;

    try {
      final response = await http.post(
        Uri.parse('$serverUrl/create-preference'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "titulo": titulo,
          "precio": precio,
          "userId": user?.id, // Coincide con req.body.userId en Node.js
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['init_point'];
      } else {
        print("Error en el servidor Node: ${response.body}");
      }
    } catch (e) {
      print("Error de conexión con el servidor: $e");
    }
    return null;
  }

  // Esta función ahora solo se usará para obtener datos de la factura si es necesario,
  // ya que el servidor Node.js es quien hace el insert en Supabase vía Webhook.
  Future<Map<String, dynamic>?> registrarFacturaLimpia({
    required String paymentId,
    required String status,
    required double total,
    required String servicios,
  }) async {
    // Nota: El servidor Node ya insertó esto.
    // Aquí podrías hacer un SELECT para traer los datos y generar el PDF.
    try {
      final res = await Supabase.instance.client
          .from('facturas')
          .select()
          .eq('payment_id', paymentId)
          .single();
      return res;
    } catch (e) {
      return null;
    }
  }
}

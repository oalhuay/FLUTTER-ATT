import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class MPService {
  // Usamos tu URL principal de producción
  final String serverUrl = "https://flutter-att.vercel.app";

  Future<String?> crearPreferencia({
    required String titulo,
    required double precio,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    final double precioFinal = precio <= 0 ? 10.0 : precio;

    try {
      final response = await http.post(
        Uri.parse('$serverUrl/create-preference'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "titulo": titulo,
          "precio": precioFinal,
          "userId": user?.id,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['init_point'];
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // Busca la factura que el Webhook acaba de insertar
  Future<Map<String, dynamic>?> buscarFacturaEnSupabase({
    required String paymentId,
  }) async {
    try {
      final response = await Supabase.instance.client
          .from('facturas')
          .select()
          .eq('payment_id', paymentId)
          .maybeSingle();

      return response;
    } catch (e) {
      print("❌ Error al buscar factura: $e");
      return null;
    }
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class MPService {
  // IP para emulador de Android (10.0.2.2).
  // Si vas a probar en la web o celular real, recuerda cambiar esto por tu URL de Vercel/Ngrok.
  final String serverUrl = "https://flutter-att-8xz7.vercel.app";

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
        print("❌ Error en el servidor Node: ${response.body}");
        return null;
      }
    } catch (e) {
      print("❌ Error de conexión: $e");
      return null;
    }
  }

  // Nueva función para verificar si el pago ya impactó en Supabase
  // Esta la llamarás desde la pantalla de reserva tras volver de MP
  Future<bool> verificarPagoExitoso(String paymentId) async {
    try {
      final response = await Supabase.instance.client
          .from('facturas')
          .select()
          .eq('payment_id', paymentId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> buscarFacturaEnSupabase({
    required String paymentId,
  }) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return null;

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

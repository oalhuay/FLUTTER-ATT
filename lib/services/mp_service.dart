import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class MPService {
  // IP para emulador de Android (10.0.2.2).
  // Si vas a probar en la web o celular real, recuerda cambiar esto por tu URL de Vercel/Ngrok.
  final String serverUrl = "http://10.0.2.2:3001";

  Future<String?> crearPreferencia({
    required String titulo,
    required double precio,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;

    // Validación de seguridad mínima
    final double precioFinal = precio <= 0 ? 10.0 : precio;

    try {
      final response = await http.post(
        Uri.parse('$serverUrl/create-preference'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "titulo": titulo,
          "precio": precioFinal,
          "userId": user
              ?.id, // Enviamos el ID para que el Webhook sepa de quién es el pago
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // El servidor nos devuelve el link de Mercado Pago
        return data['init_point'];
      } else {
        print("❌ Error en el servidor Node: ${response.body}");
        return null;
      }
    } catch (e) {
      print("❌ Error de conexión con el servidor: $e");
      return null;
    }
  }

  /// Esta función busca en Supabase la factura que el Servidor Node ya debió insertar
  /// vía Webhook. La usamos para confirmar el pago y generar el PDF.
  Future<Map<String, dynamic>?> buscarFacturaEnSupabase({
    required String paymentId,
  }) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return null;

      // Hacemos el select para ver si el Webhook ya hizo su trabajo
      final response = await Supabase.instance.client
          .from('facturas')
          .select()
          .eq('payment_id', paymentId)
          .maybeSingle(); // Usamos maybeSingle para que no explote si aún no existe

      if (response != null) {
        print("✅ Factura encontrada en Supabase");
      }
      return response;
    } catch (e) {
      print("❌ Error al buscar factura: $e");
      return null;
    }
  }
}

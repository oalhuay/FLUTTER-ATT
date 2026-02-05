import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class MPService {
  final String _accessToken =
      "APP_USR-3237879502950879-012309-a6a9898d2fb9e8d05eee8e2d0d1a0adf-3154302970";
  final supabase = Supabase.instance.client;

  Future<String?> crearPreferencia({
    required String titulo,
    required double precio,
    required int cantidad,
  }) async {
    // Usamos 1.0 como mínimo para evitar errores de la API de Mercado Pago
    final double precioFinal = precio <= 0 ? 1.0 : precio;
    final url = Uri.parse('https://api.mercadopago.com/checkout/preferences');

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "items": [
            {
              "title": titulo,
              "quantity": cantidad,
              "unit_price": precioFinal,
              "currency_id": "ARS",
            },
          ],
          "back_urls": {
            // IMPORTANTE: Usamos el esquema de la app para el retorno
            "success": "att-app://pago-finalizado",
            "failure": "att-app://pago-finalizado",
            "pending": "att-app://pago-finalizado",
          },
          "auto_return": "approved",
          "external_reference": supabase.auth.currentUser?.id,
          "binary_mode": true, // Evita estados pendientes, o aprueba o rechaza
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['init_point'];
      } else {
        print("Error API Mercado Pago: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Error conexión MP: $e");
      return null;
    }
  }

  /// Registra la factura y devuelve la fila con ID y fecha real de Supabase
  Future<Map<String, dynamic>?> registrarFacturaLimpia({
    required String paymentId,
    required String status,
    required double total,
    required String servicios,
  }) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return null;

      final response = await supabase
          .from('facturas')
          .insert({
            'payment_id': paymentId,
            'status': status,
            'forma_pago': 'mercadopago',
            'total': total,
            'servicios': servicios,
            'user_id': user.id,
          })
          .select()
          .single();

      print("✅ Factura registrada exitosamente");
      return response;
    } catch (e) {
      print("❌ Error al registrar factura en Supabase: $e");
      return null;
    }
  }
}

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
            // Esquema personalizado para que el celular abra tu App
            "success": "localhost:3000/pago-finalizado",
            "failure": "localhost:3000/pago-finalizado",
            "pending": "localhost:3000/pago-finalizado",
          },
          "auto_return": "approved",
          "external_reference": supabase.auth.currentUser?.id,
          "binary_mode": true, // Solo acepta pagos de aprobación instantánea
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['init_point'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> registrarFacturaLimpia({
    required String paymentId,
    required String status,
    required double total,
    required String servicios,
  }) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return null;

      return await supabase
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
    } catch (e) {
      return null;
    }
  }
}

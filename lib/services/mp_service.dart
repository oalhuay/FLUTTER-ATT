import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class MPService {
  // TODO: Mover a una variable de entorno o Supabase Vault por seguridad
  final String _accessToken =
      "APP_USR-3237879502950879-012309-a6a9898d2fb9e8d05eee8e2d0d1a0adf-3154302970";

  final supabase = Supabase.instance.client;

  Future<String?> crearPreferencia({
    required String titulo,
    required double precio,
    required int cantidad,
  }) async {
    // Evita que Mercado Pago rebote el pago por monto 0
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
            "success": "localhost:3000/success",
            "failure": "localhost:3000/failure",
            "pending": "localhost:3000/pending",
          },
          "auto_return": "approved",
          // Vinculamos el pago al usuario de Supabase para rastreo
          "external_reference": supabase.auth.currentUser?.id,
          // Evita pagos duplicados con la misma intención
          "binary_mode": true,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['init_point']; // URL para abrir en el WebView o Navegador
      } else {
        print("Error API Mercado Pago: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Error de red/conexión MP: $e");
      return null;
    }
  }

  /// Registra la factura en Supabase y devuelve los datos completos (incluida la fecha real)
  Future<Map<String, dynamic>?> registrarFacturaLimpia({
    required String paymentId,
    required String status,
    required double total,
    required String servicios,
  }) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("Usuario no autenticado");

      final response = await supabase
          .from('facturas')
          .insert({
            'payment_id': paymentId,
            'status': status,
            'forma_pago': 'mercadopago',
            'total': total,
            'servicios': servicios,
            'user_id': user.id,
            // 'email_cliente': user.email, // Útil para el PDF
          })
          .select()
          .single();

      return response;
    } catch (e) {
      print("❌ Error crítico al registrar en Supabase: $e");
      return null;
    }
  }
}

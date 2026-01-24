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
    final precioFinal = precio <= 0 ? 100.0 : precio;
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
            "success": "https://www.google.com/success",
            "failure": "https://www.google.com/failure",
            "pending": "https://www.google.com/pending",
          },
          "auto_return": "approved",
          "external_reference": supabase.auth.currentUser?.id,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['init_point'];
      } else {
        print("Error MP: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Error conexión MP: $e");
      return null;
    }
  }

  // --- FUNCIÓN EVOLUCIONADA: REGISTRA Y DEVUELVE LA FILA PARA EL PDF ---
  Future<Map<String, dynamic>?> registrarFacturaLimpia({
    required String paymentId,
    required String status,
    required double total,
    required String servicios,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;

      // Usamos .select().single() para que nos devuelva el registro recién creado
      // Esto nos da el 'id' generado por la DB y la 'fecha_emision' real.
      final response = await supabase
          .from('facturas')
          .insert({
            'payment_id': paymentId,
            'status': status,
            'forma_pago': 'mercadopago',
            'total': total,
            'servicios': servicios,
            'user_id': userId,
          })
          .select()
          .single();

      print("✅ Factura registrada y retornada para comprobante");
      return response;
    } catch (e) {
      print("❌ Error al registrar factura: $e");
      return null;
    }
  }
}

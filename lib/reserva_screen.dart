import 'dart:typed_data'; // Necesario para los bytes del PDF
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/mp_service.dart';
import 'services/pdf_helper.dart';

class ReservaScreen extends StatefulWidget {
  final dynamic lavadero;
  const ReservaScreen({super.key, required this.lavadero});

  @override
  State<ReservaScreen> createState() => _ReservaScreenState();
}

class _ReservaScreenState extends State<ReservaScreen> {
  late final Stream<List<Map<String, dynamic>>> _turnosStream;
  final List<String> _serviciosSeleccionados = ["Lavado"];
  double _totalAPagar = 0.0;

  @override
  void initState() {
    super.initState();
    final nombreLavadero = widget.lavadero['razon_social'];
    _calcularTotal();

    _turnosStream = Supabase.instance.client
        .from('turnos')
        .stream(primaryKey: ['id'])
        .eq('lavadero_nombre', nombreLavadero);
  }

  void _calcularTotal() {
    double tempTotal = 0.0;
    final Map<String, dynamic> precios =
        widget.lavadero['servicios_precios'] ?? {};

    for (var servicio in _serviciosSeleccionados) {
      double precioServicio = (precios[servicio] ?? 5000.0).toDouble();
      tempTotal += precioServicio;
    }

    setState(() {
      _totalAPagar = tempTotal;
    });
  }

  // --- NUEVA FUNCIÓN: SUBIR A STORAGE Y ASOCIAR AL TURNO ---
  Future<void> _subirComprobanteAStorage(
    String turnoId,
    Uint8List pdfBytes,
  ) async {
    try {
      final String path = 'tickets/comprobante_$turnoId.pdf';

      // 1. Subir al bucket 'comprobantes'
      await Supabase.instance.client.storage
          .from('comprobantes')
          .uploadBinary(
            path,
            pdfBytes,
            fileOptions: const FileOptions(upsert: true),
          );

      // 2. Obtener URL pública
      final String publicUrl = Supabase.instance.client.storage
          .from('comprobantes')
          .getPublicUrl(path);

      // 3. Actualizar la tabla turnos con la URL
      await Supabase.instance.client
          .from('turnos')
          .update({'url_comprobante': publicUrl})
          .eq('id', turnoId);

      debugPrint("✅ Comprobante vinculado: $publicUrl");
    } catch (e) {
      debugPrint("❌ Error Storage/Update: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final horarios = ["09:00", "10:00", "11:00", "15:00", "16:00", "17:00"];
    final Map<String, dynamic> serviciosDisponibles =
        widget.lavadero['servicios_precios'] ?? {};

    return Scaffold(
      appBar: AppBar(
        title: Text("Reserva: ${widget.lavadero['razon_social']}"),
        backgroundColor: const Color(0xFF3ABEF9),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            color: const Color(0xFF3ABEF9).withOpacity(0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Servicios Adicionales:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: serviciosDisponibles.keys.map((serv) {
                    final seleccionado = _serviciosSeleccionados.contains(serv);
                    return FilterChip(
                      label: Text("$serv (\$${serviciosDisponibles[serv]})"),
                      selected: seleccionado,
                      onSelected: serv == "Lavado"
                          ? null
                          : (val) {
                              setState(() {
                                val
                                    ? _serviciosSeleccionados.add(serv)
                                    : _serviciosSeleccionados.remove(serv);
                                _calcularTotal();
                              });
                            },
                    );
                  }).toList(),
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "TOTAL A PAGAR:",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "\$${_totalAPagar.toStringAsFixed(0)}",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _turnosStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snapshot.data ?? [];
                final horariosOcupados = data.map((item) {
                  String horaDb = item['hora'].toString().trim();
                  return horaDb.length >= 5 ? horaDb.substring(0, 5) : horaDb;
                }).toList();

                return ListView.builder(
                  itemCount: horarios.length,
                  itemBuilder: (context, index) {
                    final horaActual = horarios[index];
                    final estaOcupado = horariosOcupados.contains(horaActual);

                    return Card(
                      color: estaOcupado ? Colors.grey[200] : Colors.white,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 5,
                      ),
                      child: ListTile(
                        leading: Icon(
                          estaOcupado ? Icons.block : Icons.access_time,
                          color: estaOcupado
                              ? Colors.grey
                              : const Color(0xFF3ABEF9),
                        ),
                        title: Text(
                          "Horario: $horaActual hs",
                          style: TextStyle(
                            decoration: estaOcupado
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        trailing: estaOcupado
                            ? const Text("OCUPADO")
                            : const Icon(Icons.payment, color: Colors.green),
                        onTap: estaOcupado
                            ? null
                            : () => _procesarPagoYReserva(context, horaActual),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _procesarPagoYReserva(BuildContext context, String hora) async {
    final usuario = Supabase.instance.client.auth.currentUser;
    if (usuario == null) return;

    if (_totalAPagar <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("⚠️ Total inválido")));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final mp = MPService();
      final urlPago = await mp.crearPreferencia(
        titulo: "Reserva ATT: ${widget.lavadero['razon_social']}",
        precio: _totalAPagar,
        cantidad: 1,
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (urlPago != null) {
        await launchUrl(
          Uri.parse(urlPago),
          mode: LaunchMode.externalApplication,
        );

        // 1. REGISTRO DE FACTURA
        final facturaData = await mp.registrarFacturaLimpia(
          paymentId: "MP-${DateTime.now().millisecondsSinceEpoch}",
          status: "approved",
          total: _totalAPagar,
          servicios: _serviciosSeleccionados.join(", "),
        );

        // 2. GUARDADO DEL TURNO (Obtenemos el ID para asociar el PDF)
        final response = await Supabase.instance.client
            .from('turnos')
            .insert({
              'hora': hora,
              'lavadero_nombre': widget.lavadero['razon_social'],
              'user_id': usuario.id,
              'monto_pagado': _totalAPagar,
              'servicios': _serviciosSeleccionados.join(", "),
            })
            .select()
            .single();

        final turnoId = response['id'].toString();

        // 3. GENERACIÓN DE BYTES Y SUBIDA A STORAGE
        if (facturaData != null) {
          final pdfBytes = await PdfHelper.obtenerBytesPDF(
            nroFactura: facturaData['id']
                .toString()
                .substring(0, 8)
                .toUpperCase(),
            lavadero: widget.lavadero['razon_social'],
            fecha: facturaData['fecha_emision'].toString(),
            servicios: facturaData['servicios'],
            total: (facturaData['total'] as num).toDouble(),
          );

          await _subirComprobanteAStorage(turnoId, pdfBytes);
          _mostrarExitoConTicket(hora, facturaData);
        } else {
          _mostrarExitoSimple(hora);
        }
      }
    } catch (e) {
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);
      debugPrint("❌ Error: $e");
    }
  }

  void _mostrarExitoConTicket(String hora, Map<String, dynamic> factura) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Icon(Icons.check_circle, color: Colors.green, size: 60),
        content: const Text(
          "¡Pago y Reserva exitosa!\nEl comprobante se guardó en tu historial.",
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () => PdfHelper.generarComprobante(
              nroFactura: factura['id']
                  .toString()
                  .substring(0, 8)
                  .toUpperCase(),
              lavadero: widget.lavadero['razon_social'],
              fecha: factura['fecha_emision'].toString(),
              servicios: factura['servicios'],
              total: (factura['total'] as num).toDouble(),
            ),
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text("DESCARGAR TICKET"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text("SALIR"),
          ),
        ],
      ),
    );
  }

  void _mostrarExitoSimple(String hora) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Icon(Icons.check_circle, color: Colors.green),
        content: Text("Reserva confirmada para las $hora hs."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CERRAR"),
          ),
        ],
      ),
    );
  }
}

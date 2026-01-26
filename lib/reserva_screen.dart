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
  late Stream<List<Map<String, dynamic>>> _turnosStream;
  final List<String> _serviciosSeleccionados = ["Lavado"];
  double _totalAPagar = 0.0;

  // --- VARIABLES DE ESTADO ---
  bool _estaProcesando = false;
  DateTime _fechaSeleccionada = DateTime.now();
  final TextEditingController _comentariosController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _calcularTotal();
    _inicializarStream();
  }

  void _inicializarStream() {
    final nombreLavadero = widget.lavadero['razon_social'];
    setState(() {
      _turnosStream = Supabase.instance.client
          .from('turnos')
          .stream(primaryKey: ['id'])
          .eq('lavadero_nombre', nombreLavadero);
    });
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

  Future<void> _subirComprobanteAStorage(
    String turnoId,
    Uint8List pdfBytes,
  ) async {
    try {
      final String path = 'tickets/comprobante_$turnoId.pdf';

      await Supabase.instance.client.storage
          .from('comprobantes')
          .uploadBinary(
            path,
            pdfBytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final String publicUrl = Supabase.instance.client.storage
          .from('comprobantes')
          .getPublicUrl(path);

      await Supabase.instance.client
          .from('turnos')
          .update({'url_comprobante': publicUrl})
          .eq('id', turnoId);

      debugPrint("✅ Comprobante vinculado: $publicUrl");
    } catch (e) {
      debugPrint("❌ Error Storage/Update: $e");
    }
  }

  // --- DIÁLOGO DE PREAVISO ---
  void _confirmarAntesDePagar(BuildContext context, String hora) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Color(0xFF3ABEF9)),
            SizedBox(width: 10),
            Text("Confirmar Turno"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("¿Estás seguro de elegir esta fecha y horario?"),
            const SizedBox(height: 15),
            Text(
              "📅 Fecha: ${_fechaSeleccionada.day}/${_fechaSeleccionada.month}/${_fechaSeleccionada.year}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              "⏰ Horario: $hora hs",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCELAR", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3ABEF9),
            ),
            onPressed: () {
              Navigator.pop(context); // Cierra el aviso
              _procesarPagoYReserva(context, hora); // Inicia el proceso
            },
            child: const Text(
              "SÍ, CONTINUAR AL PAGO",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
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
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                color: const Color(0xFF3ABEF9).withOpacity(0.1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Seleccionar Fecha:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.calendar_month,
                        color: Color(0xFFEF4444),
                      ),
                      title: Text(
                        "${_fechaSeleccionada.day}/${_fechaSeleccionada.month}/${_fechaSeleccionada.year}",
                      ),
                      trailing: const Text(
                        "CAMBIAR",
                        style: TextStyle(
                          color: Color(0xFF3ABEF9),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _fechaSeleccionada,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 30),
                          ),
                        );
                        if (picked != null)
                          setState(() => _fechaSeleccionada = picked);
                      },
                    ),
                    const Divider(),
                    const Text(
                      "Servicios Adicionales:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: serviciosDisponibles.keys.map((serv) {
                        final seleccionado = _serviciosSeleccionados.contains(
                          serv,
                        );
                        return FilterChip(
                          label: Text(
                            "$serv (\$${serviciosDisponibles[serv]})",
                          ),
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
                    const SizedBox(height: 15),
                    TextField(
                      controller: _comentariosController,
                      decoration: InputDecoration(
                        labelText: "Comentarios o indicaciones...",
                        prefixIcon: const Icon(Icons.comment_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
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
                    if (snapshot.connectionState == ConnectionState.waiting)
                      return const Center(child: CircularProgressIndicator());

                    final fechaIso = _fechaSeleccionada.toIso8601String().split(
                      'T',
                    )[0];
                    final dataFiltrada = (snapshot.data ?? [])
                    .where((t) => 
                        t['fecha'].toString() == fechaIso && 
                        t['estado'] != 'cancelado' // <--- ESTO LIBERA EL HORARIO
                    )
                    .toList();
                    final ocupados = dataFiltrada.map((item) {
                      String h = item['hora'].toString().trim();
                      return h.length >= 5 ? h.substring(0, 5) : h;
                    }).toList();

                    return ListView.builder(
                      itemCount: horarios.length,
                      itemBuilder: (context, index) {
                        final hora = horarios[index];
                        final estaOcupado = ocupados.contains(hora);
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
                              "Horario: $hora hs",
                              style: TextStyle(
                                decoration: estaOcupado
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            trailing: estaOcupado
                                ? const Text(
                                    "OCUPADO",
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : const Icon(
                                    Icons.payment,
                                    color: Colors.green,
                                  ),
                            onTap: estaOcupado
                                ? null
                                : () => _confirmarAntesDePagar(context, hora),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          // --- CAPA DE CARGA (Para evitar bloqueos de Navigator) ---
          if (_estaProcesando)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  void _procesarPagoYReserva(BuildContext context, String hora) async {
    final usuario = Supabase.instance.client.auth.currentUser;
    if (usuario == null) return;
    if (_totalAPagar <= 0) return;

    setState(() => _estaProcesando = true);

    try {
      final mp = MPService();
      final urlPago = await mp.crearPreferencia(
        titulo: "Reserva ATT: ${widget.lavadero['razon_social']}",
        precio: _totalAPagar,
        cantidad: 1,
      );

      if (urlPago != null) {
        await launchUrl(
          Uri.parse(urlPago),
          mode: LaunchMode.externalApplication,
        );

        final facturaData = await mp.registrarFacturaLimpia(
          paymentId: "MP-${DateTime.now().millisecondsSinceEpoch}",
          status: "approved",
          total: _totalAPagar,
          servicios: _serviciosSeleccionados.join(", "),
        );

        final response = await Supabase.instance.client
            .from('turnos')
            .insert({
              'hora': hora,
              'fecha': _fechaSeleccionada.toIso8601String().split('T')[0],
              'comentarios': _comentariosController.text,
              'lavadero_nombre': widget.lavadero['razon_social'],
              'user_id': usuario.id,
              'monto_pagado': _totalAPagar,
              'servicios': _serviciosSeleccionados.join(", "),
              'estado': 'activo',
            })
            .select()
            .single();

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
          await _subirComprobanteAStorage(response['id'].toString(), pdfBytes);
          setState(() => _estaProcesando = false);
          _mostrarExitoConTicket(hora, facturaData);
        }
      } else {
        setState(() => _estaProcesando = false);
      }
    } catch (e) {
      setState(() => _estaProcesando = false);
      debugPrint("❌ Error: $e");
    }
  }

  void _mostrarExitoConTicket(String hora, Map<String, dynamic> factura) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Icon(Icons.check_circle, color: Colors.green, size: 60),
        content: const Text("¡Pago y Reserva exitosa!"),
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
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart'; // Importante para abrir el link del Storage

class MisTurnosScreen extends StatefulWidget {
  const MisTurnosScreen({super.key});

  @override
  State<MisTurnosScreen> createState() => _MisTurnosScreenState();
}

class _MisTurnosScreenState extends State<MisTurnosScreen> {
  final supabase = Supabase.instance.client;
  List<dynamic> misTurnos = [];
  bool cargando = true;

  String ultimaActualizacion = "---";
  bool botonHabilitado = true;
  int segundosRestantes = 0;

  Timer? _timerBloqueo;
  Timer? _timerSemaforo;

  DateTime? _horaUltimaPeticion;
  Color _colorEstado = Colors.grey;

  @override
  void initState() {
    super.initState();
    _cargarMisTurnos();
  }

  @override
  void dispose() {
    _timerBloqueo?.cancel();
    _timerSemaforo?.cancel();
    super.dispose();
  }

  // --- CANCELACIÓN OPTIMISTA ---
  Future<void> _cancelarTurno(dynamic idTurno) async {
    setState(() {
      misTurnos.removeWhere((t) => t['id'].toString() == idTurno.toString());
    });

    try {
      await supabase
          .from('turnos')
          .update({'estado': 'cancelado'})
          .eq('id', idTurno);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Reserva cancelada exitosamente"),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error al cancelar: $e");
      _cargarMisTurnos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Error al sincronizar. El turno regresará."),
          ),
        );
      }
    }
  }

  Future<void> _cargarMisTurnos() async {
    setState(() {
      cargando = true;
      botonHabilitado = false;
    });

    try {
      final data = await supabase
          .from('turnos')
          .select()
          .order('hora', ascending: true);

      final ahora = DateTime.now();
      _horaUltimaPeticion = ahora;
      final horaFormateada =
          "${ahora.hour.toString().padLeft(2, '0')}:${ahora.minute.toString().padLeft(2, '0')}:${ahora.second.toString().padLeft(2, '0')}";

      if (mounted) {
        setState(() {
          misTurnos = data;
          ultimaActualizacion = horaFormateada;
          cargando = false;
          segundosRestantes = 5;
          _colorEstado = Colors.green;
        });
        _iniciarTemporizadorBloqueo();
        _iniciarSemaforo();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          cargando = false;
          botonHabilitado = true;
        });
      }
    }
  }

  void _iniciarTemporizadorBloqueo() {
    _timerBloqueo?.cancel();
    _timerBloqueo = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (segundosRestantes > 0) {
            segundosRestantes--;
          } else {
            botonHabilitado = true;
            timer.cancel();
          }
        });
      }
    });
  }

  void _iniciarSemaforo() {
    _timerSemaforo?.cancel();
    _timerSemaforo = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_horaUltimaPeticion == null) return;
      final diferencia = DateTime.now()
          .difference(_horaUltimaPeticion!)
          .inSeconds;
      Color nuevoColor = diferencia <= 30
          ? Colors.green
          : (diferencia <= 60 ? Colors.amber : Colors.red);
      if (mounted && _colorEstado != nuevoColor)
        setState(() => _colorEstado = nuevoColor);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mis Reservas ATT!"),
        backgroundColor: const Color(0xFFEF4444),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Barra de estado superior
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.circle, size: 10, color: _colorEstado),
                    const SizedBox(width: 8),
                    Text(
                      "Sync: $ultimaActualizacion",
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: botonHabilitado ? _cargarMisTurnos : null,
                  icon: Icon(
                    botonHabilitado ? Icons.refresh : Icons.hourglass_empty,
                    size: 16,
                  ),
                  label: Text(
                    botonHabilitado ? "Actualizar" : "$segundosRestantes s",
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: cargando
                ? const Center(child: CircularProgressIndicator())
                : misTurnos.isEmpty
                ? const Center(child: Text("No tienes turnos reservados."))
                : ListView.builder(
                    itemCount: misTurnos.length,
                    itemBuilder: (context, index) {
                      final turno = misTurnos[index];
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ExpansionTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFF3ABEF9),
                            child: Icon(
                              Icons.directions_car,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            turno['lavadero_nombre'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text("Hoy: ${turno['hora']} hs"),
                          trailing: Text(
                            "\$${turno['monto_pagado'] ?? '0'}",
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Divider(),
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.receipt_long,
                                        size: 18,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        "Detalle:",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: Text(
                                          turno['servicios'] ??
                                              "Lavado estándar",
                                          style: const TextStyle(
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 15),

                                  // --- BOTÓN PARA ABRIR EL PDF DESDE STORAGE ---
                                  if (turno['url_comprobante'] != null)
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: () async {
                                          final url = Uri.parse(
                                            turno['url_comprobante'],
                                          );
                                          if (await canLaunchUrl(url)) {
                                            await launchUrl(
                                              url,
                                              mode: LaunchMode
                                                  .externalApplication,
                                            );
                                          }
                                        },
                                        icon: const Icon(
                                          Icons.picture_as_pdf,
                                          color: Colors.red,
                                        ),
                                        label: const Text(
                                          "VER COMPROBANTE PDF",
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(
                                            color: Colors.red,
                                          ),
                                          foregroundColor: Colors.red,
                                        ),
                                      ),
                                    ),

                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      // 1. TEXTO DEL ESTADO (Izquierda)
                                      Text(
                                        turno['estado'] == 'cancelado'
                                            ? "Estado: Cancelado"
                                            : "Estado: Pagado Online",
                                        style: TextStyle(
                                          color: turno['estado'] == 'cancelado'
                                              ? Colors.red
                                              : const Color(0xFF3ABEF9),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),

                                      // 2. EL BOTÓN CON CEREBRO (Derecha)
                                      // Preguntamos: ¿Está cancelado?
                                      turno['estado'] == 'cancelado'
                                          ? const Text(
                                              "ANULADO",
                                              style: TextStyle(
                                                color: Colors.grey,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ) // Si es verdadero, muestra esto
                                          : TextButton.icon(
                                              onPressed: () =>
                                                  _cancelarTurno(turno['id']),
                                              icon: const Icon(
                                                Icons.cancel,
                                                color: Colors.red,
                                                size: 20,
                                              ),
                                              label: const Text(
                                                "CANCELAR",
                                                style: TextStyle(
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ), // Si es falso, muestra el botón
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

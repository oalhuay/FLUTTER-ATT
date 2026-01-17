import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  // --- FUNCIÓN DE CANCELACIÓN OPTIMISTA Y ROBUSTA ---
  Future<void> _cancelarTurno(dynamic idTurno) async {
    // 1. Borrado Local Instantáneo e Infalible
    // Convertimos ambos a String para asegurar que la comparación sea exitosa
    setState(() {
      misTurnos.removeWhere((t) => t['id'].toString() == idTurno.toString());
    });

    try {
      // 2. Ejecutamos el borrado en Supabase (usamos await para asegurar la petición)
      await supabase.from('turnos').delete().eq('id', idTurno);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Reserva cancelada exitosamente"),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 1),
          ),
        );
        // NOTA: No llamamos a _cargarMisTurnos() aquí para evitar que el dato
        // "vuelva" si la DB aún no se actualizó internamente.
        // El usuario ya no lo ve, que es lo que importa.
      }
    } catch (e) {
      debugPrint("Error al cancelar en la nube: $e");

      // 3. Si falla la red, recuperamos los datos reales para que no haya inconsistencia
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
      debugPrint("Error: $e");
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

      Color nuevoColor;
      if (diferencia <= 30) {
        nuevoColor = Colors.green;
      } else if (diferencia <= 60) {
        nuevoColor = Colors.amber;
      } else {
        nuevoColor = Colors.red;
      }

      if (mounted && _colorEstado != nuevoColor) {
        setState(() => _colorEstado = nuevoColor);
      }
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      "Actualizado: $ultimaActualizacion",
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.circle, size: 12, color: _colorEstado),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: botonHabilitado ? _cargarMisTurnos : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3ABEF9),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                  ),
                  icon: Icon(
                    botonHabilitado ? Icons.refresh : Icons.timer,
                    size: 18,
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
                        margin: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 5,
                        ),
                        child: ListTile(
                          leading: const Icon(
                            Icons.directions_car,
                            color: Color(0xFF3ABEF9),
                          ),
                          title: Text(turno['lavadero_nombre']),
                          subtitle: Text("Hora: ${turno['hora']} hs"),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: () {
                              // Pasamos el ID directamente
                              _cancelarTurno(turno['id']);
                            },
                          ),
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

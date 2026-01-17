import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReservaScreen extends StatefulWidget {
  final dynamic lavadero;
  const ReservaScreen({super.key, required this.lavadero});

  @override
  State<ReservaScreen> createState() => _ReservaScreenState();
}

class _ReservaScreenState extends State<ReservaScreen> {
  late final Stream<List<Map<String, dynamic>>> _turnosStream;

  @override
  void initState() {
    super.initState();
    final nombreLavadero = widget.lavadero['razon_social'];

    _turnosStream = Supabase.instance.client
        .from('turnos')
        .stream(primaryKey: ['id'])
        .eq('lavadero_nombre', nombreLavadero);

    debugPrint("🚀 Realtime activado para el lavadero: $nombreLavadero");
  }

  @override
  Widget build(BuildContext context) {
    final horarios = ["09:00", "10:00", "11:00", "15:00", "16:00", "17:00"];

    return Scaffold(
      appBar: AppBar(
        title: Text("Turnos: ${widget.lavadero['razon_social']}"),
        backgroundColor: const Color(0xFF3ABEF9),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Image.asset(
              'assets/logo_att.png',
              height: 120,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.car_repair,
                size: 80,
                color: Color(0xFF3ABEF9),
              ),
            ),
          ),
          const Divider(color: Color(0xFF3ABEF9), indent: 50, endIndent: 50),
          const Padding(
            padding: EdgeInsets.all(15.0),
            child: Text(
              "Seleccioná un horario para hoy:",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFFEF4444),
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _turnosStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF3ABEF9)),
                  );
                }

                final data = snapshot.data ?? [];
                final horariosOcupados = data
                    .map((item) => item['hora'].toString().trim())
                    .toList();

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
                            color: estaOcupado ? Colors.grey : Colors.black,
                            decoration: estaOcupado
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        trailing: estaOcupado
                            ? const Text(
                                "OCUPADO",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : const Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: Color(0xFFEF4444),
                              ),
                        onTap: estaOcupado
                            ? null
                            : () => _confirmarTurno(context, horaActual),
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

  // --- FUNCIÓN DE RESERVA ACTUALIZADA ---
  void _confirmarTurno(BuildContext context, String hora) async {
    // 1. Obtener el usuario actual de Supabase
    final usuario = Supabase.instance.client.auth.currentUser;

    // 2. Seguridad: Si no hay usuario, no puede reservar
    if (usuario == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Debes iniciar sesión con Google para reservar"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF3ABEF9)),
      ),
    );

    try {
      // 3. Enviar el insert con el user_id del dueño del turno
      await Supabase.instance.client.from('turnos').insert({
        'hora': hora,
        'lavadero_nombre': widget.lavadero['razon_social'],
        'user_id': usuario.id, // <--- CAMBIO CLAVE: Enviamos el UUID de Google
      });

      if (!mounted) return;
      Navigator.pop(context); // Cierra el circulo de carga

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Icon(Icons.check_circle, color: Colors.green, size: 60),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "¡Turno Reservado!",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                "Te esperamos a las $hora hs en ${widget.lavadero['razon_social']}",
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context); // Cierra éxito
                  Navigator.pop(context); // Vuelve al mapa
                },
                child: const Text(
                  "ENTENDIDO",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Cierra el circulo de carga

      // Imprime el error real en la consola para depurar
      debugPrint("❌ Error de Postgres: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Error al reservar: Verifica que la tabla tenga la columna user_id",
          ),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class RegistroLavaderoScreen extends StatefulWidget {
  const RegistroLavaderoScreen({super.key});

  @override
  State<RegistroLavaderoScreen> createState() => _RegistroLavaderoScreenState();
}

class _RegistroLavaderoScreenState extends State<RegistroLavaderoScreen> {
  final _nombreController = TextEditingController();
  final _direccionController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final supabase = Supabase.instance.client;

  bool _mostrarMapa = false;
  // Posición inicial: Zárate, Argentina
  LatLng _puntoSeleccionado = const LatLng(-34.098, -59.028);

  @override
  void initState() {
    super.initState();
    // Inicializamos con los valores por defecto para evitar errores de null
    _actualizarControllers(_puntoSeleccionado);
  }

  void _actualizarControllers(LatLng punto) {
    _latController.text = punto.latitude.toStringAsFixed(6);
    _lngController.text = punto.longitude.toStringAsFixed(6);
  }

  Future<void> _registrar() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    if (_nombreController.text.isEmpty || _direccionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Por favor, completa el nombre y la dirección")),
      );
      return;
    }

    try {
      // Importante: Verifica que el nombre de la columna sea 'dueño_id' o 'dueno_id' en tu DB
      await supabase.from('lavaderos').insert({
        'dueño_id': user.id, 
        'razon_social': _nombreController.text,
        'direccion': _direccionController.text,
        'latitud': double.parse(_latController.text),
        'longitud': double.parse(_lngController.text),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Lavadero registrado con éxito")),
        );
        Navigator.pop(context); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Error al guardar: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Registrar Lavadero"),
        backgroundColor: const Color(0xFF3ABEF9),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nombreController,
              decoration: const InputDecoration(
                labelText: "Nombre Comercial",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _direccionController,
              decoration: const InputDecoration(
                labelText: "Dirección (Calle y altura)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Ubicación del Lavadero:",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _mostrarMapa = !_mostrarMapa),
                  icon: Icon(_mostrarMapa ? Icons.layers_clear : Icons.map),
                  label: Text(_mostrarMapa ? "Ocultar Mapa" : "Seleccionar en Mapa"),
                ),
              ],
            ),

            if (_mostrarMapa) ...[
              const Text(
                "Toca el mapa para posicionar el marcador",
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              Container(
                height: 300, // Altura fija para asegurar visibilidad
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.blueGrey.shade200),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: _puntoSeleccionado,
                      initialZoom: 15,
                      onTap: (tapPosition, point) {
                        setState(() {
                          _puntoSeleccionado = point;
                          _actualizarControllers(point);
                        });
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.tuapp.att',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _puntoSeleccionado,
                            width: 50,
                            height: 50,
                            child: const Icon(
                              Icons.location_on,
                              color: Color(0xFFEF4444),
                              size: 45,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latController,
                    readOnly: true, // Evita errores de escritura manual
                    decoration: const InputDecoration(
                      labelText: "Latitud",
                      prefixIcon: Icon(Icons.gps_fixed, size: 18),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _lngController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: "Longitud",
                      prefixIcon: Icon(Icons.gps_fixed, size: 18),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _registrar,
                child: const Text(
                  "GUARDAR LAVADERO",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
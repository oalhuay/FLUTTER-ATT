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
  // Controladores existentes
  final _nombreController = TextEditingController();
  final _direccionController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  // NUEVOS Controladores según documentación
  final _telefonoController = TextEditingController();
  final _bancoController = TextEditingController();
  final _cuentaController = TextEditingController();

  // --- LÓGICA DE SERVICIOS (TAGS) ---
  final _tagController = TextEditingController();
  final List<String> _servicios = [
    'Lavado',
    'Control de aire/ruedas',
    'Venta de insumos',
  ];

  final supabase = Supabase.instance.client;

  bool _mostrarMapa = true;
  LatLng _puntoSeleccionado = const LatLng(-34.098, -59.028);

  @override
  void initState() {
    super.initState();
    _actualizarControllers(_puntoSeleccionado);
  }

  void _actualizarControllers(LatLng punto) {
    _latController.text = punto.latitude.toStringAsFixed(6);
    _lngController.text = punto.longitude.toStringAsFixed(6);
  }

  // Método para añadir tags personalizados
  void _addTag(String val) {
    if (val.isNotEmpty && !_servicios.contains(val)) {
      setState(() {
        _servicios.add(val);
        _tagController.clear();
      });
    }
  }

  Future<void> _registrar() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    if (_nombreController.text.isEmpty ||
        _direccionController.text.isEmpty ||
        _telefonoController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ Por favor, completa los datos del lavadero"),
        ),
      );
      return;
    }

    try {
      await supabase.from('lavaderos').insert({
        'dueño_id': user.id,
        'razon_social': _nombreController.text,
        'direccion': _direccionController.text,
        'telefono': _telefonoController.text,
        'nombre_banco': _bancoController.text,
        'cuenta_bancaria': _cuentaController.text,
        'latitud': double.parse(_latController.text),
        'longitud': double.parse(_lngController.text),
        'servicios': _servicios, // Se envía la lista de tags
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Lavadero registrado con éxito")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("❌ Error al guardar: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(
        title: const Text("Configurar mi Lavadero"),
        backgroundColor: const Color(0xFF3ABEF9),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // --- SECCIÓN 1: DATOS DEL LAVADERO ---
            
            _buildSectionCard(
              title: "Datos del Lavadero",
              icon: Icons.local_car_wash,
              children: [
                _buildField(
                  _nombreController,
                  "Nombre Comercial",
                  Icons.storefront,
                ),
                const SizedBox(height: 15),
                _buildField(
                  _direccionController,
                  "Dirección (Calle y altura)",
                  Icons.location_on,
                ),
                const SizedBox(height: 15),
                _buildField(
                  _telefonoController,
                  "Teléfono de contacto",
                  Icons.phone,
                  type: TextInputType.phone,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // --- NUEVA SECCIÓN: SERVICIOS OFRECIDOS (TAGS) ---
            _buildSectionCard(
              title: "Servicios Ofrecidos",
              icon: Icons.list_alt,
              children: [
                const Text(
                  "Define tus servicios. Escribe y presiona Enter para añadir.",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 15),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: _servicios.map((s) {
                    final bool esFijo = s == 'Lavado';
                    return Chip(
                      label: Text(
                        s,
                        style: TextStyle(
                          color: esFijo ? Colors.white : Colors.black87,
                        ),
                      ),
                      backgroundColor: esFijo
                          ? const Color(0xFF3ABEF9)
                          : Colors.white,
                      side: BorderSide(
                        color: const Color(0xFF3ABEF9).withOpacity(0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      onDeleted: esFijo
                          ? null
                          : () => setState(() => _servicios.remove(s)),
                      deleteIconColor: Colors.redAccent,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _tagController,
                  decoration: InputDecoration(
                    hintText: "Ej: Encerado, Pulido...",
                    prefixIcon: const Icon(
                      Icons.add_circle_outline,
                      color: Color(0xFF3ABEF9),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onSubmitted: _addTag,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // --- SECCIÓN 2: UBICACIÓN GEOGRÁFICA ---
            _buildSectionCard(
              title: "Ubicación Geográfica",
              icon: Icons.map,
              children: [
                const Text(
                  "Toca el mapa para posicionar el marcador exacto",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 250,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: const Color(0xFF3ABEF9).withOpacity(0.3),
                    ),
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
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
            ),

            const SizedBox(height: 20),

            // --- SECCIÓN 3: REGISTRO BANCARIO ---
            _buildSectionCard(
              title: "Registro Bancario (Cobros)",
              icon: Icons.account_balance,
              children: [
                _buildField(
                  _bancoController,
                  "Nombre de Banco",
                  Icons.account_balance_wallet,
                ),
                const SizedBox(height: 15),
                _buildField(
                  _cuentaController,
                  "Cuenta Bancaria (CBU/Alias)",
                  Icons.credit_card,
                ),
              ],
            ),

            const SizedBox(height: 30),

            // --- BOTÓN DE GUARDADO ---
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 4,
              ),
              onPressed: _registrar,
              child: const Text(
                "GUARDAR CONFIGURACIÓN",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF3ABEF9), size: 22),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 30),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF3ABEF9), size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3ABEF9), width: 2),
        ),
      ),
    );
  }
}

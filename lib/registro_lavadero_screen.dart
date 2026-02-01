import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_dragmarker/flutter_map_dragmarker.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class RegistroLavaderoScreen extends StatefulWidget {
  const RegistroLavaderoScreen({super.key});

  @override
  State<RegistroLavaderoScreen> createState() => _RegistroLavaderoScreenState();
}

class _RegistroLavaderoScreenState extends State<RegistroLavaderoScreen> {
  // --- CONTROLADORES CORE ---
  final _nombreController = TextEditingController();
  final _direccionController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _bancoController = TextEditingController();
  final _cuentaController = TextEditingController();
  final _tagController = TextEditingController();
  final _precioController = TextEditingController();

  final supabase = Supabase.instance.client;
  final MapController _mapController = MapController();

  // --- ESTADO MANTENIDO ---
  Map<String, double> _preciosMap = {'Lavado': 0.0};
  final List<String> _servicios = [
    'Lavado',
    'Control de aire/ruedas',
    'Venta de insumos',
  ];
  TimeOfDay _horaApertura = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _horaCierre = const TimeOfDay(hour: 18, minute: 0);
  int _duracionTurno = 60;
  final Map<String, bool> _diasLaborales = {
    'Lun': true,
    'Mar': true,
    'Mie': true,
    'Jue': true,
    'Vie': true,
    'Sab': false,
    'Dom': false,
  };

  LatLng _puntoSeleccionado = const LatLng(-34.098, -59.028);
  String _mensajeUbicacion = "";
  bool _cargandoDireccion = false;

  // Paleta ATT! 2040
  final Color azulATT = const Color(0xFF3ABEF9);
  final Color rojoATT = const Color(0xFFEF4444);
  final Color fondoSoft = const Color(0xFFF0F4F8);

  // --- FUNCIONALIDAD DE DIRECCIÓN (MANTENIDA) ---
  Future<void> _obtenerDireccionDesdeCoords(LatLng coords) async {
    setState(() => _cargandoDireccion = true);
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${coords.latitude}&lon=${coords.longitude}&zoom=18&addressdetails=1',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'ATT_App_Web'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'];
        final String? road = address != null ? address['road'] : null;
        final String? houseNumber = address != null
            ? address['house_number']
            : null;
        final String? city = address != null
            ? (address['city'] ?? address['town'] ?? address['village'])
            : null;

        setState(() {
          if (road != null) {
            String fullAddress = "$road ${houseNumber ?? ''}".trim();
            _direccionController.text = fullAddress;
            _mensajeUbicacion =
                "✅ Dirección detectada: $fullAddress ${city != null ? '($city)' : ''}";
          } else {
            _mensajeUbicacion = "✅ Ubicación fijada manualmente";
          }
        });
      }
    } catch (e) {
      setState(() => _mensajeUbicacion = "✅ Ubicación fijada");
    } finally {
      setState(() => _cargandoDireccion = false);
    }
  }

  void _agregarServicioConPrecio() {
    final nombre = _tagController.text.trim();
    final precio = double.tryParse(_precioController.text) ?? 0.0;
    if (nombre.isNotEmpty && precio > 0) {
      setState(() {
        if (!_servicios.contains(nombre)) _servicios.add(nombre);
        _preciosMap[nombre] = precio;
        _tagController.clear();
        _precioController.clear();
      });
    }
  }

  Future<void> _registrar() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    if ((_preciosMap['Lavado'] ?? 0.0) <= 0) {
      _mostrarAlerta("⚠️ Debes asignar un precio al Lavado", rojoATT);
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
        'latitud': _puntoSeleccionado.latitude,
        'longitud': _puntoSeleccionado.longitude,
        'servicios': _servicios,
        'servicios_precios': _preciosMap,
        'hora_apertura': _horaApertura.format(context),
        'hora_cierre': _horaCierre.format(context),
        'duracion_estandar': _duracionTurno,
        'dias_abierto': _diasLaborales.entries
            .where((e) => e.value)
            .map((e) => e.key)
            .toList(),
      });
      if (mounted) {
        _mostrarAlerta("✅ Lavadero configurado con éxito", Colors.green);
        Navigator.pop(context);
      }
    } catch (e) {
      _mostrarAlerta("❌ Error al guardar: $e", rojoATT);
    }
  }

  void _mostrarAlerta(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool lavadoHabilitado = (_preciosMap['Lavado'] ?? 0.0) > 0;

    return Scaffold(
      backgroundColor: fondoSoft,
      body: CustomScrollView(
        slivers: [
          // HEADER BENTO 2040
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text(
                "CONFIGURACIÓN ATT!",
                style: TextStyle(
                  color: azulATT,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 1. DATOS DEL NEGOCIO
                _buildBentoCard(
                  title: "Datos del Lavadero",
                  icon: Icons.store_rounded,
                  children: [
                    _buildModernField(
                      _nombreController,
                      "Nombre Comercial",
                      Icons.badge_outlined,
                    ),
                    _buildModernField(
                      _direccionController,
                      "Dirección (detectada)",
                      Icons.location_on_outlined,
                      isReadOnly: true,
                      suffix: _cargandoDireccion
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                    ),
                    _buildModernField(
                      _telefonoController,
                      "Teléfono",
                      Icons.phone_android_rounded,
                      type: TextInputType.phone,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 2. MAPA INTERACTIVO (CON BOTONES RECUPERADOS)
                _buildBentoCard(
                  title: "Ubicación en el Mapa",
                  icon: Icons.map_rounded,
                  children: [
                    Stack(
                      children: [
                        Container(
                          height: 350,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.black.withOpacity(0.05),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: FlutterMap(
                              mapController: _mapController,
                              options: MapOptions(
                                initialCenter: _puntoSeleccionado,
                                initialZoom: 15,
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                ),
                                DragMarkers(
                                  markers: [
                                    DragMarker(
                                      point: _puntoSeleccionado,
                                      size: const Size(80, 80),
                                      offset: const Offset(0, -35),
                                      builder: (ctx, pos, isDragging) =>
                                          MouseRegion(
                                            cursor: isDragging
                                                ? SystemMouseCursors.grabbing
                                                : SystemMouseCursors
                                                      .grab, // <--- MANITO
                                            child: Icon(
                                              Icons.location_on,
                                              color: isDragging
                                                  ? azulATT
                                                  : rojoATT,
                                              size: 60,
                                            ),
                                          ),
                                      onDragEnd: (details, point) {
                                        setState(
                                          () => _puntoSeleccionado = point,
                                        );
                                        _obtenerDireccionDesdeCoords(point);
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        // --- BOTONES DE CONTROL FLOTANTES ---
                        Positioned(
                          right: 15,
                          bottom: 15,
                          child: Column(
                            children: [
                              _mapBtn(Icons.add_rounded, () {
                                _mapController.move(
                                  _mapController.camera.center,
                                  _mapController.camera.zoom + 1,
                                );
                              }, color: azulATT),
                              _mapBtn(Icons.remove_rounded, () {
                                _mapController.move(
                                  _mapController.camera.center,
                                  _mapController.camera.zoom - 1,
                                );
                              }, color: azulATT),
                              const SizedBox(height: 8),
                              _mapBtn(Icons.my_location_rounded, () {
                                _mapController.move(_puntoSeleccionado, 17);
                              }, color: rojoATT),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_mensajeUbicacion.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _mensajeUbicacion,
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // 3. SERVICIOS Y PRECIOS
                _buildBentoCard(
                  title: "Servicios y Precios",
                  icon: Icons.payments_rounded,
                  children: [
                    TextField(
                      keyboardType: TextInputType.number,
                      onChanged: (v) => setState(
                        () => _preciosMap['Lavado'] = double.tryParse(v) ?? 0.0,
                      ),
                      decoration: InputDecoration(
                        labelText: "Precio Lavado Básico *",
                        prefixIcon: const Icon(Icons.water_drop_rounded),
                        prefixText: "\$ ",
                        filled: true,
                        fillColor: fondoSoft.withOpacity(0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    if (!lavadoHabilitado)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          "⚠️ Define el precio base para habilitar extras",
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else ...[
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _servicios.map((s) {
                          final p = _preciosMap[s] ?? 0.0;
                          return Chip(
                            label: Text(
                              "$s: \$${p.toStringAsFixed(0)}",
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onDeleted: s == 'Lavado'
                                ? null
                                : () => setState(() => _servicios.remove(s)),
                            deleteIconColor: rojoATT,
                            backgroundColor: azulATT.withOpacity(0.1),
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          );
                        }).toList(),
                      ),
                      const Divider(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: _buildModernField(
                              _tagController,
                              "Nuevo Servicio",
                              Icons.add_box_rounded,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildModernField(
                              _precioController,
                              "Precio",
                              Icons.attach_money_rounded,
                              type: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: _agregarServicioConPrecio,
                            style: IconButton.styleFrom(
                              backgroundColor: azulATT,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                // 4. OPERACIÓN (HORARIOS)
                _buildBentoCard(
                  title: "Horarios y Jornada",
                  icon: Icons.history_toggle_off_rounded,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _timePickerBox(
                          "Apertura",
                          _horaApertura,
                          (t) => setState(() => _horaApertura = t),
                        ),
                        _timePickerBox(
                          "Cierre",
                          _horaCierre,
                          (t) => setState(() => _horaCierre = t),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "DÍAS LABORALES",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.black26,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      alignment: WrapAlignment.center,
                      children: _diasLaborales.keys.map((d) {
                        bool isSel = _diasLaborales[d]!;
                        return FilterChip(
                          label: Text(
                            d,
                            style: TextStyle(
                              color: isSel ? Colors.white : Colors.black87,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          selected: isSel,
                          onSelected: (v) =>
                              setState(() => _diasLaborales[d] = v),
                          selectedColor: azulATT,
                          checkmarkColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 5. BANCO
                _buildBentoCard(
                  title: "Cobros y Pagos",
                  icon: Icons.account_balance_rounded,
                  children: [
                    _buildModernField(
                      _bancoController,
                      "Nombre de Banco",
                      Icons.account_balance_wallet_rounded,
                    ),
                    _buildModernField(
                      _cuentaController,
                      "CBU o Alias",
                      Icons.credit_card_rounded,
                    ),
                  ],
                ),
              ]),
            ),
          ),
        ],
      ),

      // BOTÓN DE ACCIÓN GLASSMOPRHISM
      bottomSheet: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: lavadoHabilitado ? rojoATT : Colors.black12,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 65),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              elevation: 0,
            ),
            onPressed: lavadoHabilitado ? _registrar : null,
            child: const Text(
              "FINALIZAR CONFIGURACIÓN",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
            ),
          ),
        ),
      ),
    );
  }

  // --- COMPONENTES BENTO AUXILIARES ---

  Widget _buildBentoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: azulATT),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Colors.black38,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildModernField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
    bool isReadOnly = false,
    Widget? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: type,
        readOnly: isReadOnly,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 18, color: azulATT.withOpacity(0.5)),
          suffixIcon: suffix,
          filled: true,
          fillColor: fondoSoft.withOpacity(0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: azulATT, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _timePickerBox(
    String label,
    TimeOfDay time,
    Function(TimeOfDay) onSelect,
  ) {
    return MouseRegion(
      // <--- PASO A: AGREGÁS ESTO
      cursor: SystemMouseCursors.click, // <--- PASO B: ACTIVÁS LA MANITO
      child: InkWell(
        onTap: () async {
          final p = await showTimePicker(context: context, initialTime: time);
          if (p != null) onSelect(p);
        },
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Colors.black26,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: azulATT.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                time.format(context),
                style: TextStyle(
                  color: azulATT,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    ); // <--- PASO C: CERRÁS EL MOUSEREGION ACÁ
  }

  // --- BOTONES FACHEROS CON MANITO :) ---
  Widget _mapBtn(
    IconData icon,
    VoidCallback onTap, {
    Color color = Colors.black87,
  }) {
    return MouseRegion(
      // <--- AGREGÁS ESTA LÍNEA
      cursor: SystemMouseCursors.click, // <--- ESTO ACTIVA LA MANITO
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.black.withOpacity(0.05)),
          ),
          child: Icon(icon, size: 22, color: color),
        ),
      ),
    ); // <--- CERRÁS EL MOUSEREGION ACÁ
  }
}

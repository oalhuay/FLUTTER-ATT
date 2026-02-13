import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_dragmarker/flutter_map_dragmarker.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:image_picker/image_picker.dart';

class RegistroLavaderoScreen extends StatefulWidget {
  final Map<String, dynamic>?
  lavaderoParaEditar; // Recibe datos si vamos a editar
  final VoidCallback? onVolver; // <--- AGREGAMOS ESTO
  const RegistroLavaderoScreen({
    super.key,
    this.lavaderoParaEditar,
    this.onVolver,
  });
  @override
  State<RegistroLavaderoScreen> createState() => _RegistroLavaderoScreenState();
}

class _RegistroLavaderoScreenState extends State<RegistroLavaderoScreen> {
  @override
  void initState() {
    super.initState();

    // Si recibimos un lavadero, precargamos todos los controladores
    if (widget.lavaderoParaEditar != null) {
      final l = widget.lavaderoParaEditar!;

      _nombreController.text = l['razon_social'] ?? '';
      _direccionController.text = l['direccion'] ?? '';
      _telefonoController.text = l['telefono'] ?? '';
      _bancoController.text = l['nombre_banco'] ?? '';
      _cuentaController.text = l['cuenta_bancaria'] ?? '';
      _fotoUrlTemporal = l['foto_url'];

      // 1. Sincronizamos la ubicación del mapa
      if (l['latitud'] != null && l['longitud'] != null) {
        _puntoSeleccionado = LatLng(
          (l['latitud'] as num).toDouble(),
          (l['longitud'] as num).toDouble(),
        );
      }

      // 2. Sincronizamos Precios y Servicios desde Supabase
      if (l['servicios_precios'] != null) {
        // Limpiamos cualquier sugerencia previa para que solo quede lo de DB
        _preciosMap.clear();
        _servicios.clear();

        Map<String, dynamic> data = Map<String, dynamic>.from(
          l['servicios_precios'],
        );

        data.forEach((k, v) {
          String nombre = k.toString();
          double precio = (v as num).toDouble();

          _preciosMap[nombre] = precio;

          // Agregamos a la lista de servicios solo si no es el base "Lavado"
          // para que no se duplique en el Wrap de etiquetas
          if (nombre != "Lavado") {
            _servicios.add(nombre);
          }
        });
      }
    }
  }

  // --- CONTROLADORES CORE ---
  String? _fotoUrlTemporal;
  bool _subiendoImagen = false;

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
  final Map<String, double> _preciosMap = {'Lavado': 0.0};
  final List<String> _servicios = [
    'Lavado',
    'Control de aire/ruedas',
    'Venta de insumos',
  ];
  TimeOfDay _horaApertura = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _horaCierre = const TimeOfDay(hour: 18, minute: 0);
  final int _duracionTurno = 60;
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
  bool _esManual = false;
  List<dynamic> _sugerencias = [];
  bool _buscandoSugerencias = false;
  Timer? _debounce;
  // Paleta ATT! 2040
  final Color azulATT = const Color(0xFF3ABEF9);
  final Color rojoATT = const Color(0xFFEF4444);
  final Color fondoSoft = const Color(0xFFF0F4F8);

  // --- FUNCIONALIDAD DE DIRECCIÓN (MANTENIDA) ---
  Future<void> _obtenerDireccionDesdeCoords(LatLng coords) async {
    setState(() {
      _cargandoDireccion = true;
      // Al mover el mapa, reseteamos a modo detección
    });

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
            // Confirmamos que es detectada
            _mensajeUbicacion =
                "✅ Dirección detectada: $fullAddress ${city != null ? '($city)' : ''}";
          } else {
            _mensajeUbicacion = "📍 Ubicación fijada en el mapa";
          }
        });
      }
    } catch (e) {
      setState(() => _mensajeUbicacion = "✅ Ubicación fijada");
    } finally {
      setState(() => _cargandoDireccion = false);
    }
  }

  Future<void> _buscarDireccionManual(String query) async {
    if (query.length < 3) return; // Bajamos a 3 caracteres para más agilidad

    setState(() => _buscandoSugerencias = true);

    // Coordenadas aproximadas de Zárate para dar prioridad (Bounded box)
    // [Lat min, Lon min, Lat max, Lon max]
    const viewbox = "-59.13,-34.15,-58.98,-34.05";

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query)}'
        '&format=json'
        '&limit=5'
        '&countrycodes=ar' // <--- LIMITA SOLO A ARGENTINA
        '&viewbox=$viewbox' // <--- PRIORIZA TU CIUDAD
        '&bounded=0' // Ponemos 0 para que si no encuentra en Zárate, busque en el resto de AR
        '&addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'ATT_App_Zarate'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _sugerencias = json.decode(response.body);
        });
      }
    } catch (e) {
      debugPrint("Error en búsqueda: $e");
    } finally {
      setState(() => _buscandoSugerencias = false);
    }
  }


  Future<void> _elegirYSubirFoto() async {
    final picker = ImagePicker();
    // 1. El dueño elige la imagen
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80, // Comprimimos un poco desde el celu
    );

    if (image == null) return;

    setState(() => _subiendoImagen = true);

    try {
      // 2. Preparamos la petición POST a Cloudinary
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.cloudinary.com/v1_1/dcmz8zzln/image/upload'),
      );

      request.fields['upload_preset'] =
          'preset_lavaderos'; // El que creaste hoy

      var bytes = await image.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: image.name),
      );

      var response = await request.send();
      var responseData = await response.stream.toBytes();
      var jsonResponse = jsonDecode(String.fromCharCodes(responseData));

      if (response.statusCode == 200) {
        setState(() {
          _fotoUrlTemporal = jsonResponse['secure_url'];
        });
        _mostrarAlerta("📸 Foto cargada correctamente", Colors.green);
      } else {
        _mostrarAlerta(
          "❌ Error Cloudinary: ${jsonResponse['error']['message']}",
          rojoATT,
        );
      }
    } catch (e) {
      _mostrarAlerta("❌ Error al conectar con la nube: $e", rojoATT);
    } finally {
      setState(() => _subiendoImagen = false);
    }
  }

  Future<void> _registrar() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    if ((_preciosMap['Lavado'] ?? 0.0) <= 0) {
      _mostrarAlerta("⚠️ Debes asignar un precio al Lavado", rojoATT);
      return;
    }

    // Preparamos el paquete de datos
    final datosLavadero = {
      'dueño_id': user.id,
      'razon_social': _nombreController.text,
      'foto_url': _fotoUrlTemporal,
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
    };

    try {
      if (widget.lavaderoParaEditar != null) {
        // --- MODO EDICIÓN: UPDATE ---
        await supabase
            .from('lavaderos')
            .update(datosLavadero)
            .eq('id', widget.lavaderoParaEditar!['id']);
        _mostrarAlerta("✨ Datos actualizados correctamente", Colors.green);
      } else {
        // --- MODO NUEVO: INSERT ---
        await supabase.from('lavaderos').insert(datosLavadero);
        _mostrarAlerta("✅ Lavadero registrado con éxito", Colors.green);
      }

      if (mounted) {
        if (widget.onVolver != null) {
          widget.onVolver!(); // Vuelve al mapa manteniendo el sidebar
        } else {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      _mostrarAlerta("❌ Error al procesar: $e", rojoATT);
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
    String? servicioEnEdicion;

    return Scaffold(
      backgroundColor: fondoSoft,
      body: CustomScrollView(
        slivers: [
          // HEADER BENTO 2040
          // HEADER BENTO 2040 CON FLECHA AZUL
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.white,
            // --- AQUÍ ESTÁ TU FLECHA AZUL ATT ---
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Color(0xFF3ABEF9), // Azul ATT!
                size: 20,
              ),
              onPressed: () {
                // Si le pasamos la función de volver, la ejecuta
                if (widget.onVolver != null) {
                  widget.onVolver!();
                } else {
                  // Por las dudas, si no hay callback, hace el pop normal
                  Navigator.pop(context);
                }
              },
            ),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text(
                "CONFIGURACIÓN ATT!",
                style: TextStyle(
                  color: azulATT,
                  fontWeight: FontWeight.w900,
                  fontSize:
                      14, // Bajamos un punto para que no choque con la flecha
                  letterSpacing: 2,
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // --- SECCIÓN: SUBIDA DE FOTO BENTO ---
                _buildBentoCard(
                  title: "Imagen del Lavadero",
                  icon: Icons.camera_alt_rounded,
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: _subiendoImagen ? null : _elegirYSubirFoto,
                        child: Container(
                          height: 180,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: fondoSoft,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: azulATT.withOpacity(0.1),
                              width: 2,
                            ),
                            image: _fotoUrlTemporal != null
                                ? DecorationImage(
                                    image: NetworkImage(_fotoUrlTemporal!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: _subiendoImagen
                              ? const Center(child: CircularProgressIndicator())
                              : _fotoUrlTemporal == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.cloud_upload_outlined,
                                      size: 40,
                                      color: azulATT,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      "TOCA PARA SUBIR FOTO",
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: azulATT,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

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

                    // --- SECCIÓN DE DIRECCIÓN CON AUTOCOMPLETADO POR ETIQUETAS ---
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildModernField(
                          _direccionController,
                          "Dirección ${_esManual ? '(Manual)' : '(Detectada)'}",
                          Icons.location_on_outlined,
                          hint: "Ejemplo: 1225 Juan B. Justo",
                          isReadOnly: false,
                          onChanged: (valor) {
                            setState(() => _esManual = true);

                            // Lógica de Debounce: espera 500ms después de que el usuario deja de escribir
                            if (_debounce?.isActive ?? false) {
                              _debounce!.cancel();
                            }
                            _debounce = Timer(
                              const Duration(milliseconds: 500),
                              () {
                                if (valor.trim().isNotEmpty) {
                                  _buscarDireccionManual(valor);
                                } else {
                                  setState(
                                    () => _sugerencias = [],
                                  ); // Limpia si borra todo
                                }
                              },
                            );
                          },
                          onSubmitted: (valor) {
                            setState(() {
                              _esManual = true;
                              _mensajeUbicacion =
                                  "✅ Ubicación fijada manualmente";
                              _sugerencias =
                                  []; // Limpia sugerencias al dar enter
                            });
                          },
                          suffix: _cargandoDireccion || _buscandoSugerencias
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : _esManual
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.refresh_rounded,
                                    color: Colors.orange,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    _obtenerDireccionDesdeCoords(
                                      _puntoSeleccionado,
                                    );
                                  },
                                  tooltip: "Volver a detectar por GPS",
                                )
                              : null,
                        ),
                        // ETIQUETAS DE AUTOCOMPLETADO (Chips)
                        if (_sugerencias.isNotEmpty && _esManual)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12, left: 4),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _sugerencias.map((lugar) {
                                return ActionChip(
                                  backgroundColor: azulATT.withOpacity(0.1),
                                  side: BorderSide(
                                    color: azulATT.withOpacity(0.1),
                                  ),
                                  label: Text(
                                    // Esta lógica toma solo la primera parte (calle y altura)
                                    // y le suma la ciudad si es que no es Zárate para diferenciar.
                                    _limpiarNombreLugar(lugar),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: azulATT,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onPressed: () {
                                    final lat = double.parse(lugar['lat']);
                                    final lon = double.parse(lugar['lon']);
                                    final nuevaPos = LatLng(lat, lon);

                                    setState(() {
                                      _puntoSeleccionado = nuevaPos;
                                      _direccionController.text =
                                          lugar['display_name'];
                                      _sugerencias = [];
                                      _esManual = false;
                                      _mensajeUbicacion =
                                          "✅ Ubicación seleccionada del buscador";
                                    });

                                    _mapController.move(nuevaPos, 17);
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                      ],
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

                // 2. MAPA INTERACTIVO
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
                                onTap: (tapPosition, point) {
                                  setState(() => _puntoSeleccionado = point);
                                  _obtenerDireccionDesdeCoords(point);
                                },
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
                                      // --- EL REMEDIO SANTO ---
                                      // Al usar topCenter, le decimos a Flutter que el "anclaje" al mapa
                                      // no sea el medio del cuadrado, sino la parte superior.
                                      // Esto empuja toda la caja hacia arriba de forma natural.
                                      alignment: Alignment.topCenter,
                                      builder: (ctx, pos, isDragging) {
                                        return MouseRegion(
                                          cursor: isDragging
                                              ? SystemMouseCursors.grabbing
                                              : SystemMouseCursors.click,
                                          child: Icon(
                                            Icons.location_on,
                                            color: isDragging
                                                ? azulATT
                                                : rojoATT,
                                            size:
                                                80, // Ocupa todo el Size para que el área de clic sea perfecta
                                          ),
                                        );
                                      },
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

                // 3. SECCIÓN: SERVICIOS Y PRECIOS (DINÁMICO)
                _buildBentoCard(
                  title: "Servicios y Precios",
                  icon: Icons.payments_rounded,
                  children: [
                    // CAMPO 1: PRECIO LAVADO BÁSICO (SERVICIO BASE)
                    TextField(
                      keyboardType: TextInputType.number,
                      controller: TextEditingController(
                        // Usamos ?? "" para que si es null, el campo simplemente aparezca vacío
                        text: _preciosMap['Lavado']?.toStringAsFixed(0) ?? "",
                      ),
                      onChanged: (v) => setState(() {
                        _preciosMap['Lavado'] = double.tryParse(v) ?? 0.0;
                        // El servicio "Lavado" siempre debe estar en la lista de servicios para la DB
                        if (!_servicios.contains('Lavado')) {
                          // No lo agregamos a la lista visual de etiquetas, pero sí al mapa de datos
                        }
                      }),
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

                      // WRAP DE ETIQUETAS DINÁMICAS (Solo servicios adicionales)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _servicios.where((s) => s != 'Lavado').map((
                          s,
                        ) {
                          final p = _preciosMap[s] ?? 0.0;
                          final esEditandoEste = servicioEnEdicion == s;

                          return InputChip(
                            label: Text(
                              "$s: \$${p.toStringAsFixed(0)}",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: esEditandoEste
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                            // AL HACER CLIC: Cargamos los datos en los campos de edición abajo
                            onPressed: () {
                              setState(() {
                                servicioEnEdicion = s;
                                _tagController.text = s;
                                _precioController.text = p.toStringAsFixed(0);
                              });
                            },
                            onDeleted: () => setState(() {
                              _servicios.remove(s);
                              _preciosMap.remove(s);
                              if (servicioEnEdicion == s)
                                servicioEnEdicion = null;
                            }),
                            deleteIconColor: esEditandoEste
                                ? Colors.white
                                : rojoATT,
                            backgroundColor: esEditandoEste
                                ? azulATT
                                : azulATT.withOpacity(0.1),
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          );
                        }).toList(),
                      ),

                      const Divider(height: 32),

                      // FILA DE EDICIÓN / AGREGAR
                      Row(
                        children: [
                          Expanded(
                            child: _buildModernField(
                              _tagController,
                              "Servicio",
                              Icons.edit_attributes_rounded,
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

                          // BOTÓN DINÁMICO (CHECK O ADD)
                          IconButton.filled(
                            onPressed: () {
                              if (_tagController.text.isEmpty ||
                                  _precioController.text.isEmpty)
                                return;

                              setState(() {
                                String nombre = _tagController.text;
                                double precio =
                                    double.tryParse(_precioController.text) ??
                                    0.0;

                                if (servicioEnEdicion != null) {
                                  // MODO EDICIÓN: Limpiamos el anterior y actualizamos
                                  if (servicioEnEdicion != nombre) {
                                    _preciosMap.remove(servicioEnEdicion);
                                    int index = _servicios.indexOf(
                                      servicioEnEdicion!,
                                    );
                                    _servicios[index] = nombre;
                                  }
                                } else {
                                  // MODO AGREGAR: Solo si no existe
                                  if (!_servicios.contains(nombre)) {
                                    _servicios.add(nombre);
                                  }
                                }

                                _preciosMap[nombre] = precio;

                                // Reset de campos
                                servicioEnEdicion = null;
                                _tagController.clear();
                                _precioController.clear();
                              });
                            },
                            style: IconButton.styleFrom(
                              backgroundColor: servicioEnEdicion != null
                                  ? Colors.green
                                  : azulATT,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: Icon(
                              servicioEnEdicion != null
                                  ? Icons.check_rounded
                                  : Icons.add_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),

                      // OPCIÓN DE CANCELAR EDICIÓN
                      if (servicioEnEdicion != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: TextButton(
                            onPressed: () => setState(() {
                              servicioEnEdicion = null;
                              _tagController.clear();
                              _precioController.clear();
                            }),
                            child: const Text(
                              "Cancelar edición",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ),
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
            child: Text(
              widget.lavaderoParaEditar != null
                  ? "GUARDAR CAMBIOS"
                  : "FINALIZAR CONFIGURACIÓN",
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
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
    String? hint,
    Function(String)? onChanged, // Agregar esto
    Function(String)? onSubmitted, // Agregar esto
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: type,
        readOnly: isReadOnly,
        onChanged: onChanged, // Vincular
        onSubmitted: onSubmitted, // Vincular
        onTapOutside: (event) => FocusManager.instance.primaryFocus
            ?.unfocus(), // Cierra teclado al tocar fuera
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 18, color: azulATT.withOpacity(0.5)),
          suffixIcon: suffix,
          hintText: hint,
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

  String _limpiarNombreLugar(dynamic lugar) {
    var nombreCompleto = lugar['display_name'].toString();
    var partes = nombreCompleto.split(',');

    // Si tiene calle y altura, solemos querer los primeros dos elementos
    if (partes.length > 1) {
      return "${partes[0].trim()} ${partes[1].trim()}".length > 25
          ? partes[0].trim()
          : "${partes[0].trim()} ${partes[1].trim()}";
    }
    return partes[0];
  }
}

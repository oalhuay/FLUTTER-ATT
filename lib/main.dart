import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'reserva_screen.dart';
import 'splash_screen.dart';
import 'mis_turnos_screen.dart';
import 'registro_lavadero_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ESTA ES LA LÍNEA CLAVE: Inicializa los nombres de días y meses en español
  await initializeDateFormatting('es', null);

  await Supabase.initialize(
    url: 'https://oaudxvhroedmtpwrityk.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9hdWR4dmhyb2VkbXRwd3JpdHlrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwOTczMzQsImV4cCI6MjA4MzY3MzMzNH0.qj1sJFu_GSs-T656E6iyIMnSwYYZlTsQpb8Ke3OgZek',
  );

  runApp(const MyApp());
}

final supabase = Supabase.instance.client;
final GlobalKey<_MapScreenState> mapScreenKey = GlobalKey<_MapScreenState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'AR'), // Español Argentina
        Locale('en', 'US'), // Inglés por si las dudas
      ],
      locale: const Locale('es', 'AR'), // Forzamos el idioma
      // ... resto de tu código
      debugShowCheckedModeBanner: false,
      title: 'ATT!: A Todo Trapo',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3ABEF9),
          primary: const Color(0xFFEF4444),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

// --- PANTALLA DE SELECCIÓN DE ROL ---
class SeleccionRolScreen extends StatefulWidget {
  const SeleccionRolScreen({super.key});

  @override
  State<SeleccionRolScreen> createState() => _SeleccionRolScreenState();
}

class _SeleccionRolScreenState extends State<SeleccionRolScreen> {
  bool _procesando = false;

  Future<void> _definirRol(String nuevoRol) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _procesando = true);
    try {
      await supabase.from('perfiles_usuarios').upsert({
        'id': user.id,
        'rol': nuevoRol,
        'email': user.email,
      });

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainLayout()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _procesando = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(30),
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.directions_car_filled,
              size: 80,
              color: Color(0xFF3ABEF9),
            ),
            const SizedBox(height: 20),
            const Text(
              "¡Bienvenido a ATT!\n¿Cómo quieres usar la App?",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            if (_procesando)
              const CircularProgressIndicator()
            else ...[
              _botonRol("QUIERO LAVAR MI AUTO", Icons.person, 'cliente'),
              const SizedBox(height: 20),
              _botonRol("SOY DUEÑO DE LAVADERO", Icons.store, 'lavadero'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _botonRol(String texto, IconData icono, String valor) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: valor == 'cliente'
              ? const Color(0xFF3ABEF9)
              : Colors.blueGrey,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        icon: Icon(icono),
        label: Text(texto, style: const TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _definirRol(valor),
      ),
    );
  }
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _indiceActual = 0;
  bool _sidebarAbierto = true;
  dynamic _lavaderoSeleccionado;
  bool _filtroPrecio = false;
  bool _filtroRating = false;
  bool _filtroDistancia = false;
  void _aplicarOrdenamiento() {
    setState(() {
      if (_filtroPrecio) {
        // Asumiendo un precio base de 2500 o el que traiga el objeto
        _lavaderosFiltrados.sort(
          (a, b) => (a['precio'] ?? 2500).compareTo(b['precio'] ?? 2500),
        );
      }
      if (_filtroRating) {
        // Ordena de mayor a menor rating
        _lavaderosFiltrados.sort(
          (a, b) => (b['rating'] ?? 0.0).compareTo(a['rating'] ?? 0.0),
        );
      }
      if (_filtroDistancia) {
        // Aquí podrías usar la lógica de Haversine que mencionamos antes
        // Por ahora ordenamos por un campo 'distancia' ficticio o real
        _lavaderosFiltrados.sort(
          (a, b) => (a['distancia'] ?? 0.0).compareTo(b['distancia'] ?? 0.0),
        );
      }
    });
  }

  // --- LAS LÍNEAS NUEVAS EMPIEZAN AQUÍ ---
  String _rolUsuario = 'pendiente'; // Variable para saber si es dueño o cliente
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _todosLosLavaderos = []; // Lista maestra
  List<dynamic> _lavaderosFiltrados = []; // Lo que se ve en el mapa
  List<dynamic> _obtenerListaOrdenada() {
    List<dynamic> lista = List.from(_lavaderosFiltrados);

    // Aplicamos los criterios (se pueden combinar)
    lista.sort((a, b) {
      int cmp = 0;

      // 1. Prioridad: Distancia (si está activo)
      if (_filtroDistancia) {
        // Por ahora comparamos latitud como simulacro de distancia
        cmp = a['latitud'].compareTo(b['latitud']);
        if (cmp != 0) return cmp;
      }

      // 2. Prioridad: Rating (Suponiendo que tienes un campo 'rating')
      if (_filtroRating) {
        double ratingA = (a['rating'] ?? 0.0).toDouble();
        double ratingB = (b['rating'] ?? 0.0).toDouble();
        cmp = ratingB.compareTo(ratingA); // De mayor a menor
        if (cmp != 0) return cmp;
      }

      // 3. Prioridad: Precio
      if (_filtroPrecio) {
        // Simulacro: comparamos por ID para variar el orden hasta que tengas 'precio' en DB
        cmp = a['id'].compareTo(b['id']);
      }

      return cmp;
    });

    return lista.take(5).toList(); // Mantenemos tu límite de 5 tarjetas rápidas
  }

  @override
  void initState() {
    super.initState();
    _obtenerRolActual();

    supabase.auth.onAuthStateChange.listen((data) {
      if (mounted) {
        _obtenerRolActual();

        // --- AGREGAMOS ESTA LÓGICA DE LIMPIEZA ---
        // Si el usuario es nulo (cerró sesión), limpiamos la selección
        if (supabase.auth.currentUser == null) {
          setState(() {
            _lavaderoSeleccionado = null;
          });
        } else {
          setState(() {});
        }
      }
    });
  }

  Widget _buildContenidoPanelDerecho() {
    // CASO 1: Si es Dueño de Lavadero -> Siempre ve el panel de edición si hay algo seleccionado
    if (_rolUsuario == 'lavadero') {
      return _buildPanelInformacion();
    }

    // CASO 2: Si es Cliente -> Ve resultados de búsqueda o el detalle para reservar
    if (_rolUsuario == 'cliente') {
      // Si ya tocó un lavadero específico, vemos el detalle para que pueda "Solicitar Turno"
      if (_lavaderoSeleccionado != null) {
        return _buildPanelInformacion();
      }
      // Si no seleccionó nada pero está buscando, vemos las tarjetitas
      return _buildResultadosBusqueda();
    }

    // Por defecto (si el rol es pendiente o desconocido)
    return const Center(child: CircularProgressIndicator());
  }

  Future<void> _obtenerRolActual() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      final data = await supabase
          .from('perfiles_usuarios')
          .select('rol')
          .eq('id', user.id)
          .maybeSingle();
      if (data != null && mounted) {
        setState(() => _rolUsuario = data['rol'] ?? 'pendiente');
      }
    }
  }

  void _filtrarBusqueda(String query) {
    final input = query.trim().toLowerCase();

    setState(() {
      // 1. Creamos una lista temporal con las coincidencias de texto
      Iterable<dynamic> coincidencias;
      if (input.isEmpty) {
        coincidencias = _todosLosLavaderos;
      } else {
        coincidencias = _todosLosLavaderos.where((l) {
          final nombre = (l['razon_social'] ?? '').toString().toLowerCase();
          final direccion = (l['direccion'] ?? '').toString().toLowerCase();
          return nombre.contains(input) || direccion.contains(input);
        });
      }

      // 2. Evitamos duplicados en la lista de resultados
      _lavaderosFiltrados = _deduplicarLavaderos(coincidencias.toList());

      // 3. Actualizamos los markers del mapa
      mapScreenKey.currentState?.actualizarMarkersExternos(_lavaderosFiltrados);
    });
  }

  List<dynamic> _deduplicarLavaderos(List<dynamic> lista) {
    final Map<String, dynamic> unicos = {};
    for (final l in lista) {
      final id = l['id'];
      final String key;
      if (id != null) {
        key = 'id:$id';
      } else {
        final nombre = (l['razon_social'] ?? '').toString().toLowerCase();
        final direccion = (l['direccion'] ?? '').toString().toLowerCase();
        final lat = (l['latitud'] ?? '').toString();
        final lon = (l['longitud'] ?? '').toString();
        key = 'txt:$nombre|$direccion|$lat|$lon';
      }
      unicos.putIfAbsent(key, () => l);
    }
    return unicos.values.toList();
  }

  // Controladores para poder editar el texto en el panel derecho
  final TextEditingController _nombreCtrl = TextEditingController();
  final TextEditingController _direccionCtrl = TextEditingController();
  Widget _buildResultadosBusqueda() {
    if (_searchController.text.isEmpty) {
      return const Center(child: Text("Busca un lavadero para ver resultados"));
    }

    if (_lavaderosFiltrados.isEmpty) {
      return const Center(child: Text("No se encontraron resultados"));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- BOTONES DE FILTRADO (ETIQUETAS) ---
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 10, 15, 15),
          child: Wrap(
            spacing: 8,
            children: [
              _buildEtiquetaFiltro(
                "Menor Precio",
                Icons.payments_outlined,
                _filtroPrecio,
                () {
                  setState(() => _filtroPrecio = !_filtroPrecio);
                },
              ),
              _buildEtiquetaFiltro(
                "Mejor Rating",
                Icons.star_outline,
                _filtroRating,
                () {
                  setState(() => _filtroRating = !_filtroRating);
                },
              ),
              _buildEtiquetaFiltro(
                "Más Cerca",
                Icons.near_me_outlined,
                _filtroDistancia,
                () {
                  setState(() => _filtroDistancia = !_filtroDistancia);
                },
              ),
            ],
          ),
        ),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            "RESULTADOS",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              fontSize: 10,
            ),
          ),
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: _obtenerListaOrdenada()
                .length, // Usamos la nueva función de orden
            itemBuilder: (context, index) {
              final l = _obtenerListaOrdenada()[index];
              return _buildTargetaBusqueda(l);
            },
          ),
        ),
      ],
    );
  }

  // Widget auxiliar para las etiquetas
  Widget _buildEtiquetaFiltro(
    String texto,
    IconData icono,
    bool activo,
    VoidCallback onTap,
  ) {
    return FilterChip(
      label: Text(
        texto,
        style: TextStyle(
          fontSize: 11,
          color: activo ? Colors.white : Colors.black87,
        ),
      ),
      avatar: Icon(
        icono,
        size: 16,
        color: activo ? Colors.white : const Color(0xFF3ABEF9),
      ),
      selected: activo,
      onSelected: (_) => onTap(),
      selectedColor: const Color(0xFF3ABEF9),
      checkmarkColor: Colors.white,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: activo ? Colors.transparent : Colors.black12),
      ),
    );
  }

  Widget _buildTargetaBusqueda(dynamic l) {
    return GestureDetector(
      onTap: () {
        setState(() => _lavaderoSeleccionado = l);
        mapScreenKey.currentState?.moverAMarcador(
          LatLng(l['latitud'], l['longitud']),
        );
      },
      child: Container(
        height: 120,
        margin: const EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          image: DecorationImage(
            image: NetworkImage(
              'https://picsum.photos/seed/${l['id']}/400/200',
            ),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.4),
              BlendMode.darken,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l['razon_social'],
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l['direccion'] ?? 'Zárate',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3ABEF9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "\$2500",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> get _paginas {
    return [
      MapScreen(
        key: mapScreenKey,
        onIrAPerfil: () => setState(() => _indiceActual = 2),
        onSelectLavadero: (l) => setState(() => _lavaderoSeleccionado = l),
        onDeselccionar: () => setState(() => _lavaderoSeleccionado = null),
        // --- CAPTURAMOS LOS DATOS AQUÍ ---
        onLavaderosCargados: (lista) {
          setState(() {
            _todosLosLavaderos = _deduplicarLavaderos(
              List.from(lista),
            ); // Copia limpia
            _lavaderosFiltrados = List.from(_todosLosLavaderos);
          });
        },
      ),
      MisTurnosScreen(onVolver: () => setState(() => _indiceActual = 0)),
      PerfilScreen(onVolver: () => setState(() => _indiceActual = 0)),
      // --- NUEVA PANTALLA AQUÍ ---
      _buildPantallaMisClientes(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Usamos MediaQuery para saber si la pantalla es de móvil/tablet
    final bool esMovil = MediaQuery.of(context).size.width < 950;

    return Scaffold(
      // 1. EL DRAWER: Solo se activa en pantallas chicas
      drawer: esMovil
          ? Drawer(
              backgroundColor: const Color(0xFF1E1E2D),
              child:
                  _buildContenidoSidebar(), // Esta función contendrá el logo y botones
            )
          : null,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Umbral para el panel derecho fijo
          bool esPantallaChica = constraints.maxWidth < 1100;

          return Row(
            children: [
              // COLUMNA 1: SIDEBAR ANIMADO (Ahora sí se desliza real hacia la izquierda)
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOutQuart,
                // El ancho cambia de 250 a 0, activando el efecto de deslizamiento
                width: (!esMovil && _sidebarAbierto) ? 250 : 0,
                child: ClipRect(
                  child: OverflowBox(
                    minWidth: 250,
                    maxWidth: 250,
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 250,
                      color: const Color(0xFF1E1E2D),
                      child: Stack(
                        children: [
                          _buildContenidoSidebar(),
                          // BOTÓN DE CERRAR (X) A LA IZQUIERDA
                          Positioned(
                            top: 10,
                            left: 10,
                            child: IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white60,
                                size: 22,
                              ),
                              onPressed: () =>
                                  setState(() => _sidebarAbierto = false),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // COLUMNA 2: CONTENIDO CENTRAL (Se expande automáticamente)
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      color: const Color(0xFFF5F7F9),
                      child: IndexedStack(
                        index: _indiceActual == 100 ? 3 : _indiceActual,
                        children: _paginas,
                      ),
                    ),

                    // --- BOTÓN PARA VOLVER A MOSTRAR EL SIDEBAR (Animado con la barra) ---
                    if (!esMovil && _indiceActual == 0)
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOutQuart,
                        top: 20,
                        // Si está abierto o NO estamos en el mapa, lo escondemos a la izquierda
                        left: (_sidebarAbierto || _indiceActual != 0)
                            ? -60
                            : 15,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFF1E1E2D),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black26, blurRadius: 5),
                            ],
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.chevron_right,
                              color: Colors.white,
                            ),
                            onPressed: () =>
                                setState(() => _sidebarAbierto = true),
                            tooltip: "Mostrar menú",
                          ),
                        ),
                      ),

                    // --- BARRA SUPERIOR INTEGRADA (AnimatedPositioned para que el margen sea fluido) ---
                    // --- BARRA SUPERIOR INTEGRADA (Buscador + Resultados) ---
                    if (_indiceActual == 0)
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOutQuart,
                        top: 20,
                        left: esMovil ? 20 : (_sidebarAbierto ? 20 : 65),
                        right: 20,
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start, // Alinea arriba
                          children: [
                            // Botón Menú (Solo móvil)
                            if (esMovil)
                              Builder(
                                builder: (context) => Container(
                                  margin: const EdgeInsets.only(right: 10),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.menu,
                                      color: Color(0xFF1E1E2D),
                                    ),
                                    onPressed: () =>
                                        Scaffold.of(context).openDrawer(),
                                  ),
                                ),
                              ),

                            // --- BUSCADOR CON LISTA DE RESULTADOS ---
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Cuadro de texto
                                  Container(
                                    height: 45,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius:
                                          _searchController.text.isNotEmpty &&
                                              _lavaderosFiltrados.isNotEmpty
                                          ? const BorderRadius.vertical(
                                              top: Radius.circular(8),
                                            )
                                          : BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                    child: TextField(
                                      controller: _searchController,
                                      onChanged: _filtrarBusqueda,
                                      decoration: InputDecoration(
                                        hintText: "Search lavadero...",
                                        prefixIcon: const Icon(
                                          Icons.search,
                                          color: Colors.grey,
                                          size: 20,
                                        ),
                                        suffixIcon:
                                            _searchController.text.isNotEmpty
                                            ? IconButton(
                                                icon: const Icon(
                                                  Icons.clear,
                                                  size: 18,
                                                ),
                                                onPressed: () {
                                                  setState(() {
                                                    _searchController.clear();
                                                    _filtrarBusqueda('');
                                                  });
                                                },
                                              )
                                            : null,
                                        border: InputBorder.none,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              vertical: 10,
                                            ),
                                      ),
                                    ),
                                  ),

                                  // Lista de resultados (Flotante)
                                  if (_searchController.text.isNotEmpty &&
                                      _lavaderosFiltrados.isNotEmpty &&
                                      !(_lavaderosFiltrados.length == 1 &&
                                          _lavaderosFiltrados[0]['razon_social'] ==
                                              _searchController.text))
                                    Container(
                                      constraints: const BoxConstraints(
                                        maxHeight: 250,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              bottom: Radius.circular(12),
                                            ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.1,
                                            ),
                                            blurRadius: 10,
                                            offset: const Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: ListView.separated(
                                        padding: EdgeInsets.zero,
                                        shrinkWrap: true,
                                        itemCount: _lavaderosFiltrados.length,
                                        separatorBuilder: (_, __) =>
                                            const Divider(height: 1),
                                        itemBuilder: (context, index) {
                                          final l = _lavaderosFiltrados[index];
                                          return ListTile(
                                            dense: true,
                                            leading: const Icon(
                                              Icons.location_on,
                                              color: Color(0xFF3ABEF9),
                                              size: 18,
                                            ),
                                            title: Text(
                                              l['razon_social'],
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            subtitle: Text(
                                              l['direccion'] ?? '',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            onTap: () {
                                              setState(() {
                                                _lavaderoSeleccionado = l;
                                                _searchController.text =
                                                    l['razon_social'];
                                                _lavaderosFiltrados = [];
                                                FocusScope.of(
                                                  context,
                                                ).unfocus();
                                              });
                                              mapScreenKey.currentState
                                                  ?.moverAMarcador(
                                                    LatLng(
                                                      l['latitud'],
                                                      l['longitud'],
                                                    ),
                                                  );
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 15),

                            // --- BOTONES LATERALES (Varita y Avatar) ---
                            Container(
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.auto_fix_high,
                                  color: Color(0xFF3ABEF9),
                                ),
                                onPressed: () => mapScreenKey.currentState
                                    ?.generarLavaderosAutomaticos(),
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: () => setState(() => _indiceActual = 2),
                              child: CircleAvatar(
                                radius: 20,
                                backgroundColor: const Color(0xFF3ABEF9),
                                backgroundImage:
                                    supabase
                                            .auth
                                            .currentUser
                                            ?.userMetadata?['avatar_url'] !=
                                        null
                                    ? NetworkImage(
                                        supabase
                                            .auth
                                            .currentUser!
                                            .userMetadata!['avatar_url'],
                                      )
                                    : null,
                                child:
                                    supabase
                                            .auth
                                            .currentUser
                                            ?.userMetadata?['avatar_url'] ==
                                        null
                                    ? const Icon(
                                        Icons.person,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // PANEL FLOTANTE: Aparece solo en móvil cuando hay selección
                    if (esPantallaChica &&
                        _lavaderoSeleccionado != null &&
                        supabase.auth.currentUser != null)
                      Positioned(
                        right: 15,
                        top: 80,
                        bottom: 20,
                        width: 330,
                        child: Material(
                          elevation: 10,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: _buildPanelInformacion(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // COLUMNA 3: PANEL DERECHO DINÁMICO Y ANIMADO
              if (!esPantallaChica && supabase.auth.currentUser != null)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOutQuart,
                  // El ancho es 350 si hay algo que mostrar, sino es 0
                  width:
                      (_lavaderoSeleccionado != null ||
                          (_rolUsuario == 'cliente' &&
                              _searchController.text.isNotEmpty))
                      ? 350
                      : 0,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(
                          -5,
                          0,
                        ), // Sombra hacia la izquierda
                      ),
                    ],
                  ),
                  // ClipRect evita que el contenido se vea "amontonado" mientras se cierra
                  child: ClipRect(
                    child: OverflowBox(
                      minWidth: 350,
                      maxWidth: 350,
                      alignment: Alignment.centerLeft,
                      child: _buildContenidoPanelDerecho(),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // Mueve aquí el contenido que tenías antes en el Sidebar
  Widget _buildContenidoSidebar() {
    // --- PASO 1: VERIFICAR SESIÓN ACTIVA ---
    final bool tieneSesion = supabase.auth.currentUser != null;

    return Column(
      children: [
        const SizedBox(height: 50),
        // --- LOGO ATT! --- (Tu bloque de logo se mantiene igual)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFF3ABEF9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.directions_car_filled,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                  children: [
                    TextSpan(
                      text: "ATT",
                      style: TextStyle(color: Colors.white),
                    ),
                    TextSpan(
                      text: "!",
                      style: TextStyle(color: Color(0xFF3ABEF9)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),

        // --- BOTONES DEL MENÚ ---
        _itemMenuLateral(Icons.map, "Explorar Mapa", 0),

        // --- BOTÓN MIS RESERVAS: Solo si tiene sesión ---
        if (tieneSesion)
          _itemMenuLateral(Icons.calendar_month, "Mis Reservas", 1),

        _itemMenuLateral(Icons.person, "Mi Perfil", 2),

        // --- BOTÓN CONFIGURAR: Solo si tiene sesión Y es dueño ---
        if (tieneSesion && _rolUsuario == 'lavadero')
          _itemMenuLateral(Icons.add_business, "Configurar Lavadero", 99),

        // --- NUEVO BOTÓN: MIS CLIENTES (Solo para Dueños) ---
        // Lo asignamos con el índice 100 para no chocar con los demás
        if (tieneSesion && _rolUsuario == 'lavadero')
          _itemMenuLateral(Icons.people_alt_rounded, "Mis Clientes", 100),

        const Spacer(),
        const Text(
          "v1.0.8",
          style: TextStyle(color: Colors.white24, fontSize: 10),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // Función para crear los botones del menú lateral
  // --- SUSTITUIR DESDE AQUÍ ---
  Widget _itemMenuLateral(IconData icono, String texto, int index) {
    bool seleccionado = _indiceActual == index;
    return Padding(
      // 1. EL MARGEN: Para que el botón no toque los bordes del sidebar
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        // 2. EL REDONDEADO: 'borderRadius' de 12 o más para ese efecto cápsula
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

        // 3. EL COLOR DE FONDO: Solo se ve cuando está seleccionado
        tileColor: seleccionado
            ? Colors.white.withOpacity(0.1)
            : Colors.transparent,

        // 4. EL ESTADO: Para que Flutter sepa que debe aplicar los colores de arriba
        selected: seleccionado,

        onTap: () {
          if (index == 99) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const RegistroLavaderoScreen(),
              ),
            );
          } else {
            if (index == 0)
              mapScreenKey.currentState?.cargarLavaderosDeSupabase();

            setState(() {
              // IMPORTANTE: Ahora guardamos el índice real (0, 1, 2 o 100)
              _indiceActual = index;
            });
          }
        },

        leading: Icon(
          icono,
          color: seleccionado ? const Color(0xFFEF4444) : Colors.white60,
          size: 22,
        ),
        title: Text(
          texto,
          style: TextStyle(
            color: seleccionado ? Colors.white : Colors.white60,
            fontSize: 15,
            fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
  // --- HASTA AQUÍ ---

  Widget _buildPanelInformacion() {
    if (_lavaderoSeleccionado == null) {
      return const Center(
        child: Text(
          "Seleccioná un lavadero\nen el mapa para ver detalle",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    // Cargamos los datos actuales en los controladores
    _nombreCtrl.text = _lavaderoSeleccionado['razon_social'] ?? '';
    _direccionCtrl.text = _lavaderoSeleccionado['direccion'] ?? '';

    // Determinamos si el usuario puede editar (solo rol lavadero)
    bool esDueno = _rolUsuario == 'lavadero';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. IMAGEN DEL LAVADERO
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Image.network(
              'https://picsum.photos/seed/${_lavaderoSeleccionado['id']}/400/250',
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, e, s) => Container(
                height: 180,
                color: Colors.grey[200],
                child: const Icon(Icons.image),
              ),
            ),
          ),
          const SizedBox(height: 25),

          // Título dinámico según el rol
          Text(
            esDueno ? "GESTIONAR MI NEGOCIO" : "DETALLES DEL LAVADERO",
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 20),

          // 2. CAMPOS DE INFORMACIÓN
          // Si es dueño, los campos son editables. Si es cliente, son de solo lectura.
          _inputPanel("Nombre del Negocio", _nombreCtrl, habilitado: esDueno),
          const SizedBox(height: 15),
          _inputPanel("Dirección", _direccionCtrl, habilitado: esDueno),

          const SizedBox(height: 30),

          // 3. BOTONES DE ACCIÓN (Diferenciados por Rol)
          if (esDueno) ...[
            // VISTA PARA DUEÑOS: Update y Borrar
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3ABEF9),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _actualizarLavaderoEnSupabase(),
                    child: const Text("Update Info"),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _confirmarBorrado(),
                  tooltip: "Eliminar Lavadero",
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.grey),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => setState(() => _lavaderoSeleccionado = null),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          ] else ...[
            // VISTA PARA CLIENTES: Botón de Reserva destacado
            const Divider(height: 10),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 55),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.calendar_today, size: 20),
              label: const Text(
                "SOLICITAR TURNO AHORA",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ReservaScreen(lavadero: _lavaderoSeleccionado),
                  ),
                );
              },
            ),
            const SizedBox(height: 15),
            // Botón secundario para volver a los resultados
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 45),
                side: const BorderSide(color: Color(0xFF3ABEF9)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => setState(() => _lavaderoSeleccionado = null),
              child: const Text("VOLVER AL LISTADO"),
            ),
          ],
        ],
      ),
    );
  }

  // Helper modificado para soportar el estado 'readOnly'
  Widget _inputPanel(
    String label,
    TextEditingController ctrl, {
    bool habilitado = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.blueGrey,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: ctrl,
          enabled: habilitado, // Controla si el usuario puede escribir
          style: TextStyle(
            color: habilitado ? Colors.black87 : Colors.black54,
            fontWeight: habilitado ? FontWeight.normal : FontWeight.bold,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: habilitado ? Colors.grey[100] : Colors.blueGrey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            // Si no está habilitado, no mostramos el cursor
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
        ),
      ],
    );
  }

  // LA FUNCIÓN QUE GUARDA EN SUPABASE
  Future<void> _actualizarLavaderoEnSupabase() async {
    try {
      await supabase
          .from('lavaderos')
          .update({
            'razon_social': _nombreCtrl.text,
            'direccion': _direccionCtrl.text,
          })
          .eq('id', _lavaderoSeleccionado['id']);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Lavadero actualizado correctamente"),
          backgroundColor: Colors.green,
        ),
      );

      // Esto hace que el mapa se refresque solo y muestre el nuevo nombre
      mapScreenKey.currentState?.cargarLavaderosDeSupabase();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Error al actualizar: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --- FUNCIÓN PARA CONFIRMAR BORRADO ---
  void _confirmarBorrado() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Eliminar lavadero?"),
        content: Text(
          "Estás por borrar '${_lavaderoSeleccionado['razon_social']}'. Esta acción no se puede deshacer.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCELAR"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _eliminarLavaderoDeSupabase();
            },
            child: const Text("BORRAR", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // --- FUNCIÓN QUE BORRA DE SUPABASE ---
  Future<void> _eliminarLavaderoDeSupabase() async {
    try {
      await supabase
          .from('lavaderos')
          .delete()
          .eq('id', _lavaderoSeleccionado['id']);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🗑️ Lavadero eliminado"),
          backgroundColor: Colors.orange,
        ),
      );

      setState(() => _lavaderoSeleccionado = null); // Cerramos el panel derecho
      mapScreenKey.currentState
          ?.cargarLavaderosDeSupabase(); // Refrescamos el mapa
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Error al borrar: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --- PANTALLA BENTO CORREGIDA: MIS CLIENTES ---
  Widget _buildPantallaMisClientes() {
    return Container(
      color: const Color(0xFFF5F7F9),
      child: Column(
        children: [
          // --- CABECERA BLANCA CON TÍTULO Y FLECHA ---
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2)],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.black87,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _indiceActual = 0), // Vuelve al mapa
                ),
                const Expanded(
                  child: Center(
                    child: Text(
                      "MIS CLIENTES",
                      style: TextStyle(
                        color: Color(0xFF3ABEF9),
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  width: 40,
                ), // Balance visual para el botón de volver
              ],
            ),
          ),

          const SizedBox(height: 24),

          // --- BLOQUES BENTO DE ESTADÍSTICAS ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _tarjetaMiniBento(
                  "Total Clientes",
                  "0",
                  Icons.people,
                  const Color(0xFF3ABEF9),
                ),
                const SizedBox(width: 15),
                _tarjetaMiniBento(
                  "Frecuentes",
                  "0",
                  Icons.auto_awesome,
                  Colors.amber,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // --- BLOQUE BENTO PRINCIPAL ---
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: "Buscar por nombre o patente...",
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_search_rounded,
                            size: 50,
                            color: Colors.black12,
                          ),
                          SizedBox(height: 16),
                          Text(
                            "Sin clientes registrados\nLos clientes aparecerán cuando soliciten turnos.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaMiniBento(
    String titulo,
    String valor,
    IconData icono,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icono, color: color, size: 30),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  valor,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _filaClienteBento(String nombre, String patente, String auto) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF3ABEF9),
          child: Text(nombre[0], style: const TextStyle(color: Colors.white)),
        ),
        title: Text(
          nombre,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          "$auto • $patente",
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.black26),
      ),
    );
  }
}

// --- PANTALLA DE MAPA ---
class MapScreen extends StatefulWidget {
  final VoidCallback? onIrAPerfil;
  final Function(dynamic)? onSelectLavadero;
  final VoidCallback? onDeselccionar;
  final Function(List<dynamic>)? onLavaderosCargados;
  const MapScreen({
    super.key,
    this.onIrAPerfil,
    this.onSelectLavadero,
    this.onDeselccionar, // <--- AGREGA ESTA LÍNEA AQUÍ ADENTRO
    this.onLavaderosCargados,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<Marker> _markers = [];
  String _userRol = 'pendiente';
  void moverAMarcador(LatLng posicion) {
    _animatedMapMove(posicion, 16);
  }

  // CONTROLADOR DEL MAPA PARA EL ZOOM Y GPS
  final MapController _mapController = MapController();
  void actualizarMarkersExternos(List<dynamic> listaFiltrada) {
    if (!mounted) return;

    setState(() {
      _markers = listaFiltrada.map((l) {
        return Marker(
          point: LatLng(l['latitud'], l['longitud']),
          width: 200,
          height: 250,
          alignment: Alignment.topCenter,
          child: MarkerConPopup(l: l, alTocar: () => _mostrarCartel(l)),
        );
      }).toList();
    });
  }

  @override
  void initState() {
    super.initState();
    _checkUserRol();
    cargarLavaderosDeSupabase();
    _suscribirARealtime();
  }

  Future<void> _checkUserRol() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      final data = await supabase
          .from('perfiles_usuarios')
          .select('rol')
          .eq('id', user.id)
          .maybeSingle();
      if (data != null && mounted) {
        setState(() => _userRol = data['rol'] ?? 'pendiente');
      }
    }
  }

  void _suscribirARealtime() {
    supabase
        .channel('public:lavaderos')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'lavaderos',
          callback: (payload) => cargarLavaderosDeSupabase(),
        )
        .subscribe();
  }

  // --- FUNCIÓN PARA MOVIMIENTO SUAVE (PEGAR AQUÍ) ---
  void _animatedMapMove(LatLng destLocation, double destZoom) {
    final latTween = Tween<double>(
      begin: _mapController.camera.center.latitude,
      end: destLocation.latitude,
    );
    final lngTween = Tween<double>(
      begin: _mapController.camera.center.longitude,
      end: destLocation.longitude,
    );
    final zoomTween = Tween<double>(
      begin: _mapController.camera.zoom,
      end: destZoom,
    );

    final controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: Navigator.of(context),
    );

    final animation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOutCubic,
    );

    controller.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) controller.dispose();
    });

    controller.forward();
  }

  Future<void> cargarLavaderosDeSupabase() async {
    final data = await supabase.from('lavaderos').select();
    if (mounted) {
      // ESTA LÍNEA ES LA CLAVE: Envía los datos al MainLayout
      if (widget.onLavaderosCargados != null) {
        widget.onLavaderosCargados!(data as List);
      }

      setState(() {
        _markers = (data as List).map((l) {
          return Marker(
            point: LatLng(l['latitud'], l['longitud']),
            width: 200,
            height: 250,
            alignment: Alignment.topCenter,
            child: MarkerConPopup(l: l, alTocar: () => _mostrarCartel(l)),
          );
        }).toList();
      });
    }
  }

  Future<void> generarLavaderosAutomaticos() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final nuevosLavaderos = [
      {
        'dueño_id': user.id,
        'razon_social': 'Lavadero Express Zárate',
        'direccion': 'Av. Lavalle 1200',
        'latitud': -34.098,
        'longitud': -59.028,
        'telefono': '12345678',
        'nombre_banco': 'Banco Provincia',
        'cuenta_bancaria': 'AL-123456',
      },
      {
        'dueño_id': user.id,
        'razon_social': 'A Todo Trapo Premium',
        'direccion': 'Justa Lima 500',
        'latitud': -34.102,
        'longitud': -59.022,
        'telefono': '87654321',
        'nombre_banco': 'Banco Galicia',
        'cuenta_bancaria': 'AL-654321',
      },
    ];

    try {
      await supabase.from('lavaderos').insert(nuevosLavaderos);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Lavaderos de prueba creados")),
        );
      }
    } catch (e) {
      debugPrint("❌ Error al generar: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  void _mostrarCartel(dynamic l) {
    // Esta línea le avisa al Dashboard qué lavadero tocaste
    if (widget.onSelectLavadero != null) widget.onSelectLavadero!(l);
    // ... el resto de tu código del showModalBottomSheet ...
    if (_userRol == 'cliente') return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.all(24),
        height: 250,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l['razon_social'],
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFFEF4444),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Dirección: ${l['direccion'] ?? 'Zárate'}",
              style: TextStyle(color: Colors.grey[600]),
            ),
            // --- REEMPLAZO DENTRO DE _mostrarCartel ---
            const Spacer(),
            if (_userRol == 'cliente')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                  ),
                  onPressed: () {
                    // 1. VALIDAMOS SESIÓN EN TIEMPO REAL
                    final usuarioActivo = supabase.auth.currentUser;

                    if (usuarioActivo == null) {
                      // 2. SI NO HAY SESIÓN: Cerramos cartel, avisamos y mandamos al perfil
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "⚠️ Debes iniciar sesión para solicitar un turno",
                          ),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      // Llamamos a la función para cambiar de pestaña al perfil
                      if (widget.onIrAPerfil != null) widget.onIrAPerfil!();
                    } else {
                      // 3. SI HAY SESIÓN: Vamos a la reserva normalmente
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReservaScreen(lavadero: l),
                        ),
                      );
                    }
                  },
                  child: const Text(
                    "SOLICITAR TURNO",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              )
            else
              const Center(
                child: Text(
                  "Solo clientes pueden reservar.",
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.orange,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // WIDGETS DE ESTILO PARA BOTONES DEL MAPA
  Widget _botonCircular({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.black87, size: 24),
        onPressed: onPressed,
      ),
    );
  }

  Widget _botonZoom({required IconData icon, required VoidCallback onPressed}) {
    return SizedBox(
      width: 45,
      height: 45,
      child: IconButton(
        icon: Icon(icon, color: Colors.black87, size: 24),
        onPressed: onPressed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(-34.098, -59.028),
              initialZoom: 14,
              // ESTA FUNCIÓN SE ACTIVA AL TOCAR CUALQUIER PARTE VACÍA DEL MAPA
              onTap: (tapPosition, point) {
                if (widget.onDeselccionar != null) {
                  widget.onDeselccionar!();
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              ),
              MarkerLayer(markers: _markers),
            ],
          ),
          // Aquí siguen tus botones circulares de GPS y Zoom que ya tienes...
          // --- PANEL DE BOTONES FACHEROS ---
          Positioned(
            top: 100, // Bajado para no tapar el Avatar
            right: 15,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _botonCircular(
                  icon: Icons.my_location,
                  onPressed: () =>
                      _animatedMapMove(const LatLng(-34.098, -59.028), 15),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _botonZoom(
                        icon: Icons.add,
                        onPressed: () => _animatedMapMove(
                          _mapController.camera.center,
                          _mapController.camera.zoom + 1,
                        ),
                      ),
                      Container(width: 30, height: 1, color: Colors.grey[300]),
                      _botonZoom(
                        icon: Icons.remove,
                        onPressed: () => _animatedMapMove(
                          _mapController.camera.center,
                          _mapController.camera.zoom - 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // --- BLOQUE 2: BOTÓN "+" DE AÑADIR TURNO (ABAJO A LA DERECHA) ---
          // Solo aparece en la versión móvil/tablet
          if (MediaQuery.of(context).size.width < 950)
            Positioned(
              bottom: 30, // Posición clásica de pulgar
              right: 20,
              child: Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFF3ABEF9), // Rojo ATT!
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.add, color: Colors.white, size: 35),
                  onPressed: () {
                    // Aquí tu lógica para añadir turno
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// --- WIDGET PERSONALIZADO PARA EL MARCADOR CON POPUP ---
class MarkerConPopup extends StatefulWidget {
  final dynamic l;
  final VoidCallback alTocar;
  const MarkerConPopup({super.key, required this.l, required this.alTocar});

  @override
  State<MarkerConPopup> createState() => _MarkerConPopupState();
}

class _MarkerConPopupState extends State<MarkerConPopup> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            bottom: _isHovered ? 55 : 30,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 300),
              scale: _isHovered ? 1.0 : 0.0,
              curve: Curves.easeOutBack,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isHovered ? 1.0 : 0.0,
                child: Container(
                  width: 180,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                    border: Border.all(
                      color: const Color(0xFF3ABEF9),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          'https://picsum.photos/seed/${widget.l['id']}/200/120',
                          height: 80,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                height: 80,
                                color: Colors.grey[200],
                                child: const Icon(Icons.image_not_supported),
                              ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.l['razon_social'] ?? 'Lavadero',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const Text(
                        "⭐ 4.5 | Disponible",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: widget.alTocar,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 200),
              scale: _isHovered ? 1.2 : 1.0,
              child: Icon(
                Icons.location_on,
                color: _isHovered
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF3ABEF9),
                size: 45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- PANTALLA DE PERFIL ---
class PerfilScreen extends StatefulWidget {
  final VoidCallback? onVolver;
  const PerfilScreen({super.key, this.onVolver});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  // --- CONTROLADORES DE DATOS ---
  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController(); // AGREGAR ESTE
  final _telefonoController = TextEditingController();
  final _ciudadController = TextEditingController();
  final _fechaNacController = TextEditingController();

  // Garage(cliente)
  final _patenteController = TextEditingController();
  final _marcaController = TextEditingController();
  final _colorController = TextEditingController();

  // DUEÑO (Lavadero) - AGREGAR ESTOS 3
  final _cuitController = TextEditingController();
  final _cpController = TextEditingController();
  final _descripcionController = TextEditingController();

  final supabase = Supabase.instance.client;
  String _rolUsuario = 'cliente';
  bool _cargando = true;
  bool _estaEditando = false;

  // Colores Oficiales ATT! 2040
  final Color azulATT = const Color(0xFF3ABEF9);
  final Color rojoATT = const Color(0xFFEF4444);
  final Color fondoSoft = const Color(0xFFF0F4F8);

  @override
  void initState() {
    super.initState();
    _cargarDatosPerfil();
  }

  Future<void> _cargarDatosPerfil() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _cargando = false);
      return;
    }

    try {
      final data = await supabase
          .from('perfiles_usuarios')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          if (data != null) {
            _rolUsuario = data['rol'] ?? 'cliente';
            _nombreController.text =
                data['nombre'] ?? user.userMetadata?['full_name'] ?? '';
            _apellidoController.text = data['apellido'] ?? ''; // SQL: apellido
            _telefonoController.text = data['telefono'] ?? '';
            _ciudadController.text = data['ciudad'] ?? '';
            _fechaNacController.text = data['fecha_nacimiento'] ?? '';
            _patenteController.text = data['patente'] ?? '';
            _marcaController.text = data['marca_modelo'] ?? '';
            _colorController.text = data['color_vehiculo'] ?? '';
            // Campos de Dueño
            _cuitController.text = data['cuil_cuit'] ?? '';
            _cpController.text = data['codigo_postal'] ?? '';
            _descripcionController.text = data['descripcion_negocio'] ?? '';
          }
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _cargando = false);

      // 🚨 ESTO ES CLAVE: Mirá la consola de VS Code/Android Studio
      // Te va a decir "column cuil_cuit does not exist" o algo similar.
      debugPrint("❌ ERROR DE SUPABASE: $e");

      _mostrarAlerta("❌ Error al guardar datos", rojoATT);
    }
  }

  Future<void> _actualizarPerfil() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _cargando = true);

    // 1. Datos base (Comunes)
    Map<String, dynamic> updates = {
      'nombre': _nombreController.text,
      'apellido': _apellidoController.text,
      'telefono': _telefonoController.text,
      'ciudad': _ciudadController.text,
      'fecha_nacimiento': _fechaNacController.text,
    };

    // 2. Datos según Rol (Evita errores de columnas)
    if (_rolUsuario == 'cliente') {
      updates.addAll({
        'patente': _patenteController.text.toUpperCase(),
        'marca_modelo': _marcaController.text,
        'color_vehiculo': _colorController.text,
      });
    } else if (_rolUsuario == 'dueño') {
      updates.addAll({
        'cuil_cuit': _cuitController.text,
        'codigo_postal': _cpController.text,
        'descripcion_negocio': _descripcionController.text,
      });
    }

    try {
      await supabase
          .from('perfiles_usuarios')
          .update(updates)
          .eq('id', user.id);

      if (mounted) {
        setState(() {
          _estaEditando = false;
          _cargando = false;
        });
        _mostrarAlerta("✨ Perfil ATT! sincronizado", Colors.green);
      }
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
      _mostrarAlerta("❌ Error al guardar datos", rojoATT);
    }
  }

  Future<void> _cerrarSesion() async {
    await supabase.auth.signOut();
    if (mounted) {
      widget.onVolver?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuarioAuth = supabase.auth.currentUser;

    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: fondoSoft,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // HEADER BENTO 2040
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.black87,
                size: 20,
              ),
              onPressed: widget.onVolver,
            ),
            actions: [
              if (usuarioAuth != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: IconButton(
                    onPressed: () {
                      if (_estaEditando) {
                        _actualizarPerfil();
                      } else {
                        setState(() => _estaEditando = true);
                      }
                    },
                    icon: Icon(
                      _estaEditando
                          ? Icons.check_circle_rounded
                          : Icons.edit_note_rounded,
                      color: _estaEditando ? Colors.green : azulATT,
                      size: 32,
                    ),
                  ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text(
                "MI PERFIL",
                style: TextStyle(
                  color: azulATT,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (usuarioAuth == null)
                  _buildLoginBento()
                else ...[
                  // IDENTIDAD VISUAL
                  _buildIdentityHeader(usuarioAuth),
                  const SizedBox(height: 24),

                  // MÓDULO 1: DATOS PERSONALES
                  _buildBentoCard(
                    title: "Información Personal",
                    icon: Icons.person_outline_rounded,
                    child: Column(
                      children: [
                        Row(
                          // NOMBRE Y APELLIDO EN LA MISMA FILA
                          children: [
                            Expanded(
                              child: _buildField(
                                _nombreController,
                                "Nombre",
                                Icons.face_rounded,
                                _estaEditando,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildField(
                                _apellidoController,
                                "Apellido",
                                Icons.person_search_rounded,
                                _estaEditando,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _buildField(
                                _telefonoController,
                                "Teléfono",
                                Icons.phone_android_rounded,
                                _estaEditando,
                                type: TextInputType.phone,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildField(
                                _ciudadController,
                                "Ciudad",
                                Icons.location_city_rounded,
                                _estaEditando,
                              ),
                            ),
                          ],
                        ),
                        _buildField(
                          _fechaNacController,
                          "Fecha de Nacimiento",
                          Icons.cake_rounded,
                          _estaEditando,
                          isDate: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // MÓDULO 2: ESPECÍFICO SEGÚN ROL
                  if (_rolUsuario == 'cliente')
                    _buildBentoCard(
                      title: "Mi Garage Digital",
                      icon: Icons.directions_car_filled_rounded,
                      child: Column(
                        children: [
                          _buildField(
                            _patenteController,
                            "Patente",
                            Icons.pin_rounded,
                            _estaEditando,
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: _buildField(
                                  _marcaController,
                                  "Marca y Modelo",
                                  Icons.minor_crash_rounded,
                                  _estaEditando,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildField(
                                  _colorController,
                                  "Color",
                                  Icons.palette_rounded,
                                  _estaEditando,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  else if (_rolUsuario == 'dueño')
                    _buildBentoCard(
                      title: "Información del Lavadero",
                      icon: Icons.storefront_rounded,
                      child: Column(
                        children: [
                          _buildField(
                            _cuitController,
                            "CUIL / CUIT",
                            Icons.badge_rounded,
                            _estaEditando,
                            type: TextInputType.number,
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: _buildField(
                                  _cpController,
                                  "Cod. Postal",
                                  Icons.local_post_office_rounded,
                                  _estaEditando,
                                  type: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Spacer(), // Espacio para diseño bento desparejo
                            ],
                          ),
                          // CAMPO DE DESCRIPCIÓN
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: TextField(
                              controller: _descripcionController,
                              enabled: _estaEditando,
                              maxLines: 3,
                              style: TextStyle(
                                fontSize: 14,
                                color: _estaEditando
                                    ? Colors.black87
                                    : Colors.black45,
                              ),
                              decoration: InputDecoration(
                                labelText: "Descripción del Negocio",
                                alignLabelWithHint: true,
                                filled: true,
                                fillColor: _estaEditando
                                    ? azulATT.withOpacity(0.05)
                                    : fondoSoft.withOpacity(0.3),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // MÓDULO 3: PAGOS GLASSMORHPISM
                  if (_rolUsuario == 'cliente')
                    _buildBentoCard(
                      title: "Métodos de Pago",
                      icon: Icons.account_balance_wallet_rounded,
                      child: Column(
                        children: [
                          _buildTarjetaGlass("4567", "Visa"),
                          const SizedBox(height: 16),
                          _buildBentoButton(
                            "GESTIONAR TARJETAS",
                            Icons.add_card_rounded,
                            azulATT,
                            () {
                              _mostrarAlerta(
                                "Función disponible próximamente",
                                azulATT,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  // ACCIONES FINALES
                  _buildBentoCard(
                    child: _actionRow(
                      Icons.logout_rounded,
                      "Cerrar Sesión",
                      rojoATT,
                      onTap: _cerrarSesion,
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // --- COMPONENTES BENTO 2040 ---

  Widget _buildBentoCard({
    required Widget child,
    String? title,
    IconData? icon,
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
          if (title != null) ...[
            Row(
              children: [
                Icon(icon, size: 14, color: azulATT),
                const SizedBox(width: 8),
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.black26,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
            const Divider(height: 24, color: Color(0xFFF1F5F9)),
          ],
          child,
        ],
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label,
    IconData icon,
    bool edit, {
    bool isDate = false,
    TextInputType type = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        enabled: edit,
        readOnly: isDate,
        keyboardType: type,
        onTap: isDate && edit ? () => _pickDate() : null,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: edit ? Colors.black87 : Colors.black45,
        ),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(
            icon,
            size: 18,
            color: edit ? azulATT : Colors.black12,
          ),
          filled: true,
          fillColor: edit
              ? azulATT.withOpacity(0.05)
              : fondoSoft.withOpacity(0.3),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildIdentityHeader(User user) {
    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 45,
            backgroundColor: azulATT.withOpacity(0.1),
            backgroundImage: NetworkImage(
              user.userMetadata?['avatar_url'] ?? '',
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: _rolUsuario == 'cliente'
                  ? azulATT.withOpacity(0.1)
                  : rojoATT.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _rolUsuario.toUpperCase(),
              style: TextStyle(
                color: _rolUsuario == 'cliente' ? azulATT : rojoATT,
                fontWeight: FontWeight.w900,
                fontSize: 10,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTarjetaGlass(String ultimoCuatro, String marca) {
    Color colorBase = marca.toUpperCase() == 'VISA'
        ? const Color(0xFF1A1F71)
        : const Color(0xFFEB001B);
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [colorBase, colorBase.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: colorBase.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.white.withOpacity(0.1),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(
                      Icons.contactless_rounded,
                      color: Colors.white.withOpacity(0.8),
                      size: 28,
                    ),
                    Text(
                      marca.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "•••• •••• •••• $ultimoCuatro",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "MÉTODO ATT! PREDETERMINADO",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBentoButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionRow(
    IconData icon,
    String label,
    Color color, {
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: color.withOpacity(0.3),
      ),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildLoginBento() {
    return _buildBentoCard(
      child: Column(
        children: [
          const Icon(
            Icons.lock_person_rounded,
            size: 50,
            color: Colors.black12,
          ),
          const SizedBox(height: 16),
          const Text(
            "Inicia sesión para ver tu perfil",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () =>
                supabase.auth.signInWithOAuth(OAuthProvider.google),
            child: const Text("ENTRAR CON GOOGLE"),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 6570)),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      locale: const Locale("es", "AR"),
    );
    if (picked != null) {
      setState(
        () =>
            _fechaNacController.text = DateFormat('yyyy-MM-dd').format(picked),
      );
    }
  }

  void _mostrarAlerta(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'reserva_screen.dart';
import 'splash_screen.dart';
import 'mis_turnos_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://oaudxvhroedmtpwrityk.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9hdWR4dmhyb2VkbXRwd3JpdHlrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwOTczMzQsImV4cCI6MjA4MzY3MzMzNH0.qj1sJFu_GSs-T656E6iyIMnSwYYZlTsQpb8Ke3OgZek',
  );

  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

// 1. Llave global para que el Layout pueda hablar con el Mapa
final GlobalKey<_MapScreenState> mapScreenKey = GlobalKey<_MapScreenState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ATT: A todo Trapo',
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

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _indiceActual = 0;

  // 2. Pasamos la llave al MapScreen en la lista de páginas
  late final List<Widget> _paginas = [
    MapScreen(key: mapScreenKey),
    const MisTurnosScreen(),
    const PerfilScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _obtenerPerfil();

    supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.initialSession) {
        _obtenerPerfil();
      }
      if (mounted) setState(() {});
    });
  }

  Future<void> _obtenerPerfil() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      try {
        await supabase
            .from('perfiles_usuarios')
            .select()
            .eq('id', user.id)
            .maybeSingle();
      } catch (e) {
        debugPrint("❌ Error al consultar perfiles_usuarios: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _indiceActual, children: _paginas),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indiceActual,
        onTap: (index) {
          // 3. Si se presiona el botón de Mapa (índice 0), refrescamos datos
          if (index == 0) {
            mapScreenKey.currentState?.cargarLavaderosDeSupabase();
          }

          if (index == 1 && supabase.auth.currentUser == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("⚠️ Debes iniciar sesión para ver tus turnos"),
              ),
            );
            setState(() => _indiceActual = 2);
          } else {
            setState(() => _indiceActual = index);
          }
        },
        selectedItemColor: const Color(0xFFEF4444),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: "Mapa"),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: "Mis Turnos",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Perfil"),
        ],
      ),
    );
  }
}

// --- PANTALLA DE MAPA (CON REALTIME Y REFRESH EXTERNO) ---
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<Marker> _markers = [];
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    cargarLavaderosDeSupabase();
    _suscribirARealtime();
  }

  @override
  void dispose() {
    if (_channel != null) supabase.removeChannel(_channel!);
    super.dispose();
  }

  void _suscribirARealtime() {
    _channel = supabase
        .channel('public:lavaderos')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'lavaderos',
          callback: (payload) {
            debugPrint('🔥 Cambio detectado en lavaderos!');
            cargarLavaderosDeSupabase();
          },
        )
        .subscribe();
  }

  // 4. Función pública para que el NavBar pueda activarla
  Future<void> cargarLavaderosDeSupabase() async {
    final data = await supabase.from('lavaderos').select();
    if (mounted) {
      setState(() {
        _markers = (data as List).map((l) {
          return Marker(
            point: LatLng(l['latitud'], l['longitud']),
            width: 80,
            height: 80,
            child: GestureDetector(
              onTap: () => _mostrarCartel(l),
              child: const Icon(
                Icons.location_on,
                color: Color(0xFF3ABEF9),
                size: 45,
              ),
            ),
          );
        }).toList();
      });
      debugPrint("📍 Lavaderos refrescados desde la barra de navegación");
    }
  }

  void _mostrarCartel(dynamic l) {
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
              "Dirección: ${l['direccion'] ?? 'Zárate, Centro'}",
              style: TextStyle(color: Colors.grey[600]),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ReservaScreen(lavadero: l),
                    ),
                  );
                },
                child: const Text(
                  "SOLICITAR TURNO",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generarLavaderosAutomaticos() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final nuevosLavaderos = [
      {
        'dueño_id': user.id,
        'razon_social': 'Lavadero Express Zárate',
        'direccion': 'Av. Lavalle 1200',
        'latitud': -34.098,
        'longitud': -59.028,
        'telefono_contacto': '12345678', // Nombre corregido según tu SQL
        'cuit': '20-12345678-9', // Agregado porque es UNIQUE
        'duracion_estandar_min': 45,
      },
      {
        'dueño_id': user.id,
        'razon_social': 'A Todo Trapo Premium',
        'direccion': 'Justa Lima 500',
        'latitud': -34.102,
        'longitud': -59.022,
        'telefono_contacto': '87654321', // Nombre corregido según tu SQL
        'cuit': '20-87654321-0', // Agregado porque es UNIQUE
        'duracion_estandar_min': 60,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ATT: A Todo Trapo"),
        backgroundColor: const Color(0xFF3ABEF9),
        foregroundColor: Colors.white,
      ),
      body: FlutterMap(
        options: const MapOptions(
          initialCenter: LatLng(-34.098, -59.028),
          initialZoom: 14,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          ),
          MarkerLayer(markers: _markers),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            mini: true,
            heroTag: "btn_test", // Importante poner heroTags diferentes
            backgroundColor: Colors.orange,
            onPressed: _generarLavaderosAutomaticos,
            child: const Icon(Icons.add_location_alt),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            mini: true,
            heroTag: "btn_refresh",
            backgroundColor: const Color(0xFF3ABEF9),
            onPressed: cargarLavaderosDeSupabase,
            child: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}

// --- PANTALLA DE PERFIL ---
class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});
  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final TextEditingController _patenteController = TextEditingController();
  bool _cargandoPatente = false;

  @override
  void initState() {
    super.initState();
    _cargarDatosPerfil();
  }

  Future<void> _cargarDatosPerfil() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      final data = await supabase
          .from('perfiles_usuarios')
          .select('patente')
          .eq('id', user.id)
          .maybeSingle();
      if (data != null && data['patente'] != null) {
        setState(() => _patenteController.text = data['patente']);
      }
    }
  }

  Future<void> _guardarPatente() async {
    final user = supabase.auth.currentUser;
    if (user == null || _patenteController.text.isEmpty) return;
    setState(() => _cargandoPatente = true);
    try {
      await supabase
          .from('perfiles_usuarios')
          .update({'patente': _patenteController.text.toUpperCase()})
          .eq('id', user.id);
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("✅ Patente actualizada")));
    } finally {
      if (mounted) setState(() => _cargandoPatente = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = supabase.auth.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mi Perfil"),
        backgroundColor: const Color(0xFFEF4444),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: usuario == null
            ? ElevatedButton(
                onPressed: () =>
                    supabase.auth.signInWithOAuth(OAuthProvider.google),
                child: const Text("Entrar con Google"),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: NetworkImage(
                      usuario.userMetadata?['avatar_url'] ?? '',
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    usuario.userMetadata?['full_name'] ?? 'Usuario',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: TextField(
                      controller: _patenteController,
                      decoration: InputDecoration(
                        labelText: "Patente",
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.save, color: Colors.green),
                          onPressed: _guardarPatente,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.add_business),
                    label: const Text("REGISTRAR MI LAVADERO"),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RegistroLavaderoScreen(),
                        ),
                      );
                      debugPrint("🔄 El usuario volvió del registro");
                    },
                  ),
                  TextButton(
                    onPressed: () => supabase.auth.signOut(),
                    child: const Text(
                      "Cerrar Sesión",
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// --- PANTALLA: REGISTRO DE LAVADERO ---
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

  Future<void> _registrar() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      await supabase.from('lavaderos').insert({
        'dueño_id': user.id,
        'razon_social': _nombreController.text,
        'direccion': _direccionController.text,
        'latitud': double.parse(_latController.text),
        'longitud': double.parse(_lngController.text),
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("✅ Lavadero registrado")));
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Registrar Lavadero")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nombreController,
              decoration: const InputDecoration(labelText: "Nombre Comercial"),
            ),
            TextField(
              controller: _direccionController,
              decoration: const InputDecoration(labelText: "Dirección"),
            ),
            TextField(
              controller: _latController,
              decoration: const InputDecoration(
                labelText: "Latitud (ej: -34.09)",
              ),
            ),
            TextField(
              controller: _lngController,
              decoration: const InputDecoration(
                labelText: "Longitud (ej: -59.02)",
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _registrar,
              child: const Text("GUARDAR LAVADERO"),
            ),
          ],
        ),
      ),
    );
  }
}

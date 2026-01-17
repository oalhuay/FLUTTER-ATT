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

  final List<Widget> _paginas = [
    const MapScreen(),
    const MisTurnosScreen(),
    const PerfilScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _obtenerPerfil();

    supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.initialSession) {
        _obtenerPerfil();
      }
      if (mounted) setState(() {});
    });
  }

  Future<void> _obtenerPerfil() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      debugPrint("🔐 Usuario activo: ${user.email} (ID: ${user.id})");
      try {
        final perfil = await supabase
            .from('perfiles_usuarios')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        if (perfil != null) {
          debugPrint("🚀 OBJETO PERFIL RECUPERADO DE LA DB: $perfil");
        } else {
          debugPrint("⏳ Perfil no encontrado aún. ¿Corriste el Trigger en SQL?");
        }
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
          // PROTECCIÓN DE RUTA: 
          // Si el usuario intenta ir a Mis Turnos (índice 1) y NO hay sesión activa
          if (index == 1 && supabase.auth.currentUser == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("⚠️ Debes iniciar sesión para ver tus turnos"),
                backgroundColor: Color(0xFFEF4444),
                duration: Duration(seconds: 2),
              ),
            );
            // Redirigimos automáticamente a la pestaña de Perfil (índice 2)
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

// --- PANTALLA DE MAPA ---
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<Marker> _markers = [];

  @override
  void initState() {
    super.initState();
    _cargarLavaderosDeSupabase();
  }

  Future<void> _cargarLavaderosDeSupabase() async {
    final data = await supabase.from('lavaderos').select();
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
                  padding: const EdgeInsets.symmetric(vertical: 15),
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
                    fontSize: 16,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ATT: A Todo Trapo"),
        backgroundColor: const Color(0xFF3ABEF9),
        foregroundColor: Colors.white,
        elevation: 2,
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Patente actualizada correctamente")),
        );
      }
    } catch (e) {
      debugPrint("Error al guardar patente: $e");
    } finally {
      if (mounted) setState(() => _cargandoPatente = false);
    }
  }

  Future<void> _loginConGoogle() async {
    try {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'http://localhost:3000',
      );
    } catch (e) {
      debugPrint("Error de Login: $e");
    }
  }

  Future<void> _cerrarSesion() async {
    await supabase.auth.signOut();
    setState(() {});
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
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.account_circle,
                    size: 100,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Ingresá para gestionar tus turnos",
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 260,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        side: const BorderSide(color: Colors.grey, width: 0.5),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _loginConGoogle,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.network(
                            'https://authjs.dev/img/providers/google.svg',
                            height: 22,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.login),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            "Continuar con Google",
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : SingleChildScrollView(
                child: Column(
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
                    Text(
                      usuario.email ?? '',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 30),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: TextField(
                        controller: _patenteController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: "Patente del vehículo",
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.directions_car),
                          suffixIcon: _cargandoPatente
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : IconButton(
                                  icon: const Icon(
                                    Icons.save,
                                    color: Colors.green,
                                  ),
                                  onPressed: _guardarPatente,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: _cerrarSesion,
                      child: const Text(
                        "Cerrar Sesión",
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
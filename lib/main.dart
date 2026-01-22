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

  List<Widget> get _paginas => [
    MapScreen(
      key: mapScreenKey,
      onIrAPerfil: () => setState(() => _indiceActual = 2),
    ),
    const MisTurnosScreen(),
    const PerfilScreen(),
  ];

  @override
  void initState() {
    super.initState();
    supabase.auth.onAuthStateChange.listen((data) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _indiceActual, children: _paginas),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indiceActual,
        onTap: (index) {
          if (index == 0) {
            mapScreenKey.currentState?.cargarLavaderosDeSupabase();
          }
          if (index == 1 && supabase.auth.currentUser == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("⚠️ Debes iniciar sesión")),
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

// --- PANTALLA DE MAPA ---
class MapScreen extends StatefulWidget {
  final VoidCallback? onIrAPerfil;
  const MapScreen({super.key, this.onIrAPerfil});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<Marker> _markers = [];
  RealtimeChannel? _channel;
  String _userRol = 'pendiente';

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
    _channel = supabase
        .channel('public:lavaderos')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'lavaderos',
          callback: (payload) => cargarLavaderosDeSupabase(),
        )
        .subscribe();
  }

  Future<void> cargarLavaderosDeSupabase() async {
    _checkUserRol();
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
              "Dirección: ${l['direccion'] ?? 'Zárate'}",
              style: TextStyle(color: Colors.grey[600]),
            ),
            const Spacer(),
            if (_userRol == 'cliente')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
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

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final String? avatarUrl = user?.userMetadata?['avatar_url'];
    final String primerNombre = (user?.userMetadata?['full_name'] ?? 'Usuario')
        .split(' ')[0];

    return Scaffold(
      appBar: AppBar(
        title: const Text("ATT: A Todo Trapo"),
        backgroundColor: const Color(0xFF3ABEF9),
        foregroundColor: Colors.white,
        actions: [
          if (user != null)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onIrAPerfil,
                child: Padding(
                  padding: const EdgeInsets.only(right: 15.0),
                  child: Row(
                    children: [
                      Text(
                        primerNombre,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white24,
                        backgroundImage: avatarUrl != null
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: avatarUrl == null
                            ? const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 20,
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
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
  String _rolUsuario = 'pendiente';
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatosPerfil();
  }

  Future<void> _cargarDatosPerfil() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      try {
        final data = await supabase
            .from('perfiles_usuarios')
            .select()
            .eq('id', user.id)
            .maybeSingle();
        if (mounted) {
          setState(() {
            if (data != null) {
              _patenteController.text = data['patente'] ?? '';
              _rolUsuario = data['rol'] ?? 'pendiente';
            }
            _cargando = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _cargando = false);
      }
    } else {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _cerrarSesion() async {
    await supabase.auth.signOut();
    if (mounted)
      setState(() {
        _rolUsuario = 'pendiente';
        _patenteController.clear();
      });
  }

  Future<void> _guardarPatente() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    await supabase
        .from('perfiles_usuarios')
        .update({'patente': _patenteController.text.toUpperCase()})
        .eq('id', user.id);
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("✅ Patente guardada")));
  }

  @override
  Widget build(BuildContext context) {
    final usuario = supabase.auth.currentUser;
    if (_cargando)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
            : Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: NetworkImage(
                        usuario.userMetadata?['avatar_url'] ?? '',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      usuario.userMetadata?['full_name'] ?? 'Usuario',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(height: 40),
                    Text(
                      "MODO: ${_rolUsuario.toUpperCase()}",
                      style: const TextStyle(
                        color: Colors.blueGrey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_rolUsuario == 'cliente')
                      TextField(
                        controller: _patenteController,
                        decoration: InputDecoration(
                          labelText: "Tu Patente",
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.save, color: Colors.green),
                            onPressed: _guardarPatente,
                          ),
                        ),
                      ),
                    if (_rolUsuario == 'lavadero')
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.add_business),
                        label: const Text("REGISTRAR MI LAVADERO"),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const RegistroLavaderoScreen(),
                          ),
                        ),
                      ),
                    const Spacer(),
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

// --- PANTALLA: REGISTRO DE LAVADERO (CON PERSONALIZACIÓN) ---
class RegistroLavaderoScreen extends StatefulWidget {
  const RegistroLavaderoScreen({super.key});
  @override
  State<RegistroLavaderoScreen> createState() => _RegistroLavaderoScreenState();
}

class _RegistroLavaderoScreenState extends State<RegistroLavaderoScreen> {
  final _nombreController = TextEditingController();
  final _direccionController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _bancoController = TextEditingController();
  final _cuentaController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  LatLng _punto = const LatLng(-34.098, -59.028);

  @override
  void initState() {
    super.initState();
    _latController.text = _punto.latitude.toString();
    _lngController.text = _punto.longitude.toString();
  }

  Future<void> _registrar() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
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
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Lavadero configurado a todo trapo")),
        );
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
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(
        title: const Text("Mi Lavadero"),
        backgroundColor: const Color(0xFF3ABEF9),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _cardSeccion("Información del Negocio", Icons.store, [
              _input(_nombreController, "Nombre Comercial", Icons.badge),
              _input(_direccionController, "Dirección", Icons.location_on),
              _input(
                _telefonoController,
                "Teléfono",
                Icons.phone,
                k: TextInputType.phone,
              ),
            ]),
            const SizedBox(height: 15),
            _cardSeccion("Ubicación exacta (Toca el mapa)", Icons.pin_drop, [
              SizedBox(
                height: 200,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: _punto,
                      initialZoom: 15,
                      onTap: (tap, p) => setState(() {
                        _punto = p;
                        _latController.text = p.latitude.toString();
                        _lngController.text = p.longitude.toString();
                      }),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _punto,
                            child: const Icon(
                              Icons.location_on,
                              color: Color(0xFFEF4444),
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 15),
            _cardSeccion("Registro Bancario (Cobros)", Icons.account_balance, [
              _input(
                _bancoController,
                "Nombre del Banco",
                Icons.account_balance_wallet,
              ),
              _input(_cuentaController, "CBU / Alias / CVU", Icons.vignette),
            ]),
            const SizedBox(height: 25),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onPressed: _registrar,
              child: const Text(
                "GUARDAR CONFIGURACIÓN",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardSeccion(String t, IconData i, List<Widget> c) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            Row(
              children: [
                Icon(i, color: const Color(0xFF3ABEF9)),
                const SizedBox(width: 10),
                Text(t, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(),
            ...c,
          ],
        ),
      ),
    );
  }

  Widget _input(
    TextEditingController ctrl,
    String lab,
    IconData ico, {
    TextInputType k = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        keyboardType: k,
        decoration: InputDecoration(
          labelText: lab,
          prefixIcon: Icon(ico, color: const Color(0xFF3ABEF9), size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

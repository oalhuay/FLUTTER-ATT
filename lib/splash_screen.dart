import 'package:flutter/material.dart';
import 'main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _verificarRuta();
  }

  Future<void> _verificarRuta() async {
    // 1. Esperamos los 3 segundos de rigor para que se luzca el logo
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    // 2. Obtenemos el usuario actual
    final user = supabase.auth.currentUser;

    if (user == null) {
      // Si no hay nadie logueado, vamos al MainLayout (donde el Perfil pedirá login)
      _navegarA(const MainLayout());
    } else {
      // 3. SI HAY SESIÓN, verificamos el ROL en la base de datos
      try {
        final data = await supabase
            .from('perfiles_usuarios')
            .select('rol')
            .eq('id', user.id)
            .maybeSingle();

        if (mounted) {
          // Si no tiene rol en SQL o el rol es 'pendiente', lo obligamos a elegir
          if (data == null || data['rol'] == 'pendiente') {
            _navegarA(const SeleccionRolScreen());
          } else {
            // Si ya es cliente o lavadero, entra directo a la App
            _navegarA(const MainLayout());
          }
        }
      } catch (e) {
        // Por seguridad, si falla la red, lo mandamos al MainLayout
        debugPrint("Error en Splash: $e");
        _navegarA(const MainLayout());
      }
    }
  }

  // Función auxiliar para no repetir código de navegación
  void _navegarA(Widget pantalla) {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => pantalla),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEF4444), // El Rojo ATT!
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Tu logo
            Image.asset('assets/logo_att.png', width: 200),
            const SizedBox(height: 20),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}

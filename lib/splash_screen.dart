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
      // Eliminamos el backgroundColor simple para usar el Container con Gradient
      body: Container(
        width: double.infinity,
        height: double.infinity,
        // --- DEGRADADO RADIAL ROJO (Efecto profundidad) ---
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [
              Color(0xFFEF4444), // Rojo ATT! central
              Color(0xFF7F1D1D), // Rojo bordó oscuro hacia las esquinas
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // --- EL LOGO DENTRO DE UNA "MEDALLA" BENTO ---
            // Esto oculta el fondo blanco del PNG y lo hace ver premium
            // --- EL LOGO DENTRO DE UNA "MEDALLA" BENTO (CORREGIDO) ---
            // --- EL LOGO DENTRO DE UNA "MEDALLA" BENTO (CORRECCIÓN FINAL) ---
            // --- EL LOGO COMPACTO CON ANILLO AZUL (CAMBIO AQUÍ) ---
            Container(
              padding: const EdgeInsets.all(
                6,
              ), // El "aire" blanco entre el logo y el borde azul
              decoration: BoxDecoration(
                color: Colors.white,
                // Usamos StadiumBorder o BorderRadius alto para que sea OVALADO como tu logo
                borderRadius: BorderRadius.circular(60),
                border: Border.all(
                  color: const Color(0xFF003366), // Azul ATT!
                  width: 4, // El anillo exterior
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 25,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: Image.asset(
                  'assets/logo_att.png',
                  height:
                      120, // Altura controlada para que el ancho se ajuste solo
                  fit: BoxFit
                      .contain, // Mantiene la proporción original del óvalo
                ),
              ),
            ),
            const SizedBox(height: 40),

            // --- TEXTO DE IDENTIDAD (CON BORDE AZUL) ---
            // --- NOMBRE DE LA APP (SERGIO TRENDY - BLANCO PURO) ---
            const Text(
              "A TODO TRAPO",
              style: TextStyle(
                fontFamily:
                    'SergioTrendy', // Asegurate que el nombre sea igual al del pubspec.yaml
                color: Colors.white,
                fontSize: 40, // Más grande para que se luzca la fuente de Canva
                fontWeight: FontWeight.normal,
              ),
            ),

            const SizedBox(height: 5),

            // --- TU FIRMA OSCAR ALHUAY ---
            const Text(
              "OSCAR ALHUAY",
              style: TextStyle(
                color: Colors.white60,
                fontSize: 10,
                fontWeight: FontWeight.w300,
                letterSpacing: 12, // Espaciado premium
              ),
            ),

            const SizedBox(height: 60),

            // --- INDICADOR DE CARGA ---
            const SizedBox(
              width: 35,
              height: 35,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sceneController;
  late final Animation<double> _carX;
  late final Animation<double> _carOpacity;
  late final Animation<double> _glowOpacity;

  @override
  void initState() {
    super.initState();

    _sceneController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    );

    _carX = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 0.56)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 62,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.56, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 38,
      ),
    ]).animate(_sceneController);

    _carOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 52),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 28,
      ),
    ]).animate(_sceneController);

    _glowOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 44),
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 8,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 10),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 10,
      ),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 28),
    ]).animate(_sceneController);

    _verificarRuta();
  }

  @override
  void dispose() {
    _sceneController.dispose();
    super.dispose();
  }

  Future<void> _verificarRuta() async {
    await _sceneController.forward();

    if (!mounted) return;

    final user = supabase.auth.currentUser;

    if (user == null) {
      _navegarA(const MainLayout());
    } else {
      try {
        final data = await supabase
            .from('perfiles_usuarios')
            .select('rol')
            .eq('id', user.id)
            .maybeSingle();

        if (mounted) {
          if (data == null || data['rol'] == 'pendiente') {
            _navegarA(const SeleccionRolScreen());
          } else {
            _navegarA(const MainLayout());
          }
        }
      } catch (e) {
        debugPrint('Error en Splash: $e');
        _navegarA(const MainLayout());
      }
    }
  }

  void _navegarA(Widget pantalla) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => pantalla),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [Color(0xFFEF4444), Color(0xFF7F1D1D)],
          ),
        ),
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final sceneWidth = math.min(constraints.maxWidth * 0.9, 440.0);
              final fondoHeight = sceneWidth * 0.58;
              final textoHeight = sceneWidth * 0.18;
              final sceneHeight = fondoHeight + textoHeight + 16;
              const clipInset = 30.0;
              const ovalInsetX = 0.0;
              const ovalInsetY = 0.0;
              final animWidth = sceneWidth - (clipInset * 2);
              final carWidth = sceneWidth * 0.62;
              final carHeight = fondoHeight * 0.70;

              final startX = -carWidth + 34;
              final midX = (animWidth - carWidth) * 0.50;
              final endX = animWidth + 26;

              final carTop = fondoHeight * 0.52 - (carHeight / 2);
              final glowWidth = carWidth * 1.04;
              final glowHeight = carHeight * 1.04;
              final glowLeft = midX + (carWidth - glowWidth) / 2;
              final glowTop = carTop - (glowHeight * 0.08);

              return AnimatedBuilder(
                animation: _sceneController,
                builder: (context, _) {
                  final xProgress = _carX.value;
                  final carLeft = xProgress <= 0.56
                      ? startX + (midX - startX) * (xProgress / 0.56)
                      : midX + (endX - midX) * ((xProgress - 0.56) / 0.44);

                  return SizedBox(
                    width: sceneWidth,
                    height: sceneHeight,
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Positioned.fill(
                          bottom: textoHeight + 16,
                          child: Image.asset(
                            'assets/animacionSplash/fondo_blanco.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        Positioned(
                          left: clipInset,
                          right: clipInset,
                          top: 0,
                          height: fondoHeight,
                          child: ClipPath(
                            clipper: _OvalInnerClipper(
                              insetX: ovalInsetX,
                              insetY: ovalInsetY,
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  left: carLeft,
                                  top: carTop,
                                  width: carWidth,
                                  height: carHeight,
                                  child: Opacity(
                                    opacity: _carOpacity.value,
                                    child: Image.asset(
                                      'assets/animacionSplash/auto.png',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: glowLeft,
                                  top: glowTop,
                                  width: glowWidth,
                                  height: glowHeight,
                                  child: IgnorePointer(
                                    child: Opacity(
                                      opacity: _glowOpacity.value,
                                      child: Image.asset(
                                        'assets/animacionSplash/brillo.png',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          top: fondoHeight + 16,
                          height: textoHeight,
                          child: Image.asset(
                            'assets/animacionSplash/a_todo_trapo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _OvalInnerClipper extends CustomClipper<Path> {
  final double insetX;
  final double insetY;

  _OvalInnerClipper({
    required this.insetX,
    required this.insetY,
  });

  @override
  Path getClip(Size size) {
    final rect = Rect.fromLTWH(
      insetX,
      insetY,
      size.width - (insetX * 2),
      size.height - (insetY * 2),
    );
    return Path()..addOval(rect);
  }

  @override
  bool shouldReclip(covariant _OvalInnerClipper oldClipper) {
    return insetX != oldClipper.insetX || insetY != oldClipper.insetY;
  }
}

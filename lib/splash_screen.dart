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
  late final Animation<double> _foamOpacity;
  late final Animation<double> _glowOpacity;
  late final Animation<double> _sceneFadeOut;
  late final Animation<double> _textSweepFade;

  @override
  void initState() {
    super.initState();

    _sceneController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    final scenePhase = CurvedAnimation(
      parent: _sceneController,
      curve: Curves.linear,
    );

    _carX = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 0.56)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 19.2,
      ),
      TweenSequenceItem(
        tween: ConstantTween(0.56),
        weight: 34.6,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.56, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 46.2,
      ),
    ]).animate(scenePhase);

    _carOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 7.7,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 73.1),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 19.2,
      ),
    ]).animate(scenePhase);

    _foamOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 19.2),
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 3.4,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 12.4),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 3.4,
      ),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 61.6),
    ]).animate(scenePhase);

    _glowOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 46.2),
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 4.8,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 0.4),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 4.8,
      ),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 43.8),
    ]).animate(scenePhase);

    _sceneFadeOut = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(
      CurvedAnimation(
        parent: _sceneController,
        curve: const Interval(0.82, 1.0, curve: Curves.easeInOut),
      ),
    );

    _textSweepFade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _sceneController,
        curve: const Interval(0.80, 1.0, curve: Curves.easeInOut),
      ),
    );

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
    final destino = await _resolverDestino();
    if (!mounted) return;
    _navegarA(destino);
  }

  Future<Widget> _resolverDestino() async {
    final user = supabase.auth.currentUser;
    if (user == null) return const MainLayout();

    try {
      final data = await supabase
          .from('perfiles_usuarios')
          .select('rol')
          .eq('id', user.id)
          .maybeSingle();

      if (data == null || data['rol'] == 'pendiente') {
        return const SeleccionRolScreen();
      }
      return const MainLayout();
    } catch (e) {
      debugPrint('Error en Splash: $e');
      return const MainLayout();
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
      body: AnimatedBuilder(
        animation: _sceneController,
        builder: (context, _) {
          return Container(
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
              final foamWidth = glowWidth + 14;
              final foamHeight = glowHeight + 30;
              final foamLeft = glowLeft - 8;
              final foamTop = glowTop - 15;

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
                    child: Opacity(
                      opacity: _sceneFadeOut.value,
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
                                    left: foamLeft,
                                    top: foamTop,
                                    width: foamWidth,
                                    height: foamHeight,
                                    child: IgnorePointer(
                                      child: Opacity(
                                        opacity: _foamOpacity.value,
                                        child: Image.asset(
                                          'assets/animacionSplash/Espuma.png',
                                          fit: BoxFit.contain,
                                        ),
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
                            child: ShaderMask(
                              blendMode: BlendMode.dstIn,
                              shaderCallback: (rect) {
                                final sweep = _textSweepFade.value;
                                final start =
                                    (sweep - 0.12).clamp(0.0, 1.0).toDouble();
                                final end = sweep.clamp(0.0, 1.0).toDouble();
                                return LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: const [
                                    Colors.transparent,
                                    Colors.transparent,
                                    Colors.white,
                                    Colors.white,
                                  ],
                                  stops: [0.0, start, end, 1.0],
                                ).createShader(rect);
                              },
                              child: Image.asset(
                                'assets/animacionSplash/a_todo_trapo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
                },
              ),
            ),
          );
        },
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

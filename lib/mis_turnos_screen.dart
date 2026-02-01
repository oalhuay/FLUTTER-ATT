import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class MisTurnosScreen extends StatefulWidget {
  final VoidCallback? onVolver;
  const MisTurnosScreen({super.key, this.onVolver});

  @override
  State<MisTurnosScreen> createState() => _MisTurnosScreenState();
}

class _MisTurnosScreenState extends State<MisTurnosScreen> {
  // --- LÓGICA CORE (Mantenida 100%) ---
  List<dynamic> _misTurnos = [];
  String _filtroActual = 'activo';
  int _paginaActual = 0;
  int _totalRegistros = 0;
  final int _porPagina = 7;
  bool cargando = true;
  final supabase = Supabase.instance.client;

  // --- SEMÁFORO Y TIMERS ---
  String ultimaActualizacion = "---";
  bool botonHabilitado = true;
  int segundosRestantes = 0;
  Timer? _timerBloqueo;
  Timer? _timerSemaforo;
  DateTime? _horaUltimaPeticion;
  Color _colorEstado = Colors.grey;

  // --- COLORES ATT! 2040 ---
  final Color azulATT = const Color(0xFF3ABEF9);
  final Color rojoATT = const Color(0xFFEF4444);
  final Color fondoFuturista = const Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _cargarMisTurnos();
  }

  @override
  void dispose() {
    _timerBloqueo?.cancel();
    _timerSemaforo?.cancel();
    super.dispose();
  }

  // --- MÉTODOS DE DATOS (Mantenidos y Optimizados) ---
  Future<void> _cargarMisTurnos() async {
    if (!mounted) return;
    setState(() {
      cargando = true;
      botonHabilitado = false;
    });

    try {
      final user = supabase.auth.currentUser;
      final desde = _paginaActual * _porPagina;
      final hasta = desde + _porPagina - 1;

      final response = await supabase
          .from('turnos')
          .select('*')
          .eq('user_id', user?.id ?? '')
          .eq('estado', _filtroActual)
          .order('fecha', ascending: true)
          .order('hora', ascending: true)
          .range(desde, hasta);

      final countResponse = await supabase
          .from('turnos')
          .select('id')
          .eq('user_id', user?.id ?? '')
          .eq('estado', _filtroActual);

      final ahora = DateTime.now();
      _horaUltimaPeticion = ahora;

      if (mounted) {
        setState(() {
          _misTurnos = response as List<dynamic>;
          _totalRegistros = countResponse.length;
          ultimaActualizacion = DateFormat('HH:mm:ss').format(ahora);
          cargando = false;
          segundosRestantes = 5;
          _colorEstado = Colors.green;
        });
        _iniciarTemporizadorBloqueo();
        _iniciarSemaforo();
      }
    } catch (e) {
      if (mounted) setState(() => cargando = false);
    }
  }

  Future<void> _cancelarTurno(dynamic idTurno) async {
    setState(() {
      _misTurnos.removeWhere((t) => t['id'].toString() == idTurno.toString());
    });
    try {
      await supabase
          .from('turnos')
          .update({'estado': 'cancelado'})
          .eq('id', idTurno);
      _cargarMisTurnos();
    } catch (e) {
      _cargarMisTurnos();
    }
  }

  void _iniciarTemporizadorBloqueo() {
    _timerBloqueo?.cancel();
    _timerBloqueo = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (segundosRestantes > 0) {
            segundosRestantes--;
          } else {
            botonHabilitado = true;
            timer.cancel();
          }
        });
      }
    });
  }

  void _iniciarSemaforo() {
    _timerSemaforo?.cancel();
    _timerSemaforo = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_horaUltimaPeticion == null) return;
      final diferencia = DateTime.now()
          .difference(_horaUltimaPeticion!)
          .inSeconds;
      Color nuevoColor = diferencia <= 30
          ? Colors.green
          : (diferencia <= 60 ? Colors.amber : Colors.red);
      if (mounted && _colorEstado != nuevoColor)
        setState(() => _colorEstado = nuevoColor);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondoFuturista,
      body: CustomScrollView(
        slivers: [
          // HEADER ESTILO 2040
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: azulATT,
                size: 20,
              ),
              onPressed: widget.onVolver,
            ),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    "MIS RESERVAS",
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 1,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.circle, size: 6, color: _colorEstado),
                      const SizedBox(width: 4),
                      Text(
                        "SYNC: $ultimaActualizacion",
                        style: TextStyle(
                          color: Colors.black38,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: TextButton.icon(
                  onPressed: botonHabilitado ? _cargarMisTurnos : null,
                  icon: Icon(
                    botonHabilitado
                        ? Icons.refresh_rounded
                        : Icons.hourglass_top_rounded,
                    size: 18,
                    color: azulATT,
                  ),
                  label: Text(
                    botonHabilitado ? "ACTUALIZAR" : "${segundosRestantes}S",
                    style: TextStyle(
                      color: azulATT,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // FILTROS BENTO
          SliverToBoxAdapter(
            child: Container(
              height: 60,
              margin: const EdgeInsets.symmetric(vertical: 10),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildBentoFilter("ACTIVOS", "activo"),
                  _buildBentoFilter("COMPLETADOS", "completado"),
                  _buildBentoFilter("CANCELADOS", "cancelado"),
                ],
              ),
            ),
          ),

          // LISTADO CON ANIMACIÓN
          cargando
              ? const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              : _misTurnos.isEmpty
              ? _buildEmptyState()
              : SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final turno = _misTurnos[index];
                    return _buildBentoTurnoCard(turno, index);
                  }, childCount: _misTurnos.length),
                ),

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
      bottomSheet: (!cargando && _totalRegistros > 0)
          ? _buildPaginacionFuturista()
          : null,
    );
  }

  Widget _buildBentoFilter(String etiqueta, String valor) {
    bool sel = _filtroActual == valor;
    return GestureDetector(
      onTap: () {
        if (!sel) {
          setState(() {
            _filtroActual = valor;
            _paginaActual = 0;
          });
          _cargarMisTurnos();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: sel ? azulATT : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            if (sel)
              BoxShadow(
                color: azulATT.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Center(
          child: Text(
            etiqueta,
            style: TextStyle(
              color: sel ? Colors.white : Colors.black45,
              fontWeight: FontWeight.w900,
              fontSize: 10,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBentoTurnoCard(Map<String, dynamic> turno, int index) {
    // FIX DE FECHA: Evita que se reste un día por zona horaria
    DateTime fecha = DateTime.parse(turno['fecha'].toString());
    String fechaLabel = DateFormat("EEEE d 'de' MMMM", "es").format(fecha);

    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 400 + (index * 100)),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    turno['lavadero_nombre'].toString().toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                Text(
                  "\$${turno['monto_pagado'] ?? '0'}",
                  style: TextStyle(
                    color: azulATT,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _iconLabel(Icons.calendar_today_rounded, fechaLabel),
                const SizedBox(width: 15),
                _iconLabel(Icons.access_time_rounded, "${turno['hora']} HS"),
              ],
            ),
            const Divider(height: 30),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "SERVICIOS",
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: Colors.black26,
                        ),
                      ),
                      Text(
                        turno['servicios'] ?? "Lavado Estándar",
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                if (turno['url_comprobante'] != null)
                  _circleActionButton(
                    Icons.receipt_long_rounded,
                    azulATT,
                    () async {
                      final url = Uri.parse(turno['url_comprobante']);
                      if (await canLaunchUrl(url))
                        await launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        );
                    },
                  ),
                if (_filtroActual == 'activo') ...[
                  const SizedBox(width: 10),
                  _circleActionButton(
                    Icons.close_rounded,
                    rojoATT,
                    () => _confirmarCancelacion(turno['id']),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconLabel(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: azulATT.withOpacity(0.5)),
        const SizedBox(width: 5),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Colors.black45,
          ),
        ),
      ],
    );
  }

  Widget _circleActionButton(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.layers_clear_rounded,
            size: 60,
            color: azulATT.withOpacity(0.1),
          ),
          const SizedBox(height: 16),
          const Text(
            "SIN ACTIVIDAD AQUÍ",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Colors.black12,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginacionFuturista() {
    int totalPaginas = (_totalRegistros / _porPagina).ceil();
    int bloqueActual = (_paginaActual / 3).floor();
    int inicioBloque = bloqueActual * 3;
    int finBloque = (inicioBloque + 2 < totalPaginas)
        ? inicioBloque + 2
        : totalPaginas - 1;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: _paginaActual > 0
                ? () {
                    setState(() => _paginaActual--);
                    _cargarMisTurnos();
                  }
                : null,
          ),

          for (int i = inicioBloque; i <= finBloque; i++)
            GestureDetector(
              onTap: () {
                setState(() => _paginaActual = i);
                _cargarMisTurnos();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 5),
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _paginaActual == i
                      ? azulATT
                      : Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "${i + 1}",
                  style: TextStyle(
                    color: _paginaActual == i ? Colors.white : Colors.black54,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: _paginaActual < totalPaginas - 1
                ? () {
                    setState(() => _paginaActual++);
                    _cargarMisTurnos();
                  }
                : null,
          ),
        ],
      ),
    );
  }

  void _confirmarCancelacion(dynamic id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: const Text(
          "¿Cancelar Turno?",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const Text("Esta acción no se puede deshacer."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("VOLVER"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: rojoATT,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              _cancelarTurno(id);
            },
            child: const Text(
              "SÍ, CANCELAR",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

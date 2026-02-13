import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'services/mp_service.dart';
import 'services/pdf_helper.dart';
import 'package:app_links/app_links.dart';

class ReservaScreen extends StatefulWidget {
  final dynamic lavadero;
  const ReservaScreen({super.key, required this.lavadero});

  @override
  State<ReservaScreen> createState() => _ReservaScreenState();
}

class _ReservaScreenState extends State<ReservaScreen>
    with WidgetsBindingObserver {
  late Stream<List<Map<String, dynamic>>> _turnosStream;
  final List<String> _serviciosSeleccionados = ["Lavado"];
  double _totalAPagar = 0.0;
  String? _horaSeleccionada;
  bool _esperandoPago = false;
  bool _pagoConfirmado = false; // Controla si mostramos la pantalla de éxito
  String? _pagoID; // Guarda el ID para mostrarlo en el comprobante
  bool _estaProcesando = false;
  DateTime _fechaSeleccionada = DateTime.now();
  final _appLinks = AppLinks();
  // Colores Oficiales ATT! (Paleta Futurista 2040)
  final Color azulATT = const Color(0xFF3ABEF9);
  final Color rojoATT = const Color(0xFFEF4444);
  final Color fondoSoft = const Color(0xFFF0F4F8);

  @override
  void initState() {
    super.initState();
    // Validación inicial de fecha laboral
    if (!_esDiaLaboral(_fechaSeleccionada)) {
      _fechaSeleccionada = _fechaSeleccionada.add(const Duration(days: 1));
      int safeGuard = 0;
      while (!_esDiaLaboral(_fechaSeleccionada) && safeGuard < 7) {
        _fechaSeleccionada = _fechaSeleccionada.add(const Duration(days: 1));
        safeGuard++;
      }
    }
    _appLinks.uriLinkStream.listen((uri) {
      final String path = uri.host;

      if (path == "pago-fallido") {
        setState(() {
          _estaProcesando = false;
          _esperandoPago = false;
        });
        _mostrarMensajeError("No se realizó el pago. Por favor, reintente.");
      } else if (path == "pago-exitoso" || path == "pago-finalizado") {
        final paymentId = uri.queryParameters['payment_id'];

        // CAMBIO AQUÍ: Activamos la vista de éxito directamente
        setState(() {
          _pagoConfirmado = true;
          _pagoID = paymentId;
          _estaProcesando = false;
          _esperandoPago = false;
        });

        // Seguimos registrando en la base de datos por detrás
        _ejecutarRegistroEnBaseDeDatos(
          status: 'approved',
          paymentId: paymentId ?? '',
        );
      }
    });
    _calcularTotal();
    _inicializarStream();
    _calcularTotal();
    _inicializarStream();
    _configurarListenerRetorno();
  }

  void _configurarListenerRetorno() {
    _appLinks.uriLinkStream.listen((uri) {
      // Convertimos a string para buscar "pago-exitoso" en cualquier parte de la URL
      final urlString = uri.toString();

      if (urlString.contains("pago-exitoso")) {
        // Mercado Pago suele pegar los parámetros después del path.
        // Intentamos obtener el payment_id de los queryParameters normales
        String? paymentId = uri.queryParameters['payment_id'];

        // Si por el formato de la URL (#/) no lo encuentra, lo buscamos manualmente en el string
        if (paymentId == null && urlString.contains("payment_id=")) {
          paymentId = urlString.split("payment_id=").last.split("&").first;
        }

        setState(() {
          _pagoConfirmado =
              true; // Activa la vista de éxito con el botón de volver
          _pagoID = paymentId;
          _estaProcesando = false;
          _esperandoPago = false;
        });

        if (paymentId != null) {
          // Ejecutamos el registro. Nota: El webhook de Vercel ya debería estar
          // haciendo esto, pero dejarlo aquí sirve como respaldo (fallback).
          _ejecutarRegistroEnBaseDeDatos(
            status: 'approved',
            paymentId: paymentId,
          );
        }
      } else if (urlString.contains("pago-fallido")) {
        setState(() {
          _estaProcesando = false;
          _esperandoPago = false;
        });
        _mostrarMensajeError("El pago no pudo ser procesado. Reintente.");
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _procesarPagoYReserva(BuildContext context, String hora) async {
    final usuario = Supabase.instance.client.auth.currentUser;
    if (usuario == null) return;

    setState(() {
      _estaProcesando = true;
      _esperandoPago = true;
    });

    try {
      final mp = MPService();

      // IMPORTANTE: Los nombres de estas llaves (fecha_turno, hora_turno, etc)
      // deben ser EXACTAMENTE iguales a los que busca el Webhook en Node.js.
      // En reserva_screen.dart
      final urlPago = await mp.crearPreferencia(
        titulo: "Reserva ATT: ${widget.lavadero['razon_social']}",
        precio: _totalAPagar,
        metadata: {
          "user_id": usuario.id, // Verifica que el servidor busque "user_id"
          "fecha_turno": _fechaSeleccionada.toIso8601String().split('T')[0],
          "hora_turno": hora,
          "lavadero_nombre": widget.lavadero['razon_social'],
          "servicios": _serviciosSeleccionados.isEmpty
              ? "Lavado General"
              : _serviciosSeleccionados.join(", "),
        },
      );

      if (urlPago != null) {
        // 1. Abrimos Mercado Pago primero
        final bool lanzado = await launchUrl(
          Uri.parse(urlPago),
          mode: LaunchMode.externalApplication,
        );

        if (lanzado) {
          // 2. Dejamos hasta 3 segundos la pantalla actual antes de cerrarla
          await Future.delayed(const Duration(seconds: 3));

          // 3. Cerramos esta pantalla para seguir el flujo en Mercado Pago
          if (context.mounted) {
            setState(() {
              _estaProcesando = false;
              _esperandoPago = false;
            });

            // Cerramos la pantalla de reserva para continuar solo en Mercado Pago
            Navigator.pop(context);
          }
        } else if (context.mounted) {
          setState(() {
            _estaProcesando = false;
            _esperandoPago = false;
          });
          _mostrarMensajeError("No se pudo abrir Mercado Pago.");
        }
      } else {
        if (context.mounted) {
          setState(() {
            _estaProcesando = false;
            _esperandoPago = false;
          });
          _mostrarMensajeError("No se pudo conectar con el servidor de pagos.");
        }
      }
    } catch (e) {
      setState(() {
        _estaProcesando = false;
        _esperandoPago = false;
      });
      debugPrint("Error: $e");
    }
  }

  void _mostrarMensajeError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: Colors.red.shade800,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: "OK",
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  void _mostrarExitoFinal(Map<String, dynamic> factura) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        title: const Icon(
          Icons.check_circle_rounded,
          color: Colors.green,
          size: 70,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "¡Turno confirmado!",
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 10),
            const Text(
              "Tu reserva y comprobante ya están listos en la sección 'Mis Turnos'.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444), // Rojo ATT!
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size(double.infinity, 45),
            ),
            onPressed: () {
              PdfHelper.descargarComprobante(
                nroFactura: factura['payment_id'].toString(),
                lavadero: widget.lavadero['razon_social'],
                fecha: DateFormat(
                  'dd/MM/yyyy HH:mm',
                ).format(DateTime.parse(factura['fecha_emision'])),
                servicios: factura['servicios'] ?? "Servicio ATT!",
                total: (factura['total'] as num).toDouble(),
              );
            },
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            label: const Text(
              "DESCARGAR COMPROBANTE",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text(
                "VOLVER AL MAPA",
                style: TextStyle(
                  color: Color(0xFF3ABEF9),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _ejecutarRegistroEnBaseDeDatos({
    required String status,
    required String paymentId,
  }) async {
    if (status != 'approved') return;

    try {
      setState(() => _estaProcesando = true);

      // PASO 1: Esperamos un poco más (5-7 seg) para que el Webhook trabaje en Vercel
      int intentos = 0;
      Map<String, dynamic>? factura;

      while (intentos < 5 && factura == null) {
        await Future.delayed(const Duration(seconds: 3));
        factura = await Supabase.instance.client
            .from('facturas')
            .select()
            .eq('payment_id', paymentId)
            .maybeSingle();
        intentos++;
        debugPrint("🔍 Buscando factura (Intento $intentos)...");
      }

      // PASO 2: Si el servidor lo creó, mostramos el éxito
      if (factura != null) {
        _mostrarExitoFinal(factura);
      } else {
        // Si el servidor falló después de 15 seg, activamos el plan de respaldo
        debugPrint(
          "⚠️ Webhook no respondió a tiempo. Agendando desde la App...",
        );
        // Aquí pones tu código de insert de factura y turno que ya tenías
      }
    } catch (e) {
      debugPrint("❌ Error en el proceso final: $e");
    } finally {
      setState(() {
        _estaProcesando = false;
        _esperandoPago = false;
      });
    }
  }

  void _inicializarStream() {
    final nombreLavadero = widget.lavadero['razon_social'];
    setState(() {
      _turnosStream = Supabase.instance.client
          .from('turnos')
          .stream(primaryKey: ['id'])
          .eq('lavadero_nombre', nombreLavadero);
    });
  }

  void _calcularTotal() {
    double tempTotal = 0.0;
    final Map<String, dynamic> precios =
        widget.lavadero['servicios_precios'] ?? {};
    for (var servicio in _serviciosSeleccionados) {
      double precioServicio = (precios[servicio] ?? 5000.0).toDouble();
      tempTotal += precioServicio;
    }
    setState(() => _totalAPagar = tempTotal);
  }

  List<String> _generarHorarios() {
    try {
      final String aperturaRaw =
          widget.lavadero['hora_apertura']?.toString() ?? "09:00 AM";
      final String cierreRaw =
          widget.lavadero['hora_cierre']?.toString() ?? "18:00 PM";
      final int intervalo = widget.lavadero['duracion_estandar'] ?? 60;

      DateTime parseManual(String raw) {
        raw = raw.toUpperCase().trim();
        final digits = raw.replaceAll(RegExp(r'[^0-9:]'), '');
        final parts = digits.split(':');
        int hour = int.parse(parts[0]);
        int minute = parts.length > 1 ? int.parse(parts[1]) : 0;
        if (raw.contains("PM") && hour < 12) hour += 12;
        if (raw.contains("AM") && hour == 12) hour = 0;
        return DateTime(2026, 1, 1, hour, minute);
      }

      DateTime inicio = parseManual(aperturaRaw);
      DateTime fin = parseManual(cierreRaw);

      if (fin.isBefore(inicio) || fin.isAtSameMomentAs(inicio)) {
        fin = inicio.add(const Duration(hours: 8));
      }

      List<String> slots = [];
      int safeLimit = 0;
      while (inicio.isBefore(fin) && safeLimit < 50) {
        slots.add(
          "${inicio.hour.toString().padLeft(2, '0')}:${inicio.minute.toString().padLeft(2, '0')}",
        );
        inicio = inicio.add(Duration(minutes: intervalo));
        safeLimit++;
      }
      return slots;
    } catch (e) {
      return ["09:00", "10:00", "11:00", "15:00", "16:00"];
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Solo nos interesa cuando el usuario VUELVE (resumed)
    if (state == AppLifecycleState.resumed) {
      // Si después de 2 segundos de volver no entró el Deep Link de éxito/error,
      // simplemente quitamos el spinner de carga para que el usuario pueda reintentar.
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _estaProcesando) {
          setState(() {
            _estaProcesando = false;
            _esperandoPago = false;
          });
        }
      });
    }
  }

  bool _esDiaLaboral(DateTime day) {
    final diasAbiertos = List<String>.from(
      widget.lavadero['dias_abierto'] ?? [],
    );
    final mapDias = {
      DateTime.monday: 'Lun',
      DateTime.tuesday: 'Mar',
      DateTime.wednesday: 'Mie',
      DateTime.thursday: 'Jue',
      DateTime.friday: 'Vie',
      DateTime.saturday: 'Sab',
      DateTime.sunday: 'Dom',
    };
    return diasAbiertos.contains(mapDias[day.weekday]);
  }

  @override
  Widget build(BuildContext context) {
    final horarios = _generarHorarios();
    final Map<String, dynamic> precios =
        widget.lavadero['servicios_precios'] ?? {};
    return Scaffold(
      backgroundColor: fondoSoft,
      body: _pagoConfirmado
          ? _buildPantallaExito()
          : Stack(
              children: [
                CustomScrollView(
                  slivers: [
                    // HEADER PREMIUM BENTO
                    SliverAppBar(
                      expandedHeight: 120,
                      floating: true,
                      pinned: true,
                      backgroundColor: Colors.white,
                      elevation: 0,
                      flexibleSpace: FlexibleSpaceBar(
                        centerTitle: true,
                        title: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: azulATT.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            widget.lavadero['razon_social'].toUpperCase(),
                            style: TextStyle(
                              color: azulATT,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // BENTO BOX 1: FECHA
                    SliverToBoxAdapter(
                      child: _buildBentoCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _bentoHeader(
                              "Fecha del turno",
                              Icons.calendar_today_rounded,
                            ),
                            const SizedBox(height: 12),
                            InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _fechaSeleccionada,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 30),
                                  ),
                                  selectableDayPredicate: _esDiaLaboral,
                                  locale: const Locale("es", "AR"),
                                );
                                if (picked != null) {
                                  setState(() => _fechaSeleccionada = picked);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: azulATT.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: azulATT.withOpacity(0.1),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      DateFormat("EEEE d 'de' MMMM", "es")
                                          .format(_fechaSeleccionada)
                                          .toUpperCase(),
                                      style: TextStyle(
                                        color: azulATT,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(
                                      Icons.edit_calendar_rounded,
                                      color: azulATT,
                                      size: 22,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // BENTO BOX 2: SERVICIOS
                    SliverToBoxAdapter(
                      child: _buildBentoCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _bentoHeader(
                              "Servicios y Tarifas",
                              Icons.auto_awesome_rounded,
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: precios.keys.map((s) {
                                bool isSel = _serviciosSeleccionados.contains(
                                  s,
                                );
                                return ChoiceChip(
                                  label: Text("$s | \$${precios[s]}"),
                                  selected: isSel,
                                  onSelected: s == "Lavado"
                                      ? null
                                      : (val) {
                                          setState(() {
                                            val
                                                ? _serviciosSeleccionados.add(s)
                                                : _serviciosSeleccionados
                                                      .remove(s);
                                            _calcularTotal();
                                          });
                                        },
                                  selectedColor: azulATT,
                                  labelStyle: TextStyle(
                                    color: isSel
                                        ? Colors.white
                                        : Colors.black87,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                  backgroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(
                                      color: isSel ? azulATT : Colors.black12,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // BENTO BOX 3: HORARIOS
                    SliverToBoxAdapter(
                      child: _buildBentoCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _bentoHeader(
                              "Horarios disponibles",
                              Icons.alarm_rounded,
                            ),
                            const SizedBox(height: 12),
                            StreamBuilder<List<Map<String, dynamic>>>(
                              stream: _turnosStream,
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const LinearProgressIndicator();
                                }
                                final fechaIso = _fechaSeleccionada
                                    .toIso8601String()
                                    .split('T')[0];
                                final ocupados = snapshot.data!
                                    .where(
                                      (t) =>
                                          t['fecha'].toString() == fechaIso &&
                                          t['estado'] != 'cancelado',
                                    )
                                    .map(
                                      (t) =>
                                          t['hora'].toString().substring(0, 5),
                                    )
                                    .toList();

                                return GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 4,
                                        childAspectRatio: 2.1,
                                        crossAxisSpacing: 10,
                                        mainAxisSpacing: 10,
                                      ),
                                  itemCount: horarios.length,
                                  itemBuilder: (context, index) {
                                    final h = horarios[index];
                                    bool isOcupado = ocupados.contains(h);
                                    bool isSel = _horaSeleccionada == h;
                                    return InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: isOcupado
                                          ? null
                                          : () => setState(
                                              () => _horaSeleccionada = h,
                                            ),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isOcupado
                                              ? Colors.black12
                                              : (isSel
                                                    ? azulATT
                                                    : Colors.white),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: isSel
                                                ? azulATT
                                                : Colors.black12,
                                          ),
                                          boxShadow: [
                                            if (isSel)
                                              BoxShadow(
                                                color: azulATT.withOpacity(0.3),
                                                blurRadius: 8,
                                              ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Text(
                                            h,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: isSel
                                                  ? Colors.white
                                                  : (isOcupado
                                                        ? Colors.black26
                                                        : Colors.black87),
                                              decoration: isOcupado
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 160)),
                  ],
                ),

                // STICKY GLASS FOOTER (2040 EDITION)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildGlassFooter(),
                ),

                if (_estaProcesando)
                  Container(
                    color: Colors.black45,
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 28),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.72),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(color: Colors.white),
                            const SizedBox(height: 14),
                            Text(
                              _esperandoPago
                                  ? "Abriendo Mercado Pago..."
                                  : "Procesando pago...",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            if (_esperandoPago) ...[
                              const SizedBox(height: 8),
                              const Text(
                                "Esta pantalla se cerrará en 3 segundos.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildBentoCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _bentoHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: azulATT),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: Colors.black38,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildGlassFooter() {
    bool canPay = _horaSeleccionada != null;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 25,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "PRECIO ESTIMADO",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.black38,
                  ),
                ),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                    color: rojoATT,
                  ),
                  child: Text("\$${_totalAPagar.toStringAsFixed(0)}"),
                ),
              ],
            ),
            const SizedBox(width: 24),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: canPay ? rojoATT : Colors.black12,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 22),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  elevation: canPay ? 4 : 0,
                ),
                onPressed: canPay
                    ? () => _confirmarAntesDePagar(context, _horaSeleccionada!)
                    : null,
                child: const Text(
                  "RESERVAR TURNO",
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPantallaExito() {
    return Center(
      child: _buildBentoCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              color: Colors.green,
              size: 80,
            ),
            const SizedBox(height: 20),
            Text(
              "¡PAGO CONFIRMADO!",
              style: TextStyle(
                color: azulATT,
                fontWeight: FontWeight.w900,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Tu turno ha sido reservado.\nYa puedes descargar tu comprobante.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 30),

            // --- BOTÓN DINÁMICO DE PDF ---
            FutureBuilder<Map<String, dynamic>?>(
              // Buscamos la factura usando el ID que nos dio el Webhook
              future: MPService().buscarFacturaEnSupabase(
                paymentId: _pagoID ?? "",
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }

                if (snapshot.hasData && snapshot.data != null) {
                  final factura = snapshot.data!;
                  return ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: rojoATT,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                    label: const Text(
                      "DESCARGAR COMPROBANTE",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () => PdfHelper.descargarComprobante(
                      nroFactura: factura['payment_id'].toString(),
                      lavadero: widget.lavadero['razon_social'],
                      fecha: DateFormat(
                        'dd/MM/yyyy HH:mm',
                      ).format(DateTime.parse(factura['fecha_emision'])),
                      servicios: factura['servicios'] ?? "Lavado Premium ATT",
                      total: (factura['total'] as num).toDouble(),
                    ),
                  );
                }
                // Si el webhook tarda un poco, mostramos este mensaje
                return const Text(
                  "Generando factura digital...",
                  style: TextStyle(fontSize: 12),
                );
              },
            ),

            const SizedBox(height: 20),

            TextButton(
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              child: Text(
                "VOLVER A LA PÁGINA PRINCIPAL",
                style: TextStyle(color: azulATT, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmarAntesDePagar(BuildContext context, String hora) {
    final parentContext = context;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        title: const Text(
          "Confirmar Reserva",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text(
          "Día: ${DateFormat('dd/MM').format(_fechaSeleccionada)}\nHora: $hora hs\nTotal: \$$_totalAPagar",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("CANCELAR"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _procesarPagoYReserva(parentContext, hora);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: azulATT,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              "SÍ, PAGAR",
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

//TENDENCIA tendencia de Bento Grid & Glassmorphism 2026 VER INFO EN INTERNET UX/UI
//tambien la 2040 queda ahora.

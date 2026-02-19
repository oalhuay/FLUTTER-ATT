import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:html' as html;

class PdfHelper {
  static double? _buscarPrecioServicio(
    Map<String, dynamic> precios,
    String servicio,
  ) {
    final exacto = precios[servicio];
    if (exacto is num) return exacto.toDouble();
    final exactoParse = double.tryParse(exacto?.toString() ?? '');
    if (exactoParse != null) return exactoParse;

    final objetivo = servicio.trim().toLowerCase();
    for (final entry in precios.entries) {
      if (entry.key.toString().trim().toLowerCase() == objetivo) {
        final raw = entry.value;
        if (raw is num) return raw.toDouble();
        return double.tryParse(raw?.toString() ?? '');
      }
    }
    return null;
  }

  static Future<void> descargarComprobante({
    required String nroFactura,
    required String lavadero,
    required String fecha,
    required String servicios,
    required double total,
    String? fechaTurno,
    String? horaTurno,
    Map<String, dynamic>? serviciosPrecios,
  }) async {
    final pdf = _construirDocumento(
      nroFactura: nroFactura,
      lavadero: lavadero,
      fecha: fecha,
      servicios: servicios,
      total: total,
      fechaTurno: fechaTurno,
      horaTurno: horaTurno,
      serviciosPrecios: serviciosPrecios,
    );

    final Uint8List bytes = await pdf.save();
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);

    html.AnchorElement(href: url)
      ..setAttribute("download", "ATT_Factura_${nroFactura.substring(0, 8)}.pdf")
      ..click();

    html.Url.revokeObjectUrl(url);
  }

  static pw.Document _construirDocumento({
    required String nroFactura,
    required String lavadero,
    required String fecha,
    required String servicios,
    required double total,
    String? fechaTurno,
    String? horaTurno,
    Map<String, dynamic>? serviciosPrecios,
  }) {
    final pdf = pw.Document();
    final azulATT = PdfColor.fromHex('#3ABEF9');
    final rojoATT = PdfColor.fromHex('#EF4444');
    final Map<String, dynamic> precios = serviciosPrecios ?? {};
    final List<String> serviciosLista = servicios
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(35),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      "ATT! A TODO TRAPO",
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: azulATT,
                      ),
                    ),
                    pw.Text(
                      "COMPROBANTE OFICIAL",
                      style: pw.TextStyle(color: PdfColors.grey, fontSize: 10),
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Container(height: 1, color: azulATT),
                pw.SizedBox(height: 30),
                pw.Text(
                  "ID DE TRANSACCION: #$nroFactura",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text("EMITIDO EL: $fecha"),
                if ((fechaTurno ?? '').isNotEmpty || (horaTurno ?? '').isNotEmpty)
                  pw.Text(
                    "TURNO: ${fechaTurno ?? ''} ${horaTurno ?? ''}".trim(),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                pw.SizedBox(height: 30),
                pw.Text(
                  "ESTABLECIMIENTO",
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  lavadero,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  "RESUMEN DE SERVICIOS",
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                ...serviciosLista.map((servicio) {
                  final precio = _buscarPrecioServicio(precios, servicio);
                  final precioTexto = precio != null
                      ? "\$${precio.toStringAsFixed(0)}"
                      : "s/p";
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 6),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            servicio,
                            style: const pw.TextStyle(fontSize: 12),
                          ),
                        ),
                        pw.Text(
                          precioTexto,
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: rojoATT,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                pw.Spacer(),
                pw.Divider(color: PdfColors.grey300),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      "TOTAL ABONADO",
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      "\$${total.toStringAsFixed(2)}",
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: rojoATT,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 40),
                pw.Center(
                  child: pw.Text(
                    "Este comprobante confirma que el pago fue procesado exitosamente.",
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf;
  }
}

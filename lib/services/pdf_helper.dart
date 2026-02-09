import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
// Importante: Este import solo funcionará en Web.
import 'dart:html' as html;

class PdfHelper {
  static Future<void> descargarComprobante({
    required String nroFactura,
    required String lavadero,
    required String fecha,
    required String servicios,
    required double total,
  }) async {
    final pdf = _construirDocumento(
      nroFactura: nroFactura,
      lavadero: lavadero,
      fecha: fecha,
      servicios: servicios,
      total: total,
    );

    final Uint8List bytes = await pdf.save();

    // Lógica de descarga optimizada para el nuevo sistema
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);

    html.AnchorElement(href: url)
      ..setAttribute(
        "download",
        "ATT_Factura_${nroFactura.substring(0, 8)}.pdf",
      )
      ..click();

    html.Url.revokeObjectUrl(url);
  }

  static pw.Document _construirDocumento({
    required String nroFactura,
    required String lavadero,
    required String fecha,
    required String servicios,
    required double total,
  }) {
    final pdf = pw.Document();

    // Colores oficiales ATT! 2040
    final azulATT = PdfColor.fromHex('#3ABEF9');
    final rojoATT = PdfColor.fromHex('#EF4444');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(35),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Cabecera Futurista
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

                // Datos de la Transacción (Del nuevo sistema)
                pw.Text(
                  "ID DE TRANSACCIÓN: #$nroFactura",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text("EMITIDO EL: $fecha"),
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
                pw.Bullet(
                  text: servicios,
                  style: const pw.TextStyle(fontSize: 12),
                ),

                pw.Spacer(),
                pw.Divider(color: PdfColors.grey300),

                // Total con el Rojo ATT!
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
                    "Este comprobante confirma que el pago fue procesado exitosamente a través de Mercado Pago.",
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

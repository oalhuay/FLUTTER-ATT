import 'dart:typed_data'; // Necesario para Uint8List
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfHelper {
  // 1. FUNCIÓN PARA OBTENER BYTES (Para subir a Storage)
  static Future<Uint8List> obtenerBytesPDF({
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
    return pdf.save(); // Retorna los bytes crudos del PDF
  }

  // 2. FUNCIÓN PARA IMPRIMIR (La que ya tenías)
  static Future<void> generarComprobante({
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

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  // --- FUNCIÓN PRIVADA PARA NO REPETIR EL DISEÑO ---
  static pw.Document _construirDocumento({
    required String nroFactura,
    required String lavadero,
    required String fecha,
    required String servicios,
    required double total,
  }) {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      "ATT - A TODO TRAPO",
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      "COMPROBANTE DIGITAL",
                      style: pw.TextStyle(color: PdfColors.grey),
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.SizedBox(height: 10),
                pw.Text(
                  "Factura Nro: #$nroFactura",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text("Fecha de emisión: $fecha"),
                pw.SizedBox(height: 20),
                pw.Text(
                  "Detalle del Lavadero:",
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(lavadero),
                pw.SizedBox(height: 20),
                pw.Text(
                  "Servicios contratados:",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Bullet(text: servicios),
                pw.Spacer(),
                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      "TOTAL PAGADO:",
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      "\$${total.toStringAsFixed(2)}",
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Center(
                  child: pw.Text(
                    "Este es un comprobante válido de reserva para el lavadero.",
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

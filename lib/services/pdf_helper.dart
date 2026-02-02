import 'dart:typed_data'; // Necesario para Uint8List
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
// 1. PASO IMPORTANTE: Esta librería permite "hablar" con el navegador Chrome
import 'dart:html' as html;

class PdfHelper {
  // --- 1. FUNCIÓN PARA DESCARGAR (La que reemplaza a la impresión molesta) ---
  static Future<void> descargarComprobante({
    required String nroFactura,
    required String lavadero,
    required String fecha, 
    required String servicios,
    required double total,
  }) async {
    // Generamos el documento usando tu función privada de abajo
    final pdf = _construirDocumento(
      nroFactura: nroFactura,
      lavadero: lavadero,
      fecha: fecha,
      servicios: servicios,
      total: total,
    );

    // Guardamos el PDF en una lista de bytes
    final Uint8List bytes = await pdf.save();

    // LÓGICA DE DESCARGA WEB:
    // Creamos un "Blob" (un archivo virtual en la memoria del navegador)
    final blob = html.Blob([bytes], 'application/pdf');

    // Creamos una URL temporal para ese archivo
    final url = html.Url.createObjectUrlFromBlob(blob);

    // Creamos un link invisible, le ponemos nombre y le hacemos "click" solo
    html.AnchorElement(href: url)
      ..setAttribute("download", "ATT! COMPROBANTE $nroFactura.pdf")
      ..click();

    // Limpiamos la memoria
    html.Url.revokeObjectUrl(url);
  }

  // --- 2. FUNCIÓN PARA OBTENER BYTES (La mantengo por si subís a Storage) ---
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
    return pdf.save();
  }

  // --- 3. FUNCIÓN PRIVADA (Tu diseño original, no se toca nada) ---
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

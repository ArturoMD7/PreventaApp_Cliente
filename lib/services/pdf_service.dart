import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/negocio.dart';
import 'pdf_output_stub.dart'
    if (dart.library.html) 'pdf_output_web.dart'
    if (dart.library.io) 'pdf_output_io.dart';

class PdfService {
  static Future<void> imprimirRecibo({
    required Map<String, dynamic> pedido,
    required List<Map<String, dynamic>> detalles,
    required Negocio? negocio,
  }) async {
    final pdf = pw.Document();
    final total = (pedido['total'] as num?)?.toDouble() ?? 0.0;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          80 * PdfPageFormat.mm,
          200 * PdfPageFormat.mm,
        ),
        margin: const pw.EdgeInsets.all(8),
        build: (_) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                negocio?.nombreNegocio ??
                    pedido['negocios']?['nombre_negocio'] ??
                    'Tienda',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              if (negocio?.ticketHeader != null &&
                  negocio!.ticketHeader!.isNotEmpty)
                pw.Text(
                  negocio.ticketHeader!,
                  style: pw.TextStyle(fontSize: 6),
                  textAlign: pw.TextAlign.center,
                ),
              pw.SizedBox(height: 4),
              pw.Divider(height: 1, thickness: 1),
              pw.SizedBox(height: 2),
              _infoRow('Fecha:',
                  DateFormat('dd/MM/yy HH:mm').format(
                      DateTime.tryParse(pedido['fecha'] ?? '') ??
                          DateTime.now())),
              _infoRow(
                  'Pedido:',
                  '#${(pedido['id'] as String).substring(0, 8)}'),
              _infoRow(
                  'Estado:',
                  (pedido['estado'] ?? 'pendiente')
                      .toString()
                      .replaceAll('_', ' ')),
              pw.SizedBox(height: 2),
              pw.Divider(height: 1, thickness: 1),
              pw.SizedBox(height: 2),
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 5,
                    child: pw.Text('Producto',
                        style: pw.TextStyle(
                            fontSize: 6,
                            fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text('Cant',
                        style: pw.TextStyle(
                            fontSize: 6,
                            fontWeight: pw.FontWeight.bold),
                        textAlign: pw.TextAlign.center),
                  ),
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text('Total',
                        style: pw.TextStyle(
                            fontSize: 6,
                            fontWeight: pw.FontWeight.bold),
                        textAlign: pw.TextAlign.right),
                  ),
                ],
              ),
              pw.SizedBox(height: 2),
              ...detalles.map((d) {
                final nombre =
                    d['productos']?['nombre'] ?? 'Producto';
                final cant = d['cantidad'] ?? 1;
                final sub =
                    (d['subtotal'] as num?)?.toDouble() ?? 0.0;
                final precio =
                    (d['precio_unitario'] as num?)?.toDouble() ??
                        0.0;
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 1),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 5,
                        child: pw.Column(
                          crossAxisAlignment:
                              pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(nombre,
                                style: pw.TextStyle(
                                    fontSize: 6)),
                            pw.Text(
                                '${precio.toStringAsFixed(2)} c/u',
                                style: pw.TextStyle(
                                    fontSize: 5,
                                    color: PdfColors.grey600)),
                          ],
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text('$cant',
                            style:
                                pw.TextStyle(fontSize: 6),
                            textAlign: pw.TextAlign.center),
                      ),
                      pw.Expanded(
                        flex: 3,
                        child: pw.Text(
                            '\$${sub.toStringAsFixed(2)}',
                            style:
                                pw.TextStyle(fontSize: 6),
                            textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
                );
              }),
              pw.SizedBox(height: 2),
              pw.Divider(height: 1, thickness: 1),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment:
                    pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL',
                      style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold)),
                  pw.Text('\$${total.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Divider(height: 1, thickness: 1),
              if (negocio?.ticketFooter != null &&
                  negocio!.ticketFooter!.isNotEmpty)
                pw.Text(
                  negocio.ticketFooter!,
                  style: pw.TextStyle(fontSize: 6),
                  textAlign: pw.TextAlign.center,
                ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Gracias por tu compra',
                style: pw.TextStyle(fontSize: 6),
                textAlign: pw.TextAlign.center,
              ),
            ],
          );
        },
      ),
    );

    final reciboBytes = await pdf.save();
    await outputPdf(
      reciboBytes,
      filename:
          'recibo_${(pedido['id'] as String).substring(0, 8)}.pdf',
    );
  }

  static Future<void> imprimirPdf({
    required Map<String, dynamic> pedido,
    required List<Map<String, dynamic>> detalles,
    required Negocio? negocio,
  }) async {
    final pdf = pw.Document();
    final total = (pedido['total'] as num?)?.toDouble() ?? 0.0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (_) {
          final boldStyle = pw.TextStyle(
              fontWeight: pw.FontWeight.bold, fontSize: 10);
          final normalStyle =
              pw.TextStyle(fontSize: 10);

          return [
            pw.Center(
              child: pw.Column(
                crossAxisAlignment:
                    pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    negocio?.nombreNegocio ??
                        pedido['negocios']?['nombre_negocio'] ??
                        'Tienda',
                    style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold),
                  ),
                  if (negocio?.ticketHeader != null &&
                      negocio!.ticketHeader!.isNotEmpty)
                    pw.Text(
                      negocio.ticketHeader!,
                      style:
                          pw.TextStyle(fontSize: 10),
                    ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Center(
              child: pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  'PEDIDO',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border:
                    pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment:
                    pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(children: [
                    pw.Text('Fecha: ', style: boldStyle),
                    pw.Text(
                        DateFormat('dd/MM/yyyy HH:mm').format(
                            DateTime.tryParse(
                                    pedido['fecha'] ?? '') ??
                                DateTime.now()),
                        style: normalStyle),
                  ]),
                  pw.SizedBox(height: 4),
                  pw.Row(children: [
                    pw.Text('Pedido: ', style: boldStyle),
                    pw.Text(
                        '#${(pedido['id'] as String).substring(0, 8)}',
                        style: normalStyle),
                  ]),
                  pw.SizedBox(height: 4),
                  pw.Row(children: [
                    pw.Text('Estado: ', style: boldStyle),
                    pw.Text(
                        (pedido['estado'] ?? 'pendiente')
                            .toString()
                            .replaceAll('_', ' '),
                        style: normalStyle),
                  ]),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Productos',
                style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(
                  color: PdfColors.grey400),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200),
                  children: [
                    _tableHeader('Producto'),
                    _tableHeader('Cant.'),
                    _tableHeader('Precio'),
                    _tableHeader('Subtotal',
                        align: pw.TextAlign.right),
                  ],
                ),
                ...detalles.map((d) {
                  final nombre =
                      d['productos']?['nombre'] ?? 'Producto';
                  final cant = d['cantidad'] ?? 1;
                  final precio =
                      (d['precio_unitario'] as num?)
                              ?.toDouble() ??
                          0.0;
                  final sub =
                      (d['subtotal'] as num?)?.toDouble() ??
                          0.0;
                  return pw.TableRow(
                    children: [
                      _tableCell(nombre),
                      _tableCell('$cant',
                          align: pw.TextAlign.center),
                      _tableCell(
                          '\$${precio.toStringAsFixed(2)}',
                          align: pw.TextAlign.right),
                      _tableCell(
                          '\$${sub.toStringAsFixed(2)}',
                          align: pw.TextAlign.right),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Container(
              alignment: pw.Alignment.centerRight,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(
                    color: PdfColors.blue800, width: 2),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(
                'TOTAL: \$${total.toStringAsFixed(2)}',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
            ),
            pw.SizedBox(height: 30),
            if (negocio?.ticketFooter != null &&
                negocio!.ticketFooter!.isNotEmpty)
              pw.Center(
                child: pw.Text(
                  negocio.ticketFooter!,
                  style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600),
                ),
              ),
            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Text(
                'Documento generado el ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                style: pw.TextStyle(
                    fontSize: 8, color: PdfColors.grey500),
              ),
            ),
          ];
        },
      ),
    );

    final pdfBytes = await pdf.save();
    await outputPdf(
      pdfBytes,
      filename:
          'pedido_${(pedido['id'] as String).substring(0, 8)}.pdf',
    );
  }

  static pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 1),
      child: pw.Row(
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: 6, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(width: 4),
          pw.Text(value, style: pw.TextStyle(fontSize: 6)),
        ],
      ),
    );
  }

  static pw.Widget _tableHeader(String text,
      {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
            fontSize: 10, fontWeight: pw.FontWeight.bold),
        textAlign: align,
      ),
    );
  }

  static pw.Widget _tableCell(String text,
      {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 10),
        textAlign: align,
      ),
    );
  }
}

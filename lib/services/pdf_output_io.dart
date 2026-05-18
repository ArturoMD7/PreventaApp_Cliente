import 'dart:typed_data';
import 'package:printing/printing.dart';

Future<void> outputPdf(
  List<int> bytes, {
  required String filename,
}) async {
  await Printing.layoutPdf(
    onLayout: (_) async => Uint8List.fromList(bytes),
    name: filename,
  );
}

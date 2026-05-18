import 'dart:html' as html;
import 'dart:typed_data';

Future<void> outputPdf(
  List<int> bytes, {
  required String filename,
}) async {
  final blob = html.Blob([Uint8List.fromList(bytes)], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}

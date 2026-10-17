import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'domain.dart';

enum ExportOutcome { saved, handedOff, dismissed, unconfirmed }

class FileExchange {
  static const maxBytes = 20 * 1024 * 1024;
  static const group = XTypeGroup(
    label: 'Panadero JSON',
    extensions: ['json'],
    mimeTypes: ['application/json'],
  );

  Future<Transfer?> read() async {
    final file = await openFile(acceptedTypeGroups: [group]);
    if (file == null) return null;
    if (await file.length() > maxBytes) {
      throw const FormatException('El archivo supera el límite de 20 MB.');
    }
    final bytes = await file.readAsBytes();
    if (bytes.length > maxBytes) {
      throw const FormatException('El archivo supera el límite de 20 MB.');
    }
    return Transfer.decode(utf8.decode(bytes));
  }

  Future<ExportOutcome> export(Transfer transfer, {required bool share}) async {
    if (transfer.recipes.isEmpty &&
        transfer.bakes.isEmpty &&
        transfer.prepared.isEmpty) {
      throw const FormatException(
          'No hay recetas, amasadas ni preparados para exportar.');
    }
    final name =
        'panadero-${transfer.backup ? 'respaldo' : 'recetas'}-${DateTime.now().millisecondsSinceEpoch}.json';
    final bytes = Uint8List.fromList(utf8.encode(transfer.encode()));
    if (share || Platform.isAndroid) {
      final directory = await getTemporaryDirectory();
      final file = File(p.join(directory.path, name));
      await file.writeAsBytes(bytes, flush: true);
      try {
        final result = await SharePlus.instance.share(
          ShareParams(
              files: [XFile(file.path, mimeType: 'application/json')],
              subject:
                  transfer.backup ? 'Respaldo Panadero' : 'Recetas Panadero'),
        );
        return switch (result.status) {
          ShareResultStatus.success => ExportOutcome.handedOff,
          ShareResultStatus.dismissed => ExportOutcome.dismissed,
          ShareResultStatus.unavailable => ExportOutcome.unconfirmed,
        };
      } finally {
        // Android copies the file before opening the chooser. Windows can read
        // the original asynchronously; leave its temporary file to the OS.
        if (Platform.isAndroid && await file.exists()) await file.delete();
      }
    }
    final location = await getSaveLocation(
      suggestedName: name,
      acceptedTypeGroups: [group],
    );
    if (location == null) return ExportOutcome.dismissed;
    await XFile.fromData(bytes, mimeType: 'application/json', name: name)
        .saveTo(location.path);
    return ExportOutcome.saved;
  }
}

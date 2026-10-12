import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'database_service.dart';
import 'episode_state_provider.dart';

class BackupService {
  const BackupService._();

  static Future<void> exportBackup(BuildContext context) async {
    try {
      final states = await DatabaseService.instance.exportState();
      final payload = {
        'app': 'sinclair_tracker',
        'formatVersion': 1,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'states': states,
      };
      final directory = await getTemporaryDirectory();
      final date = DateTime.now().toIso8601String().substring(0, 10);
      final file = File('${directory.path}/sinclair-tracker-backup-$date.json');
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(payload),
        flush: true,
      );
      await SharePlus.instance.share(
        ShareParams(
          subject: 'Sinclair Tracker Backup',
          text: 'Backup deiner gehörten Folgen, Bewertungen und Notizen.',
          files: [XFile(file.path, mimeType: 'application/json')],
        ),
      );
    } catch (error) {
      if (context.mounted) _showError(context, 'Export fehlgeschlagen: $error');
    }
  }

  static Future<void> importBackup(
    BuildContext context,
    EpisodeStateProvider state,
  ) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result == null) return;
      final picked = result.files.single;
      final bytes = picked.bytes ??
          (picked.path == null ? null : await File(picked.path!).readAsBytes());
      if (bytes == null) {
        throw const FormatException('Datei konnte nicht gelesen werden');
      }
      final root = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (root['app'] != 'sinclair_tracker' || root['states'] is! List) {
        throw const FormatException('Kein gültiges Sinclair-Tracker-Backup');
      }
      await DatabaseService.instance.importState(root['states'] as List);
      await state.load();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup erfolgreich importiert')),
        );
      }
    } catch (error) {
      if (context.mounted) _showError(context, 'Import fehlgeschlagen: $error');
    }
  }

  static void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

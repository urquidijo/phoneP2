// lib/features/admin/reports/reports_section.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../core/api_service.dart';
import '../../../core/models.dart';
import '../../../utils/formatters.dart';
import '../shared/section_scaffold.dart';
import '../shared/section_header.dart';

class AdminReportsSection extends StatefulWidget {
  const AdminReportsSection({super.key});
  @override
  State<AdminReportsSection> createState() => _AdminReportsSectionState();
}

class _AdminReportsSectionState extends State<AdminReportsSection> {
  final ApiService _api = ApiService.instance;
  final TextEditingController _prompt = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _loading = false;
  bool _speechReady = false;
  bool _listening = false;
  ReportFormat _format = ReportFormat.screen;
  ReportScreenResponse? _report;
  String? _feedback;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    final ok = await _speech.initialize();
    if (mounted) setState(() => _speechReady = ok);
  }

  @override
  void dispose() {
    _prompt.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _toggleSpeech() async {
    if (!_speechReady) return;
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    final started = await _speech.listen(
      onResult: (r) {
        setState(() => _prompt.text = r.recognizedWords);
        if (r.finalResult) _generate();
      },
    );
    setState(() => _listening = started);
  }

  Future<void> _generate() async {
    final prompt = _prompt.text.trim();
    if (prompt.isEmpty) {
      setState(() => _feedback = 'Describe el reporte que necesitas.');
      return;
    }
    setState(() {
      _loading = true;
      _feedback = null;
    });
    try {
      final payload = ReportPromptPayload(prompt: prompt, format: _format);
      if (_format == ReportFormat.screen) {
        final r = await _api.generateReportScreen(payload);
        if (!mounted) return;
        setState(() => _report = r);
      } else {
        final file = await _api.generateReportFile(payload);
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/${file.filename}';
        final out = File(path)..writeAsBytesSync(file.bytes);
        await OpenFilex.open(out.path);
        if (!mounted) return;
        setState(() => _feedback = 'Archivo descargado en $path');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _feedback = 'No pudimos generar el reporte: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SectionScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Generador de reportes'),
          const SizedBox(height: 12),
          TextField(
            controller: _prompt,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Describe el reporte',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: _toggleSpeech,
                icon: Icon(
                  _listening
                      ? Icons.stop_circle_outlined
                      : Icons.mic_none_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<ReportFormat>(
            segments: const [
              ButtonSegment(
                value: ReportFormat.screen,
                label: Text('Pantalla'),
                icon: Icon(Icons.table_rows_outlined),
              ),
              ButtonSegment(
                value: ReportFormat.pdf,
                label: Text('PDF'),
                icon: Icon(Icons.picture_as_pdf_outlined),
              ),
              ButtonSegment(
                value: ReportFormat.excel,
                label: Text('Excel'),
                icon: Icon(Icons.grid_on_outlined),
              ),
            ],
            selected: {_format},
            onSelectionChanged: (s) => setState(() => _format = s.first),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _loading ? null : _generate,
              icon: const Icon(Icons.play_arrow),
              label: Text(_loading ? 'Generando...' : 'Generar'),
            ),
          ),
          if (_feedback != null) ...[
            const SizedBox(height: 8),
            Text(_feedback!, style: Theme.of(context).textTheme.bodySmall),
          ],
          if (_format == ReportFormat.screen && _report != null) ...[
            const SizedBox(height: 16),
            Text('Resumen', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._report!.summary.map(
              (row) => ListTile(
                dense: true,
                title: Text(row.label),
                subtitle: Text('${row.cantidad} unidades'),
                trailing: Text(currencyFormatter.format(row.montoTotal)),
              ),
            ),
            const Divider(),
            ..._report!.rows
                .take(20)
                .map(
                  (row) => ListTile(
                    title: Text(row.factura),
                    subtitle: Text('${row.cliente} · ${row.producto}'),
                    trailing: Text(currencyFormatter.format(row.montoTotal)),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

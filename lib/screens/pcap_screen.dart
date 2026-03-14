// lib/screens/pcap_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class PcapScreen extends StatefulWidget {
  const PcapScreen({super.key});
  @override
  State<PcapScreen> createState() => _PcapScreenState();
}

class _PcapScreenState extends State<PcapScreen> {
  bool _uploading = false;
  Map<String, dynamic>? _result;
  String? _error;
  String? _fileName;

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.path == null) return;

    setState(() {
      _uploading = true;
      _error = null;
      _result = null;
      _fileName = file.name;
    });

    try {
      final api = context.read<ApiService>();
      final uri = Uri.parse('${api.baseUrl}/pcap/upload');
      final request = http.MultipartRequest('POST', uri)
        ..headers['ngrok-skip-browser-warning'] = 'true'
        ..files.add(await http.MultipartFile.fromPath('file', file.path!));

      final response = await request.send().timeout(
          const Duration(seconds: 30));
      final body = await response.stream.bytesToString();
      final data = jsonDecode(body) as Map<String, dynamic>;

      if (mounted) setState(() { _result = data; _uploading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _uploading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg0,
      appBar: AppBar(title: const Text('PCAP ANALYSIS')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          // Upload card
          CyberCard(
            child: Column(children: [
              const Icon(Icons.upload_file_outlined,
                  color: AppColors.cyan, size: 48),
              const SizedBox(height: 12),
              const Text('Upload PCAP File',
                  style: TextStyle(color: AppColors.textPrimary,
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Supports .pcap and .pcapng files',
                  style: TextStyle(
                      color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: 16),
              if (_fileName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    const Icon(Icons.insert_drive_file_outlined,
                        color: AppColors.cyan, size: 16),
                    const SizedBox(width: 6),
                    Text(_fileName!,
                        style: const TextStyle(
                            color: AppColors.cyan, fontSize: 12)),
                  ]),
                ),
              ElevatedButton.icon(
                onPressed: _uploading ? null : _pickAndUpload,
                icon: _uploading
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.bg0))
                    : const Icon(Icons.folder_open, size: 18),
                label: Text(_uploading ? 'ANALYSING...' : 'SELECT FILE'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cyan,
                  foregroundColor: AppColors.bg0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                ),
              ),
            ]),
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            CyberCard(
              borderColor: AppColors.red.withOpacity(0.4),
              child: Row(children: [
                const Icon(Icons.error_outline,
                    color: AppColors.red, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(_error!,
                    style: const TextStyle(
                        color: AppColors.red, fontSize: 12))),
              ]),
            ),
          ],

          if (_result != null) ...[
            const SizedBox(height: 12),
            _buildResults(),
          ],
        ]),
      ),
    );
  }

  Widget _buildResults() {
    final analysis = (_result!['analysis'] as Map?)
            ?.cast<String, dynamic>() ?? {};
    final total = _result!['total_packets'] as int? ?? 0;
    final malicious = analysis['malicious'] as int? ?? 0;
    final suspicious = analysis['suspicious'] as int? ?? 0;
    final normal = analysis['normal'] as int? ?? 0;
    final avgScore =
        (analysis['avg_threat_score'] as num?)?.toDouble() ?? 0.0;
    final topThreats =
        (_result!['top_threats'] as List?)?.cast<Map>() ?? [];

    return Column(children: [
      // Summary stats
      CyberCard(
        child: Column(children: [
          SectionHeader(
              title: 'ANALYSIS COMPLETE',
              trailing: Text(_result!['filename'] as String? ?? '',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 10))),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10, mainAxisSpacing: 10,
            childAspectRatio: 2.2,
            children: [
              _StatCard('TOTAL', total.toString(), AppColors.cyan),
              _StatCard('AVG SCORE',
                  avgScore.toStringAsFixed(1), AppColors.yellow),
              _StatCard('MALICIOUS',
                  malicious.toString(), AppColors.red),
              _StatCard('SUSPICIOUS',
                  suspicious.toString(), AppColors.orange),
            ],
          ),
        ]),
      ),
      const SizedBox(height: 12),
      // Top threats
      if (topThreats.isNotEmpty)
        CyberCard(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            const SectionHeader(
                title: 'TOP THREATS DETECTED',
                accentColor: AppColors.red),
            const SizedBox(height: 12),
            ...topThreats.take(5).map((t) {
              final score =
                  (t['threat_score'] as num?)?.toDouble() ?? 0.0;
              final color = AppColors.scoreToColor(score);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.bg2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: color.withOpacity(0.3)),
                ),
                child: Row(children: [
                  Expanded(
                    child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                      Text(
                          '${t['src_ip']} → ${t['dst_ip']}',
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 11,
                              fontFamily: 'monospace')),
                      Text(
                          '${t['protocol']}  port ${t['dst_port']}',
                          style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 10)),
                    ]),
                  ),
                  Column(children: [
                    ThreatChip(
                        label: t['threat_label'] as String? ??
                            'Normal'),
                    Text(score.toStringAsFixed(1),
                        style: TextStyle(
                            color: color,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                  ]),
                ]),
              );
            }),
          ]),
        ),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatCard(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center,
          children: [
        Text(value,
            style: TextStyle(color: color, fontSize: 20,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 9,
                letterSpacing: 1)),
      ]),
    );
  }
}

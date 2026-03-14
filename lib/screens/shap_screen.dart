// lib/screens/shap_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class ShapScreen extends StatefulWidget {
  final Map<String, dynamic>? packet;
  const ShapScreen({super.key, this.packet});
  @override
  State<ShapScreen> createState() => _ShapScreenState();
}

class _ShapScreenState extends State<ShapScreen> {
  bool _loading = true;
  Map<String, dynamic> _data = {};
  Map<String, dynamic> _summary = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = context.read<ApiService>();
      final explain = await api.explainThreat(
        packet: widget.packet ?? {},
        threatLabel: widget.packet?['threat_label'] as String? ?? 'Normal',
        threatScore: (widget.packet?['threat_score'] as num?)?.toDouble() ?? 0.0,
      );
      final summary = await api.getExplainSummary();
      if (mounted) setState(() {
        _data = explain;
        _summary = summary;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg0,
      appBar: AppBar(
        title: const Text('SHAP EXPLANATION'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              label: const Text('XGBoost',
                  style: TextStyle(fontSize: 10)),
              backgroundColor: AppColors.cyan.withOpacity(0.15),
              side: BorderSide(color: AppColors.cyan.withOpacity(0.4)),
            ),
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(
              color: AppColors.cyan))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                _buildExplanationCard(),
                const SizedBox(height: 12),
                _buildTopFeaturesCard(),
                const SizedBox(height: 12),
                _buildGlobalImportanceCard(),
              ]),
            ),
    );
  }

  Widget _buildExplanationCard() {
    final label = _data['threat_label'] as String? ?? 'Normal';
    final score = (_data['threat_score'] as num?)?.toDouble() ?? 0.0;
    final attackType = _data['attack_type'] as String? ?? '';
    final explanation = _data['explanation'] as String? ?? '';
    final network = _data['network_context'] as String? ?? '';
    final impact = _data['impact'] as String? ?? '';
    final action = _data['recommended_action'] as String? ?? '';
    final color = AppColors.scoreToColor(score);

    return CyberCard(
      borderColor: color.withOpacity(0.4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('AI DECISION', style: TextStyle(
              color: AppColors.textMuted, fontSize: 10, letterSpacing: 2)),
          const Spacer(),
          ThreatChip(label: label),
          const SizedBox(width: 8),
          Text('${score.toStringAsFixed(1)}/100',
              style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ]),

        if (attackType.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withOpacity(0.3))),
            child: Row(children: [
              Icon(Icons.security, color: color, size: 14),
              const SizedBox(width: 8),
              Expanded(child: Text(attackType,
                  style: TextStyle(color: color, fontSize: 12,
                      fontWeight: FontWeight.bold))),
            ]),
          ),
        ],

        const SizedBox(height: 10),
        _InfoBlock(icon: Icons.psychology_outlined,
            color: AppColors.cyan, title: 'WHAT IS HAPPENING', text: explanation),
        const SizedBox(height: 8),
        _InfoBlock(icon: Icons.wifi_outlined,
            color: AppColors.yellow, title: 'NETWORK CONTEXT', text: network),
        const SizedBox(height: 8),
        _InfoBlock(icon: Icons.warning_amber_outlined,
            color: AppColors.red, title: 'POTENTIAL IMPACT', text: impact),
        const SizedBox(height: 8),
        _InfoBlock(icon: Icons.shield_outlined,
            color: AppColors.green, title: 'RECOMMENDED ACTION', text: action),
      ]),
    );
  }

  Widget _buildTopFeaturesCard() {
    final topFeatures = (_data['top_features'] as List?)?.cast<Map>() ?? [];
    return CyberCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        const SectionHeader(
            title: 'TOP CONTRIBUTING FEATURES',
            subtitle: 'SHAP IMPACT VALUES'),
        const SizedBox(height: 14),
        ...topFeatures.map((f) {
          final impact = (f['shap_impact'] as num?)?.toDouble() ?? 0.0;
          final isRisk = impact > 0;
          final color = isRisk ? AppColors.red : AppColors.green;
          final barWidth = (impact.abs() * 2).clamp(0.0, 1.0);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(children: [
                Icon(isRisk ? Icons.arrow_upward : Icons.arrow_downward,
                    color: color, size: 14),
                const SizedBox(width: 6),
                Text(f['feature'] as String? ?? '',
                    style: TextStyle(color: color, fontSize: 12,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${impact > 0 ? "+" : ""}${impact.toStringAsFixed(3)}',
                    style: TextStyle(color: color, fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: barWidth,
                  backgroundColor: AppColors.bg3,
                  valueColor: AlwaysStoppedAnimation(color),
                  minHeight: 4,
                ),
              ),
              Text(
                isRisk ? 'Increases threat risk' : 'Decreases threat risk',
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 9),
              ),
            ]),
          );
        }),
      ]),
    );
  }

  Widget _buildGlobalImportanceCard() {
    final features = (_summary['feature_importance'] as List?)
            ?.cast<Map>().take(8).toList() ?? [];
    final maxImpact = features.isEmpty ? 1.0
        : (features.first['mean_impact'] as num?)?.toDouble() ?? 1.0;
    return CyberCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        const SectionHeader(
            title: 'GLOBAL FEATURE IMPORTANCE',
            subtitle: 'MEAN SHAP VALUES ACROSS ALL PREDICTIONS'),
        const SizedBox(height: 14),
        ...features.map((f) {
          final impact = (f['mean_impact'] as num?)?.toDouble() ?? 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              SizedBox(
                width: 130,
                child: Text(f['feature'] as String? ?? '',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 10)),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: impact / maxImpact,
                    backgroundColor: AppColors.bg3,
                    valueColor: const AlwaysStoppedAnimation(AppColors.cyan),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(impact.toStringAsFixed(3),
                  style: const TextStyle(
                      color: AppColors.cyan, fontSize: 10)),
            ]),
          );
        }),
      ]),
    );
  }
}

// Helper widget for detailed information blocks
class _InfoBlock extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, text;
  const _InfoBlock({required this.icon, required this.color,
      required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 6),
          Text(title, style: TextStyle(color: color, fontSize: 9,
              letterSpacing: 1.5, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 6),
        Text(text, style: const TextStyle(color: AppColors.textPrimary,
            fontSize: 11, height: 1.5)),
      ]),
    );
  }
}

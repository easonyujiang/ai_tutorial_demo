import 'package:flutter/material.dart';

import '../config.dart';
import '../models/tutorial.dart';
import '../services/tutorial_service.dart';

class SkillLibraryPage extends StatefulWidget {
  final Future<void> Function(Tutorial tutorial, String? sessionId) onStartTutorial;

  const SkillLibraryPage({super.key, required this.onStartTutorial});

  @override
  State<SkillLibraryPage> createState() => _SkillLibraryPageState();
}

class _SkillLibraryPageState extends State<SkillLibraryPage> {
  List<Map<String, dynamic>> _skills = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSkills();
  }

  Future<void> _loadSkills() async {
    setState(() { _loading = true; _error = null; });
    try {
      final service = TutorialService(baseUrl: AppConfig.backendUrl);
      final skills = await service.fetchSkills();
      if (mounted) setState(() { _skills = skills; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _startSkill(Map<String, dynamic> skillData) {
    final rawSteps = skillData['steps'] as List? ?? [];
    final steps = rawSteps.asMap().entries.map<TutorialStep>((entry) {
      final idx = entry.key;
      final s = entry.value as Map<String, dynamic>;
      return TutorialStep(
        index: idx,
        instruction: (s['instruction'] ?? '') as String,
        targetText: (s['target_text'] ?? '') as String,
        targetDescription: (s['target_description'] ?? '') as String,
        targetType: (s['target_type'] ?? 'text') as String,
        pageDescription: (s['page_description'] ?? '') as String,
      );
    }).toList();

    final tutorial = Tutorial(
      id: (skillData['id'] ?? '') as String,
      title: (skillData['title'] ?? '') as String,
      steps: steps,
      launchPackage: (skillData['launch_package'] ?? '') as String,
      launchActivity: (skillData['launch_activity'] ?? '') as String,
    );

    widget.onStartTutorial(tutorial, tutorial.id);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Row(
              children: [
                Builder(
                  builder: (ctx) => IconButton(
                    icon: const Icon(Icons.menu, color: Color(0xFF8A8AB0)),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF667EEA), Color(0xFF764BA2)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.bookmark, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('技能库', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                    Text('从云端加载预置教程', style: TextStyle(color: Color(0xFF6A6A9A), fontSize: 11)),
                  ],
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _loadSkills,
                  icon: const Icon(Icons.refresh, size: 16, color: Color(0xFF6A6A9A)),
                  label: const Text('刷新', style: TextStyle(color: Color(0xFF6A6A9A), fontSize: 12)),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF667EEA)));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: Color(0xFF3A3A6A), size: 48),
            const SizedBox(height: 12),
            Text('加载失败', style: TextStyle(color: Color(0xFF6A6A9A), fontSize: 14)),
            const SizedBox(height: 4),
            Text(_error!, style: TextStyle(color: Color(0xFF5A5A8A), fontSize: 11), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(onPressed: _loadSkills, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_skills.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, color: Color(0xFF3A3A6A), size: 64),
            SizedBox(height: 16),
            Text('暂无云端技能', style: TextStyle(color: Color(0xFF5A5A8A), fontSize: 15)),
            SizedBox(height: 6),
            Text('在 Web 控制台创建技能后点击刷新', style: TextStyle(color: Color(0xFF3A3A6A), fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      itemCount: _skills.length,
      itemBuilder: (_, i) => _buildSkillCard(_skills[i]),
    );
  }

  Widget _buildSkillCard(Map<String, dynamic> skill) {
    final title = (skill['title'] ?? '') as String;
    final desc = (skill['description'] ?? '') as String;
    final steps = (skill['steps'] as List? ?? []);
    final iconSteps = steps.where((s) => s['target_type'] == 'icon').length;
    final launchPkg = (skill['launch_package'] ?? '') as String;
    final appName = launchPkg.isNotEmpty ? launchPkg.split('.').last : '';
    final deviceList = (skill['device_allowlist'] ?? '') as String;
    final osList = (skill['os_allowlist'] ?? '') as String;

    return Card(
      color: const Color(0xFF1A1A35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _startSkill(skill),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                  if (appName.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF667EEA).withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(appName, style: const TextStyle(color: Color(0xFF667EEA), fontSize: 11)),
                    ),
                ],
              ),
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(desc, style: const TextStyle(color: Color(0xFF6A6A9A), fontSize: 12)),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 4, runSpacing: 4,
                children: [
                  _infoChip('${steps.length} 步骤', Icons.format_list_numbered),
                  if (iconSteps > 0) _infoChip('$iconSteps 图标识别', Icons.auto_awesome),
                  if (appName.isNotEmpty) _infoChip(appName, Icons.phone_android),
                  if (deviceList.isNotEmpty) _infoChip(deviceList, Icons.devices),
                  if (osList.isNotEmpty) _infoChip('Android $osList', Icons.android),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                steps.take(4).map((s) => '${(s['index'] ?? 0) + 1}. ${s['target_description'] ?? s['target_text'] ?? s['instruction']}').join('  ⟶  '),
                style: const TextStyle(color: Color(0xFF4A4A7A), fontSize: 11),
                maxLines: 2, overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A4A),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF8A8AB0)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Color(0xFF8A8AB0), fontSize: 11)),
        ],
      ),
    );
  }
}

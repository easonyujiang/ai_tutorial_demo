import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config.dart';

const _appPresets = <Map<String, String>>[
  {'name': '设置', 'pkg': 'com.android.settings', 'act': '.Settings'},
  {'name': '微信', 'pkg': 'com.tencent.mm', 'act': '.ui.LauncherUI'},
  {'name': '支付宝', 'pkg': 'com.eg.android.AlipayGphone', 'act': ''},
  {'name': '抖音', 'pkg': 'com.ss.android.ugc.aweme', 'act': ''},
  {'name': 'QQ', 'pkg': 'com.tencent.mobileqq', 'act': ''},
  {'name': '淘宝', 'pkg': 'com.taobao.taobao', 'act': ''},
  {'name': '美团', 'pkg': 'com.sankuai.meituan', 'act': ''},
  {'name': '小红书', 'pkg': 'com.xingin.xhs', 'act': ''},
  {'name': '哔哩哔哩', 'pkg': 'tv.danmaku.bili', 'act': ''},
  {'name': '百度地图', 'pkg': 'com.baidu.BaiduMap', 'act': ''},
  {'name': '高德地图', 'pkg': 'com.autonavi.minimap', 'act': ''},
  {'name': '京东', 'pkg': 'com.jingdong.app.mall', 'act': ''},
  {'name': '拼多多', 'pkg': 'com.xunmeng.pinduoduo', 'act': ''},
  {'name': '网易云音乐', 'pkg': 'com.netease.cloudmusic', 'act': ''},
  {'name': 'QQ音乐', 'pkg': 'com.tencent.qqmusic', 'act': ''},
  {'name': '相机', 'pkg': 'com.android.camera', 'act': ''},
  {'name': '相册', 'pkg': 'com.android.gallery3d', 'act': ''},
  {'name': '电话', 'pkg': 'com.android.dialer', 'act': ''},
  {'name': '短信', 'pkg': 'com.android.mms', 'act': ''},
  {'name': '浏览器', 'pkg': 'com.android.browser', 'act': ''},
  {'name': '文件管理', 'pkg': 'com.android.fileexplorer', 'act': ''},
  {'name': '应用商店', 'pkg': 'com.android.vending', 'act': ''},
];

class SkillEditorPage extends StatefulWidget {
  final Map<String, dynamic>? prefillDemo;

  const SkillEditorPage({super.key, this.prefillDemo});

  @override
  State<SkillEditorPage> createState() => _SkillEditorPageState();
}

class _SkillEditorPageState extends State<SkillEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _pkgController = TextEditingController();
  final _actController = TextEditingController();
  final _deviceController = TextEditingController();
  final _osController = TextEditingController();

  final _steps = <_StepData>[];
  bool _analyzing = false;
  bool _saving = false;
  String? _analyzeError;
  String? _videoUrl;
  String? _uploadFileName;

  @override
  void initState() {
    super.initState();
    final demo = widget.prefillDemo;
    if (demo != null) {
      _titleController.text = (demo['title'] ?? '') as String;
      _descController.text = (demo['app_name'] ?? '') as String;
      _pkgController.text = (demo['app_package'] ?? '') as String;
      _videoUrl = (demo['video_url'] ?? '') as String?;
      final steps = demo['steps'] as List? ?? [];
      for (final s in steps) {
        final sm = s as Map<String, dynamic>;
        _steps.add(_StepData(
          instruction: (sm['instruction'] ?? '') as String,
          targetText: (sm['target_text'] ?? '') as String,
          targetType: (sm['target_type'] ?? 'text') as String,
          targetDescription: (sm['target_description'] ?? '') as String,
          pageDescription: (sm['page_description'] ?? '') as String,
        ));
      }
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    _descController.dispose();
    _pkgController.dispose();
    _actController.dispose();
    _deviceController.dispose();
    _osController.dispose();
    super.dispose();
  }

  Future<void> _analyzeUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    setState(() { _analyzing = true; _analyzeError = null; });
    try {
      final uri = Uri.parse('${AppConfig.backendUrl}/api/skills/analyze');
      final resp = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'url': url}),
      ).timeout(const Duration(seconds: 300));
      if (resp.statusCode != 200) {
        throw _parseError(resp.body);
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      _applyAnalysis(data);
    } catch (e) {
      setState(() => _analyzeError = e.toString());
    } finally {
      setState(() => _analyzing = false);
    }
  }

  Future<void> _uploadVideo() async {
    final controller = TextEditingController();
    final path = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A35),
        title: const Text('上传视频', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: '输入本地视频文件路径',
            hintStyle: const TextStyle(color: Color(0xFF5A5A8A)),
            filled: true,
            fillColor: const Color(0xFF12122A),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('上传')),
        ],
      ),
    );
    if (path == null || path.isEmpty) return;

    final fileName = path.split('/').last;
    setState(() { _analyzing = true; _analyzeError = null; _uploadFileName = fileName; });

    try {
      final bytes = await _readFileAsync(path);
      if (bytes == null) throw Exception('无法读取文件: $path');

      final uri = Uri.parse('${AppConfig.backendUrl}/api/skills/analyze/upload');
      final request = http.MultipartRequest('POST', uri)
        ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));
      final streamedResp = await request.send().timeout(const Duration(seconds: 300));
      final respBody = await streamedResp.stream.bytesToString();
      if (streamedResp.statusCode != 200) {
        throw _parseError(respBody);
      }
      final data = jsonDecode(respBody) as Map<String, dynamic>;
      _applyAnalysis(data);
    } catch (e) {
      setState(() => _analyzeError = e.toString());
    } finally {
      setState(() => _analyzing = false);
    }
  }

  Future<Uint8List?> _readFileAsync(String path) async {
    final uri = Uri.parse('${AppConfig.backendUrl}/api/videos/read-local-file');
    try {
      final resp = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'path': path}),
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        return Uint8List.fromList(resp.bodyBytes);
      }
    } catch (_) {}
    return null;
  }

  String _parseError(String body) {
    try {
      final d = jsonDecode(body);
      return d['detail'] ?? body;
    } catch (_) {
      return body.length > 200 ? body.substring(0, 200) : body;
    }
  }

  void _applyAnalysis(Map<String, dynamic> data) {
    setState(() {
      _titleController.text = (data['title'] ?? '') as String;
      final appPkg = (data['app_package'] ?? '') as String;
      if (appPkg.isNotEmpty) _pkgController.text = appPkg;
      final appName = (data['app_name'] ?? '') as String;
      if (appName.isNotEmpty && _descController.text.isEmpty) {
        _descController.text = appName;
      }
      final stepsList = data['steps'] as List? ?? [];
      _steps.clear();
      for (final s in stepsList) {
        final sm = s as Map<String, dynamic>;
        _steps.add(_StepData(
          instruction: (sm['instruction'] ?? '') as String,
          targetText: (sm['target_text'] ?? '') as String,
          targetType: (sm['target_type'] ?? 'text') as String,
          targetDescription: (sm['target_description'] ?? '') as String,
          pageDescription: (sm['page_description'] ?? '') as String,
        ));
      }
    });
  }

  void _pickApp(Map<String, String> preset) {
    _pkgController.text = preset['pkg'] ?? '';
    _actController.text = preset['act'] ?? '';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入技能标题')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final body = {
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'launch_package': _pkgController.text.trim(),
        'launch_activity': _actController.text.trim(),
        'device_allowlist': _deviceController.text.trim(),
        'os_allowlist': _osController.text.trim(),
        'video_url': _videoUrl ?? '',
        'steps': _steps.where((s) => s.instruction.isNotEmpty).map((s) => {
          'instruction': s.instruction,
          'target_text': s.targetText,
          'target_type': s.targetType,
          'target_description': s.targetDescription,
          'page_description': s.pageDescription,
        }).toList(),
      };

      final uri = Uri.parse('${AppConfig.backendUrl}/api/skills');
      final resp = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('技能创建成功'), backgroundColor: Color(0xFF22C55E)),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        throw _parseError(resp.body);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        title: const Text('新建技能', style: TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: const Color(0xFF0F0F1A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF8A8AB0)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _buildVideoSection(),
            const SizedBox(height: 20),
            _buildTitleSection(),
            const SizedBox(height: 16),
            _buildAppSection(),
            const SizedBox(height: 16),
            _buildDeviceSection(),
            const SizedBox(height: 16),
            _buildStepsSection(),
            const SizedBox(height: 24),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A4A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Color(0xFF667EEA), size: 18),
              SizedBox(width: 6),
              Text(' AI 智能解析', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _urlController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: '粘贴视频链接（抖音/B站/YouTube）',
                    hintStyle: const TextStyle(color: Color(0xFF5A5A8A), fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF12122A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    suffixIcon: _analyzing
                        ? const Padding(padding: EdgeInsets.all(10), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                        : IconButton(
                            icon: const Icon(Icons.search, color: Color(0xFF667EEA), size: 20),
                            onPressed: _analyzeUrl,
                          ),
                  ),
                  onSubmitted: (_) => _analyzeUrl(),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: _uploadVideo,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  decoration: BoxDecoration(
                    color: const Color(0xFF12122A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.upload_file, color: Color(0xFF667EEA), size: 18),
                      SizedBox(width: 4),
                      Text('上传', style: TextStyle(color: Color(0xFF8A8AB0), fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_uploadFileName != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('📁 $_uploadFileName', style: const TextStyle(color: Color(0xFF6A6A9A), fontSize: 11)),
            ),
          if (_analyzeError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('❌ 解析失败: $_analyzeError',
                  style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 11)),
              ),
            ),
          if (_videoUrl != null && _videoUrl!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF667EEA).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.videocam, color: Color(0xFF667EEA), size: 14),
                    const SizedBox(width: 4),
                    Expanded(child: Text('已关联视频', style: TextStyle(color: Color(0xFF667EEA), fontSize: 11))),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTitleSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A4A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('标题 *', style: TextStyle(color: Color(0xFF8A8AB0), fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          TextField(
            controller: _titleController,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: '技能标题，如：如何连接WiFi',
              hintStyle: const TextStyle(color: Color(0xFF5A5A8A), fontSize: 13),
              filled: true,
              fillColor: const Color(0xFF12122A),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 10),
          const Text('描述', style: TextStyle(color: Color(0xFF8A8AB0), fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          TextField(
            controller: _descController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: '简短描述这个技能是做什么的',
              hintStyle: const TextStyle(color: Color(0xFF5A5A8A), fontSize: 12),
              filled: true,
              fillColor: const Color(0xFF12122A),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A4A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('搜索应用...', style: TextStyle(color: Color(0xFF8A8AB0), fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: _appPresets.map((p) => InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _pickApp(p),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _pkgController.text == (p['pkg'] ?? '')
                      ? const Color(0xFF667EEA).withValues(alpha: 0.3)
                      : const Color(0xFF12122A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _pkgController.text == (p['pkg'] ?? '')
                      ? const Color(0xFF667EEA)
                      : const Color(0xFF2A2A4A)),
                ),
                child: Text(p['name'] ?? '',
                  style: TextStyle(
                    color: _pkgController.text == (p['pkg'] ?? '') ? Colors.white : const Color(0xFF8A8AB0),
                    fontSize: 12,
                  )),
              ),
            )).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('目标应用包名', style: TextStyle(color: Color(0xFF5A5A8A), fontSize: 10)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _pkgController,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: '如：com.android.settings',
                        hintStyle: const TextStyle(color: Color(0xFF3A3A6A), fontSize: 11),
                        filled: true, fillColor: const Color(0xFF12122A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('启动 Activity', style: TextStyle(color: Color(0xFF5A5A8A), fontSize: 10)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _actController,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: '通常留空即可',
                        hintStyle: const TextStyle(color: Color(0xFF3A3A6A), fontSize: 11),
                        filled: true, fillColor: const Color(0xFF12122A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('💡 关于 Activity：绝大多数应用留空即可，系统会自动找默认启动页。只有特定页面才需要填写。',
            style: TextStyle(color: Color(0xFF3A3A6A), fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildDeviceSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A4A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('机型白名单（逗号分隔品牌关键字）', style: TextStyle(color: Color(0xFF8A8AB0), fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          const Text('💡 设备型号包含任一关键字即适用此技能。如填 "Xiaomi" 可匹配 Redmi Note 11T Pro。',
              style: TextStyle(color: Color(0xFF3A3A6A), fontSize: 10)),
          const SizedBox(height: 6),
          TextField(
            controller: _deviceController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: '如：Xiaomi,Redmi,OPPO,vivo',
              hintStyle: const TextStyle(color: Color(0xFF5A5A8A), fontSize: 12),
              filled: true, fillColor: const Color(0xFF12122A),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 10),
          const Text('系统白名单（逗号分隔系统版本关键字）', style: TextStyle(color: Color(0xFF8A8AB0), fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          const Text('💡 不同品牌系统版本名不同：小米=MIUI/HyperOS、OPPO=ColorOS、三星=One UI。留空则不限系统。',
              style: TextStyle(color: Color(0xFF3A3A6A), fontSize: 10)),
          const SizedBox(height: 6),
          TextField(
            controller: _osController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: '如：MIUI 14,HyperOS,ColorOS 13,One UI 5',
              hintStyle: const TextStyle(color: Color(0xFF5A5A8A), fontSize: 12),
              filled: true, fillColor: const Color(0xFF12122A),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepsSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A4A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('操作步骤', style: TextStyle(color: Color(0xFF8A8AB0), fontSize: 12, fontWeight: FontWeight.w500)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => _steps.add(_StepData())),
                icon: const Icon(Icons.add, size: 16, color: Color(0xFF667EEA)),
                label: const Text('添加', style: TextStyle(color: Color(0xFF667EEA), fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._steps.asMap().entries.map((entry) {
            final idx = entry.key;
            final step = entry.value;
            return _buildStepCard(idx, step);
          }),
          if (_steps.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: const Text('粘贴视频链接并解析，或手动添加步骤', textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF4A4A6A), fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildStepCard(int index, _StepData step) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF12122A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2A2A4A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFF667EEA).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(child: Text('${index + 1}', style: const TextStyle(color: Color(0xFF667EEA), fontSize: 11, fontWeight: FontWeight.w700))),
              ),
              const SizedBox(width: 8),
              Text('步骤 ${index + 1}', style: const TextStyle(color: Color(0xFF6A6A9A), fontSize: 12)),
              const Spacer(),
              InkWell(
                onTap: () => setState(() => _steps.removeAt(index)),
                child: const Icon(Icons.delete_outline, color: Color(0xFF5A5A8A), size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: TextEditingController(text: step.instruction),
            onChanged: (v) => step.instruction = v,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: '操作说明，如：点击设置图标',
              hintStyle: const TextStyle(color: Color(0xFF4A4A6A), fontSize: 12),
              filled: true, fillColor: const Color(0xFF1A1A35),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: TextEditingController(text: step.targetText),
                  onChanged: (v) => step.targetText = v,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: '目标文字（文字按钮）',
                    hintStyle: const TextStyle(color: Color(0xFF4A4A6A), fontSize: 11),
                    filled: true, fillColor: const Color(0xFF1A1A35),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: TextEditingController(text: step.targetDescription),
                  onChanged: (v) => step.targetDescription = v,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: '目标外观描述（如：右上角三个点）',
                    hintStyle: const TextStyle(color: Color(0xFF4A4A6A), fontSize: 11),
                    filled: true, fillColor: const Color(0xFF1A1A35),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: TextEditingController(text: step.pageDescription),
            onChanged: (v) => step.pageDescription = v,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: InputDecoration(
              hintText: '页面描述，如：手机桌面主屏幕',
              hintStyle: const TextStyle(color: Color(0xFF4A4A6A), fontSize: 11),
              filled: true, fillColor: const Color(0xFF1A1A35),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        onPressed: _saving ? null : _save,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF667EEA),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _saving
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('保存技能', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _StepData {
  String instruction;
  String targetText;
  String targetType;
  String targetDescription;
  String pageDescription;

  _StepData({
    this.instruction = '',
    this.targetText = '',
    this.targetType = 'text',
    this.targetDescription = '',
    this.pageDescription = '',
  });
}

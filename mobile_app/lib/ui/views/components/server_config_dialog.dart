import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../view_models/parking_view_model.dart';

void showServerConfigDialog(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _ServerConfigModal(),
  );
}

class _ServerConfigModal extends StatefulWidget {
  const _ServerConfigModal({Key? key}) : super(key: key);

  @override
  State<_ServerConfigModal> createState() => _ServerConfigModalState();
}

class _ServerConfigModalState extends State<_ServerConfigModal> {
  late TextEditingController _urlController;
  bool _isTesting = false;
  bool? _testResult;
  String? _testMessage;

  static const String _defaultWifiIp = 'https://10.9.240.129:8000';
  static const String _emulatorIp = 'https://10.0.2.2:8000';
  static const String _localhostIp = 'https://localhost:8000';

  @override
  void initState() {
    super.initState();
    final currentUrl = context.read<ParkingViewModel>().currentBaseUrl;
    _urlController = TextEditingController(text: currentUrl.isNotEmpty ? currentUrl : _defaultWifiIp);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _runTest() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isTesting = true;
      _testResult = null;
      _testMessage = null;
    });

    final vm = context.read<ParkingViewModel>();
    final ok = await vm.testConnection(url);

    if (!mounted) return;
    setState(() {
      _isTesting = false;
      _testResult = ok;
      _testMessage = ok
          ? 'Successfully connected to FastAPI server (200 OK)!'
          : 'Could not connect. Ensure FastAPI is running on host PC and both devices are on the same Wi-Fi.';
    });
  }

  void _saveAndApply() {
    final url = _urlController.text.trim();
    if (url.isNotEmpty) {
      final vm = context.read<ParkingViewModel>();
      vm.updateBackendUrl(url);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backend server updated to: $url'),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.wifi_tethering_rounded, color: Color(0xFF2563EB), size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Server Configuration',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Connect your physical smartphone to the FastAPI backend running on your computer.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),

            // Quick Preset Selection
            const Text(
              'QUICK IP PRESETS',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.8),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.wifi_rounded, size: 16, color: Color(0xFF2563EB)),
                  label: const Text('Host Wi-Fi (10.9.240.129)'),
                  backgroundColor: const Color(0xFFEFF6FF),
                  onPressed: () {
                    setState(() {
                      _urlController.text = _defaultWifiIp;
                      _testResult = null;
                    });
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.phone_android_rounded, size: 16, color: Color(0xFF64748B)),
                  label: const Text('PC Emulator (10.0.2.2)'),
                  backgroundColor: const Color(0xFFF1F5F9),
                  onPressed: () {
                    setState(() {
                      _urlController.text = _emulatorIp;
                      _testResult = null;
                    });
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.laptop_chromebook_rounded, size: 16, color: Color(0xFF64748B)),
                  label: const Text('Localhost (8000)'),
                  backgroundColor: const Color(0xFFF1F5F9),
                  onPressed: () {
                    setState(() {
                      _urlController.text = _localhostIp;
                      _testResult = null;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Custom URL input
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'Backend Base URL (HTTPS)',
                hintText: 'https://10.9.240.129:8000',
                prefixIcon: const Icon(Icons.link_rounded),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () => _urlController.clear(),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),

            // Test connection result banner
            if (_testResult != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _testResult == true ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _testResult == true ? const Color(0xFF6EE7B7) : const Color(0xFFFCA5A5),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _testResult == true ? Icons.check_circle_rounded : Icons.error_rounded,
                      color: _testResult == true ? const Color(0xFF059669) : const Color(0xFFDC2626),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _testMessage ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: _testResult == true ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: _isTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.network_check_rounded),
                    label: Text(_isTesting ? 'Testing...' : 'Test Connection'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isTesting ? null : _runTest,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Save & Connect'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _saveAndApply,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

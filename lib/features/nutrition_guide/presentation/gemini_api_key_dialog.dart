import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/panda_button.dart';
import '../data/gemini_api_key_provider.dart';

class GeminiApiKeyDialog extends ConsumerStatefulWidget {
  const GeminiApiKeyDialog({super.key});

  @override
  ConsumerState<GeminiApiKeyDialog> createState() => _GeminiApiKeyDialogState();
}

class _GeminiApiKeyDialogState extends ConsumerState<GeminiApiKeyDialog> {
  final _keyController = TextEditingController();
  bool _obscureText = true;
  bool _isSaving = false;
  String? _errorMessage;

  static const String _aiStudioUrl = 'https://aistudio.google.com/apikey';

  @override
  void initState() {
    super.initState();
    final currentKey = ref.read(geminiApiKeyProvider).valueOrNull;
    if (currentKey != null) {
      _keyController.text = currentKey;
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null) {
      setState(() {
        _keyController.text = data!.text!.trim();
        _errorMessage = null;
      });
    }
  }

  void _copyUrlToClipboard() {
    Clipboard.setData(const ClipboardData(text: _aiStudioUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied link: https://aistudio.google.com/apikey'),
        backgroundColor: AppColors.emerald,
      ),
    );
  }

  Future<void> _saveKey() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() => _errorMessage = 'Please enter or paste a valid Gemini API key.');
      return;
    }

    if (!key.startsWith('AIzaSy')) {
      setState(() => _errorMessage = 'Key should usually start with "AIzaSy...". Please verify.');
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final success = await ref.read(geminiApiKeyProvider.notifier).saveKey(key);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚡ Panda Live AI connected successfully!'),
          backgroundColor: AppColors.emerald,
        ),
      );
    } else {
      setState(() => _errorMessage = 'Failed to save API key.');
    }
  }

  Future<void> _removeKey() async {
    await ref.read(geminiApiKeyProvider.notifier).removeKey();
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Gemini API key removed. Panda AI switched to offline mode.'),
        backgroundColor: AppColors.textSecondary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentKey = ref.watch(geminiApiKeyProvider).valueOrNull;
    final isConfigured = currentKey != null && currentKey.isNotEmpty;

    return Dialog(
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.glassBorder),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome, color: AppColors.emerald, size: 24),
                      SizedBox(width: 10),
                      Text(
                        'Panda Eats AI Setup',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textMuted, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Overview Banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.emerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.emerald.withValues(alpha: 0.35)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚡ 100% Free · Real-Time Intelligence & Web Search',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.emeraldLight,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Connect your free Google Gemini API key to unlock natural conversational advice, unlimited dynamic recipes, and real-time food matrix search.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Step-by-Step Guide
              const Text(
                'How to get your free key in 30 seconds:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 10),

              _buildStepItem(
                step: '1',
                title: 'Open Google AI Studio',
                subtitle: 'Log in with your standard Google/Gmail account (no credit card needed).',
                trailing: TextButton.icon(
                  onPressed: _copyUrlToClipboard,
                  icon: const Icon(Icons.copy, size: 16, color: AppColors.cyan),
                  label: const Text('Copy URL', style: TextStyle(color: AppColors.cyan, fontSize: 12)),
                ),
              ),
              _buildStepItem(
                step: '2',
                title: 'Click "Create API Key"',
                subtitle: 'Generate a new free key with 1 click on Google AI Studio.',
              ),
              _buildStepItem(
                step: '3',
                title: 'Paste & Activate Below',
                subtitle: 'Saved securely and stored locally on your device.',
              ),
              const SizedBox(height: 18),

              // API Key Input Field
              const Text(
                'Gemini API Key',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _keyController,
                obscureText: _obscureText,
                decoration: InputDecoration(
                  hintText: 'AIzaSy...',
                  prefixIcon: const Icon(Icons.key, color: AppColors.emerald, size: 20),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          _obscureText ? Icons.visibility : Icons.visibility_off,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscureText = !_obscureText),
                      ),
                      IconButton(
                        icon: const Icon(Icons.paste, color: AppColors.cyan, size: 20),
                        tooltip: 'Paste from clipboard',
                        onPressed: _pasteFromClipboard,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppColors.rose, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),

              // Action Buttons
              Row(
                children: [
                  if (isConfigured) ...[
                    TextButton.icon(
                      onPressed: _removeKey,
                      icon: const Icon(Icons.delete_outline, color: AppColors.rose, size: 18),
                      label: const Text('Remove Key', style: TextStyle(color: AppColors.rose, fontSize: 12)),
                    ),
                    const Spacer(),
                  ],
                  Expanded(
                    flex: isConfigured ? 0 : 1,
                    child: PandaButton(
                      label: isConfigured ? 'Update Key' : 'Activate Panda AI',
                      icon: Icons.bolt,
                      isLoading: _isSaving,
                      onPressed: _saveKey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepItem({
    required String step,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.emerald,
              shape: BoxShape.circle,
            ),
            child: Text(
              step,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (trailing != null) trailing,
                  ],
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.25),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/database/initial_data_seeder.dart';
import '../../../core/services/auth_service.dart';
import '../../../shared/widgets/bottom_nav_shell.dart';
import '../widgets/auth_widgets.dart';
import 'register_screen.dart';

/// Layar Login HoloDex.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _fillDemoCredentials() {
    setState(() {
      _usernameCtrl.text = InitialDataSeeder.demoUsername;
      _passwordCtrl.text = InitialDataSeeder.demoPassword;
      _errorMessage = null;
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await AuthService.login(
        username: _usernameCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const BottomNavShell()),
      );
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Terjadi kesalahan saat masuk. Coba lagi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Masuk',
      subtitle: 'Lanjutkan ke katalog dan pasar kartu Pokémon TCG.',
      children: [
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _usernameCtrl,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.username],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Username wajib diisi'
                      : null,
                ),
                const SizedBox(height: 14),
                PasswordField(
                  controller: _passwordCtrl,
                  onSubmitted: _submit,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Password wajib diisi' : null,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Pintasan pengisian akun demo untuk mempermudah pengujian praktikum
        InkWell(
          onTap: _isLoading ? null : _fillDemoCredentials,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceLow,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: const Row(
              children: [
                Icon(Icons.bolt, color: AppColors.gold, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Akun Demo: trainer_ash / password123 (Ketuk untuk isi)',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          AuthErrorBox(message: _errorMessage!),
        ],
        const SizedBox(height: 24),
        AuthSubmitButton(
          label: 'Masuk',
          loadingLabel: 'Memverifikasi...',
          isLoading: _isLoading,
          onPressed: _submit,
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Belum punya akun?',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      setState(() => _errorMessage = null);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      );
                    },
              child: const Text('Daftar'),
            ),
          ],
        ),
      ],
    );
  }
}

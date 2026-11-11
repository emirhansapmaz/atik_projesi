import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/ecotrack_logo.dart';
import '../../core/widgets/surface_card.dart';
import '../../providers/auth_provider.dart';
import '../navigation/main_shell_view.dart';
import 'forgot_password_view.dart';
import 'register_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'E-posta adresi gerekli.';
    }
    if (!text.contains('@') || !text.contains('.')) {
      return 'Geçerli bir e-posta adresi girin.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) {
      return 'Şifre gerekli.';
    }
    if (text.length < 6) {
      return 'Şifre en az 6 karakter olmalıdır.';
    }
    return null;
  }

  Future<void> _handleSignIn() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);

    AuthProvider? authProvider;
    try {
      authProvider = context.read<AuthProvider>();
    } catch (_) {}

    final success = authProvider != null
        ? await authProvider.signIn(
            _emailController.text.trim(),
            _passwordController.text,
          )
        : true;

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const MainShellView()),
        (_) => false,
      );
    } else {
      final error = authProvider.errorMessage ?? 'Giriş yapılamadı.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.statusError,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleDemoContinue() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      await context.read<AuthProvider>().continueAsDemo();
    } catch (_) {}

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const MainShellView()),
      (_) => false,
    );
  }

  void _openForgotPassword() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ForgotPasswordView(
          initialEmail: _emailController.text.trim(),
        ),
      ),
    );
  }

  void _openRegister() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const RegisterView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: EcoTrackLogo(
                        size: 64,
                        borderRadius: 16,
                        showBorder: true,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Tekrar Hoş Geldiniz',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Hesabınıza giriş yapın ve doğaya katkıya devam edin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 28),
                    SurfaceCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _emailController,
                            enabled: !_isSubmitting,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            validator: _validateEmail,
                            style: TextStyle(color: AppColors.textPrimaryOf(context)),
                            decoration: InputDecoration(
                              labelText: 'E-posta',
                              hintText: 'ornek@ecotrack.org',
                              prefixIcon: Icon(
                                Icons.email_outlined,
                                color: AppColors.textSecondaryOf(context),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            enabled: !_isSubmitting,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _handleSignIn(),
                            validator: _validatePassword,
                            style: TextStyle(color: AppColors.textPrimaryOf(context)),
                            decoration: InputDecoration(
                              labelText: 'Şifre',
                              hintText: '••••••••',
                              prefixIcon: Icon(
                                Icons.lock_outline,
                                color: AppColors.textSecondaryOf(context),
                              ),
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Şifreyi Göster'
                                    : 'Şifreyi Gizle',
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: AppColors.textSecondaryOf(context),
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed:
                                  _isSubmitting ? null : _openForgotPassword,
                              child: const Text('Şifremi Unuttum'),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: _isSubmitting ? null : _handleSignIn,
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Giriş Yap'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _isSubmitting ? null : _handleDemoContinue,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimaryOf(context),
                        side: BorderSide(color: AppColors.surfaceBorderOf(context)),
                      ),
                      icon: const Icon(Icons.explore_outlined, size: 18),
                      label: const Text('Demo Hesapla Devam Et'),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Hesabınız yok mu?',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: AppColors.textSecondaryOf(context),
                          ),
                        ),
                        TextButton(
                          onPressed: _isSubmitting ? null : _openRegister,
                          child: const Text('Kayıt Ol'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

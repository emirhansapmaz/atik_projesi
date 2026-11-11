import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/surface_card.dart';
import '../../providers/auth_provider.dart';
import '../navigation/main_shell_view.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    final text = value?.trim() ?? '';
    if (text.length < 2) {
      return 'Ad Soyad en az 2 karakter olmalıdır.';
    }
    return null;
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
    if (text.length < 6) {
      return 'Şifre en az 6 karakter olmalıdır.';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value != _passwordController.text) {
      return 'Şifreler eşleşmiyor.';
    }
    return null;
  }

  Future<void> _handleRegister() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);

    AuthProvider? authProvider;
    try {
      authProvider = context.read<AuthProvider>();
    } catch (_) {}

    final success = authProvider != null
        ? await authProvider.register(
            fullName: _fullNameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
          )
        : true;

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const MainShellView()),
        (_) => false,
      );
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Hesabınız oluşturuldu! EcoTrack dünyasına hoş geldiniz.'),
          backgroundColor: AppColors.surface,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      final error = authProvider.errorMessage ?? 'Kayıt oluşturulamadı.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.statusError,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        title: const Text('Yeni Hesap Oluştur'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Aramıza Katılın',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Atıkları tanıyın, çevre ihbarlarıyla şehrinize destek olun.',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SurfaceCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _fullNameController,
                            enabled: !_isSubmitting,
                            textInputAction: TextInputAction.next,
                            validator: _validateName,
                            style: TextStyle(color: AppColors.textPrimaryOf(context)),
                            decoration: InputDecoration(
                              labelText: 'Ad Soyad',
                              hintText: 'Örn: Emirhan Sapmaz',
                              prefixIcon: Icon(
                                Icons.person_outline,
                                color: AppColors.textSecondaryOf(context),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
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
                            textInputAction: TextInputAction.next,
                            validator: _validatePassword,
                            style: TextStyle(color: AppColors.textPrimaryOf(context)),
                            decoration: InputDecoration(
                              labelText: 'Şifre',
                              hintText: 'En az 6 karakter',
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
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _confirmPasswordController,
                            enabled: !_isSubmitting,
                            obscureText: _obscureConfirmPassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _handleRegister(),
                            validator: _validateConfirmPassword,
                            style: TextStyle(color: AppColors.textPrimaryOf(context)),
                            decoration: InputDecoration(
                              labelText: 'Şifre Tekrar',
                              hintText: 'Şifrenizi doğrulayın',
                              prefixIcon: Icon(
                                Icons.lock_outline,
                                color: AppColors.textSecondaryOf(context),
                              ),
                              suffixIcon: IconButton(
                                tooltip: _obscureConfirmPassword
                                    ? 'Şifreyi Göster'
                                    : 'Şifreyi Gizle',
                                onPressed: () => setState(
                                  () => _obscureConfirmPassword =
                                      !_obscureConfirmPassword,
                                ),
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: AppColors.textSecondaryOf(context),
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          ElevatedButton(
                            onPressed: _isSubmitting ? null : _handleRegister,
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Kayıt Ol'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Zaten hesabınız var mı?',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: AppColors.textSecondaryOf(context),
                          ),
                        ),
                        TextButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text('Giriş Yap'),
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

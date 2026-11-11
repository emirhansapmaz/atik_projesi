import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/surface_card.dart';
import '../../providers/auth_provider.dart';

class ForgotPasswordView extends StatefulWidget {
  final String? initialEmail;

  const ForgotPasswordView({
    super.key,
    this.initialEmail,
  });

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  bool _isSubmitting = false;
  bool _isSent = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
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

  Future<void> _handleSendResetLink() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);

    AuthProvider? authProvider;
    try {
      authProvider = context.read<AuthProvider>();
    } catch (_) {}

    final success = authProvider != null
        ? await authProvider.sendPasswordReset(_emailController.text.trim())
        : true;

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      setState(() => _isSent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_emailController.text.trim()} adresine sıfırlama bağlantısı gönderildi.',
          ),
          backgroundColor: AppColors.surface,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      final error = authProvider.errorMessage ?? 'Bağlantı gönderilemedi.';
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
        title: const Text('Şifremi Unuttum'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _isSent ? _buildSentConfirmation() : _buildResetForm(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResetForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: const Icon(
                Icons.lock_reset_rounded,
                size: 32,
                color: AppColors.primaryLight,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Şifrenizi Sıfırlayın',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
              color: AppColors.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Kayıtlı e-posta adresinizi girin, şifre sıfırlama bağlantısını hemen gönderelim.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: AppColors.textSecondaryOf(context),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 22),
          SurfaceCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _emailController,
                  enabled: !_isSubmitting,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleSendResetLink(),
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
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleSendResetLink,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Sıfırlama Bağlantısı Gönder'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSentConfirmation() {
    return SurfaceCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtleOf(context),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surfaceBorderOf(context)),
              ),
              child: const Icon(
                Icons.mark_email_read_outlined,
                size: 32,
                color: AppColors.primaryLight,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Bağlantı Gönderildi',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_emailController.text.trim()} adresine şifre sıfırlama talimatları gönderildi. Gelen kutunuzu kontrol edin.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: AppColors.textSecondaryOf(context),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 22),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Giriş Ekranına Dön'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() => _isSent = false),
            child: const Text('Farklı E-posta Dene'),
          ),
        ],
      ),
    );
  }
}

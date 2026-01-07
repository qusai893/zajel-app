import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../providers/auth_provider.dart';
import '../appColors.dart';
import 'dashboard_screen.dart'; // Eğer MainScreen buradaysa
import '../main.dart'; // Veya buradaysa

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // --- MANTIK DEĞİŞKENLERİ (DOKUNULMADI) ---
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isTestingConnection = false;

  @override
  void initState() {
    super.initState();
    // _testConnection(); // İsteğe bağlı, orijinal koddaki gibi kapalı
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- MANTIK FONKSİYONLARI (DOKUNULMADI) ---
  Future<void> _testConnection() async {
    setState(() {
      _isTestingConnection = true;
    });
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _isTestingConnection = false;
    });
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.login(
        _usernameController.text.trim(),
        _passwordController.text.trim(),
      );

      if (!mounted) return;

      if (success) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainScreen(),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text(authProvider.errorMessage)),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(20),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // --- TASARIM BÖLÜMÜ ---
  @override
  Widget build(BuildContext context) {
    // Klavye açıldığında ekranın sıkışmasını önlemek için height hesabı
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 1. Arkaplan Dekoru (Üst kısımdaki dalga/gold alan)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.45,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, Color(0xFFC69C50)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
            ),
          ),

          // 2. Ana İçerik
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 20.0),
                child: Consumer<AuthProvider>(
                  builder: (context, authProvider, child) {
                    return ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 450),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // LOGO ALANI
                          _buildLogoSection(),

                          const SizedBox(height: 30),

                          // BEYAZ GİRİŞ KARTI
                          Container(
                            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.textPrimary.withOpacity(0.1),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'تسجيل الدخول',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'مرحباً بك مجدداً في زاجل',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.secondary.withOpacity(0.8),
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                                const SizedBox(height: 30),
                                _buildLoginForm(authProvider),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // GİRİŞ BUTONU (Kartın dışında, daha belirgin)
                          _buildLoginButton(authProvider),

                          // ALT BİLGİ
                          const SizedBox(height: 30),
                          Text(
                            '© 2025 Zajel Payment Systems',
                            style: TextStyle(
                              color: AppColors.textPrimary.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),

                          // DEBUG BAĞLANTI TESTİ GÖSTERGESİ
                          if (_isTestingConnection)
                            Padding(
                              padding: const EdgeInsets.only(top: 20),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          AppColors.primary),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text('Bağlantı test ediliyor...',
                                      style: TextStyle(
                                          color: AppColors.secondary)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Logo Tasarımı
  Widget _buildLogoSection() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4), // Dış beyaz çerçeve kalınlığı
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.2), // Yarı saydam dış halka
          ),
          child: Container(
            width: 110,
            height: 110,
            padding: const EdgeInsets.all(15), // Logonun iç boşluğu
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Image.asset(
              'assets/images/zajelLogo.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                // Eğer resim bulunamazsa fallback ikon göster
                return const Icon(
                  Icons.account_balance_wallet,
                  size: 50,
                  color: AppColors.primary,
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'زاجل',
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w900,
            color: Colors.white, // Koyu arka plan üstünde beyaz yazı
            letterSpacing: 1,
            shadows: [
              Shadow(
                blurRadius: 10.0,
                color: Colors.black26,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Form Tasarımı
  Widget _buildLoginForm(AuthProvider authProvider) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Kullanıcı Adı
          TextFormField(
            controller: _usernameController,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: 'اسم المستخدم',
              hintText: 'أدخل اسم المستخدم',
              prefixIcon: const Icon(Icons.person_rounded),
              // Floating label stili
              floatingLabelStyle: const TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'يرجى إدخال اسم المستخدم';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Şifre
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: 'كلمة المرور',
              hintText: 'أدخل كلمة المرور',
              prefixIcon: const Icon(Icons.lock_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: AppColors.secondary,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              floatingLabelStyle: const TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'يرجى إدخال كلمة المرور';
              }
              if (value.length < 3) {
                return 'كلمة المرور قصيرة جداً';
              }
              return null;
            },
          ),

          // Hata Mesajı Alanı
          if (authProvider.errorMessage.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 20),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.error, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      authProvider.errorMessage,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Buton Tasarımı
  Widget _buildLoginButton(AuthProvider authProvider) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        gradient: AppColors.primaryGradient, // Gradient kullanımı
      ),
      child: ElevatedButton(
        onPressed: authProvider.isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors
              .transparent, // Container gradient'i görünebilsin diye transparent
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent, // Kendi gölgesini kapattık
          disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: authProvider.isLoading
            ? const SizedBox(
                width: 30,
                height: 30,
                child: SpinKitThreeBounce(
                  color: Colors.white,
                  size: 20,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'تسجيل الدخول',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded),
                ],
              ),
      ),
    );
  }
}

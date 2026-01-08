import 'package:flutter/material.dart';
import 'package:zajel/models/transfer_model.dart';
import 'package:zajel/providers/auth_provider.dart';
import 'package:zajel/screens/transfer_detail_screen.dart';
import 'package:zajel/widgets/password_change_dialog.dart';
import '../appColors.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'login_screen.dart';
import '../models/customer.dart';

class AccountScreen extends StatefulWidget {
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      authProvider.refreshAccountData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          final customer = authProvider.currentCustomer;

          if (customer == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.2),
                          blurRadius: 15,
                        )
                      ],
                    ),
                    child: const CircularProgressIndicator(
                        color: AppColors.primary),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'جاري تحميل بيانات الحساب...',
                    style: TextStyle(
                        fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              bool isMobile = constraints.maxWidth < 600;

              return RefreshIndicator(
                onRefresh: () async {
                  await authProvider.refreshAccountData();
                },
                color: AppColors.primary,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // Modern Sliver AppBar
                    _buildSliverAppBar(context),

                    // İçerik
                    SliverPadding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 20 : 32,
                        vertical: 24,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          // Profil Başlığı
                          _buildProfileHeader(customer, isMobile),

                          // const SizedBox(height: 30),

                          // // Bakiye Kartları
                          // _buildSectionTitle('الرصيد الحالي'),
                          // const SizedBox(height: 12),
                          // _buildBalanceCards(customer, isMobile),

                          const SizedBox(height: 30),

                          // İstatistikler
                          _buildSectionTitle('إحصائيات الحساب'),
                          const SizedBox(height: 12),
                          _buildAccountStats(authProvider, isMobile),

                          const SizedBox(height: 30),

                          // Ayarlar ve Çıkış
                          // _buildActionButtons(isMobile),

                          const SizedBox(height: 50),
                        ]),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // --- Sliver AppBar ---
  SliverAppBar _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 80.0,
      floating: true,
      pinned: true,
      elevation: 0,
      backgroundColor: AppColors.primary,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'ملفي الشخصي',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
        centerTitle: true,
        background: Container(
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.refresh_rounded,
                color: Colors.white, size: 20),
          ),
          onPressed: () {
            final authProvider = context.read<AuthProvider>();
            authProvider.refreshAccountData();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('تم تحديث البيانات',
                    style: TextStyle(fontFamily: 'Cairo')),
                behavior: SnackBarBehavior.floating,
                backgroundColor: AppColors.success,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                duration: const Duration(seconds: 1),
              ),
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // --- Profil Header ---
  Widget _buildProfileHeader(Customer customer, bool isMobile) {
    final userName =
        customer.cusName!.isNotEmpty ? customer.cusName : customer.cusName;
    final initials = _getInitials(userName.toString());

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppColors.primary.withOpacity(0.3), width: 2),
            ),
            child: CircleAvatar(
              radius: isMobile ? 40 : 50,
              backgroundColor: AppColors.primary,
              child: Text(
                initials,
                style: TextStyle(
                  fontSize: isMobile ? 28 : 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // İsim
          Text(
            userName.toString(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isMobile ? 22 : 26,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              fontFamily: 'Cairo',
            ),
          ),

          const SizedBox(height: 4),

          // Kullanıcı Adı
          Text(
            '${customer.cusName}',
            style: TextStyle(
                fontSize: 14,
                color: AppColors.secondary,
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w500),
          ),

          const SizedBox(height: 20),
          Divider(color: AppColors.border.withOpacity(0.5)),
          const SizedBox(height: 10),

          // Alt Bilgiler (ID ve Tarih)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMiniInfoChip(
                icon: Icons.badge_outlined,
                label: 'رقم العميل',
                value: '${customer.clientId}',
              ),
              Container(width: 1, height: 40, color: AppColors.border),
              _buildMiniInfoChip(
                icon: Icons.calendar_today_outlined,
                label: 'عضو منذ',
                value: DateFormat('yyyy/MM/dd').format(
                    DateTime.now()), // API'den tarih gelmediği için şimdilik
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniInfoChip(
      {required IconData icon, required String label, required String value}) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.secondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                  color: AppColors.secondary,
                  fontSize: 12,
                  fontFamily: 'Cairo'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 15,
            fontFamily: 'Cairo',
          ),
        ),
      ],
    );
  }

  // --- Bakiye Kartları ---
  Widget _buildBalanceCards(Customer customer, bool isMobile) {
    return Row(
      children: [
        Expanded(
          child: _buildSingleBalanceCard(
            currency: 'ل.س',
            balance: customer.cusBalanceSyr,
            color: const Color(0xFFD8AB59), // Gold
            isMobile: isMobile,
          ),
        ),
        SizedBox(width: isMobile ? 12 : 20),
        Expanded(
          child: _buildSingleBalanceCard(
            currency: 'USD',
            balance: customer.cusBalanceDollar,
            color: const Color(0xFF2E7D32), // Green
            isMobile: isMobile,
          ),
        ),
      ],
    );
  }

  Widget _buildSingleBalanceCard({
    required String currency,
    required double balance,
    required Color color,
    required bool isMobile,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              currency,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                fontFamily: 'Cairo',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            balance.toStringAsFixed(2),
            style: TextStyle(
              fontSize: isMobile ? 18 : 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }

  // --- İstatistikler ---
  Widget _buildAccountStats(AuthProvider authProvider, bool isMobile) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.9,
      children: [
        _buildStatBox(
          title: 'الحوالات',
          value: authProvider.totalTransfers.toString(),
          icon: Icons.swap_horiz_rounded,
          color: Colors.blue,
        ),
        _buildStatBox(
          title: 'المستلمين',
          value: authProvider.totalContacts.toString(),
          icon: Icons.people_outline_rounded,
          color: Colors.purple,
        ),
        _buildStatBox(
          title: 'نشاط', // Duration yerine placeholder activity
          value:
              authProvider.totalSentTransfers.toInt() > 10 ? 'عالي' : 'منخفض',
          icon: Icons.analytics_outlined,
          color: Colors.orange,
        ),
      ],
    );
  }

  Widget _buildStatBox({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              fontFamily: 'Cairo',
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.secondary,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }

  // --- Son Transferler ---
  Widget _buildRecentTransfers(
    AuthProvider authProvider,
    bool isMobile,
  ) {
    final recentTransfers = authProvider.recentTransfers;

    if (recentTransfers.isEmpty) {
      return GestureDetector(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border.withOpacity(0.5)),
          ),
          child: Column(
            children: [
              Icon(Icons.inbox_outlined,
                  size: 40, color: AppColors.secondary.withOpacity(0.4)),
              const SizedBox(height: 10),
              Text(
                'لا توجد نشاطات حديثة',
                style:
                    TextStyle(color: AppColors.secondary, fontFamily: 'Cairo'),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: recentTransfers.asMap().entries.map((entry) {
          final index = entry.key;
          final transfer = entry.value; // Bu artık TransferModel
          final isLast = index == recentTransfers.length - 1;

          // TransferModel'in özelliklerini doğrudan kullan
          final isIncoming = transfer.isIncoming;
          final amount = transfer.amount;
          final currency = transfer.currency;
          final otherParty =
              transfer.name; // veya receiverName/senderName'e göre
          final date = transfer.date;
          final status = transfer.status;

          return Column(
            children: [
              _buildRecentTransferItem(
                title: otherParty,
                amount: amount,
                currency: currency,
                date: _formatTransferDate(date), // Date'i formatla
                isIncoming: isIncoming,
                status: status,
              ),
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Divider(
                      height: 1, color: AppColors.border.withOpacity(0.5)),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

// Yeni formatlama fonksiyonu
  String _formatTransferDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'اليوم ${DateFormat('HH:mm').format(date)}';
    } else if (difference.inDays == 1) {
      return 'أمس ${DateFormat('HH:mm').format(date)}';
    } else {
      return DateFormat('dd/MM', 'ar').format(date);
    }
  }

  Widget _buildRecentTransferItem({
    required String title,
    required double amount,
    required String currency,
    required String date,
    required bool isIncoming,
    required int status,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // İkon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (isIncoming ? AppColors.success : AppColors.primary)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isIncoming
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: isIncoming ? AppColors.success : AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),

          // Detaylar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontFamily: 'Cairo',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.secondary,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),

          // Miktar ve Durum
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${amount.toStringAsFixed(0)} $currency',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isIncoming ? AppColors.success : AppColors.error,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _getStatusText(status),
                style: TextStyle(
                  fontSize: 11,
                  color: _getStatusColor(status),
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Eylem Butonları ---
  // Widget _buildActionButtons(bool isMobile) {
  //   return Column(
  //     children: [
  //       // Şifre Değiştir
  //       _buildSettingsButton(
  //         label: 'تغيير كلمة المرور',
  //         icon: Icons.lock_outline_rounded,
  //         onTap: () {
  //           showDialog(
  //             context: context,
  //             builder: (context) => PasswordChangeDialog(),
  //           );
  //         },
  //         color: AppColors.primary,
  //       ),

  //       const SizedBox(height: 16),

  //       // Çıkış Yap
  //       _buildSettingsButton(
  //         label: 'تسجيل الخروج',
  //         icon: Icons.logout_rounded,
  //         onTap: () => _showLogoutConfirmation(),
  //         color: AppColors.error,
  //         isOutlined: true,
  //       ),
  //     ],
  //   );
  // }

  Widget _buildSettingsButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
    bool isOutlined = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: isOutlined ? Colors.transparent : color,
          foregroundColor: isOutlined ? color : Colors.white,
          elevation: isOutlined ? 0 : 4,
          shadowColor: isOutlined ? Colors.transparent : color.withOpacity(0.4),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: isOutlined ? BorderSide(color: color) : BorderSide.none,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Yardımcı Başlık ---
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
        fontFamily: 'Cairo',
      ),
    );
  }

  // --- Yardımcı Metotlar ---
  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'اليوم ${DateFormat('HH:mm').format(date)}';
      } else if (difference.inDays == 1) {
        return 'أمس ${DateFormat('HH:mm').format(date)}';
      } else {
        return DateFormat('dd/MM', 'ar').format(date);
      }
    } catch (e) {
      return dateString;
    }
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case 1:
        return Colors.orange; // Gönderildi
      case 2:
        return Colors.green; // Teslim edildi
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(int status) {
    switch (status) {
      case 1:
        return 'تم الارسال';
      case 2:
        return 'تم الاستلام';
      default:
        return 'غير معروف ';
    }
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('تسجيل الخروج',
              style:
                  TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
              textAlign: TextAlign.right),
          content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج؟',
              style: TextStyle(fontFamily: 'Cairo'),
              textAlign: TextAlign.right),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء',
                  style: TextStyle(
                      color: AppColors.secondary,
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                final authProvider = context.read<AuthProvider>();
                authProvider.logout();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('تسجيل الخروج',
                  style: TextStyle(
                      fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}

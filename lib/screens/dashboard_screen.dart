import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:zajel/models/customer_balance_model.dart';
import 'package:zajel/screens/new_transfer_screen.dart';
import 'package:zajel/screens/transfer_detail_screen.dart';
import '../appColors.dart';
import '../models/transfer_model.dart';
import '../models/balance_model.dart';
import '../providers/auth_provider.dart';
import 'transfers_screen.dart';

class DashboardScreen extends StatelessWidget {
  final CustomerBalance? currentBalance;
  final List<TransferModel> sentTransfers;
  final List<TransferModel> receivedTransfers;
  final bool isLoading;
  final VoidCallback onRefresh;

  const DashboardScreen({
    Key? key,
    required this.currentBalance,
    required this.sentTransfers,
    required this.receivedTransfers,
    required this.isLoading,
    required this.onRefresh,
  }) : super(key: key);

  Future<void> redirect(BuildContext context, Widget newRoute) async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (context) => newRoute));

    print("🔄 Dashboard: Sayfadan dönüldü, veriler yenileniyor...");
    onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    return _buildDashboardBody(context);
  }

  Widget _buildDashboardBody(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final customer = authProvider.currentCustomer;
    final userName = customer?.cusName ?? "";

    // ⭐⭐⭐ KRİTİK: Önce API'den gelen veriyi kullan
    // API verisi yoksa Provider'daki veriyi göster (ilk yüklemede)
    final double displaySyrBalance = currentBalance != null
        ? currentBalance!.balanceSyr.toDouble()
        : (customer?.cusBalanceSyr.toDouble() ?? 0.0);

    final double displayDollarBalance = currentBalance != null
        ? currentBalance!.balanceDollar.toDouble()
        : (customer?.cusBalanceDollar.toDouble() ?? 0.0);

    print('📊 Dashboard Render:');
    print('   💵 Gösterilen Dollar: $displayDollarBalance');
    print('   💴 Gösterilen SYP: $displaySyrBalance');
    print('   🔄 Loading: $isLoading');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isMobile = constraints.maxWidth < 800;
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(isMobile, context, userName, displaySyrBalance,
                  displayDollarBalance),
              SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 20 : 40,
                  vertical: 24,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildSectionHeader(
                      context: context,
                      title: 'المحفظة والرصيد',
                      actionButton: ElevatedButton.icon(
                        onPressed: () => redirect(context, NewTransferScreen()),
                        icon: const Icon(Icons.add_circle_outline_rounded,
                            size: 20),
                        label: const Text('حوالة جديدة',
                            style: TextStyle(fontFamily: 'Cairo')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.textPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      isMobile: isMobile,
                    ),
                    SizedBox(height: isMobile ? 16 : 24),
                    _buildBalanceGrid(
                        isMobile, displaySyrBalance, displayDollarBalance),
                    SizedBox(height: isMobile ? 32 : 48),
                    _buildTransfersSection(
                      context: context,
                      title: "الحوالات المرسلة",
                      transfers: sentTransfers,
                      isMobile: isMobile,
                      icon: Icons.arrow_upward_rounded,
                      iconColor: AppColors.primary,
                    ),
                    SizedBox(height: isMobile ? 24 : 32),
                    _buildTransfersSection(
                      context: context,
                      title: "الحوالات المستلمة",
                      transfers: receivedTransfers,
                      isMobile: isMobile,
                      icon: Icons.arrow_downward_rounded,
                      iconColor: AppColors.success,
                    ),
                    const SizedBox(height: 80),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(bool isMobile, BuildContext context,
      String userName, double syrBalance, double dollarBalance) {
    return SliverAppBar(
      expandedHeight: isMobile ? 180 : 200,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.primary,
      stretch: true,
      actions: [
        if (isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(12.0),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2)),
            ),
          )
        else
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () {
              print('🔄 Manuel yenileme butonu tıklandı');
              onRefresh();
            },
            tooltip: 'تحديث',
          ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(gradient: AppColors.primaryGradient),
          child: Stack(
            children: [
              Positioned(
                  right: -50,
                  top: -50,
                  child: CircleAvatar(
                      radius: 100,
                      backgroundColor: Colors.white.withOpacity(0.1))),
              Positioned(
                  left: -30,
                  bottom: -30,
                  child: CircleAvatar(
                      radius: 80,
                      backgroundColor: Colors.white.withOpacity(0.1))),
              Positioned(
                bottom: 30,
                right: 20,
                left: 20,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مرحباً بك،',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                          fontFamily: 'Cairo'),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            userName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '\$${dollarBalance.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
                            ),
                            Text(
                              '${syrBalance.toStringAsFixed(0)} SYP',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 14),
                            ),
                          ],
                        )
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'آخر تحديث للبيانات: ${DateFormat('HH:mm').format(DateTime.now())}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontFamily: 'Cairo'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(20),
        child: Container(
          height: 20,
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30), topRight: Radius.circular(30)),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required BuildContext context,
    required String title,
    Widget? actionButton,
    required bool isMobile,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: isMobile ? 20 : 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            fontFamily: 'Cairo',
          ),
        ),
        if (actionButton != null) actionButton,
      ],
    );
  }

  Widget _buildBalanceGrid(
      bool isMobile, double syrBalance, double dollarBalance) {
    final balances = [
      BalanceModel(
        currency: 'الدولار الأمريكي',
        amount: dollarBalance,
        symbol: '\$',
        color: const Color(0xFF2E7D32),
      ),
      BalanceModel(
        currency: 'الليرة السورية',
        amount: syrBalance,
        symbol: 'ل.س',
        color: const Color(0xFFD8AB59),
      ),
    ];

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 1 : 2,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: isMobile ? 1.8 : 2.2,
      ),
      itemCount: balances.length,
      itemBuilder: (context, index) {
        return _buildPremiumBalanceCard(balances[index]);
      },
    );
  }

  Widget _buildPremiumBalanceCard(BalanceModel balance) {
    bool isDollar = balance.symbol == '\$';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 6,
              child: Container(color: balance.color),
            ),
            Positioned(
              right: -20,
              bottom: -20,
              child: Icon(
                isDollar ? Icons.attach_money : Icons.account_balance_wallet,
                size: 100,
                color: balance.color.withOpacity(0.05),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: balance.color.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isDollar ? Icons.attach_money : Icons.money,
                          color: balance.color,
                          size: 20,
                        ),
                      ),
                      Text(
                        balance.currency,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الرصيد الحالي',
                        style: TextStyle(
                          color: AppColors.textSecondary.withOpacity(0.6),
                          fontSize: 12,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            balance.amount.toStringAsFixed(isDollar ? 2 : 0),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            balance.symbol,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: balance.color,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransfersSection({
    required BuildContext context,
    required String title,
    required List<TransferModel> transfers,
    required bool isMobile,
    required IconData icon,
    required Color iconColor,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
            if (transfers.isNotEmpty)
              TextButton(
                onPressed: () => redirect(context, TransfersScreen()),
                child: const Text('عرض الكل',
                    style: TextStyle(
                        fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (transfers.isEmpty)
          isLoading ? _buildLoadingState() : _buildEmptyState()
        else
          ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: transfers.take(3).length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _buildTransferItem(context, transfers[index], index == 0);
            },
          ),
      ],
    );
  }

  Widget _buildTransferItem(
      BuildContext context, TransferModel transfer, bool showHint) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: AnimatedScaleWidget(
        child: Material(
          color: Colors.white,
          clipBehavior: Clip.hardEdge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.border.withOpacity(0.5)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            splashColor: AppColors.primary.withOpacity(0.1),
            highlightColor: AppColors.primary.withOpacity(0.05),
            onTap: () {
              HapticFeedback.lightImpact();
            },
            onLongPress: () async {
              await HapticFeedback.mediumImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      TransferDetailScreen(transfer: transfer),
                ),
              );
            },
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color:
                              _getStatusColor(transfer.status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          transfer.isIncoming
                              ? Icons.arrow_downward
                              : Icons.arrow_upward,
                          color: _getStatusColor(transfer.status),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              transfer.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                                fontFamily: 'Cairo',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.access_time_rounded,
                                    size: 12,
                                    color: AppColors.textSecondary
                                        .withOpacity(0.7)),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDate(transfer.date),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary
                                        .withOpacity(0.7),
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${transfer.amount.toStringAsFixed(0)} ${transfer.currency}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: transfer.isIncoming
                                  ? AppColors.success
                                  : AppColors.error,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: transfer.statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: transfer.statusColor.withOpacity(0.3)),
                            ),
                            child: Text(
                              transfer.statusText,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: transfer.statusColor,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (showHint)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.05),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.touch_app_rounded,
                            size: 12,
                            color: AppColors.textSecondary.withOpacity(0.5)),
                        const SizedBox(width: 6),
                        Text(
                          'اضغط مطولاً للتفاصيل',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary.withOpacity(0.6),
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(30),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_rounded,
              size: 40, color: AppColors.secondary.withOpacity(0.3)),
          const SizedBox(height: 10),
          Text(
            'لا توجد حوالات حديثة',
            style: TextStyle(
              color: AppColors.secondary.withOpacity(0.6),
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case 1:
        return Colors.orange;
      case 2:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM HH:mm').format(date);
  }
}

class AnimatedScaleWidget extends StatefulWidget {
  final Widget child;

  const AnimatedScaleWidget({super.key, required this.child});

  @override
  State<AnimatedScaleWidget> createState() => _AnimatedScaleWidgetState();
}

class _AnimatedScaleWidgetState extends State<AnimatedScaleWidget> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        child: widget.child,
      ),
    );
  }
}

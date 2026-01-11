import 'package:flutter/material.dart';
import 'package:zajel/appColors.dart';
import 'package:zajel/main.dart';
import 'package:zajel/models/transfer_model.dart';
import 'package:zajel/screens/dashboard_screen.dart';
import 'package:zajel/screens/new_transfer_screen.dart';
import 'package:zajel/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:zajel/widgets/transfer_filter_chip.dart';
import 'package:zajel/widgets/transfer_card.dart';
import 'dart:ui' as ui;

class TransfersScreen extends StatefulWidget {
  @override
  _TransfersScreenState createState() => _TransfersScreenState();
}

class _TransfersScreenState extends State<TransfersScreen> {
  // --- MANTIK DEĞİŞKENLERİ ---
  List<TransferModel> _allTransfers = [];
  List<TransferModel> _displayedTransfers = []; // Ekrana basılan liste
  List<TransferModel> _statsBaseList =
      []; // İstatistikler için liste (Artık displayed ile aynı çalışacak)

  TransferType _currentFilter = TransferType.all;
  String _selectedCurrency = 'ALL'; // 'ALL', 'USD', 'SYP'

  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  String _searchQuery = '';

  // Tarih Aralığı
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _loadTransfers();
  }

  void redirect(Widget newRoute) {
    Navigator.pushReplacement(
        (context), MaterialPageRoute(builder: (context) => newRoute));
  }

  Future<void> _loadTransfers() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _searchQuery = '';
      _selectedDateRange = null; // Sıfırla
      _selectedCurrency = 'ALL';
      _currentFilter = TransferType.all;
    });

    try {
      final transfers = await ApiService.getAllTransfers();
      transfers.sort((a, b) => b.date.compareTo(a.date));

      if (!mounted) return;

      setState(() {
        _allTransfers = transfers;
        _statsBaseList = transfers;
        _displayedTransfers = transfers;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- KRİTİK DÜZENLEME BURADA YAPILDI ---
  void _updateFilteredTransfers() {
    List<TransferModel> tempList = _allTransfers;

    // 1. Tarih Aralığı Filtresi
    if (_selectedDateRange != null) {
      tempList = tempList.where((transfer) {
        final transferDate = DateTime(
            transfer.date.year, transfer.date.month, transfer.date.day);

        final startDate = DateTime(_selectedDateRange!.start.year,
            _selectedDateRange!.start.month, _selectedDateRange!.start.day);

        final endDate = DateTime(_selectedDateRange!.end.year,
            _selectedDateRange!.end.month, _selectedDateRange!.end.day);

        return (transferDate.isAtSameMomentAs(startDate) ||
                transferDate.isAfter(startDate)) &&
            (transferDate.isAtSameMomentAs(endDate) ||
                transferDate.isBefore(endDate));
      }).toList();
    }

    // 2. Arama Filtresi
    if (_searchQuery.isNotEmpty) {
      tempList = tempList.where((transfer) {
        return transfer.transferNumber
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            transfer.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            transfer.transferReason
                .toLowerCase()
                .contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // 3. Tip Filtresi (Sent/Received) - ARTIK STATS GÜNCELLENMEDEN ÖNCE YAPILIYOR
    if (_currentFilter != TransferType.all) {
      tempList = tempList
          .where((transfer) => transfer.type == _currentFilter)
          .toList();
    }

    // 4. Para Birimi Filtresi (USD/SYP) - ARTIK STATS GÜNCELLENMEDEN ÖNCE YAPILIYOR
    if (_selectedCurrency != 'ALL') {
      tempList = tempList
          .where((transfer) => transfer.currency == _selectedCurrency)
          .toList();
    }

    // SONUÇ: Hem ekrandaki liste hem de istatistik listesi filtrelenmiş veriyi alır
    setState(() {
      _displayedTransfers = tempList;
      _statsBaseList =
          tempList; // İstatistikler de artık filtrelenmiş veriden besleniyor
    });
  }

  void _applyTypeFilter(TransferType filterType) {
    setState(() {
      _currentFilter = filterType;
      // setState içinde çağırmaya gerek yok ama mantık akışı için dışarıda olması daha temiz
    });
    _updateFilteredTransfers();
  }

  void _applyCurrencyFilter(String currency) {
    setState(() {
      _selectedCurrency = currency;
    });
    _updateFilteredTransfers();
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTime now = DateTime.now();

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _selectedDateRange,
      saveText: 'تأكيد',
      helpText: 'اختر الفترة الزمنية',
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: AppColors.primary,
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            buttonTheme: ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
      _updateFilteredTransfers();
    }
  }

  void _clearFilters() {
    setState(() {
      _currentFilter = TransferType.all;
      _selectedCurrency = 'ALL';
      _selectedDateRange = null;
      _searchQuery = '';
      _statsBaseList = _allTransfers;
      _displayedTransfers = _allTransfers;
    });
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => redirect(NewTransferScreen()),
        backgroundColor: AppColors.primary,
        icon: Icon(Icons.add, color: Colors.white),
        label: Text('حوالة جديدة',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                color: Colors.white)),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildSliverAppBar(),
            SliverToBoxAdapter(
              child: _buildSearchAndFilterSection(),
            ),
            SliverToBoxAdapter(
              child: _buildStatsSummary(),
            ),
            _buildSliverContent(),
            SliverPadding(padding: EdgeInsets.only(bottom: 80)),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 80.0,
      floating: true,
      pinned: true,
      backgroundColor: AppColors.primary,
      leading: IconButton(
        icon: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 18),
        ),
        onPressed: () => Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => MainScreen())),
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: _isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
          ),
          onPressed: _isLoading ? null : _loadTransfers,
        ),
        SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'الحوالات المرسلة والمستلمة',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
            fontSize: 16,
          ),
        ),
        centerTitle: true,
        background: Container(
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterSection() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Arama ve Tarih Aralığı Butonu
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                      _updateFilteredTransfers();
                    },
                    style: TextStyle(fontFamily: 'Cairo'),
                    decoration: InputDecoration(
                      hintText: 'بحث برقم الحوالة أو الاسم...',
                      hintStyle: TextStyle(
                          color: AppColors.secondary.withOpacity(0.7),
                          fontSize: 13,
                          fontFamily: 'Cairo'),
                      prefixIcon:
                          Icon(Icons.search_rounded, color: AppColors.primary),
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),

              // Tarih Aralığı Butonu
              Container(
                decoration: BoxDecoration(
                  color: _selectedDateRange != null
                      ? AppColors.primary
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, 4)),
                  ],
                ),
                child: IconButton(
                  icon: Icon(Icons.date_range_rounded,
                      color: _selectedDateRange != null
                          ? Colors.white
                          : AppColors.primary),
                  onPressed: () => _selectDateRange(context),
                  tooltip: 'تصفية حسب الفترة',
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          // Seçili Tarih Aralığı Göstergesi
          if (_selectedDateRange != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedDateRange = null; // Sadece tarihi temizle
                  });
                  _updateFilteredTransfers();
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 14, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text(
                        '${DateFormat('yyyy/MM/dd').format(_selectedDateRange!.start)} - ${DateFormat('yyyy/MM/dd').format(_selectedDateRange!.end)}',
                        textDirection: ui.TextDirection.ltr,
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.close_rounded,
                          size: 16, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ),

          // Tip Filtreleri
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: BouncingScrollPhysics(),
            child: Row(
              children: [
                TransferFilterChip(
                  type: TransferType.all,
                  isSelected: _currentFilter == TransferType.all,
                  onTap: () => _applyTypeFilter(TransferType.all),
                ),
                SizedBox(width: 10),
                TransferFilterChip(
                  type: TransferType.sent,
                  isSelected: _currentFilter == TransferType.sent,
                  onTap: () => _applyTypeFilter(TransferType.sent),
                ),
                SizedBox(width: 10),
                TransferFilterChip(
                  type: TransferType.received,
                  isSelected: _currentFilter == TransferType.received,
                  onTap: () => _applyTypeFilter(TransferType.received),
                ),
              ],
            ),
          ),

          SizedBox(height: 10),

          // Para Birimi Filtreleri
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildCurrencyChip('الكل', 'ALL'),
                SizedBox(width: 8),
                _buildCurrencyChip('USD (\$)', 'USD'),
                SizedBox(width: 8),
                _buildCurrencyChip('ليرة سورية', 'SYP'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyChip(String label, String currencyCode) {
    bool isSelected = _selectedCurrency == currencyCode;
    return GestureDetector(
      onTap: () => _applyCurrencyFilter(currencyCode),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black87 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.grey.shade300,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2))
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontFamily: 'Cairo',
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSummary() {
    // Liste boşsa gizle
    if (_statsBaseList.isEmpty &&
        _searchQuery.isEmpty &&
        _currentFilter == TransferType.all &&
        _selectedCurrency == 'ALL' &&
        _selectedDateRange == null) return SizedBox.shrink();

    final sentCount =
        _statsBaseList.where((t) => t.type == TransferType.sent).length;
    final receivedCount =
        _statsBaseList.where((t) => t.type == TransferType.received).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade100)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStatItem('العدد الكلي', '${_statsBaseList.length}',
                Colors.grey.shade800),
            Container(width: 1, height: 20, color: Colors.grey.shade300),
            _buildStatItem('مرسلة', '$sentCount', AppColors.primary),
            Container(width: 1, height: 20, color: Colors.grey.shade300),
            _buildStatItem('مستلمة', '$receivedCount', Colors.green),
            if (_selectedDateRange != null ||
                _currentFilter != TransferType.all ||
                _selectedCurrency != 'ALL' ||
                _searchQuery.isNotEmpty)
              TextButton(
                onPressed: _clearFilters,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size(50, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'مسح',
                  style: TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String count, Color color) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
              fontFamily: 'Cairo'),
        ),
        Text(
          label,
          style: TextStyle(
              fontSize: 10, color: AppColors.secondary, fontFamily: 'Cairo'),
        ),
      ],
    );
  }

  Widget _buildSliverContent() {
    if (_isLoading) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_hasError) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppColors.error),
              SizedBox(height: 16),
              Text(_errorMessage, style: TextStyle(fontFamily: 'Cairo')),
              TextButton(
                onPressed: _loadTransfers,
                child: Text('إعادة المحاولة',
                    style: TextStyle(fontFamily: 'Cairo')),
              )
            ],
          ),
        ),
      );
    }

    if (_displayedTransfers.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
              SizedBox(height: 16),
              Text(
                'لا توجد حوالات',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade500,
                    fontFamily: 'Cairo'),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final transfer = _displayedTransfers[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: TransferCard(transfer: transfer),
          );
        },
        childCount: _displayedTransfers.length,
      ),
    );
  }
}

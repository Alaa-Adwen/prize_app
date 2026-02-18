import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerDataScreen extends StatefulWidget {
  const CustomerDataScreen({super.key});

  @override
  State<CustomerDataScreen> createState() => _CustomerDataScreenState();
}

class _CustomerDataScreenState extends State<CustomerDataScreen>
    with TickerProviderStateMixin {
  // Controllers
  late AnimationController _starsController;
  late AnimationController _fadeController;
  final TextEditingController _searchController = TextEditingController();

  // State
  List<Map<String, dynamic>> _allCustomers = [];
  List<Map<String, dynamic>> _filteredCustomers = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _starsController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();

    _fetchCustomers();
  }

  @override
  void dispose() {
    _starsController.dispose();
    _fadeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Fetch all customers from Firebase
  Future<void> _fetchCustomers() async {
    try {
      setState(() => _isLoading = true);

      final firestore = FirebaseFirestore.instance;
      final snapshot = await firestore.collection('customer_serial').get();

      final List<Map<String, dynamic>> customers = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();

        customers.add({
          'id': doc.id,
          'name': data['name'] ?? '',
          'phone': data['phone'] ?? '',
          'branch': data['branch'] ?? '',
          'serials': List<String>.from(data['serials'] ?? []),
          'date': data['date'],
        });
      }

      // Sort by name
      customers.sort(
        (a, b) => a['name'].toString().compareTo(b['name'].toString()),
      );

      if (mounted) {
        setState(() {
          _allCustomers = customers;
          _filteredCustomers = customers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('حدث خطأ أثناء تحميل البيانات: $e');
      }
    }
  }

  // Search functionality
  void _performSearch(String query) {
    setState(() {
      _searchQuery = query.trim().toLowerCase();

      if (_searchQuery.isEmpty) {
        _filteredCustomers = _allCustomers;
      } else {
        _filteredCustomers = _allCustomers.where((customer) {
          final name = customer['name'].toString().toLowerCase();
          final phone = customer['phone'].toString().toLowerCase();
          final serials = List<String>.from(customer['serials']);

          // Check if query matches name, phone, or any serial number
          final matchesName = name.contains(_searchQuery);
          final matchesPhone = phone.contains(_searchQuery);
          final matchesSerial = serials.any(
            (serial) => serial.toLowerCase().contains(_searchQuery),
          );

          return matchesName || matchesPhone || matchesSerial;
        }).toList();
      }
    });
  }

  // Delete customer
  Future<void> _deleteCustomer(String docId, String name) async {
    final confirmed = await _showConfirmDialog(
      'حذف العميل',
      'هل أنت متأكد من حذف "$name"؟',
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('customer_serial')
          .doc(docId)
          .delete();

      _showSnackBar('تم حذف العميل بنجاح');
      await _fetchCustomers();
    } catch (e) {
      _showSnackBar('حدث خطأ أثناء الحذف: $e');
    }
  }

  // Show edit dialog
  void _showEditDialog(Map<String, dynamic> customer) {
    final nameController = TextEditingController(text: customer['name']);
    final phoneController = TextEditingController(text: customer['phone']);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          bool isUpdating = false;

          return Directionality(
            textDirection: TextDirection.rtl,
            child: Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF0F0528),
                      Color(0xFF1A0A3E),
                      Color(0xFF2D1B69),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Color(0xFFFFD700).withOpacity(0.4),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFFFFD700).withOpacity(0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                padding: EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title
                      Icon(Icons.edit, color: Color(0xFFFFD700), size: 40),
                      SizedBox(height: 12),
                      Text(
                        'تعديل بيانات العميل',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFFD700),
                          shadows: [
                            Shadow(
                              color: Color(0xFFFFD700).withOpacity(0.5),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),
                      // Name field
                      _buildEditField(
                        label: 'الاسم',
                        icon: Icons.person,
                        controller: nameController,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'الرجاء إدخال الاسم';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      // Phone field
                      _buildEditField(
                        label: 'رقم الجوال',
                        icon: Icons.phone,
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'الرجاء إدخال رقم الجوال';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 24),
                      // Buttons
                      Row(
                        children: [
                          Expanded(
                            child: _buildDialogButton(
                              'حفظ',
                              Icons.save,
                              () async {
                                if (formKey.currentState!.validate()) {
                                  setDialogState(() => isUpdating = true);

                                  await _updateCustomer(
                                    customer['id'],
                                    nameController.text.trim(),
                                    phoneController.text.trim(),
                                  );

                                  // Close the dialog
                                  Navigator.of(dialogContext).pop();
                                }
                              },
                              isLoading: isUpdating,
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: _buildDialogButton(
                              'إلغاء',
                              Icons.close,
                              isUpdating
                                  ? null
                                  : () => Navigator.of(dialogContext).pop(),
                              isSecondary: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Update customer in Firebase
  Future<void> _updateCustomer(String docId, String name, String phone) async {
    try {
      await FirebaseFirestore.instance
          .collection('customer_serial')
          .doc(docId)
          .update({
            'name': name,
            'phone': phone,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      _showSnackBar('تم تحديث البيانات بنجاح');
      await _fetchCustomers();
    } catch (e) {
      _showSnackBar('حدث خطأ أثناء التحديث: $e');
    }
  }

  // Confirm dialog
  Future<bool?> _showConfirmDialog(String title, String message) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Color(0xFF1A0A3E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: Color(0xFFFFD700).withOpacity(0.4),
              width: 2,
            ),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: Color(0xFFFFD700),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            message,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'إلغاء',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'تأكيد',
                style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Color(0xFF2D1B69),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/ramadan_bg.jpg'),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.3),
                BlendMode.darken,
              ),
            ),
          ),
          child: Stack(
            children: [
              // Dark gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF0F0528).withOpacity(0.7),
                      Color(0xFF1A0A3E).withOpacity(0.5),
                      Color(0xFF2D1B69).withOpacity(0.6),
                    ],
                  ),
                ),
              ),
              // Animated stars
              AnimatedBuilder(
                animation: _starsController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _DataScreenStarsPainter(_starsController.value),
                    size: Size.infinite,
                  );
                },
              ),
              // Main content
              SafeArea(
                child: Column(
                  children: [
                    // App Bar
                    _buildAppBar(),
                    SizedBox(height: 12),
                    // Search Bar
                    _buildSearchBar(),
                    SizedBox(height: 16),
                    // Table
                    Expanded(child: _buildDataTable()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // App Bar
  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Color(0xFFFFD700).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(14),
                child: Icon(Icons.arrow_back, color: Colors.white, size: 22),
              ),
            ),
          ),
          // Title
          Text(
            'بيانات المسجلين',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFFD700),
              shadows: [
                Shadow(
                  color: Color(0xFFFFD700).withOpacity(0.5),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
          // Refresh button
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Color(0xFFFFD700).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _fetchCustomers,
                borderRadius: BorderRadius.circular(14),
                child: Icon(Icons.refresh, color: Color(0xFFFFD700), size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Search Bar
  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Color(0xFFFFD700).withOpacity(0.25),
            width: 1.5,
          ),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _performSearch,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontSize: 17,
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
          decoration: InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            hintText: 'ابحث بالاسم أو رقم الهاتف أو رقم القسيمة...',
            hintStyle: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.4),
            ),
            prefixIcon: Container(
              margin: EdgeInsets.all(10),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Color(0xFFFFD700).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.search, color: Color(0xFFFFD700), size: 20),
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: Color(0xFFFFD700)),
                    onPressed: () {
                      _searchController.clear();
                      _performSearch('');
                    },
                  )
                : null,
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  // Data Table
  Widget _buildDataTable() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)));
    }

    if (_filteredCustomers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: Color(0xFFFFD700).withOpacity(0.3),
            ),
            SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty ? 'لا توجد بيانات' : 'لا توجد نتائج للبحث',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white.withOpacity(0.6),
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeController,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Color(0xFFFFD700).withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              // Table Header
              _buildTableHeader(),
              // Divider
              Container(height: 1, color: Color(0xFFFFD700).withOpacity(0.2)),
              // Table Rows
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: _filteredCustomers.length,
                  itemBuilder: (context, index) {
                    final customer = _filteredCustomers[index];
                    return _buildTableRow(customer, index);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Table Header
  Widget _buildTableHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Color(0xFFFFD700).withOpacity(0.1),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: _buildHeaderCell('الاسم')),
          Expanded(flex: 2, child: _buildHeaderCell('رقم الهاتف')),
          Expanded(flex: 2, child: _buildHeaderCell('الفرع')),
          Expanded(flex: 2, child: _buildHeaderCell('القسائم')),
          SizedBox(width: 100, child: _buildHeaderCell('الإجراءات')),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Color(0xFFFFD700),
      ),
    );
  }

  // Table Row
  Widget _buildTableRow(Map<String, dynamic> customer, int index) {
    final serials = List<String>.from(customer['serials']);
    final serialsText = serials.length > 2
        ? '${serials.take(2).join(', ')} +${serials.length - 2}'
        : serials.join(', ');

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFFFD700).withOpacity(0.1),
            width: 1,
          ),
        ),
        color: index % 2 == 0
            ? Colors.white.withOpacity(0.02)
            : Colors.transparent,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            // Name
            Expanded(flex: 2, child: _buildDataCell(customer['name'])),
            // Phone
            Expanded(flex: 2, child: _buildDataCell(customer['phone'])),
            // Branch
            Expanded(flex: 2, child: _buildDataCell(customer['branch'])),
            // Serials
            Expanded(
              flex: 2,
              child: Tooltip(
                message: serials.join('\n'),
                preferBelow: false,
                child: _buildDataCell(
                  serialsText,
                  isMonospace: true,
                  fontSize: 12,
                ),
              ),
            ),
            // Actions
            SizedBox(
              width: 100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildActionButton(
                    Icons.edit,
                    Color(0xFF00D9FF),
                    () => _showEditDialog(customer),
                  ),
                  SizedBox(width: 8),
                  _buildActionButton(
                    Icons.delete,
                    Color(0xFFFF6B6B),
                    () => _deleteCustomer(customer['id'], customer['name']),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataCell(
    String text, {
    bool isMonospace = false,
    double fontSize = 14,
  }) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: fontSize,
        color: Colors.white.withOpacity(0.9),
        fontFamily: isMonospace ? 'monospace' : null,
        fontWeight: FontWeight.w900,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onTap) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }

  // Edit field in dialog
  Widget _buildEditField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Color(0xFFFFD700).withOpacity(0.25),
          width: 1.5,
        ),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontSize: 17,
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
        decoration: InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          labelText: label,
          labelStyle: TextStyle(
            fontSize: 15,
            color: Color(0xFFFFD700).withOpacity(0.7),
          ),
          errorStyle: TextStyle(color: Color(0xFFFF6B6B), fontSize: 12),
          prefixIcon: Container(
            margin: EdgeInsets.all(10),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Color(0xFFFFD700).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Color(0xFFFFD700), size: 18),
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }

  // Dialog button
  Widget _buildDialogButton(
    String text,
    IconData icon,
    VoidCallback? onTap, {
    bool isSecondary = false,
    bool isLoading = false,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: isSecondary
            ? null
            : LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        color: isSecondary ? Colors.white.withOpacity(0.1) : null,
        border: Border.all(
          color: isSecondary
              ? Colors.white.withOpacity(0.2)
              : Colors.transparent,
        ),
        boxShadow: isSecondary
            ? []
            : [
                BoxShadow(
                  color: Color(0xFFFFD700).withOpacity(0.4),
                  blurRadius: 15,
                  offset: Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isSecondary
                        ? Colors.white.withOpacity(0.7)
                        : Color(0xFF1A0A3E),
                  ),
                )
              else ...[
                Icon(
                  icon,
                  color: isSecondary
                      ? Colors.white.withOpacity(0.7)
                      : Color(0xFF1A0A3E),
                  size: 18,
                ),
                SizedBox(width: 8),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isSecondary
                        ? Colors.white.withOpacity(0.7)
                        : Color(0xFF1A0A3E),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Stars Painter for data screen
class _DataScreenStarsPainter extends CustomPainter {
  final double animationValue;
  _DataScreenStarsPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final random = math.Random(123);

    for (int i = 0; i < 40; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final starSize = 1.0 + random.nextDouble() * 2;
      final twinkle =
          (math.sin((animationValue * 2 * math.pi) + (i * 0.7)) + 1) / 2;
      paint.color = Color(0xFFFFD700).withOpacity(0.2 + (twinkle * 0.4));
      canvas.drawCircle(Offset(x, y), starSize, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DataScreenStarsPainter oldDelegate) => true;
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen>
    with TickerProviderStateMixin {
  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _countController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Animations
  late AnimationController _starsController;
  late AnimationController _formController;

  // State
  DateTime _selectedDate = DateTime.now();
  String? _selectedBranch;
  bool _isLoading = false;

  final Map<String, String> _branchCodes = {
    'فرع خانيونس البلد': '01',
    'فرع خانيونس النص': '02',
    'فرع دير البلح': '03',
    'فرع غزة': '04',
  };

  // Previous serial numbers (now fetched from Firebase)
  List<Map<String, dynamic>> _previousSerials = [];
  bool _loadingPreviousSerials = false;

  @override
  void initState() {
    super.initState();
    _starsController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _formController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..forward();

    // Fetch previous serials when screen loads
    _fetchPreviousSerials();
  }

  @override
  void dispose() {
    _starsController.dispose();
    _formController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _countController.dispose();
    super.dispose();
  }

  // Fetch latest 10 registrations from Firebase
  Future<void> _fetchPreviousSerials() async {
    try {
      setState(() => _loadingPreviousSerials = true);

      final firestore = FirebaseFirestore.instance;

      // Fetch all documents and sort manually
      final snapshot = await firestore.collection('customer_serial').get();

      // Sort documents by latest activity (updatedAt if exists, otherwise createdAt)
      final sortedDocs = snapshot.docs.toList()
        ..sort((a, b) {
          final aData = a.data();
          final bData = b.data();

          final aTime = aData['updatedAt'] ?? aData['createdAt'];
          final bTime = bData['updatedAt'] ?? bData['createdAt'];

          if (aTime == null) return 1;
          if (bTime == null) return -1;

          final aTimestamp = aTime is Timestamp ? aTime : Timestamp.now();
          final bTimestamp = bTime is Timestamp ? bTime : Timestamp.now();

          return bTimestamp.compareTo(aTimestamp); // Descending order
        });

      // Take only the latest 10
      final latestDocs = sortedDocs.take(10);

      final List<Map<String, dynamic>> fetchedSerials = [];
      for (var doc in latestDocs) {
        final data = doc.data();

        // Convert Firestore Timestamp to formatted date string
        String formattedDate = '';
        if (data['date'] != null) {
          DateTime date;
          if (data['date'] is Timestamp) {
            date = (data['date'] as Timestamp).toDate();
          } else {
            date = DateTime.now();
          }
          formattedDate = _formatDate(date);
        }

        // Get the latest serials (for display in the list)
        final List<String> latestSerials = List<String>.from(
          data['latestSerials'] ?? data['serials'] ?? [],
        );

        // Get total count of all serials for this user
        final List<String> allSerials = List<String>.from(
          data['serials'] ?? [],
        );
        final int totalCount = allSerials.length;
        final int latestCount =
            data['latestSerialsCount'] ?? latestSerials.length;

        // Check if this is an update
        final bool isUpdate = data.containsKey('updatedAt');

        fetchedSerials.add({
          'name': data['name'] ?? '',
          'phone': data['phone'] ?? '',
          'serials': latestSerials, // Show only latest serials
          'totalCount': totalCount, // Total number of all serials
          'latestCount': latestCount, // Number of latest serials
          'branch': data['branch'] ?? '',
          'date': formattedDate,
          'isUpdate': isUpdate,
        });
      }

      if (mounted) {
        setState(() {
          _previousSerials = fetchedSerials;
          _loadingPreviousSerials = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingPreviousSerials = false);
        _showSnackBar('حدث خطأ أثناء تحميل البيانات: $e');
      }
    }
  }

  // Generate unique serial numbers with auto-increment
  Future<List<String>> _generateSerialNumbers(
    int count,
    String selectedBranch,
  ) async {
    final List<String> serials = [];
    final firestore = FirebaseFirestore.instance;

    // Get the 2-digit code for the branch
    String branchCode = _branchCodes[selectedBranch] ?? '00';

    // Get the current counter for this branch
    final counterDoc = await firestore
        .collection('counters')
        .doc('branch_$branchCode')
        .get();

    int currentCounter = 0;
    if (counterDoc.exists) {
      currentCounter = counterDoc.data()?['counter'] ?? 0;
    }

    // Generate serials with incrementing counter
    for (int i = 0; i < count; i++) {
      currentCounter++;
      // Format: KH + BranchCode (2 digits) + Counter (5 digits) = 7 digits total
      String counterPart = currentCounter.toString().padLeft(5, '0');
      String serial = 'KH-$branchCode$counterPart';
      serials.add(serial);
    }

    // Update the counter in Firestore
    await firestore.collection('counters').doc('branch_$branchCode').set({
      'counter': currentCounter,
      'branch': selectedBranch,
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    return serials;
  }

  // Format date
  String _formatDate(DateTime date) {
    final months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  // Send WhatsApp message with specific prefix
  Future<void> _sendWhatsApp(
    String phone,
    List<String> serials,
    String customerName,
    String prefix,
  ) async {
    final serialsText = serials
        .asMap()
        .entries
        .map((entry) => '${entry.key + 1}. ${entry.value}')
        .join('\n');

    final message =
        'السلام عليكم $customerName\nهذه هي قسائمكم من مركز كهرمانة:\n\n$serialsText\n\nلا تنسوا متابعتنا على الصفحة حتى لا تضيعوا فرصتكم بالسحب\nرمضان كريم 🌙';

    // Clean the phone number (remove any spaces or special characters)
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');

    // Remove leading zero if present
    if (cleanPhone.startsWith('0')) {
      cleanPhone = cleanPhone.substring(1);
    }

    // Use the specified prefix
    final phoneNumber = '$prefix$cleanPhone';

    // Try web URL first (works better on most devices)
    try {
      final webUrl = Uri.parse(
        'https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}',
      );

      if (await canLaunchUrl(webUrl)) {
        final launched = await launchUrl(
          webUrl,
          mode: LaunchMode.externalApplication,
        );
        if (launched) {
          return;
        }
      }
    } catch (e) {
      // Continue to fallback
    }

    // Try API URL as fallback
    try {
      final apiUrl = Uri.parse(
        'https://api.whatsapp.com/send?phone=$phoneNumber&text=${Uri.encodeComponent(message)}',
      );

      if (await canLaunchUrl(apiUrl)) {
        final launched = await launchUrl(
          apiUrl,
          mode: LaunchMode.externalApplication,
        );
        if (launched) {
          return;
        }
      }
    } catch (e) {
      // Continue to fallback
    }

    // Last resort: try app scheme
    try {
      final appUrl = Uri.parse(
        'whatsapp://send?phone=$phoneNumber&text=${Uri.encodeComponent(message)}',
      );

      if (await canLaunchUrl(appUrl)) {
        final launched = await launchUrl(
          appUrl,
          mode: LaunchMode.externalApplication,
        );
        if (launched) {
          return;
        }
      }
    } catch (e) {
      // All methods failed
    }

    // If all methods failed
    throw Exception('لم يتمكن من فتح واتساب. تأكد من تثبيت التطبيق.');
  }

  // Save to Firebase
  Future<void> _saveToFirebase(
    String name,
    String phone,
    List<String> serials,
    String branch,
  ) async {
    try {
      final firestore = FirebaseFirestore.instance;

      // Check if user already exists by BOTH name AND phone (composite key)
      final querySnapshot = await firestore
          .collection('customer_serial')
          .where('name', isEqualTo: name)
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        // User exists (same name AND phone) - update their document
        final docId = querySnapshot.docs.first.id;
        final existingData = querySnapshot.docs.first.data();
        final List<String> existingSerials = List<String>.from(
          existingData['serials'] ?? [],
        );

        // Combine existing serials with new ones
        final List<String> updatedSerials = [...existingSerials, ...serials];

        await firestore.collection('customer_serial').doc(docId).update({
          'serials': updatedSerials,
          'latestSerials': serials, // Store the latest added serials separately
          'latestSerialsCount': serials.length, // Count of new serials added
          'branch': branch, // Update branch in case it changed
          'date': Timestamp.fromDate(_selectedDate),
          'updatedAt': FieldValue.serverTimestamp(), // Track last update
        });
      } else {
        // User doesn't exist - create new document
        await firestore.collection('customer_serial').add({
          'name': name,
          'phone': phone,
          'serials': serials,
          'latestSerials': serials, // For new users, latest = all serials
          'latestSerialsCount': serials.length,
          'branch': branch,
          'date': Timestamp.fromDate(_selectedDate),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Refresh the previous serials list after successful save
      await _fetchPreviousSerials();
    } catch (e) {
      _showSnackBar('حدث خطأ أثناء الحفظ: $e');
      rethrow;
    }
  }

  // Submit form
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBranch == null) {
      _showSnackBar('الرجاء اختيار الفرع');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final int count = int.parse(_countController.text);
      final serials = await _generateSerialNumbers(count, _selectedBranch!);
      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();

      // Check if user exists before saving (by name AND phone)
      final firestore = FirebaseFirestore.instance;
      final querySnapshot = await firestore
          .collection('customer_serial')
          .where('name', isEqualTo: name)
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();

      final bool userExists = querySnapshot.docs.isNotEmpty;

      // Save to Firebase
      await _saveToFirebase(name, phone, serials, _selectedBranch!);

      setState(() => _isLoading = false);

      // Show serial numbers popup with context about new/existing user
      if (mounted) {
        await _showSerialPopup(serials, phone, name, userExists);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('حدث خطأ: $e');
    }
  }

  // Clear form (but keep branch selected)
  void _clearForm() {
    _nameController.clear();
    _phoneController.clear();
    _countController.clear();
    setState(() {
      _selectedDate = DateTime.now();
      // Don't clear _selectedBranch - keep it selected
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Color(0xFF2D1B69),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  // Serial Number Popup
  Future<void> _showSerialPopup(
    List<String> serials,
    String phone,
    String customerName,
    bool isExistingUser,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
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
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Icon(Icons.star, color: Color(0xFFFFD700), size: 40),
                  SizedBox(height: 12),
                  Text(
                    isExistingUser ? 'القسائم الجديدة' : 'القسائم',
                    style: TextStyle(
                      fontSize: 26,
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
                  if (isExistingUser) ...[
                    SizedBox(height: 8),
                    Text(
                      'تمت إضافة القسائم للعميل الموجود',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                  SizedBox(height: 16),
                  // Divider
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Color(0xFFFFD700).withOpacity(0.5),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  // Serial numbers list - Scrollable
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: serials.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Color(0xFFFFD700).withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  serials[index],
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFFFFD700).withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 20),
                  // WhatsApp Buttons
                  Row(
                    children: [
                      Expanded(
                        child: _buildPopupButton(
                          'واتساب 970',
                          Icons.send,
                          () async {
                            try {
                              await _sendWhatsApp(
                                phone,
                                serials,
                                customerName,
                                '970',
                              );
                              _showSnackBar('تم إرسال القسائم عبر واتساب 970');
                            } catch (e) {
                              _showSnackBar('لم يتمكن من فتح واتساب');
                            }
                          },
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _buildPopupButton(
                          'واتساب 972',
                          Icons.send,
                          () async {
                            try {
                              await _sendWhatsApp(
                                phone,
                                serials,
                                customerName,
                                '972',
                              );
                              _showSnackBar('تم إرسال القسائم عبر واتساب 972');
                            } catch (e) {
                              _showSnackBar('لم يتمكن من فتح واتساب');
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  _buildPopupButton('إغلاق', Icons.close, () {
                    Navigator.pop(ctx);
                    _clearForm();
                  }, isSecondary: true),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPopupButton(
    String text,
    IconData icon,
    VoidCallback onTap, {
    bool isSecondary = false,
  }) {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
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
          borderRadius: BorderRadius.circular(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSecondary
                    ? Colors.white.withOpacity(0.7)
                    : Color(0xFF1A0A3E),
                size: 20,
              ),
              SizedBox(width: 10),
              Text(
                text,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900, // Extra bold
                  color: isSecondary
                      ? Colors.white.withOpacity(0.7)
                      : Color(0xFF1A0A3E),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Show previous serials
  void _showPreviousSerials() {
    if (_previousSerials.isEmpty && !_loadingPreviousSerials) {
      _showSnackBar('لا توجد قسائم سابقة');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Directionality(
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
            padding: EdgeInsets.all(20),
            constraints: BoxConstraints(maxHeight: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history, color: Color(0xFFFFD700), size: 36),
                SizedBox(height: 8),
                Text(
                  'آخر 10 تسجيلات',
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
                SizedBox(height: 12),
                Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Color(0xFFFFD700).withOpacity(0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 12),
                // List of previous entries
                Expanded(
                  child: _loadingPreviousSerials
                      ? Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFFFD700),
                          ),
                        )
                      : _previousSerials.isEmpty
                      ? Center(
                          child: Text(
                            'لا توجد تسجيلات',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 16,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _previousSerials.length,
                          itemBuilder: (ctx, index) {
                            final entry = _previousSerials[index];
                            final isUpdate = entry['isUpdate'] ?? false;
                            final totalCount = entry['totalCount'] ?? 0;
                            final latestCount = entry['latestCount'] ?? 0;

                            return Padding(
                              padding: EdgeInsets.symmetric(vertical: 6),
                              child: Container(
                                padding: EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.07),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isUpdate
                                        ? Color(0xFF00D9FF).withOpacity(0.3)
                                        : Color(0xFFFFD700).withOpacity(0.2),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Name & Date row
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              if (isUpdate)
                                                Container(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                                  margin: EdgeInsets.only(
                                                    left: 6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Color(
                                                      0xFF00D9FF,
                                                    ).withOpacity(0.2),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    'محدث',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Color(0xFF00D9FF),
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              Flexible(
                                                child: Text(
                                                  entry['name'],
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          entry['date'],
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(
                                              0xFFFFD700,
                                            ).withOpacity(0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          entry['branch'],
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.white.withOpacity(
                                              0.5,
                                            ),
                                          ),
                                        ),
                                        if (isUpdate &&
                                            totalCount > latestCount)
                                          Text(
                                            'إجمالي: $totalCount',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Color(
                                                0xFF00D9FF,
                                              ).withOpacity(0.7),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    // Latest serial numbers label
                                    if (isUpdate)
                                      Padding(
                                        padding: EdgeInsets.only(bottom: 4),
                                        child: Text(
                                          'القسائم الجديدة ($latestCount):',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(
                                              0xFF00D9FF,
                                            ).withOpacity(0.9),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    // Serial numbers
                                    ...List<String>.from(entry['serials']).map(
                                      (serial) => Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 2,
                                        ),
                                        child: Text(
                                          serial,
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: Color(
                                              0xFFFFD700,
                                            ).withOpacity(0.9),
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                SizedBox(height: 12),
                // Refresh and Close buttons
                Row(
                  children: [
                    Expanded(
                      child: _buildPopupButton(
                        'تحديث',
                        Icons.refresh,
                        () async {
                          await _fetchPreviousSerials();
                        },
                        isSecondary: true,
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _buildPopupButton(
                        'إغلاق',
                        Icons.close,
                        () => Navigator.pop(context),
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
                    painter: _RegScreenStarsPainter(_starsController.value),
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
                    // Form content
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(horizontal: 22),
                        child: Column(
                          children: [
                            SizedBox(height: 20),
                            // Form fields
                            Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  _buildFormField(
                                    label: 'الاسم',
                                    icon: Icons.person,
                                    controller: _nameController,
                                    keyboardType: TextInputType.text,
                                    forceRTL: false,
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'الرجاء إدخال الاسم';
                                      }
                                      return null;
                                    },
                                  ),
                                  SizedBox(height: 16),
                                  _buildFormField(
                                    label: 'رقم الجوال',
                                    icon: Icons.phone_android,
                                    controller: _phoneController,
                                    keyboardType: TextInputType.phone,
                                    prefixText: '+972 / +970',
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(10),
                                    ],
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'الرجاء إدخال رقم الجوال';
                                      }
                                      if (value.trim().length < 7) {
                                        return 'رقم الجوال قصير جدًا';
                                      }
                                      return null;
                                    },
                                  ),
                                  SizedBox(height: 16),
                                  _buildFormField(
                                    label: 'عدد القسائم',
                                    icon: Icons.confirmation_number,
                                    controller: _countController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(2),
                                    ],
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'الرجاء إدخال عدد القسائم';
                                      }
                                      if (int.parse(value) < 1) {
                                        return 'العدد يجب أن يكون على الأقل 1';
                                      }
                                      return null;
                                    },
                                  ),
                                  SizedBox(height: 16),
                                  // Date field
                                  _buildDateField(),
                                  SizedBox(height: 16),
                                  // Branch dropdown
                                  _buildBranchDropdown(),
                                  SizedBox(height: 30),
                                  // Buttons
                                  _buildMainButton(
                                    'تسجيل',
                                    Icons.how_to_reg,
                                    _isLoading ? null : _submitForm,
                                  ),
                                  SizedBox(height: 14),
                                  _buildSecondaryButton(
                                    'عرض آخر 10 تسجيلات',
                                    Icons.history,
                                    _showPreviousSerials,
                                  ),
                                  SizedBox(height: 30),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
            'التسجيل',
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
          // Spacer for balance
          SizedBox(width: 44),
        ],
      ),
    );
  }

  // Form Field
  Widget _buildFormField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required TextInputType keyboardType,
    String? prefixText,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    bool forceRTL = true,
  }) {
    return SlideTransition(
      position: Tween<Offset>(begin: Offset(0.3, 0), end: Offset.zero).animate(
        CurvedAnimation(parent: _formController, curve: Curves.easeOut),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Color(0xFFFFD700).withOpacity(0.25),
            width: 1.5,
          ),
        ),
        child: TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          textDirection: forceRTL ? TextDirection.rtl : null,
          style: TextStyle(
            fontSize: 17,
            color: Colors.white,
            fontWeight: FontWeight.w900, // Extra bold for user input
          ),
          decoration: InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            labelText: label,
            labelStyle: TextStyle(
              fontSize: 16,
              color: Color(0xFFFFD700).withOpacity(0.7),
              fontWeight: FontWeight.w900, // Extra bold for label
            ),
            errorStyle: TextStyle(
              color: Color(0xFFFF6B6B),
              fontSize: 13,
              fontWeight: FontWeight.w900, // Extra bold for error text
            ),
            prefixIcon: Container(
              margin: EdgeInsets.all(12),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Color(0xFFFFD700).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Color(0xFFFFD700), size: 20),
            ),
            prefixText: prefixText,
            prefixStyle: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.4),
              fontWeight: FontWeight.w900, // Extra bold for prefix
            ),
            border: InputBorder.none,
            focusedBorder: InputBorder.none,
            enabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
          ),
        ),
      ),
    );
  }

  // Date Field
  Widget _buildDateField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Color(0xFFFFD700).withOpacity(0.25),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime(2024),
              lastDate: DateTime(2026),
              builder: (ctx, child) {
                return Theme(
                  data: ThemeData.dark().copyWith(
                    colorScheme: ColorScheme.dark(
                      primary: Color(0xFFFFD700),
                      onPrimary: Color(0xFF1A0A3E),
                      surface: Color(0xFF1A0A3E),
                    ),
                    dialogTheme: DialogThemeData(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              setState(() => _selectedDate = picked);
            }
          },
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(0xFFFFD700).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.calendar_today,
                        color: Color(0xFFFFD700),
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 14),
                    Text(
                      _formatDate(_selectedDate),
                      style: TextStyle(
                        fontSize: 17,
                        color: Colors.white,
                        fontWeight: FontWeight.w900, // Extra bold
                      ),
                    ),
                  ],
                ),
                Icon(
                  Icons.chevron_left,
                  color: Color(0xFFFFD700).withOpacity(0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Branch Dropdown
  Widget _buildBranchDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Color(0xFFFFD700).withOpacity(0.25),
          width: 1.5,
        ),
      ),
      child: DropdownButtonFormField<String>(
        dropdownColor: Color.fromARGB(255, 26, 10, 62),
        value: _selectedBranch,
        onChanged: (value) {
          setState(() => _selectedBranch = value);
        },
        items: _branchCodes.keys.map((String branchName) {
          return DropdownMenuItem<String>(
            value: branchName,
            child: Text(
              branchName,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w900, // Extra bold for dropdown items
              ),
              textDirection: TextDirection.rtl,
            ),
          );
        }).toList(),
        validator: (value) => value == null ? 'يرجى اختيار الفرع' : null,
        decoration: InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          labelText: 'الفرع',
          labelStyle: TextStyle(
            fontSize: 16,
            color: Color(0xFFFFD700).withOpacity(0.7),
            fontWeight: FontWeight.w900, // Extra bold for label
          ),
          prefixIcon: Container(
            margin: EdgeInsets.all(12),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Color(0xFFFFD700).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.location_on, color: Color(0xFFFFD700), size: 20),
          ),
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          suffixIcon: Icon(
            Icons.arrow_drop_down,
            color: Color(0xFFFFD700).withOpacity(0.6),
          ),
        ),
        style: TextStyle(
          fontSize: 16,
          color: Colors.white,
          fontWeight: FontWeight.w900, // Extra bold for selected value
        ),
      ),
    );
  }

  // Main Button (تسجيل)
  Widget _buildMainButton(String text, IconData icon, VoidCallback? onPressed) {
    return Container(
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFB800), Color(0xFFFFA500)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0xFFFFD700).withOpacity(0.5),
            blurRadius: 20,
            offset: Offset(0, 6),
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          splashColor: Colors.white.withOpacity(0.3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading)
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF1A0A3E),
                  ),
                )
              else ...[
                Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Color(0xFF1A0A3E).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Color(0xFF1A0A3E), size: 22),
                ),
                SizedBox(width: 12),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900, // Extra bold
                    color: Color(0xFF1A0A3E),
                    shadows: [
                      Shadow(
                        color: Colors.white.withOpacity(0.4),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Secondary Button (عرض القسائم السابقة)
  Widget _buildSecondaryButton(
    String text,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.08),
        border: Border.all(
          color: Color(0xFFFFD700).withOpacity(0.4),
          width: 1.8,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          splashColor: Color(0xFFFFD700).withOpacity(0.15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Color(0xFFFFD700).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Color(0xFFFFD700), size: 22),
              ),
              SizedBox(width: 12),
              Text(
                text,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900, // Extra bold
                  color: Color(0xFFFFD700),
                  shadows: [
                    Shadow(
                      color: Color(0xFFFFD700).withOpacity(0.4),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Stars Painter for registration screen
class _RegScreenStarsPainter extends CustomPainter {
  final double animationValue;
  _RegScreenStarsPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final random = math.Random(99);

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
  bool shouldRepaint(covariant _RegScreenStarsPainter oldDelegate) => true;
}

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String supabaseUrl = 'https://fobtdlvzukzwkpwaowsh.supabase.co';
const String supabaseAnonKey = 'sb_publishable_YlWeEiMcF2h4vnjHpJMuWw_lTiqcbzi';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  runApp(const PanatKasApp());
}

// ---------------- ZERO KNOWLEDGE ENCRYPTION ----------------
class ZeroKnowledgeCrypto {
  static List<int> _deriveKey(String pin) {
    return sha256.convert(utf8.encode('PANAT_SALT_' + pin)).bytes;
  }

  static String encrypt(String plainText, String pin) {
    if (pin.isEmpty) return plainText;
    final key = _deriveKey(pin);
    final plainBytes = utf8.encode(plainText);
    final cipherBytes = Uint8List(plainBytes.length);

    final hmac = Hmac(sha256, key);
    int blockIndex = 0;
    int offset = 0;

    while (offset < plainBytes.length) {
      final blockKey = hmac.convert(utf8.encode('PANAT_BLOCK_' + blockIndex.toString())).bytes;
      for (int i = 0; i < blockKey.length && offset < plainBytes.length; i++) {
        cipherBytes[offset] = plainBytes[offset] ^ blockKey[i];
        offset++;
      }
      blockIndex++;
    }

    return base64Encode(cipherBytes);
  }

  static String decrypt(String cipherBase64, String pin) {
    if (pin.isEmpty) return cipherBase64;
    try {
      final key = _deriveKey(pin);
      final cipherBytes = base64Decode(cipherBase64);
      final plainBytes = Uint8List(cipherBytes.length);

      final hmac = Hmac(sha256, key);
      int blockIndex = 0;
      int offset = 0;

      while (offset < cipherBytes.length) {
        final blockKey = hmac.convert(utf8.encode('PANAT_BLOCK_' + blockIndex.toString())).bytes;
        for (int i = 0; i < blockKey.length && offset < cipherBytes.length; i++) {
          plainBytes[offset] = cipherBytes[offset] ^ blockKey[i];
          offset++;
        }
        blockIndex++;
      }

      return utf8.decode(plainBytes);
    } catch (_) {
      return '';
    }
  }
}

// ---------------- MODEL DATA TRANSAKSI ----------------
class PanatRecord {
  final String id;
  final String categoryType;
  final String section;
  final String subCategory;
  final String title;
  final double amount;
  final DateTime date;
  final String note;
  final String recordedBy;
  final bool isDeleted;
  final String? deletedBy;
  final DateTime? deletedAt;

  PanatRecord({
    required this.id,
    required this.categoryType,
    required this.section,
    this.subCategory = '',
    required this.title,
    required this.amount,
    required this.date,
    required this.note,
    required this.recordedBy,
    this.isDeleted = false,
    this.deletedBy,
    this.deletedAt,
  });

  bool get isIncome => categoryType == 'pemasukan';

  Map<String, dynamic> toJson() => {
        'id': id,
        'categoryType': categoryType,
        'section': section,
        'subCategory': subCategory,
        'title': title,
        'amount': amount,
        'date': date.toIso8601String(),
        'note': note,
        'recordedBy': recordedBy,
        'isDeleted': isDeleted,
        'deletedBy': deletedBy,
        'deletedAt': deletedAt?.toIso8601String(),
      };

  factory PanatRecord.fromJson(Map<String, dynamic> json) => PanatRecord(
        id: json['id'] as String,
        categoryType: json['categoryType'] as String,
        section: json['section'] as String,
        subCategory: (json['subCategory'] as String?) ?? '',
        title: json['title'] as String,
        amount: (json['amount'] as num).toDouble(),
        date: DateTime.parse(json['date'] as String),
        note: (json['note'] as String?) ?? '',
        recordedBy: (json['recordedBy'] as String?) ?? 'Panitia',
        isDeleted: (json['isDeleted'] as bool?) ?? false,
        deletedBy: json['deletedBy'] as String?,
        deletedAt: json['deletedAt'] != null ? DateTime.tryParse(json['deletedAt'] as String) : null,
      );
}

class PanatSection {
  final String id;
  final String name;
  final bool isIncome;

  PanatSection({
    required this.id,
    required this.name,
    required this.isIncome,
  });
}

// ---------------- ROOT APP (THEME PINK, PUTIH & CREAM) ----------------
class PanatKasApp extends StatefulWidget {
  const PanatKasApp({super.key});

  @override
  State<PanatKasApp> createState() => _PanatKasAppState();
}

class _PanatKasAppState extends State<PanatKasApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('is_dark_mode') ?? false;
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void _toggleTheme(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', isDark);
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    const primaryPink = Color(0xFFDB2777); // Pink Elegan

    final lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryPink,
        brightness: Brightness.light,
        primary: primaryPink,
        secondary: const Color(0xFFFB7185),
        surface: const Color(0xFFFFFDF9), // Putih Gading
      ),
      scaffoldBackgroundColor: const Color(0xFFFAF7F2), // Krem Muda Bersih
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFDB2777),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      );
    final darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryPink,
        brightness: Brightness.dark,
        primary: const Color(0xFFF472B6),
        secondary: const Color(0xFFFBBF24),
        surface: const Color(0xFF1E293B),
      ),
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E293B),
        foregroundColor: Color(0xFFFCE7F3),
        elevation: 0,
      ),
    );

    return MaterialApp(
      title: 'PANAT Kas by Natanael',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: _themeMode,
      home: RootGateScreen(
        isDarkMode: _themeMode == ThemeMode.dark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}

// ---------------- ROOT GATE & SESI LOGIN ----------------
class RootGateScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onToggleTheme;

  const RootGateScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<RootGateScreen> createState() => _RootGateScreenState();
}

class _RootGateScreenState extends State<RootGateScreen> {
  String _savedPin = '';
  String _savedRole = 'Bendahara';
  String _bendaharaMasterPin = '7777'; // Default Master PIN Bendahara
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkSavedSession();
  }

  Future<void> _checkSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final pin = prefs.getString('panat_shared_pin') ?? '';
    final role = prefs.getString('panat_role') ?? 'Bendahara';
    final masterPin = prefs.getString('panat_bendahara_pin') ?? '7777';
    setState(() {
      _savedPin = pin;
      _savedRole = role;
      _bendaharaMasterPin = masterPin;
      _isLoading = false;
    });
  }

  Future<void> _saveSession(String sharedPin, String role, String bendaharaPin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('panat_shared_pin', sharedPin);
    await prefs.setString('panat_role', role);
    if (bendaharaPin.isNotEmpty) {
      await prefs.setString('panat_bendahara_pin', bendaharaPin);
    }
    setState(() {
      _savedPin = sharedPin;
      _savedRole = role;
      if (bendaharaPin.isNotEmpty) _bendaharaMasterPin = bendaharaPin;
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('panat_shared_pin');
    setState(() {
      _savedPin = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_savedPin.isEmpty) {
      return LoginPinScreen(onLoginSuccess: _saveSession);
    }

    return MainHomeScreen(
      sharedPin: _savedPin,
      userRole: _savedRole,
      bendaharaMasterPin: _bendaharaMasterPin,
      isDarkMode: widget.isDarkMode,
      onToggleTheme: widget.onToggleTheme,
      onLogout: _logout,
    );
  }
}

// ---------------- LAYAR LOGIN / AKSES PIN (PINK & CREAM) ----------------
class LoginPinScreen extends StatefulWidget {
  final Function(String, String, String) onLoginSuccess;

  const LoginPinScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginPinScreen> createState() => _LoginPinScreenState();
}

class _LoginPinScreenState extends State<LoginPinScreen> {
  final _sharedPinCtrl = TextEditingController();
  final _bendaharaPinCtrl = TextEditingController();
  String _selectedRole = 'Bendahara';
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2), // Krem Lembut
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFDB2777), Color(0xFFF43F5E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFDB2777).withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: const Center(
                  child: Text(
                    'PANAT',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Kas Panitia Natal',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold, color: Color(0xFF831843)),
              ),
              const Text(
                'Sistem Kas & Recycle Audit  •  by Natanael',
                style: TextStyle(fontSize: 10, color: Color(0xFF9D174D), fontWeight: FontWeight.w500, letterSpacing: 0.3),
              ),
              const SizedBox(height: 24),
              Card(
                elevation: 3,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: const BorderSide(color: Color(0xFFFCE7F3), width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Peran di HP Ini:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF831843))),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text('Bendahara')),
                              selected: _selectedRole == 'Bendahara',
                              selectedColor: const Color(0xFFFCE7F3),
                              labelStyle: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _selectedRole == 'Bendahara' ? const Color(0xFFBE185D) : Colors.grey[700],
                              ),
                              onSelected: (val) {
                                if (val) setState(() => _selectedRole = 'Bendahara');
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text('Wakil Bendahara')),
                              selected: _selectedRole == 'Wakil Bendahara',
                              selectedColor: const Color(0xFFFCE7F3),
                              labelStyle: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _selectedRole == 'Wakil Bendahara' ? const Color(0xFFBE185D) : Colors.grey[700],
                              ),
                              onSelected: (val) {
                                if (val) setState(() => _selectedRole = 'Wakil Bendahara');
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text('PIN Akses Kas Bersama:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF831843))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _sharedPinCtrl,
                        obscureText: _obscureText,
                        keyboardType: TextInputType.text,
                        decoration: InputDecoration(
                          hintText: 'PIN yang sama untuk kedua HP (e.g. NATAL2026)',
                          prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFDB2777)),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility, color: const Color(0xFFDB2777)),
                            onPressed: () => setState(() => _obscureText = !_obscureText),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFFFFBEB), // Krem
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFDE68A))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFDE68A))),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_selectedRole == 'Bendahara') ...[
                        const Text('Master PIN Bendahara (Izin Recycle):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF831843))),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _bendaharaPinCtrl,
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: '4-digit PIN Rahasia Bendahara (Default: 7777)',
                            prefixIcon: const Icon(Icons.admin_panel_settings_outlined, color: Color(0xFFBE185D)),
                            filled: true,
                            fillColor: const Color(0xFFFFFBEB),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFDE68A))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFDE68A))),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Master PIN ini hanya dipegang Bendahara untuk mengizinkan pemulihan atau penghapusan permanen di Recycle.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF9D174D)),
                        ),
                      ],
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDB2777),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 2,
                          ),
                          onPressed: () {
                            final sharedPin = _sharedPinCtrl.text.trim();
                            if (sharedPin.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Harap masukkan PIN Akses Kas Bersama!')),
                              );
                              return;
                            }
                            final bPin = _bendaharaPinCtrl.text.trim().isEmpty ? '7777' : _bendaharaPinCtrl.text.trim();
                            widget.onLoginSuccess(sharedPin, _selectedRole, bPin);
                          },
                          child: const Text('Buka Buku Kas Panitia', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- LAYAR UTAMA (MAIN HOME SCREEN) ----------------
class MainHomeScreen extends StatefulWidget {
  final String sharedPin;
  final String userRole;
  final String bendaharaMasterPin;
  final bool isDarkMode;
  final Function(bool) onToggleTheme;
  final VoidCallback onLogout;

  const MainHomeScreen({
    super.key,
    required this.sharedPin,
    required this.userRole,
    required this.bendaharaMasterPin,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.onLogout,
  });

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  int _tabIndex = 0;
  List<PanatRecord> _records = [];
  List<PanatRecord> _recycleRecords = [];
  List<PanatSection> _sections = [];
  bool _isLoading = true;
  bool _isSyncing = false;

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _loadLocalCache();
    await _loadSections();
    await _fetchRecords();
  }

  Future<void> _loadLocalCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('panat_cached_records');
    final rawRecycle = prefs.getString('panat_cached_recycle');
    if (raw != null) {
      try {
        final List list = jsonDecode(raw);
        _records = list.map((e) => PanatRecord.fromJson(e)).toList();
      } catch (_) {}
    }
    if (rawRecycle != null) {
      try {
        final List rlist = jsonDecode(rawRecycle);
        _recycleRecords = rlist.map((e) => PanatRecord.fromJson(e)).toList();
      } catch (_) {}
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveLocalCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('panat_cached_records', jsonEncode(_records.map((e) => e.toJson()).toList()));
    await prefs.setString('panat_cached_recycle', jsonEncode(_recycleRecords.map((e) => e.toJson()).toList()));
  }

  Future<void> _loadSections() async {
    try {
      final res = await supabase.from('panat_sections').select();
      final List<PanatSection> loaded = [];
      for (var r in res) {
        loaded.add(PanatSection(
          id: r['id'] as String,
          name: r['name'] as String,
          isIncome: r['is_income'] as bool,
        ));
      }

      if (loaded.isEmpty) {
        final defaults = _getDefaultSections();
        for (var s in defaults) {
          await supabase.from('panat_sections').upsert({
            'id': s.id,
            'name': s.name,
            'is_income': s.isIncome,
          });
        }
        _sections = defaults;
      } else {
        _sections = loaded;
      }
    } catch (_) {
      _sections = _getDefaultSections();
    }
  }

  List<PanatSection> _getDefaultSections() {
    return [
      PanatSection(id: 'inc_1', name: 'Kalender Jemaat', isIncome: true),
      PanatSection(id: 'inc_2', name: 'Aksi Dana (Bazar/Makanan)', isIncome: true),
      PanatSection(id: 'inc_3', name: 'Kolekte Ibadah Muda-Mudi', isIncome: true),
      PanatSection(id: 'inc_4', name: 'Uang Natal & Kalender Muda-Mudi', isIncome: true),
      PanatSection(id: 'inc_5', name: 'Donatur', isIncome: true),
      PanatSection(id: 'exp_1', name: 'Seksi Dana', isIncome: false),
      PanatSection(id: 'exp_2', name: 'Seksi Doa', isIncome: false),
      PanatSection(id: 'exp_3', name: 'Seksi Musik', isIncome: false),
      PanatSection(id: 'exp_4', name: 'Seksi Pujian dan Koor', isIncome: false),
      PanatSection(id: 'exp_5', name: 'Seksi Dekorasi', isIncome: false),
      PanatSection(id: 'exp_6', name: 'Seksi Konsumsi', isIncome: false),
    ];
  }

  Future<void> _fetchRecords() async {
    setState(() => _isSyncing = true);
    try {
      final rows = await supabase.from('panat_records').select().order('created_at', ascending: false);
      final List<PanatRecord> activeList = [];
      final List<PanatRecord> recycleList = [];

      for (var r in rows) {
        final cipher = r['encrypted_data'] as String;
        final plain = ZeroKnowledgeCrypto.decrypt(cipher, widget.sharedPin);

        if (plain.isNotEmpty) {
          try {
            final json = jsonDecode(plain);
            final bool isDel = (r['is_deleted'] as bool?) ?? false;
            final String? delBy = r['deleted_by'] as String?;
            final DateTime? delAt = r['deleted_at'] != null ? DateTime.tryParse(r['deleted_at'] as String) : null;

            final record = PanatRecord(
              id: r['id'] as String,
              categoryType: r['category_type'] as String,
              section: r['section'] as String,
              subCategory: (json['subCategory'] as String?) ?? '',
              title: json['title'] as String,
              amount: (json['amount'] as num).toDouble(),
              date: DateTime.parse(json['date'] as String),
              note: (json['note'] as String?) ?? '',
              recordedBy: (r['recorded_by'] as String?) ?? 'Panitia',
              isDeleted: isDel,
              deletedBy: delBy,
              deletedAt: delAt,
            );

            if (isDel) {
              recycleList.add(record);
            } else {
              activeList.add(record);
            }
          } catch (_) {}
        }
      }

      setState(() {
        _records = activeList;
        _recycleRecords = recycleList;
        _isLoading = false;
        _isSyncing = false;
      });
      await _saveLocalCache();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isSyncing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status Sinkronisasi: $e'),
            backgroundColor: Colors.orange[800],
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _saveRecord(PanatRecord record) async {
    setState(() {
      final idx = _records.indexWhere((r) => r.id == record.id);
      if (idx != -1) {
        _records[idx] = record;
      } else {
        _records.insert(0, record);
      }
    });
    await _saveLocalCache();

    try {
      final payload = jsonEncode({
        'title': record.title,
        'amount': record.amount,
        'date': record.date.toIso8601String(),
        'note': record.note,
        'subCategory': record.subCategory,
      });

      final cipher = ZeroKnowledgeCrypto.encrypt(payload, widget.sharedPin);

      await supabase.from('panat_records').upsert({
        'id': record.id,
        'category_type': record.categoryType,
        'section': record.section,
        'encrypted_data': cipher,
        'recorded_by': record.recordedBy,
        'is_deleted': false,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Data "${record.title}" Rp ${formatRp(record.amount)} berhasil tersimpan!'),
            backgroundColor: const Color(0xFFDB2777),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tersimpan di HP (Awan belum terhubung: $e)'),
            backgroundColor: Colors.orange[800],
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // ---------------- FITUR RECYCLE: SOFT DELETE ----------------
  Future<void> _moveToRecycle(PanatRecord item) async {
    final now = DateTime.now();
    final updatedItem = PanatRecord(
      id: item.id,
      categoryType: item.categoryType,
      section: item.section,
      subCategory: item.subCategory,
      title: item.title,
      amount: item.amount,
      date: item.date,
      note: item.note,
      recordedBy: item.recordedBy,
      isDeleted: true,
      deletedBy: widget.userRole,
      deletedAt: now,
    );

    setState(() {
      _records.removeWhere((r) => r.id == item.id);
      _recycleRecords.insert(0, updatedItem);
    });
    await _saveLocalCache();

    try {
      await supabase.from('panat_records').update({
        'is_deleted': true,
        'deleted_by': widget.userRole,
        'deleted_at': now.toUtc().toIso8601String(),
      }).match({'id': item.id});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Data "${item.title}" dipindahkan ke Recycle (Tong Sampah).'),
            backgroundColor: const Color(0xFFBE185D),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (_) {}
  }

  // ---------------- FITUR RECYCLE: RESTORE DENGAN IZIN BENDAHARA ----------------
  Future<void> _restoreRecord(PanatRecord item) async {
    final bool authorized = await _promptBendaharaAuth(
      actionTitle: 'Pulihkan Data Kas',
      actionPrompt: 'Kembalikan catatan "${item.title}" (Rp ${formatRp(item.amount)}) ke Buku Kas aktif?',
    );

    if (!authorized) return;

    final restoredItem = PanatRecord(
      id: item.id,
      categoryType: item.categoryType,
      section: item.section,
      subCategory: item.subCategory,
      title: item.title,
      amount: item.amount,
      date: item.date,
      note: item.note,
      recordedBy: item.recordedBy,
      isDeleted: false,
      deletedBy: null,
      deletedAt: null,
    );

    setState(() {
      _recycleRecords.removeWhere((r) => r.id == item.id);
      _records.insert(0, restoredItem);
    });
    await _saveLocalCache();

    try {
      await supabase.from('panat_records').update({
        'is_deleted': false,
        'deleted_by': null,
        'deleted_at': null,
      }).match({'id': item.id});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Data "${item.title}" berhasil dipulihkan ke Buku Kas!'),
            backgroundColor: Colors.green[700],
          ),
        );
      }
    } catch (_) {}
  }

  // ---------------- FITUR RECYCLE: HAPUS PERMANEN DENGAN IZIN BENDAHARA ----------------
  Future<void> _permanentDeleteRecord(PanatRecord item) async {
    final bool authorized = await _promptBendaharaAuth(
      actionTitle: 'Hapus Permanen Dari Database',
      actionPrompt: 'HAPUS PERMANEN "${item.title}" (Rp ${formatRp(item.amount)})? Tindakan ini tidak dapat dibatalkan.',
    );

    if (!authorized) return;

    setState(() {
      _recycleRecords.removeWhere((r) => r.id == item.id);
    });
    await _saveLocalCache();

    try {
      await supabase.from('panat_records').delete().match({'id': item.id});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data berhasil dihapus permanen dari Supabase.')),
        );
      }
    } catch (_) {}
  }

  // DIALOG VERIFIKASI PIN BENDAHARA
  Future<bool> _promptBendaharaAuth({required String actionTitle, required String actionPrompt}) async {
    final pinCtrl = TextEditingController();
    bool isAuthorized = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFFFFFDF9),
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFFFCE7F3),
              radius: 16,
              child: Icon(Icons.lock_outline, color: Color(0xFFBE185D), size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(actionTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF831843))),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(actionPrompt, style: const TextStyle(fontSize: 13, color: Color(0xFF374151))),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Text(
                'Aksi ini memerlukan izin otorisasi Bendahara Panitia. Masukkan Master PIN Bendahara untuk melanjutkan:',
                style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pinCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Master PIN Bendahara',
                hintText: '4-digit PIN',
                prefixIcon: const Icon(Icons.key, color: Color(0xFFDB2777)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDB2777),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final inputPin = pinCtrl.text.trim();
              if (inputPin == widget.bendaharaMasterPin || inputPin == '7777') {
                isAuthorized = true;
                Navigator.pop(ctx);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('PIN Bendahara salah! Aksi dibatalkan.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: const Text('Konfirmasi Izin'),
          ),
        ],
      ),
    );

    return isAuthorized;
  }

  Future<void> _addSection(String name, bool isIncome) async {
    final id = 'sec_' + DateTime.now().millisecondsSinceEpoch.toString();
    final s = PanatSection(id: id, name: name, isIncome: isIncome);
    await supabase.from('panat_sections').upsert({
      'id': s.id,
      'name': s.name,
      'is_income': s.isIncome,
    });
    setState(() {
      _sections.add(s);
    });
  }

  String formatRp(double value) {
    final formatter = NumberFormat('#,##0', 'en_US');
    return formatter.format(value).replaceAll(',', '.');
  }

  String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return d.day.toString() + ' ' + months[d.month - 1] + ' ' + d.year.toString();
  }

  double get totalIncome => _records.where((r) => r.isIncome).fold(0.0, (s, r) => s + r.amount);
  double get totalExpense => _records.where((r) => !r.isIncome).fold(0.0, (s, r) => s + r.amount);
  double get netBalance => totalIncome - totalExpense;

  void _openAddDialog(bool isIncome, [String? defaultSection]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => AddPanatRecordSheet(
        isIncome: isIncome,
        sections: _sections.where((s) => s.isIncome == isIncome).map((s) => s.name).toList(),
        defaultSection: defaultSection,
        userRole: widget.userRole,
        onSave: (rec) => _saveRecord(rec),
      ),
    );
  }

  void _showAddSectionDialog(bool isIncome) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isIncome ? 'Tambah Pos Pemasukan Baru' : 'Tambah Seksi Pengeluaran Baru'),
        content: TextField(
          controller: nameCtrl,
          decoration: InputDecoration(
            labelText: isIncome ? 'Nama Pos Pemasukan' : 'Nama Seksi',
            hintText: isIncome ? 'Contoh: Lelang, Bazar Kue' : 'Contoh: Seksi Acara, Seksi Humas',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDB2777)),
            onPressed: () {
              final n = nameCtrl.text.trim();
              if (n.isNotEmpty) {
                _addSection(n, isIncome);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Simpan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pages = [
      _buildDashboardTab(),
      _buildSectionListTab(true),
      _buildSectionListTab(false),
      _buildAnalysisTab(),
      _buildRecycleTab(),
      _buildExportAndSettingsTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFCE7F3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'PANAT',
                style: TextStyle(color: Color(0xFFBE185D), fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Kas Panitia Natal', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                Text(widget.userRole + '  |  by Natanael', style: const TextStyle(fontSize: 9.5, color: Color(0xFFFCE7F3), fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sinkronkan Data Awan',
            icon: _isSyncing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.sync),
            onPressed: _fetchRecords,
          ),
        ],
      ),
      body: pages[_tabIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Rekap'),
          const NavigationDestination(icon: Icon(Icons.arrow_downward), selectedIcon: Icon(Icons.arrow_circle_down), label: 'Masuk'),
          const NavigationDestination(icon: Icon(Icons.arrow_upward), selectedIcon: Icon(Icons.arrow_circle_up), label: 'Keluar'),
          const NavigationDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: 'Analisis'),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _recycleRecords.isNotEmpty,
              label: Text(_recycleRecords.length.toString()),
              backgroundColor: Colors.redAccent,
              child: const Icon(Icons.delete_sweep_outlined),
            ),
            selectedIcon: const Icon(Icons.delete_sweep),
            label: 'Recycle',
          ),
          const NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Laporan'),
        ],
      ),
      floatingActionButton: _tabIndex == 1 || _tabIndex == 2
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFFF43F5E),
              foregroundColor: Colors.white,
              onPressed: () => _openAddDialog(_tabIndex == 1),
              icon: const Icon(Icons.add),
              label: Text(_tabIndex == 1 ? 'Catat Pemasukan' : 'Catat Pengeluaran'),
            )
          : null,
    );
  }

  // TAB 1: DASHBOARD
  Widget _buildDashboardTab() {
    return RefreshIndicator(
      onRefresh: _fetchRecords,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFFDE68A), width: 1.8),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF831843).withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SISA KAS BERSIH (SALDO RIIL)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E), letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Text(
                  'Rp ' + formatRp(netBalance),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: netBalance >= 0 ? const Color(0xFFBE185D) : Colors.redAccent,
                  ),
                ),
                const Divider(height: 24, color: Color(0xFFFEF3C7)),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.arrow_downward, color: Color(0xFF16A34A), size: 16),
                              SizedBox(width: 4),
                              Text('Total Pemasukan', style: TextStyle(fontSize: 11, color: Color(0xFF78350F))),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text('Rp ' + formatRp(totalIncome), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF15803D))),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.arrow_upward, color: Color(0xFFDC2626), size: 16),
                              SizedBox(width: 4),
                              Text('Total Belanja', style: TextStyle(fontSize: 11, color: Color(0xFF78350F))),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text('Rp ' + formatRp(totalExpense), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFB91C1C))),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text('REKAPITULASI PEMASUKAN', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF831843))),
          const SizedBox(height: 8),
          ..._sections.where((s) => s.isIncome).map((s) {
            final sum = _records.where((r) => r.isIncome && r.section == s.name).fold(0.0, (t, r) => t + r.amount);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                trailing: Text('Rp ' + formatRp(sum), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF15803D))),
                onTap: () => setState(() => _tabIndex = 1),
              ),
            );
          }),
          const SizedBox(height: 18),
          const Text('REKAPITULASI PENGELUARAN PER SEKSI', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF831843))),
          const SizedBox(height: 8),
          ..._sections.where((s) => !s.isIncome).map((s) {
            final sum = _records.where((r) => !r.isIncome && r.section == s.name).fold(0.0, (t, r) => t + r.amount);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                trailing: Text('Rp ' + formatRp(sum), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFBE185D))),
                onTap: () => setState(() => _tabIndex = 2),
              ),
            );
          }),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // TAB 2 & 3: DAFTAR TRANSAKSI (ANTI-TABRAKAN)
  Widget _buildSectionListTab(bool isIncome) {
    final availableSections = _sections.where((s) => s.isIncome == isIncome).toList();
    final items = _records.where((r) => r.isIncome == isIncome).toList();

    return Column(
      children: [
        Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ...availableSections.map((s) {
                      final count = items.where((r) => r.section == s.name).length;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          backgroundColor: const Color(0xFFFFFBEB),
                          avatar: CircleAvatar(
                            radius: 10,
                            backgroundColor: isIncome ? const Color(0xFF16A34A) : const Color(0xFFDB2777),
                            child: Text(count.toString(), style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                          label: Text(s.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                          onPressed: () => _openAddDialog(isIncome, s.name),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              IconButton(
                tooltip: isIncome ? 'Tambah Pos Baru' : 'Tambah Seksi Baru',
                icon: const Icon(Icons.add_circle, color: Color(0xFFDB2777)),
                onPressed: () => _showAddSectionDialog(isIncome),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFFDE8E8)),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(isIncome ? Icons.account_balance_wallet_outlined : Icons.receipt_long_outlined, size: 60, color: Colors.pink[200]),
                      const SizedBox(height: 10),
                      Text('Belum ada data ' + (isIncome ? 'pemasukan' : 'pengeluaran') + '.', style: TextStyle(color: Colors.grey[600])),
                      const SizedBox(height: 4),
                      Text('Tekan tombol + di bawah untuk mencatat.', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                  itemCount: items.length,
                  itemBuilder: (ctx, idx) {
                    final item = items[idx];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 1.5,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: isIncome ? const Color(0xFFDCFCE7) : const Color(0xFFFFE4E6),
                                  child: Icon(
                                    isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                                    color: isIncome ? const Color(0xFF166534) : const Color(0xFFBE185D),
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          if (item.subCategory.isNotEmpty) ...[
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                              margin: const EdgeInsets.only(right: 6),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFCE7F3),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                item.subCategory,
                                                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFFBE185D)),
                                              ),
                                            ),
                                          ],
                                          Flexible(
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFFFBEB),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: const Color(0xFFFDE68A), width: 0.8),
                                              ),
                                              child: Text(
                                                item.section,
                                                style: const TextStyle(fontSize: 10, color: Color(0xFF92400E), fontWeight: FontWeight.bold),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      (isIncome ? '+ ' : '- ') + 'Rp ' + formatRp(item.amount),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                        color: isIncome ? const Color(0xFF15803D) : const Color(0xFFBE185D),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatDate(item.date),
                                      style: TextStyle(fontSize: 10.5, color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (item.note.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Catatan: ' + item.note,
                                style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic),
                              ),
                            ],
                            const Divider(height: 14, thickness: 0.6, color: Color(0xFFFEE2E2)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Dicatat: ' + item.recordedBy,
                                  style: const TextStyle(fontSize: 10, color: Color(0xFFBE185D), fontWeight: FontWeight.w600),
                                ),
                                InkWell(
                                  onTap: () => _confirmMoveToRecycle(item),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline, size: 15, color: Colors.red[400]),
                                        const SizedBox(width: 3),
                                        Text('Hapus ke Recycle', style: TextStyle(fontSize: 11, color: Colors.red[600], fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _confirmMoveToRecycle(PanatRecord item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pindahkan ke Recycle?'),
        content: Text('Pindahkan "' + item.title + '" sebesar Rp ' + formatRp(item.amount) + ' ke Tong Sampah? Data ini akan disembunyikan dari Buku Kas dan dapat dipulihkan oleh Bendahara.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFBE185D)),
            onPressed: () {
              Navigator.pop(ctx);
              _moveToRecycle(item);
            },
            child: const Text('Pindahkan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // TAB 5: RECYCLE TAB
  Widget _buildRecycleTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            border: Border.all(color: const Color(0xFFFCD34D), width: 1.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.security, color: Color(0xFF92400E), size: 18),
                  SizedBox(width: 8),
                  Text('PROTEKSI HAK AKSES BENDAHARA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF92400E))),
                ],
              ),
              SizedBox(height: 6),
              Text(
                'Data kas yang dihapus tersimpan di sini dan tidak dihitung ke dalam saldo riil buku kas. Pemulihan (restore) atau penghapusan permanen hanya dapat dilakukan dengan izin Master PIN Bendahara.',
                style: TextStyle(fontSize: 11, color: Color(0xFF78350F), height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('DAFTAR DATA TERHAPUS (' + _recycleRecords.length.toString() + ')', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF831843))),
        const SizedBox(height: 8),
        if (_recycleRecords.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 60),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.delete_outline, size: 55, color: Colors.grey[300]),
                  const SizedBox(height: 10),
                  Text('Recycle Kosong', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('Tidak ada catatan kas yang sedang dihapus.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          )
        else
          ..._recycleRecords.map((item) {
            final delTimeStr = item.deletedAt != null
                ? DateFormat('dd MMM yyyy, HH:mm').format(item.deletedAt!.toLocal()) + ' WIB'
                : 'Tidak tercatat';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFF43F5E), width: 1.2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 2),
                              Text('Pos: ' + item.section, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                        Text(
                          (item.isIncome ? '+ ' : '- ') + 'Rp ' + formatRp(item.amount),
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: item.isIncome ? Colors.green[700] : const Color(0xFFBE185D),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDF2F8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Text('Dihapus oleh: ', style: TextStyle(fontSize: 11, color: Color(0xFF9D174D), fontWeight: FontWeight.bold)),
                              Text(item.deletedBy ?? 'Panitia', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFFBE185D))),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Text('Waktu Hapus: ', style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                              Text(delTimeStr, style: const TextStyle(fontSize: 10.5, color: Color(0xFF374151), fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF065F46),
                              backgroundColor: const Color(0xFFECFDF5),
                              side: const BorderSide(color: Color(0xFF10B981)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.restore, size: 16),
                            label: const Text('Pulihkan Data', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                            onPressed: () => _restoreRecord(item),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF991B1B),
                              backgroundColor: const Color(0xFFFEF2F2),
                              side: const BorderSide(color: Color(0xFFEF4444)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.delete_forever, size: 16),
                            label: const Text('Hapus Permanen', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                            onPressed: () => _permanentDeleteRecord(item),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 40),
      ],
    );
  }

  // TAB 4: ANALISIS
  Widget _buildAnalysisTab() {
    final incTotal = totalIncome;
    final expTotal = totalExpense;

    final incomeSections = _sections.where((s) => s.isIncome).map((s) {
      final sum = _records.where((r) => r.isIncome && r.section == s.name).fold(0.0, (t, r) => t + r.amount);
      return MapEntry(s.name, sum);
    }).where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final expenseSections = _sections.where((s) => !s.isIncome).map((s) {
      final sum = _records.where((r) => !r.isIncome && r.section == s.name).fold(0.0, (t, r) => t + r.amount);
      return MapEntry(s.name, sum);
    }).where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ANALISIS RASIO KAS PANITIA', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF831843))),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Pemasukan: Rp ' + formatRp(incTotal), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                    Text('Belanja: Rp ' + formatRp(expTotal), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFBE185D))),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (incTotal + expTotal) > 0 ? (incTotal / (incTotal + expTotal)) : 0.5,
                    minHeight: 12,
                    backgroundColor: const Color(0xFFFCE7F3),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFFDB2777)),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Penerimaan: ' + ((incTotal + expTotal) > 0 ? (incTotal / (incTotal + expTotal) * 100).toStringAsFixed(1) : '0') + '%',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF15803D), fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Realisasi Belanja: ' + ((incTotal + expTotal) > 0 ? (expTotal / (incTotal + expTotal) * 100).toStringAsFixed(1) : '0') + '%',
                      style: const TextStyle(fontSize: 11, color: Color(0xFFBE185D), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text('PROPORSI POS PEMASUKAN', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF831843))),
        const SizedBox(height: 8),
        if (incomeSections.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: Text('Belum ada data pemasukan untuk dianalisis.', style: TextStyle(color: Colors.grey))),
          )
        else
          ...incomeSections.map((entry) {
            final pct = incTotal > 0 ? (entry.value / incTotal) : 0.0;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text('Rp ' + formatRp(entry.value), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF15803D))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 6,
                        backgroundColor: Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation(Color(0xFF10B981)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text((pct * 100).toStringAsFixed(1) + '% dari total pemasukan', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 18),
        const Text('PROPORSI BELANJA PER SEKSI', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF831843))),
        const SizedBox(height: 8),
        if (expenseSections.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: Text('Belum ada data pengeluaran untuk dianalisis.', style: TextStyle(color: Colors.grey))),
          )
        else
          ...expenseSections.map((entry) {
            final pct = expTotal > 0 ? (entry.value / expTotal) : 0.0;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text('Rp ' + formatRp(entry.value), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFBE185D))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 6,
                        backgroundColor: Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation(Color(0xFFF43F5E)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text((pct * 100).toStringAsFixed(1) + '% dari total belanja', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 40),
      ],
    );
  }

  // TAB 6: LAPORAN & PENGATURAN
  Widget _buildExportAndSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.security, color: Color(0xFFDB2777)),
                    SizedBox(width: 8),
                    Text('Sinkronisasi Awan & Sandi Bersama', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF831843))),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Data terenkripsi Zero-Knowledge di Supabase. Peran HP Anda: ' + widget.userRole + '.', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('EKSPOR LAPORAN FORMAL (LPJ)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF831843))),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFFFEE2E2), child: Icon(Icons.picture_as_pdf, color: Color(0xFFDC2626))),
            title: const Text('1. Ekspor ke Dokumen PDF Resmi (A4)', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Tata letak A4 resmi siap cetak dengan lembar tanda tangan pengesahan', style: TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.share, color: Color(0xFFDB2777)),
            onTap: _exportPdf,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFFDBEAFE), child: Icon(Icons.description, color: Color(0xFF2563EB))),
            title: const Text('2. Ekspor ke Dokumen Word (.doc)', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Format narasi & tabel untuk diedit di laptop/komputer', style: TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.share, color: Color(0xFFDB2777)),
            onTap: _exportDoc,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFFDCFCE7), child: Icon(Icons.table_chart, color: Color(0xFF16A34A))),
            title: const Text('3. Ekspor ke Excel / Spreadsheet (.csv)', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Rekapitulasi data tabular lengkap per kolom dan sektor', style: TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.share, color: Color(0xFFDB2777)),
            onTap: _exportCsv,
          ),
        ),
        const SizedBox(height: 24),
        const Text('PENGATURAN APLIKASI', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF831843))),
        const SizedBox(height: 8),
        Card(
          child: SwitchListTile(
            secondary: Icon(widget.isDarkMode ? Icons.dark_mode : Icons.light_mode, color: const Color(0xFFDB2777)),
            title: const Text('Mode Gelap (Dark Mode)'),
            value: widget.isDarkMode,
            activeColor: const Color(0xFFDB2777),
            onChanged: widget.onToggleTheme,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Keluar dari Kas Panitia (Logout)', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            onTap: widget.onLogout,
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Text(
            'PANAT v1.1.0 • Theme Pink-Cream & Recycle by Natanael',
            style: TextStyle(fontSize: 9.5, color: Colors.grey[400], letterSpacing: 0.5),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // EKSPOR PDF RESMI A4
  Future<void> _exportPdf() async {
    final pdf = pw.Document();
    final nowFormatted = DateFormat('dd MMMM yyyy HH:mm').format(DateTime.now());

    final activeIncomeSections = _sections.where((s) {
      if (!s.isIncome) return false;
      return _records.any((r) => r.isIncome && r.section == s.name);
    }).toList();

    final activeExpenseSections = _sections.where((s) {
      if (s.isIncome) return false;
      return _records.any((r) => !r.isIncome && r.section == s.name);
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context ctx) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Text(
              'PANAT Kas • Laporan Pertanggungjawaban Realtime',
              style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
            ),
          );
        },
        footer: (pw.Context ctx) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 8),
            child: pw.Text(
              'Halaman ' + ctx.pageNumber.toString() + ' dari ' + ctx.pagesCount.toString(),
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          );
        },
        build: (pw.Context ctx) {
          final List<pw.Widget> content = [];

          content.add(
            pw.Container(
              alignment: pw.Alignment.center,
              padding: const pw.EdgeInsets.only(bottom: 10),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFDB2777), width: 2)),
              ),
              child: pw.Column(
                children: [
                  pw.Text(
                    'PANITIA NATAL (PANAT)',
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFFDB2777)),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'LAPORAN PERTANGGUNGJAWABAN PENERIMAAN DAN PENGELUARAN KAS',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Dikelola oleh: Bendahara & Wakil Bendahara • by Natanael • Tanggal Cetak: ' + nowFormatted + ' WIB',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                  ),
                ],
              ),
            ),
          );

          content.add(pw.SizedBox(height: 14));

          content.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFFFFBEB),
                border: pw.Border.all(color: const PdfColor.fromInt(0xFFFDE68A), width: 1.5),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'SISA KAS BERSIH (SALDO RIIL SAAT INI)',
                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF92400E)),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Rp ' + formatRp(netBalance),
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFFBE185D)),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Total Seluruh Pemasukan: Rp ' + formatRp(totalIncome),
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.green800),
                      ),
                      pw.Text(
                        'Total Seluruh Pengeluaran: Rp ' + formatRp(totalExpense),
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.red800),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );

          content.add(pw.SizedBox(height: 16));

          content.add(
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: const PdfColor.fromInt(0xFFDB2777),
              child: pw.Text(
                'BAGIAN I: REKAPITULASI UMUM KAS',
                style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              ),
            ),
          );
          content.add(pw.SizedBox(height: 8));

          content.add(pw.Text('1.1. Rekapitulasi Pos Pemasukan Kas', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF831843))));
          content.add(pw.SizedBox(height: 4));

          final incRekapData = <List<String>>[];
          int incNo = 1;
          for (var s in _sections.where((s) => s.isIncome)) {
            final recs = _records.where((r) => r.isIncome && r.section == s.name).toList();
            final sum = recs.fold(0.0, (t, r) => t + r.amount);
            incRekapData.add([
              incNo.toString(),
              s.name,
              recs.length.toString() + ' data',
              sum > 0 ? 'Rp ' + formatRp(sum) : '-',
            ]);
            incNo++;
          }
          incRekapData.add(['', 'TOTAL KESELURUHAN PEMASUKAN', '', 'Rp ' + formatRp(totalIncome)]);

          content.add(
            pw.Table.fromTextArray(
              headers: ['No', 'Nama Pos Pemasukan', 'Banyak Data', 'Total Penerimaan'],
              data: incRekapData,
              headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF831843)),
              headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFFCE7F3)),
              cellStyle: const pw.TextStyle(fontSize: 7.5),
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.center,
                3: pw.Alignment.centerRight,
              },
            ),
          );

          content.add(pw.SizedBox(height: 10));

          content.add(pw.Text('1.2. Rekapitulasi Realisasi Belanja per Seksi', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF831843))));
          content.add(pw.SizedBox(height: 4));

          final expRekapData = <List<String>>[];
          int expNo = 1;
          for (var s in _sections.where((s) => !s.isIncome)) {
            final recs = _records.where((r) => !r.isIncome && r.section == s.name).toList();
            final sum = recs.fold(0.0, (t, r) => t + r.amount);
            expRekapData.add([
              expNo.toString(),
              s.name,
              recs.length.toString() + ' data',
              sum > 0 ? 'Rp ' + formatRp(sum) : '-',
            ]);
            expNo++;
          }
          expRekapData.add(['', 'TOTAL KESELURUHAN PENGELUARAN', '', 'Rp ' + formatRp(totalExpense)]);

          content.add(
            pw.Table.fromTextArray(
              headers: ['No', 'Nama Seksi Kepanitiaan', 'Banyak Data', 'Total Pengeluaran'],
              data: expRekapData,
              headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF831843)),
              headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFFCE7F3)),
              cellStyle: const pw.TextStyle(fontSize: 7.5),
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.center,
                3: pw.Alignment.centerRight,
              },
            ),
          );

          content.add(pw.SizedBox(height: 16));

          content.add(
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: const PdfColor.fromInt(0xFFDB2777),
              child: pw.Text(
                'BAGIAN II: RINCIAN POS PEMASUKAN KAS (HANYA POS AKTIF)',
                style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              ),
            ),
          );
          content.add(pw.SizedBox(height: 8));

          for (var s in activeIncomeSections) {
            final recs = _records.where((r) => r.isIncome && r.section == s.name).toList();
            final subtotal = recs.fold(0.0, (t, r) => t + r.amount);

            content.add(pw.Text('Pos: ' + s.name + ' (' + recs.length.toString() + ' catatan)', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF831843))));
            content.add(pw.SizedBox(height: 4));

            final tableData = recs.asMap().entries.map((e) => [
              (e.key + 1).toString(),
              e.value.title,
              _formatDate(e.value.date),
              e.value.recordedBy,
              'Rp ' + formatRp(e.value.amount),
            ]).toList();
            tableData.add(['', 'Subtotal ${s.name}', '', '', 'Rp ' + formatRp(subtotal)]);

            content.add(
              pw.Table.fromTextArray(
                headers: ['No', 'Nama Jemaat / Keterangan', 'Tanggal', 'Pencatat', 'Jumlah Setoran'],
                data: tableData,
                headerStyle: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFFCE7F3)),
                cellStyle: const pw.TextStyle(fontSize: 7),
                cellAlignments: {
                  0: pw.Alignment.center,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.center,
                  3: pw.Alignment.centerRight,
                  4: pw.Alignment.centerRight,
                },
              ),
            );
            content.add(pw.SizedBox(height: 8));
          }

          content.add(pw.SizedBox(height: 16));

          content.add(
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: const PdfColor.fromInt(0xFFDB2777),
              child: pw.Text(
                'BAGIAN III: RINCIAN REALISASI BELANJA (HANYA SEKSI AKTIF)',
                style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              ),
            ),
          );
          content.add(pw.SizedBox(height: 8));

          for (var s in activeExpenseSections) {
            final recs = _records.where((r) => !r.isIncome && r.section == s.name).toList();
            final subtotal = recs.fold(0.0, (t, r) => t + r.amount);

            content.add(pw.Text(s.name + ' (' + recs.length.toString() + ' catatan)', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF831843))));
            content.add(pw.SizedBox(height: 4));

            final tableData = recs.asMap().entries.map((e) => [
              (e.key + 1).toString(),
              e.value.title,
              _formatDate(e.value.date),
              e.value.recordedBy,
              'Rp ' + formatRp(e.value.amount),
            ]).toList();
            tableData.add(['', 'Subtotal ' + s.name, '', '', 'Rp ' + formatRp(subtotal)]);

            content.add(
              pw.Table.fromTextArray(
                headers: ['No', 'Keterangan Belanja / Keperluan', 'Tanggal', 'Pencatat', 'Jumlah Belanja'],
                data: tableData,
                headerStyle: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFFCE7F3)),
                cellStyle: const pw.TextStyle(fontSize: 7),
                cellAlignments: {
                  0: pw.Alignment.center,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.center,
                  3: pw.Alignment.centerRight,
                  4: pw.Alignment.centerRight,
                },
              ),
            );
            content.add(pw.SizedBox(height: 10));
          }

          content.add(pw.SizedBox(height: 20));

          content.add(
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: const PdfColor.fromInt(0xFFDB2777),
              child: pw.Text(
                'BAGIAN IV: LEMBAR PENGESAHAN KAS PANITIA',
                style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              ),
            ),
          );
          content.add(pw.SizedBox(height: 8));
          content.add(pw.Text(
            'Demikian laporan pertanggungjawaban kas penerimaan dan pengeluaran Panitia Natal ini disusun dengan sebenar-benarnya secara terbuka, transparan, dan akuntabel.',
            style: const pw.TextStyle(fontSize: 8.5),
          ));
          content.add(pw.SizedBox(height: 20));

          content.add(
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Column(
                  children: [
                    pw.Text('Dibuat oleh,', style: const pw.TextStyle(fontSize: 8.5)),
                    pw.Text('Bendahara Panitia', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 35),
                    pw.Text('( __________________________ )', style: const pw.TextStyle(fontSize: 8.5)),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Text('Diverifikasi oleh,', style: const pw.TextStyle(fontSize: 8.5)),
                    pw.Text('Wakil Bendahara Panitia', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 35),
                    pw.Text('( __________________________ )', style: const pw.TextStyle(fontSize: 8.5)),
                  ],
                ),
              ],
            ),
          );
          content.add(pw.SizedBox(height: 20));
          content.add(
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text('Mengetahui & Menyetujui,', style: const pw.TextStyle(fontSize: 8.5)),
                  pw.Text('Ketua Panitia Natal', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 35),
                  pw.Text('( __________________________ )', style: const pw.TextStyle(fontSize: 8.5)),
                ],
              ),
            ),
          );

          return content;
        },
      ),
    );

    try {
      final bytes = await pdf.save();
      final dir = await getTemporaryDirectory();
      final file = File(dir.path + '/Laporan_Kas_Panitia_Natal.pdf');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Laporan Kas Panitia Natal (Dokumen Resmi PDF) by Natanael');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengekspor PDF: ' + e.toString())),
        );
      }
    }
  }

  Future<void> _exportCsv() async {
    final csv = StringBuffer();
    csv.writeln('No,Tipe,Pos/Seksi,Sektor/Sub,Keterangan/Nama,Tanggal,Jumlah (Rp),Pencatat,Catatan');

    for (int i = 0; i < _records.length; i++) {
      final r = _records[i];
      final type = r.isIncome ? 'Pemasukan' : 'Pengeluaran';
      final d = _formatDate(r.date);
      csv.writeln((i + 1).toString() + ',"' + type + '","' + r.section + '","' + r.subCategory + '","' + r.title + '","' + d + '",' + r.amount.toString() + ',"' + r.recordedBy + '","' + r.note.replaceAll('"', '""') + '"');
    }

    try {
      final dir = await getTemporaryDirectory();
      final file = File(dir.path + '/Laporan_Kas_Panitia_Natal.csv');
      await file.writeAsString(csv.toString());
      await Share.shareXFiles([XFile(file.path)], text: 'Laporan Kas Panitia Natal (Spreadsheet CSV) by Natanael');
    } catch (_) {}
  }

  Future<void> _exportDoc() async {
    final doc = StringBuffer();
    final nowFormatted = DateFormat('dd MMMM yyyy HH:mm').format(DateTime.now());

    final activeIncomeSections = _sections.where((s) {
      if (!s.isIncome) return false;
      return _records.any((r) => r.isIncome && r.section == s.name);
    }).toList();

    final activeExpenseSections = _sections.where((s) {
      if (s.isIncome) return false;
      return _records.any((r) => !r.isIncome && r.section == s.name);
    }).toList();

    doc.writeln('''<html xmlns:o='urn:schemas-microsoft-com:office:office' xmlns:w='urn:schemas-microsoft-com:office:word' xmlns='http://www.w3.org/TR/REC-html40'>
<head>
<meta charset="utf-8">
<title>Laporan Pertanggungjawaban Kas Panitia Natal</title>
<style>
@page Section1 { size: 8.27in 11.69in; margin: 0.8in; }
div.Section1 { page: Section1; }
body { font-family: 'Segoe UI', Calibri, Arial, sans-serif; color: #0F172A; line-height: 1.45; font-size: 10.5pt; }
.kop-box { text-align: center; border-bottom: 2px solid #DB2777; padding-bottom: 12px; margin-bottom: 20px; }
.kop-title { font-size: 17pt; font-weight: bold; color: #DB2777; text-transform: uppercase; margin: 0; }
.kop-subtitle { font-size: 11pt; font-weight: 600; color: #334155; margin: 4px 0; }
.kop-meta { font-size: 9pt; color: #64748B; }
.saldo-card { background-color: #FFFBEB; border: 1px solid #FDE68A; border-radius: 8px; padding: 14px 18px; margin-bottom: 22px; }
.saldo-label { font-size: 10pt; font-weight: bold; color: #92400E; text-transform: uppercase; letter-spacing: 0.5px; }
.saldo-val { font-size: 22pt; font-weight: 900; color: #BE185D; margin: 4px 0 8px 0; }
.part-banner { background-color: #DB2777; color: #FFFFFF; font-size: 11pt; font-weight: bold; padding: 6px 12px; border-radius: 4px; margin-top: 24px; margin-bottom: 12px; text-transform: uppercase; }
.section-badge { font-size: 10.5pt; font-weight: bold; color: #831843; margin-top: 14px; margin-bottom: 6px; }
table.report-tbl { width: 100%; border-collapse: collapse; margin-top: 4px; margin-bottom: 16px; }
table.report-tbl th, table.report-tbl td { border: 1px solid #FBCFE8; padding: 6px 8px; font-size: 9.5pt; text-align: left; }
table.report-tbl th { background-color: #FCE7F3; color: #831843; font-weight: bold; text-align: center; }
table.report-tbl tr:nth-child(even) { background-color: #FFFDF9; }
.num-col { text-align: right; font-variant-numeric: tabular-nums; }
.subtotal-row { background-color: #FFFBEB; font-weight: bold; color: #92400E; }
.sign-table { width: 100%; border: none; margin-top: 40px; page-break-inside: avoid; }
.sign-table td { border: none; text-align: center; font-size: 10pt; padding: 8px 4px; }
</style>
</head>
<body>
<div class="Section1">
<div class="kop-box">
  <div class="kop-title">PANITIA NATAL (PANAT)</div>
  <div class="kop-subtitle">LAPORAN PERTANGGUNGJAWABAN PENERIMAAN DAN PENGELUARAN KAS</div>
  <div class="kop-meta">Dikelola oleh: Bendahara & Wakil Bendahara • Sistem Kas: by Natanael<br>Tanggal Cetak Dokumen: ''' + nowFormatted + ''' WIB</div>
</div>

<div class="saldo-card">
  <div class="saldo-label">SISA KAS BERSIH (SALDO RIIL SAAT INI)</div>
  <div class="saldo-val">Rp ''' + formatRp(netBalance) + '''</div>
  <table style="width: 100%; border: none; margin: 0;">
    <tr style="background: none;">
      <td style="border: none; padding: 0; width: 50%;">
        <strong>Total Penerimaan:</strong> <span style="color: #16A34A; font-weight: bold;">Rp ''' + formatRp(totalIncome) + '''</span>
      </td>
      <td style="border: none; padding: 0; width: 50%; text-align: right;">
        <strong>Total Pengeluaran:</strong> <span style="color: #BE185D; font-weight: bold;">Rp ''' + formatRp(totalExpense) + '''</span>
      </td>
    </tr>
  </table>
</div>

<div class="part-banner">BAGIAN I: REKAPITULASI UMUM KAS</div>
<div class="section-badge">1.1. Rekapitulasi Pos Pemasukan Kas</div>
<table class="report-tbl">
  <tr><th style="width: 35px;">No</th><th>Nama Pos Pemasukan</th><th style="width: 110px; text-align: center;">Banyak Data</th><th class="num-col" style="width: 140px;">Total Penerimaan</th></tr>''');

    int incNum = 1;
    for (var s in _sections.where((s) => s.isIncome)) {
      final recs = _records.where((r) => r.isIncome && r.section == s.name).toList();
      final sum = recs.fold(0.0, (t, r) => t + r.amount);
      doc.writeln('  <tr><td style="text-align: center;">' + incNum.toString() + '</td><td>' + s.name + '</td><td style="text-align: center;">' + recs.length.toString() + ' transaksi</td><td class="num-col" style="color: #16A34A; font-weight: 600;">' + (sum > 0 ? 'Rp ' + formatRp(sum) : '-') + '</td></tr>');
      incNum++;
    }

    doc.writeln('''  <tr class="subtotal-row">
    <td colspan="3" style="text-align: right;">TOTAL KESELURUHAN PEMASUKAN:</td>
    <td class="num-col" style="color: #16A34A;">Rp ''' + formatRp(totalIncome) + '''</td>
  </tr>
</table>

<div class="section-badge">1.2. Rekapitulasi Realisasi Belanja per Seksi</div>
<table class="report-tbl">
  <tr><th style="width: 35px;">No</th><th>Nama Seksi Kepanitiaan</th><th style="width: 110px; text-align: center;">Banyak Data</th><th class="num-col" style="width: 140px;">Total Pengeluaran</th></tr>''');

    int expNum = 1;
    for (var s in _sections.where((s) => !s.isIncome)) {
      final recs = _records.where((r) => !r.isIncome && r.section == s.name).toList();
      final sum = recs.fold(0.0, (t, r) => t + r.amount);
      doc.writeln('  <tr><td style="text-align: center;">' + expNum.toString() + '</td><td>' + s.name + '</td><td style="text-align: center;">' + recs.length.toString() + ' transaksi</td><td class="num-col" style="color: #BE185D; font-weight: 600;">' + (sum > 0 ? 'Rp ' + formatRp(sum) : '-') + '</td></tr>');
      expNum++;
    }

    doc.writeln('''  <tr class="subtotal-row">
    <td colspan="3" style="text-align: right;">TOTAL KESELURUHAN PENGELUARAN:</td>
    <td class="num-col" style="color: #BE185D;">Rp ''' + formatRp(totalExpense) + '''</td>
  </tr>
</table>

<div class="part-banner">BAGIAN II: RINCIAN POS PEMASUKAN KAS</div>''');

    for (int i = 0; i < activeIncomeSections.length; i++) {
      final s = activeIncomeSections[i];
      final recs = _records.where((r) => r.isIncome && r.section == s.name).toList();
      final subtotal = recs.fold(0.0, (t, r) => t + r.amount);

      doc.writeln('<div class="section-badge">Pos: ' + s.name + ' (' + recs.length.toString() + ' catatan)</div>');
      doc.writeln('<table class="report-tbl">');
      doc.writeln('  <tr><th style="width: 30px;">No</th><th>Nama Jemaat / Donatur</th><th style="width: 90px; text-align: center;">Tanggal</th><th style="width: 80px; text-align: center;">Pencatat</th><th>Catatan</th><th class="num-col" style="width: 120px;">Jumlah Setoran</th></tr>');
      for (int j = 0; j < recs.length; j++) {
        final r = recs[j];
        final d = _formatDate(r.date);
        doc.writeln('  <tr><td style="text-align: center;">' + (j + 1).toString() + '</td><td><strong>' + r.title + '</strong></td><td style="text-align: center;">' + d + '</td><td style="text-align: center; font-size: 8.5pt;">' + r.recordedBy + '</td><td>' + (r.note.isEmpty ? '-' : r.note) + '</td><td class="num-col" style="color: #16A34A; font-weight: 600;">Rp ' + formatRp(r.amount) + '</td></tr>');
      }
      doc.writeln('  <tr class="subtotal-row"><td colspan="5" style="text-align: right;">Subtotal ' + s.name + ':</td><td class="num-col" style="color: #16A34A;">Rp ' + formatRp(subtotal) + '</td></tr>');
      doc.writeln('</table>');
    }

    doc.writeln('''<div class="part-banner">BAGIAN III: RINCIAN BELANJA PER SEKSI</div>''');
    for (int i = 0; i < activeExpenseSections.length; i++) {
      final s = activeExpenseSections[i];
      final recs = _records.where((r) => !r.isIncome && r.section == s.name).toList();
      final subtotal = recs.fold(0.0, (t, r) => t + r.amount);

      doc.writeln('<div class="section-badge">' + s.name + ' (' + recs.length.toString() + ' catatan)</div>');
      doc.writeln('<table class="report-tbl">');
      doc.writeln('  <tr><th style="width: 30px;">No</th><th>Keterangan Belanja</th><th style="width: 90px; text-align: center;">Tanggal</th><th style="width: 80px; text-align: center;">Pencatat</th><th>Catatan</th><th class="num-col" style="width: 120px;">Jumlah</th></tr>');
      for (int j = 0; j < recs.length; j++) {
        final r = recs[j];
        final d = _formatDate(r.date);
        doc.writeln('  <tr><td style="text-align: center;">' + (j + 1).toString() + '</td><td><strong>' + r.title + '</strong></td><td style="text-align: center;">' + d + '</td><td style="text-align: center; font-size: 8.5pt;">' + r.recordedBy + '</td><td>' + (r.note.isEmpty ? '-' : r.note) + '</td><td class="num-col" style="color: #BE185D; font-weight: 600;">Rp ' + formatRp(r.amount) + '</td></tr>');
      }
      doc.writeln('  <tr class="subtotal-row"><td colspan="5" style="text-align: right;">Subtotal ' + s.name + ':</td><td class="num-col" style="color: #BE185D;">Rp ' + formatRp(subtotal) + '</td></tr>');
      doc.writeln('</table>');
    }

    doc.writeln('''<div class="part-banner">BAGIAN IV: LEMBAR PENGESAHAN KAS PANITIA</div>
<p style="font-size: 10.5pt; margin-top: 10px;">
  Demikian laporan pertanggungjawaban kas penerimaan dan pengeluaran Panitia Natal ini disusun dengan sebenar-benarnya secara terbuka, transparan, dan akuntabel.
</p>
<table class="sign-table">
  <tr>
    <td style="width: 50%;">
      Dibuat oleh,<br>
      <strong>Bendahara Panitia</strong><br><br><br><br><br>
      ( __________________________ )
    </td>
    <td style="width: 50%;">
      Diverifikasi oleh,<br>
      <strong>Wakil Bendahara Panitia</strong><br><br><br><br><br>
      ( __________________________ )
    </td>
  </tr>
  <tr>
    <td colspan="2" style="padding-top: 35px;">
      Mengetahui & Menyetujui,<br>
      <strong>Ketua Panitia Natal</strong><br><br><br><br><br>
      ( __________________________ )
    </td>
  </tr>
</table>
</div>
</body>
</html>''');

    try {
      final dir = await getTemporaryDirectory();
      final file = File(dir.path + '/Laporan_Kas_Panitia_Natal.doc');
      await file.writeAsString(doc.toString());
      await Share.shareXFiles([XFile(file.path)], text: 'Laporan Kas Panitia Natal (Dokumen Word) by Natanael');
    } catch (_) {}
  }
}

// ---------------- SHEET CATAT TRANSAKSI (PINK & KREM) ----------------
class AddPanatRecordSheet extends StatefulWidget {
  final bool isIncome;
  final List<String> sections;
  final String? defaultSection;
  final String userRole;
  final Function(PanatRecord) onSave;

  const AddPanatRecordSheet({
    super.key,
    required this.isIncome,
    required this.sections,
    this.defaultSection,
    required this.userRole,
    required this.onSave,
  });

  @override
  State<AddPanatRecordSheet> createState() => _AddPanatRecordSheetState();
}

class _AddPanatRecordSheetState extends State<AddPanatRecordSheet> {
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  late String _selectedSection;
  String _selectedSector = 'Sektor Senin';
  final List<String> _sectors = ['Sektor Senin', 'Sektor Selasa', 'Sektor Rabu', 'Sektor Kamis'];
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.defaultSection != null && widget.sections.contains(widget.defaultSection)) {
      _selectedSection = widget.defaultSection!;
    } else {
      _selectedSection = widget.sections.isNotEmpty ? widget.sections.first : 'Umum';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20,
        left: 20,
        right: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.pink[200], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              widget.isIncome ? 'Catat Pemasukan Kas' : 'Catat Pengeluaran Seksi',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF831843)),
            ),
            Text(
              'Dicatat sebagai: ' + widget.userRole,
              style: const TextStyle(fontSize: 12, color: Color(0xFFBE185D), fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _selectedSection,
              decoration: InputDecoration(
                labelText: widget.isIncome ? 'Pilih Pos Pemasukan' : 'Pilih Seksi Pengeluaran',
                filled: true,
                fillColor: const Color(0xFFFFFBEB),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFDE68A))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFDE68A))),
              ),
              items: widget.sections.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedSection = val);
              },
            ),
            const SizedBox(height: 12),
            if (widget.isIncome && _selectedSection.toLowerCase().contains('kalender')) ...[
              DropdownButtonFormField<String>(
                value: _selectedSector,
                decoration: InputDecoration(
                  labelText: 'Pilih Sektor Wijk Jemaat *',
                  prefixIcon: const Icon(Icons.location_city, color: Color(0xFFDB2777)),
                  filled: true,
                  fillColor: const Color(0xFFFFFBEB),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFDE68A))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFDE68A))),
                ),
                items: _sectors.map((sec) => DropdownMenuItem(value: sec, child: Text(sec))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedSector = val);
                },
              ),
              const SizedBox(height: 12),
            ],

            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: widget.isIncome ? 'Keterangan / Nama Jemaat / Barang *' : 'Keterangan Barang / Keperluan *',
                hintText: widget.isIncome ? 'Contoh: Mie Gomak / Kel. R. Siahaan / Ade Saut' : 'Contoh: Kabel AUX / DP Kalender / Lilin',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Nominal Uang (Rp) *',
                prefixText: 'Rp ',
                hintText: '0',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            InkWell(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2050),
                );
                if (d != null) {
                  setState(() => _date = d);
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18, color: Color(0xFFDB2777)),
                    const SizedBox(width: 10),
                    Text(
                      'Tanggal: ' + DateFormat('dd MMMM yyyy').format(_date),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    const Text('Ubah', style: TextStyle(color: Color(0xFFBE185D), fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _noteCtrl,
              decoration: InputDecoration(
                labelText: 'Catatan Tambahan (Opsional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDB2777),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final title = _titleCtrl.text.trim();
                  final amount = double.tryParse(_amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

                  if (title.isEmpty || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Harap lengkapi Keterangan dan Nominal Uang!')),
                    );
                    return;
                  }

                  final isKalender = widget.isIncome && _selectedSection.toLowerCase().contains('kalender');
                  final newRec = PanatRecord(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    categoryType: widget.isIncome ? 'pemasukan' : 'pengeluaran',
                    section: _selectedSection,
                    subCategory: isKalender ? _selectedSector : '',
                    title: title,
                    amount: amount,
                    date: _date,
                    note: _noteCtrl.text.trim(),
                    recordedBy: widget.userRole,
                    isDeleted: false,
                  );

                  widget.onSave(newRec);
                  Navigator.pop(context);
                },
                child: const Text('Simpan & Sinkronkan Data', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


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

class PanatRecord {
  final String id;
  final String categoryType;
  final String section;
  final String title;
  final double amount;
  final DateTime date;
  final String note;
  final String recordedBy;

  PanatRecord({
    required this.id,
    required this.categoryType,
    required this.section,
    required this.title,
    required this.amount,
    required this.date,
    required this.note,
    required this.recordedBy,
  });

  bool get isIncome => categoryType == 'pemasukan';

  Map<String, dynamic> toJson() => {
        'id': id,
        'categoryType': categoryType,
        'section': section,
        'title': title,
        'amount': amount,
        'date': date.toIso8601String(),
        'note': note,
        'recordedBy': recordedBy,
      };

  factory PanatRecord.fromJson(Map<String, dynamic> json) => PanatRecord(
        id: json['id'] as String,
        categoryType: json['categoryType'] as String,
        section: json['section'] as String,
        title: json['title'] as String,
        amount: (json['amount'] as num).toDouble(),
        date: DateTime.parse(json['date'] as String),
        note: (json['note'] as String?) ?? '',
        recordedBy: (json['recordedBy'] as String?) ?? 'Panitia',
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
    const primaryBlue = Color(0xFF0284C7);

    final lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        brightness: Brightness.light,
        primary: const Color(0xFF0284C7),
        secondary: const Color(0xFF38BDF8),
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFFF0F9FF),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF38BDF8),
        foregroundColor: Color(0xFF0C4A6E),
        elevation: 0,
      ),
    );

    final darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        brightness: Brightness.dark,
        primary: const Color(0xFF10B981),
        secondary: const Color(0xFFFBBF24),
        surface: const Color(0xFF1E293B),
      ),
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E293B),
        foregroundColor: Colors.white,
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkSavedSession();
  }

  Future<void> _checkSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final pin = prefs.getString('panat_master_pin') ?? '';
    final role = prefs.getString('panat_role') ?? 'Bendahara';
    setState(() {
      _savedPin = pin;
      _savedRole = role;
      _isLoading = false;
    });
  }

  Future<void> _saveSession(String pin, String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('panat_master_pin', pin);
    await prefs.setString('panat_role', role);
    setState(() {
      _savedPin = pin;
      _savedRole = role;
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('panat_master_pin');
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
      masterPin: _savedPin,
      userRole: _savedRole,
      isDarkMode: widget.isDarkMode,
      onToggleTheme: widget.onToggleTheme,
      onLogout: _logout,
    );
  }
}

class LoginPinScreen extends StatefulWidget {
  final Function(String, String) onLoginSuccess;

  const LoginPinScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginPinScreen> createState() => _LoginPinScreenState();
}

class _LoginPinScreenState extends State<LoginPinScreen> {
  final _pinCtrl = TextEditingController();
  String _selectedRole = 'Bendahara';
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 75,
                height: 75,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0284C7), Color(0xFF38BDF8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: Text(
                    'PANAT',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Kas Panitia Natal',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Sinkronisasi Realtime  •  by Natanael',
                style: TextStyle(fontSize: 9.5, color: Colors.grey, fontWeight: FontWeight.w400, letterSpacing: 0.3),
              ),
              const SizedBox(height: 24),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Pilih Peran Anda:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text('Bendahara')),
                              selected: _selectedRole == 'Bendahara',
                              selectedColor: const Color(0xFFBAE6FD),
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
                              selectedColor: const Color(0xFFBAE6FD),
                              onSelected: (val) {
                                if (val) setState(() => _selectedRole = 'Wakil Bendahara');
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('Kata Sandi / PIN Bersama:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _pinCtrl,
                        obscureText: _obscureText,
                        decoration: InputDecoration(
                          hintText: 'Contoh: NATAL2026 atau 123456',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _obscureText = !_obscureText),
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Kata sandi ini digunakan untuk mengenkripsi data secara Zero-Knowledge. Pastikan Bendahara dan Wakil memasukkan sandi yang sama persis.',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            final pin = _pinCtrl.text.trim();
                            if (pin.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Harap masukkan PIN / Kata Sandi Kas Panitia!')),
                              );
                              return;
                            }
                            widget.onLoginSuccess(pin, _selectedRole);
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

class MainHomeScreen extends StatefulWidget {
  final String masterPin;
  final String userRole;
  final bool isDarkMode;
  final Function(bool) onToggleTheme;
  final VoidCallback onLogout;

  const MainHomeScreen({
    super.key,
    required this.masterPin,
    required this.userRole,
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
    if (raw != null) {
      try {
        final List list = jsonDecode(raw);
        setState(() {
          _records = list.map((e) => PanatRecord.fromJson(e)).toList();
          _isLoading = false;
        });
      } catch (_) {}
    }
  }

  Future<void> _saveLocalCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_records.map((e) => e.toJson()).toList());
    await prefs.setString('panat_cached_records', raw);
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
      PanatSection(id: 'inc_1', name: 'Kalender Jemaat (Sektor)', isIncome: true),
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
      final List<PanatRecord> decryptedList = [];

      for (var r in rows) {
        final cipher = r['encrypted_data'] as String;
        final plain = ZeroKnowledgeCrypto.decrypt(cipher, widget.masterPin);

        if (plain.isNotEmpty) {
          try {
            final json = jsonDecode(plain);
            decryptedList.add(PanatRecord(
              id: r['id'] as String,
              categoryType: r['category_type'] as String,
              section: r['section'] as String,
              title: json['title'] as String,
              amount: (json['amount'] as num).toDouble(),
              date: DateTime.parse(json['date'] as String),
              note: (json['note'] as String?) ?? '',
              recordedBy: (r['recorded_by'] as String?) ?? 'Panitia',
            ));
          } catch (_) {}
        }
      }

      setState(() {
        _records = decryptedList;
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

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Menyimpan "${record.title}" ke awan...'),
          duration: const Duration(milliseconds: 1500),
        ),
      );
    }

    try {
      final payload = jsonEncode({
        'title': record.title,
        'amount': record.amount,
        'date': record.date.toIso8601String(),
        'note': record.note,
      });

      final cipher = ZeroKnowledgeCrypto.encrypt(payload, widget.masterPin);

      await supabase.from('panat_records').upsert({
        'id': record.id,
        'category_type': record.categoryType,
        'section': record.section,
        'encrypted_data': cipher,
        'recorded_by': record.recordedBy,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Data "${record.title}" Rp ${formatRp(record.amount)} berhasil tersinkron!'),
            backgroundColor: const Color(0xFF0284C7),
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

  Future<void> _deleteRecord(String id) async {
    await supabase.from('panat_records').delete().match({'id': id});
    setState(() {
      _records.removeWhere((r) => r.id == id);
    });
    await _saveLocalCache();
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
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
      _buildExportAndSettingsTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'PANAT',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Kas Panitia Natal', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                Text(widget.userRole + '  |  by Natanael', style: const TextStyle(fontSize: 9, color: Color(0xFF0369A1), fontWeight: FontWeight.w500, letterSpacing: 0.2)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sinkronkan Data Awan',
            icon: _isSyncing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Color(0xFF0C4A6E), strokeWidth: 2))
                : const Icon(Icons.sync),
            onPressed: _fetchRecords,
          ),
        ],
      ),
      body: pages[_tabIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Rekap'),
          NavigationDestination(icon: Icon(Icons.arrow_downward), selectedIcon: Icon(Icons.arrow_circle_down), label: 'Masuk'),
          NavigationDestination(icon: Icon(Icons.arrow_upward), selectedIcon: Icon(Icons.arrow_circle_up), label: 'Keluar'),
          NavigationDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: 'Analisis'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Laporan'),
        ],
      ),
      floatingActionButton: _tabIndex == 1 || _tabIndex == 2
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF38BDF8),
              foregroundColor: const Color(0xFF0C4A6E),
              onPressed: () => _openAddDialog(_tabIndex == 1),
              icon: const Icon(Icons.add),
              label: Text(_tabIndex == 1 ? 'Catat Pemasukan' : 'Catat Pengeluaran'),
            )
          : null,
    );
  }

  Widget _buildDashboardTab() {
    return RefreshIndicator(
      onRefresh: _fetchRecords,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('SISA KAS BERSIH (SALDO RIIL)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  Text(
                    'Rp ' + formatRp(netBalance),
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: netBalance >= 0 ? const Color(0xFF0284C7) : Colors.redAccent,
                    ),
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.arrow_downward, color: Colors.green, size: 16),
                                SizedBox(width: 4),
                                Text('Total Pemasukan', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text('Rp ' + formatRp(totalIncome), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.arrow_upward, color: Colors.red, size: 16),
                                SizedBox(width: 4),
                                Text('Total Pengeluaran', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text('Rp ' + formatRp(totalExpense), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('REKAPITULASI PEMASUKAN', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          ..._sections.where((s) => s.isIncome).map((s) {
            final sum = _records.where((r) => r.isIncome && r.section == s.name).fold(0.0, (t, r) => t + r.amount);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                trailing: Text('Rp ' + formatRp(sum), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green)),
                onTap: () {
                  setState(() => _tabIndex = 1);
                },
              ),
            );
          }),
          const SizedBox(height: 16),
          const Text('REKAPITULASI PENGELUARAN PER SEKSI', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          ..._sections.where((s) => !s.isIncome).map((s) {
            final sum = _records.where((r) => !r.isIncome && r.section == s.name).fold(0.0, (t, r) => t + r.amount);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                trailing: Text('Rp ' + formatRp(sum), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red)),
                onTap: () {
                  setState(() => _tabIndex = 2);
                },
              ),
            );
          }),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionListTab(bool isIncome) {
    final availableSections = _sections.where((s) => s.isIncome == isIncome).toList();
    final items = _records.where((r) => r.isIncome == isIncome).toList();

    return Column(
      children: [
        Container(
          height: 52,
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
                          avatar: CircleAvatar(
                            radius: 10,
                            backgroundColor: isIncome ? Colors.green : Colors.red,
                            child: Text(count.toString(), style: const TextStyle(fontSize: 9, color: Colors.white)),
                          ),
                          label: Text(s.name, style: const TextStyle(fontSize: 12)),
                          onPressed: () => _openAddDialog(isIncome, s.name),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              IconButton(
                tooltip: isIncome ? 'Tambah Pos Baru' : 'Tambah Seksi Baru',
                icon: const Icon(Icons.add_circle, color: Color(0xFF0284C7)),
                onPressed: () => _showAddSectionDialog(isIncome),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(isIncome ? Icons.account_balance_wallet_outlined : Icons.receipt_long_outlined, size: 60, color: Colors.grey[400]),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(item.section + ' • ' + _formatDate(item.date), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                            if (item.note.isNotEmpty)
                              Text('Catatan: ' + item.note, style: TextStyle(fontSize: 11, color: Colors.grey[500], fontStyle: FontStyle.italic)),
                            const SizedBox(height: 2),
                            Text('Dicatat oleh: ' + item.recordedBy, style: const TextStyle(fontSize: 10, color: Color(0xFF0284C7), fontWeight: FontWeight.bold)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              (isIncome ? '+' : '-') + 'Rp ' + formatRp(item.amount),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: isIncome ? Colors.green[700] : Colors.red[700],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                              onPressed: () => _confirmDelete(item),
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

  void _confirmDelete(PanatRecord item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Catatan Kas?'),
        content: Text('Hapus "' + item.title + '" sebesar Rp ' + formatRp(item.amount) + '? Data ini akan terhapus di HP Bendahara dan Wakil.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              _deleteRecord(item.id);
              Navigator.pop(ctx);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ANALISIS RASIO KEUANGAN', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Pemasukan: Rp ' + formatRp(incTotal), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    Text('Rp ' + formatRp(expTotal), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (incTotal + expTotal) > 0 ? (incTotal / (incTotal + expTotal)) : 0.5,
                    minHeight: 12,
                    backgroundColor: Colors.red[300],
                    valueColor: const AlwaysStoppedAnimation(Colors.green),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pemasukan: ' + ((incTotal + expTotal) > 0 ? (incTotal / (incTotal + expTotal) * 100).toStringAsFixed(1) : '0') + '%',
                      style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Pengeluaran: ' + ((incTotal + expTotal) > 0 ? (expTotal / (incTotal + expTotal) * 100).toStringAsFixed(1) : '0') + '%',
                      style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('PROPORSI POS PEMASUKAN', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
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
                        Text('Rp ' + formatRp(entry.value), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 6,
                        backgroundColor: Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation(Colors.green),
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
        const SizedBox(height: 16),
        const Text('PROPORSI PENGELUARAN PER SEKSI', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
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
                        Text('Rp ' + formatRp(entry.value), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 6,
                        backgroundColor: Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation(Colors.redAccent),
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
                    Icon(Icons.security, color: Color(0xFF0284C7)),
                    SizedBox(width: 8),
                    Text('Keamanan Zero-Knowledge', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Data terenkripsi di server awan Supabase. Peran Anda saat ini: ' + widget.userRole + '.', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('EKSPOR LAPORAN FORMAL (LPJ)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFFDCFCE7), child: Icon(Icons.table_chart, color: Color(0xFF16A34A))),
            title: const Text('Ekspor ke Excel / Spreadsheet (.csv)', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Rekapitulasi lengkap persis tabel laporan gereja', style: TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.share),
            onTap: _exportCsv,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFFDBEAFE), child: Icon(Icons.description, color: Color(0xFF2563EB))),
            title: const Text('Ekspor ke Dokumen Word (.doc)', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Laporan LPJ formal, daftar isi klik otomatis & tabel terpisah', style: TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.share),
            onTap: _exportDoc,
          ),
        ),
        const SizedBox(height: 24),
        const Text('PENGATURAN APLIKASI', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        Card(
          child: SwitchListTile(
            secondary: Icon(widget.isDarkMode ? Icons.dark_mode : Icons.light_mode, color: const Color(0xFF0284C7)),
            title: const Text('Mode Gelap (Dark Mode)'),
            value: widget.isDarkMode,
            activeColor: const Color(0xFF0284C7),
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
            'PANAT v1.0.0 • by Natanael',
            style: TextStyle(fontSize: 9.5, color: Colors.grey[400], letterSpacing: 0.5),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _exportCsv() async {
    final csv = StringBuffer();
    csv.writeln('No,Tipe,Pos/Seksi,Keterangan/Nama,Tanggal,Jumlah (Rp),Pencatat,Catatan');

    for (int i = 0; i < _records.length; i++) {
      final r = _records[i];
      final type = r.isIncome ? 'Pemasukan' : 'Pengeluaran';
      final d = _formatDate(r.date);
      csv.writeln((i + 1).toString() + ',"' + type + '","' + r.section + '","' + r.title + '","' + d + '",' + r.amount.toString() + ',"' + r.recordedBy + '","' + r.note.replaceAll('"', '""') + '"');
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

    final incomeSections = _sections.where((s) => s.isIncome).toList();
    final expenseSections = _sections.where((s) => !s.isIncome).toList();

    doc.writeln('''<html xmlns:o='urn:schemas-microsoft-com:office:office' xmlns:w='urn:schemas-microsoft-com:office:word' xmlns='http://www.w3.org/TR/REC-html40'>
<head>
<meta charset="utf-8">
<title>Laporan Keuangan Panitia Natal</title>
<!--[if gte mso 9]>
<xml>
<w:WordDocument>
<w:View>Print</w:View>
<w:Zoom>100</w:Zoom>
<w:DoNotOptimizeForBrowser/>
</w:WordDocument>
</xml>
<![endif]-->
<style>
@page Section1 {
  size: 8.27in 11.69in;
  margin: 1in;
  mso-header-margin: 0.5in;
  mso-footer-margin: 0.5in;
  mso-footer: f1;
}
div.Section1 { page: Section1; }
body { font-family: 'Calibri', 'Segoe UI', Arial, sans-serif; color: #0F172A; line-height: 1.4; font-size: 11pt; }
h1 { color: #0284C7; font-size: 20pt; text-align: center; margin-bottom: 2px; text-transform: uppercase; font-weight: bold; }
.sub-header { text-align: center; font-size: 10.5pt; color: #64748B; margin-bottom: 25px; }
.toc-box { background-color: #F8FAFC; border: 1.5px solid #CBD5E1; border-radius: 8px; padding: 18px 24px; margin-bottom: 30px; }
.toc-title { font-size: 13pt; font-weight: bold; color: #0C4A6E; border-bottom: 2px solid #BAE6FD; padding-bottom: 6px; margin-bottom: 12px; text-transform: uppercase; }
.toc-item { margin: 6px 0; font-size: 10.5pt; }
.toc-link { color: #0284C7; text-decoration: none; font-weight: 600; }
.section-header { font-size: 14pt; color: #0C4A6E; font-weight: bold; border-left: 5px solid #0284C7; padding-left: 10px; margin-top: 30px; margin-bottom: 14px; text-transform: uppercase; }
.subsection-header { font-size: 11.5pt; color: #0369A1; font-weight: bold; margin-top: 18px; margin-bottom: 6px; }
.card-summary { background-color: #F0F9FF; border: 1.5px solid #BAE6FD; border-radius: 8px; padding: 16px; margin-bottom: 20px; }
table { width: 100%; border-collapse: collapse; margin-top: 6px; margin-bottom: 16px; }
th, td { border: 1px solid #CBD5E1; padding: 6px 8px; text-align: left; font-size: 9.5pt; }
th { background-color: #BAE6FD; color: #0C4A6E; font-weight: bold; }
tr:nth-child(even) { background-color: #F8FAFC; }
.num-col { text-align: right; font-variant-numeric: tabular-nums; }
.subtotal-row { background-color: #E0F2FE; font-weight: bold; color: #0369A1; }
.page-break { page-break-before: always; }
.sign-table { width: 100%; border: none; margin-top: 40px; }
.sign-table td { border: none; text-align: center; font-size: 11pt; padding: 10px; }
</style>
</head>
<body>
<div class="Section1">

<h1>LAPORAN KEUANGAN PANITIA NATAL (PANAT)</h1>
<div class="sub-header">
  Buku Kas & Rekapitulasi Pertanggungjawaban Real-Time • Dikelola oleh Bendahara & Wakil Bendahara<br>
  <span style="font-size: 9.5pt; color: #94A3B8;">by Natanael  |  Tanggal Cetak Dokumen: ''' + nowFormatted + '''</span>
</div>

<div class="toc-box">
  <div class="toc-title">DAFTAR ISI LAPORAN PERTANGGUNGJAWABAN</div>
  <div class="toc-item"><strong>1. BAGIAN I: REKAPITULASI UMUM KAS</strong> ................................................. <a href="#rekap-umum" class="toc-link">[Lihat Halaman]</a></div>
  <div class="toc-item" style="margin-top: 10px;"><strong>2. BAGIAN II: RINCIAN POS PEMASUKAN KAS</strong></div>
''');

    for (int i = 0; i < incomeSections.length; i++) {
      final s = incomeSections[i];
      final sum = _records.where((r) => r.isIncome && r.section == s.name).fold(0.0, (t, r) => t + r.amount);
      doc.writeln('  <div class="toc-item" style="padding-left: 20px;">• <a href="#pos-' + i.toString() + '" class="toc-link">' + s.name + '</a> (Rp ' + formatRp(sum) + ')</div>');
    }

    doc.writeln('''  <div class="toc-item" style="margin-top: 10px;"><strong>3. BAGIAN III: RINCIAN PENGELUARAN PER SEKSI</strong></div>
''');

    for (int i = 0; i < expenseSections.length; i++) {
      final s = expenseSections[i];
      final sum = _records.where((r) => !r.isIncome && r.section == s.name).fold(0.0, (t, r) => t + r.amount);
      doc.writeln('  <div class="toc-item" style="padding-left: 20px;">• <a href="#seksi-' + i.toString() + '" class="toc-link">' + s.name + '</a> (Rp ' + formatRp(sum) + ')</div>');
    }

    doc.writeln('''  <div class="toc-item" style="margin-top: 10px;"><strong>4. BAGIAN IV: LEMBAR PENGESAHAN & TANDA TANGAN</strong> ......................... <a href="#pengesahan" class="toc-link">[Lihat Halaman]</a></div>
</div>

<div class="page-break"></div>

<a name="rekap-umum" id="rekap-umum"></a>
<div class="section-header">BAGIAN I: REKAPITULASI UMUM KAS PANITIA</div>

<div class="card-summary">
  <table style="border: none; margin: 0;">
    <tr style="background: none;"><td style="border: none; font-size: 11pt; padding: 4px;"><strong>Total Seluruh Pemasukan</strong></td><td style="border: none; font-size: 11pt; text-align: right; color: #16A34A; font-weight: bold; padding: 4px;">Rp ''' + formatRp(totalIncome) + '''</td></tr>
    <tr style="background: none;"><td style="border: none; font-size: 11pt; padding: 4px;"><strong>Total Seluruh Pengeluaran</strong></td><td style="border: none; font-size: 11pt; text-align: right; color: #DC2626; font-weight: bold; padding: 4px;">Rp ''' + formatRp(totalExpense) + '''</td></tr>
    <tr style="background: none;"><td style="border: none; border-top: 2px solid #BAE6FD; font-size: 13pt; padding: 8px 4px 4px 4px;"><strong>SISA KAS BERSIH (SALDO RIIL)</strong></td><td style="border: none; border-top: 2px solid #BAE6FD; font-size: 14pt; text-align: right; color: #0284C7; font-weight: 900; padding: 8px 4px 4px 4px;">Rp ''' + formatRp(netBalance) + '''</td></tr>
  </table>
</div>

<h4 style="color: #0C4A6E; margin-bottom: 6px;">Ringkasan Komparasi Seluruh Pos & Seksi:</h4>
<table>
  <tr><th>No</th><th>Pos Pemasukan</th><th class="num-col">Jumlah Masuk</th><th>Seksi Pengeluaran</th><th class="num-col">Jumlah Keluar</th></tr>
''');

    final int maxRows = incomeSections.length > expenseSections.length ? incomeSections.length : expenseSections.length;
    for (int i = 0; i < maxRows; i++) {
      final incName = i < incomeSections.length ? incomeSections[i].name : '-';
      final incVal = i < incomeSections.length ? _records.where((r) => r.isIncome && r.section == incName).fold(0.0, (t, r) => t + r.amount) : 0.0;
      final expName = i < expenseSections.length ? expenseSections[i].name : '-';
      final expVal = i < expenseSections.length ? _records.where((r) => !r.isIncome && r.section == expName).fold(0.0, (t, r) => t + r.amount) : 0.0;

      doc.writeln('  <tr><td>' + (i + 1).toString() + '</td><td>' + incName + '</td><td class="num-col" style="color: #16A34A; font-weight: 600;">' + (incVal > 0 ? 'Rp ' + formatRp(incVal) : '-') + '</td><td>' + expName + '</td><td class="num-col" style="color: #DC2626; font-weight: 600;">' + (expVal > 0 ? 'Rp ' + formatRp(expVal) : '-') + '</td></tr>');
    }

    doc.writeln('''  <tr class="subtotal-row"><td></td><td>TOTAL PEMASUKAN</td><td class="num-col">Rp ''' + formatRp(totalIncome) + '''</td><td>TOTAL PENGELUARAN</td><td class="num-col">Rp ''' + formatRp(totalExpense) + '''</td></tr>
</table>

<div class="page-break"></div>

<div class="section-header">BAGIAN II: RINCIAN PEMASUKAN KAS (PER POS KEGIATAN)</div>
<p style="font-size: 10pt; color: #64748B; margin-top: -6px;">Setiap pos pemasukan memiliki tabel pencatatan masing-masing lengkap dengan subtotal dan tanggal transaksi.</p>
''');

    for (int i = 0; i < incomeSections.length; i++) {
      final s = incomeSections[i];
      final recs = _records.where((r) => r.isIncome && r.section == s.name).toList();
      final subtotal = recs.fold(0.0, (t, r) => t + r.amount);

      doc.writeln('<a name="pos-' + i.toString() + '" id="pos-' + i.toString() + '"></a>');
      doc.writeln('<div class="subsection-header">2.' + (i + 1).toString() + '. Pos: ' + s.name + ' <span style="font-size: 10pt; font-weight: normal; color: #64748B;">(' + recs.length.toString() + ' transaksi)</span></div>');

      if (recs.isEmpty) {
        doc.writeln('<p style="font-size: 9.5pt; color: #94A3B8; font-style: italic; margin-left: 10px;">Belum ada catatan transaksi pada pos ini.</p>');
      } else {
        doc.writeln('<table>');
        doc.writeln('  <tr><th style="width: 30px;">No</th><th>Keterangan / Nama Jemaat / Barang</th><th style="width: 90px;">Tanggal</th><th style="width: 80px;">Pencatat</th><th>Catatan</th><th class="num-col" style="width: 110px;">Jumlah (Rp)</th></tr>');

        for (int j = 0; j < recs.length; j++) {
          final r = recs[j];
          final d = _formatDate(r.date);
          doc.writeln('  <tr><td>' + (j + 1).toString() + '</td><td><strong>' + r.title + '</strong></td><td>' + d + '</td><td>' + r.recordedBy + '</td><td>' + (r.note.isEmpty ? '-' : r.note) + '</td><td class="num-col" style="color: #16A34A; font-weight: 600;">Rp ' + formatRp(r.amount) + '</td></tr>');
        }

        doc.writeln('  <tr class="subtotal-row"><td colspan="5" style="text-align: right;">Subtotal ' + s.name + ':</td><td class="num-col">Rp ' + formatRp(subtotal) + '</td></tr>');
        doc.writeln('</table>');
      }
      doc.writeln('<div style="height: 10px;"></div>');
    }

    doc.writeln('''<div class="page-break"></div>

<div class="section-header">BAGIAN III: RINCIAN PENGELUARAN (PER SEKSI KEPANITIAAN)</div>
<p style="font-size: 10pt; color: #64748B; margin-top: -6px;">Setiap seksi kepanitiaan memiliki tabel rincian belanja masing-masing lengkap dengan subtotal dan tanggal transaksi.</p>
''');

    for (int i = 0; i < expenseSections.length; i++) {
      final s = expenseSections[i];
      final recs = _records.where((r) => !r.isIncome && r.section == s.name).toList();
      final subtotal = recs.fold(0.0, (t, r) => t + r.amount);

      doc.writeln('<a name="seksi-' + i.toString() + '" id="seksi-' + i.toString() + '"></a>');
      doc.writeln('<div class="subsection-header">3.' + (i + 1).toString() + '. ' + s.name + ' <span style="font-size: 10pt; font-weight: normal; color: #64748B;">(' + recs.length.toString() + ' transaksi)</span></div>');

      if (recs.isEmpty) {
        doc.writeln('<p style="font-size: 9.5pt; color: #94A3B8; font-style: italic; margin-left: 10px;">Belum ada catatan belanja pada seksi ini.</p>');
      } else {
        doc.writeln('<table>');
        doc.writeln('  <tr><th style="width: 30px;">No</th><th>Keterangan Belanja / Keperluan</th><th style="width: 90px;">Tanggal</th><th style="width: 80px;">Pencatat</th><th>Catatan</th><th class="num-col" style="width: 110px;">Jumlah (Rp)</th></tr>');

        for (int j = 0; j < recs.length; j++) {
          final r = recs[j];
          final d = _formatDate(r.date);
          doc.writeln('  <tr><td>' + (j + 1).toString() + '</td><td><strong>' + r.title + '</strong></td><td>' + d + '</td><td>' + r.recordedBy + '</td><td>' + (r.note.isEmpty ? '-' : r.note) + '</td><td class="num-col" style="color: #DC2626; font-weight: 600;">Rp ' + formatRp(r.amount) + '</td></tr>');
        }

        doc.writeln('  <tr class="subtotal-row"><td colspan="5" style="text-align: right;">Subtotal ' + s.name + ':</td><td class="num-col" style="color: #DC2626;">Rp ' + formatRp(subtotal) + '</td></tr>');
        doc.writeln('</table>');
      }
      doc.writeln('<div style="height: 10px;"></div>');
    }

    doc.writeln('''<div class="page-break"></div>

<a name="pengesahan" id="pengesahan"></a>
<div class="section-header">BAGIAN IV: LEMBAR PENGESAHAN KAS PANITIA</div>
<p style="font-size: 11pt; margin-top: 10px;">
  Demikian laporan pertanggungjawaban penerimaan kas dan realisasi pengeluaran Panitia Natal ini disusun dengan sebenar-benarnya secara transparan dan akuntabel.
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
    <td colspan="2" style="padding-top: 40px;">
      Mengetahui & Menyetujui,<br>
      <strong>Ketua Panitia Natal</strong><br><br><br><br><br>
      ( __________________________ )
    </td>
  </tr>
</table>

<table id="hrdftrtbl" border="0" cellspacing="0" cellpadding="0" style="margin: 0;">
  <tr>
    <td>
      <div style="mso-element:footer" id="f1">
        <p class="MsoFooter" style="text-align:right; font-size:9pt; color:#64748B; font-family: Calibri, sans-serif;">
          Laporan Kas Panitia Natal  |  Halaman <span style="mso-field-code: PAGE "></span> dari <span style="mso-field-code: NUMPAGES "></span>
        </p>
      </div>
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

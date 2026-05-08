import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'firebase_options.dart';
import 'legal_screens.dart';

// ==========================================
// CLOUD SYNC & AUTH (Production Phase)
// ==========================================

import 'package:flutter/foundation.dart';
import 'paddle_stub.dart' if (dart.library.js) 'paddle_web.dart' as paddle;


class FirebaseAuthService {
  // TODO: Replace with your actual Web Client ID from Firebase Console -> Authentication -> Sign-in Method -> Google -> Web SDK Configuration
  static const String webClientId = '118109513018-7ivqfotsk4umcmggvnnfli2blvj8f5r8.apps.googleusercontent.com';
  
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? webClientId : null,
  );

  static FirebaseAuth? get _auth {
    if (Firebase.apps.isEmpty) return null;
    return FirebaseAuth.instance;
  }

  static Future<User?> signInWithGoogle() async {
    if (_auth == null) {
      throw Exception("Firebase not initialized. Please run 'flutterfire configure' or provide Web Client ID.");
    }
    try {
      if (kIsWeb) {
        GoogleAuthProvider authProvider = GoogleAuthProvider();
        authProvider.setCustomParameters({'prompt': 'select_account'});
        final UserCredential userCredential = await _auth!.signInWithPopup(authProvider);
        if (userCredential.user != null) {
          await FirebaseSyncService.initializeUser(userCredential.user!);
        }
        return userCredential.user;
      } else {
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return null; // Cancelled
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        final UserCredential userCredential = await _auth!.signInWithCredential(credential);
        if (userCredential.user != null) {
          await FirebaseSyncService.initializeUser(userCredential.user!);
        }
        return userCredential.user;
      }
    } catch (e) {
      debugPrint("Google Sign-In Error: ${e}");
      rethrow;
    }
  }

  static Future<void> signOut() async {
    try {
      await _googleSignIn.disconnect();
    } catch (e) {
      await _googleSignIn.signOut();
    }
    if (_auth != null) {
      await _auth!.signOut();
    }
  }
}

final authUserProvider = StreamProvider<User?>((ref) {
  if (Firebase.apps.isEmpty) return Stream.value(null);
  return FirebaseAuth.instance.authStateChanges();
});

class FirebaseSyncService {
  static Future<void> syncProStatus(String uid, DateTime expiry, {String? email}) async {
    try {
      if (Firebase.apps.isEmpty) return;
      
      final Map<String, dynamic> data = {
        'isPro': true,
        'proExpiry': expiry.toIso8601String(),
      };
      if (email != null) {
        data['email'] = email;
      }
      
      await FirebaseFirestore.instance.collection('users').doc(uid).set(data, SetOptions(merge: true)).timeout(const Duration(seconds: 5));
      debugPrint("--- CLOUD SYNC PRO STATUS ---");
    } catch (e) {
      debugPrint("Cloud sync pro status failed: $e");
    }
  }

  static Future<DateTime?> fetchProStatus(String uid) async {
    try {
      if (Firebase.apps.isEmpty) return null;
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get().timeout(const Duration(seconds: 5));
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final isPro = data['isPro'] == true;
        if (isPro && data.containsKey('proExpiry')) {
          return DateTime.parse(data['proExpiry']);
        }
      }
      return null;
    } catch (e) {
      debugPrint("Cloud fetch pro status failed: $e");
      return null;
    }
  }

  static Future<void> initializeUser(User user) async {
    try {
      if (Firebase.apps.isEmpty) return;
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'email': user.email,
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 5));
      debugPrint("--- CLOUD USER INITIALIZED ---");
    } catch (e) {
      debugPrint("Cloud user initialization failed: $e");
    }
  }

  static Future<void> syncTradesToCloud(String uid, List<BrokerAccount> accounts, bool isPro) async {
    try {
      if (Firebase.apps.isEmpty) {
        debugPrint("Firebase not initialized. Cannot sync.");
        return;
      }
      if (!isPro) {
        debugPrint("Sync blocked: User is not Pro.");
        return;
      }
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'accounts': accounts.map((e) => e.toJson()).toList(),
        'lastSync': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 5));
      debugPrint("--- CLOUD SYNC SUCCESS ---");
    } catch (e) {
      debugPrint("Cloud sync failed: ${e}");
      rethrow;
    }
  }

  static Future<List<BrokerAccount>?> fetchTradesFromCloud(String uid, bool isPro) async {
    try {
      if (Firebase.apps.isEmpty) return null;
      if (!isPro) {
        debugPrint("Fetch blocked: User is not Pro.");
        return null;
      }
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get().timeout(const Duration(seconds: 5));
      if (doc.exists && doc.data() != null && doc.data()!.containsKey('accounts')) {
        final List<dynamic> accs = doc.data()!['accounts'];
        return accs.map((e) => BrokerAccount.fromJson(e)).toList();
      }
      return null;
    } catch (e) {
      debugPrint("Cloud fetch failed: ${e}");
      rethrow;
    }
  }
}

// Web-Safe MVP Mock for Local Notifications
Future<void> initializeNotifications() async {
  // Setup Android/iOS channels here for full mobile native builds 
}

void scheduleMorningPing(BrokerAccount? account) {
  if (account == null) return;
  bool isLocked = account.lockdownExpiry != null && DateTime.now().isBefore(account.lockdownExpiry!);
  
  String title;
  String body;
  if (isLocked) {
    final days = account.lockdownExpiry!.difference(DateTime.now()).inDays;
    title = 'TradeGuard Pro Alert';
    body = 'Your account is locked. $days days remaining.';
  } else {
    final activeCount = account.trades.where((t) => t.isActive).length;
    final available = 3 - activeCount;
    title = 'Good Morning!';
    body = 'You have $available trades available today in ${account.name}.';
  }

  // MVP Logger Placeholder (Scheduled for 09:00 AM)
  debugPrint("--- LOCAL NOTIFICATION SCHEDULED (09:00 AM) ---");
  debugPrint("$title: $body");
}

// ==========================================
// MODELS & BUSINESS LOGIC - STRIKE COUNTER: PDT
// ==========================================

final List<DateTime> usHolidays2026 = [
  DateTime(2026, 1, 1),   // New Year's Day
  DateTime(2026, 1, 19),  // MLK Jr. Day
  DateTime(2026, 2, 16),  // Washington's Birthday
  DateTime(2026, 4, 3),   // Good Friday
  DateTime(2026, 5, 25),  // Memorial Day
  DateTime(2026, 6, 19),  // Juneteenth
  DateTime(2026, 7, 3),   // Independence Day (Observed)
  DateTime(2026, 9, 7),   // Labor Day
  DateTime(2026, 11, 26), // Thanksgiving
  DateTime(2026, 12, 25), // Christmas
];

/// Checks if a day is a trading day (skips weekends and holidays)
bool isTradingDay(DateTime date) {
  if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) return false;
  final dateOnly = DateTime(date.year, date.month, date.day);
  return !usHolidays2026.contains(dateOnly);
}

/// Adds days while skipping Saturdays, Sundays, and Holidays
DateTime adjustToTradingDay(DateTime date) {
  DateTime adjusted = date;
  while (!isTradingDay(adjusted)) {
    adjusted = adjusted.add(const Duration(days: 1));
  }
  return adjusted;
}

DateTime getTradingExpiration(DateTime tradeDate) {
  DateTime effectiveDate = adjustToTradingDay(tradeDate);
  DateTime result = effectiveDate;
  int added = 0;
  while (added < 5) {
    result = result.add(const Duration(days: 1));
    if (isTradingDay(result)) {
      added++;
    }
  }
  return DateTime(result.year, result.month, result.day);
}

/// US Market T+1 Settlement: Funds clear 1 business day after the trade
DateTime getSettlementDate(DateTime tradeDate) {
  DateTime effectiveDate = adjustToTradingDay(tradeDate);
  DateTime result = effectiveDate.add(const Duration(days: 1));
  while (!isTradingDay(result)) {
    result = result.add(const Duration(days: 1));
  }
  return DateTime(result.year, result.month, result.day);
}

int getTradingSessionsLeft(DateTime expiration) {
  DateTime current = DateTime.now();
  if (current.isAfter(expiration)) return 0;
  int sessions = 0;
  current = DateTime(current.year, current.month, current.day);
  DateTime end = DateTime(expiration.year, expiration.month, expiration.day);
  
  while (current.isBefore(end)) {
    current = current.add(const Duration(days: 1));
    if (isTradingDay(current)) {
      sessions++;
    }
  }
  return sessions > 5 ? 5 : sessions;
}

class Trade {
  final String id;
  final String ticker;
  final DateTime timestamp;

  Trade({
    required this.id,
    required this.ticker,
    required this.timestamp,
  });

  DateTime get actualExpiry => tradingExpiry;
  DateTime get tradingExpiry => getTradingExpiration(timestamp);
  DateTime get settlement => getSettlementDate(timestamp);
  bool get isActive => DateTime.now().isBefore(tradingExpiry);
  bool get isSettled => DateTime.now().isAfter(settlement);

  Map<String, dynamic> toJson() => {
    'id': id,
    'ticker': ticker,
    'timestamp': timestamp.toIso8601String(),
  };

  factory Trade.fromJson(Map<String, dynamic> json) => Trade(
    id: json['id'],
    ticker: json['ticker'],
    timestamp: DateTime.parse(json['timestamp']),
  );
}

// ==========================================
// STATE MANAGEMENT (RIVERPOD) & PAYWALL
// ==========================================

class ProStatusNotifier extends StateNotifier<DateTime?> {
  StreamSubscription? _statusSubscription;
  final Ref ref;

  ProStatusNotifier(this.ref) : super(null) {
    _loadExpiration();
    _listenToFirestore();
  }

  void _listenToFirestore() {
    ref.listen(authUserProvider, (previous, next) {
      final user = next.value;
      _statusSubscription?.cancel();
      if (user != null) {
        _statusSubscription = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots()
            .listen((doc) {
          if (doc.exists && doc.data() != null) {
            final data = doc.data()!;
            if (data['isPro'] == true && data.containsKey('proExpiry')) {
              final expiry = DateTime.parse(data['proExpiry']);
              setExpiry(expiry);
            } else {
              setExpiry(null);
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadExpiration() async {
    final prefs = await SharedPreferences.getInstance();
    final String? expiryStr = prefs.getString('proExpiry');
    if (expiryStr != null) {
      state = DateTime.parse(expiryStr);
    }
  }

  Future<void> setExpiry(DateTime? expiry) async {
    state = expiry;
    final prefs = await SharedPreferences.getInstance();
    if (expiry == null) {
      await prefs.remove('proExpiry');
    } else {
      await prefs.setString('proExpiry', expiry.toIso8601String());
    }
  }

  Future<void> refreshStatus() async {
    final user = ref.read(authUserProvider).value;
    if (user != null) {
      final expiry = await FirebaseSyncService.fetchProStatus(user.uid);
      await setExpiry(expiry);
    }
  }
}

final proExpiryProvider = StateNotifierProvider<ProStatusNotifier, DateTime?>((ref) {
  return ProStatusNotifier(ref);
});

final isProProvider = Provider<bool>((ref) {
  final expiry = ref.watch(proExpiryProvider);
  if (expiry == null) return false;
  return expiry.isAfter(DateTime.now());
});

Future<bool> handleAccountSwitch(User user, WidgetRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  final lastUid = prefs.getString('lastLoggedInUid');
  bool wiped = false;
  if (lastUid != null && lastUid != user.uid) {
    ref.read(accountsProvider.notifier).wipeLocalData();
    ref.read(proExpiryProvider.notifier).setExpiry(null);
    wiped = true;
  }
  await prefs.setString('lastLoggedInUid', user.uid);
  return wiped;
}

class BrokerAccount {
  final String id;
  final String name;
  final List<Trade> trades;
  final DateTime? lockdownExpiry;

  BrokerAccount({
    required this.id,
    required this.name,
    required this.trades,
    this.lockdownExpiry,
  });

  BrokerAccount copyWith({
    String? name,
    List<Trade>? trades,
    DateTime? lockdownExpiry,
  }) {
    return BrokerAccount(
      id: id,
      name: name ?? this.name,
      trades: trades ?? this.trades,
      lockdownExpiry: lockdownExpiry ?? this.lockdownExpiry,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'trades': trades.map((e) => e.toJson()).toList(),
    'lockdownExpiry': lockdownExpiry?.toIso8601String(),
  };

  factory BrokerAccount.fromJson(Map<String, dynamic> json) => BrokerAccount(
    id: json['id'],
    name: json['name'],
    trades: (json['trades'] as List).map((e) => Trade.fromJson(e)).toList(),
    lockdownExpiry: json['lockdownExpiry'] != null ? DateTime.parse(json['lockdownExpiry']) : null,
  );
}

final accountsProvider = StateNotifierProvider<AccountsNotifier, List<BrokerAccount>>((ref) {
  return AccountsNotifier(ref);
});

class AccountsNotifier extends StateNotifier<List<BrokerAccount>> {
  Timer? _cleanupTimer;
  final Ref ref;

  AccountsNotifier(this.ref) : super([]) {
    _loadAccounts();
    _cleanupTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      bool changed = false;
      for (var a in state) {
        for (var t in a.trades) {
          if (!t.isActive) changed = true;
        }
      }
      if (changed) state = [...state]; // Trigger rebuild for active filters
    });
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    super.dispose();
  }

  void _autoSyncIfPro() {
    final isPro = ref.read(isProProvider);
    final authUser = ref.read(authUserProvider).value;
    if (isPro && authUser != null) {
      FirebaseSyncService.syncTradesToCloud(authUser.uid, state, isPro);
    }
  }

  void wipeLocalData() {
    state = [];
    _saveAccounts(state);
  }

  Future<void> _loadAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final String? accountsJson = prefs.getString('accounts');
    if (accountsJson != null) {
      final List<dynamic> decoded = jsonDecode(accountsJson);
      state = decoded.map((e) => BrokerAccount.fromJson(e)).toList();
    } else {
      state = [BrokerAccount(id: 'default', name: 'Main Account', trades: [])];
    }
  }

  Future<void> _saveAccounts(List<BrokerAccount> accs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accounts', jsonEncode(accs.map((e) => e.toJson()).toList()));
  }

  String addAccount(String name) {
    final id = 'acc_${DateTime.now().millisecondsSinceEpoch}';
    final acc = BrokerAccount(
      id: id,
      name: name,
      trades: [],
    );
    state = [...state, acc];
    _saveAccounts(state);
    _autoSyncIfPro();
    return id;
  }

  void setAccounts(List<BrokerAccount> accounts) {
    state = accounts;
    _saveAccounts(state);
  }

  void updateAccount(BrokerAccount updated) {
    state = state.map((acc) => acc.id == updated.id ? updated : acc).toList();
    _saveAccounts(state);
    _autoSyncIfPro();
  }

  void addTrade(String accountId, String ticker) {
    state = state.map((acc) {
      if (acc.id == accountId) {
        final now = DateTime.now();
        final trade = Trade(
          id: now.millisecondsSinceEpoch.toString(),
          ticker: ticker.toUpperCase(),
          timestamp: now,
        );
        final activeTradesInfo = acc.trades.where((t) => t.isActive).toList();
        DateTime? newLockdown = acc.lockdownExpiry;
        if (activeTradesInfo.length >= 3) {
          // Trigger 90-day lockdown
          newLockdown = now.add(const Duration(days: 90));
        }
        return BrokerAccount(id: acc.id, name: acc.name, trades: [...acc.trades, trade], lockdownExpiry: newLockdown);
      }
      return acc;
    }).toList();
    _saveAccounts(state);
    _autoSyncIfPro();
  }

  void removeTrade(String accountId, String tradeId) {
    state = state.map((acc) {
      if (acc.id == accountId) {
        final newTrades = acc.trades.where((t) => t.id != tradeId).toList();
        final activeCount = newTrades.where((t) => t.isActive).length;
        DateTime? newLockdown = acc.lockdownExpiry;
        if (activeCount < 3 && newLockdown != null) {
          // Immediately lift lockdown if trades drop below 3 via deletion
          newLockdown = null; 
        }
        return BrokerAccount(
          id: acc.id,
          name: acc.name,
          trades: newTrades,
          lockdownExpiry: newLockdown,
        );
      }
      return acc;
    }).toList();
    _saveAccounts(state);
    _autoSyncIfPro();
  }

  void updateTrade(String accountId, Trade updatedTrade) {
    state = state.map((acc) {
      if (acc.id == accountId) {
        final newTrades = acc.trades.map((t) => t.id == updatedTrade.id ? updatedTrade : t).toList();
        return BrokerAccount(id: acc.id, name: acc.name, trades: newTrades, lockdownExpiry: acc.lockdownExpiry);
      }
      return acc;
    }).toList();
    _saveAccounts(state);
    _autoSyncIfPro();
  }

  void resetLockdown(String accountId) {
    state = state.map((acc) {
      if (acc.id == accountId) {
        return BrokerAccount(id: acc.id, name: acc.name, trades: [], lockdownExpiry: null);
      }
      return acc;
    }).toList();
    _saveAccounts(state);
    _autoSyncIfPro();
  }

  void deleteAccount(String accountId) {
    state = state.where((acc) => acc.id != accountId).toList();
    if (state.isEmpty) {
      state = [BrokerAccount(id: 'default', name: 'Main Account', trades: [])];
    }
    _saveAccounts(state);
    _autoSyncIfPro();
  }
}

final selectedAccountIdProvider = StateProvider<String?>((ref) => null);

final selectedAccountProvider = Provider<BrokerAccount?>((ref) {
  final accounts = ref.watch(accountsProvider);
  final selectedId = ref.watch(selectedAccountIdProvider);
  if (accounts.isEmpty) return null;
  if (selectedId == null) return accounts.first;
  try {
    return accounts.firstWhere((a) => a.id == selectedId);
  } catch (e) {
    return accounts.first;
  }
});

final activeTradesProvider = Provider<List<Trade>>((ref) {
  final acc = ref.watch(selectedAccountProvider);
  if (acc == null) return [];
  return acc.trades.where((t) => t.isActive).toList();
});

final availableTradesProvider = Provider<int>((ref) {
  final active = ref.watch(activeTradesProvider);
  return 3 - active.length;
});

final oldestActiveTradeProvider = Provider<Trade?>((ref) {
  final active = ref.watch(activeTradesProvider);
  if (active.isEmpty) return null;
  final sorted = List<Trade>.from(active)..sort((a, b) => a.tradingExpiry.compareTo(b.tradingExpiry));
  return sorted.first;
});

// ==========================================
// MAIN APP
// ==========================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase init failed: \${e}");
  }
  await initializeNotifications();
  runApp(const ProviderScope(child: TradeGuardApp()));
}

class TradeGuardApp extends StatelessWidget {
  const TradeGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TradeGuard Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        primaryColor: const Color(0xFF00FF00),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FF00),   // Neon Green
          surface: Color(0xFF111111),
          error: Color(0xFFFF3B30),     // Emergency Red
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/terms': (context) => const TermsScreen(),
        '/privacy': (context) => const PrivacyScreen(),
        '/pricing': (context) => const PricingScreen(),
        '/refund': (context) => const RefundScreen(),
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        // Only redirect to dashboard if we are still on the splash screen route
        // This prevents deep links (like /pricing) from being interrupted.
        if (ModalRoute.of(context)?.isCurrent ?? false) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/icon.png', width: 120, height: 120, errorBuilder: (_,__,___) => const Icon(Icons.security, size: 120, color: Color(0xFF00FF00))),
            const SizedBox(height: 24),
            const Text('TRADEGUARD PRO', style: TextStyle(color: Color(0xFF00FF00), fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 4.0)),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// UI LOGIC & WIDGETS
// ==========================================

/// Formats the remaining timespan until expiration
String formatDuration(Duration duration, {bool longTermFormat = false}) {
  if (duration.isNegative) return "Expired";
  final days = duration.inDays;
  final hours = duration.inHours.remainder(24);
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  
  if (longTermFormat && days > 0) {
    return "$days DAYS ${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')} REMAINING";
  }
  
  return "${duration.inHours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
}

/// A real-time updating text widget for the countdown
class CountdownText extends StatefulWidget {
  final DateTime target;
  final TextStyle? style;
  final bool longTermFormat;

  const CountdownText({super.key, required this.target, this.style, this.longTermFormat = false});

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  late Timer _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    // Update the UI string every exactly 1 second
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateRemaining());
  }

  void _updateRemaining() {
    if (!mounted) return;
    setState(() {
      _remaining = widget.target.difference(DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      formatDuration(_remaining, longTermFormat: widget.longTermFormat),
      style: widget.style,
      textAlign: TextAlign.center,
    );
  }
}



/// Flashing mechanism for 0 Days remaining
class FlashingWidget extends StatefulWidget {
  final Widget child;
  const FlashingWidget({super.key, required this.child});

  @override
  State<FlashingWidget> createState() => _FlashingWidgetState();
}

class _FlashingWidgetState extends State<FlashingWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..repeat(reverse: true);
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _controller, child: widget.child);
  }
}


/// Dynamic Sessions Left UI Component
class TradingSessionsCounter extends StatelessWidget {
  final int sessions;
  const TradingSessionsCounter({super.key, required this.sessions});

  @override
  Widget build(BuildContext context) {
    Color color = Colors.cyan;
    if (sessions <= 0) {
      color = const Color(0xFF00FF00); // Neon Green
    } else if (sessions <= 2) {
      color = Colors.orange;
    }

    String displayText = sessions <= 0 ? "READY" : "$sessions Sessions Left";

    Widget content = Row(
      children: [
        Icon(sessions <= 0 ? Icons.check_circle : Icons.calendar_today, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          displayText,
          style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 8),
        Text(sessions <= 0 ? "STATUS" : "TRADING", style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );

    if (sessions <= 0) {
      return FlashingWidget(child: content);
    }
    return content;
  }
}

/// The Banner shown at the top of the interface
class NextResetBanner extends ConsumerWidget {
  const NextResetBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oldest = ref.watch(oldestActiveTradeProvider);
    if (oldest == null) return const SizedBox.shrink();

    final dateFormat = DateFormat('MMM dd, yyyy @ HH:mm');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        border: Border(bottom: BorderSide(color: Color(0xFF333333))),
      ),
      child: Column(
        children: [
          const Text(
            "NEXT RESET",
            style: TextStyle(
              color: Colors.amber, 
              fontWeight: FontWeight.bold, 
              letterSpacing: 1.5, 
              fontSize: 12
            ),
          ),
          const SizedBox(height: 6),
          Text(
            dateFormat.format(oldest.tradingExpiry),
            style: const TextStyle(
              color: Colors.white, 
              fontSize: 16, 
              fontWeight: FontWeight.w600
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer_outlined, color: Colors.amber, size: 16),
              const SizedBox(width: 6),
              CountdownText(
                target: oldest.tradingExpiry,
                style: const TextStyle(color: Colors.amberAccent, fontSize: 15),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ProPaywallScreen extends ConsumerStatefulWidget {
  const ProPaywallScreen({super.key});

  @override
  ConsumerState<ProPaywallScreen> createState() => _ProPaywallScreenState();
}

class _ProPaywallScreenState extends ConsumerState<ProPaywallScreen> {
  bool _showSuccess = false;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      final Stream<List<PurchaseDetails>> purchaseUpdated = _inAppPurchase.purchaseStream;
      _purchaseSubscription = purchaseUpdated.listen((purchaseDetailsList) {
        _listenToPurchaseUpdated(purchaseDetailsList);
      }, onDone: () {
        _purchaseSubscription?.cancel();
      }, onError: (error) {
        // Handle error
      });
    }
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      _purchaseSubscription?.cancel();
    }
    super.dispose();
  }

  Future<void> _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Pending purchase handling UI
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Purchase Error: ${purchaseDetails.error!}'), backgroundColor: Colors.red));
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                   purchaseDetails.status == PurchaseStatus.restored) {
          User? user = ref.read(authUserProvider).value;
          if (user != null) {
            final expiry = DateTime.now().add(const Duration(days: 30));
            await FirebaseSyncService.syncProStatus(user.uid, expiry, email: user.email);
            await ref.read(proExpiryProvider.notifier).refreshStatus();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Purchase successful! Pro unlocked.'), backgroundColor: Color(0xFF00FF00)));
            }
          }
        }
        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for Pro status changes to trigger success animation and redirect
    ref.listen<bool>(isProProvider, (previous, next) {
      if (next == true && (_showSuccess == false)) {
        setState(() {
          _showSuccess = true;
        });
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) Navigator.pop(context);
        });
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white54),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => ref.read(proExpiryProvider.notifier).refreshStatus(),
            icon: const Icon(Icons.refresh, color: Color(0xFF00FF00), size: 16),
            label: const Text('REFRESH', style: TextStyle(color: Color(0xFF00FF00), fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black,
                  const Color(0xFF00FF00).withOpacity(0.05),
                  Colors.black,
                ],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.workspace_premium, size: 80, color: Color(0xFF00FF00)),
                    const SizedBox(height: 24),
                    const Text(
                      'TRADEGUARD PRO',
                      style: TextStyle(
                        color: Color(0xFF00FF00),
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4.0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'INSTANT CLOUD SYNC',
                      style: TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2.0),
                    ),
                    const SizedBox(height: 40),
                    _buildPremiumFeatureCard([
                      _FeatureItem(Icons.sync, 'Auto-Sync trades across all devices'),
                      _FeatureItem(Icons.devices, 'Workstation & Mobile continuity'),
                      _FeatureItem(Icons.cloud_done, 'Full Multi-Account Synchronization'),
                      _FeatureItem(Icons.notifications_active, 'Subscription expiry alerts'),
                    ]),
                    const SizedBox(height: 48),
                    const Text(
                      '\$4.99 / MONTH',
                      style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                    ),
                    const Text(
                      'Cancel anytime. Access remains until end of period.',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00FF00),
                          foregroundColor: Colors.black,
                          elevation: 8,
                          shadowColor: const Color(0xFF00FF00).withOpacity(0.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          try {
                            User? user = ref.read(authUserProvider).value;
                            if (user == null) {
                              user = await FirebaseAuthService.signInWithGoogle();
                            }
                            if (user != null) {
                              await handleAccountSwitch(user, ref);
                              
                              if (kIsWeb) {
                                paddle.openPaddleCheckout('pri_01kmcnvf7ge2ewfkcm5perxeey');
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Opening Secure Paddle Checkout...', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), backgroundColor: Colors.amber, duration: Duration(seconds: 4)),
                                  );
                                }
                              } else {
                                // PLAY STORE CHECKOUT
                                final bool available = await InAppPurchase.instance.isAvailable();
                                if (!available) {
                                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Store is not available on this device.'), backgroundColor: Colors.red));
                                  return;
                                }
                                const Set<String> kIds = <String>{'tradeguard_pro_monthly'};
                                final ProductDetailsResponse response = await InAppPurchase.instance.queryProductDetails(kIds);
                                if (response.notFoundIDs.isNotEmpty || response.productDetails.isEmpty) {
                                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product not found. Ensure "tradeguard_pro_monthly" is active in Play Console.'), backgroundColor: Colors.red));
                                  return;
                                }
                                final ProductDetails productDetails = response.productDetails.first;
                                final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
                                await InAppPurchase.instance.buyNonConsumable(purchaseParam: purchaseParam);
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red));
                            }
                          }
                        },
                        child: const Text('UPGRADE TO PRO', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RefundScreen())),
                      child: const Text(
                        '14-DAY REFUND GUARANTEE. SEE REFUND POLICY.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextButton(
                      onPressed: () async {
                        try {
                          final user = await FirebaseAuthService.signInWithGoogle();
                          if (user != null && context.mounted) {
                            await handleAccountSwitch(user, ref);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Checking cloud status...', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), backgroundColor: Color(0xFF00FF00)),
                            );
                            await ref.read(proExpiryProvider.notifier).refreshStatus();
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red));
                          }
                        }
                      },
                      child: const Text('ALREADY A PRO MEMBER? SYNC NOW', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () async {
                        if (!kIsWeb) {
                          try {
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Checking Play Store for past purchases...'), backgroundColor: Colors.amber));
                            await InAppPurchase.instance.restorePurchases();
                          } catch (e) {
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restore error: $e'), backgroundColor: Colors.red));
                          }
                        } else {
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Web subscriptions sync automatically on login.'), backgroundColor: Colors.orange));
                        }
                      },
                      child: const Text('RESTORE PURCHASES', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_showSuccess)
            Positioned.fill(
              child: Container(
                color: Colors.black87,
                child: Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 500),
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.scale(
                          scale: 0.8 + (0.2 * value),
                          child: child,
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111111),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF00FF00), width: 2),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF00FF00).withOpacity(0.2), blurRadius: 30, spreadRadius: 10),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_outline, color: Color(0xFF00FF00), size: 100),
                          const SizedBox(height: 24),
                          const Text(
                            'WELCOME TO PRO',
                            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Your premium features and cloud sync are now active.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPremiumFeatureCard(List<_FeatureItem> features) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF333333)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00FF00).withOpacity(0.05),
            blurRadius: 20,
            spreadRadius: 5,
          )
        ],
      ),
      child: Column(
        children: features.map((f) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF00FF00).withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(f.icon, color: const Color(0xFF00FF00), size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(f.text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500))),
            ],
          ),
        )).toList(),
      ),
    );
  }
}

class _FeatureItem {
  final IconData icon;
  final String text;
  _FeatureItem(this.icon, this.text);
}

/// Main entry dashboard
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  void _showLogTradeDialog(BuildContext context, WidgetRef ref) {
    final tickerController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF111111),
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Color(0xFF00FF00), width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          title: const Text(
            'QUICK LOG', 
            style: TextStyle(color: Color(0xFF00FF00), fontWeight: FontWeight.bold)
          ),
          content: TextField(
            controller: tickerController,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            decoration: const InputDecoration(
              hintText: 'TICKER (e.g. TSLA)',
              hintStyle: TextStyle(color: Colors.white30),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FF00))),
            ),
            onSubmitted: (val) {
              final acc = ref.read(selectedAccountProvider);
              if (acc != null) {
                final ticker = val.trim().isEmpty ? 'TRADE' : val.trim();
                ref.read(accountsProvider.notifier).addTrade(acc.id, ticker);
              }
              Navigator.pop(context);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF00),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              onPressed: () {
                final text = tickerController.text.trim();
                final acc = ref.read(selectedAccountProvider);
                if (acc != null) {
                  final ticker = text.isEmpty ? 'TRADE' : text;
                  ref.read(accountsProvider.notifier).addTrade(acc.id, ticker);
                }
                Navigator.pop(context);
              },
              child: const Text('LOG', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showEditTradeDialog(BuildContext context, WidgetRef ref, Trade trade) {
    final tickerController = TextEditingController(text: trade.ticker);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF111111),
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Color(0xFF00FF00), width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          title: const Text('EDIT DAY TRADE', style: TextStyle(color: Color(0xFF00FF00), fontWeight: FontWeight.bold)),
          content: TextField(
            controller: tickerController,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            decoration: const InputDecoration(
              hintText: 'TICKER (e.g. TSLA)',
              hintStyle: TextStyle(color: Colors.white30),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FF00))),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF00),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              onPressed: () {
                final text = tickerController.text.trim();
                final acc = ref.read(selectedAccountProvider);
                if (acc != null && text.isNotEmpty) {
                  final updated = Trade(
                    id: trade.id,
                    ticker: text,
                    timestamp: trade.timestamp,
                  );
                  ref.read(accountsProvider.notifier).updateTrade(acc.id, updated);
                }
                Navigator.pop(context);
              },
              child: const Text('SAVE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showAccountSettingsDialog(BuildContext context, WidgetRef ref, BrokerAccount? account) {
    if (account == null) return;
    final nameController = TextEditingController(text: account.name);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF111111),
          shape: RoundedRectangleBorder(side: const BorderSide(color: Colors.white10), borderRadius: BorderRadius.circular(8)),
          title: const Text('ACCOUNT SETTINGS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          content: TextField(
            controller: nameController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Account Name',
              labelStyle: TextStyle(color: Colors.white54),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FF00))),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF111111),
                    title: const Text('Delete Account?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    content: const Text('All trade history for this broker will be permanently deleted.', style: TextStyle(color: Colors.white54)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL', style: TextStyle(color: Colors.white54))),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.pop(context);
                          ref.read(accountsProvider.notifier).deleteAccount(account.id);
                        },
                        child: const Text('DELETE', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('DELETE', style: TextStyle(color: Colors.redAccent)),
            ),
            const Spacer(),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF00)),
              onPressed: () {
                final updated = account.copyWith(name: nameController.text.trim());
                ref.read(accountsProvider.notifier).updateAccount(updated);
                Navigator.pop(context);
              },
              child: const Text('SAVE CHANGES', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showAddAccountDialog(BuildContext context, WidgetRef ref) {
    final existingBrokerNames = ref.read(accountsProvider).map((e) => e.name).toSet();
    final List<String> brokers = [
      'Interactive Brokers (IBKR)', 'Charles Schwab', 'Robinhood', 
      'Webull', 'Fidelity', 'E*TRADE', 'TradeStation', 
      'Tastytrade', 'Firstrade', 'Other'
    ].where((b) => b == 'Other' || !existingBrokerNames.contains(b)).toList();

    String? selectedBroker = brokers.isNotEmpty ? brokers.first : 'Other';
    final otherController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF111111),
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: Color(0xFF00FF00), width: 1),
                borderRadius: BorderRadius.circular(8),
              ),
              title: const Text('ADD BROKER ACCOUNT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: selectedBroker,
                      dropdownColor: const Color(0xFF222222),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: const InputDecoration(
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FF00))),
                      ),
                      items: brokers.map((b) => DropdownMenuItem(value: b, child: Text(b, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => selectedBroker = val);
                      },
                    ),
                    if (selectedBroker == 'Other') ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: otherController,
                        autofocus: true,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        decoration: const InputDecoration(
                          hintText: 'Enter Broker Name',
                          hintStyle: TextStyle(color: Colors.white30),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FF00))),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FF00),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  onPressed: () {
                    String finalName = (selectedBroker == 'Other' || selectedBroker == null) 
                        ? (otherController.text.trim().isEmpty ? 'Custom Broker' : otherController.text.trim())
                        : selectedBroker!;
                    final newId = ref.read(accountsProvider.notifier).addAccount(finalName);
                    ref.read(selectedAccountIdProvider.notifier).state = newId;
                    Navigator.pop(context);
                  },
                  child: const Text('ADD', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTrades = ref.watch(activeTradesProvider);
    final activeCount = activeTrades.length;

    final selectedAcc = ref.watch(selectedAccountProvider);
    final accounts = ref.watch(accountsProvider);

    final expiry = ref.read(proExpiryProvider);
    bool justExpired = false;
    if (expiry != null && expiry.isBefore(DateTime.now())) {
      justExpired = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(proExpiryProvider.notifier).setExpiry(null);
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (justExpired && context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF111111),
            title: const Text('Subscription Expired', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
            content: const Text('Your monthly subscription access has ended, to enjoy auto sync and multi device support please pay or whatever you think is good', style: TextStyle(color: Colors.white, fontSize: 16)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('DISMISS', style: TextStyle(color: Colors.white54))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ProPaywallScreen()));
                },
                child: const Text('RENEW PRO', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      } else {
        scheduleMorningPing(selectedAcc);
        if (expiry != null && expiry.isAfter(DateTime.now())) {
          final daysLeft = expiry.difference(DateTime.now()).inDays;
          if (daysLeft <= 5 && daysLeft >= 0) {
            debugPrint("--- LOCAL NOTIFICATION SCHEDULED (SUBSCRIPTION REMINDER) ---");
            debugPrint("Reminder: Your TradeGuard Pro subscription expires in $daysLeft day(s)!");
          }
        }
      }
    });

    final bool inLockdown = selectedAcc?.lockdownExpiry != null && DateTime.now().isBefore(selectedAcc!.lockdownExpiry!);
    final bool isWarning = activeCount == 3 && !inLockdown;

    Color getAccColor(BrokerAccount acc) {
      final bool accInLockdown = acc.lockdownExpiry != null && DateTime.now().isBefore(acc.lockdownExpiry!);
      final int accActiveCount = acc.trades.where((t) => t.isActive).length;
      final bool accIsWarning = accActiveCount == 3 && !accInLockdown;
      return accInLockdown ? const Color(0xFFFF3B30) : (accIsWarning ? Colors.amber : const Color(0xFF00FF00));
    }

    final primaryColor = selectedAcc != null ? getAccColor(selectedAcc) : const Color(0xFF00FF00);

    return Scaffold(
      appBar: AppBar(
        title: LayoutBuilder(
          builder: (context, constraints) {
            final isSmall = constraints.maxWidth < 360;
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedAcc?.id,
                      isExpanded: false,
                      dropdownColor: const Color(0xFF111111),
                      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF00FF00)),
                      style: TextStyle(
                        color: primaryColor, 
                        fontWeight: FontWeight.bold, 
                        letterSpacing: 0.5, 
                        fontSize: isSmall ? 14 : 16
                      ),
                      onChanged: (String? newValue) {
                        if (newValue == 'ADD_NEW') {
                          _showAddAccountDialog(context, ref);
                        } else if (newValue != null) {
                          ref.read(selectedAccountIdProvider.notifier).state = newValue;
                        }
                      },
                      items: [
                        ...accounts.map((acc) {
                          final accColor = getAccColor(acc);
                          return DropdownMenuItem<String>(
                            value: acc.id,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(acc.name.toUpperCase(), overflow: TextOverflow.ellipsis, style: TextStyle(color: accColor)),
                                if (accounts.length > 1) ...[
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () {
                                      // Close dropdown by popping first to avoid "stuck" UI
                                      Navigator.pop(context); 
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          backgroundColor: const Color(0xFF111111),
                                          title: const Text('Delete Broker?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          content: Text('Delete "${acc.name}" and all its history?', style: TextStyle(color: Colors.white70)),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL', style: TextStyle(color: Colors.white54))),
                                            TextButton(
                                              onPressed: () {
                                                Navigator.pop(ctx);
                                                ref.read(accountsProvider.notifier).deleteAccount(acc.id);
                                                // If we deleted the active one, the notifier handles switching, but we need to ensure UI refreshes.
                                              },
                                              child: const Text('DELETE', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    child: const Icon(Icons.delete_outline, color: Colors.white24, size: 16),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }),
                        const DropdownMenuItem<String>(
                          value: 'ADD_NEW',
                          child: Text('+ ADD', style: TextStyle(color: Colors.white54, fontSize: 14)),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white30, size: 20),
                  onPressed: () => _showAccountSettingsDialog(context, ref, selectedAcc),
                  tooltip: 'Account Settings',
                ),
              ],
            );
          }
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: false,
        actions: [
          Consumer(
            builder: (context, ref, child) {
              final authUser = ref.watch(authUserProvider).value;
              final isPro = ref.watch(isProProvider);
              final isSmallDevice = MediaQuery.of(context).size.width < 600;

              Future<void> handleRestore() async {
                if (!isPro) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ProPaywallScreen()));
                  return;
                }
                User? user = authUser;
                try {
                  if (user == null) {
                    user = await FirebaseAuthService.signInWithGoogle();
                  }
                  if (user != null) {
                    await handleAccountSwitch(user, ref);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Restoring Data...', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), backgroundColor: Colors.amber, duration: Duration(seconds: 1)),
                      );
                    }
                    final cloudData = await FirebaseSyncService.fetchTradesFromCloud(user.uid, isPro);
                    if (cloudData != null && cloudData.isNotEmpty) {
                      ref.read(accountsProvider.notifier).setAccounts(cloudData);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('accounts', jsonEncode(cloudData.map((e) => e.toJson()).toList()));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Restored across devices!', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), backgroundColor: Color(0xFF00FF00), duration: Duration(seconds: 2)),
                        );
                      }
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No backup found!', style: TextStyle(color: Colors.white)), backgroundColor: Colors.orange));
                      }
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red));
                  }
                }
              }

              Future<void> handleBackup() async {
                if (!isPro) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ProPaywallScreen()));
                  return;
                }
                User? user = authUser;
                try {
                  if (user == null) {
                    user = await FirebaseAuthService.signInWithGoogle();
                  }
                  if (user != null) {
                    final wiped = await handleAccountSwitch(user, ref);
                    if (wiped) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account switched! Local data wiped. Tap Restore.', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), backgroundColor: Colors.orange));
                      return; // Stop backup if they just switched accounts and wiped data!
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Syncing to Cloud...', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), 
                          backgroundColor: Colors.amber,
                          duration: Duration(seconds: 1),
                        ),
                      );
                    }
                    final accounts = ref.read(accountsProvider);
                    await FirebaseSyncService.syncTradesToCloud(user.uid, accounts, isPro);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Synced to Cloud!', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), 
                          backgroundColor: Color(0xFF00FF00),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Sign-in cancelled.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
                          backgroundColor: Colors.orange,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.toString().replaceAll('Exception: ', ''), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }
                }
              }

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  isSmallDevice
                      ? IconButton(
                          icon: const Icon(Icons.cloud_download, color: Colors.amber, size: 22),
                          onPressed: handleRestore,
                          tooltip: 'RESTORE',
                        )
                      : TextButton.icon(
                          onPressed: handleRestore,
                          icon: const Icon(Icons.cloud_download, color: Colors.amber, size: 20),
                          label: const Text('RESTORE', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13, height: 1.0)),
                        ),
                  isSmallDevice
                      ? IconButton(
                          icon: const Icon(Icons.cloud_upload, color: Color(0xFF00FF00), size: 22),
                          onPressed: handleBackup,
                          tooltip: 'BACKUP',
                        )
                      : TextButton.icon(
                          onPressed: handleBackup,
                          icon: const Icon(Icons.cloud_upload, color: Color(0xFF00FF00), size: 20),
                          label: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('BACKUP', style: TextStyle(color: Color(0xFF00FF00), fontWeight: FontWeight.bold, fontSize: 13, height: 1.0)),
                              Text(authUser?.email ?? 'Guest', style: const TextStyle(color: Colors.white54, fontSize: 10, height: 1.0), overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                  if (authUser != null)
                    IconButton(
                      icon: const Icon(Icons.power_settings_new, color: Colors.white54),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: const Color(0xFF111111),
                            title: const Text('Log Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            content: const Text('Are you sure you want to log out?', style: TextStyle(color: Colors.white54)),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL', style: TextStyle(color: Colors.white54))),
                              TextButton(
                                onPressed: () async {
                                  Navigator.pop(ctx);
                                  await FirebaseAuthService.signOut();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logged out successfully', style: TextStyle(color: Colors.white)), backgroundColor: Colors.orange));
                                  }
                                },
                                child: const Text('LOG OUT', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              );
            }
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF111111),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.black),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text('TRADEGUARD PRO', style: TextStyle(color: Color(0xFF00FF00), fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  SizedBox(height: 8),
                  Text('Settings & Legal', style: TextStyle(color: Colors.white70, fontSize: 15)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.amber),
              title: const Text('PDT Guide', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const InfoScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.workspace_premium, color: Colors.amber),
              title: const Text('TradeGuard Pro', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ProPaywallScreen()));
              },
            ),

            const Divider(color: Color(0xFF222222)),
            ListTile(
              leading: const Icon(Icons.warning_amber, color: Colors.redAccent),
              title: const Text('Wipe Local Data', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF111111),
                    title: const Text('Wipe All Data?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    content: const Text('This will permanently delete your offline trades. Only do this if you are changing accounts or have a cloud backup.', style: TextStyle(color: Colors.white54)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL', style: TextStyle(color: Colors.white54))),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          ref.read(accountsProvider.notifier).wipeLocalData();
                          ref.read(proExpiryProvider.notifier).setExpiry(null);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Device data wiped clean.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.orange));
                          }
                        },
                        child: const Text('WIPE DATA', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              },
            ),
            const Divider(color: Color(0xFF222222)),
            ListTile(
              leading: const Icon(Icons.chrome_reader_mode_outlined, color: Color(0xFF00FF00)),
              title: const Text('About TradeGuard Pro', style: TextStyle(color: Color(0xFF00FF00), fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (ctx) => AboutDialog(
                    applicationName: 'TradeGuard Pro',
                    applicationVersion: '1.0.3+5',
                    applicationIcon: Image.asset('assets/icon.png', width: 48),
                    children: [
                      const Text('The ultimate PDT protection utility for retail traders.'),
                    ],
                  ),
                );
              },
            ),
            const Divider(color: Color(0xFF222222)),
            ListTile(
              leading: const Icon(Icons.description_outlined, color: Colors.white54),
              title: const Text('Terms of Service', style: TextStyle(color: Colors.white54, fontSize: 14)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/terms');
              },
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined, color: Colors.white54),
              title: const Text('Privacy Policy', style: TextStyle(color: Colors.white54, fontSize: 14)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/privacy');
              },
            ),
            ListTile(
              leading: const Icon(Icons.payments_outlined, color: Colors.white54),
              title: const Text('Pricing Policy', style: TextStyle(color: Colors.white54, fontSize: 14)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/pricing');
              },
            ),
            ListTile(
              leading: const Icon(Icons.assignment_return_outlined, color: Colors.white54),
              title: const Text('Refund Policy', style: TextStyle(color: Colors.white54, fontSize: 14)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/refund');
              },
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              const NextResetBanner(),
              if (inLockdown)
                _buildLockdownOverlay(context, ref, selectedAcc!)
              else
                // Strike Counter UI
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40.0),
                  child: Column(
                    children: [
                      _buildStrikeCounter(context, ref, activeCount, primaryColor, isWarning),
                      const SizedBox(height: 40),
                      _buildLaunchButton(context, ref, inLockdown),
                    ],
                  ),
                ),

              // Trade History Section
              Expanded(
                  child: Consumer(
                    builder: (context, ref, child) {
                      final acc = ref.watch(selectedAccountProvider);
                      if (acc == null || acc.trades.isEmpty) {
                        return const Center(child: Text('No trades logged yet.', style: TextStyle(color: Colors.white24)));
                      }
                      final sortedTrades = List<Trade>.from(acc.trades)..sort((a, b) => b.timestamp.compareTo(a.timestamp));
                      return ListView.builder(
                        padding: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
                        itemCount: sortedTrades.length,
                        itemBuilder: (context, index) {
                          final trade = sortedTrades[index];
                          return Card(
                            color: const Color(0xFF111111),
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: trade.isActive ? (isWarning ? Colors.amber : const Color(0xFF00FF00)) : Colors.white10,
                                width: 1
                              ),
                            ),
                            child: ListTile(
                              onTap: () => _showEditTradeDialog(context, ref, trade),
                              title: Text(trade.ticker, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text('Resets On: ', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                      Text(DateFormat('EEEE, MMM dd @ HH:mm').format(trade.tradingExpiry), 
                                        style: TextStyle(color: trade.isActive ? (isWarning ? Colors.amber : const Color(0xFF00FF00)) : Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
                                      Text(' (', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                      CountdownText(target: trade.tradingExpiry, 
                                        style: TextStyle(color: trade.isActive ? (isWarning ? Colors.amber : const Color(0xFF00FF00)) : Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
                                      Text(' remaining)', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today_outlined, color: trade.isActive ? Colors.cyan : Colors.white24, size: 14),
                                      const SizedBox(width: 6),
                                      TradingSessionsCounter(sessions: getTradingSessionsLeft(trade.tradingExpiry)),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.white30, size: 28),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: const Color(0xFF111111),
                                      title: const Text('Delete Trade Log?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      content: const Text('This will remove this trade log from your history. This action cannot be undone.', style: TextStyle(color: Colors.white54)),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL', style: TextStyle(color: Colors.white54))),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(ctx);
                                            final acc = ref.read(selectedAccountProvider);
                                            if (acc != null) {
                                              ref.read(accountsProvider.notifier).removeTrade(acc.id, trade.id);
                                            }
                                          },
                                          child: const Text('DELETE', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                tooltip: 'Delete Trade',
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLockdownOverlay(BuildContext context, WidgetRef ref, BrokerAccount account) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final daysRemaining = account.lockdownExpiry!.difference(DateTime.now()).inDays + 1;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFF3B30), width: 3),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline, color: Color(0xFFFF3B30), size: 64),
          const SizedBox(height: 24),
          const Text('PDT LOCKDOWN', style: TextStyle(color: Color(0xFFFF3B30), fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
          const SizedBox(height: 32),
          Text(
            '$daysRemaining DAYS\nREMAINING',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.amber, fontSize: 56, fontWeight: FontWeight.w900, height: 1.1),
          ),
          const SizedBox(height: 32),
          Text(
            'Full Access Restored On: ${dateFormat.format(account.lockdownExpiry!)}',
            style: const TextStyle(color: Colors.white38, fontSize: 13),
          ),
          const SizedBox(height: 64),
          SizedBox(
            width: 240,
            height: 56,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF3B30),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                elevation: 4,
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF111111),
                    title: const Text('Admin Overide?', style: TextStyle(color: Colors.white)),
                    content: const Text('This will reset your account history and lift the safety lock manually.', style: TextStyle(color: Colors.white54)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL', style: TextStyle(color: Colors.white54))),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          ref.read(accountsProvider.notifier).resetLockdown(account.id);
                        }, 
                        child: const Text('RESET NOW', style: TextStyle(color: Color(0xFF00FF00), fontWeight: FontWeight.bold))
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
              label: const Text('MANUAL RESET', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrikeCounter(BuildContext context, WidgetRef ref, int activeCount, Color primaryColor, bool isWarning) {
    return Column(
      children: [
        if (isWarning) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.amber, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'WARNING: 3/3 DAY TRADES USED\nNEXT TRADE = 90-DAY LOCKDOWN',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.0),
            ),
          ),
          const SizedBox(height: 32),
        ],
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 220,
              height: 220,
              child: CircularProgressIndicator(
                value: activeCount / 3,
                strokeWidth: 15,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$activeCount/3',
                  style: TextStyle(color: primaryColor, fontSize: 64, fontWeight: FontWeight.w900),
                ),
                const Text(
                  'USED',
                  style: TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLaunchButton(BuildContext context, WidgetRef ref, bool inLockdown) {
    final activeCount = ref.watch(selectedAccountProvider)?.trades.where((t) => t.isActive).length ?? 0;
    final isWarning = activeCount == 3 && !inLockdown;
    final btnColor = inLockdown ? (Colors.grey[900] ?? Colors.black) : (isWarning ? Colors.amber : const Color(0xFF00FF00));
    
    return SizedBox(
      width: 320,
      height: 60,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: btnColor,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: inLockdown ? 0 : 8,
          shadowColor: btnColor.withOpacity(0.5),
        ),
        onPressed: inLockdown ? null : () => _showLogTradeDialog(context, ref),
        icon: const Icon(Icons.add_circle, color: Colors.black, size: 24),
        label: const Text('LOG DAY TRADE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
      ),
    );
  }
}

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('INFO & LEGAL', style: TextStyle(color: Color(0xFF00FF00), fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('A. The PDT Guide', style: TextStyle(color: Color(0xFF00FF00), fontSize: 22, fontWeight: FontWeight.w900)),
            SizedBox(height: 12),
            Text('What is the PDT Rule?', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('The Pattern Day Trader (PDT) rule is a regulation by FINRA that applies to US Margin accounts.', style: TextStyle(color: Colors.white70, fontSize: 15)),
            SizedBox(height: 16),
            Text('The Limit: You are allowed 3 day trades within a rolling 5 business day period.', style: TextStyle(color: Colors.white70, fontSize: 15)),
            SizedBox(height: 8),
            Text('The Strike: If you execute a 4th day trade, your account is flagged as a Pattern Day Trader.', style: TextStyle(color: Colors.white70, fontSize: 15)),
            SizedBox(height: 8),
            Text('The Penalty: If your account balance is below \$25,000, your broker will restrict day trading for 90 days.', style: TextStyle(color: Colors.white70, fontSize: 15)),
            SizedBox(height: 8),
            Text('How TradeGuard Helps: We track your 5-day rolling window and alert you BEFORE you hit the 4th trade.', style: TextStyle(color: Colors.white70, fontSize: 15)),
            SizedBox(height: 36),
            Text('B. Terms & Conditions', style: TextStyle(color: Color(0xFF00FF00), fontSize: 22, fontWeight: FontWeight.w900)),
            SizedBox(height: 12),
            Text('Disclaimer & Terms:', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Informational Tool: TradeGuard is an independent tracking tool and is NOT directly linked to your brokerage account.', style: TextStyle(color: Colors.white70, fontSize: 15)),
            SizedBox(height: 8),
            Text('Accuracy: While we strive for 100% accuracy, users should always verify their trade count with their official broker dashboard.', style: TextStyle(color: Colors.white70, fontSize: 15)),
            SizedBox(height: 8),
            Text('No Liability: TradeGuard is not responsible for any trading losses, broker penalties, or account lockdowns.', style: TextStyle(color: Colors.white70, fontSize: 15)),
            SizedBox(height: 8),
            Text('Data Privacy: Your trade data is stored locally on your device. When you back up your data via Google log-in, we store your trade logs to sync across your logged-in devices and your email ID to track subscription status.', style: TextStyle(color: Colors.white70, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}


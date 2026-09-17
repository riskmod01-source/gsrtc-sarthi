import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase Error: $e");
  }
  // AdMob Initialize
  await MobileAds.instance.initialize();
  runApp(const GSRTCSarthiApp());
}


class GSRTCSarthiApp extends StatelessWidget {
  const GSRTCSarthiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GSRTC સારથિ & મિત્ર',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'sans-serif',
        colorSchemeSeed: const Color(0xFF0D5C46),
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      ),
      home: const MasterAppRouter(),
    );
  }
}

// પ્રશ્ન મોડેલ
class CompleteQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  CompleteQuestion({required this.question, required this.options, required this.correctIndex});

  Map<String, dynamic> toMap() => {
    'question': question,
    'options': options,
    'correctIndex': correctIndex,
  };

  factory CompleteQuestion.fromMap(Map<String, dynamic> map) => CompleteQuestion(
    question: map['question'] ?? '',
    options: List<String>.from(map['options'] ?? []),
    correctIndex: map['correctIndex'] ?? 0,
  );
}

// સ્પેશિયલ ટેસ્ટ મોડેલ
class SpecialExamModel {
  final String id;
  final String title;
  final String targetRole;
  final int price;
  final int durationMinutes;
  final List<CompleteQuestion> questions;

  SpecialExamModel({
    required this.id,
    required this.title,
    required this.targetRole,
    required this.price,
    required this.durationMinutes,
    required this.questions,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'targetRole': targetRole,
    'price': price,
    'durationMinutes': durationMinutes,
    'questions': questions.map((q) => q.toMap()).toList(),
  };

  factory SpecialExamModel.fromMap(Map<String, dynamic> map, String docId) => SpecialExamModel(
    id: docId,
    title: map['title'] ?? '',
    targetRole: map['targetRole'] ?? '',
    price: map['price'] ?? 0,
    durationMinutes: map['durationMinutes'] ?? 60,
    questions: (map['questions'] as List<dynamic>?)
            ?.map((item) => CompleteQuestion.fromMap(Map<String, dynamic>.from(item)))
            .toList() ??
        [],
  );
}

// ૧. માસ્ટર રાઉટર
class MasterAppRouter extends StatefulWidget {
  const MasterAppRouter({super.key});

  @override
  State<MasterAppRouter> createState() => _MasterAppRouterState();
}

class _MasterAppRouterState extends State<MasterAppRouter> {
  static const String _adminEmail = 'riskmod01@gmail.com';
  int _currentStep = 1;
  String _currentUserEmail = '';
  String _currentUserName = '';

  void _onUserAuthenticated(String email, String defaultName) {
    setState(() {
      _currentUserEmail = email;
      if (email.toLowerCase() == _adminEmail.toLowerCase()) {
        _currentUserName = 'Thakor XYZ (Admin)';
        _currentStep = 4;
      } else {
        _currentUserName = defaultName.isNotEmpty ? defaultName : 'વિદ્યાર્થી મિત્ર';
        _currentStep = 2;
      }
    });
  }

  void _onProfileCompleted(String enteredName) {
    setState(() {
      _currentUserName = enteredName;
      _currentStep = 3;
    });
  }

  Future<void> _onLogout() async {
    try {
      await FirebaseAuth.instance.signOut();
      await GoogleSignIn().signOut();
    } catch (_) {}
    setState(() {
      _currentStep = 1;
      _currentUserEmail = '';
      _currentUserName = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_currentStep) {
      case 1:
        return CompleteLoginScreen(onLoginSuccess: _onUserAuthenticated);
      case 2:
        return CompleteProfileScreen(
          suggestedName: _currentUserName,
          onComplete: _onProfileCompleted,
          onBack: _onLogout,
        );
      case 3:
        return MainExamHomeScreen(
          candidateName: _currentUserName,
          onLogout: _onLogout,
        );
      case 4:
        return CompleteAdminPanel(
          adminEmail: _currentUserEmail,
          onLogout: _onLogout,
        );
      default:
        return CompleteLoginScreen(onLoginSuccess: _onUserAuthenticated);
    }
  }
}

// ૨. લૉગિન પેજ (Firebase Email/Password + Google Sign-In)
class CompleteLoginScreen extends StatefulWidget {
  final Function(String email, String name) onLoginSuccess;
  const CompleteLoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<CompleteLoginScreen> createState() => _CompleteLoginScreenState();
}

class _CompleteLoginScreenState extends State<CompleteLoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isSignUp = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleEmailAuth() async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('કૃપા કરીને ઈમેઇલ અને પાસવર્ડ લખો')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      UserCredential userCred;
      if (_isSignUp) {
        userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        userCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
      final user = userCred.user;
      if (user != null) {
        widget.onLoginSuccess(user.email ?? email, user.displayName ?? '');
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text(e.message ?? 'Authentication error')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text('ભૂલ: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;
      if (user != null) {
        widget.onLoginSuccess(user.email ?? googleUser.email, user.displayName ?? googleUser.displayName ?? '');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text('Google Sign-In Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF0D5C46);
    const accentYellow = Color(0xFFE5A93C);

    return Scaffold(
      backgroundColor: primaryGreen,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: accentYellow, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.directions_bus_rounded, color: Colors.black87, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('GSRTC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2)),
                      Text('EXAM ROUTE', style: TextStyle(color: accentYellow, fontWeight: FontWeight.w600, fontSize: 10, letterSpacing: 1.5)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text('YOUR NEXT STOP: SELECTION', style: TextStyle(color: accentYellow, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const SizedBox(height: 6),
              const Text('Study with a route.\nArrive ready.', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, height: 1.2)),
              const SizedBox(height: 8),
              Text(
                'A focused practice desk for GSRTC conductor and driver candidates. Gujarati-friendly from the first question.',
                style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 12),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(22.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 15, offset: const Offset(0, 8))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(_isSignUp ? 'નવું એકાઉન્ટ બનાવો' : 'Sign In / પ્રવેશ કરો', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 6),
                    Text(
                      _isSignUp ? 'વિગતો ભરીને નોંધણી કરો' : 'સુરક્ષિત રીતે તૈયારી શરૂ કરવા લૉગિન કરો',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'ઈમેઇલ (Email)',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'પાસવર્ડ (Password)',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else ...[
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _handleEmailAuth,
                        child: Text(_isSignUp ? 'Sign Up' : 'Log In', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: () => setState(() => _isSignUp = !_isSignUp),
                        child: Text(_isSignUp ? 'પહેલેથી એકાઉન્ટ છે? Log In' : 'નવા છો? એકાઉન્ટ બનાવો (Sign Up)', style: const TextStyle(fontSize: 12)),
                      ),
                      const Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('અથવા', style: TextStyle(color: Colors.grey, fontSize: 12))),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _handleGoogleSignIn,
                        icon: Image.network(
                          'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/480px-Google_%22G%22_logo.svg.png',
                          height: 20,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata, color: Colors.red, size: 24),
                        ),
                        label: const Text('Continue with Google', style: TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    ],
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

// ૩. પ્રોફાઇલ પેજ
class CompleteProfileScreen extends StatefulWidget {
  final String suggestedName;
  final Function(String) onComplete;
  final VoidCallback onBack;
  const CompleteProfileScreen({super.key, required this.suggestedName, required this.onComplete, required this.onBack});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  late TextEditingController _nameController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.suggestedName == 'વિદ્યાર્થી મિત્ર' ? '' : widget.suggestedName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF0D5C46);
    const accentYellow = Color(0xFFE5A93C);

    return Scaffold(
      backgroundColor: primaryGreen,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: widget.onBack)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Container(padding: const EdgeInsets.all(16), decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle), child: const Icon(Icons.person_pin, size: 60, color: accentYellow)),
              const SizedBox(height: 16),
              const Text('સ્વાગત છે ઉમેદવાર!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 6),
              const Text('તમારું પૂરું નામ દાખલ કરો', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.white70)),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.badge_outlined),
                          hintText: 'દા.ત. Thakor XYZ',
                          labelText: 'તમારું પૂરું નામ',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'કૃપા કરીને નામ દાખલ કરો' : null,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            widget.onComplete(_nameController.text.trim());
                          }
                        },
                        child: const Text('તૈયારી શરૂ કરો', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

// ૪. હોમ પેજ
class MainExamHomeScreen extends StatelessWidget {
  final String candidateName;
  final VoidCallback onLogout;
  const MainExamHomeScreen({super.key, required this.candidateName, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF0D5C46);

    return Scaffold(
      appBar: AppBar(
        title: const Text('GSRTC સારથિ ડેસ્ક'),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: onLogout)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: Row(
                children: [
                  const CircleAvatar(radius: 26, backgroundColor: Color(0xFFE8F5E9), child: Icon(Icons.person, color: primaryGreen, size: 30)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('નમસ્તે, $candidateName 👋', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const Text('તૈયારી માટે શ્રેણી પસંદ કરો', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RoleExamHubScreen(role: 'કંડક્ટર'))),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF1976D2), Color(0xFF1565C0)]),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(color: Colors.blue.withAlpha(70), blurRadius: 8, offset: const Offset(0, 4))],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.confirmation_number_outlined, color: Colors.white, size: 40),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('કંડક્ટર પરીક્ષા હબ', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text('આખો ભેગો ટેસ્ટ • ૬ વિષયવાર ટેસ્ટ • સ્પેશિયલ પેઇડ ટેસ્ટ્સ', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RoleExamHubScreen(role: 'ડ્રાઈવર'))),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF00796B), Color(0xFF004D40)]),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(color: Colors.teal.withAlpha(70), blurRadius: 8, offset: const Offset(0, 4))],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.drive_eta, color: Colors.white, size: 40),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ડ્રાઈવર પરીક્ષા હબ', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text('આખો ભેગો ટેસ્ટ • ૬ વિષયવાર ટેસ્ટ • સ્પેશિયલ પેઇડ ટેસ્ટ્સ', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            // કરંટ અફેર્સ Card
            InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CurrentAffairsScreen())),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFE65100), Color(0xFFBF360C)]),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(color: Colors.orange.withAlpha(70), blurRadius: 8, offset: const Offset(0, 4))],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.newspaper, color: Colors.white, size: 40),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('કરંટ અફેર્સ', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text('GSRTC • ગુજરાત સરકાર • દૈનિક અપડેટ્સ', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            // ગત વર્ષના પેપર્સ Card
            InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PreviousPapersScreen())),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF6A1B9A), Color(0xFF4A148C)]),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(color: Colors.purple.withAlpha(70), blurRadius: 8, offset: const Offset(0, 4))],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.picture_as_pdf, color: Colors.white, size: 40),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ગત વર્ષના પેપર્સ', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text('PDF ફોર્મેટ • જૂના પ્રશ્નપત્રો • Solutions', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            // ઓફલાઇન બુકમાર્ક Card
            InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BookmarksScreen())),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF37474F), Color(0xFF263238)]),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(color: Colors.blueGrey.withAlpha(70), blurRadius: 8, offset: const Offset(0, 4))],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.bookmark, color: Colors.white, size: 40),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ઓફલાઇન બુકમાર્ક', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text('સેવ કરેલા પ્રશ્નો • ઇન્ટરનેટ વગર વાંચો', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ૫. એક્ઝામ હબ (Cloud Firestore થી લાઈવ રીઅલ-ટાઇમ સિંક)
class RoleExamHubScreen extends StatefulWidget {
  final String role;
  const RoleExamHubScreen({super.key, required this.role});

  @override
  State<RoleExamHubScreen> createState() => _RoleExamHubScreenState();
}

class _RoleExamHubScreenState extends State<RoleExamHubScreen> {
  final Set<String> _unlockedExamIds = {};

  void _showPaymentDialog(SpecialExamModel exam) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.workspace_premium, color: Colors.amber),
            SizedBox(width: 8),
            Text('સ્પેશિયલ ટેસ્ટ અનલૉક'),
          ],
        ),
        content: Column(
          mainAxisSize: minAxisSize(),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(exam.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            const Text('એડમિન દ્વારા નિર્ધારિત સત્તાવાર ફી:'),
            const SizedBox(height: 12),
            Center(
              child: Text(
                '₹ ${exam.price}',
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.green),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text('(${exam.questions.length} પ્રશ્નો • ${exam.durationMinutes} મિનિટ)', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('રદ કરો')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              setState(() => _unlockedExamIds.add(exam.id));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(backgroundColor: Colors.green, content: Text('ચૂકવણી સફળ! સ્પેશિયલ ટેસ્ટ અનલૉક થઈ ગયો છે! 🎉')),
              );
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ExamQuizScreen(
                    role: widget.role,
                    testTitle: exam.title,
                    questions: exam.questions,
                    durationSeconds: exam.durationMinutes * 60,
                  ),
                ),
              );
            },
            child: const Text('Pay & Start Test'),
          ),
        ],
      ),
    );
  }

  MainAxisSize minAxisSize() => MainAxisSize.min;

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.role == 'કંડક્ટર' ? const Color(0xFF1976D2) : const Color(0xFF00796B);

    final List<Map<String, dynamic>> subjects = widget.role == 'કંડક્ટર'
        ? [
            {'title': '૧. કંડક્ટર ફરજો & ટિકિટિંગ', 'desc': 'લગેજ નિયમો, ભાડા ગણતરી', 'icon': Icons.assignment_turned_in},
            {'title': '૨. પ્રાથમિક સારવાર (First Aid)', 'desc': 'પ્રાથમિક ઉપચાર, CPR', 'icon': Icons.medical_services_outlined},
            {'title': '૩. મોટર વ્હીકલ એક્ટ & ટ્રાફિક સાઈન', 'desc': 'ટ્રાફિક નિયમો અને દંડ', 'icon': Icons.traffic},
            {'title': '૪. ગુજરાતી ભાષા અને વ્યાકરણ', 'desc': 'જોડણી, સમાસ, અલંકાર', 'icon': Icons.menu_book},
            {'title': '૫. સામાન્ય જ્ઞાન (GK) & કરંટ અફેર્સ', 'desc': 'ગુજરાત ભૂગોળ, ઇતિહાસ', 'icon': Icons.public},
            {'title': '૬. સામાન્ય ગણિત અને રીઝનિંગ', 'desc': 'તાર્કિક કસોટી અને ગણતરી', 'icon': Icons.calculate_outlined},
          ]
        : [
            {'title': '૧. મોટર મિકેનિઝમ & સ્પેરપાર્ટ્સ', 'desc': 'એન્જિન રચના, કૂલિંગ સિસ્ટમ', 'icon': Icons.build_circle_outlined},
            {'title': '૨. MV એક્ટ, નિયમો & રોડ સેફ્ટી', 'desc': 'હેવી વ્હીકલ ડ્રાઇવિંગ રૂલ્સ', 'icon': Icons.traffic},
            {'title': '૩. પ્રાથમિક સમારકામ & ફોલ્ટ્સ', 'desc': 'બ્રેક, ક્લચ ફોલ્ટ નિવારણ', 'icon': Icons.car_repair},
            {'title': '૪. ગુજરાતી ભાષા અને વ્યાકરણ', 'desc': 'સામાન્ય ભાષા કસોટી', 'icon': Icons.menu_book},
            {'title': '૫. સામાન્ય જ્ઞાન (GK) & ગુજરાત પરિચય', 'desc': 'માર્ગ વ્યવહાર ઇતિહાસ', 'icon': Icons.public},
            {'title': '૬. રોડ સેફ્ટી & મુસાફર વર્તણૂક', 'desc': 'સુરક્ષિત ડ્રાઇવિંગ માર્ગદર્શન', 'icon': Icons.shield_outlined},
          ];

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.role} પરીક્ષા હબ'),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ૧. આખો ભેગો મોક ટેસ્ટ
          Card(
            elevation: 3,
            color: Colors.deepOrange.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.deepOrange.shade300)),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const CircleAvatar(radius: 24, backgroundColor: Colors.deepOrange, child: Icon(Icons.star, color: Colors.white)),
              title: const Text('આખો ભેગો મોક ટેસ્ટ (Full Exam)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: const Text('બધા ૬ વિષયોમાંથી કુલ પ્રશ્નો • ૧ કલાક સમય'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () async {
                final snapshot = await FirebaseFirestore.instance.collection('full_mock').doc(widget.role).get();
                List<CompleteQuestion> qList = [];
                if (snapshot.exists && snapshot.data()?['questions'] != null) {
                  qList = (snapshot.data()!['questions'] as List)
                      .map((e) => CompleteQuestion.fromMap(Map<String, dynamic>.from(e)))
                      .toList();
                }
                if (qList.isEmpty) {
                  qList = List.generate(
                    50,
                    (i) => CompleteQuestion(
                      question: '${widget.role} મોડેલ પ્રશ્ન ${i + 1}: GSRTC સત્તાવાર નિયમ?',
                      options: ['સાચો વિકલ્પ', 'વિકલ્પ B', 'વિકલ્પ C', 'વિકલ્પ D'],
                      correctIndex: 0,
                    ),
                  );
                }
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ExamQuizScreen(
                      role: widget.role,
                      testTitle: '${widget.role} ફુલ મોક ટેસ્ટ',
                      questions: qList,
                      durationSeconds: 3600,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // ૨. સ્પેશિયલ પેઇડ ટેસ્ટ્સ (Cloud Firestore લાઈવ)
          const Text('સ્પેશિયલ પેઇડ ટેસ્ટ્સ (Admin Added):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('special_tests').where('targetRole', isEqualTo: widget.role).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()));
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: const Center(child: Text('અત્યારે કોઈ સ્પેશિયલ ટેસ્ટ સક્રિય નથી.', style: TextStyle(color: Colors.grey))),
                );
              }

              final specialTests = docs.map((doc) => SpecialExamModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();

              return Column(
                children: specialTests.map((exam) {
                  final isUnlocked = _unlockedExamIds.contains(exam.id);
                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.only(bottom: 12),
                    color: Colors.amber.shade50,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.amber.shade600)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      leading: CircleAvatar(
                        backgroundColor: Colors.amber.shade700,
                        child: Icon(isUnlocked ? Icons.lock_open : Icons.lock, color: Colors.white),
                      ),
                      title: Row(
                        children: [
                          Expanded(child: Text(exam.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(8)),
                            child: Text('₹ ${exam.price}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                      subtitle: Text('${exam.questions.length} પ્રશ્નો • ${exam.durationMinutes} મિનિટ • ${isUnlocked ? 'અનલૉક કરેલ' : 'ક્લિક કરીને અનલૉક કરો'}'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () {
                        if (isUnlocked) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ExamQuizScreen(
                                role: widget.role,
                                testTitle: exam.title,
                                questions: exam.questions,
                                durationSeconds: exam.durationMinutes * 60,
                              ),
                            ),
                          );
                        } else {
                          _showPaymentDialog(exam);
                        }
                      },
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 18),

          // ૩. વિષયવાર પ્રેક્ટિસ ટેસ્ટ
          const Text('વિષયવાર પ્રેક્ટિસ ટેસ્ટ (૩૦ મિનિટ):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          ...subjects.map((sub) {
            final docKey = '${widget.role}_${sub['title']}';
            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: themeColor.withAlpha(25),
                  child: Icon(sub['icon'] as IconData, color: themeColor),
                ),
                title: Text(sub['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text('${sub['desc']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () async {
                  final snapshot = await FirebaseFirestore.instance.collection('subject_tests').doc(docKey).get();
                  List<CompleteQuestion> questions = [];
                  if (snapshot.exists && snapshot.data()?['questions'] != null) {
                    questions = (snapshot.data()!['questions'] as List)
                        .map((e) => CompleteQuestion.fromMap(Map<String, dynamic>.from(e)))
                        .toList();
                  }
                  if (questions.isEmpty) {
                    questions = List.generate(
                      25,
                      (i) => CompleteQuestion(
                        question: '[${sub['title']}] પ્રશ્ન ${i + 1}: GSRTC સિલેબસ આધારિત પ્રશ્ન?',
                        options: ['સાચો જવાબ A', 'જવાબ B', 'જવાબ C', 'જવાબ D'],
                        correctIndex: 0,
                      ),
                    );
                  }
                  if (!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ExamQuizScreen(
                        role: widget.role,
                        testTitle: sub['title'] as String,
                        questions: questions,
                        durationSeconds: 1800,
                      ),
                    ),
                  );
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ૬. પરીક્ષા સ્ક્રીન
class ExamQuizScreen extends StatefulWidget {
  final String role;
  final String testTitle;
  final List<CompleteQuestion> questions;
  final int durationSeconds;

  const ExamQuizScreen({
    super.key,
    required this.role,
    required this.testTitle,
    required this.questions,
    required this.durationSeconds,
  });

  @override
  State<ExamQuizScreen> createState() => _ExamQuizScreenState();
}

class _ExamQuizScreenState extends State<ExamQuizScreen> {
  int currentIndex = 0;
  int score = 0;
  int? selectedAnswer;
  Timer? _timer;
  late int remainingSeconds;

  @override
  void initState() {
    super.initState();
    remainingSeconds = widget.durationSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds > 0) {
        setState(() => remainingSeconds--);
      } else {
        _timer?.cancel();
        _showResult();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _showResult() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('પરીક્ષા પરિણામ 🎯', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('ટેસ્ટ: ${widget.testTitle}\nતમારો સ્કોર: $score / ${widget.questions.length}'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('હોમ પેજ પર જાઓ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentQ = widget.questions[currentIndex];
    final themeColor = widget.role == 'કંડક્ટર' ? const Color(0xFF1976D2) : const Color(0xFF00796B);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.testTitle, style: const TextStyle(fontSize: 16)),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade200),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.timer_outlined, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('બાકી સમય:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                    ],
                  ),
                  Text(_formatTime(remainingSeconds), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('પ્રશ્ન ${currentIndex + 1} / ${widget.questions.length}', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(currentQ.question, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(currentQ.options.length, (index) {
              final isChosen = selectedAnswer == index;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isChosen ? themeColor.withAlpha(20) : Colors.white,
                  border: Border.all(color: isChosen ? themeColor : Colors.grey.shade300, width: isChosen ? 2 : 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: ListTile(
                    title: Text(currentQ.options[index], style: const TextStyle(fontSize: 14)),
                    leading: Icon(isChosen ? Icons.check_circle : Icons.radio_button_unchecked, color: isChosen ? themeColor : Colors.grey),
                    onTap: () => setState(() => selectedAnswer = index),
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: selectedAnswer == null
                  ? null
                  : () {
                      if (selectedAnswer == currentQ.correctIndex) {
                        score++;
                      }
                      if (currentIndex < widget.questions.length - 1) {
                        setState(() {
                          currentIndex++;
                          selectedAnswer = null;
                        });
                      } else {
                        _timer?.cancel();
                        _showResult();
                      }
                    },
              child: Text(currentIndex == widget.questions.length - 1 ? 'ટેસ્ટ સબમિટ કરો' : 'આગળનો પ્રશ્ન (${currentIndex + 1}/${widget.questions.length})', style: const TextStyle(fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }
}

// ૭. એડમિન પેનલ (Cloud Firestore માં કાયમી Bulk Upload)
class CompleteAdminPanel extends StatefulWidget {
  final String adminEmail;
  final VoidCallback onLogout;

  const CompleteAdminPanel({
    super.key,
    required this.adminEmail,
    required this.onLogout,
  });

  @override
  State<CompleteAdminPanel> createState() => _CompleteAdminPanelState();
}

class _CompleteAdminPanelState extends State<CompleteAdminPanel> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isUploading = false;

  String _bulkTargetRole = 'કંડક્ટર';
  String _bulkExamType = 'આખો ભેગો મોક ટેસ્ટ';
  String _bulkSelectedSubject = '૧. કંડક્ટર ફરજો & ટિકિટિંગ';
  final _generalBulkJsonCtrl = TextEditingController();

  String _specialTargetRole = 'કંડક્ટર';
  final _specialTitleCtrl = TextEditingController();
  final _specialPriceCtrl = TextEditingController(text: '49');
  final _specialDurationCtrl = TextEditingController(text: '60');
  final _specialBulkJsonCtrl = TextEditingController();

  final List<String> _conductorSubjects = [
    '૧. કંડક્ટર ફરજો & ટિકિટિંગ',
    '૨. પ્રાથમિક સારવાર (First Aid)',
    '૩. મોટર વ્હીકલ એક્ટ & ટ્રાફિક સાઈન',
    '૪. ગુજરાતી ભાષા અને વ્યાકરણ',
    '૫. સામાન્ય જ્ઞાન (GK) & કરંટ અફેર્સ',
    '૬. સામાન્ય ગણિત અને રીઝનિંગ',
  ];

  final List<String> _driverSubjects = [
    '૧. મોટર મિકેનિઝમ & સ્પેરપાર્ટ્સ',
    '૨. MV એક્ટ, નિયમો & રોડ સેફ્ટી',
    '૩. પ્રાથમિક સમારકામ & ફોલ્ટ્સ',
    '૪. ગુજરાતી ભાષા અને વ્યાકરણ',
    '૫. સામાન્ય જ્ઞાન (GK) & ગુજરાત પરિચય',
    '૬. રોડ સેફ્ટી & મુસાફર વર્તણૂક',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _generalBulkJsonCtrl.text = '''[
  {
    "question": "કંડક્ટરે મુસાફરો પાસેથી ભાડું ક્યારે વસૂલ કરવું જોઈએ?",
    "options": ["બસ ઉપડ્યા પછી તરત", "બસ સ્ટેન્ડ પહોંચવા આવે ત્યારે", "ગમે ત્યારે", "મુસાફર કહે ત્યારે"],
    "correctIndex": 0
  }
]''';

    _specialBulkJsonCtrl.text = '''[
  {
    "question": "સ્પેશિયલ પેઇડ પ્રશ્ન: બસમાં અગ્નિશામક (Fire Extinguisher) ક્યાં રાખવામાં આવે છે?",
    "options": ["ડ્રાઈવર કેબિન નજીક", "છેલ્લી સીટ નીચે", "બસની છત પર", "કંડક્ટર બેગમાં"],
    "correctIndex": 0
  }
]''';
  }

  @override
  void dispose() {
    _tabController.dispose();
    _generalBulkJsonCtrl.dispose();
    _specialTitleCtrl.dispose();
    _specialPriceCtrl.dispose();
    _specialDurationCtrl.dispose();
    _specialBulkJsonCtrl.dispose();
    super.dispose();
  }

  Future<void> _uploadGeneralBulkQuestions() async {
    final text = _generalBulkJsonCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('કૃપા કરીને JSON ડેટા પેસ્ટ કરો')));
      return;
    }

    setState(() => _isUploading = true);
    try {
      final List<dynamic> decoded = jsonDecode(text);
      List<Map<String, dynamic>> rawList = [];
      for (var item in decoded) {
        rawList.add({
          'question': item['question'],
          'options': List<String>.from(item['options']),
          'correctIndex': item['correctIndex'],
        });
      }

      if (_bulkExamType == 'આખો ભેગો મોક ટેસ્ટ') {
        await FirebaseFirestore.instance.collection('full_mock').doc(_bulkTargetRole).set({
          'questions': FieldValue.arrayUnion(rawList),
        }, SetOptions(merge: true));
      } else {
        final docKey = '${_bulkTargetRole}_$_bulkSelectedSubject';
        await FirebaseFirestore.instance.collection('subject_tests').doc(docKey).set({
          'questions': FieldValue.arrayUnion(rawList),
        }, SetOptions(merge: true));
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.green, content: Text('સફળ! Cloud Firestore માં ${rawList.length} પ્રશ્નો કાયમી સેવ થઈ ગયા! 🎉')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.redAccent, content: Text('JSON ફોર્મેટ અથવા નેટવર્ક ભૂલ: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _uploadSpecialBulkTest() async {
    final title = _specialTitleCtrl.text.trim();
    final price = int.tryParse(_specialPriceCtrl.text.trim()) ?? 49;
    final duration = int.tryParse(_specialDurationCtrl.text.trim()) ?? 60;
    final jsonText = _specialBulkJsonCtrl.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('કૃપા કરીને સ્પેશિયલ ટેસ્ટનું નામ લખો')));
      return;
    }

    setState(() => _isUploading = true);
    try {
      final List<dynamic> decoded = jsonDecode(jsonText);
      List<Map<String, dynamic>> rawList = [];
      for (var item in decoded) {
        rawList.add({
          'question': item['question'],
          'options': List<String>.from(item['options']),
          'correctIndex': item['correctIndex'],
        });
      }

      await FirebaseFirestore.instance.collection('special_tests').add({
        'title': title,
        'targetRole': _specialTargetRole,
        'price': price,
        'durationMinutes': duration,
        'questions': rawList,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _specialTitleCtrl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.green, content: Text('સ્પેશિયલ ટેસ્ટ "$title" Cloud Firestore માં કાયમી લાઈવ થઈ ગયો! 🎉')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.redAccent, content: Text('ભૂલ: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF0D5C46);
    final currentSubjectList = _bulkTargetRole == 'કંડક્ટર' ? _conductorSubjects : _driverSubjects;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Master Desk (Thakor XYZ)'),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: widget.onLogout)],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFE5A93C),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.upload_file), text: 'મોક / વિષયો Bulk'),
            Tab(icon: Icon(Icons.workspace_premium), text: 'સ્પેશિયલ પેઇડ Bulk'),
          ],
        ),
      ),
      body: _isUploading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                        child: const Row(
                          children: [
                            Icon(Icons.cloud_sync, color: Colors.blue),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'પ્રશ્નો અહીંથી સીધા Cloud Firestore માં અપલોડ થશે અને તમામ યુઝર્સને લાઈવ દેખાશે.',
                                style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: _bulkTargetRole,
                        decoration: InputDecoration(labelText: 'વિભાગ પસંદ કરો', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                        items: const [
                          DropdownMenuItem(value: 'કંડક્ટર', child: Text('કંડક્ટર પરીક્ષા')),
                          DropdownMenuItem(value: 'ડ્રાઈવર', child: Text('ડ્રાઈવર પરીક્ષા')),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _bulkTargetRole = val!;
                            _bulkSelectedSubject = val == 'કંડક્ટર' ? _conductorSubjects[0] : _driverSubjects[0];
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _bulkExamType,
                        decoration: InputDecoration(labelText: 'ટેસ્ટનો પ્રકાર પસંદ કરો', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                        items: const [
                          DropdownMenuItem(value: 'આખો ભેગો મોક ટેસ્ટ', child: Text('આખો ભેગો મોક ટેસ્ટ (Full Mock)')),
                          DropdownMenuItem(value: 'વિષયવાર ટેસ્ટ', child: Text('૬ સત્તાવાર વિષયવાર ટેસ્ટ')),
                        ],
                        onChanged: (val) => setState(() => _bulkExamType = val!),
                      ),
                      const SizedBox(height: 12),
                      if (_bulkExamType == 'વિષયવાર ટેસ્ટ') ...[
                        DropdownButtonFormField<String>(
                          initialValue: currentSubjectList.contains(_bulkSelectedSubject) ? _bulkSelectedSubject : currentSubjectList[0],
                          decoration: InputDecoration(labelText: 'વિષય પસંદ કરો', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                          items: currentSubjectList.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                          onChanged: (val) => setState(() => _bulkSelectedSubject = val!),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: _generalBulkJsonCtrl,
                        maxLines: 12,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                        decoration: InputDecoration(
                          labelText: 'પ્રશ્નોનો JSON Bulk Data',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _uploadGeneralBulkQuestions,
                        icon: const Icon(Icons.cloud_upload),
                        label: const Text('Cloud માં કાયમી સેવ કરો (Bulk Upload)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.amber.shade300)),
                        child: const Row(
                          children: [
                            Icon(Icons.workspace_premium, color: Colors.amber),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'નવો સ્પેશિયલ પેઇડ ટેસ્ટ સીધો Cloud Firestore માં લાઈવ થશે.',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: _specialTargetRole,
                        decoration: InputDecoration(labelText: 'વિભાગ પસંદ કરો', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                        items: const [
                          DropdownMenuItem(value: 'કંડક્ટર', child: Text('કંડક્ટર પરીક્ષા')),
                          DropdownMenuItem(value: 'ડ્રાઈવર', child: Text('ડ્રાઈવર પરીક્ષા')),
                        ],
                        onChanged: (val) => setState(() => _specialTargetRole = val!),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _specialTitleCtrl,
                        decoration: InputDecoration(
                          labelText: 'સ્પેશિયલ ટેસ્ટનું નામ',
                          hintText: 'દા.ત. સુપર સિલેક્શન મેગા પેઇડ ટેસ્ટ 2026',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _specialPriceCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'ફી (₹ રૂપિયા)',
                                prefixText: '₹ ',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _specialDurationCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'સમય (મિનિટ)',
                                suffixText: 'મિનિટ',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _specialBulkJsonCtrl,
                        maxLines: 10,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                        decoration: InputDecoration(
                          labelText: 'સ્પેશિયલ ટેસ્ટના પ્રશ્નો (JSON Format)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _uploadSpecialBulkTest,
                        icon: const Icon(Icons.publish),
                        label: const Text('નવો સ્પેશિયલ ટેસ્ટ લાઈવ કરો (Publish to Cloud)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ══════════════════════════════════════════════
// કરંટ અફેર્સ સ્ક્રીન
// ══════════════════════════════════════════════
class CurrentAffairsScreen extends StatelessWidget {
  const CurrentAffairsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFE65100);
    return Scaffold(
      appBar: AppBar(
        title: const Text('કરંટ અફેર્સ'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('current_affairs')
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.newspaper, size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('હજી કોઈ કરંટ અફેર્સ ઉપલબ્ધ નથી', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  SizedBox(height: 8),
                  Text('Admin દ્વારા ટૂંક સમયમાં ઉમેરાશે', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(14),
                  leading: CircleAvatar(
                    backgroundColor: primaryColor.withAlpha(25),
                    child: const Icon(Icons.article, color: primaryColor),
                  ),
                  title: Text(data['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(data['content'] ?? '', style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 6),
                      Text(data['date'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════
// ગત વર્ષના પેપર્સ સ્ક્રીન
// ══════════════════════════════════════════════
class PreviousPapersScreen extends StatelessWidget {
  const PreviousPapersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF6A1B9A);
    return Scaffold(
      appBar: AppBar(
        title: const Text('ગત વર્ષના પેપર્સ'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('previous_papers')
            .orderBy('year', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.picture_as_pdf, size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('હજી કોઈ પેપર ઉપલબ્ધ નથી', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(14),
                  leading: CircleAvatar(
                    backgroundColor: primaryColor.withAlpha(25),
                    child: const Icon(Icons.picture_as_pdf, color: primaryColor),
                  ),
                  title: Text(data['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text('વર્ષ: ${data['year'] ?? ''} • ${data['role'] ?? ''}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  trailing: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onPressed: () async {
                      final url = data['pdfUrl'] ?? '';
                      if (url.isNotEmpty) {
                        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('ખોલો', style: TextStyle(fontSize: 12)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════
// ઓફલાઇન બુકમાર્ક સ્ક્રીન
// ══════════════════════════════════════════════
class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  List<Map<String, dynamic>> _bookmarks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('bookmarks') ?? [];
    setState(() {
      _bookmarks = raw.map((e) => Map<String, dynamic>.from(jsonDecode(e))).toList();
      _isLoading = false;
    });
  }

  Future<void> _removeBookmark(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('bookmarks') ?? [];
    raw.removeAt(index);
    await prefs.setStringList('bookmarks', raw);
    setState(() => _bookmarks.removeAt(index));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('બુકમાર્ક દૂર કર્યો')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF37474F);
    return Scaffold(
      appBar: AppBar(
        title: const Text('ઓફલાઇન બુકમાર્ક'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _bookmarks.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bookmark_border, size: 60, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('કોઈ સેવ કરેલો પ્રશ્ન નથી', style: TextStyle(color: Colors.grey, fontSize: 16)),
                      SizedBox(height: 8),
                      Text('ટેસ્ટ દરમ્યાન 🔖 icon થી સેવ કરો', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _bookmarks.length,
                  itemBuilder: (context, index) {
                    final item = _bookmarks[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.bookmark, color: Color(0xFF37474F), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(item['question'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                  onPressed: () => _removeBookmark(index),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...List.generate(
                              (item['options'] as List?)?.length ?? 0,
                              (i) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  children: [
                                    Icon(
                                      i == (item['correctIndex'] ?? -1) ? Icons.check_circle : Icons.radio_button_unchecked,
                                      size: 16,
                                      color: i == (item['correctIndex'] ?? -1) ? Colors.green : Colors.grey,
                                    ),
                                    const SizedBox(width: 6),
                                    Text((item['options'] as List)[i].toString(), style: TextStyle(fontSize: 13, color: i == (item['correctIndex'] ?? -1) ? Colors.green : Colors.black87)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// ══════════════════════════════════════════════
// Bookmark Save Helper
// ══════════════════════════════════════════════
Future<void> saveBookmark(CompleteQuestion question) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getStringList('bookmarks') ?? [];
  final item = jsonEncode(question.toMap());
  if (!raw.contains(item)) {
    raw.add(item);
    await prefs.setStringList('bookmarks', raw);
  }
}

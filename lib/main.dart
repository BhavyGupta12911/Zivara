// ============================================================
//  ZIVARA — Mental Wellness Flutter App
//  Paste into lib/main.dart and run.
//
//  pubspec.yaml:
//    google_fonts: ^6.2.1
//    hive_flutter: ^1.1.0
//    intl: ^0.19.0
//    audioplayers: ^5.2.1
//    image_picker: ^1.0.7
//    file_picker: ^8.0.0
//    record: ^5.0.4
//    just_audio: ^0.9.36
//    path_provider: ^2.1.2
// ============================================================

import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:zivara/twilio_service.dart';



// ─────────────────────────────────────────────
//  HIVE MODELS
// ─────────────────────────────────────────────

class JournalEntry extends HiveObject {
  late DateTime date;
  late String text;
  late int moodIndex;
  JournalEntry({
    required this.date,
    required this.text,
    required this.moodIndex,
  });
}

class JournalEntryAdapter extends TypeAdapter<JournalEntry> {
  @override
  final int typeId = 0;
  @override
  JournalEntry read(BinaryReader reader) => JournalEntry(
        date: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
        text: reader.readString(),
        moodIndex: reader.readInt(),
      );
  @override
  void write(BinaryWriter writer, JournalEntry obj) {
    writer.writeInt(obj.date.millisecondsSinceEpoch);
    writer.writeString(obj.text);
    writer.writeInt(obj.moodIndex);
  }
}

class AnchorContact extends HiveObject {
  late String name;
  late String phone;
  late String emoji;
  AnchorContact({required this.name, required this.phone, required this.emoji});
}

class AnchorContactAdapter extends TypeAdapter<AnchorContact> {
  @override
  final int typeId = 1;
  @override
  AnchorContact read(BinaryReader reader) => AnchorContact(
        name: reader.readString(),
        phone: reader.readString(),
        emoji: reader.readString(),
      );
  @override
  void write(BinaryWriter writer, AnchorContact obj) {
    writer.writeString(obj.name);
    writer.writeString(obj.phone);
    writer.writeString(obj.emoji);
  }
}

class AnchorMemory extends HiveObject {
  late String type;
  late String content;
  late String? subtitle;
  late int colorIndex;
  AnchorMemory({
    required this.type,
    required this.content,
    this.subtitle,
    required this.colorIndex,
  });
}

class AnchorMemoryAdapter extends TypeAdapter<AnchorMemory> {
  @override
  final int typeId = 2;
  @override
  AnchorMemory read(BinaryReader reader) => AnchorMemory(
        type: reader.readString(),
        content: reader.readString(),
        subtitle: reader.readString(),
        colorIndex: reader.readInt(),
      );
  @override
  void write(BinaryWriter writer, AnchorMemory obj) {
    writer.writeString(obj.type);
    writer.writeString(obj.content);
    writer.writeString(obj.subtitle ?? '');
    writer.writeInt(obj.colorIndex);
  }
}

// ─────────────────────────────────────────────
//  CONSTANTS
// ─────────────────────────────────────────────

const moodEmojis = ['😄', '🙂', '😐', '😔', '😢'];
const moodLabels = ['Joyful', 'Calm', 'Neutral', 'Sad', 'Anxious'];
const moodColors = [
  Color(0xFF7B5CF0),
  Color(0xFF9B7CF0),
  Color(0xFFB39DFA),
  Color(0xFF7C6FC4),
  Color(0xFF5B4FCC),
];

const breathingExercises = [
  {
    'name': '4-7-8 Calm',
    'in': 4,
    'hold': 7,
    'out': 8,
    'desc': 'For anxiety & sleep',
  },
  {
    'name': 'Box Breathing',
    'in': 4,
    'hold': 4,
    'out': 4,
    'desc': 'Focus & stress relief',
  },
  {
    'name': '4-4 Rhythm',
    'in': 4,
    'hold': 0,
    'out': 4,
    'desc': 'Gentle daily balance',
  },
  {
    'name': '5-5-5 Reset',
    'in': 5,
    'hold': 5,
    'out': 5,
    'desc': 'Nervous system reset',
  },
];

const crisisResources = [
  {
    'name': 'iCall',
    'number': '9152987821',
    'desc': 'Free counselling helpline',
  },
  {
    'name': 'Vandrevala',
    'number': '1860-2662-345',
    'desc': '24/7 mental health support',
  },
  {
    'name': 'NIMHANS',
    'number': '080-46110007',
    'desc': 'National mental health helpline',
  },
  {
    'name': 'Snehi',
    'number': '044-24640050',
    'desc': 'Emotional support helpline',
  },
];

const affirmations = [
  "You are stronger than you know.",
  "This moment will pass. You are safe.",
  "Your feelings are valid. You matter.",
  "You are not alone in this.",
  "One breath at a time. You've got this.",
  "You deserve care and compassion.",
  "Healing is not linear. Be patient with yourself.",
];

const groundingSteps = [
  {
    'num': '5',
    'sense': 'See',
    'icon': Icons.visibility,
    'prompt': 'Name 5 things you can SEE around you right now.',
  },
  {
    'num': '4',
    'sense': 'Touch',
    'icon': Icons.pan_tool,
    'prompt': 'Name 4 things you can TOUCH. Feel their texture.',
  },
  {
    'num': '3',
    'sense': 'Hear',
    'icon': Icons.hearing,
    'prompt': 'Name 3 things you can HEAR in this moment.',
  },
  {
    'num': '2',
    'sense': 'Smell',
    'icon': Icons.air,
    'prompt': 'Name 2 things you can SMELL nearby.',
  },
  {
    'num': '1',
    'sense': 'Taste',
    'icon': Icons.restaurant,
    'prompt': 'Name 1 thing you can TASTE right now.',
  },
];

String getGreeting(String name) {
  final h = DateTime.now().hour;
  if (h < 5) return 'Still up, $name?';
  if (h < 12) return 'Good Morning, $name';
  if (h < 17) return 'Good Afternoon, $name';
  if (h < 21) return 'Good Evening, $name';
  return 'Good Night, $name';
}

// ─────────────────────────────────────────────
//  THEME
// ─────────────────────────────────────────────

class ZT {
  static const bg = Color(0xFFF3F0FF);
  static const bgCard = Color(0xFFFFFFFF);
  static const surface = Color(0xFFEDE9FF);
  static const p1 = Color(0xFF7B5CF0);
  static const p2 = Color(0xFF9B7CF4);
  static const p3 = Color(0xFFB39DFA);
  static const pDark = Color(0xFF5B3FCC);
  static const pDeep = Color(0xFF4527A0);
  static const accent = Color(0xFFAB8BFF);
  static const textDark = Color(0xFF1A1033);
  static const textMid = Color(0xFF5A4A8A);
  static const textLight = Color(0xFF9E8FC0);
  static const border = Color(0xFFE0D8FF);

  static const grad = LinearGradient(
    colors: [p1, Color(0xFF9B59F5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const gradDeep = LinearGradient(
    colors: [pDeep, p1],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const gradSoft = LinearGradient(
    colors: [Color(0xFFEDE9FF), Color(0xFFDDD6FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get theme => ThemeData(
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.light(
          primary: p1,
          secondary: p2,
          surface: bgCard,
        ),
        textTheme: GoogleFonts.outfitTextTheme().apply(
          bodyColor: textMid,
          displayColor: textDark,
        ),
        useMaterial3: true,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      );
}

// ─────────────────────────────────────────────
//  MAIN
// ─────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  await Hive.initFlutter();
  Hive.registerAdapter(JournalEntryAdapter());
  Hive.registerAdapter(AnchorContactAdapter());
  Hive.registerAdapter(AnchorMemoryAdapter());
  await Hive.openBox<JournalEntry>('journal');
  await Hive.openBox<AnchorContact>('anchors');
  await Hive.openBox<AnchorMemory>('anchor_memories');
  await Hive.openBox('prefs');
  runApp(const ZivaraApp());
}

class ZivaraApp extends StatelessWidget {
  const ZivaraApp({super.key});
  @override
  Widget build(BuildContext context) {
    final prefs = Hive.box('prefs');
    final hasName = (prefs.get('name', defaultValue: '') as String).isNotEmpty;
    return MaterialApp(
      title: 'Zivara',
      debugShowCheckedModeBanner: false,
      theme: ZT.theme,
      home: hasName ? const MainShell() : const OnboardingScreen(),
    );
  }
}

// ─────────────────────────────────────────────
//  SHARED WIDGETS
// ─────────────────────────────────────────────

class ZCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final bool elevated;
  const ZCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: padding ?? const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: ZT.bgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ZT.border, width: 0.8),
            boxShadow: elevated
                ? [
                    BoxShadow(
                      color: ZT.p1.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: child,
        ),
      );
}

class GradButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool small;
  final IconData? icon;
  const GradButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.small = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: small ? 18 : 28,
            vertical: small ? 10 : 14,
          ),
          decoration: BoxDecoration(
            gradient: ZT.grad,
            borderRadius: BorderRadius.circular(50),
            boxShadow: [
              BoxShadow(
                color: ZT.p1.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: small ? 14 : 18),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: small ? 13 : 15,
                ),
              ),
            ],
          ),
        ),
      );
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          text.toUpperCase(),
          style: GoogleFonts.outfit(
            color: ZT.textLight,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
      );
}

// ─────────────────────────────────────────────
//  ONBOARDING
// ─────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = TextEditingController();
  int _step = 0;

  void _next() {
    if (_step == 0) {
      setState(() => _step = 1);
    } else {
      final name = _ctrl.text.trim();
      if (name.isEmpty) return;
      Hive.box('prefs').put('name', name);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: ZT.gradDeep),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: Image.asset('assets/images/logo.png',
                        width: 40, height: 40),
                  ),
                ),
                const SizedBox(height: 32),
                if (_step == 0) ...[
                  Text(
                    'Welcome to',
                    style: GoogleFonts.outfit(
                      color: Colors.white60,
                      fontSize: 20,
                    ),
                  ),
                  Text(
                    'Zivara',
                    style: GoogleFonts.playfairDisplay(
                      color: Colors.white,
                      fontSize: 52,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'A safe space for your mental wellness.\nYou are not alone.',
                    style: GoogleFonts.outfit(
                      color: Colors.white70,
                      fontSize: 17,
                      height: 1.7,
                    ),
                  ),
                  const SizedBox(height: 48),
                  GestureDetector(
                    onTap: _next,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Text(
                        'Get Started',
                        style: GoogleFonts.outfit(
                          color: ZT.p1,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Text(
                    "What's your name?",
                    style: GoogleFonts.playfairDisplay(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Just your first name — private & safe.',
                    style: GoogleFonts.outfit(
                      color: Colors.white60,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _ctrl,
                    autofocus: true,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                    cursorColor: Colors.white,
                    decoration: InputDecoration(
                      hintText: 'e.g. Anshika',
                      hintStyle: GoogleFonts.outfit(
                        color: Colors.white38,
                        fontSize: 18,
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                    ),
                    onSubmitted: (_) => _next(),
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: _next,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Text(
                        'Begin',
                        style: GoogleFonts.outfit(
                          color: ZT.p1,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  MAIN SHELL
// ─────────────────────────────────────────────

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  final _pages = const [
    HomeScreen(),
    JournalScreen(),
    ResourcesScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: ZT.bgCard,
          border: Border(top: BorderSide(color: ZT.border, width: 0.8)),
          boxShadow: [
            BoxShadow(
              color: ZT.p1.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  index: 0,
                  current: _tab,
                  onTap: (i) => setState(() => _tab = i),
                ),
                _NavItem(
                  icon: Icons.menu_book_rounded,
                  label: 'Journal',
                  index: 1,
                  current: _tab,
                  onTap: (i) => setState(() => _tab = i),
                ),
                _NavItem(
                  icon: Icons.self_improvement,
                  label: 'Resources',
                  index: 2,
                  current: _tab,
                  onTap: (i) => setState(() => _tab = i),
                ),
                _NavItem(
                  icon: Icons.person_rounded,
                  label: 'Profile',
                  index: 3,
                  current: _tab,
                  onTap: (i) => setState(() => _tab = i),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index, current;
  final void Function(int) onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = index == current;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: active ? ZT.p1.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: active ? ZT.p1 : ZT.textLight),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 10,
                color: active ? ZT.p1 : ZT.textLight,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  HOME SCREEN
// ─────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String get _name => Hive.box('prefs').get('name', defaultValue: 'Friend');
  final _affirmation = affirmations[Random().nextInt(affirmations.length)];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZT.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Image.asset('assets/images/logo.png',
                                width: 36, height: 36),
                            const SizedBox(width: 10),
                            Text(
                              'Zivara',
                              style: GoogleFonts.playfairDisplay(
                                color: ZT.p1,
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('h:mm a').format(DateTime.now()),
                          style: GoogleFonts.outfit(
                            color: ZT.textLight,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: ZT.bgCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: ZT.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.notifications_outlined,
                          color: ZT.p1,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: ZT.p1,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Greeting
              Text(
                getGreeting(_name),
                style: GoogleFonts.playfairDisplay(
                  color: ZT.textDark,
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _affirmation,
                style: GoogleFonts.outfit(
                  color: ZT.textMid,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 24),

              // Panic Mode Button
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PanicModeScreen())),
                child: Center(
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Color.fromARGB(255, 224, 153, 233),
                          Color.fromARGB(255, 171, 105, 212),
                          Color.fromARGB(255, 119, 86, 239),
                          Color(0xFF4A90D9),
                          Color.fromARGB(255, 48, 98, 186),
                        ],
                        center: Alignment(-0.3, -0.4),
                        radius: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                            color: Color(0xFF4A90D9).withValues(alpha: 0.5),
                            blurRadius: 35,
                            offset: Offset(0, 18)),
                        BoxShadow(
                            color: Color(0xFFB06FD8).withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: Offset(-6, -6)),
                        BoxShadow(
                            color: Colors.white24,
                            blurRadius: 6,
                            offset: Offset(-3, -3)),
                      ],
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.25),
                            Colors.transparent,
                            Color(0xFF3B6FCC).withValues(alpha: 0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.15),
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 1.5),
                              ),
                              child: const Icon(Icons.shield_rounded,
                                  color: Colors.white, size: 34),
                            ),
                            const SizedBox(height: 12),
                            Text('Crisis Mode',
                                style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5)),
                            const SizedBox(height: 4),
                            Text('I need support now',
                                style: GoogleFonts.outfit(
                                    color: Colors.white70, fontSize: 12)),
                          ]),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.favorite_border, color: ZT.textLight, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      "You're not alone. We're here to support you.",
                      style: GoogleFonts.outfit(
                        color: ZT.textLight,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // My Anchor
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyAnchorScreen()),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7B5CF0), Color(0xFF6B4FE0)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: ZT.p1.withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'My Anchor',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Connect with your loved ones',
                              style: GoogleFonts.outfit(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),
              Center(
                child: Text(
                  'A Safe Space for Memories.',
                  style: GoogleFonts.outfit(
                    color: ZT.textLight,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Quick Actions
              const SectionLabel('Quick Actions'),
              Row(
                children: [
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.air_rounded,
                      label: 'Breathe',
                      color: ZT.p1,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BreathingScreen(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.edit_note_rounded,
                      label: 'Journal',
                      color: ZT.p1,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const JournalEntryScreen(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.spa_rounded,
                      label: 'Ground',
                      color: ZT.p1,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const GroundingScreen(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.phone_in_talk_rounded,
                      label: 'Homies',
                      color: ZT.p1,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HelplineScreen(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Mood check-in
              ZCard(
                elevated: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.mood, color: ZT.p1, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'How are you feeling?',
                          style: GoogleFonts.outfit(
                            color: ZT.textDark,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(
                        5,
                        (i) => GestureDetector(
                          onTap: () {
                            Hive.box('prefs').put('lastMood', i);
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Feeling ${moodLabels[i]} — noted 💜',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                  ),
                                ),
                                backgroundColor: ZT.p1,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                          },
                          child: Column(
                            children: [
                              Text(
                                moodEmojis[i],
                                style: const TextStyle(fontSize: 28),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                moodLabels[i],
                                style: GoogleFonts.outfit(
                                  color: ZT.textLight,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: ZT.textMid,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
}

// ─────────────────────────────────────────────
//  PANIC MODE SCREEN
// ─────────────────────────────────────────────

class PanicModeScreen extends StatefulWidget {
  const PanicModeScreen({super.key});
  @override
  State<PanicModeScreen> createState() => _PanicModeScreenState();
}

class _PanicModeScreenState extends State<PanicModeScreen>
    with TickerProviderStateMixin {
  int _phase = 0;
  bool _sosSent = false;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  final _affirmation =
      _panicAffirmations[Random().nextInt(_panicAffirmations.length)];

  @override
  void initState() {
    super.initState();
    CalmAudio.start();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);
    _fadeCtrl.forward();
    _sendSOS();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
    CalmAudio.stop();
  }

  void _sendSOS() async {
    final prefs = Hive.box('prefs');
    final raw = prefs.get('homies');
    final List<Map<String, String>> contacts = raw == null
        ? []
        : (raw as List)
            .map((e) => Map<String, String>.from(
                (e as Map).map((k, v) => MapEntry(k.toString(), v.toString()))))
            .toList();

    if (contacts.isEmpty) {
      print('[SOS] No homies found — add contacts in the Homies screen first.');
      if (mounted) setState(() => _sosSent = true);
      return;
    }

    final message = prefs.get(
      'sosMessage',
      defaultValue: 'I need support right now. Please check on me. 💜',
    ) as String;

    print('[SOS] Sending to ${contacts.length} contact(s)...');
    for (final contact in contacts) {
      final number = contact['number'] ?? '';
      if (number.isNotEmpty) {
        print('[SOS] Sending to ${contact['name']} ($number)');
        final ok = await TwilioService.sendSMS(to: number, message: message);
        print('[SOS] Result for $number: ${ok ? "✅ sent" : "❌ failed"}');
      }
    }

    if (mounted) setState(() => _sosSent = true);
  }

  void _goToPhase(int phase) {
    _fadeCtrl.reverse().then((_) {
      if (!mounted) return;
      setState(() => _phase = phase);
      _fadeCtrl.forward();
    });
  }

  Widget _buildPhase() {
    switch (_phase) {
      case 0:
        return _AffirmationPhase(
          affirmation: _affirmation,
          sosSent: _sosSent,
          onNext: () => _goToPhase(1),
        );
      case 1:
        return _PanicBreathingPhase(onNext: () => _goToPhase(2));
      case 2:
        return DistractionPhase(onDone: () => Navigator.pop(context));
      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2D1B69), Color(0xFF5B3FCC), Color(0xFF7B5CF0)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Stack(children: [
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white70, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _PhaseDot(active: _phase == 0, done: _phase > 0, label: '💜'),
                _PhaseLine(done: _phase > 0),
                _PhaseDot(active: _phase == 1, done: _phase > 1, label: '🫁'),
                _PhaseLine(done: _phase > 1),
                _PhaseDot(active: _phase == 2, done: false, label: '🎈'),
              ]),
            ),
            Positioned.fill(
              top: 60,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: _buildPhase(),
              ),
            ),
            Positioned(
              bottom: 24,
              right: 20,
              child: GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const MyAnchorScreen())),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.favorite_rounded,
                        color: Color(0xFF7B5CF0), size: 18),
                    const SizedBox(width: 6),
                    Text('My Anchor',
                        style: GoogleFonts.outfit(
                            color: const Color(0xFF7B5CF0),
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                  ]),
                ),
              ),
            ),
            if (_sosSent)
              Positioned(
                top: 52,
                left: 20,
                right: 20,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.check_circle_outline,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text('SOS sent to your homies💜',
                            style: GoogleFonts.outfit(
                                color: Colors.white, fontSize: 12))),
                  ]),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class _PhaseDot extends StatelessWidget {
  final bool active, done;
  final String label;
  const _PhaseDot(
      {required this.active, required this.done, required this.label});
  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: active ? 36 : 28,
        height: active ? 36 : 28,
        decoration: BoxDecoration(
          color: done
              ? Colors.white
              : (active ? Colors.white : Colors.white.withValues(alpha: 0.2)),
          shape: BoxShape.circle,
          border: Border.all(
              color: Colors.white.withValues(alpha: active ? 1 : 0.4),
              width: 1.5),
        ),
        child: Center(
            child: Text(label, style: TextStyle(fontSize: active ? 16 : 13))),
      );
}

class _PhaseLine extends StatelessWidget {
  final bool done;
  const _PhaseLine({required this.done});
  @override
  Widget build(BuildContext context) => Container(
        width: 32,
        height: 2,
        color: done ? Colors.white : Colors.white.withValues(alpha: 0.25),
      );
}

// ─────────────────────────────────────────────
//  PHASE 1 — AFFIRMATION
// ─────────────────────────────────────────────

const _panicAffirmations = [
  "You are safe right now.\nThis feeling will pass.",
  "You have survived every hard moment before.\nYou will survive this too.",
  "You are not alone.\nHelp is right here with you.",
  "Your breath is your anchor.\nYou are grounded and safe.",
  "This is temporary.\nYou are stronger than this moment.",
  "You matter.\nYour peace matters.\nYou are worthy of calm.",
  "Take it one breath at a time.\nYou do not have to face this alone.",
];

class _AffirmationPhase extends StatefulWidget {
  final String affirmation;
  final bool sosSent;
  final VoidCallback onNext;
  const _AffirmationPhase(
      {required this.affirmation, required this.sosSent, required this.onNext});
  @override
  State<_AffirmationPhase> createState() => _AffirmationPhaseState();
}

class _AffirmationPhaseState extends State<_AffirmationPhase>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 100),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => Transform.scale(
              scale: 1.0 + _pulseCtrl.value * 0.12,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white
                      .withValues(alpha: 0.15 + _pulseCtrl.value * 0.05),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.favorite_rounded,
                    color: Colors.white, size: 48),
              ),
            ),
          ),
          const SizedBox(height: 36),
          Text('You are safe',
              style: GoogleFonts.outfit(
                  color: Colors.white60, fontSize: 14, letterSpacing: 1.5)),
          const SizedBox(height: 16),
          Text(
            widget.affirmation,
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
                color: Colors.white,
                fontSize: 24,
                height: 1.6,
                fontWeight: FontWeight.w400,
                fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 48),
          Text('Take a slow breath. Read this again.',
              style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: widget.onNext,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(50),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text("I'm ready to breathe",
                    style: GoogleFonts.outfit(
                        color: const Color(0xFF7B5CF0),
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded,
                    color: Color(0xFF7B5CF0), size: 18),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  PHASE 2 — BREATHING (panic-mode inline)
// ─────────────────────────────────────────────

class _PanicBreathingPhase extends StatefulWidget {
  final VoidCallback onNext;
  const _PanicBreathingPhase({required this.onNext});
  @override
  State<_PanicBreathingPhase> createState() => _PanicBreathingPhaseState();
}

class _PanicBreathingPhaseState extends State<_PanicBreathingPhase>
    with SingleTickerProviderStateMixin {
  late AnimationController _breathCtrl;
  late Animation<double> _breathAnim;
  int _countdown = 4;
  int _phaseIdx = 0;
  int _cycles = 0;
  bool _running = false;
  Timer? _timer;

  final _durations = [4, 4, 4];
  final _phases = ['Inhale', 'Hold', 'Exhale'];
  final _tips = ['Breathe in slowly...', 'Hold gently...', 'Release slowly...'];

  @override
  void initState() {
    super.initState();
    _breathCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _breathAnim = Tween<double>(begin: 0.55, end: 1.0)
        .animate(CurvedAnimation(parent: _breathCtrl, curve: Curves.easeInOut));
    Future.delayed(const Duration(milliseconds: 600), _start);
  }

  void _start() {
    if (!mounted) return;
    setState(() {
      _running = true;
      _phaseIdx = 0;
      _countdown = 4;
    });
    _breathCtrl.forward(from: 0);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_countdown > 1) {
          _countdown--;
        } else {
          _phaseIdx = (_phaseIdx + 1) % 3;
          if (_phaseIdx == 0) {
            _cycles++;
            _breathCtrl.forward(from: 0);
          } else if (_phaseIdx == 2) {
            _breathCtrl.reverse(from: 1);
          }
          _countdown = _durations[_phaseIdx];
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _breathCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('Box Breathing',
            style: GoogleFonts.outfit(
                color: Colors.white60, fontSize: 13, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        if (_cycles > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12)),
            child: Text('Cycle $_cycles of 3',
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 12)),
          ),
        const SizedBox(height: 24),
        AnimatedBuilder(
          animation: _breathAnim,
          builder: (_, __) {
            final s = _running ? _breathAnim.value : 0.65;
            return Container(
              width: 200 * s + 40,
              height: 200 * s + 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12 + s * 0.08),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4 + s * 0.2),
                    width: 2),
              ),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_running ? _phases[_phaseIdx] : 'Starting...',
                        style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text('$_countdown',
                        style: GoogleFonts.playfairDisplay(
                            color: Colors.white,
                            fontSize: 52,
                            fontWeight: FontWeight.w300)),
                  ]),
            );
          },
        ),
        const SizedBox(height: 24),
        Text(_running ? _tips[_phaseIdx] : '...',
            style: GoogleFonts.outfit(color: Colors.white60, fontSize: 14)),
        const SizedBox(height: 40),
        if (_cycles >= 3)
          GestureDetector(
            onTap: widget.onNext,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(50)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('Great! Play a distraction game',
                    style: GoogleFonts.outfit(
                        color: const Color(0xFF7B5CF0),
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
                const SizedBox(width: 6),
                const Icon(Icons.games_rounded,
                    color: Color(0xFF7B5CF0), size: 18),
              ]),
            ),
          )
        else
          Column(children: [
            Text('Complete 3 cycles to continue',
                style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 10),
            Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  3,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: i < _cycles ? 24 : 12,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i < _cycles
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                )),
          ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
//  MY ANCHOR SCREEN
// ─────────────────────────────────────────────

const _anchorPastels = [
  Color(0xFFFFF59D),
  Color(0xFFFFCDD2),
  Color(0xFFB3E5FC),
  Color(0xFFDCEDC8),
  Color(0xFFF8BBD0),
];

class MyAnchorScreen extends StatefulWidget {
  const MyAnchorScreen({super.key});
  @override
  State<MyAnchorScreen> createState() => _MyAnchorScreenState();
}

class _MyAnchorScreenState extends State<MyAnchorScreen> {
  Box<AnchorMemory> get _memBox => Hive.box<AnchorMemory>('anchor_memories');
  final _picker = ImagePicker();

  void _seedDefaults() {
    if (_memBox.isNotEmpty) return;
    final seeds = [
      AnchorMemory(
        type: 'quote',
        content:
            '"The best things in life are the people we love, the places we\'ve been, and the memories we\'ve made along the way."',
        subtitle: '— Unknown',
        colorIndex: 0,
      ),
      AnchorMemory(
        type: 'note',
        content: 'Coffee dates with Sarah ☕\nEvery Sunday morning at our favorite spot',
        colorIndex: 1,
      ),
      AnchorMemory(
        type: 'note',
        content: 'Remember to cherish every moment ✨',
        colorIndex: 1,
      ),
      AnchorMemory(
        type: 'note',
        content: 'First day at new job! 🎉\nFeeling nervous but excited',
        colorIndex: 1,
      ),
      AnchorMemory(
        type: 'quote',
        content:
            '"Life is not measured by the number of breaths we take, but by the moments that take our breath away."',
        subtitle: '— Maya Angelou',
        colorIndex: 0,
      ),
      AnchorMemory(
        type: 'quote',
        content: '"In the end, we only regret the chances we didn\'t take."',
        subtitle: '— Lewis Carroll',
        colorIndex: 0,
      ),
    ];
    for (final s in seeds) {
      _memBox.add(s);
    }
  }

  @override
  void initState() {
    super.initState();
    _seedDefaults();
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: ZT.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ZT.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Add to My Anchor',
              style: GoogleFonts.playfairDisplay(
                color: ZT.textDark,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: ZT.grad,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.photo_library_rounded,
                    color: Colors.white, size: 22),
              ),
              title: Text('Choose from Gallery',
                  style: GoogleFonts.outfit(
                      color: ZT.textDark, fontWeight: FontWeight.w600)),
              subtitle: Text('Pick a photo you love',
                  style: GoogleFonts.outfit(color: ZT.textLight, fontSize: 12)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ZT.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    const Icon(Icons.camera_alt_rounded, color: ZT.p1, size: 22),
              ),
              title: Text('Take a Photo',
                  style: GoogleFonts.outfit(
                      color: ZT.textDark, fontWeight: FontWeight.w600)),
              subtitle: Text('Capture a new memory',
                  style: GoogleFonts.outfit(color: ZT.textLight, fontSize: 12)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9C4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.sticky_note_2_rounded,
                    color: Color(0xFFE6AC00), size: 22),
              ),
              title: Text('Add a Note',
                  style: GoogleFonts.outfit(
                      color: ZT.textDark, fontWeight: FontWeight.w600)),
              subtitle: Text('Write a memory or thought',
                  style: GoogleFonts.outfit(color: ZT.textLight, fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _showAddNoteSheet();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (source == null) return;

    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: 80,
    );
    if (image == null) return;

    final appDir = await getApplicationDocumentsDirectory();
    final fileName = 'anchor_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final savedPath = '${appDir.path}/$fileName';
    await File(image.path).copy(savedPath);

    _memBox.add(AnchorMemory(
      type: 'photo',
      content: savedPath,
      colorIndex: 0,
    ));
    setState(() {});
  }

  void _showAddNoteSheet() {
    final textCtrl = TextEditingController();
    final subtitleCtrl = TextEditingController();
    int selectedColor = 1;
    bool isQuote = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: ZT.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: StatefulBuilder(
          builder: (ctx, setS) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ZT.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Add a Memory',
                style: GoogleFonts.playfairDisplay(
                  color: ZT.textDark,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: List.generate(
                  _anchorPastels.length,
                  (i) => GestureDetector(
                    onTap: () => setS(() => selectedColor = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 32,
                      height: 32,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: _anchorPastels[i],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selectedColor == i
                              ? ZT.p1
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => setS(() => isQuote = false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: !isQuote ? ZT.p1 : ZT.surface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Note',
                        style: GoogleFonts.outfit(
                          color: !isQuote ? Colors.white : ZT.textMid,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setS(() => isQuote = true),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isQuote ? ZT.p1 : ZT.surface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Quote',
                        style: GoogleFonts.outfit(
                          color: isQuote ? Colors.white : ZT.textMid,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: textCtrl,
                maxLines: 3,
                style: GoogleFonts.outfit(color: ZT.textDark, fontSize: 15),
                decoration: InputDecoration(
                  hintText: isQuote
                      ? '"Your favorite quote..."'
                      : 'Write a memory or thought...',
                  hintStyle: GoogleFonts.outfit(color: ZT.textLight),
                  filled: true,
                  fillColor: ZT.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: ZT.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: ZT.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: ZT.p1, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
              ),
              if (isQuote) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: subtitleCtrl,
                  style: GoogleFonts.outfit(color: ZT.textDark, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: '— Author (optional)',
                    hintStyle: GoogleFonts.outfit(color: ZT.textLight),
                    filled: true,
                    fillColor: ZT.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: ZT.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: ZT.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: ZT.p1, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: GradButton(
                  label: 'Save Memory',
                  onPressed: () {
                    final text = textCtrl.text.trim();
                    if (text.isEmpty) return;
                    _memBox.add(AnchorMemory(
                      type: isQuote ? 'quote' : 'note',
                      content: text,
                      subtitle: subtitleCtrl.text.trim().isNotEmpty
                          ? subtitleCtrl.text.trim()
                          : null,
                      colorIndex: selectedColor,
                    ));
                    setState(() {});
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _deleteMemory(int index) {
    _memBox.deleteAt(index);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final memories = _memBox.values.toList();
    final leftCol = <AnchorMemory>[];
    final rightCol = <AnchorMemory>[];
    final leftIdx = <int>[];
    final rightIdx = <int>[];
    for (int i = 0; i < memories.length; i++) {
      if (i % 2 == 0) {
        leftCol.add(memories[i]);
        leftIdx.add(i);
      } else {
        rightCol.add(memories[i]);
        rightIdx.add(i);
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F7),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 140,
                pinned: true,
                backgroundColor: const Color(0xFF7B6FD6),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF7B6FD6), Color(0xFF9B8FF0)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'My Anchor ',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Text('💙',
                                    style: TextStyle(fontSize: 24)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your treasured moments',
                              style: GoogleFonts.outfit(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 100),
                sliver: SliverToBoxAdapter(
                  child: memories.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 80),
                            child: Column(
                              children: [
                                const Text('🌸',
                                    style: TextStyle(fontSize: 48)),
                                const SizedBox(height: 12),
                                Text(
                                  'Start adding your treasured\nmoments here!',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    color: ZT.textLight,
                                    fontSize: 15,
                                    height: 1.7,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                children: List.generate(leftCol.length, (i) {
                                  return _MemoryTile(
                                    memory: leftCol[i],
                                    onDelete: () =>
                                        _deleteMemory(leftIdx[i]),
                                  );
                                }),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                children: List.generate(rightCol.length, (i) {
                                  return _MemoryTile(
                                    memory: rightCol[i],
                                    onDelete: () =>
                                        _deleteMemory(rightIdx[i]),
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 28,
            right: 24,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: ZT.grad,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: ZT.p1.withValues(alpha: 0.45),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.add_rounded,
                    color: Colors.white, size: 32),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoryTile extends StatelessWidget {
  final AnchorMemory memory;
  final VoidCallback onDelete;
  const _MemoryTile({required this.memory, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _confirmDelete(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: memory.type == 'photo'
              ? Colors.transparent
              : _anchorPastels[memory.colorIndex.clamp(0, _anchorPastels.length - 1)],
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: memory.type == 'photo'
            ? _buildPhoto()
            : memory.type == 'quote'
                ? _buildQuote()
                : _buildNote(),
      ),
    );
  }

  Widget _buildPhoto() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.file(
        File(memory.content),
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, __, ___) => Container(
          height: 120,
          color: ZT.surface,
          child: const Center(
            child: Icon(Icons.broken_image_rounded,
                color: ZT.textLight, size: 36),
          ),
        ),
      ),
    );
  }

  Widget _buildQuote() {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            memory.content,
            style: GoogleFonts.playfairDisplay(
              color: const Color(0xFF4A3800),
              fontSize: 13,
              fontStyle: FontStyle.italic,
              height: 1.6,
            ),
          ),
          if (memory.subtitle != null && memory.subtitle!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                memory.subtitle!,
                style: GoogleFonts.outfit(
                  color: const Color(0xFF7A6000),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNote() {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Text(
        memory.content,
        style: GoogleFonts.outfit(
          color: const Color(0xFF4A1A2A),
          fontSize: 13.5,
          height: 1.55,
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ZT.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ZT.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Remove this memory?',
              style: GoogleFonts.outfit(
                color: ZT.textDark,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This cannot be undone.',
              style:
                  GoogleFonts.outfit(color: ZT.textLight, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: ZT.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.outfit(
                                color: ZT.textMid,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        onDelete();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            'Remove',
                            style: GoogleFonts.outfit(
                                color: Colors.red,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  GROUNDING SCREEN (5-4-3-2-1)
// ─────────────────────────────────────────────

class GroundingScreen extends StatefulWidget {
  const GroundingScreen({super.key});
  @override
  State<GroundingScreen> createState() => _GroundingScreenState();
}

class _GroundingScreenState extends State<GroundingScreen> {
  int _step = 0;

  @override
  Widget build(BuildContext context) {
    final s = groundingSteps[_step];
    return Scaffold(
      backgroundColor: ZT.bg,
      appBar: AppBar(
        backgroundColor: ZT.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: ZT.textMid,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '5-4-3-2-1 Grounding',
          style: GoogleFonts.outfit(color: ZT.textDark, fontSize: 16),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: i == _step ? 32 : 10,
                  height: 10,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    gradient: i <= _step ? ZT.grad : null,
                    color: i <= _step ? null : ZT.border,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 48),
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: ZT.grad,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: ZT.p1.withValues(alpha: 0.3),
                    blurRadius: 30,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    s['num'] as String,
                    style: GoogleFonts.playfairDisplay(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    s['sense'] as String,
                    style: GoogleFonts.outfit(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Text(
              s['prompt'] as String,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: ZT.textDark,
                fontSize: 18,
                height: 1.7,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_step > 0)
                  GestureDetector(
                    onTap: () => setState(() => _step--),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: ZT.surface,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: ZT.border),
                      ),
                      child: Text(
                        'Back',
                        style: GoogleFonts.outfit(
                          color: ZT.textMid,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                if (_step > 0) const SizedBox(width: 12),
                GradButton(
                  label: _step < 4 ? 'Next →' : 'Done ✓',
                  onPressed: () {
                    if (_step < 4)
                      setState(() => _step++);
                    else
                      Navigator.pop(context);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  BREATHING SCREEN
// ─────────────────────────────────────────────

class BreathingScreen extends StatefulWidget {
  final Map<String, dynamic>? exercise;
  const BreathingScreen({super.key, this.exercise});
  @override
  State<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends State<BreathingScreen>
    with TickerProviderStateMixin {
  late int _inDur, _holdDur, _outDur;
  late String _exName;
  int _phaseIdx = 0, _countdown = 4, _cycles = 0;
  bool _running = false;
  Timer? _timer;
  late AnimationController _scaleCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    final ex = widget.exercise ?? breathingExercises[1];
    _inDur = ex['in'] as int;
    _holdDur = ex['hold'] as int;
    _outDur = ex['out'] as int;
    _exName = ex['name'] as String;
    _countdown = _inDur;
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: Duration(seconds: _inDur),
    );
    _scaleAnim = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeInOut));
  }

  List<int> get _durations {
    final d = [_inDur];
    if (_holdDur > 0) d.add(_holdDur);
    d.add(_outDur);
    return d;
  }

  List<String> get _phases {
    final p = ['Inhale'];
    if (_holdDur > 0) p.add('Hold');
    p.add('Exhale');
    return p;
  }

  void _start() {
    setState(() {
      _running = true;
      _phaseIdx = 0;
      _cycles = 0;
      _countdown = _durations[0];
    });
    _scaleCtrl.forward(from: 0);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        if (_countdown > 1) {
          _countdown--;
        } else {
          _phaseIdx = (_phaseIdx + 1) % _durations.length;
          if (_phaseIdx == 0) {
            _cycles++;
            _scaleCtrl.forward(from: 0);
          } else if (_phaseIdx == _durations.length - 1)
            _scaleCtrl.reverse(from: 1);
          _countdown = _durations[_phaseIdx];
        }
      });
    });
  }

  void _stop() {
    _timer?.cancel();
    _scaleCtrl.stop();
    setState(() {
      _running = false;
      _cycles = 0;
      _phaseIdx = 0;
      _countdown = _inDur;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phase = _running ? _phases[_phaseIdx] : 'Ready';
    return Scaffold(
      backgroundColor: ZT.bg,
      appBar: AppBar(
        backgroundColor: ZT.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: ZT.textMid,
            size: 18,
          ),
          onPressed: () {
            _stop();
            Navigator.pop(context);
          },
        ),
        title: Text(
          _exName,
          style: GoogleFonts.outfit(color: ZT.textDark, fontSize: 16),
        ),
      ),
      body: Column(
        children: [
          if (_running && _cycles > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: ZT.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Cycle $_cycles',
                  style: GoogleFonts.outfit(color: ZT.p1, fontSize: 13),
                ),
              ),
            ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _scaleAnim,
                    builder: (_, __) {
                      final scale = _running ? _scaleAnim.value : 0.65;
                      return Container(
                        width: 200 * scale + 60,
                        height: 200 * scale + 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              ZT.p1.withValues(alpha: _running ? 0.8 : 0.3),
                              ZT.p2.withValues(alpha: _running ? 0.6 : 0.2),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: _running
                              ? [
                                  BoxShadow(
                                    color: ZT.p1.withValues(alpha: 0.3),
                                    blurRadius: 40,
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              phase,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$_countdown',
                              style: GoogleFonts.playfairDisplay(
                                color: Colors.white,
                                fontSize: 54,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                  Text(
                    _running
                        ? 'Breathe with the circle...'
                        : 'Sit comfortably and tap Begin',
                    style: GoogleFonts.outfit(
                      color: ZT.textLight,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 32),
                  GradButton(
                    label: _running ? 'Stop' : 'Begin',
                    onPressed: _running ? _stop : _start,
                  ),
                  const SizedBox(height: 48),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Other exercises',
                          style: GoogleFonts.outfit(
                            color: ZT.textLight,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...breathingExercises
                            .where((e) => e['name'] != _exName)
                            .map(
                              (e) => GestureDetector(
                                onTap: () => Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        BreathingScreen(exercise: e),
                                  ),
                                ),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: ZT.bgCard,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: ZT.border),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        e['name'] as String,
                                        style: GoogleFonts.outfit(
                                          color: ZT.textDark,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        e['desc'] as String,
                                        style: GoogleFonts.outfit(
                                          color: ZT.textLight,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
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
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  HELPLINE SCREEN
// ─────────────────────────────────────────────

// ─────────────────────────────────────────────
//  HOMIES (HELPLINE) SCREEN — editable contacts
// ─────────────────────────────────────────────

class HelplineScreen extends StatefulWidget {
  const HelplineScreen({super.key});
  @override
  State<HelplineScreen> createState() => _HelplineScreenState();
}

class _HelplineScreenState extends State<HelplineScreen> {
  // Hive box key for custom homies
  static const _boxKey = 'homies';

  // Seed default numbers on first launch
  List<Map<String, String>> _loadHomies() {
    final box = Hive.box('prefs');
    final raw = box.get(_boxKey);
    if (raw == null) {
      // First launch — seed defaults from crisisResources
      final defaults = crisisResources
          .map((r) => {
                'name': r['name']!,
                'number': r['number']!,
                'desc': r['desc']!,
              })
          .toList();
      box.put(_boxKey, defaults.map((m) => Map<String, dynamic>.from(m)).toList());
      return defaults;
    }
    return (raw as List)
        .map((e) => Map<String, String>.from(
            (e as Map).map((k, v) => MapEntry(k.toString(), v.toString()))))
        .toList();
  }

  void _saveHomies(List<Map<String, String>> list) {
    Hive.box('prefs').put(
      _boxKey,
      list.map((m) => Map<String, dynamic>.from(m)).toList(),
    );
  }

  void _showAddSheet({Map<String, String>? existing, int? editIndex}) {
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final numCtrl  = TextEditingController(text: existing?['number'] ?? '');
    final descCtrl = TextEditingController(text: existing?['desc'] ?? '');

    showModalBottomSheet(
      context: context,
      backgroundColor: ZT.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          top: 20, left: 20, right: 20,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: ZT.border, borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            editIndex == null ? 'Add Homie' : 'Edit Homie',
            style: GoogleFonts.playfairDisplay(
                color: ZT.textDark, fontSize: 22),
          ),
          const SizedBox(height: 16),
          _HomieField(ctrl: nameCtrl, hint: 'Name (e.g. iCall)'),
          const SizedBox(height: 10),
          _HomieField(ctrl: numCtrl, hint: 'Phone number', keyboardType: TextInputType.phone),
          const SizedBox(height: 10),
          _HomieField(ctrl: descCtrl, hint: 'Short description (optional)'),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: GradButton(
              label: editIndex == null ? 'Add' : 'Save',
              onPressed: () {
                final name = nameCtrl.text.trim();
                final num  = numCtrl.text.trim();
                if (name.isEmpty || num.isEmpty) return;
                final list = _loadHomies();
                final entry = {'name': name, 'number': num, 'desc': descCtrl.text.trim()};
                if (editIndex == null) {
                  list.add(entry);
                } else {
                  list[editIndex] = entry;
                }
                _saveHomies(list);
                setState(() {});
                Navigator.pop(context);
              },
            ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _delete(int index) async {
    bool confirm = false;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ZT.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Remove Homie?',
            style: GoogleFonts.outfit(
                color: ZT.textDark, fontWeight: FontWeight.w600)),
        content: Text('This contact will be removed from your list.',
            style: GoogleFonts.outfit(color: ZT.textMid)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.outfit(color: ZT.textMid)),
          ),
          TextButton(
            onPressed: () { confirm = true; Navigator.pop(ctx); },
            child: Text('Remove',
                style: GoogleFonts.outfit(
                    color: Colors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm) {
      final list = _loadHomies();
      list.removeAt(index);
      _saveHomies(list);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final homies = _loadHomies();

    return Scaffold(
      backgroundColor: ZT.bg,
      appBar: AppBar(
        backgroundColor: ZT.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: ZT.textMid, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Homies',
            style: GoogleFonts.outfit(color: ZT.textDark, fontSize: 16)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GradButton(
              label: '+ Add',
              small: true,
              onPressed: () => _showAddSheet(),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('Available Now'),
            Expanded(
              child: homies.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('📞', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 12),
                          Text('No homies yet.\nTap "+ Add" to add one.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                  color: ZT.textLight,
                                  fontSize: 15,
                                  height: 1.7)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: homies.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final r = homies[i];
                        return GestureDetector(
                          onLongPress: () => _showEditOptions(i, r),
                          child: ZCard(
                            elevated: true,
                            child: Row(children: [
                              Container(
                                width: 48, height: 48,
                                decoration: BoxDecoration(
                                    color: ZT.p1.withValues(alpha: 0.1),
                                    borderRadius:
                                        BorderRadius.circular(14)),
                                child: const Icon(
                                    Icons.support_agent_rounded,
                                    color: ZT.p1,
                                    size: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(r['name']!,
                                      style: GoogleFonts.outfit(
                                          color: ZT.textDark,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14)),
                                  Text(r['number']!,
                                      style: GoogleFonts.outfit(
                                          color: ZT.p1,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500)),
                                  if ((r['desc'] ?? '').isNotEmpty)
                                    Text(r['desc']!,
                                        style: GoogleFonts.outfit(
                                            color: ZT.textLight,
                                            fontSize: 11)),
                                ]),
                              ),
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                // Edit button
                                GestureDetector(
                                  onTap: () => _showAddSheet(
                                      existing: r, editIndex: i),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                        color: ZT.surface,
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    child: const Icon(
                                        Icons.edit_rounded,
                                        color: ZT.p1,
                                        size: 16),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Call button
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                      gradient: ZT.grad,
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.phone_rounded,
                                      color: Colors.white, size: 18),
                                ),
                              ]),
                            ]),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditOptions(int i, Map<String, String> r) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ZT.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: ZT.border,
                borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(height: 16),
          Text(r['name']!,
              style: GoogleFonts.outfit(
                  color: ZT.textDark,
                  fontWeight: FontWeight.w600,
                  fontSize: 16)),
          const SizedBox(height: 8),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: ZT.surface,
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.edit_rounded, color: ZT.p1, size: 20),
            ),
            title: Text('Edit',
                style: GoogleFonts.outfit(
                    color: ZT.textDark, fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(context);
              _showAddSheet(existing: r, editIndex: i);
            },
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.delete_outline_rounded,
                  color: Colors.red.shade400, size: 20),
            ),
            title: Text('Remove',
                style: GoogleFonts.outfit(
                    color: Colors.red, fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(context);
              _delete(i);
            },
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}

class _HomieField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final TextInputType? keyboardType;
  const _HomieField(
      {required this.ctrl, required this.hint, this.keyboardType});

  @override
  Widget build(BuildContext context) => TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: GoogleFonts.outfit(color: ZT.textDark, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.outfit(color: ZT.textLight),
          filled: true,
          fillColor: ZT.surface,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: ZT.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: ZT.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: ZT.p1, width: 1.5)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      );
}

// ─────────────────────────────────────────────
//  CRISIS SUPPORT SCREEN — separate from Homies
// ─────────────────────────────────────────────

class CrisisSupportScreen extends StatefulWidget {
  const CrisisSupportScreen({super.key});
  @override
  State<CrisisSupportScreen> createState() => _CrisisSupportScreenState();
}

class _CrisisSupportScreenState extends State<CrisisSupportScreen> {
  static const _boxKey = 'crisis_contacts';

  List<Map<String, String>> _loadContacts() {
    final box = Hive.box('prefs');
    final raw = box.get(_boxKey);
    if (raw == null) {
      final defaults = crisisResources
          .map((r) => {
                'name': r['name']!,
                'number': r['number']!,
                'desc': r['desc']!,
              })
          .toList();
      box.put(_boxKey,
          defaults.map((m) => Map<String, dynamic>.from(m)).toList());
      return defaults;
    }
    return (raw as List)
        .map((e) => Map<String, String>.from(
            (e as Map).map((k, v) => MapEntry(k.toString(), v.toString()))))
        .toList();
  }

  void _saveContacts(List<Map<String, String>> list) {
    Hive.box('prefs').put(
      _boxKey,
      list.map((m) => Map<String, dynamic>.from(m)).toList(),
    );
  }

  void _showManageSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: ZT.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) {
          final contacts = _loadContacts();
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 20, left: 20, right: 20,
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: ZT.border,
                      borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Manage Crisis Contacts',
                      style: GoogleFonts.playfairDisplay(
                          color: ZT.textDark, fontSize: 20)),
                  GradButton(
                    label: '+ Add',
                    small: true,
                    onPressed: () {
                      Navigator.pop(context);
                      _showAddSheet();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (contacts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text('No contacts yet. Tap "+ Add" to add one.',
                      style:
                          GoogleFonts.outfit(color: ZT.textLight, fontSize: 14)),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.45,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: contacts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final r = contacts[i];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: ZT.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: ZT.border),
                        ),
                        child: Row(children: [
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(r['name']!,
                                  style: GoogleFonts.outfit(
                                      color: ZT.textDark,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14)),
                              Text(r['number']!,
                                  style: GoogleFonts.outfit(
                                      color: ZT.p1,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500)),
                              if ((r['desc'] ?? '').isNotEmpty)
                                Text(r['desc']!,
                                    style: GoogleFonts.outfit(
                                        color: ZT.textLight, fontSize: 11)),
                            ]),
                          ),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                                _showAddSheet(existing: r, editIndex: i);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                    color: ZT.p1.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.edit_rounded,
                                    color: ZT.p1, size: 16),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () async {
                                Navigator.pop(context);
                                await _delete(i);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(10)),
                                child: Icon(Icons.delete_outline_rounded,
                                    color: Colors.red.shade400, size: 16),
                              ),
                            ),
                          ]),
                        ]),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
            ]),
          );
        },
      ),
    ).then((_) => setState(() {}));
  }

  void _showAddSheet({Map<String, String>? existing, int? editIndex}) {
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final numCtrl = TextEditingController(text: existing?['number'] ?? '');
    final descCtrl = TextEditingController(text: existing?['desc'] ?? '');

    showModalBottomSheet(
      context: context,
      backgroundColor: ZT.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          top: 20, left: 20, right: 20,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: ZT.border, borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            editIndex == null ? 'Add Contact' : 'Edit Contact',
            style: GoogleFonts.playfairDisplay(color: ZT.textDark, fontSize: 22),
          ),
          const SizedBox(height: 16),
          _HomieField(ctrl: nameCtrl, hint: 'Name (e.g. iCall)'),
          const SizedBox(height: 10),
          _HomieField(ctrl: numCtrl, hint: 'Phone number', keyboardType: TextInputType.phone),
          const SizedBox(height: 10),
          _HomieField(ctrl: descCtrl, hint: 'Short description (optional)'),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: GradButton(
              label: editIndex == null ? 'Add' : 'Save',
              onPressed: () {
                final name = nameCtrl.text.trim();
                final num = numCtrl.text.trim();
                if (name.isEmpty || num.isEmpty) return;
                final list = _loadContacts();
                final entry = {'name': name, 'number': num, 'desc': descCtrl.text.trim()};
                if (editIndex == null) {
                  list.add(entry);
                } else {
                  list[editIndex] = entry;
                }
                _saveContacts(list);
                setState(() {});
                Navigator.pop(context);
              },
            ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _delete(int index) async {
    bool confirm = false;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ZT.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Remove Contact?',
            style: GoogleFonts.outfit(
                color: ZT.textDark, fontWeight: FontWeight.w600)),
        content: Text('This contact will be permanently removed.',
            style: GoogleFonts.outfit(color: ZT.textMid)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.outfit(color: ZT.textMid)),
          ),
          TextButton(
            onPressed: () { confirm = true; Navigator.pop(ctx); },
            child: Text('Remove',
                style: GoogleFonts.outfit(
                    color: Colors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm) {
      final list = _loadContacts();
      list.removeAt(index);
      _saveContacts(list);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final contacts = _loadContacts();
    return Scaffold(
      backgroundColor: ZT.bg,
      appBar: AppBar(
        backgroundColor: ZT.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: ZT.textMid, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Crisis Support',
            style: GoogleFonts.outfit(color: ZT.textDark, fontSize: 16)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GradButton(
              label: 'Edit',
              small: true,
              onPressed: () => _showManageSheet(),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('Helplines'),
            Expanded(
              child: contacts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('📞', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 12),
                          Text('No contacts yet.\nTap "Edit" to add one.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                  color: ZT.textLight,
                                  fontSize: 15,
                                  height: 1.7)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: contacts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final r = contacts[i];
                        return ZCard(
                          elevated: true,
                          child: Row(children: [
                            Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(
                                  color: ZT.p1.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(14)),
                              child: const Icon(Icons.support_agent_rounded,
                                  color: ZT.p1, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(r['name']!,
                                    style: GoogleFonts.outfit(
                                        color: ZT.textDark,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14)),
                                Text(r['number']!,
                                    style: GoogleFonts.outfit(
                                        color: ZT.p1,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500)),
                                if ((r['desc'] ?? '').isNotEmpty)
                                  Text(r['desc']!,
                                      style: GoogleFonts.outfit(
                                          color: ZT.textLight, fontSize: 11)),
                              ]),
                            ),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  gradient: ZT.grad,
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.phone_rounded,
                                  color: Colors.white, size: 18),
                            ),
                          ]),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  JOURNAL SCREEN
// ─────────────────────────────────────────────

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});
  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  Box<JournalEntry> get _box => Hive.box<JournalEntry>('journal');

  List<JournalEntry> get _entries =>
      _box.values.toList()..sort((a, b) => b.date.compareTo(a.date));

  Future<void> _goToWrite() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const JournalEntryScreen()),
    );
    if (mounted) setState(() {});
  }

  void _deleteEntry(JournalEntry e) {
    e.delete();
    setState(() {});
  }

  void _showFullEntry(BuildContext context, JournalEntry e) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ZT.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ZT.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: ZT.p1.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(moodEmojis[e.moodIndex],
                            style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 4),
                        Text(
                          moodLabels[e.moodIndex],
                          style: GoogleFonts.outfit(
                              color: ZT.p1,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    DateFormat('MMM d, yyyy · h:mm a').format(e.date),
                    style:
                        GoogleFonts.outfit(color: ZT.textLight, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                e.text,
                style: GoogleFonts.outfit(
                    color: ZT.textMid, fontSize: 15, height: 1.8),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _deleteEntry(e);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'Delete Entry',
                        style: GoogleFonts.outfit(
                            color: Colors.red, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAndDelete(BuildContext context, JournalEntry e) async {
    bool confirm = false;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ZT.bgCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Entry?',
            style: GoogleFonts.outfit(
                color: ZT.textDark, fontWeight: FontWeight.w600)),
        content: Text(
            'This journal entry will be permanently removed.',
            style: GoogleFonts.outfit(color: ZT.textMid)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.outfit(color: ZT.textMid)),
          ),
          TextButton(
            onPressed: () {
              confirm = true;
              Navigator.pop(ctx);
            },
            child: Text('Delete',
                style: GoogleFonts.outfit(
                    color: Colors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm) _deleteEntry(e);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _box.listenable(),
      builder: (context, Box<JournalEntry> box, _) {
        final entries = box.values.toList()..sort((a, b) => b.date.compareTo(a.date));
        return Scaffold(
      backgroundColor: ZT.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Journal',
                          style: GoogleFonts.playfairDisplay(
                            color: ZT.textDark,
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'A safe space for your thoughts',
                          style: GoogleFonts.outfit(
                              color: ZT.textLight, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  GradButton(
                    label: '+ Write',
                    onPressed: _goToWrite,
                    small: true,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: entries.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('📓',
                                style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 12),
                            Text(
                              'Nothing yet.\nTap "+ Write" to begin.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                color: ZT.textLight,
                                fontSize: 15,
                                height: 1.7,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: entries.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          final e = entries[i];
                          return Dismissible(
                            key: ValueKey(e.key),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(Icons.delete_outline_rounded,
                                  color: Colors.red, size: 26),
                            ),
                            confirmDismiss: (_) async {
                              bool confirm = false;
                              await showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: ZT.bgCard,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(20)),
                                  title: Text('Delete Entry?',
                                      style: GoogleFonts.outfit(
                                          color: ZT.textDark,
                                          fontWeight: FontWeight.w600)),
                                  content: Text(
                                      'This journal entry will be permanently removed.',
                                      style: GoogleFonts.outfit(
                                          color: ZT.textMid)),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: Text('Cancel',
                                          style: GoogleFonts.outfit(
                                              color: ZT.textMid)),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        confirm = true;
                                        Navigator.pop(ctx);
                                      },
                                      child: Text('Delete',
                                          style: GoogleFonts.outfit(
                                              color: Colors.red,
                                              fontWeight:
                                                  FontWeight.w600)),
                                    ),
                                  ],
                                ),
                              );
                              return confirm;
                            },
                            onDismissed: (_) => _deleteEntry(e),
                            child: ZCard(
                              elevated: true,
                              onTap: () => _showFullEntry(context, e),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 4),
                                        decoration: BoxDecoration(
                                          color: ZT.p1
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              moodEmojis[e.moodIndex],
                                              style: const TextStyle(
                                                  fontSize: 14),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              moodLabels[e.moodIndex],
                                              style: GoogleFonts.outfit(
                                                color: ZT.p1,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        DateFormat('MMM d, yyyy')
                                            .format(e.date),
                                        style: GoogleFonts.outfit(
                                            color: ZT.textLight,
                                            fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    e.text.length > 120
                                        ? '${e.text.substring(0, 120)}…'
                                        : e.text,
                                    style: GoogleFonts.outfit(
                                        color: ZT.textMid,
                                        fontSize: 14,
                                        height: 1.6),
                                  ),
                                  const SizedBox(height: 10),
                                  // ── Delete button row ──
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Tap to read',
                                        style: GoogleFonts.outfit(
                                            color: ZT.textLight,
                                            fontSize: 10),
                                      ),
                                      GestureDetector(
                                        onTap: () =>
                                            _confirmAndDelete(context, e),
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade50,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            Icons.delete_outline_rounded,
                                            color: Colors.red.shade300,
                                            size: 16,
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
          ),
        ),
      ),
    );
      },
    );
  }
}

class JournalEntryScreen extends StatefulWidget {
  const JournalEntryScreen({super.key});
  @override
  State<JournalEntryScreen> createState() => _JournalEntryScreenState();
}

class _JournalEntryScreenState extends State<JournalEntryScreen> {
  final _ctrl = TextEditingController();
  int _moodIndex = 2;
  bool _saved = false;

  void _save() {
    if (_ctrl.text.trim().isEmpty) return;
    Hive.box<JournalEntry>('journal').add(
      JournalEntry(
        date: DateTime.now(),
        text: _ctrl.text.trim(),
        moodIndex: _moodIndex,
      ),
    );
    setState(() => _saved = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZT.bg,
      appBar: AppBar(
        backgroundColor: ZT.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: ZT.textMid,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'New Entry',
          style: GoogleFonts.outfit(color: ZT.textDark, fontSize: 16),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: _save,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  gradient: _saved ? null : ZT.grad,
                  color: _saved ? ZT.surface : null,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _saved ? 'Saved ✓' : 'Save',
                  style: GoogleFonts.outfit(
                    color: _saved ? ZT.p1 : Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('Your mood'),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(
                5,
                (i) => GestureDetector(
                  onTap: () => setState(() => _moodIndex = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _moodIndex == i
                          ? ZT.p1.withValues(alpha: 0.1)
                          : ZT.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _moodIndex == i ? ZT.p1 : ZT.border,
                        width: _moodIndex == i ? 1.5 : 0.8,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          moodEmojis[i],
                          style: TextStyle(fontSize: _moodIndex == i ? 26 : 22),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          moodLabels[i],
                          style: GoogleFonts.outfit(
                            fontSize: 9,
                            color: _moodIndex == i ? ZT.p1 : ZT.textLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const SectionLabel('Write freely'),
            TextField(
              controller: _ctrl,
              maxLines: null,
              autofocus: true,
              style: GoogleFonts.outfit(
                color: ZT.textDark,
                fontSize: 16,
                height: 1.9,
              ),
              cursorColor: ZT.p1,
              decoration: InputDecoration(
                hintText: "What's on your heart today?",
                hintStyle: GoogleFonts.outfit(
                  color: ZT.textLight,
                  fontSize: 15,
                  height: 1.8,
                ),
                border: InputBorder.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  RESOURCES SCREEN
//  NOTE: Affirmations section removed intentionally.
// ─────────────────────────────────────────────

class ResourcesScreen extends StatelessWidget {
  const ResourcesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZT.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Resources',
                style: GoogleFonts.playfairDisplay(
                  color: ZT.textDark,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Tools for your wellness',
                style: GoogleFonts.outfit(color: ZT.textLight, fontSize: 13),
              ),
              const SizedBox(height: 24),
              const SectionLabel('Exercises'),
              _ResourceCard(
                icon: Icons.air_rounded,
                title: 'Breathing Exercises',
                desc: 'Calm your nervous system',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BreathingScreen()),
                ),
              ),
              const SizedBox(height: 12),
              _ResourceCard(
                icon: Icons.spa_rounded,
                title: '5-4-3-2-1 Grounding',
                desc: 'Come back to the present',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GroundingScreen()),
                ),
              ),
              const SizedBox(height: 12),
              _ResourceCard(
                icon: Icons.shield_rounded,
                title: 'Crisis Mode',
                desc: 'Immediate crisis support',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PanicModeScreen()),
                ),
              ),
              const SizedBox(height: 24),
              const SectionLabel('Helplines'),
              _ResourceCard(
                icon: Icons.phone_in_talk_rounded,
                title: 'Homies',
                desc: 'Free, confidential support',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HelplineScreen()),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResourceCard extends StatelessWidget {
  final IconData icon;
  final String title, desc;
  final VoidCallback onTap;
  const _ResourceCard({
    required this.icon,
    required this.title,
    required this.desc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ZCard(
        elevated: true,
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: ZT.grad,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      color: ZT.textDark,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    desc,
                    style:
                        GoogleFonts.outfit(color: ZT.textLight, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: ZT.textLight),
          ],
        ),
      );
}

// ─────────────────────────────────────────────
//  PROFILE SCREEN
// ─────────────────────────────────────────────

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  void _showSOSMessageDialog(BuildContext context) {
  final prefs = Hive.box('prefs');
  final ctrl = TextEditingController(
    text: prefs.get(
      'sosMessage',
      defaultValue: 'I need support right now. Please check on me. 💜',
    ),
  );
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: ZT.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('SOS Message',
          style: GoogleFonts.playfairDisplay(color: ZT.textDark)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('This message will be sent to your anchor contacts when you enter Crisis Mode.',
            style: GoogleFonts.outfit(color: ZT.textLight, fontSize: 13, height: 1.5)),
        const SizedBox(height: 12),
        TextField(
          controller: ctrl,
          maxLines: 3,
          style: GoogleFonts.outfit(color: ZT.textDark),
          cursorColor: ZT.p1,
          decoration: InputDecoration(
            filled: true,
            fillColor: ZT.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ]),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: GoogleFonts.outfit(color: ZT.textLight)),
        ),
        TextButton(
          onPressed: () {
            prefs.put('sosMessage', ctrl.text.trim());
            Navigator.pop(context);
          },
          child: Text('Save',
              style: GoogleFonts.outfit(
                  color: ZT.p1, fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
}
  void _showTermsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ZT.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, ctrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: ZT.border, borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: ZT.grad,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.gavel_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Terms & Conditions',
                            style: GoogleFonts.playfairDisplay(
                                color: ZT.textDark,
                                fontSize: 20,
                                fontWeight: FontWeight.w600)),
                        Text('Last Updated: April 2026',
                            style: GoogleFonts.outfit(
                                color: ZT.textLight, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Divider(color: ZT.border, height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TermsSection(number: '1', title: 'Definitions',
                      content: '"Application" refers to the Zivara mobile application.\n"User" refers to any individual who accesses or uses the application.\n"Services" refer to the features provided by Zivara.'),
                    _TermsSection(number: '2', title: 'Acceptance of Terms',
                      content: 'By installing or using the application, the User agrees to be bound by these Terms and Conditions.'),
                    _TermsSection(number: '3', title: 'Scope of Services',
                      content: 'Zivara provides mental wellness support features such as calming tools, memory storage, and emergency contact assistance.\n\nThe application is intended for support purposes only and does not provide medical advice.'),
                    _TermsSection(number: '4', title: 'User Obligations',
                      content: 'The User agrees to:\n• Use the application responsibly\n• Provide accurate information\n• Not misuse or attempt to harm the application'),
                    _TermsSection(number: '5', title: 'Data and Privacy',
                      content: 'User data and uploaded content shall be handled in accordance with the Privacy Policy.\n\nZivara does not share personal content without user permission.'),
                    _TermsSection(number: '6', title: 'Emergency and Safety Disclaimer',
                      content: 'Emergency features depend on network and device permissions.\n\nUsers must contact official emergency services in real emergencies.'),
                    _TermsSection(number: '7', title: 'Limitation of Liability',
                      content: 'The developers shall not be liable for:\n• Data loss\n• Technical failures\n• Misuse of the application\n• Any decisions made using the application'),
                    _TermsSection(number: '8', title: 'Intellectual Property Rights',
                      content: 'All content, design, and features of Zivara are the property of the developers and are protected under applicable laws.'),
                    _TermsSection(number: '9', title: 'Modification of Terms',
                      content: 'These Terms may be updated periodically. Continued use of the application indicates acceptance of the revised Terms.'),
                    _TermsSection(number: '10', title: 'Governing Law',
                      content: 'These Terms shall be governed by the laws of India.'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: ZT.p1.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ZT.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.favorite_rounded, color: ZT.p1, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Zivara is a safe space. Your wellbeing is our priority.',
                              style: GoogleFonts.outfit(
                                  color: ZT.textMid, fontSize: 12,
                                  height: 1.5, fontStyle: FontStyle.italic),
                            ),
                          ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final name =
        Hive.box('prefs').get('name', defaultValue: 'Friend') as String;
    final journalCount = Hive.box<JournalEntry>('journal').length;
    final anchorCount = Hive.box<AnchorContact>('anchors').length;

    return Scaffold(
      backgroundColor: ZT.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profile',
                style: GoogleFonts.playfairDisplay(
                  color: ZT.textDark,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: ZT.grad,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: ZT.p1.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          name[0].toUpperCase(),
                          style: GoogleFonts.playfairDisplay(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      name,
                      style: GoogleFonts.playfairDisplay(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Your wellness journey',
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      value: '$journalCount',
                      label: 'Journal\nEntries',
                      icon: Icons.menu_book_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      value: '$anchorCount',
                      label: 'Anchors',
                      icon: Icons.favorite_rounded,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              const SectionLabel('Settings'),

              _SettingsTile(
                icon: Icons.person_outline,
                label: 'Edit Name',
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => _EditNameDialog(),
                  );
                },
              ),
              _SettingsTile(
                icon: Icons.anchor,
                label: 'My Anchor',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyAnchorScreen()),
                ),
              ),
              _SettingsTile(
  icon: Icons.message_outlined,
  label: 'SOS Message',
  onTap: () => _showSOSMessageDialog(context),
),
              _SettingsTile(
                icon: Icons.phone_in_talk_rounded,
                label: 'Crisis Support',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CrisisSupportScreen()),
                ),
              ),
              _SettingsTile(
                icon: Icons.info_outline,
                label: 'About Zivara',
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: ZT.bgCard,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      title: Text(
                        'About Zivara',
                        style: GoogleFonts.playfairDisplay(color: ZT.textDark),
                      ),
                      content: Text(
                        'Zivara is a safe space for your mental wellness. You are not alone.',
                        style: GoogleFonts.outfit(
                          color: ZT.textMid,
                          height: 1.6,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Close',
                            style: GoogleFonts.outfit(
                              color: ZT.p1,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              _SettingsTile(
                icon: Icons.gavel_rounded,
                label: 'Terms & Conditions',
                onTap: () => _showTermsDialog(context),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value, label;
  final IconData icon;
  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
  });
  @override
  Widget build(BuildContext context) => ZCard(
        elevated: true,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: ZT.p1, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.playfairDisplay(
                color: ZT.textDark,
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: ZT.textLight,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: ZT.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ZT.border),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: ZT.p1.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: ZT.p1, size: 18),
              ),
              const SizedBox(width: 14),
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: ZT.textDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              const Icon(Icons.chevron_right, color: ZT.textLight, size: 20),
            ],
          ),
        ),
      );
}

class _EditNameDialog extends StatefulWidget {
  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  final _ctrl = TextEditingController(
    text: Hive.box('prefs').get('name', defaultValue: ''),
  );
  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: ZT.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Edit Name',
          style: GoogleFonts.playfairDisplay(color: ZT.textDark),
        ),
        content: TextField(
          controller: _ctrl,
          style: GoogleFonts.outfit(color: ZT.textDark),
          cursorColor: ZT.p1,
          decoration: InputDecoration(
            filled: true,
            fillColor: ZT.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                Text('Cancel', style: GoogleFonts.outfit(color: ZT.textLight)),
          ),
          TextButton(
            onPressed: () {
              if (_ctrl.text.trim().isNotEmpty)
                Hive.box('prefs').put('name', _ctrl.text.trim());
              Navigator.pop(context);
            },
            child: Text(
              'Save',
              style:
                  GoogleFonts.outfit(color: ZT.p1, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
}

class CalmAudio {
  static final AudioPlayer _player = AudioPlayer();
  static bool _playing = false;

  static Future<void> start() async {
    if (_playing) return;
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(0.35);
      await _player.play(AssetSource('audio/calm.mp3'));
      _playing = true;
    } catch (_) {}
  }

  static Future<void> stop() async {
    try {
      await _player.stop();
      _playing = false;
    } catch (_) {}
  }

  static Future<void> setVolume(double v) async {
    try {
      await _player.setVolume(v.clamp(0.0, 1.0));
    } catch (_) {}
  }

  static void chime() => HapticFeedback.lightImpact();
  static void tadaSound() => HapticFeedback.heavyImpact();
}

// ─────────────────────────────────────────────
//  GAME REGISTRY
// ─────────────────────────────────────────────

enum ZGame {
  balloonPop,
  colorTap,
  lanterns,
  stars,
  matchShape,
  calmWords,
  makeSmile,
  colorFill
}

const _gameNames = {
  ZGame.balloonPop: '🎈 Pop Balloons',
  ZGame.colorTap: '🎨 Tap the Color',
  ZGame.lanterns: '🏮 Light the Lanterns',
  ZGame.stars: '⭐ Glow the Stars',
  ZGame.matchShape: '🔷 Match the Shape',
  ZGame.calmWords: '💬 Calm Words',
  ZGame.makeSmile: '😊 Make It Smile',
  ZGame.colorFill: '🖌 Color Fill',
};

// ─────────────────────────────────────────────
//  DISTRACTION PHASE
// ─────────────────────────────────────────────

class DistractionPhase extends StatefulWidget {
  final VoidCallback onDone;
  const DistractionPhase({super.key, required this.onDone});
  @override
  State<DistractionPhase> createState() => _DistractionPhaseState();
}

class _DistractionPhaseState extends State<DistractionPhase> {
  ZGame? _current;
  int _score = 0;
  bool _complete = false;
  final _rand = Random();

  final _allGames = ZGame.values.toList();

  void _pickRandom() {
    setState(() {
      _current = _allGames[_rand.nextInt(_allGames.length)];
      _complete = false;
      _score = 0;
    });
  }

  void _onComplete(int score) {
    setState(() {
      _score = score;
      _complete = true;
    });
    CalmAudio.chime();
  }

  Widget _buildGame() {
    switch (_current!) {
      case ZGame.balloonPop:
        return BalloonPopGame(onComplete: _onComplete);
      case ZGame.colorTap:
        return ColorTapGame(onComplete: _onComplete);
      case ZGame.lanterns:
        return LanternGame(onComplete: _onComplete);
      case ZGame.stars:
        return StarGlowGame(onComplete: _onComplete);
      case ZGame.matchShape:
        return MatchShapeGame(onComplete: _onComplete);
      case ZGame.calmWords:
        return CalmWordsGame(onComplete: _onComplete);
      case ZGame.makeSmile:
        return MakeSmileGame(onComplete: _onComplete);
      case ZGame.colorFill:
        return ColorFillGame(onComplete: _onComplete);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_current == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('🎮', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          Text("Let's distract your mind",
              style: GoogleFonts.playfairDisplay(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Pick a game or let us choose one for you',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.white60, fontSize: 14)),
          const SizedBox(height: 32),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: _allGames
                .map((g) => GestureDetector(
                      onTap: () => setState(() {
                        _current = g;
                        _complete = false;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Text(_gameNames[g]!,
                            style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: _pickRandom,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(50)),
              child: Text('🎲 Random Game',
                  style: GoogleFonts.outfit(
                      color: const Color(0xFF7B5CF0),
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
            ),
          ),
        ]),
      );
    }

    if (_complete) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(28, 16, 28, 100),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('🎉', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text('Amazing!',
              style: GoogleFonts.playfairDisplay(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Score: $_score',
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 18)),
          const SizedBox(height: 12),
          Text('You made it through.\nYou are doing so well. 💜',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                  color: Colors.white60, fontSize: 15, height: 1.7)),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: _pickRandom,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(30)),
              child: Text('🎮 Play Another',
                  style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: widget.onDone,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(50)),
              child: Text("I'm feeling better 💜",
                  style: GoogleFonts.outfit(
                      color: const Color(0xFF7B5CF0),
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
            ),
          ),
        ]),
      );
    }

    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Row(children: [
          GestureDetector(
            onTap: () => setState(() {
              _current = null;
              _complete = false;
            }),
            child: const Icon(Icons.grid_view_rounded,
                color: Colors.white70, size: 20),
          ),
          const SizedBox(width: 10),
          Text(_gameNames[_current!]!,
              style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
      Expanded(child: _buildGame()),
    ]);
  }
}

// ─────────────────────────────────────────────
//  SHARED GAME WRAPPER
// ─────────────────────────────────────────────

class GameWrapper extends StatelessWidget {
  final Widget child;
  const GameWrapper({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
        child: child,
      );
}

// ─────────────────────────────────────────────
//  GAME 1 — BALLOON POP
// ─────────────────────────────────────────────

class _Balloon {
  double x, y, speed;
  Color color;
  double size;
  bool popped;
  _Balloon(
      {required this.x,
      required this.y,
      required this.speed,
      required this.color,
      required this.size,
      this.popped = false});
}

class BalloonPopGame extends StatefulWidget {
  final void Function(int) onComplete;
  const BalloonPopGame({super.key, required this.onComplete});
  @override
  State<BalloonPopGame> createState() => _BalloonPopGameState();
}

class _BalloonPopGameState extends State<BalloonPopGame> {
  final List<_Balloon> _balloons = [];
  int _score = 0, _timeLeft = 30;
  Timer? _gameTimer, _spawnTimer;
  final _rand = Random();
  final _colors = [
    const Color(0xFFFF6B9D),
    const Color(0xFFFFB347),
    const Color(0xFF87CEEB),
    const Color(0xFF98FB98),
    const Color(0xFFDDA0DD),
    const Color(0xFFFFF44F),
    const Color(0xFFFF8C69),
    const Color(0xFFADD8E6),
  ];

  @override
  void initState() {
    super.initState();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _timeLeft--;
        for (final b in _balloons) {
          if (!b.popped) b.y -= b.speed;
        }
        _balloons.removeWhere((b) => b.y < -100 || b.popped);
      });
      if (_timeLeft <= 0) {
        _gameTimer?.cancel();
        _spawnTimer?.cancel();
        widget.onComplete(_score);
      }
    });
    _spawnTimer = Timer.periodic(const Duration(milliseconds: 1100), (_) {
      if (!mounted) return;
      setState(() => _balloons.add(_Balloon(
            x: _rand.nextDouble() * 280 + 20,
            y: 480,
            speed: _rand.nextDouble() * 5 + 6,
            color: _colors[_rand.nextInt(_colors.length)],
            size: _rand.nextDouble() * 22 + 40,
          )));
    });
  }

  void _pop(int i) {
    if (_balloons[i].popped) return;
    CalmAudio.chime();
    setState(() {
      _balloons[i].popped = true;
      _score += 10;
    });
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _spawnTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GameWrapper(
          child: Column(children: [
        _ScoreBar(
            score: _score, time: _timeLeft, label: '🎈 Pop every balloon!'),
        Expanded(
            child: Stack(children: [
          ..._balloons.asMap().entries.where((e) => !e.value.popped).map((e) {
            final b = e.value;
            return Positioned(
              left: b.x - b.size / 2,
              top: b.y - b.size,
              child: GestureDetector(
                onTap: () => _pop(e.key),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: b.size,
                    height: b.size * 1.2,
                    decoration: BoxDecoration(
                      color: b.color,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(b.size / 2),
                        topRight: Radius.circular(b.size / 2),
                        bottomLeft: Radius.circular(b.size / 2),
                        bottomRight: Radius.circular(b.size / 3),
                      ),
                      boxShadow: [
                        BoxShadow(
                            color: b.color.withValues(alpha: 0.5),
                            blurRadius: 8)
                      ],
                    ),
                    child: Center(
                        child: Container(
                            width: b.size * 0.28,
                            height: b.size * 0.28,
                            decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.45),
                                shape: BoxShape.circle))),
                  ),
                  Container(
                      width: 1.5,
                      height: 14,
                      color: b.color.withValues(alpha: 0.5)),
                ]),
              ),
            );
          }),
        ])),
      ]));
}

// ─────────────────────────────────────────────
//  GAME 2 — COLOR TAP
// ─────────────────────────────────────────────

class _CTTarget {
  double x, y, size;
  Color color;
  String name;
  _CTTarget(
      {required this.x,
      required this.y,
      required this.size,
      required this.color,
      required this.name});
}

class ColorTapGame extends StatefulWidget {
  final void Function(int) onComplete;
  const ColorTapGame({super.key, required this.onComplete});
  @override
  State<ColorTapGame> createState() => _ColorTapGameState();
}

class _ColorTapGameState extends State<ColorTapGame> {
  int _score = 0, _timeLeft = 30, _streak = 0;
  String? _targetName;
  Color? _targetColor;
  String? _feedback;
  Timer? _timer;
  List<_CTTarget> _targets = [];
  final _rand = Random();
  final _colorMap = {
    'Red': const Color(0xFFFF5252),
    'Blue': const Color(0xFF448AFF),
    'Green': const Color(0xFF69F0AE),
    'Yellow': const Color(0xFFFFFF00),
    'Pink': const Color(0xFFFF80AB),
    'Orange': const Color(0xFFFF9100),
    'Purple': const Color(0xFFE040FB),
    'White': const Color(0xFFFFFFFF),
  };

  @override
  void initState() {
    super.initState();
    _spawnRound();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _timeLeft--);
      if (_timeLeft <= 0) {
        _timer?.cancel();
        widget.onComplete(_score);
      }
    });
  }

  void _spawnRound() {
    final keys = _colorMap.keys.toList()..shuffle();
    _targetName = keys.first;
    _targetColor = _colorMap[_targetName];
    _feedback = null;
    final pool = keys.take(4).toList();
    if (!pool.contains(_targetName)) pool[0] = _targetName!;
    pool.shuffle();
    const pos = [
      [50.0, 100.0],
      [210.0, 100.0],
      [50.0, 240.0],
      [210.0, 240.0]
    ];
    _targets = List.generate(
        4,
        (i) => _CTTarget(
            x: pos[i][0],
            y: pos[i][1],
            color: _colorMap[pool[i]]!,
            name: pool[i],
            size: 62 + _rand.nextDouble() * 14));
  }

  void _onTap(_CTTarget t) {
    if (t.name == _targetName) {
      CalmAudio.chime();
      setState(() {
        _score += 10 + _streak * 5;
        _streak++;
        _feedback = _streak >= 3
            ? '🔥 Streak! +${10 + _streak * 5}'
            : '✓ +${10 + _streak * 5}';
      });
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) setState(_spawnRound);
      });
    } else {
      setState(() {
        _streak = 0;
        _feedback = '✗ Wrong!';
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GameWrapper(
          child: Column(children: [
        _ScoreBar(
            score: _score, time: _timeLeft, label: 'Tap: ${_targetName ?? ""}'),
        if (_targetColor != null)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: _targetColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                            color: _targetColor!.withValues(alpha: 0.5),
                            blurRadius: 14)
                      ]))),
        AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(_feedback ?? ' ',
                key: ValueKey(_feedback),
                style: GoogleFonts.outfit(
                    color: (_feedback?.startsWith('✓') == true ||
                            _feedback?.startsWith('🔥') == true)
                        ? const Color(0xFF69F0AE)
                        : const Color(0xFFFF5252),
                    fontSize: 15,
                    fontWeight: FontWeight.w700))),
        const SizedBox(height: 8),
        Expanded(
            child: SizedBox(
                width: 300,
                child: Stack(
                    children: _targets
                        .map((t) => Positioned(
                            left: t.x - t.size / 2,
                            top: t.y - t.size / 2,
                            child: GestureDetector(
                                onTap: () => _onTap(t),
                                child: Container(
                                    width: t.size,
                                    height: t.size,
                                    decoration: BoxDecoration(
                                        color: t.color,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white
                                                .withValues(alpha: 0.4),
                                            width: 2),
                                        boxShadow: [
                                          BoxShadow(
                                              color: t.color
                                                  .withValues(alpha: 0.4),
                                              blurRadius: 12)
                                        ])))))
                        .toList()))),
      ]));
}

// ─────────────────────────────────────────────
//  GAME 3 — LIGHT THE LANTERNS
// ─────────────────────────────────────────────

class LanternGame extends StatefulWidget {
  final void Function(int) onComplete;
  const LanternGame({super.key, required this.onComplete});
  @override
  State<LanternGame> createState() => _LanternGameState();
}

class _LanternGameState extends State<LanternGame>
    with TickerProviderStateMixin {
  static const _total = 12;
  late List<bool> _lit;
  late List<AnimationController> _glowCtrls;
  int _score = 0, _timeLeft = 40;
  Timer? _timer;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _lit = List.filled(_total, false);
    _glowCtrls = List.generate(
        _total,
        (_) => AnimationController(
            vsync: this, duration: const Duration(milliseconds: 600)));
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _timeLeft--);
      if (_timeLeft <= 0 || _done) {
        _timer?.cancel();
        widget.onComplete(_score);
      }
    });
  }

  void _tap(int i) {
    if (_lit[i]) return;
    CalmAudio.chime();
    setState(() {
      _lit[i] = true;
      _score += 15;
    });
    _glowCtrls[i].forward();
    if (_lit.every((l) => l)) {
      _done = true;
      CalmAudio.tadaSound();
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) widget.onComplete(_score);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _glowCtrls) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GameWrapper(
          child: Column(children: [
        _ScoreBar(
            score: _score,
            time: _timeLeft,
            label: '🏮 Light all the lanterns!'),
        const SizedBox(height: 8),
        Text('${_lit.where((l) => l).length} / $_total lit',
            style: GoogleFonts.outfit(color: Colors.white60, fontSize: 13)),
        const SizedBox(height: 16),
        Expanded(
            child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, mainAxisSpacing: 12, crossAxisSpacing: 12),
          itemCount: _total,
          itemBuilder: (_, i) => GestureDetector(
            onTap: () => _tap(i),
            child: AnimatedBuilder(
              animation: _glowCtrls[i],
              builder: (_, __) => Container(
                decoration: BoxDecoration(
                  color: _lit[i]
                      ? Color.lerp(Colors.deepOrange.shade300,
                          const Color(0xFFFFB347), _glowCtrls[i].value)
                      : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _lit[i]
                      ? [
                          BoxShadow(
                              color: const Color(0xFFFFB347)
                                  .withValues(alpha: 0.6 * _glowCtrls[i].value),
                              blurRadius: 18)
                        ]
                      : null,
                  border: Border.all(
                      color: _lit[i]
                          ? const Color(0xFFFFB347)
                          : Colors.white.withValues(alpha: 0.2),
                      width: 1.5),
                ),
                child: Center(
                    child: Text(_lit[i] ? '🏮' : '⬜',
                        style: TextStyle(fontSize: _lit[i] ? 30 : 22))),
              ),
            ),
          ),
        )),
      ]));
}

// ─────────────────────────────────────────────
//  GAME 4 — GLOW THE STARS
// ─────────────────────────────────────────────

class StarGlowGame extends StatefulWidget {
  final void Function(int) onComplete;
  const StarGlowGame({super.key, required this.onComplete});
  @override
  State<StarGlowGame> createState() => _StarGlowGameState();
}

class _StarGlowGameState extends State<StarGlowGame>
    with TickerProviderStateMixin {
  static const _total = 16;
  late List<int> _glow;
  late List<AnimationController> _twinkleCtrls;
  int _score = 0, _timeLeft = 45;
  Timer? _timer;
  final _rand = Random();

  late final List<Offset> _positions;

  @override
  void initState() {
    super.initState();
    _glow = List.filled(_total, 0);
    _twinkleCtrls = List.generate(
        _total,
        (_) => AnimationController(
            vsync: this, duration: const Duration(milliseconds: 800))
          ..repeat(reverse: true));

    _positions = List.generate(
        _total,
        (_) => Offset(
              _rand.nextDouble() * 280 + 20,
              _rand.nextDouble() * 320 + 20,
            ));

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _timeLeft--);
      if (_timeLeft <= 0 || _glow.every((g) => g == 2)) {
        _timer?.cancel();
        widget.onComplete(_score);
      }
    });
  }

  void _tap(int i) {
    if (_glow[i] == 2) return;
    CalmAudio.chime();
    setState(() {
      _glow[i]++;
      _score += _glow[i] == 2 ? 20 : 10;
    });
    if (_glow.every((g) => g == 2)) {
      CalmAudio.tadaSound();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) widget.onComplete(_score);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _twinkleCtrls) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bright = _glow.where((g) => g == 2).length;
    return GameWrapper(
        child: Column(children: [
      _ScoreBar(
          score: _score, time: _timeLeft, label: '⭐ Tap to make stars glow!'),
      const SizedBox(height: 4),
      Text('$bright / $_total fully glowing',
          style: GoogleFonts.outfit(color: Colors.white60, fontSize: 12)),
      const SizedBox(height: 8),
      Expanded(
          child: Stack(
              children: List.generate(_total, (i) {
        final starChar = _glow[i] == 0 ? '✦' : (_glow[i] == 1 ? '★' : '⭐');
        final size = _glow[i] == 0 ? 22.0 : (_glow[i] == 1 ? 30.0 : 38.0);
        return Positioned(
          left: _positions[i].dx,
          top: _positions[i].dy,
          child: GestureDetector(
            onTap: () => _tap(i),
            child: AnimatedBuilder(
              animation: _twinkleCtrls[i],
              builder: (_, __) => Opacity(
                opacity: _glow[i] == 2
                    ? 0.7 + _twinkleCtrls[i].value * 0.3
                    : 0.4 + _glow[i] * 0.25,
                child: Text(starChar, style: TextStyle(fontSize: size)),
              ),
            ),
          ),
        );
      }))),
    ]));
  }
}

// ─────────────────────────────────────────────
//  GAME 5 — MATCH THE SHAPE
// ─────────────────────────────────────────────

enum _Shape { circle, square, triangle, diamond, star, heart }

class MatchShapeGame extends StatefulWidget {
  final void Function(int) onComplete;
  const MatchShapeGame({super.key, required this.onComplete});
  @override
  State<MatchShapeGame> createState() => _MatchShapeGameState();
}

class _MatchShapeGameState extends State<MatchShapeGame> {
  int _score = 0, _timeLeft = 45, _round = 0;
  late _Shape _targetShape;
  late List<_Shape> _options;
  String? _feedback;
  Timer? _timer;
  final _rand = Random();
  final _allShapes = _Shape.values;

  @override
  void initState() {
    super.initState();
    _nextRound();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _timeLeft--);
      if (_timeLeft <= 0) {
        _timer?.cancel();
        widget.onComplete(_score);
      }
    });
  }

  void _nextRound() {
    _targetShape = _allShapes[_rand.nextInt(_allShapes.length)];
    final opts = _allShapes.toList()..shuffle();
    _options = opts.take(4).toList();
    if (!_options.contains(_targetShape)) _options[0] = _targetShape;
    _options.shuffle();
    _feedback = null;
    _round++;
  }

  void _pick(_Shape s) {
    if (s == _targetShape) {
      CalmAudio.chime();
      setState(() {
        _score += 15;
        _feedback = '✓ Matched!';
      });
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) setState(_nextRound);
      });
    } else {
      setState(() {
        _feedback = '✗ Try again';
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _shapeEmoji(_Shape s) {
    switch (s) {
      case _Shape.circle:
        return '⭕';
      case _Shape.square:
        return '⬛';
      case _Shape.triangle:
        return '🔺';
      case _Shape.diamond:
        return '🔷';
      case _Shape.star:
        return '⭐';
      case _Shape.heart:
        return '❤️';
    }
  }

  String _shapeName(_Shape s) => s.name[0].toUpperCase() + s.name.substring(1);

  @override
  Widget build(BuildContext context) => GameWrapper(
          child: Column(children: [
        _ScoreBar(score: _score, time: _timeLeft, label: '🔷 Match the Shape!'),
        const SizedBox(height: 12),
        Text('Find the:',
            style: GoogleFonts.outfit(color: Colors.white60, fontSize: 13)),
        const SizedBox(height: 6),
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.4), width: 2),
          ),
          child: Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                Text(_shapeEmoji(_targetShape),
                    style: const TextStyle(fontSize: 42)),
                Text(_shapeName(_targetShape),
                    style: GoogleFonts.outfit(
                        color: Colors.white54, fontSize: 11)),
              ])),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(_feedback ?? ' ',
                key: ValueKey(_feedback),
                style: GoogleFonts.outfit(
                    color: _feedback?.startsWith('✓') == true
                        ? const Color(0xFF69F0AE)
                        : const Color(0xFFFF7675),
                    fontSize: 15,
                    fontWeight: FontWeight.w600))),
        const SizedBox(height: 16),
        Expanded(
            child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.4,
          children: _options
              .map((s) => GestureDetector(
                    onTap: () => _pick(s),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1.5),
                      ),
                      child: Center(
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                            Text(_shapeEmoji(s),
                                style: const TextStyle(fontSize: 36)),
                            const SizedBox(height: 4),
                            Text(_shapeName(s),
                                style: GoogleFonts.outfit(
                                    color: Colors.white60, fontSize: 11)),
                          ])),
                    ),
                  ))
              .toList(),
        )),
      ]));
}

// ─────────────────────────────────────────────
//  GAME 6 — CALM WORDS
// ─────────────────────────────────────────────

class CalmWordsGame extends StatefulWidget {
  final void Function(int) onComplete;
  const CalmWordsGame({super.key, required this.onComplete});
  @override
  State<CalmWordsGame> createState() => _CalmWordsGameState();
}

class _CalmWordsGameState extends State<CalmWordsGame> {
  static const _calmWords = [
    'Calm', 'Breathe', 'Safe', 'Peace', 'Gentle', 'Still', 'Ease',
    'Soft', 'Rest', 'Serene', 'Quiet', 'Trust', 'Light', 'Warm', 'Loved'
  ];
  static const _otherWords = [
    'Rush', 'Panic', 'Fast', 'Loud', 'Sharp', 'Tense', 'Hard',
    'Cold', 'Fear', 'Dark', 'Stress', 'Harsh', 'Wild', 'Noise', 'Tight'
  ];

  int _score = 0, _timeLeft = 35, _tapped = 0;
  final Set<String> _tappedWords = {};
  late List<_WordTile> _tiles;
  Timer? _timer;
  final _rand = Random();

  @override
  void initState() {
    super.initState();
    _buildTiles();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _timeLeft--);
      if (_timeLeft <= 0) {
        _timer?.cancel();
        widget.onComplete(_score);
      }
    });
  }

  void _buildTiles() {
    final calm = _calmWords.toList()..shuffle();
    final other = _otherWords.toList()..shuffle();
    final all = [...calm.take(8), ...other.take(6)];
    all.shuffle();
    _tiles = all
        .map((w) => _WordTile(word: w, isCalm: _calmWords.contains(w)))
        .toList();
  }

  void _tap(_WordTile t) {
    if (_tappedWords.contains(t.word)) return;
    if (t.isCalm) {
      CalmAudio.chime();
      _tappedWords.add(t.word);
      setState(() {
        _score += 15;
        _tapped++;
      });
      if (_tapped >= 8) {
        _timer?.cancel();
        CalmAudio.tadaSound();
        widget.onComplete(_score);
      }
    } else {
      setState(() {
        if (_score > 0) _score -= 5;
      });
      HapticFeedback.mediumImpact();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GameWrapper(
          child: Column(children: [
        _ScoreBar(
            score: _score,
            time: _timeLeft,
            label: '💬 Tap only the CALM words!'),
        const SizedBox(height: 8),
        Text('$_tapped / 8 calm words found',
            style: GoogleFonts.outfit(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 12),
        Expanded(
            child: Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: _tiles.map((t) {
            final tapped = _tappedWords.contains(t.word);
            return GestureDetector(
              onTap: () => _tap(t),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: tapped
                      ? const Color(0xFF69F0AE).withValues(alpha: 0.25)
                      : Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: tapped
                        ? const Color(0xFF69F0AE)
                        : Colors.white.withValues(alpha: 0.25),
                    width: tapped ? 2 : 1,
                  ),
                  boxShadow: tapped
                      ? [
                          BoxShadow(
                              color: const Color(0xFF69F0AE)
                                  .withValues(alpha: 0.3),
                              blurRadius: 12)
                        ]
                      : null,
                ),
                child: Text(t.word,
                    style: GoogleFonts.outfit(
                        color: tapped ? const Color(0xFF69F0AE) : Colors.white,
                        fontSize: 16,
                        fontWeight:
                            tapped ? FontWeight.w700 : FontWeight.w400)),
              ),
            );
          }).toList(),
        )),
      ]));
}

class _WordTile {
  final String word;
  final bool isCalm;
  _WordTile({required this.word, required this.isCalm});
}

// ─────────────────────────────────────────────
//  GAME 7 — MAKE IT SMILE
// ─────────────────────────────────────────────

class MakeSmileGame extends StatefulWidget {
  final void Function(int) onComplete;
  const MakeSmileGame({super.key, required this.onComplete});
  @override
  State<MakeSmileGame> createState() => _MakeSmileGameState();
}

class _MakeSmileGameState extends State<MakeSmileGame>
    with TickerProviderStateMixin {
  static const _total = 9;
  late List<int> _stages;
  late List<AnimationController> _bounceCtrls;
  int _score = 0, _timeLeft = 50;
  Timer? _timer;
  bool _done = false;

  final _emojis = [
    ['😢', '😐', '😊'],
  ];

  @override
  void initState() {
    super.initState();
    final r = Random();
    _stages = List.generate(_total, (_) => r.nextInt(2));
    _bounceCtrls = List.generate(
        _total,
        (_) => AnimationController(
            vsync: this, duration: const Duration(milliseconds: 300)));
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _timeLeft--);
      if (_timeLeft <= 0 || _done) {
        _timer?.cancel();
        widget.onComplete(_score);
      }
    });
  }

  void _tap(int i) {
    if (_stages[i] == 2) return;
    CalmAudio.chime();
    _bounceCtrls[i].forward(from: 0);
    setState(() {
      _stages[i]++;
      _score += _stages[i] == 2 ? 20 : 8;
    });
    if (_stages.every((s) => s == 2)) {
      _done = true;
      CalmAudio.tadaSound();
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) widget.onComplete(_score);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _bounceCtrls) c.dispose();
    super.dispose();
  }

  String _emoji(int i) => _emojis[0][_stages[i]];

  @override
  Widget build(BuildContext context) {
    final smiling = _stages.where((s) => s == 2).length;
    return GameWrapper(
        child: Column(children: [
      _ScoreBar(
          score: _score, time: _timeLeft, label: '😊 Tap to make them smile!'),
      const SizedBox(height: 4),
      Text('$smiling / $_total smiling',
          style: GoogleFonts.outfit(color: Colors.white60, fontSize: 12)),
      const SizedBox(height: 8),
      Text('Tap 1–2 times until 😊 appears',
          style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11)),
      const SizedBox(height: 12),
      Expanded(
          child: GridView.count(
        crossAxisCount: 3,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        children: List.generate(
            _total,
            (i) => GestureDetector(
                  onTap: () => _tap(i),
                  child: AnimatedBuilder(
                    animation: _bounceCtrls[i],
                    builder: (_, __) => Transform.scale(
                      scale: 1.0 +
                          _bounceCtrls[i].value *
                              0.2 *
                              (1 - _bounceCtrls[i].value) *
                              4,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _stages[i] == 2
                              ? const Color(0xFFFFD700).withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _stages[i] == 2
                                ? const Color(0xFFFFD700).withValues(alpha: 0.6)
                                : Colors.white.withValues(alpha: 0.15),
                            width: 1.5,
                          ),
                          boxShadow: _stages[i] == 2
                              ? [
                                  BoxShadow(
                                      color: const Color(0xFFFFD700)
                                          .withValues(alpha: 0.3),
                                      blurRadius: 16)
                                ]
                              : null,
                        ),
                        child: Center(
                            child: Text(_emoji(i),
                                style: const TextStyle(fontSize: 40))),
                      ),
                    ),
                  ),
                )),
      )),
    ]));
  }
}

// ─────────────────────────────────────────────
//  GAME 8 — COLOR FILL
// ─────────────────────────────────────────────

class ColorFillGame extends StatefulWidget {
  final void Function(int) onComplete;
  const ColorFillGame({super.key, required this.onComplete});
  @override
  State<ColorFillGame> createState() => _ColorFillGameState();
}

class _ColorFillGameState extends State<ColorFillGame> {
  static const _rows = 5, _cols = 5, _total = _rows * _cols;
  late List<Color?> _filled;
  int _score = 0, _timeLeft = 50;
  Timer? _timer;
  int _selectedColorIdx = 0;

  final _palette = [
    const Color(0xFFFF8FAB),
    const Color(0xFFFFD166),
    const Color(0xFF06D6A0),
    const Color(0xFF118AB2),
    const Color(0xFFAF87FF),
    const Color(0xFFFF6B6B),
    const Color(0xFF95E1D3),
    const Color(0xFFF3A712),
  ];

  @override
  void initState() {
    super.initState();
    _filled = List.filled(_total, null);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _timeLeft--);
      if (_timeLeft <= 0 || _filled.every((c) => c != null)) {
        _timer?.cancel();
        widget.onComplete(_score);
      }
    });
  }

  void _fillCell(int i) {
    CalmAudio.chime();
    setState(() {
      _filled[i] = _palette[_selectedColorIdx];
      _score += 5;
    });
    if (_filled.every((c) => c != null)) {
      CalmAudio.tadaSound();
      _timer?.cancel();
      widget.onComplete(_score);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filled = _filled.where((c) => c != null).length;
    return GameWrapper(
        child: Column(children: [
      _ScoreBar(score: _score, time: _timeLeft, label: '🎨 Fill the canvas!'),
      const SizedBox(height: 4),
      Text('$filled / $_total cells filled',
          style: GoogleFonts.outfit(color: Colors.white60, fontSize: 12)),
      const SizedBox(height: 10),
      SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _palette.length,
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => setState(() => _selectedColorIdx = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: _palette[i],
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: i == _selectedColorIdx
                          ? Colors.white
                          : Colors.transparent,
                      width: 3),
                  boxShadow: i == _selectedColorIdx
                      ? [
                          BoxShadow(
                              color: _palette[i].withValues(alpha: 0.6),
                              blurRadius: 12)
                        ]
                      : null,
                ),
              ),
            ),
          )),
      const SizedBox(height: 12),
      Expanded(
          child: AspectRatio(
        aspectRatio: 1,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _cols, mainAxisSpacing: 3, crossAxisSpacing: 3),
          itemCount: _total,
          itemBuilder: (_, i) => GestureDetector(
            onTap: () => _fillCell(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: _filled[i] ?? Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1), width: 0.5),
              ),
            ),
          ),
        ),
      )),
    ]));
  }
}

// ─────────────────────────────────────────────
//  SHARED SCORE BAR
// ─────────────────────────────────────────────

class _ScoreBar extends StatelessWidget {
  final int score, time;
  final String label;
  const _ScoreBar(
      {required this.score, required this.time, required this.label});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10)),
            child: Text('⏱ $time',
                style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10)),
            child: Text('⭐ $score',
                style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
      );
} 


// ─────────────────────────────────────────────
//  TERMS SECTION WIDGET
// ─────────────────────────────────────────────

class _TermsSection extends StatelessWidget {
  final String number, title, content;
  const _TermsSection({
    required this.number,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  gradient: ZT.grad,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    number,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    color: ZT.textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 38),
            child: Text(
              content,
              style: GoogleFonts.outfit(
                color: ZT.textMid,
                fontSize: 13,
                height: 1.7,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  END OF ZIVARA
// ============================================================
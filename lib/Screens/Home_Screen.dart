import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rahbar_app/Controller/Alert_Controller.dart';
import 'package:rahbar_app/utils/App_colors.dart';
import 'package:rahbar_app/widget/bottom_navigation.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // Whether the SOS button is armed (dark red, pulsing) or idle (pink).
  bool _isArmed = false;

  // Drives the "hold to send" progress bar while armed and pressed.
  late final AnimationController _holdController;
  static const Duration _holdDuration = Duration(seconds: 2);

  // Drives the pulsing outer rings while armed.
  late final AnimationController _pulseController;

  // Greeting name shown in the top bar. Starts from the Auth
  // displayName (set at signup) so there's no empty flash, then gets
  // refreshed from the user's Firestore doc -- the actual source of
  // truth for 'name' -- once that loads.
  String _greetingName = 'there';

  // Real trusted contacts that are set to be notified, loaded from
  // users/{uid}/trustedContacts -- the same subcollection
  // TrustedContactScreen writes at onboarding and ContactsScreen
  // manages afterwards. Still used here for the "Alerting N contacts"
  // summary card -- AlertController does its OWN fresh fetch of this
  // same subcollection when an alert actually starts, so the two
  // stay independent and the summary card never blocks sending.
  List<String> _notifiedContactNames = [];
  bool _isLoadingContacts = true;

  @override
  void initState() {
    super.initState();
    _holdController = AnimationController(vsync: this, duration: _holdDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _onSosSent();
        }
      });
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _loadUserName();
    _loadNotifiedContacts();
  }

  // Loads only the contacts flagged to be notified -- those are the
  // ones that actually matter for the "who gets alerted" summary.
  // Contacts saved before 'isNotified' existed are treated as notified.
  Future<void> _loadNotifiedContacts() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _isLoadingContacts = false);
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('trustedContacts')
          .orderBy('createdAt')
          .get();

      if (!mounted) return;
      setState(() {
        _notifiedContactNames = snapshot.docs
            .where((d) => d.data()['isNotified'] as bool? ?? true)
            .map((d) => (d.data()['name'] ?? '').toString().trim())
            .where((name) => name.isNotEmpty)
            .toList();
        _isLoadingContacts = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingContacts = false);
    }
  }

  Future<void> _loadUserName() async {
    final user = FirebaseAuth.instance.currentUser;

    // Immediate fallback from the cached Auth profile.
    final fallback = _firstNameFrom(user?.displayName);
    if (fallback != null && mounted) {
      setState(() => _greetingName = fallback);
    }

    final uid = user?.uid;
    if (uid == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final name = _firstNameFrom(doc.data()?['name'] as String?);
      if (mounted && name != null) {
        setState(() => _greetingName = name);
      }
    } catch (_) {
      // Firestore lookup failed -- keep whatever fallback we already have.
    }
  }

  // Trims and returns just the first name, or null if there's nothing usable.
  String? _firstNameFrom(String? fullName) {
    final trimmed = fullName?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed.split(RegExp(r'\s+')).first;
  }

  @override
  void dispose() {
    _holdController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // Single tap toggles armed / disarmed. Only meaningful when not
  // currently mid-hold.
  void _onTap() {
    setState(() => _isArmed = !_isArmed);
    if (!_isArmed) _holdController.reset();
  }

  void _onHoldStart() {
    if (!_isArmed) return;
    _holdController.forward(from: _holdController.value);
  }

  void _onHoldEnd() {
    if (_holdController.isAnimating) {
      _holdController.stop();
      _holdController.reverse();
    }
  }

  void _onSosSent() {
    _holdController.reset();
    setState(() => _isArmed = false);

    // AlertController owns the live GPS stream and the Firestore
    // alert doc -- registered here (not local state) because it must
    // keep running after this screen is gone, e.g. while
    // ActiveAlertScreen is showing. startAlert() does its own fresh
    // Firestore fetch of trusted contacts (including linkedUserId),
    // so no arguments need to be passed in here.
    final alertController = Get.put(AlertController());
    alertController.startAlert();

    // ActiveAlertScreen reads everything live from AlertController via
    // Get.find<AlertController>() -- no navigation arguments needed,
    // since location/elapsed time keep changing after this point.
    Get.toNamed('/active-alert');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 8),

              // ---- Top bar: greeting + avatar ----
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Hi, $_greetingName',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.title,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Get.toNamed('/profile'),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.ringColor,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.person,
                        color: AppColors.primaryPurple,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(flex: 3),

              // ---- SOS button with pulsing rings ----
              GestureDetector(
                onTap: _onTap,
                onLongPressStart: (_) => _onHoldStart(),
                onLongPressEnd: (_) => _onHoldEnd(),
                child: SizedBox(
                  width: 260,
                  height: 260,
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_isArmed) ..._buildPulsingRings(),
                          if (!_isArmed) _buildStaticRings(),
                          child!,
                        ],
                      );
                    },
                    child: _buildCoreButton(),
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // ---- Caption + bottom card, swaps by state ----
              if (!_isArmed) ..._buildIdleFooter() else ..._buildArmedFooter(),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentTab: NavTab.home),
    );
  }

  // ---- Idle state (pink SOS button) ----

  Widget _buildStaticRings() {
    return Container(
      width: 260,
      height: 260,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primaryPurple.withOpacity(0.06),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 210,
        height: 210,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primaryPurple.withOpacity(0.08),
        ),
      ),
    );
  }

  // ---- Armed state (dark red button + expanding pulse rings) ----

  List<Widget> _buildPulsingRings() {
    // Two rings, offset in phase, that scale up and fade out on a loop.
    return [0.0, 0.5].map((offset) {
      final t = (_pulseController.value + offset) % 1.0;
      final scale = 0.55 + (t * 0.45); // grows from 0.55x to 1.0x of 260
      final opacity = (1.0 - t).clamp(0.0, 1.0) * 0.35;
      return Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: 260,
            height: 260,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF7A1F2B),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildCoreButton() {
    return AnimatedBuilder(
      animation: _holdController,
      builder: (context, _) {
        // Slightly grow the core button while holding, for feedback.
        final holdScale = 1.0 + (_holdController.value * 0.05);
        return Transform.scale(
          scale: holdScale,
          child: Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isArmed
                  ? const Color(0xFF5C1620)
                  : const Color(0xFFE14F72),
              boxShadow: [
                BoxShadow(
                  color:
                      (_isArmed
                              ? const Color(0xFF5C1620)
                              : const Color(0xFFE14F72))
                          .withOpacity(0.35),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 34,
                ),
                const SizedBox(height: 6),
                Text(
                  _isArmed ? 'ARMED' : 'SOS',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---- Footers ----

  List<Widget> _buildIdleFooter() {
    return [
      const Text(
        'Tap once to arm, hold to send',
        style: TextStyle(fontSize: 14, color: AppColors.subtitle),
      ),
      const SizedBox(height: 16),
      _buildContactsCard(),
    ];
  }

  // Tappable summary of who actually gets alerted. Opens the Contacts
  // screen, then refreshes on return since contacts may have been
  // added, removed, or toggled while over there.
  Widget _buildContactsCard() {
    return InkWell(
      onTap: () async {
        await Get.toNamed('/contacts');
        _loadNotifiedContacts();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.fieldFill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.fieldBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.ringColor,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.people_alt_rounded,
                size: 18,
                color: AppColors.primaryPurple,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _contactsTitle,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.title,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _contactsSubtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.subtitle,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.subtitle),
          ],
        ),
      ),
    );
  }

  String get _contactsTitle {
    if (_isLoadingContacts) return 'Loading contacts...';
    final count = _notifiedContactNames.length;
    if (count == 0) return 'No contacts yet';
    if (count == 1) return 'Alerting 1 contact';
    return 'Alerting $count contacts';
  }

  String get _contactsSubtitle {
    if (_isLoadingContacts) return '';
    if (_notifiedContactNames.isEmpty) {
      return 'Tap to add someone who gets alerted';
    }
    return _notifiedContactNames.join(', ');
  }

  List<Widget> _buildArmedFooter() {
    return [
      const Text(
        'Press and hold to send alert',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF9B2C3A),
        ),
      ),
      const SizedBox(height: 14),
      AnimatedBuilder(
        animation: _holdController,
        builder: (context, _) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: _holdController.value,
              minHeight: 8,
              backgroundColor: AppColors.ringColor,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFE14F72),
              ),
            ),
          );
        },
      ),
    ];
  }
}

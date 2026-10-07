import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rahbar_app/utils/App_colors.dart';
import 'package:rahbar_app/widget/bottom_navigation.dart';

/// The alerts INBOX: every SOS alert this user was notified about, newest
/// first. Active ones are pinned on top, ended ones listed under "Earlier".
///
/// DELETING: swipe an ended alert to the left (or tap "Clear all") to remove
/// it from YOUR inbox. This only hides it for you -- the alert itself still
/// belongs to the sender and other contacts still see it. The hidden ids are
/// saved in users/{uid}/dismissedAlerts so they stay hidden after restart.
/// Active alerts can't be deleted (you shouldn't miss a live SOS).
///
/// This doubles as the offline inbox: the alert lives in Firestore the
/// moment it is raised, whether or not this phone was reachable.
///
/// No Firestore index needed: we filter with array-contains only and sort
/// on the phone.
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  /// Ids hidden right now, before Firestore echoes the change back. Needed
  /// because a swiped-away Dismissible must leave the tree immediately.
  final Set<String> _hiddenNow = {};

  CollectionReference<Map<String, dynamic>> _dismissedRef(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('dismissedAlerts');

  Future<void> _dismiss(String uid, List<String> alertIds) async {
    setState(() => _hiddenNow.addAll(alertIds));
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final id in alertIds) {
        batch.set(_dismissedRef(uid).doc(id), {
          'at': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (_) {
      if (!mounted) return;
      setState(() => _hiddenNow.removeAll(alertIds));
      Get.snackbar(
        'Could not delete',
        'Check your connection and try again.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              action,
              style: const TextStyle(color: AppColors.alertDanger),
            ),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const _Shell(
        child: Center(
          child: Text(
            'Please sign in to see alerts.',
            style: TextStyle(color: AppColors.subtitle),
          ),
        ),
      );
    }

    // Outer stream: which alerts this user already deleted.
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _dismissedRef(uid).snapshots(),
      builder: (context, dismissedSnap) {
        final dismissedIds = <String>{
          ...?dismissedSnap.data?.docs.map((d) => d.id),
          ..._hiddenNow,
        };

        // Inner stream: every alert this user was notified about.
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('alerts')
              .where('notifiedUserIds', arrayContains: uid)
              .snapshots(),
          builder: (context, snap) {
            final isLoading = snap.connectionState == ConnectionState.waiting;

            // Newest first. A just-created alert can briefly have a null
            // startedAt (server timestamp not resolved yet) -- treat as
            // "now".
            final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
                List.of(
                  snap.data?.docs ??
                      <QueryDocumentSnapshot<Map<String, dynamic>>>[],
                )..removeWhere((d) => dismissedIds.contains(d.id));

            docs.sort((a, b) {
              final ta =
                  (a.data()['startedAt'] as Timestamp?)?.toDate() ??
                  DateTime.now();
              final tb =
                  (b.data()['startedAt'] as Timestamp?)?.toDate() ??
                  DateTime.now();
              return tb.compareTo(ta);
            });

            // "Active" = status active AND started within the last 3 hours.
            // An alert still marked active after that was almost certainly
            // forgotten (sender's app closed before End was tapped).
            bool isActive(QueryDocumentSnapshot<Map<String, dynamic>> d) {
              final data = d.data();
              if ((data['status'] as String? ?? 'active') != 'active') {
                return false;
              }
              final started = (data['startedAt'] as Timestamp?)?.toDate();
              return started == null ||
                  DateTime.now().difference(started) < const Duration(hours: 3);
            }

            final active = docs.where(isActive).toList();
            final earlier = docs.where((d) => !isActive(d)).toList();
            final hasActiveAlerts = active.isNotEmpty;

            Widget cardFor(
              QueryDocumentSnapshot<Map<String, dynamic>> doc, {
              required bool activeNow,
            }) {
              final card = _AlertCard(
                alertId: doc.id,
                senderId: doc.data()['senderId'] as String?,
                senderName: doc.data()['senderName'] as String?,
                isActive: activeNow,
                when: (doc.data()['startedAt'] as Timestamp?)?.toDate(),
              );
              // Live alerts are not swipe-deletable.
              if (activeNow) return card;

              return Dismissible(
                key: ValueKey('alert-${doc.id}'),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) => _confirm(
                  title: 'Delete this alert?',
                  message: 'It will be removed from your alerts list.',
                  action: 'Delete',
                ),
                onDismissed: (_) => _dismiss(uid, [doc.id]),
                background: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  alignment: Alignment.centerRight,
                  decoration: BoxDecoration(
                    color: AppColors.alertDanger,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.delete_outline,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                child: card,
              );
            }

            return Scaffold(
              backgroundColor: AppColors.background,
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      const Text(
                        'Alerts',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.title,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primaryPurple,
                                ),
                              )
                            : docs.isEmpty
                            ? const Center(
                                child: Text(
                                  'No alerts yet.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.subtitle,
                                  ),
                                ),
                              )
                            : ListView(
                                children: [
                                  if (active.isNotEmpty) ...[
                                    const _SectionLabel('Active now'),
                                    for (final doc in active)
                                      cardFor(doc, activeNow: true),
                                  ],
                                  if (earlier.isNotEmpty) ...[
                                    Row(
                                      children: [
                                        const Expanded(
                                          child: _SectionLabel('Earlier'),
                                        ),
                                        TextButton(
                                          onPressed: () async {
                                            final ok = await _confirm(
                                              title: 'Clear all earlier?',
                                              message:
                                                  'All ended alerts will be removed from your list.',
                                              action: 'Clear all',
                                            );
                                            if (ok) {
                                              _dismiss(uid, [
                                                for (final d in earlier) d.id,
                                              ]);
                                            }
                                          },
                                          child: const Text(
                                            'Clear all',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.alertDanger,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    for (final doc in earlier)
                                      cardFor(doc, activeNow: false),
                                  ],
                                  const SizedBox(height: 12),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              bottomNavigationBar: BottomNavBar(
                currentTab: NavTab.alerts,
                showAlertBadge: hasActiveAlerts,
              ),
            );
          },
        );
      },
    );
  }
}

/// Small shell used only for the "not signed in" early-return state.
class _Shell extends StatelessWidget {
  final Widget child;
  const _Shell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: child),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: AppColors.subtitle,
        ),
      ),
    );
  }
}

/// One inbox row. Active alerts are red; ended ones are muted and show
/// when they happened.
class _AlertCard extends StatelessWidget {
  final String alertId;
  final String? senderId;
  final String? senderName;
  final bool isActive;
  final DateTime? when;

  const _AlertCard({
    required this.alertId,
    required this.senderId,
    required this.senderName,
    required this.isActive,
    required this.when,
  });

  void _openAlert() {
    Get.toNamed('/incoming-alert', arguments: {'alertId': alertId});
  }

  static String _initialsFrom(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// "Today, 14:32" / "Yesterday, 09:10" / "5 Oct, 21:45".
  static String _whenLabel(DateTime? t) {
    if (t == null) return '';
    final local = t.toLocal();
    final now = DateTime.now();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');

    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final diff = today.difference(day).inDays;

    if (diff == 0) return 'Today, $hh:$mm';
    if (diff == 1) return 'Yesterday, $hh:$mm';
    return '${local.day} ${_months[local.month - 1]}, $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    if (senderId == null) return const SizedBox.shrink();

    final accent = isActive ? AppColors.alertDanger : AppColors.subtitle;

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(senderId)
          .get(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final stored = senderName?.trim();
        final fetched = (data?['name'] as String?)?.trim();
        final name = (stored != null && stored.isNotEmpty)
            ? stored
            : (fetched != null && fetched.isNotEmpty)
            ? fetched
            : 'Someone';
        final initials = _initialsFrom(name);

        final statusText = isActive
            ? 'SOS active'
            : 'Ended${when != null ? ' · ${_whenLabel(when)}' : ''}';

        return InkWell(
          onTap: _openAlert,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.fieldFill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActive
                    ? AppColors.alertDanger.withOpacity(0.35)
                    : AppColors.fieldBorder,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive
                        ? AppColors.alertDanger
                        : AppColors.subtitle.withOpacity(0.55),
                  ),
                  alignment: Alignment.center,
                  child:
                      snap.connectionState == ConnectionState.waiting &&
                          (stored == null || stored.isEmpty)
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.title,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 13,
                          color: accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.subtitle),
              ],
            ),
          ),
        );
      },
    );
  }
}

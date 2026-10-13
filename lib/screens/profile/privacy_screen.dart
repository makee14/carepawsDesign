import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../data/models.dart';
import '../../data/seed.dart';
import '../../design/icons.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../state/app_store.dart';
import '../../widgets/common.dart';

/// Privacy: data export, delete account with the iOS system-style alert.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return CupertinoPageScaffold(
      backgroundColor: p.background,
      navigationBar: const DetailNavBar(title: 'Privacy'),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  SoftCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Ic.svg(Ic.shield, color: p.accent, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Your records, your control', style: Type.headline(p)),
                              const SizedBox(height: 6),
                              Text(
                                'Pet records, visit notes and orders stay on your account. '
                                'Export a copy any time, or delete the account and everything in it.',
                                style: Type.body(p).copyWith(color: p.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: T.s20),
                  Text('Your data', style: Type.headline(p)),
                  const SizedBox(height: 10),
                  SoftCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        RowTile(
                          title: 'Export my data',
                          subtitle: 'Pets, visits, orders and prescriptions as JSON',
                          leadingPath: Ic.download,
                          onTap: () => Navigator.of(context).push(
                            appRoute(const ExportScreen()),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: T.s20),
                  Text('Danger zone', style: Type.headline(p)),
                  const SizedBox(height: 10),
                  SoftCard(
                    padding: EdgeInsets.zero,
                    borderColor: p.destructive.withValues(alpha: 0.3),
                    child: Column(
                      children: [
                        RowTile(
                          title: 'Delete account',
                          subtitle: 'Permanently removes pets, appointments and orders',
                          leadingPath: Ic.trash,
                          destructive: true,
                          onTap: () => _deleteAccount(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final store = AppScope.read(context);
    // iOS system-style alert; Delete in systemRed, Cancel is the default.
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete account?'),
        content: const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text(
            'This permanently removes your pets, appointments, and orders.',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    // Prototype behaviour: clear local data and confirm in-app.
    store.clearPets();
    store.orders = [];
    store.appointments = store.appointments.where((a) => a.status.isActive).toList();
    if (!context.mounted) return;
    dismissSheet(context);
    if (!context.mounted) return;
    await showAppSheet(
      context,
      scrollable: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Ic.svg(Ic.checkCircle, color: context.p.success, size: 40, stroke: 1.9),
            const SizedBox(height: 12),
            Text('Account deleted', style: Type.headline(context.p), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Your pets, appointments and orders have been removed from this device.',
              style: Type.body(context.p).copyWith(color: context.p.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: T.s20),
            PrimaryButton(
              label: 'OK',
              onPressed: () => dismissSheet(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// Data export — a real JSON preview with a share/copy action.
class ExportScreen extends StatelessWidget {
  const ExportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.p;
    final json = _buildJson(store);

    return CupertinoPageScaffold(
      backgroundColor: p.background,
      navigationBar: const DetailNavBar(title: 'Export my data'),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Ic.svg(Ic.doc, color: p.accent, size: 20),
                            const SizedBox(width: 10),
                            Expanded(child: Text('Your export', style: Type.headline(p))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'A machine-readable copy of everything PetCare holds for ${Seed.ownerName}. '
                          'Generated ${shortDate(store.now)}.',
                          style: Type.body(p).copyWith(color: p.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: T.s16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: p.surfaceAlt,
                      borderRadius: BorderRadius.circular(T.rCard),
                      border: Border.all(color: p.divider),
                    ),
                    child: Text(
                      json,
                      style: Type.caption(p).copyWith(
                        fontFamily: 'monospace',
                        color: p.text,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            StickyCta(
              child: PrimaryButton(
                label: 'Copy to clipboard',
                icon: Ic.bookmark,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: json));
                  if (!context.mounted) return;
                  await showAppSheet(
                    context,
                    scrollable: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Ic.svg(Ic.checkCircle, color: context.p.success, size: 40, stroke: 1.9),
                          const SizedBox(height: 12),
                          Text('Copied', style: Type.headline(context.p)),
                          const SizedBox(height: 8),
                          Text(
                            'Your data export is on the clipboard. Paste it anywhere.',
                            style: Type.footnote(context.p),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: T.s20),
                          PrimaryButton(
                            label: 'Done',
                            onPressed: () => dismissSheet(context),
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
    );
  }

  static String _buildJson(AppStore store) {
    final data = {
      'account': {
        'name': Seed.ownerName,
        'contact': Seed.ownerContact,
        'exported': isoDay(store.now),
      },
      'pets': [
        for (final pet in store.pets)
          {
            'name': pet.name,
            'species': pet.species.name,
            'breed': pet.breed,
            'birth_date': isoDay(pet.birthDate),
            'weight_kg': pet.weightKg,
            'microchip': pet.microchip,
            'allergies': pet.allergies,
            'documents': [for (final d in pet.docs) d.name],
          },
      ],
      'appointments': [
        for (final a in store.appointments)
          {
            'id': a.id,
            'pet': store.pet(a.petId)?.name,
            'service': store.serviceOf(a.serviceId).name,
            'staff': store.staffOf(a.staffId).name,
            'when': mediumDate(a.start),
            'status': a.status.label,
            'total': a.price,
          },
      ],
      'orders': [
        for (final o in store.orders)
          {
            'id': o.id,
            'placed': mediumDate(o.placedAt),
            'status': o.status.label,
            'total': o.total,
            'pickup_code': o.pickupCode,
          },
      ],
      'prescriptions': [
        for (final r in store.prescriptions)
          {
            'product': store.productOf(r.productId).name,
            'signed_by': r.vetName,
            'expires': isoDay(r.expires),
            'refills': r.refills,
          },
      ],
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }
}

enum LegalKind { terms, privacy }

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.kind});
  final LegalKind kind;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final sections = kind == LegalKind.terms
        ? const [
            (
              'Using PetCare',
              'PetCare is a veterinary clinic app. Bookings, health checks and chat are provided by '
                  'the clinic team, and the AI assistant gives general guidance only — never a diagnosis.',
            ),
            (
              'Appointments',
              'Routine bookings confirm immediately. Visits for a sick pet are submitted as a request '
                  'and confirmed by the vet assistant during clinic hours. You can cancel or reschedule '
                  'at any time before the appointment.',
            ),
            (
              'Pricing',
              'Consultation and vaccination prices are fixed. Grooming is charged from an estimated or '
                  'starting price, and the final amount is confirmed at the counter after a coat assessment.',
            ),
            (
              'Shop orders',
              'All orders are collected at the clinic counter. We do not deliver. Paid orders are held '
                  'for 7 days; unpaid orders are released after 24 hours.',
            ),
          ]
        : const [
            (
              'What we collect',
              'Your contact details, pet records, appointment history, chat messages with the clinic, '
                  'and orders you place. We do not sell your data.',
            ),
            (
              'AI assistance',
              'When you run a health check, the text and any photo you attach are sent to the configured '
                  'AI model to generate guidance. If no key is configured, the request is handled locally '
                  'by a built-in responder and nothing leaves your device.',
            ),
            (
              'Your choices',
              'Export everything we hold at any time from Privacy, or delete your account and all of its '
                  'records. Deleting is permanent.',
            ),
            (
              'Payments',
              'Card and GCash details are processed by the payment provider. PetCare stores only the '
                  'method and the resulting order status.',
            ),
          ];

    return CupertinoPageScaffold(
      backgroundColor: p.background,
      navigationBar: DetailNavBar(
        title: kind == LegalKind.terms ? 'Terms of service' : 'Privacy policy',
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            Text(
              kind == LegalKind.terms
                  ? 'Last updated 1 October 2026 · Applies to PetCare ${Seed.appVersion}'
                  : 'Last updated 1 October 2026 · Applies to PetCare ${Seed.appVersion}',
              style: Type.footnote(p),
            ),
            const SizedBox(height: T.s16),
            for (final s in sections)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.$1, style: Type.headline(p)),
                      const SizedBox(height: 6),
                      Text(s.$2, style: Type.body(p)),
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
import 'package:flutter/cupertino.dart';

import '../../app.dart';
import '../../data/seed.dart';
import '../../design/icons.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../state/app_store.dart';
import '../../widgets/common.dart';

/// About: brand, version, build metadata.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.p;

    return CupertinoPageScaffold(
      backgroundColor: p.background,
      navigationBar: const DetailNavBar(title: 'About'),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          children: [
            const Center(child: LogoMark(size: 104)),
            const SizedBox(height: T.s20),
            Text('CAREPAWS', style: Type.largeTitle(p).copyWith(letterSpacing: 4)),
            const SizedBox(height: 4),
            Text(
              'Veterinary Clinic',
              style: Type.footnote(p).copyWith(letterSpacing: 1.4, color: p.accentText),
            ),
            const SizedBox(height: 6),
            Text(
              Seed.appVersion,
              style: Type.caption(p),
            ),
            const SizedBox(height: T.s24),
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('The clinic', style: Type.headline(p)),
                  const SizedBox(height: 8),
                  Text(
                    'A full-service neighbourhood vet in Mandaluyong: consultations, vaccinations, '
                    'microchipping and grooming, with same-day health checks when your pet needs them.',
                    style: Type.body(p).copyWith(color: p.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Text(Seed.clinicAddress, style: Type.footnote(p)),
                  const SizedBox(height: 4),
                  Text(Seed.clinicPhone, style: Type.footnote(p)),
                ],
              ),
            ),
            const SizedBox(height: T.s16),
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('In this build', style: Type.headline(p)),
                  const SizedBox(height: 10),
                  _BuildRow(
                    icon: Ic.sparkle,
                    label: 'CarePaws AI',
                    value: store.ai.isLive
                        ? 'Live · ${store.ai.modelLabel ?? 'auto-selected model'}'
                        : 'Unavailable · no API key',
                  ),
                  _BuildRow(icon: Ic.checkCircle, label: 'Clinic hours', value: clinicStatusLine(store.now)),
                  _BuildRow(icon: Ic.paw, label: 'Pets on file', value: '${store.petCount}'),
                  _BuildRow(icon: Ic.calendar, label: 'Upcoming visits', value: '${store.upcoming.length}'),
                  _BuildRow(icon: Ic.bag, label: 'Orders', value: '${store.orders.length}'),
                ],
              ),
            ),
            const SizedBox(height: T.s16),
            SoftCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Ic.svg(Ic.info, color: p.textSecondary, size: 17),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Prototype build for testing. Sample pets, staff, products and orders are '
                      'fictional; no real patient data is stored.',
                      style: Type.footnote(p),
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
}

class _BuildRow extends StatelessWidget {
  const _BuildRow({required this.icon, required this.label, required this.value});
  final String icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Ic.svg(icon, color: p.accent, size: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: Type.footnote(p)),
                Text(value, style: Type.footnoteEmph(p)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
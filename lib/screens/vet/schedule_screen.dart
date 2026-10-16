import 'package:flutter/cupertino.dart';

import '../../app.dart'
    show LargeTitleBar, dayMonth, dayNames, isToday, shortDate;
import '../../data/clinic.dart';
import '../../data/models.dart';
import '../../design/icons.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../state/app_store.dart';
import '../../widgets/common.dart';
import 'widgets/schedule_card.dart';

/// Groups appointments by calendar day (local midnight key); each day's list
/// is sorted by start time.
Map<DateTime, List<Appointment>> groupAppointmentsByDay(
  List<Appointment> appointments,
) {
  final map = <DateTime, List<Appointment>>{};
  for (final a in appointments) {
    final day = DateTime(a.start.year, a.start.month, a.start.day);
    (map[day] ??= []).add(a);
  }
  for (final list in map.values) {
    list.sort((x, y) => x.start.compareTo(y.start));
  }
  return map;
}

/// SCHEDULE — the vet's day view: a day strip (today selected by default),
/// then every appointment on the selected day with confirm / reschedule /
/// cancel / status-advance / staff-assign actions.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late DateTime _selected;
  late final ScrollController _stripController;

  /// 7 days back, today, 13 forward — the vet can review the recent past and
  /// plan the near future from one strip.
  static List<DateTime> _stripDays(DateTime today) =>
      List.generate(21, (i) => today.add(Duration(days: i - 7)));

  @override
  void initState() {
    super.initState();
    final now = AppScope.read(context).now;
    final today = DateTime(now.year, now.month, now.day);
    _selected = today;
    _stripController = ScrollController(initialScrollOffset: 6 * 64);
    // At large Dynamic Type sizes the day cells widen (see _DayCell); nudge
    // the strip so the selected day stays in view. At 1x the initial offset
    // is already exact.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_stripController.hasClients) return;
      final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
      if (scale <= 1.0) return;
      _stripController.jumpTo(7 * 64 * scale);
    });
  }

  @override
  void dispose() {
    _stripController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final store = AppScope.of(context);
    final now = store.now;
    final today = DateTime(now.year, now.month, now.day);
    final grouped = groupAppointmentsByDay(store.appointments);
    final dayAppointments = grouped[_selected] ?? const <Appointment>[];
    final sunday = _selected.weekday == DateTime.sunday;

    return CupertinoPageScaffold(
      backgroundColor: p.background,
      child: CustomScrollView(
        slivers: [
          const LargeTitleBar(title: 'Schedule'),
          // The strip sizes itself to the tallest day cell (intrinsic height):
          // at large Dynamic Type sizes the cells grow instead of clipping,
          // and no hand-computed height can drift out of sync with the text.
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              controller: _stripController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: T.s16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final day in _stripDays(today)) ...[
                    _DayCell(
                      day: day,
                      selected: day == _selected,
                      isToday: isToday(day, now),
                      onTap: () => setState(() => _selected = day),
                    ),
                    const SizedBox(width: T.s8),
                  ],
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(T.s16, T.s16, T.s16, 0),
              child: SectionHeader(
                title:
                    '${Clinic.weekdayName(_selected.weekday)}, ${dayMonth(_selected)}',
                padding: EdgeInsets.zero,
              ),
            ),
          ),
          if (sunday)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Ic.moon,
                title: 'Closed on Sundays',
                body: 'The clinic is closed on Sundays. ${Clinic.hoursLabel}.',
              ),
            )
          else if (dayAppointments.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Ic.calendar,
                title: 'No appointments',
                body: isToday(_selected, now)
                    ? 'Nothing scheduled for today yet.'
                    : 'Nothing scheduled for this day yet.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(T.s16, T.s12, T.s16, T.s12),
              sliver: SliverList.separated(
                itemCount: dayAppointments.length,
                separatorBuilder: (_, _) => const SizedBox(height: T.s12),
                itemBuilder: (ctx, i) {
                  final a = dayAppointments[i];
                  return VetScheduleCard(
                    key: ValueKey(a.id),
                    appointment: a,
                    store: store,
                  );
                },
              ),
            ),
          // Room for the floating tab bar under the last card.
          SliverToBoxAdapter(
            child: SizedBox(height: TabBarClearance.of(context)),
          ),
        ],
      ),
    );
  }
}

/// One day in the strip. The semantics label is the contract the tests pin:
/// 'Sat, 17 Oct' / 'Sat, 17 Oct, selected' — an exact label (children
/// excluded) so the finder can't merge with a sibling node.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.isToday,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final sunday = day.weekday == DateTime.sunday;
    final label = '${shortDate(day)}${selected ? ', selected' : ''}';
    final fg = selected
        ? (p.isDark ? T.espresso : T.card)
        : sunday
        ? p.textSecondary
        : p.text;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        child: PressScale(
          onTap: onTap,
          scale: 0.96,
          child: Opacity(
            opacity: sunday && !selected ? 0.75 : 1,
            // AX5: the cell widens with Dynamic Type instead of clipping the
            // weekday/number. T.scale clamps the growth to 1.6x, so the strip
            // stays a strip. Pixel-identical at 1x.
            child: Container(
              width: Layout.scale(context, 56),
              padding: EdgeInsets.symmetric(vertical: Layout.scale(context, 8)),
              decoration: BoxDecoration(
                color: selected ? p.accent : p.surface,
                borderRadius: BorderRadius.circular(T.s16),
                border: selected
                    ? null
                    : Border.all(color: isToday ? p.accentText : p.divider),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dayNames[day.weekday - 1],
                    style: Type.caption(p).copyWith(
                      color: fg,
                      fontWeight: isToday ? FontWeight.w700 : null,
                    ),
                  ),
                  Text('${day.day}', style: Type.title3(p).copyWith(color: fg)),
                  SizedBox(
                    height: 14,
                    child: sunday
                        ? Text(
                            'Closed',
                            style: Type.caption2(p)
                                .copyWith(color: fg.withValues(alpha: 0.8)),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/cupertino.dart';

import '../../app.dart';
import '../../data/models.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../widgets/common.dart';

// STREAM-B CONTRACT STUB — Stream C owns the real HealthCheckResultSheet
// (plan task C4: lib/screens/triage/health_result_sheet.dart). This minimal
// stub exists only so Stream B's clinic-chat result button (B7) compiles and
// runs against the B↔C contract before C merges. AT MERGE: delete this file
// in favor of Stream C's version (both branches add the same path —
// resolve the both-added conflict with C's file).

/// Opens the latest AI Health Check result for a pet.
class HealthCheckResultSheet {
  const HealthCheckResultSheet._();

  static Future<void> show(BuildContext context, HealthCheckResult result) {
    return showAppSheet(context, child: _StubResultBody(result: result));
  }
}

class _StubResultBody extends StatelessWidget {
  const _StubResultBody({required this.result});
  final HealthCheckResult result;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Health check result', style: Type.title2(p)),
          const SizedBox(height: 8),
          StatusChip(label: result.urgency.name, compact: true),
          const SizedBox(height: 8),
          Text(result.summary, style: Type.body(p)),
          const SizedBox(height: 8),
          Text(result.recommendation, style: Type.footnote(p)),
          const SizedBox(height: T.s16),
          PrimaryButton(label: 'Done', onPressed: () => dismissSheet(context)),
        ],
      ),
    );
  }
}

import 'package:flutter/cupertino.dart';

import '../design/icons.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../services/ai_service.dart';
import 'common.dart';

/// Shared "AI unavailable" card. Rendered wherever the assistant would have
/// answered — the AI chat thread, the triage screen, and the booking AI step —
/// and states exactly what went wrong plus what to do. Never a dead end: it
/// always offers working alternatives.
class AiUnavailableCard extends StatelessWidget {
  const AiUnavailableCard({
    super.key,
    required this.failure,
    required this.onOpenSettings,
    this.onBook,
    required this.onCall,
  });

  final AiFailure failure;
  final VoidCallback onOpenSettings;

  /// Omitted on screens that are already about booking.
  final VoidCallback? onBook;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final book = onBook;
    return Semantics(
      label: 'PetCare AI is unavailable. ${failure.label}. ${failure.hint}',
      child: ExcludeSemantics(
        child: SoftCard(
          color: T.amber.withValues(alpha: 0.12),
          borderColor: p.accent.withValues(alpha: 0.3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Ic.svg(Ic.sparkle, color: p.warning, size: 18),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text('PetCare AI is unavailable', style: Type.headline(p)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${failure.label}. ${failure.hint}',
                style: Type.body(p).copyWith(color: p.textSecondary),
              ),
              const SizedBox(height: T.s16),
              PrimaryButton(
                label: 'Add an API key',
                icon: Ic.sparkle,
                compact: true,
                onPressed: onOpenSettings,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (book != null) ...[
                    Expanded(
                      child: SecondaryButton(
                        label: 'Book a visit',
                        icon: Ic.calendar,
                        onPressed: book,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: SecondaryButton(
                      label: 'Call the clinic',
                      icon: Ic.phone,
                      onPressed: onCall,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Plain-text version of the unavailable state for chat bubbles.
String aiUnavailableText(AiFailure failure) => switch (failure) {
  AiFailure.noKey =>
    'PetCare AI is unavailable — no API key is configured. Paste a key in Settings → PetCare AI to turn it on. You can still book a visit or call the clinic in the meantime.',
  AiFailure.unreachable =>
    "PetCare AI is unavailable — I couldn't reach the AI service. Check your connection and try again, or book a visit / call the clinic if it can't wait.",
  AiFailure.serviceError =>
    'PetCare AI is unavailable — the AI service returned an error. The key may be invalid; try pasting a fresh one in Settings → PetCare AI.',
};

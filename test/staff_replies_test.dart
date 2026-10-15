import 'package:carepaws/data/models.dart';
import 'package:carepaws/services/staff_replies.dart';
import 'package:flutter_test/flutter_test.dart';

/// Unit tests for the clinic team's dynamic reply composer (B5).
///
/// Each reply must reference the user's specific inquiry and stay in role —
/// the opposite of the old hardcoded auto-responses.
void main() {
  group('composeStaffReply', () {
    test('grooming question to the assistant routes to Ana', () {
      final r = composeStaffReply(
        role: StaffRole.vetAssistant,
        userText: 'How much is a full groom for Biscuit?',
        petName: 'Biscuit',
        clinicOpen: true,
      );
      expect(r, contains('Ana'));
      expect(r, contains('Biscuit'));
    });

    test('groomer answers nail questions directly', () {
      final r = composeStaffReply(
        role: StaffRole.groomer,
        userText: 'Does Mochi need an appointment for nail trimming?',
        petName: 'Mochi',
        clinicOpen: true,
      );
      expect(r, contains('No appointment needed for nails'));
      expect(r, contains('Mochi'));
    });

    test('groomer quotes the seed full-groom price when asked', () {
      final r = composeStaffReply(
        role: StaffRole.groomer,
        userText: 'How much is a full groom?',
        petName: 'Biscuit',
        clinicOpen: true,
      );
      // Matches Seed.services sv4 (Full Grooming) — the booking flow's price.
      expect(r, contains('₱1450'));
    });

    test('booking question names the mentioned day', () {
      final r = composeStaffReply(
        role: StaffRole.vetAssistant,
        userText: "Can I move Luna's checkup to Friday?",
        petName: 'Luna',
        clinicOpen: true,
      );
      expect(r, contains('Friday'));
      expect(r, contains('Luna'));
    });

    test('cancel beats day detection', () {
      final r = composeStaffReply(
        role: StaffRole.vetAssistant,
        userText: 'Cancel my Friday appointment',
        petName: 'Luna',
        clinicOpen: true,
      );
      expect(r, contains('No problem'));
      expect(r, isNot(contains('Friday works')));
    });

    test('vet answers symptoms calmly: one follow-up, never alarming', () {
      final r = composeStaffReply(
        role: StaffRole.vet,
        userText: 'Biscuit has been scratching a lot since yesterday',
        petName: 'Biscuit',
        clinicOpen: true,
      );
      expect(r, contains('scratching'));
      expect(r, contains('redness'));
      expect(r, contains('Biscuit'));
      // Never anxiety-inducing, never a remote diagnosis.
      expect(r.toLowerCase(), isNot(contains('emergency')));
      expect(r.toLowerCase(), isNot(contains('serious')));
      expect(r.toLowerCase(), isNot(contains('diagnos')));
    });

    test('assistant flags symptoms for the vet', () {
      final r = composeStaffReply(
        role: StaffRole.vetAssistant,
        userText: 'Mochi is limping on her back leg',
        petName: 'Mochi',
        clinicOpen: true,
      );
      expect(r, contains('Dr. Alvarez'));
      expect(r, contains('limping'));
    });

    test('groomer routes symptoms to the vet', () {
      final r = composeStaffReply(
        role: StaffRole.groomer,
        userText: 'Biscuit is limping on his back leg',
        petName: 'Biscuit',
        clinicOpen: true,
      );
      expect(r, contains('Dr. Alvarez'));
    });

    test('hours question gets hours, open vs closed', () {
      final open = composeStaffReply(
        role: StaffRole.vetAssistant,
        userText: 'What are your hours?',
        petName: 'Biscuit',
        clinicOpen: true,
      );
      expect(open, contains('open now until 6:00 PM'));

      final closed = composeStaffReply(
        role: StaffRole.vetAssistant,
        userText: 'What are your hours?',
        petName: 'Biscuit',
        clinicOpen: false,
      );
      expect(closed, contains('back at 9:00 AM'));
    });

    test('photo receipt references the pet', () {
      final r = composeStaffReply(
        role: StaffRole.vetAssistant,
        userText: '',
        petName: 'Mochi',
        clinicOpen: true,
        photoSent: true,
      );
      expect(r, contains('Photo received'));
      expect(r, contains('Mochi'));
    });

    test('health-check handoff is acknowledged with the pet name', () {
      final r = composeStaffReply(
        role: StaffRole.vetAssistant,
        userText: 'health check handoff: Skin irritation',
        petName: 'Biscuit',
        clinicOpen: true,
      );
      expect(r, contains('health check'));
      expect(r, contains('Biscuit'));
    });

    test('default reply is warm and names the pet', () {
      final r = composeStaffReply(
        role: StaffRole.vetAssistant,
        userText: 'Do you sell birthday cakes for dogs?',
        petName: 'Biscuit',
        clinicOpen: true,
      );
      expect(r, contains('Biscuit'));
    });

    test('closed variant never promises an immediate reply', () {
      final r = composeStaffReply(
        role: StaffRole.vet,
        userText: 'Biscuit vomited twice this morning',
        petName: 'Biscuit',
        clinicOpen: false,
      );
      expect(r, contains('back at 9:00 AM'));
      expect(r, contains('vomiting'));
    });
  });

  group('authorForRole', () {
    test('maps each role to its chat author', () {
      expect(authorForRole(StaffRole.vet), ChatAuthor.vet);
      expect(authorForRole(StaffRole.vetAssistant), ChatAuthor.vetAssistant);
      expect(authorForRole(StaffRole.groomer), ChatAuthor.groomer);
    });
  });
}

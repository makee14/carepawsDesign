import 'dart:typed_data';

import 'package:carepaws/data/models.dart';
import 'package:carepaws/state/app_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// F1 regression tests for the data-loss bug Mark reported: after
/// backgrounding the app, things he saved (pet's new name, new pet photo)
/// were gone. Everything the user saves must survive backgrounding, process
/// death and a cold start.
///
/// These tests model "process death + cold start" by throwing the store away
/// and building a fresh [AppStore] over the same mocked [SharedPreferences]
/// backing — exactly what an OS kill + relaunch does to on-device state.
Pet _testPet({required String id, String name = 'Biscuit'}) => Pet(
  id: id,
  name: name,
  species: Species.dog,
  breed: 'Puspin',
  sex: 'Male',
  birthDate: DateTime(2022, 5, 1),
  weightKg: 12.0,
  color: Colors.orange,
  microchip: 'chip-1',
  allergies: const [],
  vitals: const [],
  timeline: const [],
  docs: const [],
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<AppStore> signedInStore() async {
    final s = AppStore();
    expect(await s.register('Mark', 'mark@test.com', 'password1'), isTrue);
    expect(await s.signIn('mark@test.com', 'password1'), isTrue);
    return s;
  }

  group('registered account', () {
    test('pet rename survives process death + cold start', () async {
      final s1 = await signedInStore();
      const id = 'pet-1';
      s1.addPet(_testPet(id: id));
      final renamed = s1.pet(id)!;
      s1.updatePet(
        Pet(
          id: renamed.id,
          name: 'Browsi',
          species: renamed.species,
          breed: renamed.breed,
          sex: renamed.sex,
          birthDate: renamed.birthDate,
          weightKg: 13.5,
          color: renamed.color,
          microchip: renamed.microchip,
          allergies: renamed.allergies,
          vitals: renamed.vitals,
          timeline: renamed.timeline,
          docs: renamed.docs,
        ),
      );
      await s1.flushPersistence();

      // Process death: new store, same on-device state.
      final s2 = AppStore();
      await s2.loadSettings();
      await s2.loadPhotos();

      expect(s2.signedIn, isTrue, reason: 'session must survive');
      expect(s2.pet(id)?.name, 'Browsi', reason: 'renamed pet survives');
      expect(s2.pet(id)?.weightKg, 13.5);
    });

    test('pet photo survives process death + cold start', () async {
      final s1 = await signedInStore();
      const id = 'pet-1';
      s1.addPet(_testPet(id: id));
      final bytes = Uint8List.fromList(List.generate(64, (i) => i));
      await s1.setPetPhoto(id, bytes);
      await s1.flushPersistence();

      final s2 = AppStore();
      await s2.loadSettings();
      await s2.loadPhotos();

      expect(s2.pet(id)?.hasPhoto, isTrue, reason: 'photo survives');
      expect(s2.pet(id)?.photo, bytes);
    });

    test(
      'appointment + reminder + cart survive process death + cold start',
      () async {
        final s1 = await signedInStore();
        const id = 'pet-1';
        s1.addPet(_testPet(id: id));
        s1.addAppointment(
          Appointment(
            id: 'appt-1',
            petId: id,
            serviceId: 'svc_checkup',
            staffId: 'st_vet',
            start: DateTime(2026, 10, 20, 10),
            durationMinutes: 30,
            status: ApptStatus.booked,
            price: 500,
          ),
        );
        s1.toggleReminder('rem_med_biscuit', true);
        s1.addToCart('pr1', 2);
        s1.pushMessage(
          ChatMessage(
            id: 'm1',
            threadId: 'th_clinic',
            author: ChatAuthor.vetAssistant,
            text: 'Hello',
            at: DateTime(2026, 10, 15, 9),
          ),
        );
        await s1.flushPersistence();

        final s2 = AppStore();
        await s2.loadSettings();
        await s2.loadPhotos();

        expect(s2.appt('appt-1')?.status, ApptStatus.booked);
        expect(s2.qtyOf('pr1'), 2, reason: 'cart survives');
        expect(s2.thread('th_clinic').length, 1, reason: 'chat survives');
      },
    );
  });

  group('demo account', () {
    test('pet rename survives process death + cold start', () async {
      final s1 = AppStore();
      expect(
        await s1.signIn(AppStore.demoEmail, AppStore.demoPassword),
        isTrue,
      );
      final first = s1.pets.first;
      s1.updatePet(
        Pet(
          id: first.id,
          name: 'Renamed',
          species: first.species,
          breed: first.breed,
          sex: first.sex,
          birthDate: first.birthDate,
          weightKg: first.weightKg,
          color: first.color,
          microchip: first.microchip,
          allergies: first.allergies,
          vitals: first.vitals,
          timeline: first.timeline,
          docs: first.docs,
        ),
      );
      await s1.flushPersistence();

      final s2 = AppStore();
      await s2.loadSettings();
      await s2.loadPhotos();

      expect(s2.signedIn, isTrue);
      expect(s2.pet(first.id)?.name, 'Renamed');
    });
  });
}

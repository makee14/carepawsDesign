# Audit Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the 3 P1 and 3 P2 issues found by the backend/frontend audit agents.

**Architecture:** Six surgical fixes, each in its owning file, following the codebase's existing patterns. No new files, no new dependencies, no refactors beyond the fix.

**Tech Stack:** Flutter/Dart, existing test suite.

**Spec:** The audit verdicts delivered 2026-10-16 (backend: SOUND_WITH_CONCERNS, frontend: READY_WITH_CONCERNS). Backend findings are plan-document corrections (applied separately to the Supabase plan markdown); this plan covers the six code fixes.

## Global Constraints

- `flutter analyze` must show 0 issues after each task.
- `flutter test` must stay green (437 passed / 1 skipped baseline).
- Commits stay local; no push without Mark's tap.
- Follow ponytail rules: smallest diff, no new abstractions.

## Review Focus

- Price strings anywhere else in the app that drift from seed data (grooming, vet, products).
- Any other FAB/list overlaps on other tabs.
- Any other hardcoded business facts (phone, address, hours) outside their config.

---

### Task 1: Fix ₱850 price drift on Home carousel

**Files:**
- Modify: `lib/data/seed.dart:564`
- Test: `test/` (add price-drift guard)

**Interfaces:**
- Consumes: `Seed.services` (sv4 = Full Grooming, ₱1,450)
- Produces: Promo subtitle that cannot drift from service data

- [ ] **Step 1: Write the failing test**

```dart
test('promo grooming price matches Full Grooming service price', () {
  final promo = Seed.promos.firstWhere((p) => p.id == 'promo-groom');
  final fullGroom = Seed.services.firstWhere((s) => s.id == 'sv4');
  expect(promo.subtitle, contains('₱${fullGroom.price}'));
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/price_drift_test.dart`
Expected: FAIL (subtitle says ₱850, service says ₱1450)

- [ ] **Step 3: Fix `seed.dart:564`**

Change `'Full grooms from ₱850'` to derive from the service: `'Full grooms from ₱${_groomPrice}'` where `_groomPrice` reads sv4's price, or hardcode ₱1,450 with a comment pointing at sv4. Prefer the derived version so copy can't drift again.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/price_drift_test.dart`
Expected: PASS

- [ ] **Step 5: Run full gates**

Run: `flutter analyze && flutter test`
Expected: 0 issues, all green

- [ ] **Step 6: Commit**

```bash
git add lib/data/seed.dart test/price_drift_test.dart
git commit -m "Fix ₱850 price drift: promo reads Full Grooming price from seed"
```

### Task 2: Fix FAB covering Details button on Appointments

**Files:**
- Modify: `lib/screens/appointments_screen.dart` (bottom SliverPadding or FAB position)

**Interfaces:**
- Consumes: `TabBarClearance.of(context)`, `T.s16`, `T.s32`
- Produces: Last card's Details action never under the FAB

- [ ] **Step 1: Reproduce visually**

Build web, screenshot Appointments tab at 390×844, confirm the FAB overlaps the last card's Details button.

- [ ] **Step 2: Fix the overlap**

The bottom `SliverPadding` already reserves `56 + T.s32 + TabBarClearance`, but the Details button (rightmost in the action row) still slides under the FAB at `right: T.s16`. Increase the bottom padding OR add right-side clearance to the last card. Smallest fix that resolves the root cause.

- [ ] **Step 3: Verify visually**

Re-screenshot; confirm no overlap at 390×844 and at AX5.

- [ ] **Step 4: Run gates**

Run: `flutter analyze && flutter test`
Expected: 0 issues, all green

- [ ] **Step 5: Commit**

```bash
git add lib/screens/appointments_screen.dart
git commit -m "Fix FAB overlap: Details button clear of booking FAB"
```

### Task 3: Consolidate clinic hours to single source

**Files:**
- Modify: `lib/state/app_store.dart:249`, `lib/data/staff_replies.dart:26,116`, `lib/screens/settings/settings_screens.dart:1382`, `lib/screens/home/home_screen.dart:561`, `lib/screens/appointments/book_flow.dart:214,1313`
- Source of truth: `lib/data/clinic.dart` (`Clinic.hoursLabel`)

- [ ] **Step 1: Replace each hardcoded hours string with `Clinic.hoursLabel`**

Each site currently hardcodes "9:00 AM" / "Mon–Sat" variants. Replace with the constant. Where the string is embedded in a sentence (e.g., app_store.dart:249 "offline until 9:00 AM"), use the constant's components or add a `Clinic.openTimeLabel` if needed — but prefer reusing `hoursLabel` whole.

- [ ] **Step 2: Run gates**

Run: `flutter analyze && flutter test`
Expected: 0 issues, all green

- [ ] **Step 3: Verify no remaining hardcoded hours**

Run: `grep -rn "9:00 AM" lib/ --include="*.dart" | grep -v "clinic.dart" | grep -v test`
Expected: empty (or only intentional display copies with a comment)

- [ ] **Step 4: Commit**

```bash
git add lib/
git commit -m "Consolidate clinic hours to Clinic.hoursLabel single source"
```

### Task 4: Fix splash heartbeat ending at 1.015

**Files:**
- Modify: `lib/widgets/splash_morph.dart:48`

- [ ] **Step 1: Fix the decay math**

The `(1 - beatT)` decay binds to the cosine term instead of the whole sinusoid, leaving the emblem at scale 1.015. Fix so the heartbeat settles at exactly 1.0.

- [ ] **Step 2: Add/extend the keyframe test**

Extend the splash test to assert the final heartbeat scale is 1.0.

- [ ] **Step 3: Run gates**

Run: `flutter analyze && flutter test`
Expected: 0 issues, all green

- [ ] **Step 4: Commit**

```bash
git add lib/widgets/splash_morph.dart test/
git commit -m "Fix splash heartbeat: settle at 1.0 not 1.015"
```

### Task 5: Delete dead PetChip widget

**Files:**
- Modify: `lib/app.dart` (delete lines ~976-1056, the `PetChip` class)

- [ ] **Step 1: Confirm zero references**

Run: `grep -rn "PetChip" lib/ test/ --include="*.dart"`
Expected: only the class definition itself

- [ ] **Step 2: Delete the class**

Remove the 80-line `PetChip` widget.

- [ ] **Step 3: Run gates**

Run: `flutter analyze && flutter test`
Expected: 0 issues, all green

- [ ] **Step 4: Commit**

```bash
git add lib/app.dart
git commit -m "Delete dead PetChip widget (zero references)"
```

### Task 6: Fix AI key deletion matching by masked label

**Files:**
- Modify: `lib/screens/settings/settings_screens.dart:343-355`

- [ ] **Step 1: Change deletion to match by full key (or stable index)**

Currently matches by masked label (first-4/last-3), so two similar keys can delete the wrong one. Match by the full key value or by list index.

- [ ] **Step 2: Run gates**

Run: `flutter analyze && flutter test`
Expected: 0 issues, all green

- [ ] **Step 3: Commit**

```bash
git add lib/screens/settings/settings_screens.dart
git commit -m "Fix AI key deletion: match by full key, not masked label"
```

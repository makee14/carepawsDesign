# CarePaws Veterinary Clinic — customer app

A complete, tappable Flutter prototype of the CarePaws Veterinary Clinic customer
mobile app (testing build).

Cupertino-first: `CupertinoApp`, `CupertinoNavigationBar` / `CupertinoTabBar`,
Cupertino sheets and alerts, and the system (SF Pro) text theme, so it reads as
a native iOS app on every screen. Android runs the same code; Linux desktop is
included so the prototype can be run and reviewed without a simulator.

---

## Run it

### Fastest options

```bash
# AI unavailable without a key — the app runs, the assistant explains why
flutter run

# Live Gemini AI — one-time setup, then just this:
cp .env.local.example .env.local   # paste your key from
                                  # https://aistudio.google.com/apikey
tool/dev.sh                        # runs the app in live-AI mode
```

`tool/dev.sh` reads the key from `.env.local` (gitignored) or the environment,
so it is never typed on the command line and never enters shell history. Any
extra arguments pass through — `tool/dev.sh -d emulator-5554`. The equivalent
manual invocation still works:

```bash
flutter run --dart-define=GEMINI_API_KEY=your_key_here
```

### Pick a device quickly

`flutter run` with no `-d` uses the first available device. To see what is
connected — and pick one by id — use the device list:

```bash
flutter devices                      # shows every target with its id
flutter run -d <device-id>           # e.g. -d "iPhone 16" or -d emulator-5554
```

In Android Studio / IntelliJ you can skip the terminal entirely: open the
project, pick a target from the device dropdown in the toolbar, and press Run.
The **Device Manager** (icon in the toolbar, or `Window ▸ Device Manager`
/ `Tools ▸ Device Manager`) is where you start emulators, pair a physical
phone, and confirm a device is authorised.

### Wired (USB) — Android

```bash
# 1. On the phone: Settings ▸ About phone ▸ tap Build number 7x
#    then Settings ▸ Developer options ▸ USB debugging ON
# 2. Plug in the cable and accept the "Allow USB debugging" prompt
adb devices -l                        # confirm the device is listed as "device"

flutter devices                       # find the id
flutter run -d <device-id>            # hot reload: r  · hot restart: R
```

Release build to the same device:

```bash
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

### Wired (USB) — iOS (physical device)

```bash
# 1. Plug in the iPhone and trust this computer when prompted
# 2. Xcode ▸ Window ▸ Devices and Simulators ▸ the phone ▸ "Register Device"
open -a Xcode   # one-time, so the signing identity is created

flutter devices                       # the iPhone appears by name
flutter run -d <iphone-id>
```

First run asks for the bundle id `com.carepaws.carepaws` in Xcode ▸
Signing & Capabilities ▸ Team. Set **iOS Deployment Target** to 13.0 or higher.
On device, trust the developer certificate the first time you launch the app
(Settings ▸ General ▸ VPN & Device Management).

### Wireless — Android (no cable)

```bash
# Phone and computer must be on the same Wi-Fi network
# Developer options ▸ Wireless debugging ON, then "Pair device with pairing
# code" — note the IP:port and the pairing code it shows.

adb pair <ip:port>                    # enter the pairing code when prompted
adb connect <ip:port>                 # the same address shown in Wireless debugging
adb devices                           # confirm connected

flutter run -d <device-id>            # works for the rest of the session
```

Android 11+ only. For Android 9/10, wireless debugging is not supported — use
the USB route above, or `adb tcpip 5555` on a USB-connected device once.

### Wireless — iOS

Requires Xcode and a Mac. The device must have been paired over USB at least
once (so the signing identity exists).

```bash
# 1. iPhone ▸ Settings ▸ General ▸ AirPlay & Continuity ▸ FaceTime Handoff ON
#    and connect to the same Wi-Fi as the Mac
# 2. Xcode ▸ Window ▸ Devices and Simulators ▸ select the phone ▸
#    "Connect via network" (tick the box)
flutter devices                       # the iPhone appears over Wi-Fi
flutter run -d <iphone-id>
```

### Emulators

```bash
flutter emulators                     # list what is already configured
flutter emulators --launch <emulator-id>
flutter run -d <emulator-id>
```

Android: **Device Manager ▸ Create device** in Android Studio, then launch it.
iOS: `open -a Simulator`, then `flutter run -d <simulator-id>`.

### Handy run flags

| Flag | Effect |
|---|---|
| `-d <id>` | target a specific device |
| `--dart-define=GEMINI_API_KEY=…` | switch to live AI |
| `--dart-define=SHOT=<screen>` | boot straight into one screen (see below) |
| `--profile` / `--release` | optimised builds |

Visual review of one screen at a time (Linux desktop, or any device):

```bash
flutter run -d linux --dart-define=SHOT=triage   # home|pet|triage|book|shop|
                                                  # product|cart|checkout|orders|
                                                  # order|ai|clinic|profile|settings|
                                                  # privacy|about|faq|reminders|
                                                  # clinicinfo|addpet|splash
```

While `flutter run` is active: `r` hot reload, `R` hot restart, `q` quit.

---

## Design system

Locked palette, sampled from the official logo. Every colour pair below was
computed and is asserted in `test/unit_test.dart`.

| Token | Hex | Role | Contrast |
|---|---|---|---|
| `brand-orange` | `#E4843E` | logo mark, illustration highlights | — |
| `terracotta` | `#D4621A` | large text, icons, accents (never body) | 3.44:1 on cream → ≥3:1 large only |
| `terracotta-deep` | `#A8480F` | filled buttons, small accents | 5.32:1 cream / 5.84:1 white text |
| `amber` | `#F4AE52` | chips, ratings — **never carries text** | 8.80:1 with espresso |
| `espresso` | `#2A1A0E` | primary text | 15.27:1 on cream |
| `ink` | `#25221E` | wordmark ink, large titles | 14.43:1 on cream |
| `cream` | `#FEF3E2` | app background | — |
| `card` | `#FFFFFF` | cards on cream | — |
| `taupe` | `#9B8A76` | secondary icons, dividers | 3.04:1 → icons only |
| `text-secondary` | `#6B5646` | derived secondary copy | 6.28:1 on cream |
| `sand` | `#C7AB83` | decorative tint only | — |
| `destructive` | `#DC2626` | destructive actions | 4.83:1 on card |

Rules enforced in code:

- Body text is Espresso on Cream or Card only.
- Terracotta carries large text, icons and accents — never body copy.
- Amber is a surface, never a text colour.
- Filled buttons use Espresso fill + Cream text, or the darkened terracotta
  fill + white text.
- **One paw-mark rule:** the logo appears on the splash screen only. No paw
  patterns anywhere else.
- Light warm theme is the default; a matching dark token set ships per HIG §7
  and can be switched on in Profile → Appearance.

**Type ramp:** Large Title 34 semibold · Title 28 · Headline 17 semibold ·
Body 17 · Footnote 13 · Caption 12, on the system stack.

**Effects:** frosted-glass cards (12–20px backdrop blur, 1px translucent
border), sheet spring transitions, 200ms ease-out press scale, haptic feedback
on success. Reduce Motion renders static final states.

**Icons:** every icon is a hand-authored SVG line glyph (`lib/design/icons.dart`,
rendered with `flutter_svg`). No emoji are used as icons anywhere.

---

## Running the app

The flow is **splash → onboarding (first launch) → sign-in → app**. The splash
waits for you — it no longer pushes the app on a timer, which made the "Get
started" button almost impossible to press. First launch then shows a five-page
Apple-style onboarding tour (swipe or Continue; Skip ends it early). It runs
once — Settings ▸ Help ▸ "Take the tour again" replays it. Each of the five
pages carries a one-shot animated illustration in the locked warm palette (a
paw mark that draws itself in, a pulsing AI orb with a triage question, a mini
calendar with a docking time chip, chat bubbles where typing dots resolve into
the clinic's reply, a product card with a popping cart badge) — entrances
replay when you swipe back to a page, and reduced motion shows the final
static frame instead. Sign in with the
demo account:

| Field | Value |
|---|---|
| Email | `carepaws@test.com` |
| Password | `carepawscustomer1` |

Any other email or password is rejected with an inline message and the form
stays put. "Use the demo account" fills both fields and signs in. **Settings ▸
Data ▸ Sign out** returns you to the splash so the flow can be shown again.

These credentials are compared on the device — a design demonstration, not real
authentication.

---

## AI integration

### Adding a key on the device (no rebuild)

**Settings ▸ CarePaws AI** has a key field. Paste a key (or use the paste
button) and tap **Save key** — the status chip flips to *Live* immediately and
the key is remembered across launches. This avoids `--dart-define` entirely,
which is handy when testing on a phone.

The value is stored in `SharedPreferences` **in plaintext**. It is a testing
affordance only; remove it before shipping a build.

### Key resolution

The key is read from, in order:

1. A key typed into Settings ▸ CarePaws AI on the device.
2. A key baked in at build time — `tool/dev.sh`, or
   `flutter run --dart-define=GEMINI_API_KEY=…`.

### Model discovery

The key lives in exactly one clearly-marked placeholder:

```dart
// lib/services/ai_service.dart
const String geminiApiKey = String.fromEnvironment(
  'GEMINI_API_KEY',
  defaultValue: 'YOUR_GEMINI_API_KEY',
);
```

No key is hardcoded anywhere in the project.

At startup `AiService.bootstrap()`:

1. If no key is configured → the assistant is **unavailable**. Every AI
   surface (chat thread, triage screen, booking AI step) shows an "AI
   unavailable" card naming exactly what went wrong and what to do, with
   working alternatives (book directly, call the clinic). Nothing is a dead
   end, and there are no canned answers.
2. Otherwise it lists `models`, filters to `generateContent` models that accept
   text **and** image input, and ranks them — flash family first, full flash
   over lite, stable builds over previews and rolling aliases. **No model name
   is hardcoded.**
3. If the network call fails for any reason, the assistant reports
   `unreachable` or `serviceError` — the UI states which, and offers the same
   alternatives.

There is no demo responder: without a working key the assistant says so
plainly instead of guessing.

---

## Motion

`lib/design/motion.dart` holds the whole motion vocabulary — three durations,
one curve, one stagger step — so motion does not drift screen to screen.

- **Every animation is one-shot and finite.** Nothing loops, which is what keeps
  the golden suite's `pumpAndSettle()` from timing out.
- **Everything checks `reduceMotionOf(context)`** and paints its final state on
  the first frame when the OS or the in-app Reduce motion toggle asks for
  stillness.
- `FadeSlideIn(index:)` staggers a group in; `PopIn` scales a hero element in.
- The curve is `easeOutQuart`, not `easeOutCubic` — the latter decelerates so
  gradually that entrances read as floaty.
- Stagger is capped at 170ms. A long stagger makes a screen feel like it is
  loading rather than arriving.
- `appRoute()` uses a custom fade-and-settle route: the outgoing page holds
  still, the incoming page cross-fades in at 98% scale, no sideways slide.
  Apple reserves the directional slide for drill-in navigation inside one flow;
  using it for every push made the app feel like it was endlessly burrowing
  sideways. The iOS back-swipe gesture still works via
  `CupertinoRouteTransitionMixin`, and Reduce Motion degrades the route to a
  pure fade.

### Header layout

Screen titles and their actions share one row on Home, Appointments, Shop and
Profile, reclaiming roughly 50pt above the fold on each. The actions stay in the
page content rather than the navigation bar's `trailing` slot, because Cupertino
clamps that slot to 44pt — below the 48pt minimum touch target the
accessibility suite enforces.

### Glass and surfaces

#### Floating tab bar

`RootShell` is a `Stack`: the tab bodies fill it, and `FloatingTabBar` floats on
top. `CupertinoTabScaffold` could not be used — it reserves a strip of the
layout for its bar, so content can never scroll behind it.

Per the design spec the bar is:

| | |
|---|---|
| Shape | one capsule, fully rounded (radius = height / 2) |
| Height | 64pt |
| Margins | 16pt left and right, plus any notch inset in landscape |
| Vertical | floats 10pt above the bottom safe area — never over the home indicator |
| Slots | five, evenly spaced, icon over label, each at least 44×44pt |
| Theme | light and dark, via the palette's glass tokens |

Two details that are easy to get wrong:

- **The bar is a `Padding`, not a `Positioned`.** The shell wraps it in an
  `AnimatedSlide`, and a nested `Positioned` under a transition is a
  `ParentDataWidget` mismatch.
- **The blur goes through `GlassCard`.** A bare `BackdropFilter` in a `Stack`
  samples everything painted beneath it and blurs the entire page, not just
  the pill; `GlassCard` wraps the filter in a `ClipRRect`, which bounds it.

**The bar hides on pushed routes.** A Navigator reports a push for the route it
starts on, so depth is tracked per tab and the initial push is ignored. While a
detail screen is open the bar fades out **and is wrapped in `IgnorePointer`**,
because it would otherwise sit over that screen's own bottom furniture — the
chat composer, the sticky CTA, Done/Cancel buttons — and swallow taps on it.
An `AnimatedOpacity` at zero is still hit-testable, so the fade alone was not
enough: the invisible bar kept eating bottom-of-screen taps.

**Clearance is its own inset, not `MediaQuery.padding`.** Tab lists reserve
room via `TabBarClearance`, an `InheritedWidget` provided above the tab
Navigators. Inflating `MediaQuery.padding` instead would also move every
`SafeArea`, pushing up each `StickyCta` and shrinking the scroll area above it.
When the bar is hidden the clearance is 0, so pushed screens get their full
height back.

#### Other surfaces

The five tab screens use `LargeTitleBar` instead of `CupertinoSliverNavigationBar`.
The stock widget always keeps a 44pt bar above the large title and hides the
small title while it is expanded, so on a notched phone there is a blank strip
between the status bar and the title. `LargeTitleBar` puts the large title where
that strip was and shrinks it into the 44pt bar on scroll.

### Photos

Pet portraits and the owner avatar are optional. When a pet has no photo the
generated `PetArt` is used, so nothing changes for existing records.

- **Pet:** Home → pet → pencil icon → pick a photo, or change name, breed, sex,
  weight and allergies. Vitals, visits and documents are clinic records and are
  carried over untouched.
- **Owner:** Profile → your name → camera badge on the avatar.

Photos are downscaled to 640px / quality 72 and stored as base64 JPEG in
`SharedPreferences` (`lib/services/photo_store.dart`). That is deliberately
simple: fine for a handful of small portraits, but a shipping app should write
files to app storage and keep paths instead. A corrupt stored value is dropped
rather than crashing the profile on every launch.

The bottom action bar (`StickyCta`, used on 13 screens) is a floating frosted
pill: inset from every edge, 24pt radius, real `BackdropFilter`, hairline
border and drop shadow. It is kept deliberately tight — the float comes from the
inset margins, radius and shadow, and every extra point of padding is content
hidden above the fold.

Glass is applied only where a surface genuinely floats over content (the action
bar, hero cards, the splash and the sheet chrome). Inline `SoftCard`s stay
opaque on purpose: they sit on a flat background where a blur has nothing to
sample, and stacking `BackdropFilter`s down a scrolling list costs real frames
while making body text harder to read.

---

## Structure

```
lib/
  main.dart                 entry point + visual-review harness
  app.dart                  CupertinoApp, splash, tab shell, routing, date helpers
  design/
    tokens.dart             locked colour, spacing, radius, layout tokens
    theme.dart              light + dark palettes, type ramp
    icons.dart              SVG line icon set, IconTap, PressScale
  data/
    models.dart             Pet, Appointment, Product, Order, TriageResult, …
    seed.dart               realistic sample data (2 pets, 5 visits, 8 products)
  services/
    ai_service.dart         Gemini client, model discovery, honest AI-unavailable states
  state/
    app_store.dart          single ChangeNotifier store + AppScope
  widgets/
    common.dart             glass/soft cards, chips, stat strips, sticky CTA, …
    nav_actions.dart        header action row (keeps 48pt targets)
    time_of_day.dart
  screens/
    home_screen.dart …      one folder per tab, plus triage / booking / shop
    onboarding_screen.dart  five-page first-run tour (replayable from Help);
    onboarding_illustrations.dart  one-shot animated illustrations, one per page
```

---

## What is covered

**HOME** — time-aware large title, search, notifications; upcoming-appointments
hero carousel (photo, vet, date/time, live countdown per page over a floating
glass card; auto-advances every 5s, pauses while touched, dots for position,
static with no timer under Reduce Motion); My Pets with
pet cards → Pet Profile; zero-pet state; quick actions (Book / AI Triage / Chat /
Shop); care reminders with Terracotta switches and an in-context notification
permission sheet on the first toggle; clinic info with hours, address,
emergency contact and the nearest after-hours hospital.

**CHATS** — one inbox. Pinned "CarePaws AI" thread (Always available, labelled
AI, "Start health check" entry point) and a "Clinic team" thread with a
response-time note when offline. Staff directory (name + role, no presence
badges). AI → clinic handoff carries the pet and the triage result.

**AI TRIAGE** — one shared engine, three entries (Home, AI thread, Book step 2).
Text + optional photo → exactly one of book / chat / home care / emergency.
Emergency shows the call CTA above the fold (`tel:` link, switching to the
nearest 24-hour hospital after hours). Every outcome states it is not a
diagnosis. The text-only path is identical to the photo path.

**APPOINTMENTS** — segmented Upcoming / Past, status as text (never colour
only), grooming statuses, reschedule / cancel / details with destructive
confirmation, rebook that skips triage. Six-step booking flow with
duration-aware slots, auto-assigned staff, total shown before confirm, grooming
intake with estimated pricing, and a success sheet with "Add to Calendar".

**SHOPS** — catalog with search and filter chips, no-results → "Browse all
products"; product detail with gallery and "+N" overflow; out-of-stock becomes
"Notify me" instead of disappearing; cart with quantity editing and destructive
remove; one-screen checkout with GCash / card, pickup panel and "No delivery —
pickup at the clinic"; restricted items require an active prescription signed
by the vet; payment failure retries inline with the cart intact; pickup code +
QR + receipt; orders with statuses and a refund path.

**PROFILE** — user header, notifications → reminders, language, appearance,
privacy (data export, delete account with the iOS system alert), support,
about, log out. Rows are ≥56pt with chevrons.

---

## Tests

```bash
flutter analyze          # clean, zero issues
flutter test             # 94 tests + golden image diffs
```

| Suite | What it covers |
|---|---|
| `test/unit_test.dart` | contrast ratios, peso/date formatting, store behaviour, seed-data integrity |
| `test/widget_test.dart` | all five tabs, triage routes, booking end to end, shop/checkout, accessibility, AX5 and landscape |
| `test/ai_live_test.dart` | real Gemini API — skipped unless `--tags live` with a key |
| `test/screens_test.dart` | renders every screen at iPhone size and diffs against `test/goldens/` |

Live API check:

```bash
tool/dev.sh test                    # equivalent to the line below
```

```bash
flutter test test/ai_live_test.dart --tags live \
  --dart-define=GEMINI_API_KEY=your_key_here
```

Regenerate reference images after an intentional visual change:

```bash
flutter test test/screens_test.dart --update-goldens
```

---

## Releases & testing

Every push to `main` runs the `build` workflow (`.github/workflows/build.yml`):

- **`carepaws-debug-apk`** (Android, debug key): installable for testing —
  `adb install app-debug.apk`. Good enough for on-device testing of the app.
- **`carepaws-unsigned-ipa`** (iOS, no codesign): sideload with Sideloadly on
  Windows — see [IOS_TESTING.md](IOS_TESTING.md) for the full steps and the
  7-day certificate refresh caveat.

Signed release APKs land in `releases/` (`carepaws-<version>.apk`). The release
keystore lives outside the repo (see `android/app/build.gradle.kts`: the
release `signingConfig` reads `CAREPAWS_KEYSTORE`, `CAREPAWS_KEY_ALIAS`,
`CAREPAWS_STORE_PASSWORD`, `CAREPAWS_KEY_PASSWORD` from the environment — never
from committed files).

## Known scope notes

- Payments, SMS and push delivery are simulated locally — the prototype has no
  server. A genuine payment failure would keep the cart intact and surface the
  inline retry UI.
- `image_picker` has no Linux implementation, so on desktop the photo picker
  explains the situation and the text-only path continues — never a dead end.
- `tel:` links have no handler on desktop; the number is shown instead.
- The "AI unavailable" card is shown whenever no key is configured or the
  service cannot be reached — it names the failure and the fix.
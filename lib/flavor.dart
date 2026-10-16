/// Compile-time build flavor.
///
/// One codebase, two downloads: the `customer` APK/IPA is the pet-owner app,
/// the `vet` APK/IPA adds the vet portal. Bake the flavor in at build time:
///
///   Android:  flutter build apk --flavor vet --dart-define=APP_FLAVOR=vet
///   iOS:      the `vet` scheme (ios/Runner.xcodeproj), built with
///             --dart-define=APP_FLAVOR=vet
///
/// Anything else builds the customer app — the default keeps every existing
/// build command working unchanged.
const String appFlavor = String.fromEnvironment(
  'APP_FLAVOR',
  defaultValue: 'customer',
);

/// True when this binary is the vet portal flavor.
///
/// Vet-only imports must live behind this (or in files only the vet entry
/// point `lib/main_vet.dart` reaches) so the customer build tree-shakes the
/// portal out. The customer entry (`lib/main.dart` → `lib/app.dart`) must
/// never import `lib/screens/vet/`.
const bool kVetFlavor = appFlavor == 'vet';

# Testing the CarePaws app on iPhone (no Mac needed)

The iOS build from CI is an **unsigned IPA**. There is no way to install an
unsigned IPA directly on an iPhone — the workaround is **Sideloadly**, a free
tool that signs the IPA with your Apple ID *at install time* and then installs
it over USB. This path works entirely from a Windows PC.

## Prerequisites

- An iPhone (any model running a supported iOS version).
- A free Apple ID (your normal one is fine; Sideloadly needs it to request a
  signing certificate from Apple).
- A Windows PC with:
  - **Apple Devices** (or iTunes) installed from **Apple's website**, not the
    Microsoft Store version — Sideloadly needs the Apple-provided USB drivers.
    Get it at https://support.apple.com/downloads (or iTunes 12.6.5-style
    installer from Apple's site).
  - **Sideloadly** (free) from https://sideloadly.io — install the latest
    release.

## Step by step

1. Go to the **Actions** tab of the `carepawsDesign` repo on GitHub and open
   the latest `build` run.
2. Download the **carepaws-unsigned-ipa** artifact (it contains one `.ipa`).
3. Connect the iPhone to the PC with a USB cable and unlock it. Tap **Trust**
   when the iPhone asks to trust the computer.
4. Open Sideloadly. Select your iPhone from the device dropdown and drag the
   `.ipa` file onto the Sideloadly window.
5. Enter your Apple ID when prompted. Sideloadly talks to Apple's servers to
   get a free 7-day signing certificate and installs the app.
6. On the iPhone, go to **Settings → General → VPN & Device Management**,
   tap your Apple ID under **Developer App**, and tap **Trust**.
7. The CarePaws app icon appears on the home screen — open it and test.

## The 7-day refresh caveat

Free Apple IDs get a **7-day signing certificate**. After 7 days the app will
refuse to open (it will crash on launch). This is an Apple limit on free
accounts, not a bug. To keep testing, reconnect the phone and re-sideload the
IPA with Sideloadly — it takes a minute and resets the clock. Paid Apple
Developer accounts get a 1-year certificate, but are not needed for testing.

## Common errors

- **"iPhone not detected"** — make sure Apple Devices/iTunes came from Apple's
  site (the MS Store version doesn't register the drivers Sideloadly needs).
  Try another cable/port and re-tap Trust on the phone.
- **"Provisioning failed / could not obtain certificate"** — Apple's free-tier
  signing can be rate-limited per Apple ID (a few apps per week). Wait and retry,
  or use a different Apple ID.
- **App crashes on launch after several days** — the 7-day certificate expired;
  re-sideload (see above).
- **"Untrusted Developer"** — you skipped step 6: Settings → General → VPN &
  Device Management → trust the Apple ID.
- **Sideloadly asks for the IPA password** — enter your Apple ID *app-specific
  password* if your account has two-factor authentication enabled (Apple ID
  settings → Sign-In and Security → App-Specific Passwords).

## Future: App Store signing on a Mac

For a real release, the app needs proper signing with an Apple Developer
account ($99/year). On a Mac with Xcode:

1. Enroll in the Apple Developer Program and open the project in Xcode.
2. Set the Team on the Runner target (bundle ID `com.petcare.petcareArtifact`).
3. `flutter build ipa` (with codesigning) or use Xcode's Product → Archive,
   then Distribute App to the App Store or TestFlight.

Until then, the Sideloadly path above is the supported way to run this app on a
physical iPhone.

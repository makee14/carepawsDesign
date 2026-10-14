#!/usr/bin/env bash
# Runs the app or the live AI tests against the real Gemini API.
#
# The key is read from the environment, or from a gitignored `.env.local`, so it
# never has to be typed on the command line (and never lands in shell history).
#
#   cp .env.local.example .env.local    # once, then paste your key
#   tool/dev.sh                         # run the app with live AI
#   tool/dev.sh test                    # run the live API test suite
#   tool/dev.sh run -d emulator-5554    # any extra args are passed through
set -euo pipefail

cd "$(dirname "$0")/.."

# Prefer an already-exported key, else load .env.local if it exists.
if [[ -z "${GEMINI_API_KEY:-}" && -f .env.local ]]; then
  # shellcheck disable=SC1091
  set -a && source .env.local && set +a
fi

if [[ -z "${GEMINI_API_KEY:-}" || "${GEMINI_API_KEY}" == "your_key_here" ]]; then
  cat >&2 <<'EOF'
No GEMINI_API_KEY found — the app would silently fall back to demo-AI mode.

  1. Get a key:      https://aistudio.google.com/apikey
  2. Create the file: cp .env.local.example .env.local
  3. Paste the key into .env.local, then re-run.

Alternatively export it for one session:
  GEMINI_API_KEY=... tool/dev.sh
EOF
  exit 1
fi

# `lib/services/ai_service.dart` only treats a key as real when it is longer
# than 20 characters, so fail loudly rather than dropping into demo mode.
if (( ${#GEMINI_API_KEY} <= 20 )); then
  echo "GEMINI_API_KEY looks too short — this will be treated as unset." >&2
  exit 1
fi

DEFINE="--dart-define=GEMINI_API_KEY=${GEMINI_API_KEY}"

case "${1:-run}" in
  test)
    shift
    echo "› Running live API tests against the real Gemini endpoint…"
    exec flutter test "${DEFINE}" --tags live "$@"
    ;;
  run)
    shift
    echo "› Starting app in live-AI mode (no 'Demo AI' badge expected)…"
    exec flutter run "${DEFINE}" "$@"
    ;;
  *)
    # Anything else is treated as plain `flutter run` args.
    exec flutter run "${DEFINE}" "$@"
    ;;
esac

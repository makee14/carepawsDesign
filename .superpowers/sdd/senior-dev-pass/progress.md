# Senior Dev Pass ledger

Base: 85c3f1f (prod-f-persistence) → integration branch: senior-dev-pass
Goal: strict senior-dev pass — verify/fix UI/UX, ponytail refactor, demo cleanup — readying the app for the vet-side app.

## Branch strategy (Ruling)
Task said all workers on `senior-dev-pass`. Per agent-team skill ("two devs on the same branch is faster" → stash sweeps), each stream works in its own worktree + branch, merged by the lead in dependency order:
- senior-dev-pass-demo (~/workspace/carepaws-app/wt-senior-demo) — merges FIRST (deletions)
- senior-dev-pass-refactor (~/workspace/carepaws-app/wt-senior-refactor) — merges SECOND
- senior-dev-pass-ui (~/workspace/carepaws-app/wt-senior-ui) — merges LAST (goldens regen on merged tree)
Cost if wrong: none — integration branch is what gets reviewed.

## File-set ownership (no two writers on one file)
- Demo Cleanup: lib/state/app_store.dart (demo lines only), demo UI anywhere, tests pinning demo behavior
- Refactor Dev: lib/state/** EXCEPT app_store.dart, lib/services/**, lib/data/**, lib/design/** (non-token)
- UI/UX Verifier: lib/screens/**, lib/widgets/**, lib/app.dart, test/goldens/**, lib/design/tokens.dart (only if a token is wrong)

## Stream status
- [ ] demo: dispatched
- [ ] refactor: dispatched
- [ ] ui: dispatched
- [ ] merge demo → senior-dev-pass
- [ ] merge refactor → senior-dev-pass
- [ ] merge ui → senior-dev-pass (+ golden regen + eyeball maskedDiff)
- [ ] gates on merged tree (analyze 0, test green)
- [ ] Review Lead dispatched

## Dispatch (build lead)
- UI/UX Verifier → wt-senior-ui / senior-dev-pass-ui (screens, widgets, app.dart, goldens)
- Ponytail Refactor Dev → wt-senior-refactor / senior-dev-pass-refactor (state excl. app_store, services, data)
- Demo Cleanup Dev → wt-senior-demo / senior-dev-pass-demo (app_store demo lines, demo UI, demo tests)
All: read AGENTS.md + LEARNED.md + carepaws-app/AGENTS.md + role skills; gates analyze 0 + test green; commits local.
Next: merge demo → refactor → ui onto senior-dev-pass; gates; dispatch Review Lead.

## Standing rule applied (Mark, 2026-10-17)
Frontend verified with Playwright always — real rendered output, not goldens alone. Passed to UI/UX Verifier via subagent.send; recorded in ~/AGENTS.md by parent. Applies to all future frontend work.

## Text Placement Judge added (Mark, 2026-10-17)
- 4th stream: wt-senior-text / senior-dev-pass-text (text-placement fixes in screens/widgets; minimal, text-scoped; flags broader layout to UI Verifier; does NOT regen goldens)
- Revised merge order: demo → refactor → text → ui (UI last, owns golden regen on merged tree)
- [ ] text: dispatched

## Demo merged (build lead verified)
- Commit a95edb0 merged into senior-dev-pass (fast-forward). Diff verified: 5 files, +5/−56, deletions only.
- Gates per worker: analyze 0, test 437 passed / 1 skipped (2 demo-reset tests deleted, baseline 439).
- Demo login intact (demoEmail/demoPassword + signIn path + rehydration fallback kept).
- Concern noted: _ShotHost screenshot host in main.dart kept (visual-judging harness, not a demo feature).
- [x] demo: DONE, merged

## Refactor merged (build lead verified)
- 7 commits merged into senior-dev-pass (merge 83797fd). Diff verified: 11 files, all in refactor's file set (no app_store.dart, no screens).
- Metrics: -208 net production lines; 9 decode loops → DatasetStore._decode; 5 prefs helpers → services/prefs.dart; 70-case byName switch → const map; _symptomHit merged into _symptoms table; _parseChat reuses _extractJson; dead speciesFrom/Pet.tint deleted.
- Gates per worker: analyze 0, test 443 passed / 1 skipped (baseline 439 + 4 new pins), format clean.
- Shareable vs app-specific boundary list captured for vet-app extraction (in worker report).
- Concern noted: dart format --set-exit-if-changed rewrites in place (use --output=none for dry run) — recorded in LEARNED.md by worker.
- [x] refactor: DONE, merged

## UI verified (build lead, worker report was empty — recovered from branch)
- Commit 42d1336 "Senior UI pass: 6 Playwright-verified fixes (F0-F5)" — build lead ran gates directly: analyze 0 issues, test 448 passed / 1 skipped (matches commit claim).
- F0 reduced-motion AnimatedSize crash; F1 segmented 44pt; F2 FilterPill 44pt; F3 greeting AX5; F4 LargeTitleBar AX5; F5 monogram noScaling.
- 6 new tests RED→GREEN; goldens 04_appointments + 05_shop regen'd, maskedDiffs eyeballed per commit msg.
- NOT merged yet — text judge merges first, UI last (owns final golden regen).

## Text merged (build lead verified)
- 2 commits (2c7b4e8, b2bfe91): F1-F11 text fixes, scale-gated so 1x is pixel-identical. File set clean (screens/widgets only).
- Gates per worker: analyze 0, test 438/1/1 (1 intentional AX5 golden).
- 2 layout concerns flagged (not fixed): L1 product grid 1-col at AX5, L2 profile avatar alignment — for Review Lead.
- [x] text: DONE_WITH_CONCERNS, merged (50fcda8)

## UI merged (build lead verified + merge conflicts resolved)
- Commit 42d1336: F0-F5 Playwright-verified. Worker report was empty; recovered from branch + direct gate run (analyze 0, 448 passed).
- Conflicts in 4 files (both streams fixed same AX5 issues): LargeTitleBar → kept UI structure + text's 2-line maxExtent; segmented/filter rows → 44pt × Dynamic Type scale.
- Ruling (build lead): my LargeTitleBar merge initially double-applied textScale (took text judge's pre-multiplied size); caught by large_title_ax5_test, fixed in 5df5089 (revert to UI's ambient-scaler version). Cost if wrong: AX5 header clip — now covered by test.
- Goldens regen'd on merged tree: only 23_home_ax5.png changed (intentional reflow, eyeballed). Full suite: 450 passed / 1 skipped.
- [x] ui: DONE, merged (0a42d9d)

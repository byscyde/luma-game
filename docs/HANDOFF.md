# Handoff — continue LUMA from another Claude account

_Written 2026-10-26 at the end of session 3. Read this first, then `CLAUDE.md`._

## 1. Moving to another Claude account (owner checklist)
Everything lives in GitHub; nothing important is stored in the Claude account.

1. Log in to the new Claude account → Settings → Connectors → **GitHub** → connect the
   GitHub user that owns `byscyde/luma-game` (or that has write access to it).
2. Make sure the **Claude GitHub App** is installed on the repository
   (https://github.com/apps/claude/installations/select_target).
3. Start a Claude Code session (claude.ai/code) on `byscyde/luma-game`, branch
   **`feature/mvp-core`**.
4. First message to paste (Croatian replies are fine):

   > Read CLAUDE.md, docs/HANDOFF.md and docs/CURRENT_STATUS.md. Work on branch
   > feature/mvp-core. Next task: section 4 of docs/HANDOFF.md, item 1
   > (finish the board/level-screen redesign). Reply to me in Croatian.

5. Git identity used so far: `git config user.name "SCYDE"`,
   `git config user.email "dev@scyde.dev"`.
6. No secrets need to move: there are no Apple / Android signing secrets configured. If added
   later they go only into GitHub → Settings → Secrets (names in `RELEASE_RUNBOOK.md`).

## 2. Where things are
| What | Where |
|---|---|
| Rules for agents | `CLAUDE.md` |
| Full spec | `docs/MASTER_PLAN.md` |
| Decisions (D-001 … D-016) | `docs/DECISION_LOG.md` |
| Status log | `docs/CURRENT_STATUS.md` |
| CI / release / secrets | `docs/RELEASE_RUNBOOK.md`, `.github/workflows/` |
| Art direction | `docs/ART_DIRECTION.md` |
| Privacy / stores | `docs/PRIVACY_AND_COMPLIANCE.md` |
| Branches | `feature/mvp-core` (main work, PR #1), `wip/board-redesign` (unfinished, see §4) |

## 3. State at handoff (verified)
- Head of `feature/mvp-core`: commit "Fix double rotation per tap on touch screens".
- Local: `tools/run_tests.sh` → **76/76 tests**, 30/30 levels solvable; repo hygiene passes.
- **iOS**: each successful direct `iOS build` run publishes a pre-release
  `ios-build-<run>` under https://github.com/byscyde/luma-game/releases with
  `LUMA-<version>-ios-build<run>-unsigned.ipa` (owner re-signs with Feather). Verified with
  build 8. iOS builds run on push to `main`, `release/**`, `ci/**`, or manually
  (Actions → iOS build → Run workflow). **A push to `feature/mvp-core` does not build iOS**:
  trigger it manually after pushing.
- Repo appears public → those IPAs are public. Owner has not yet decided whether that is OK.

### Bug fixed this session (the "everything is buggy" report)
On real touch screens every tap arrived twice (touch + emulated mouse click,
`emulate_mouse_from_touch=true`). Each tap rotated a tile **twice**: straights never changed,
corners jumped 180°, level 3 was unsolvable, and Undo seemed to "fix" a tile (it undid one
of the two turns). Same double-handling existed in the island view. Fixed in
`BoardView._gui_input` and `IslandView._gui_input` (ignore `DEVICE_ID_EMULATION`), with a
regression test. Not yet in an IPA → **trigger a new iOS build** and ask the owner to
re-test on the phone.

## 4. Next tasks (in order)
Session 4 finished the board / level-screen redesign, dark mode, splash + loading screen,
app icon and 120 Hz work (D-017). Next:
1. Owner tests the new IPA on the phone (FPS counter in Settings) and reports issues.
2. Planned: port to **Unity** (owner's decision, after this Godot pass). Start with a written
   port plan; Unity needs the owner's Unity licence as a GitHub secret before CI can build.
3. Open questions for the owner: iOS build on every push to `feature/mvp-core`? Public vs
   draft IPA releases (D-016)?
4. Then `docs/MASTER_PLAN.md` (World 2, store-readiness checklist).

## 5. Working rules that matter
- Never claim a build/test passed without seeing it; report failures with output.
- Don't add Apple/Android secrets; unsigned builds are the default.
- Don't force-push; small commits; run `tools/run_tests.sh` before every push.
- Wait on CI with scheduled check-ins (`send_later`), not `sleep`.
- Owner writes in Croatian; answer in Croatian.

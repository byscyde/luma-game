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
1. **Board & level-screen redesign (owner: "looks awful").** Started on branch
   `wip/board-redesign` (one commit, **never compiled or looked at**). Ideas there:
   checkered lawn under every cell (empty cells become background), rotatable tiles as
   round cream discs (r 0.465) with 4 notches that turn as a whole, fixed tiles as grey
   square slabs with bronze rivets, dark slate grooves with bright water, cream stone frame
   around the board. Problems seen in the old look (`build/before/*.png` is not committed;
   regenerate with the screenshot tour): discs as big as the tile so they overlap
   neighbours, dry channels look like brown planks, empty cells as loud as pieces, big
   empty gap above the board, washed-out bottom buttons, tutorial caption pushes the
   board around.
   Still to do for the screen (`scripts/ui/gameplay_screen.gd`): compact header,
   one status bar for moves + objectives, caption as an overlay bubble, bottom dock with
   icon-over-label Undo / Reset / Hint (Hint accented). Keep node names
   (`UndoButton`, `ResetButton`, `HintButton`, `Board`) and fields used by tests.
   Verify with the Xvfb screenshot command in `CLAUDE.md` at 720×1280 and 640×1136, run
   `tools/run_tests.sh`, then merge into `feature/mvp-core`.
2. Trigger iOS build, give the owner the release link, collect feedback from the device.
3. Ask the owner: iOS build on every push to `feature/mvp-core`? Public vs draft IPA
   releases (D-016)?
4. Remove the stray tracked file `tools/_probe.gd.uid` (its `.gd` no longer exists).
5. Then continue `docs/MASTER_PLAN.md` (World 2, store-readiness checklist in
   `PRIVACY_AND_COMPLIANCE.md`: privacy policy URL, legal entity).

## 5. Working rules that matter
- Never claim a build/test passed without seeing it; report failures with output.
- Don't add Apple/Android secrets; unsigned builds are the default.
- Don't force-push; small commits; run `tools/run_tests.sh` before every push.
- Wait on CI with scheduled check-ins (`send_later`), not `sleep`.
- Owner writes in Croatian; answer in Croatian.

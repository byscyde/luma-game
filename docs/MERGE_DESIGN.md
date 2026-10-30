# LUMA Harbour — merge-2 mode (after level 30)

Owner request (2026-10-27): after the 30 puzzle levels the game becomes a merge-2 game with the
mechanics, progression, look and feel of *Gossip Harbor: Merge & Story* (Microfun).

**What we copy and what we don't.** Game mechanics and genre conventions are free to use and we
follow Gossip Harbor's closely. Its characters (Quinn, Coconut…), story text, location
(Brimwave Island), names, UI artwork, icons and music are Microfun's copyright/trade dress and are
**not** copied: LUMA Harbour has its own cast, mystery, setting and procedurally drawn art in a
similar bright, saturated, casual style.

## Research summary (sources at the end)
Core loop: energy → tap generators → items appear on the board → merge two identical items into
the next level → fill customers' orders → coins + XP → spend coins on renovation tasks ("chores")
that restore the restaurant and unlock the next story scene. Further, as reported by guides:
- Energy: cap 100, +1 every 2 min (full in ~3 h 20 m); energy bottles are board items that merge
  into bigger bottles; level-ups refill energy; refills for gems escalate (10 → 20 → 40).
- Generators: tapping costs 1 energy and drops an item onto the nearest free tile; generators
  themselves merge to higher levels (better drops); some generators are free but have charges and
  a cooldown; merging a generator resets its timer; some are temporary (destroyed after N taps).
- Board: generators and items each take one tile; board space is the main constraint; items can
  be sold for coins (with a short undo); inventory ("cabinet") slots bought with gems.
- Merge bubbles: merging can spawn a bubbled bonus copy that can be popped with gems for a short
  time, otherwise it turns into coins.
- Scissors split an item into two of the level below; scissors stack.
- Coins, gems, energy bottles are mergeable resource items; collect when needed.
- Orders: a row of customer orders above the board, each 1–3 items; special requests/side-quest
  chains from named characters; order quests with their own capped generators.
- Story: each renovation task costs coins, plays a short scene, reveals clues; every restored
  object has three designs that can be switched for free; new chapters weekly.
- Levels: XP from chores/orders; levels unlock dishes/generators; level 15 generator boost (2×/4×).
- Live ops: season pass, coin races, dice board (Lucky Larks), collection events, card album,
  daily rewards, mailbox gifts. Monetisation: gem/energy bundles, season pass, rewarded video.

## LUMA Harbour design (original content)
**Setting & story.** The restored island has an old harbour whose lantern café burned down the
night the springs ran dry. Nell Marlowe comes home to reopen her grandfather's *Lantern Café*.
Someone on the island doesn't want it reopened — who, and why? Cast: Nell (lead), Tobias (old
fisherman), Ada (baker, Nell's childhood friend), Mayor Rafe Holloway, Juno (travelling
botanist), Pip (the café otter).

**Board.** 7 × 9 tiles. Start layout: two generators, a few items, and *crates* — tiles holding a
greyed item that is freed by merging a matching item onto it.

**Chains** (`resources/merge/items.json`): Coffee (beans → … → layered cake latte), Bakery
(flour → … → celebration pie), Catch (shell → … → seafood platter), Garden (seed → … → bouquet),
generator chains (Coffee Grinder, Flour Sack, Fishing Net, Seed Tin), resources (coins, gems,
energy bottles), chests (wood/silver/gold, timed), scissors.

**Economy (defaults, tuned in `resources/merge/balance.json`).** Energy cap 100, +1/120 s,
offline regeneration from wall-clock time. Level-up: energy refill + gems. Orders: 3 visible,
generated from unlocked chains with difficulty by player level; rewards coins + XP; occasional
story orders from named characters. Bubbles: 8 % on merges to level ≥ 4, 60 s, gem price by
level, otherwise 1 coin item. Inventory 4 slots, +1 for 10/20/40/… gems. Sell value by level,
5 s undo. Chests: timer or gems.

**Renovation & story** (`resources/merge/story.json`). Chapters of 5–8 tasks, each with a coin
cost, a short dialogue and an area of the café that changes; selected tasks offer 3 designs,
switchable for free. Finishing a chapter grants a reward and unlocks the next.

**Not included (needs owner decision / later phases).** Real-money purchases, ads, season pass,
leaderboards, online events and anything needing accounts or the internet (the app is offline and
requests no INTERNET permission). Gems are earned in play (level-ups, chapters, chests, gem items).

## Phases
1. **Core (this change):** rules engine, items/orders/energy/levels/bubbles/crates/inventory/sell/
   scissors/chests, renovation task list with story dialogues, merge screen, unlock after level 30,
   save + tests.
2. Café scene with per-task restoration and 3 designs per object, character portraits, daily
   reward calendar, mailbox, generator boost, order-quest chains.
3. Offline live-ops: weekly coin race vs. bots, collection event, dice board, card album.
4. Monetisation/ads only after an explicit owner decision (store setup, privacy review).

## Sources
- Deconstructor of Fun, “Finding Genre Success: the Case of Gossip Harbor” (2024-08-19)
- App Store listing, Gossip Harbor®: Merge & Story (id1623318294)
- App Store story “5 tips for Gossip Harbor”
- gossipharborguide.com/guides, u4gm.com beginner guide, fandom wiki “Scissors”

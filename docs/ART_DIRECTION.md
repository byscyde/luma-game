# Art direction

**Premium, warm, peaceful, tactile miniature-island diorama.** Readability first.

## Palette (`scripts/ui/palette.gd`)
- Night teal backgrounds (`#12303a`, `#1a4652`) so the warm board and island glow.
- Warm stone and sand for puzzle slabs (`#ecdcb9`, `#c9b48d`), carved wet-earth grooves (`#7a5b3e`).
- Turquoise water (`#3cc6d0`, deep `#1f93a8`, highlight `#b5f4f1`).
- Controlled greens for life (`#6dbe5b` family); dry tones (`#c2ab78`, `#b49a6c`) for the dormant state.
- Gold (`#f2c14e`) reserved for primary actions, glow and the Heart Tree.

## Puzzle readability rules
- Orthographic top-down board — perspective never distorts connections.
- **Rotatable** = round inset stone disc with four rim notches (the disc visibly turns).
  **Fixed** = square slab with corner rivets. Shape, not colour, carries the meaning.
- Water is drawn only inside connected channels and advances from the source ring by ring;
  spills show animated droplets at the open end.
- Targets are saplings that grow on the board; optional flower beds have a dashed gold ring.
- Gates/levers pair by **symbol + colour** (circle/triangle/square/diamond).
- Lever state: handle angle + filled dot (on) vs ring (off).

## Island
Isometric (2:1) heightmap, painter-ordered, lit from the upper left. Restoration reads at a
glance: ground colour shifts from straw to green with the area's restoration progress; objects
have distinct silhouettes per stage. Mist + lock badge for locked areas.

## Motion
Short and responsive: tile turn 0.14 s (back-ease), water ring step 0.075 s, result card
0.35 s, restoration 1.5 s per object. **Reduced motion** shortens or removes all of these and
disables particles/drift.

## Typography
Nunito (rounded, friendly, excellent legibility), weights 700/800. Minimum 22 px at the
720-px-wide base (≈ 12 pt on a 6.1" phone).

## Production approach
All art is drawn in code (`scripts/ui/painter.gd`): resolution independent, tiny download,
fully original, consistent. The app icon, SCYDE splash and loading key art are built from owner-supplied masters in `art/source` by `tools/build_brand_assets.py`. When a dedicated
artist joins, textures can replace Painter calls per element without touching gameplay.

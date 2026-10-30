class_name Palette
extends RefCounted
## LUMA colour language (see docs/ART_DIRECTION.md). Warm stone and wood,
## controlled greens, turquoise water, restrained gold glow.

const NIGHT := Color("12303a")
const DEEP := Color("1a4652")
const SEA := Color("2b8c9e")
const SEA_LIGHT := Color("57b3bf")
const FOAM := Color("d8f3ef")

const CREAM := Color("f8f1e1")
const SAND := Color("ecdcb9")
const SAND_SHADE := Color("d6c29a")
const STONE := Color("c9b48d")
const STONE_DARK := Color("9c8460")
const STONE_DEEP := Color("6f5b40")
const GROOVE := Color("7a5b3e")
const GROOVE_DARK := Color("553e2a")

const WATER := Color("3cc6d0")
const WATER_DEEP := Color("1f93a8")
const WATER_LIGHT := Color("b5f4f1")

const LEAF := Color("6dbe5b")
const LEAF_DARK := Color("3f8f4a")
const LEAF_DEEP := Color("2c6b3d")
const LEAF_LIGHT := Color("a9dd7c")
const GRASS := Color("8fc46a")
const GRASS_DRY := Color("c2ab78")
const DRY := Color("b49a6c")
const DRY_DARK := Color("8a7350")
const BARK := Color("7b5636")
const BARK_DARK := Color("5a3d25")

const GOLD := Color("f2c14e")
const GOLD_DEEP := Color("d99a2b")
const CORAL := Color("f28c9b")
const LILAC := Color("b89be8")
const ROCK := Color("8e939a")
const ROCK_DARK := Color("62676e")
const MOSS := Color("7fa956")

const TEXT := Color("2e3b36")
const TEXT_SOFT := Color("5d6b63")
const TEXT_LIGHT := Color("fdf8ec")
const SHADOW := Color(0.05, 0.1, 0.1, 0.28)

## Link colours + shapes so gates/switches never rely on colour alone.
const LINK_COLORS := [Color("f2c14e"), Color("b89be8"), Color("f28c9b"), Color("7fd1e0")]

# ---- UI design system (light lagoon / dark night lagoon) ----
# Static so the whole UI can switch with the device theme; set by apply().
static var dark := false
static var INK := Color("23423a")
static var INK_SOFT := Color("5f7b71")
static var PAPER := Color("ffffff")
static var SHEET := Color("fbf8f1")
const SUN := Color("ffc94a")
const SUN_EDGE := Color("e0952a")
const SUN_INK := Color("5a3a10")
static var SUN_SOFT := Color("fff3d1")
static var MINT_EDGE := Color("cfe2dc")
static var TEAL := Color("2c97a3")
static var TEAL_SOFT := Color("bfe6e4")
static var LAGOON_TOP := Color("dff3ee")
static var LAGOON_BOTTOM := Color("9ad6d6")
static var DISABLED := Color("e7ece9")
static var TRACK := Color("e4efeb")       ## slider / progress / switch-off track
static var MUTED := Color("cbd8d3")       ## inactive icons and stars
static var CHIP := Color(1, 1, 1, 0.9)
static var CALLOUT := Color(1, 1, 1, 0.95)
static var CARD_SHADOW := Color(0.08, 0.2, 0.2, 0.16)
static var MOTE := Color(1, 1, 1)          ## backdrop light motes and wave lines


static func apply(is_dark: bool) -> void:
	dark = is_dark
	if is_dark:
		INK = Color("e6f1ed")
		INK_SOFT = Color("9db8af")
		PAPER = Color("1c3a41")
		SHEET = Color("17323a")
		SUN_SOFT = Color("4a3d1c")
		MINT_EDGE = Color("0f262c")
		TEAL = Color("5ccbd1")
		TEAL_SOFT = Color("21505a")
		LAGOON_TOP = Color("12303a")
		LAGOON_BOTTOM = Color("0a1b22")
		DISABLED = Color("223f47")
		TRACK = Color("2a4a52")
		MUTED = Color("3d5d64")
		CHIP = Color(0.11, 0.23, 0.26, 0.92)
		CALLOUT = Color(0.11, 0.23, 0.26, 0.96)
		CARD_SHADOW = Color(0, 0, 0, 0.35)
		MOTE = Color(0.75, 0.95, 1.0)
	else:
		INK = Color("23423a")
		INK_SOFT = Color("5f7b71")
		PAPER = Color("ffffff")
		SHEET = Color("fbf8f1")
		SUN_SOFT = Color("fff3d1")
		MINT_EDGE = Color("cfe2dc")
		TEAL = Color("2c97a3")
		TEAL_SOFT = Color("bfe6e4")
		LAGOON_TOP = Color("dff3ee")
		LAGOON_BOTTOM = Color("9ad6d6")
		DISABLED = Color("e7ece9")
		TRACK = Color("e4efeb")
		MUTED = Color("cbd8d3")
		CHIP = Color(1, 1, 1, 0.9)
		CALLOUT = Color(1, 1, 1, 0.95)
		CARD_SHADOW = Color(0.08, 0.2, 0.2, 0.16)
		MOTE = Color(1, 1, 1)

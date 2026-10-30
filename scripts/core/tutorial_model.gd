class_name TutorialModel
extends RefCounted
## Tracks first-time-user-experience steps and one-time mechanic intros.
## Steps are keyed strings stored in save["tutorial"]["done"], so the tutorial
## resumes exactly where the player left off after an interruption.

## Steps of the guided onboarding, in order. Completing the level that carries
## a step marks it done.
const ONBOARDING := ["tap_to_rotate", "restore_tree", "multi_turns", "blocker", "milestone"]

## Caption shown on the board for each tutorial key (translation keys).
const CAPTIONS := {
	"tap_to_rotate": "TUT_TAP_TO_ROTATE",
	"restore_tree": "TUT_RESTORE_TREE",
	"multi_turns": "TUT_MULTI_TURNS",
	"blocker": "TUT_BLOCKER",
	"milestone": "TUT_MILESTONE",
	"intro_tee": "TUT_INTRO_TEE",
	"intro_bonus": "TUT_INTRO_BONUS",
	"intro_no_leaks": "TUT_INTRO_NO_LEAKS",
	"intro_gate": "TUT_INTRO_GATE",
	"intro_inverted_gate": "TUT_INTRO_INVERTED_GATE",
	"intro_cross": "TUT_INTRO_CROSS",
	"intro_pinned": "TUT_INTRO_PINNED",
}

## Onboarding steps that show a pointing hand on the best tile.
const POINTER_STEPS := ["tap_to_rotate", "restore_tree"]

var t: Dictionary  ## save["tutorial"]


func _init(tutorial_section: Dictionary) -> void:
	t = tutorial_section


func is_done(step: String) -> bool:
	return t["done"].has(step)


func mark_done(step: String) -> bool:
	if step == "" or is_done(step):
		return false
	t["done"].append(step)
	if not t["complete"]:
		var all := true
		for s in ONBOARDING:
			if not is_done(s):
				all = false
				break
		t["complete"] = all
	return true


func is_complete() -> bool:
	return bool(t["complete"])


## Whether the board should show this level's tutorial caption.
func should_show(step: String) -> bool:
	return step != "" and CAPTIONS.has(step) and not is_done(step)


func caption_key(step: String) -> String:
	return CAPTIONS.get(step, "")


func wants_pointer(step: String) -> bool:
	return POINTER_STEPS.has(step) and not is_done(step)

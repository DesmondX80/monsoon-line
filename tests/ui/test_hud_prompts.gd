extends GutTest
## M2-06: HUDin tehtäväohje, otsikkokortti ja lempinimikortti EventBus-signaaleista.

var _hud: Hud


func before_each() -> void:
	_hud = (load("res://ui/hud.tscn") as PackedScene).instantiate() as Hud
	add_child_autofree(_hud)


func test_objective_prompt_shows_finnish_by_default() -> void:
	EventBus.objective_prompt.emit("Hyppää ovesta (F tai Space)", "Jump out the door (F or Space)")
	assert_eq(_hud.get_objective_text(), "Hyppää ovesta (F tai Space)")


func test_objective_prompt_english_and_fallback() -> void:
	_hud.language = &"en"
	EventBus.objective_prompt.emit("Juokse", "Run")
	assert_eq(_hud.get_objective_text(), "Run")
	EventBus.objective_prompt.emit("Vain suomeksi", "")
	assert_eq(_hud.get_objective_text(), "Vain suomeksi", "puuttuva käännös korvataan")


func test_empty_objective_hides() -> void:
	EventBus.objective_prompt.emit("Juokse", "Run")
	EventBus.objective_prompt.emit("", "")
	assert_eq(_hud.get_objective_text(), "")
	assert_false((_hud.get_node(^"Objective") as Control).visible)


func test_nickname_card() -> void:
	EventBus.nickname_assigned.emit("Lawn Dart")
	assert_eq(_hud.get_nickname_card_text(), "Lempinimesi: LAWN DART")


func test_title_card_shows_and_fades_out() -> void:
	EventBus.title_card.emit("Katum, Tay Ninh", "22. helmikuuta 1967")
	assert_true(_hud.is_title_card_visible())
	assert_eq((_hud.get_node(^"TitleCard/Band/VBox/Title") as Label).text, "KATUM, TAY NINH")
	await wait_seconds(Hud.TITLE_FADE_IN + Hud.TITLE_HOLD + Hud.TITLE_FADE_OUT + 0.4)
	assert_false(_hud.is_title_card_visible(), "kortti häipyy noin 4 sekunnissa")


func test_hud_contains_fade_layer() -> void:
	var fade: FadeLayer = _hud.get_fade_layer()
	assert_not_null(fade)
	assert_true(fade.is_in_group(&"fade_layer"))

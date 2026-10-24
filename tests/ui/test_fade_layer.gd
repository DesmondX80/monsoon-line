extends GutTest
## M2-06: FadeLayer – häivytys, ryhmä "fade_layer" ja staattinen haku.

const FADE_SCENE: String = "res://ui/fade_layer.tscn"


func _make(auto: bool) -> FadeLayer:
	var fade: FadeLayer = (load(FADE_SCENE) as PackedScene).instantiate() as FadeLayer
	fade.auto_fade_in = auto
	add_child_autofree(fade)
	return fade


func test_in_group_and_findable() -> void:
	var fade: FadeLayer = _make(false)
	assert_true(fade.is_in_group(&"fade_layer"))
	assert_eq(FadeLayer.find(get_tree()), fade)


func test_auto_fade_in_starts_black() -> void:
	var fade: FadeLayer = _make(true)
	assert_almost_eq(fade.get_opacity(), 1.0, 0.05, "alkaa mustana")
	assert_true(fade.is_fading())


func test_fade_out_reaches_black_within_limit() -> void:
	var fade: FadeLayer = _make(false)
	assert_almost_eq(fade.get_opacity(), 0.0, 0.001)
	assert_lte(FadeLayer.DEFAULT_FADE_OUT, 1.2, "ohjaajat vaihtavat scenen 1,5 s jälkeen")
	fade.fade_out(0.2)
	await wait_for_signal(fade.fade_out_finished, 1.0)
	assert_almost_eq(fade.get_opacity(), 1.0, 0.001)


func test_fade_in_clears() -> void:
	var fade: FadeLayer = _make(false)
	fade.set_black(true)
	fade.fade_in(0.2)
	await wait_for_signal(fade.fade_in_finished, 1.0)
	assert_almost_eq(fade.get_opacity(), 0.0, 0.001)


func test_zero_duration_is_instant() -> void:
	var fade: FadeLayer = _make(false)
	fade.fade_out(0.0)
	assert_almost_eq(fade.get_opacity(), 1.0, 0.001)
	fade.fade_in(0.0)
	assert_almost_eq(fade.get_opacity(), 0.0, 0.001)

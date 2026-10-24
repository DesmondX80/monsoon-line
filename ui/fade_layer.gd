class_name FadeLayer
extends CanvasLayer
## Ruudun häivytys mustaan ja takaisin scene-vaihtojen yhteyteen (M2-06). Ei autoload.
##
## HUD instansioi tämän, joten jokainen HUDilla varustettu taso saa sen: kun scene käynnistyy,
## kerros alkaa mustana ja häivyttyy automaattisesti näkyviin (auto_fade_in).
##
## Käyttö ohjaajista (solmu on ryhmässä "fade_layer"):
##   await FadeLayer.fade_out_tree(get_tree())          # staattinen apu, toimii ilman HUDia
##   FadeLayer.change_scene_with_fade(get_tree(), path)   # häivytys + scene-vaihto
##   var fade: FadeLayer = FadeLayer.find(get_tree())     # suora viittaus tai null
##   fade.fade_out(1.0) / fade.fade_in(1.0) / fade.set_black(true)
## Signaalit fade_out_finished ja fade_in_finished kertovat valmistumisesta.

signal fade_out_finished
signal fade_in_finished

const GROUP: StringName = &"fade_layer"
## Oletuskesto. Ohjaajat vaihtavat scenen 1,5 s fade_out-kutsun jälkeen, joten pidä alle 1,2 s.
const DEFAULT_FADE_OUT: float = 1.0
const DEFAULT_FADE_IN: float = 1.2

## Häivytetäänkö näkyviin automaattisesti, kun kerros tulee puuhun (uuden scenen alku).
@export var auto_fade_in: bool = true
## Automaattisen häivytyksen kesto sekunteina.
@export var auto_fade_in_duration: float = DEFAULT_FADE_IN
@export var fade_color: Color = Color(0.0, 0.0, 0.0, 1.0)

var _rect: ColorRect
var _tween: Tween


func _init() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	_ensure_rect()
	if auto_fade_in:
		set_black(true)
		fade_in(auto_fade_in_duration)
	else:
		set_black(false)


# --- Julkinen rajapinta -------------------------------------------------------

## Häivyttää ruudun mustaksi. Palauttaa signaalin, jota voi odottaa: `await fade.fade_out()`.
func fade_out(duration: float = DEFAULT_FADE_OUT) -> Signal:
	_fade_to(1.0, duration, fade_out_finished)
	return fade_out_finished


## Häivyttää mustasta näkyviin. Palauttaa signaalin, jota voi odottaa.
func fade_in(duration: float = DEFAULT_FADE_IN) -> Signal:
	_fade_to(0.0, duration, fade_in_finished)
	return fade_in_finished


## Asettaa ruudun heti mustaksi (true) tai näkyviin (false) ilman häivytystä.
func set_black(black: bool) -> void:
	_ensure_rect()
	_kill_tween()
	_rect.modulate.a = 1.0 if black else 0.0
	_rect.visible = black


## Mustan peiton nykyinen peittävyys 0–1.
func get_opacity() -> float:
	_ensure_rect()
	return _rect.modulate.a if _rect.visible else 0.0


## Onko häivytys käynnissä.
func is_fading() -> bool:
	return _tween != null and _tween.is_valid() and _tween.is_running()


## Ensimmäinen puussa oleva FadeLayer tai null.
static func find(tree: SceneTree) -> FadeLayer:
	if tree == null:
		return null
	return tree.get_first_node_in_group(GROUP) as FadeLayer


## Hakee FadeLayerin tai luo väliaikaisen juureen (ei automaattista sisäänhäivytystä).
static func find_or_create(tree: SceneTree) -> FadeLayer:
	var existing: FadeLayer = find(tree)
	if existing != null:
		return existing
	var created: FadeLayer = FadeLayer.new()
	created.name = "FadeLayer"
	created.auto_fade_in = false
	if tree.current_scene != null:
		tree.current_scene.add_child(created)
	else:
		tree.root.add_child(created)
	return created


## Staattinen apu: häivyttää mustaksi ja palauttaa odotettavan signaalin.
static func fade_out_tree(tree: SceneTree, duration: float = DEFAULT_FADE_OUT) -> Signal:
	return find_or_create(tree).fade_out(duration)


## Staattinen apu: häivyttää näkyviin ja palauttaa odotettavan signaalin.
static func fade_in_tree(tree: SceneTree, duration: float = DEFAULT_FADE_IN) -> Signal:
	return find_or_create(tree).fade_in(duration)


## Häivyttää mustaksi ja vaihtaa scenen. Uuden scenen HUD häivyttää takaisin näkyviin.
static func change_scene_with_fade(tree: SceneTree, path: String, duration: float = DEFAULT_FADE_OUT) -> void:
	var fade: FadeLayer = find_or_create(tree)
	await fade.fade_out(duration)
	var err: Error = tree.change_scene_to_file(path)
	if err != OK:
		push_error("FadeLayer: scenen '%s' lataus epäonnistui (%s)" % [path, error_string(err)])
		fade.fade_in(0.3)


# --- Sisäiset ------------------------------------------------------------------

func _ensure_rect() -> void:
	if _rect != null:
		return
	_rect = get_node_or_null(^"Black") as ColorRect
	if _rect == null:
		_rect = ColorRect.new()
		_rect.name = "Black"
		add_child(_rect)
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.color = fade_color


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _fade_to(target: float, duration: float, done: Signal) -> void:
	_ensure_rect()
	_kill_tween()
	_rect.visible = true
	if duration <= 0.0 or not is_inside_tree():
		_rect.modulate.a = target
		_rect.visible = target > 0.0
		done.emit.call_deferred()
		return
	_tween = create_tween()
	_tween.tween_property(_rect, ^"modulate:a", target, duration * absf(_rect.modulate.a - target))
	_tween.tween_callback(func() -> void:
		_rect.visible = target > 0.0
		done.emit()
	)

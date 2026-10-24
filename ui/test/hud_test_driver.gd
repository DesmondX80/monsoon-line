extends Node
## HUD-testiscenen ohjain: ajaa kaikki HUDin ja AudioDirectorin polut läpi
## lähettämällä EventBus-signaaleja ja painamalla F3. Tulostaa tulokset konsoliin.
## Käyttö: godot --headless res://ui/test/hud_test.tscn --quit-after 200

var _frame: int = 0


func _process(_delta: float) -> void:
	_frame += 1
	var player: Node = PlayerLookup.find_player(get_tree())
	var hud: Hud = get_parent().get_node_or_null(^"HUD") as Hud
	match _frame:
		5:
			_check(hud != null, "HUD löytyy")
			_check(player != null, "pelaaja löytyy")
			_toggle_f3()
		10:
			var overlay: CanvasLayer = hud.get_node_or_null(^"DebugOverlay") as CanvasLayer
			_check(overlay != null and overlay.visible, "F3 avaa debug-näkymän")
			var supp: Node = PlayerLookup.get_suppression(player)
			if supp != null and supp.has_method(&"register_near_miss"):
				supp.call(&"register_near_miss", 0.5)
			EventBus.bullet_snap.emit(player as Node3D, 1.0)
			var health: Node = PlayerLookup.get_health(player)
			if health != null and health.has_method(&"take_hit"):
				health.call(&"take_hit", 5.0, &"arm_l")
		20:
			var weapon: Node = PlayerLookup.get_weapon(player)
			if weapon != null and &"heat" in weapon:
				weapon.set(&"heat", 0.95)
			EventBus.shot_fired.emit(player as Node3D, Vector3(0, 1.5, -2), Vector3.FORWARD)
			EventBus.barrel_overheated.emit(weapon)
			EventBus.squad_callout.emit(null, &"tibbs_welcome")
			EventBus.squad_callout.emit(player as Node3D, &"sl_gun_up")
			# Vieras ase ei saa näyttää vihjettä.
			var foreign: Node = Node.new()
			EventBus.belt_empty.emit(foreign)
			foreign.free()
		30:
			_check(AudioDirector.is_wildlife_quiet(), "ambienssi hiljenee laukauksen jälkeen")
			var effects: ColorRect = hud.get_node(^"Effects") as ColorRect
			_check(effects.visible, "efektit näkyvät pelaajan tilasta")
			var subs: RichTextLabel = hud.get_node(^"Subtitles") as RichTextLabel
			_check(subs.text.contains("Tibbs"), "Tibbsin tekstitys näkyy")
			var catalog: VoiceLineCatalog = VoiceLineCatalog.get_default()
			_check(catalog != null and catalog.lines.size() >= 15, "katalogissa ainakin 15 repliikkiä")
			var weapon: Node = PlayerLookup.get_weapon(player)
			if weapon != null and &"jammed" in weapon:
				weapon.set(&"jammed", true)
		40:
			_toggle_f3()
		45:
			var overlay: CanvasLayer = hud.get_node(^"DebugOverlay") as CanvasLayer
			_check(not overlay.visible, "F3 piilottaa debug-näkymän")
			_check((hud.get_node(^"Hint") as Label).text.contains("jumissa"), "jumitusvihje näkyy")
			# Korvataan pelaaja tyngällä, jolta puuttuvat kaikki lapsisolmut: HUD ei saa kaatua.
			if player != null:
				player.queue_free()
			var stub: Node3D = Node3D.new()
			stub.name = "StubPlayer"
			stub.add_to_group(&"player")
			get_parent().add_child(stub)
			_toggle_f3()
		60:
			var stub: Node = get_parent().get_node_or_null(^"StubPlayer")
			EventBus.actor_hit.emit(stub as Node3D, 10.0, &"torso")
			EventBus.suppression_changed.emit(stub as Node3D, 0.8)
		70:
			var stub: Node = get_parent().get_node_or_null(^"StubPlayer")
			if stub != null:
				stub.queue_free()
		80:
			AudioDirector.set("_quiet_left", 0.0)
		150:
			_check(AudioDirector.wildlife_level > 0.0, "ambienssi palaa hiljaisuuden jälkeen")
			print("HUD_TEST: valmis")


func _toggle_f3() -> void:
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_F3
	key.pressed = true
	Input.parse_input_event(key)
	var release: InputEventKey = key.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("HUD_TEST ok: %s" % label)
	else:
		print("HUD_TEST FAIL: %s" % label)

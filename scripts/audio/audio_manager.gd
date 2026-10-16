class_name AudioManager
extends Node

const SOUNDS := {
	"step": preload("res://assets/audio/step.wav"),
	"place": preload("res://assets/audio/place.wav"),
	"fuse": preload("res://assets/audio/fuse.wav"),
	"explosion": preload("res://assets/audio/explosion.wav"),
	"crate": preload("res://assets/audio/crate.wav"),
	"pickup": preload("res://assets/audio/pickup.wav"),
	"death": preload("res://assets/audio/death.wav"),
	"victory": preload("res://assets/audio/victory.wav"),
	"defeat": preload("res://assets/audio/defeat.wav"),
	"ui": preload("res://assets/audio/ui.wav")}
var voices: Array[AudioStreamPlayer] = []
var settings: GameSettings
const PRIORITY := {"step": 0, "fuse": 1, "crate": 2, "place": 3, "explosion": 4, "pickup": 5, "death": 6, "ui": 7, "victory": 8, "defeat": 8}
var play_order: int = 0
# Headless QA validates assets/events/buses without starting inaudible dummy-driver voices.
var playback_enabled: bool = DisplayServer.get_name() != "headless"

func _ready() -> void:
	for bus in ["SFX", "UI", "Music", "Ambience"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, "Master")
	for i in range(8):
		var player := AudioStreamPlayer.new()
		add_child(player)
		voices.append(player)

func apply_settings(value: GameSettings) -> void:
	settings = value
	for pair in [["Master", value.master], ["SFX", value.sfx], ["UI", value.ui]]:
		var index := AudioServer.get_bus_index(pair[0])
		AudioServer.set_bus_mute(index, pair[1] <= 0.0)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(0.001, pair[1])))

func play(kind: String) -> void:
	if not SOUNDS.has(kind) or not playback_enabled:
		return
	var active: Array[Dictionary] = []
	for player in voices:
		active.append({"playing": player.playing, "kind": player.get_meta("kind", "step"), "order": player.get_meta("order", 0)})
	var index := select_voice(active, kind)
	if index < 0: return
	var voice := voices[index]
	voice.stop()
	play_order += 1
	voice.set_meta("kind", kind)
	voice.set_meta("order", play_order)
	voice.bus = "UI" if kind == "ui" else "SFX"
	voice.stream = SOUNDS[kind]
	voice.play()

static func select_voice(active: Array[Dictionary], kind: String) -> int:
	if not PRIORITY.has(kind): return -1
	var candidate := -1
	for i in range(active.size()):
		if not active[i].playing: return i
		if candidate < 0 or PRIORITY[active[i].kind] < PRIORITY[active[candidate].kind] or (PRIORITY[active[i].kind] == PRIORITY[active[candidate].kind] and active[i].order < active[candidate].order):
			candidate = i
	if candidate >= 0 and PRIORITY[kind] >= PRIORITY[active[candidate].kind]: return candidate
	return -1

func stop_effects() -> void:
	for voice in voices:
		voice.stop()

func _exit_tree() -> void:
	for voice in voices:
		voice.stop()
		voice.stream = null

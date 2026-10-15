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
	var voice: AudioStreamPlayer = null
	for player in voices:
		if not player.playing:
			voice = player
			break
	# Quiet feedback may be dropped under load; crucial events preempt the first voice.
	if voice == null:
		if kind in ["step", "fuse", "crate"]:
			return
		voice = voices[0]
	voice.stop()
	voice.bus = "UI" if kind == "ui" else "SFX"
	voice.stream = SOUNDS[kind]
	voice.play()

func stop_effects() -> void:
	for voice in voices:
		voice.stop()

func _exit_tree() -> void:
	for voice in voices:
		voice.stop()
		voice.stream = null

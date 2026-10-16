class_name RuntimeBundle
extends RefCounted

const PATH := "res://resources/data/runtime.bin"

static func section(name: String) -> Dictionary:
	if not FileAccess.file_exists(PATH): return {}
	var envelope := SealedData.open_bytes(FileAccess.get_file_as_bytes(PATH), "runtime")
	var payload = envelope.get("payload")
	if not payload is Dictionary or not payload.get(name) is Dictionary: return {}
	return payload[name]

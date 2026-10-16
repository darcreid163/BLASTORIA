class_name SealedData
extends RefCounted

# Local anti-spoiler container. A player controlling this offline client can recover keys.
# These are client content keys, NEVER credentials or server verification secrets.
const HEADER := "BLST024A"
const LIMIT := 262144
const CONTENT_KEY := [201, 53, 224, 88, 17, 152, 245, 66, 132, 98, 196, 35, 71, 2, 192, 124, 246, 174, 76, 153, 6, 239, 177, 41, 167, 249, 101, 12, 93, 188, 216, 34]
const AUTH_KEY := [65, 249, 122, 190, 87, 41, 216, 233, 7, 93, 160, 204, 179, 44, 138, 171, 50, 5, 211, 253, 97, 109, 155, 16, 28, 195, 203, 82, 91, 117, 26, 225]

static func seal(value: Dictionary, purpose: String) -> PackedByteArray:
	var source := JSON.stringify(value).to_utf8_buffer()
	if source.size() > LIMIT - 80:
		return PackedByteArray()
	var padding := 16 - source.size() % 16
	for _i in range(padding): source.append(padding)
	var crypto := Crypto.new()
	var iv := crypto.generate_random_bytes(16)
	var aes := AESContext.new()
	if aes.start(AESContext.MODE_CBC_ENCRYPT, PackedByteArray(CONTENT_KEY), iv) != OK:
		return PackedByteArray()
	var body := HEADER.to_utf8_buffer() + iv + aes.update(source)
	aes.finish()
	var tag := crypto.hmac_digest(HashingContext.HASH_SHA256, PackedByteArray(AUTH_KEY), purpose.to_utf8_buffer() + body)
	return body + tag

static func open_bytes(bytes: PackedByteArray, purpose: String) -> Dictionary:
	if bytes.size() < 72 or bytes.size() > LIMIT or (bytes.size() - 56) % 16 != 0 or bytes.slice(0, 8).get_string_from_ascii() != HEADER:
		return {}
	var body := bytes.slice(0, bytes.size() - 32)
	var crypto := Crypto.new()
	var expected := crypto.hmac_digest(HashingContext.HASH_SHA256, PackedByteArray(AUTH_KEY), purpose.to_utf8_buffer() + body)
	if not crypto.constant_time_compare(expected, bytes.slice(bytes.size() - 32)):
		return {} # Authenticate before decrypting, including IV/header and purpose.
	var aes := AESContext.new()
	if aes.start(AESContext.MODE_CBC_DECRYPT, PackedByteArray(CONTENT_KEY), body.slice(8, 24)) != OK:
		return {}
	var plain := aes.update(body.slice(24))
	aes.finish()
	if plain.is_empty(): return {}
	var padding := int(plain[-1])
	if padding < 1 or padding > 16 or padding > plain.size(): return {}
	for i in range(plain.size() - padding, plain.size()):
		if plain[i] != padding: return {}
	var parser := JSON.new()
	if parser.parse(plain.slice(0, plain.size() - padding).get_string_from_utf8()) != OK or not parser.data is Dictionary:
		return {}
	return parser.data

static func open_hex(value: Variant, purpose: String) -> Dictionary:
	if not value is String or value.length() > LIMIT * 2 or value.length() % 2 != 0:
		return {}
	for c in value:
		if not c in "0123456789abcdef": return {}
	return open_bytes(value.hex_decode(), purpose)

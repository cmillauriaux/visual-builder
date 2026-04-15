# Animation APNG Foreground — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Intégrer les animations APNG comme foregrounds avec options de lecture (Reverse, Speed, Loop, Reverse Loop) dans l'éditeur et le player.

**Architecture:** Un `ApngLoader` statique parse les chunks binaires APNG et retourne frames + délais. Un `ForegroundAnimPlayer` (Control node) cycle les frames via `_process()`. Le modèle `Foreground` reçoit 4 champs `anim_*`. La galerie expose un filtre "Animations" et accepte les `.apng`. Le `sequence_visual_editor` bascule sur `ForegroundAnimPlayer` quand `fg.image.ends_with(".apng")`.

**Tech Stack:** GDScript / Godot 4.6.1, GUT 9.3.0 pour les tests.

---

## Fichiers créés / modifiés

| Fichier | Action |
|---|---|
| `src/ui/shared/apng_loader.gd` | **Créé** — parser binaire APNG |
| `src/ui/visual/foreground_anim_player.gd` | **Créé** — lecteur de frames animées |
| `src/models/foreground.gd` | **Modifié** — +4 champs `anim_*` |
| `src/controllers/sequence_ui_controller.gd` | **Modifié** — +4 propriétés dans `TRACKED_FG_PROPERTIES` |
| `src/ui/dialogs/gallery_dialog.gd` | **Modifié** — extensions + filtre Animations + badge |
| `src/services/gallery_cleaner_service.gd` | **Modifié** — +`"apng"` aux extensions |
| `src/ui/sequence/sequence_visual_editor.gd` | **Modifié** — chemin APNG dans `_update_single_fg_visual` |
| `src/ui/sequence/foreground_properties_panel.gd` | **Modifié** — section Animation conditionnelle |
| `specs/models/test_foreground.gd` | **Modifié** — +tests champs anim |
| `specs/ui/shared/test_apng_loader.gd` | **Créé** — tests ApngLoader |
| `specs/ui/visual/test_foreground_anim_player.gd` | **Créé** — tests ForegroundAnimPlayer |
| `specs/ui/dialogs/test_gallery_dialog.gd` | **Modifié** — +tests filtre APNG |

---

## Task 1 : Foreground model — champs animation

**Files:**
- Modify: `src/models/foreground.gd`
- Modify: `src/controllers/sequence_ui_controller.gd:20-24`
- Test: `specs/models/test_foreground.gd`

- [ ] **Step 1 : Écrire les tests qui vont échouer**

Ajouter à la fin de `specs/models/test_foreground.gd` :

```gdscript
# --- Tests champs animation ---

func test_anim_default_values():
	var fg = Foreground.new()
	assert_eq(fg.anim_speed, 1.0)
	assert_eq(fg.anim_reverse, false)
	assert_eq(fg.anim_loop, true)
	assert_eq(fg.anim_reverse_loop, false)

func test_anim_speed_clamped_min():
	var fg = Foreground.new()
	fg.anim_speed = 0.0
	assert_eq(fg.anim_speed, 0.1, "anim_speed minimum = 0.1")

func test_anim_speed_clamped_max():
	var fg = Foreground.new()
	fg.anim_speed = 10.0
	assert_eq(fg.anim_speed, 4.0, "anim_speed maximum = 4.0")

func test_anim_speed_valid():
	var fg = Foreground.new()
	fg.anim_speed = 2.0
	assert_eq(fg.anim_speed, 2.0)

func test_to_dict_excludes_anim_fields_for_static_image():
	var fg = Foreground.new()
	fg.image = "assets/foregrounds/hero.png"
	var d = fg.to_dict()
	assert_false(d.has("anim_speed"), "champs anim absents pour PNG statique")
	assert_false(d.has("anim_reverse"))
	assert_false(d.has("anim_loop"))
	assert_false(d.has("anim_reverse_loop"))

func test_to_dict_includes_anim_fields_for_apng():
	var fg = Foreground.new()
	fg.image = "assets/foregrounds/character.apng"
	fg.anim_speed = 2.0
	fg.anim_reverse = true
	fg.anim_loop = false
	fg.anim_reverse_loop = true
	var d = fg.to_dict()
	assert_eq(d["anim_speed"], 2.0)
	assert_eq(d["anim_reverse"], true)
	assert_eq(d["anim_loop"], false)
	assert_eq(d["anim_reverse_loop"], true)

func test_from_dict_anim_fields():
	var d = {
		"uuid": "fg-anim",
		"name": "AnimChar",
		"image": "assets/foregrounds/character.apng",
		"anim_speed": 0.5,
		"anim_reverse": true,
		"anim_loop": false,
		"anim_reverse_loop": true,
	}
	var fg = Foreground.from_dict(d)
	assert_eq(fg.anim_speed, 0.5)
	assert_eq(fg.anim_reverse, true)
	assert_eq(fg.anim_loop, false)
	assert_eq(fg.anim_reverse_loop, true)

func test_from_dict_anim_defaults_when_missing():
	var d = {"uuid": "fg-anim", "name": "AnimChar", "image": "character.apng"}
	var fg = Foreground.from_dict(d)
	assert_eq(fg.anim_speed, 1.0)
	assert_eq(fg.anim_reverse, false)
	assert_eq(fg.anim_loop, true)
	assert_eq(fg.anim_reverse_loop, false)
```

- [ ] **Step 2 : Vérifier que les tests échouent**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/models/test_foreground.gd 2>&1 | tail -20
```
Attendu : plusieurs FAIL sur les nouvelles fonctions.

- [ ] **Step 3 : Implémenter les champs dans `src/models/foreground.gd`**

Après la ligne `var _transition_duration: float = 0.5` (ligne ~17), ajouter :

```gdscript
var _anim_speed: float = 1.0
var anim_reverse: bool = false
var anim_loop: bool = true
var anim_reverse_loop: bool = false

var anim_speed: float:
	get:
		return _anim_speed
	set(value):
		_anim_speed = clampf(value, 0.1, 4.0)
```

Dans `to_dict()`, remplacer le `return { ... }` existant par :

```gdscript
func to_dict() -> Dictionary:
	var d = {
		"uuid": uuid,
		"name": fg_name,
		"image": image,
		"z_order": z_order,
		"opacity": opacity,
		"flip_h": flip_h,
		"flip_v": flip_v,
		"scale": scale,
		"anchor_bg": {"x": anchor_bg.x, "y": anchor_bg.y},
		"anchor_fg": {"x": anchor_fg.x, "y": anchor_fg.y},
		"transition_type": transition_type,
		"transition_duration": transition_duration,
	}
	if image.ends_with(".apng"):
		d["anim_speed"] = anim_speed
		d["anim_reverse"] = anim_reverse
		d["anim_loop"] = anim_loop
		d["anim_reverse_loop"] = anim_reverse_loop
	return d
```

Dans `from_dict()`, après `fg.transition_duration = ...` (fin de la fonction), ajouter :

```gdscript
	fg.anim_speed = d.get("anim_speed", 1.0)
	fg.anim_reverse = d.get("anim_reverse", false)
	fg.anim_loop = d.get("anim_loop", true)
	fg.anim_reverse_loop = d.get("anim_reverse_loop", false)
	return fg
```

- [ ] **Step 4 : Ajouter les propriétés dans `TRACKED_FG_PROPERTIES`** (`src/controllers/sequence_ui_controller.gd:20-24`)

```gdscript
const TRACKED_FG_PROPERTIES := [
	"anchor_bg", "scale", "z_order",
	"flip_h", "flip_v", "opacity",
	"transition_type", "transition_duration",
	"anim_speed", "anim_reverse", "anim_loop", "anim_reverse_loop",
]
```

- [ ] **Step 5 : Vérifier que les tests passent**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/models/test_foreground.gd 2>&1 | tail -20
```
Attendu : tous les tests PASS.

- [ ] **Step 6 : Commit**

```bash
git add src/models/foreground.gd src/controllers/sequence_ui_controller.gd specs/models/test_foreground.gd
git commit -m "feat: foreground model — champs animation anim_speed/reverse/loop/reverse_loop"
```

---

## Task 2 : ApngLoader — parser binaire APNG

**Files:**
- Create: `src/ui/shared/apng_loader.gd`
- Create: `specs/ui/shared/test_apng_loader.gd`

- [ ] **Step 1 : Écrire les tests**

Créer `specs/ui/shared/test_apng_loader.gd` :

```gdscript
# SPDX-License-Identifier: AGPL-3.0-only
extends GutTest

const ApngLoader = preload("res://src/ui/shared/apng_loader.gd")

# PNG 1x1 blanc encodé en base64 (format valide, pas d'APNG)
const MINIMAL_PNG_B64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII="

func test_empty_buffer_returns_empty():
	var result = ApngLoader.load_from_buffer(PackedByteArray())
	assert_eq(result, {})

func test_invalid_signature_returns_empty():
	var result = ApngLoader.load_from_buffer(PackedByteArray([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]))
	assert_eq(result, {})

func test_valid_png_returns_one_frame():
	var data = Marshalls.base64_to_raw(MINIMAL_PNG_B64)
	var result = ApngLoader.load_from_buffer(data)
	assert_true(result.has("frames"), "doit avoir 'frames'")
	assert_true(result.has("delays"), "doit avoir 'delays'")
	assert_eq((result["frames"] as Array).size(), 1, "PNG sans acTL → 1 frame")
	assert_eq((result["delays"] as Array).size(), 1)
	assert_almost_eq(result["delays"][0] as float, 1.0 / 12.0, 0.001, "délai par défaut")

func test_read_uint32_be():
	var data = PackedByteArray([0x00, 0x00, 0x00, 0x0D])
	assert_eq(ApngLoader._read_uint32_be(data, 0), 13)

func test_read_uint32_be_large():
	var data = PackedByteArray([0x01, 0x00, 0x00, 0x00])
	assert_eq(ApngLoader._read_uint32_be(data, 0), 16777216)

func test_read_uint16_be():
	var data = PackedByteArray([0x00, 0x0A])
	assert_eq(ApngLoader._read_uint16_be(data, 0), 10)

func test_make_idat_chunk_has_correct_length():
	var payload = PackedByteArray([1, 2, 3, 4])
	var chunk = ApngLoader._make_idat_chunk(payload)
	# 4 bytes length + 4 bytes "IDAT" + 4 bytes payload + 4 bytes CRC = 16
	assert_eq(chunk.size(), 16)
	# First 4 bytes = length = 4
	assert_eq(ApngLoader._read_uint32_be(chunk, 0), 4)
	# Bytes 4-7 = "IDAT"
	assert_eq(chunk[4], 0x49)  # I
	assert_eq(chunk[5], 0x44)  # D
	assert_eq(chunk[6], 0x41)  # A
	assert_eq(chunk[7], 0x54)  # T

func test_crc32_known_value():
	# CRC32 de "IEND" = 0xAE426082
	var data = PackedByteArray([0x49, 0x45, 0x4E, 0x44])
	assert_eq(ApngLoader._crc32(data), 0xAE426082)

func test_load_nonexistent_file_returns_empty():
	var result = ApngLoader.load("/tmp/nonexistent_apng_test_file_xyz.apng")
	assert_eq(result, {})
```

- [ ] **Step 2 : Vérifier que les tests échouent**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/ui/shared/test_apng_loader.gd 2>&1 | tail -20
```
Attendu : erreur "preload failed" ou FAIL.

- [ ] **Step 3 : Créer `src/ui/shared/apng_loader.gd`**

```gdscript
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends RefCounted
class_name ApngLoader

## Parse un fichier APNG et extrait ses frames et délais.
## Retourne {} en cas d'erreur.
## Retourne { "frames": Array[ImageTexture], "delays": Array[float] } en cas de succès.

const PNG_SIG = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
const DEFAULT_DELAY = 1.0 / 12.0

static func load(path: String) -> Dictionary:
	var fa = FileAccess.open(path, FileAccess.READ)
	if not fa:
		return {}
	var data = fa.get_buffer(fa.get_length())
	fa.close()
	return load_from_buffer(data)


static func load_from_buffer(data: PackedByteArray) -> Dictionary:
	if data.size() < 8:
		return {}
	for i in range(8):
		if data[i] != PNG_SIG[i]:
			return {}

	var offset = 8
	var ihdr_chunk := PackedByteArray()
	var actl_found := false
	var current_delay := DEFAULT_DELAY
	var current_idat_parts: Array[PackedByteArray] = []
	var frame_delays: Array[float] = []
	var frame_parts_list: Array = []  # Array of Array[PackedByteArray]

	while offset + 8 <= data.size():
		var chunk_start = offset
		var chunk_len = _read_uint32_be(data, offset)
		offset += 4
		if offset + 4 > data.size():
			break
		var type_bytes = data.slice(offset, offset + 4)
		var type_str = type_bytes.get_string_from_ascii()
		offset += 4
		var chunk_data := PackedByteArray()
		if chunk_len > 0 and offset + chunk_len <= data.size():
			chunk_data = data.slice(offset, offset + chunk_len)
		offset += chunk_len
		var full_chunk = data.slice(chunk_start, offset + 4)
		offset += 4  # skip CRC

		match type_str:
			"IHDR":
				ihdr_chunk = full_chunk
			"acTL":
				actl_found = true
			"fcTL":
				# Flush frames accumulés avant de démarrer la prochaine
				if not current_idat_parts.is_empty():
					frame_parts_list.append(current_idat_parts.duplicate())
					frame_delays.append(current_delay)
					current_idat_parts.clear()
				var delay_num = _read_uint16_be(chunk_data, 20)
				var delay_den = _read_uint16_be(chunk_data, 22)
				if delay_den == 0:
					delay_den = 100
				current_delay = DEFAULT_DELAY if delay_num == 0 else float(delay_num) / float(delay_den)
			"IDAT":
				current_idat_parts.append(full_chunk)  # Réutilise le chunk original (CRC valide)
			"fdAT":
				# Convertit fdAT (sequence_number + data) en chunk IDAT
				if chunk_data.size() > 4:
					current_idat_parts.append(_make_idat_chunk(chunk_data.slice(4)))
			"IEND":
				if not current_idat_parts.is_empty():
					frame_parts_list.append(current_idat_parts.duplicate())
					frame_delays.append(current_delay)
				break

	if not actl_found:
		# PNG standard (pas APNG) : charger comme frame unique
		var img = Image.new()
		if img.load_png_from_buffer(data) != OK:
			return {}
		var tex = ImageTexture.create_from_image(img)
		return { "frames": [tex], "delays": [DEFAULT_DELAY] }

	if frame_parts_list.is_empty():
		return {}

	var frames: Array[ImageTexture] = []
	var delays: Array[float] = []
	for i in range(frame_parts_list.size()):
		var tex = _reconstruct_frame(ihdr_chunk, frame_parts_list[i])
		if tex:
			frames.append(tex)
			delays.append(frame_delays[i])

	if frames.is_empty():
		return {}
	return { "frames": frames, "delays": delays }


static func _reconstruct_frame(ihdr: PackedByteArray, idat_parts: Array[PackedByteArray]) -> ImageTexture:
	var result := PackedByteArray()
	# Signature PNG
	result.append_array(PackedByteArray([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]))
	# IHDR original
	result.append_array(ihdr)
	# Chunks IDAT
	for part in idat_parts:
		result.append_array(part)
	# IEND fixe
	result.append_array(PackedByteArray([0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82]))
	var img = Image.new()
	if img.load_png_from_buffer(result) != OK:
		return null
	return ImageTexture.create_from_image(img)


static func _make_idat_chunk(payload: PackedByteArray) -> PackedByteArray:
	var chunk := PackedByteArray()
	var len = payload.size()
	chunk.append((len >> 24) & 0xFF)
	chunk.append((len >> 16) & 0xFF)
	chunk.append((len >> 8) & 0xFF)
	chunk.append(len & 0xFF)
	var type_bytes = PackedByteArray([0x49, 0x44, 0x41, 0x54])  # "IDAT"
	chunk.append_array(type_bytes)
	chunk.append_array(payload)
	var crc_input := PackedByteArray()
	crc_input.append_array(type_bytes)
	crc_input.append_array(payload)
	var crc = _crc32(crc_input)
	chunk.append((crc >> 24) & 0xFF)
	chunk.append((crc >> 16) & 0xFF)
	chunk.append((crc >> 8) & 0xFF)
	chunk.append(crc & 0xFF)
	return chunk


static func _crc32(data: PackedByteArray) -> int:
	var crc: int = 0xFFFFFFFF
	for b in data:
		crc ^= b
		for _i in range(8):
			if crc & 1:
				crc = (crc >> 1) ^ 0xEDB88320
			else:
				crc >>= 1
	return crc ^ 0xFFFFFFFF


static func _read_uint32_be(data: PackedByteArray, pos: int) -> int:
	return (data[pos] << 24) | (data[pos + 1] << 16) | (data[pos + 2] << 8) | data[pos + 3]


static func _read_uint16_be(data: PackedByteArray, pos: int) -> int:
	return (data[pos] << 8) | data[pos + 1]
```

- [ ] **Step 4 : Vérifier que les tests passent**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/ui/shared/test_apng_loader.gd 2>&1 | tail -20
```
Attendu : tous PASS.

- [ ] **Step 5 : Commit**

```bash
git add src/ui/shared/apng_loader.gd specs/ui/shared/test_apng_loader.gd
git commit -m "feat: ApngLoader — parser binaire APNG (frames + délais)"
```

---

## Task 3 : ForegroundAnimPlayer — lecteur de frames

**Files:**
- Create: `src/ui/visual/foreground_anim_player.gd`
- Create: `specs/ui/visual/test_foreground_anim_player.gd`

- [ ] **Step 1 : Écrire les tests**

Créer `specs/ui/visual/test_foreground_anim_player.gd` :

```gdscript
# SPDX-License-Identifier: AGPL-3.0-only
extends GutTest

const ForegroundAnimPlayer = preload("res://src/ui/visual/foreground_anim_player.gd")

func _make_player(frame_count: int, delay: float = 0.1) -> Node:
	var player = Node.new()
	player.set_script(ForegroundAnimPlayer)
	add_child_autofree(player)
	for _i in range(frame_count):
		var img = Image.create(1, 1, false, Image.FORMAT_RGB8)
		player._frames.append(ImageTexture.create_from_image(img))
		player._delays.append(delay)
	return player

func test_default_values():
	var player = Node.new()
	player.set_script(ForegroundAnimPlayer)
	add_child_autofree(player)
	assert_eq(player.anim_speed, 1.0)
	assert_eq(player.anim_loop, true)
	assert_eq(player.anim_reverse, false)
	assert_eq(player.anim_reverse_loop, false)
	assert_false(player.is_playing())

func test_play_starts_at_frame_zero():
	var player = _make_player(3)
	player.play()
	assert_eq(player._current_frame, 0)
	assert_true(player.is_playing())

func test_play_reverse_loop_starts_at_last_frame():
	var player = _make_player(3)
	player.anim_reverse_loop = true
	player.play()
	assert_eq(player._current_frame, 2)

func test_stop_halts_playback():
	var player = _make_player(3)
	player.play()
	player.stop()
	assert_false(player.is_playing())

func test_loop_mode_cycles_forward():
	var player = _make_player(3, 0.1)
	player.anim_loop = true
	player.play()
	assert_eq(player._current_frame, 0)
	simulate(player, 2, 0.11)  # 2 × 0.11s > 2 × 0.1s → avance de 2 frames
	assert_eq(player._current_frame, 2)

func test_loop_mode_wraps_around():
	var player = _make_player(3, 0.1)
	player.anim_loop = true
	player.play()
	simulate(player, 4, 0.11)  # 4 frames → dépasse la fin, boucle
	assert_eq(player._current_frame, 1)  # 4 % 3 = 1

func test_reverse_loop_cycles_backward():
	var player = _make_player(3, 0.1)
	player.anim_reverse_loop = true
	player.play()
	assert_eq(player._current_frame, 2)
	simulate(player, 1, 0.11)
	assert_eq(player._current_frame, 1)

func test_reverse_loop_wraps_around():
	var player = _make_player(3, 0.1)
	player.anim_reverse_loop = true
	player.play()
	simulate(player, 4, 0.11)  # recule de 4 → (2 - 4 + 6) % 3 = 1
	assert_eq(player._current_frame, 1)

func test_one_shot_forward_stops_at_last():
	var player = _make_player(3, 0.1)
	player.anim_loop = false
	player.anim_reverse = false
	player.play()
	simulate(player, 5, 0.11)
	assert_eq(player._current_frame, 2)
	assert_false(player.is_playing())

func test_one_shot_reverse_stops_at_zero():
	var player = _make_player(3, 0.1)
	player.anim_loop = false
	player.anim_reverse = true
	player.anim_reverse_loop = false
	player.play()
	# démarre à frame 0 en reverse → recule vers -1 → stop à 0
	simulate(player, 2, 0.11)
	assert_eq(player._current_frame, 0)
	assert_false(player.is_playing())

func test_speed_factor_slows_advance():
	var player = _make_player(3, 0.1)
	player.anim_speed = 0.5  # ×0.5 → délai effectif 0.2s
	player.anim_loop = true
	player.play()
	simulate(player, 1, 0.11)  # 0.11s < 0.2s → pas d'avancement
	assert_eq(player._current_frame, 0)
	simulate(player, 1, 0.12)  # 0.12s de plus → total 0.23s > 0.2s → avance
	assert_eq(player._current_frame, 1)

func test_get_first_frame_texture_returns_null_when_empty():
	var player = Node.new()
	player.set_script(ForegroundAnimPlayer)
	add_child_autofree(player)
	assert_null(player.get_first_frame_texture())

func test_get_first_frame_texture_returns_first():
	var player = _make_player(3)
	assert_not_null(player.get_first_frame_texture())
	assert_eq(player.get_first_frame_texture(), player._frames[0])
```

- [ ] **Step 2 : Vérifier que les tests échouent**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/ui/visual/test_foreground_anim_player.gd 2>&1 | tail -20
```
Attendu : erreur preload ou FAIL.

- [ ] **Step 3 : Créer `src/ui/visual/foreground_anim_player.gd`**

```gdscript
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends Control
class_name ForegroundAnimPlayer

## Lecteur de frames pour foregrounds APNG.
## Cycle les frames via _process(delta) selon les options de lecture.

const ApngLoaderScript = preload("res://src/ui/shared/apng_loader.gd")

var anim_speed: float = 1.0
var anim_reverse: bool = false
var anim_loop: bool = true
var anim_reverse_loop: bool = false

var flip_h: bool = false:
	set(v):
		flip_h = v
		if _tex_rect:
			_tex_rect.flip_h = v

var flip_v: bool = false:
	set(v):
		flip_v = v
		if _tex_rect:
			_tex_rect.flip_v = v

var _frames: Array = []  # Array[ImageTexture]
var _delays: Array = []  # Array[float]
var _current_frame: int = 0
var _elapsed: float = 0.0
var _playing: bool = false
var _tex_rect: TextureRect


func _ready() -> void:
	_tex_rect = TextureRect.new()
	_tex_rect.name = "Texture"
	_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_tex_rect)
	set_process(false)


func load_apng(path: String) -> bool:
	var result = ApngLoaderScript.load(path)
	if result.is_empty():
		return false
	_frames = result["frames"]
	_delays = result["delays"]
	_current_frame = 0
	_elapsed = 0.0
	if not _frames.is_empty() and _tex_rect:
		_tex_rect.texture = _frames[0]
	return true


func play() -> void:
	if _frames.is_empty():
		return
	_current_frame = _frames.size() - 1 if anim_reverse_loop else 0
	_elapsed = 0.0
	_playing = true
	set_process(true)


func stop() -> void:
	_playing = false
	set_process(false)


func is_playing() -> bool:
	return _playing


func get_first_frame_texture() -> Texture2D:
	if _frames.is_empty():
		return null
	return _frames[0]


func _process(delta: float) -> void:
	if not _playing or _frames.is_empty():
		return
	_elapsed += delta
	var frame_delay = _delays[_current_frame] / maxf(anim_speed, 0.01)
	if _elapsed < frame_delay:
		return
	_elapsed = 0.0

	if anim_reverse_loop:
		_current_frame -= 1
		if _current_frame < 0:
			_current_frame = _frames.size() - 1
	elif anim_loop:
		_current_frame += 1
		if _current_frame >= _frames.size():
			_current_frame = 0
	elif anim_reverse:
		_current_frame -= 1
		if _current_frame < 0:
			_current_frame = 0
			stop()
			return
	else:
		_current_frame += 1
		if _current_frame >= _frames.size():
			_current_frame = _frames.size() - 1
			stop()
			return

	if _tex_rect:
		_tex_rect.texture = _frames[_current_frame]
```

- [ ] **Step 4 : Vérifier que les tests passent**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/ui/visual/test_foreground_anim_player.gd 2>&1 | tail -20
```
Attendu : tous PASS.

- [ ] **Step 5 : Commit**

```bash
git add src/ui/visual/foreground_anim_player.gd specs/ui/visual/test_foreground_anim_player.gd
git commit -m "feat: ForegroundAnimPlayer — lecteur de frames APNG (loop/reverse/speed)"
```

---

## Task 4 : Galerie — support APNG + filtre Animations

**Files:**
- Modify: `src/ui/dialogs/gallery_dialog.gd`
- Modify: `src/services/gallery_cleaner_service.gd`
- Modify: `specs/ui/dialogs/test_gallery_dialog.gd`

- [ ] **Step 1 : Écrire les tests qui vont échouer**

Ajouter à la fin de `specs/ui/dialogs/test_gallery_dialog.gd` :

```gdscript
func _create_test_apng(path: String) -> void:
	# Crée un faux fichier .apng (contenu PNG valide, extension apng)
	var img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.GREEN)
	img.save_png(path)


func test_list_images_includes_apng():
	GalleryCacheService.clear_all()
	var apng_path = _test_dir + "/assets/foregrounds/anim.apng"
	_create_test_apng(apng_path)
	_dialog.setup(_build_story(), _test_dir)
	# Seul le fichier APNG existe physiquement dans le dossier
	var grid = _dialog._fg_grid
	assert_eq(grid.get_child_count(), 1, "La grille doit contenir le fichier APNG")


func test_anim_filter_shows_only_apng():
	GalleryCacheService.clear_all()
	_create_test_image(_test_dir + "/assets/foregrounds/hero.png")
	_create_test_apng(_test_dir + "/assets/foregrounds/walk.apng")
	_dialog.setup(_build_story(), _test_dir)
	_dialog._anim_filter_check.button_pressed = true
	_dialog._refresh()
	await get_tree().process_frame
	var grid = _dialog._fg_grid
	assert_eq(grid.get_child_count(), 1, "Filtre actif → seulement le .apng")


func test_anim_filter_off_shows_all():
	GalleryCacheService.clear_all()
	_create_test_image(_test_dir + "/assets/foregrounds/hero.png")
	_create_test_apng(_test_dir + "/assets/foregrounds/walk.apng")
	_dialog.setup(_build_story(), _test_dir)
	_dialog._anim_filter_check.button_pressed = false
	_dialog._refresh()
	await get_tree().process_frame
	var grid = _dialog._fg_grid
	assert_eq(grid.get_child_count(), 2, "Filtre inactif → PNG + APNG")
```

- [ ] **Step 2 : Vérifier que les tests échouent**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/ui/dialogs/test_gallery_dialog.gd 2>&1 | tail -20
```
Attendu : FAIL sur les nouvelles fonctions.

- [ ] **Step 3 : Modifier `src/services/gallery_cleaner_service.gd`**

À la ligne 66, remplacer :
```gdscript
if ext in ["png", "jpg", "jpeg", "webp"]:
```
par :
```gdscript
if ext in ["png", "jpg", "jpeg", "webp", "apng"]:
```

- [ ] **Step 4 : Modifier `src/ui/dialogs/gallery_dialog.gd` — extensions + filtre + badge**

**4a. Ajouter la variable membre** (après la ligne `var _search_edit: LineEdit`) :
```gdscript
var _anim_filter_check: CheckBox
```

**4b. Dans `_build_ui()`, remplacer la section "--- Section Foregrounds ---"** :

```gdscript
	# --- Section Foregrounds ---
	var fg_header_row = HBoxContainer.new()
	scroll_inner.add_child(fg_header_row)

	_fg_section_label = Label.new()
	_fg_section_label.text = tr("Foregrounds")
	_fg_section_label.add_theme_font_size_override("font_size", 18)
	_fg_section_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fg_header_row.add_child(_fg_section_label)

	_anim_filter_check = CheckBox.new()
	_anim_filter_check.text = tr("Animations")
	_anim_filter_check.toggled.connect(func(_v): _refresh())
	fg_header_row.add_child(_anim_filter_check)

	_fg_empty_label = Label.new()
	_fg_empty_label.text = tr("Aucun foreground disponible.")
	_fg_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fg_empty_label.visible = false
	scroll_inner.add_child(_fg_empty_label)

	_fg_grid = GridContainer.new()
	_fg_grid.columns = 4
	scroll_inner.add_child(_fg_grid)
```

**4c. Dans `_refresh()`, remplacer** :
```gdscript
func _refresh() -> void:
	_refresh_grid(_bg_grid, _bg_empty_label, _story_base_path + "/assets/backgrounds")
	_refresh_grid(_fg_grid, _fg_empty_label, _story_base_path + "/assets/foregrounds")
	_update_clean_button_state()
```
par :
```gdscript
func _refresh() -> void:
	_refresh_grid(_bg_grid, _bg_empty_label, _story_base_path + "/assets/backgrounds")
	var anim_only = _anim_filter_check != null and _anim_filter_check.button_pressed
	_refresh_grid(_fg_grid, _fg_empty_label, _story_base_path + "/assets/foregrounds", anim_only)
	_update_clean_button_state()
```

**4d. Dans `_refresh_grid()`, ajouter le paramètre `anim_only`** :
```gdscript
func _refresh_grid(grid: GridContainer, empty_label: Label, dir_path: String, anim_only: bool = false) -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()

	var images = _list_images(dir_path)
	if anim_only:
		images = images.filter(func(p): return p.get_extension().to_lower() == "apng")
	var selected_cats = _get_selected_categories()
	# ... reste du code existant inchangé
```

**4e. Dans `_list_images()`, ajouter "apng"** :
```gdscript
func _list_images(dir_path: String) -> Array:
	return GalleryCacheService.get_file_list(dir_path, ["png", "jpg", "jpeg", "webp", "apng"])
```

**4f. Dans `_add_gallery_item()`, ajouter le badge APNG** — juste avant `container.gui_input.connect(...)` :
```gdscript
	if path.get_extension().to_lower() == "apng":
		var badge = Label.new()
		badge.text = "▶"
		badge.add_theme_color_override("font_color", Color(0.3, 0.85, 0.3))
		badge.add_theme_font_size_override("font_size", 14)
		badge.position = Vector2(4, 4)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(badge)
```

- [ ] **Step 5 : Vérifier que les tests passent**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/ui/dialogs/test_gallery_dialog.gd 2>&1 | tail -20
```
Attendu : tous PASS (inclus les anciens tests).

- [ ] **Step 6 : Commit**

```bash
git add src/ui/dialogs/gallery_dialog.gd src/services/gallery_cleaner_service.gd specs/ui/dialogs/test_gallery_dialog.gd
git commit -m "feat: galerie — support APNG, filtre Animations, badge ▶"
```

---

## Task 5 : Sequence visual editor — rendu APNG

**Files:**
- Modify: `src/ui/sequence/sequence_visual_editor.gd`

Pas de nouveau fichier de test pour cette tâche — le rendu APNG est vérifié visuellement après implémentation (tests e2e si disponibles). Les tests unitaires des composants sous-jacents (`ApngLoader`, `ForegroundAnimPlayer`) couvrent la logique.

- [ ] **Step 1 : Ajouter le preload de `ForegroundAnimPlayer`** — après les preloads existants en tête du fichier (`ForegroundBlinkPlayerScript` est à la ligne 13) :

```gdscript
const ForegroundAnimPlayerScript = preload("res://src/ui/visual/foreground_anim_player.gd")
```

- [ ] **Step 2 : Modifier `_update_single_fg_visual()` pour détecter APNG**

Dans `_update_single_fg_visual(fg)`, juste avant le bloc `if _wrapper_matches_fg(wrapper, fg):`, ajouter :

```gdscript
	if fg.image.ends_with(".apng"):
		_update_apng_fg_visual(wrapper, fg)
		_update_fg_non_visual_props(wrapper, fg)
		return
```

- [ ] **Step 3 : Ajouter la fonction `_update_apng_fg_visual()`** — placer après `_update_single_fg_visual()` :

```gdscript
func _update_apng_fg_visual(wrapper: Control, fg) -> void:
	# Masquer le TextureRect statique
	var tex_rect: TextureRect = wrapper.get_node("Texture")
	tex_rect.visible = false
	tex_rect.texture = null

	# Supprimer le blink player s'il existe
	var blink_player = wrapper.get_node_or_null("BlinkPlayer")
	if blink_player:
		blink_player.queue_free()

	var anim_player = wrapper.get_node_or_null("AnimPlayer")
	var image_changed = wrapper.get_meta("fg_image", "") != fg.image

	if anim_player == null or image_changed:
		if anim_player:
			anim_player.queue_free()
			anim_player = null
		var new_player = ForegroundAnimPlayerScript.new()
		new_player.name = "AnimPlayer"
		wrapper.add_child(new_player)
		if not new_player.load_apng(fg.image):
			new_player.queue_free()
			return
		anim_player = new_player

	# Mettre à jour les options de lecture
	anim_player.anim_speed = fg.anim_speed
	anim_player.anim_reverse = fg.anim_reverse
	anim_player.anim_loop = fg.anim_loop
	anim_player.anim_reverse_loop = fg.anim_reverse_loop
	anim_player.flip_h = fg.flip_h
	anim_player.flip_v = fg.flip_v
	if not anim_player.is_playing():
		anim_player.play()

	# Taille depuis la première frame
	var first_tex = anim_player.get_first_frame_texture()
	if first_tex == null:
		return
	var quality_div: float = _get_image_quality_divisor()
	var fg_size = first_tex.get_size() * fg.scale * quality_div
	wrapper.size = fg_size
	anim_player.size = fg_size

	# Position via système d'ancrage
	var bg_size = Vector2(1920, 1080)
	if _bg_rect and _bg_rect.texture:
		bg_size = _bg_rect.texture.get_size() * quality_div
	wrapper.position = fg.anchor_bg * bg_size - fg.anchor_fg * fg_size
	wrapper.z_index = fg.z_order

	# Stocker les métadonnées pour détecter les changements d'image
	wrapper.set_meta("fg_image", fg.image)
	wrapper.set_meta("fg_anchor_bg", fg.anchor_bg)
	wrapper.set_meta("fg_anchor_fg", fg.anchor_fg)
	wrapper.set_meta("fg_scale", fg.scale)
	wrapper.set_meta("fg_flip_h", fg.flip_h)
	wrapper.set_meta("fg_flip_v", fg.flip_v)
```

- [ ] **Step 4 : Vérifier qu'aucun test existant n'est cassé**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 120 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://specs/ui/sequence/ 2>&1 | tail -30
```
Attendu : aucun test régressé.

- [ ] **Step 5 : Commit**

```bash
git add src/ui/sequence/sequence_visual_editor.gd
git commit -m "feat: sequence_visual_editor — rendu APNG via ForegroundAnimPlayer"
```

---

## Task 6 : Foreground properties panel — section Animation

**Files:**
- Modify: `src/ui/sequence/foreground_properties_panel.gd`

Pas de test unitaire pour ce panneau (logique purement UI/signal). La couverture est assurée par les tests des modèles et des players. Vérification visuelle requise après implémentation.

- [ ] **Step 1 : Ajouter les variables membres** — après `var _duration_spin: SpinBox` (ligne ~23) :

```gdscript
var _anim_section: VBoxContainer
var _anim_reverse_check: CheckButton
var _anim_speed_slider: HSlider
var _anim_speed_label: Label
var _anim_loop_check: CheckButton
var _anim_reverse_loop_check: CheckButton
```

- [ ] **Step 2 : Ajouter la section Animation dans `_ready()`** — après la construction de la section Transition (après la ligne `trans_row.add_child(_duration_spin)`) :

```gdscript
	# Animation (visible uniquement pour foregrounds APNG)
	add_child(HSeparator.new())

	_anim_section = VBoxContainer.new()
	_anim_section.add_theme_constant_override("separation", 4)
	_anim_section.visible = false
	add_child(_anim_section)

	var anim_title = Label.new()
	anim_title.text = tr("Animation")
	anim_title.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	anim_title.add_theme_font_size_override("font_size", 12)
	_anim_section.add_child(anim_title)

	# Reverse
	var reverse_row = HBoxContainer.new()
	_anim_section.add_child(reverse_row)
	var reverse_key = Label.new()
	reverse_key.text = "Reverse"
	reverse_key.custom_minimum_size = Vector2(70, 0)
	reverse_row.add_child(reverse_key)
	_anim_reverse_check = CheckButton.new()
	_anim_reverse_check.toggled.connect(_on_property_changed)
	reverse_row.add_child(_anim_reverse_check)

	# Vitesse
	var speed_row = HBoxContainer.new()
	_anim_section.add_child(speed_row)
	var speed_key = Label.new()
	speed_key.text = tr("Vitesse")
	speed_key.custom_minimum_size = Vector2(70, 0)
	speed_row.add_child(speed_key)
	_anim_speed_slider = HSlider.new()
	_anim_speed_slider.min_value = 0.1
	_anim_speed_slider.max_value = 4.0
	_anim_speed_slider.step = 0.05
	_anim_speed_slider.value = 1.0
	_anim_speed_slider.size_flags_horizontal = SIZE_EXPAND_FILL
	_anim_speed_slider.value_changed.connect(_on_property_changed)
	speed_row.add_child(_anim_speed_slider)
	_anim_speed_label = Label.new()
	_anim_speed_label.text = "1.00×"
	_anim_speed_label.custom_minimum_size = Vector2(40, 0)
	speed_row.add_child(_anim_speed_label)

	# Loop / Reverse Loop
	var loop_row = HBoxContainer.new()
	_anim_section.add_child(loop_row)
	_anim_loop_check = CheckButton.new()
	_anim_loop_check.text = "Loop"
	_anim_loop_check.size_flags_horizontal = SIZE_EXPAND_FILL
	_anim_loop_check.toggled.connect(_on_anim_loop_toggled)
	loop_row.add_child(_anim_loop_check)
	_anim_reverse_loop_check = CheckButton.new()
	_anim_reverse_loop_check.text = "Reverse Loop"
	_anim_reverse_loop_check.toggled.connect(_on_anim_reverse_loop_toggled)
	loop_row.add_child(_anim_reverse_loop_check)
```

- [ ] **Step 3 : Mettre à jour `show_for_foreground(fg)`** — dans le bloc `_updating = false` et avant `visible = true`, insérer :

```gdscript
	var is_apng = fg.image.ends_with(".apng")
	_anim_section.visible = is_apng
	if is_apng:
		_anim_reverse_check.button_pressed = fg.anim_reverse
		_anim_speed_slider.value = fg.anim_speed
		_anim_speed_label.text = "%.2f×" % fg.anim_speed
		_anim_loop_check.button_pressed = fg.anim_loop
		_anim_reverse_loop_check.button_pressed = fg.anim_reverse_loop
		_update_anim_reverse_enabled()
```

- [ ] **Step 4 : Mettre à jour `_on_property_changed()`** — à la fin de la fonction, après `properties_changed.emit()` (en fait avant), ajouter le bloc animation :

```gdscript
	if _foreground.image.ends_with(".apng"):
		_foreground.anim_reverse = _anim_reverse_check.button_pressed
		_foreground.anim_speed = _anim_speed_slider.value
		_anim_speed_label.text = "%.2f×" % _anim_speed_slider.value
		_foreground.anim_loop = _anim_loop_check.button_pressed
		_foreground.anim_reverse_loop = _anim_reverse_loop_check.button_pressed
	properties_changed.emit()
```

Retirer l'appel existant `properties_changed.emit()` qui était à la fin et le remplacer par ce bloc (qui l'inclut déjà).

- [ ] **Step 5 : Ajouter les fonctions de gestion exclusivité Loop/Reverse Loop** — après `_on_property_changed()` :

```gdscript
func _on_anim_loop_toggled(pressed: bool) -> void:
	if pressed and _anim_reverse_loop_check.button_pressed:
		_anim_reverse_loop_check.set_pressed_no_signal(false)
	_on_property_changed()
	_update_anim_reverse_enabled()


func _on_anim_reverse_loop_toggled(pressed: bool) -> void:
	if pressed and _anim_loop_check.button_pressed:
		_anim_loop_check.set_pressed_no_signal(false)
	_on_property_changed()
	_update_anim_reverse_enabled()


func _update_anim_reverse_enabled() -> void:
	if _anim_reverse_check == null:
		return
	_anim_reverse_check.disabled = _anim_loop_check.button_pressed or _anim_reverse_loop_check.button_pressed
```

- [ ] **Step 6 : Vérifier les tests existants du panneau et la suite complète**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 120 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://specs/ui/sequence/ 2>&1 | tail -30
```
Attendu : aucune régression.

- [ ] **Step 7 : Commit**

```bash
git add src/ui/sequence/foreground_properties_panel.gd
git commit -m "feat: foreground properties panel — section Animation APNG (reverse/speed/loop)"
```

---

## Vérification finale

- [ ] **Lancer `/check-global-acceptance`** pour valider l'ensemble.

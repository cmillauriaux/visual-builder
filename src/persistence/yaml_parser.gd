extends RefCounted

## Parser YAML simplifié pour le format du Visual Novel Editor.
## Supporte : strings, ints, floats, bools, dicts inline, arrays de dicts, arrays/dicts vides.

# --- Écriture (dict → YAML) ---

static func dict_to_yaml(d: Dictionary, indent: int = 0) -> String:
	var lines := PackedStringArray()
	var prefix = "  ".repeat(indent)
	for key in d:
		var value = d[key]
		lines.append(prefix + _serialize_key_value(key, value, indent))
	return "\n".join(lines)

static func _serialize_key_value(key: String, value, indent: int) -> String:
	if value == null:
		return "%s: null" % key
	elif value is String:
		return '%s: "%s"' % [key, value.replace('"', '\\"')]
	elif value is bool:
		return "%s: %s" % [key, "true" if value else "false"]
	elif value is int:
		return "%s: %s" % [key, str(value)]
	elif value is float:
		return "%s: %s" % [key, str(value)]
	elif value is Dictionary:
		if value.is_empty():
			return "%s: {}" % key
		# Petit dict (position-like) → inline
		if _is_small_dict(value):
			return "%s: { %s }" % [key, _inline_dict(value)]
		# Grand dict → nested
		var nested = dict_to_yaml(value, indent + 1)
		return "%s:\n%s" % [key, nested]
	elif value is Array:
		if value.is_empty():
			return "%s: []" % key
		var arr_lines := PackedStringArray()
		arr_lines.append("%s:" % key)
		var child_prefix = "  ".repeat(indent + 1)
		for item in value:
			if item is Dictionary:
				var first = true
				for k in item:
					var serialized = _serialize_key_value(k, item[k], indent + 2)
					if first:
						arr_lines.append(child_prefix + "- " + serialized)
						first = false
					else:
						arr_lines.append(child_prefix + "  " + serialized)
			else:
				arr_lines.append(child_prefix + "- " + _serialize_value(item))
		return "\n".join(arr_lines)
	return "%s: %s" % [key, str(value)]

static func _is_small_dict(d: Dictionary) -> bool:
	if d.size() > 3:
		return false
	for v in d.values():
		if v is Dictionary or v is Array:
			return false
	return true

static func _inline_dict(d: Dictionary) -> String:
	var parts := PackedStringArray()
	for key in d:
		parts.append("%s: %s" % [key, _serialize_value(d[key])])
	return ", ".join(parts)

static func _serialize_value(value) -> String:
	if value is String:
		return '"%s"' % value.replace('"', '\\"')
	elif value is bool:
		return "true" if value else "false"
	return str(value)

# --- Lecture (YAML → dict) ---

static func yaml_to_dict(yaml: String) -> Dictionary:
	var lines = yaml.split("\n")
	var result = {}
	_parse_block(lines, 0, 0, result)
	return result

static func _get_indent(line: String) -> int:
	var count = 0
	for c in line:
		if c == " ":
			count += 1
		elif c == "\t":
			count += 2
		else:
			break
	return count

static func _parse_block(lines: Array, start: int, base_indent: int, target: Dictionary) -> int:
	var i = start
	while i < lines.size():
		var line = lines[i]
		var stripped = line.strip_edges()

		# Lignes vides ou commentaires
		if stripped == "" or stripped.begins_with("#"):
			i += 1
			continue

		var indent = _get_indent(line)
		if indent < base_indent:
			return i

		# Traitement d'un élément de tableau au niveau courant (ne devrait pas arriver ici)
		if stripped.begins_with("- "):
			return i

		var colon_pos = stripped.find(":")
		if colon_pos < 0:
			i += 1
			continue

		var key = stripped.substr(0, colon_pos).strip_edges()
		var rest = stripped.substr(colon_pos + 1).strip_edges()

		if rest == "":
			# Bloc enfant — déterminer si c'est un array ou un dict
			if i + 1 < lines.size():
				var next_stripped = lines[i + 1].strip_edges()
				if next_stripped.begins_with("- "):
					# C'est un array
					var arr = []
					i = _parse_array(lines, i + 1, indent + 2, arr)
					target[key] = arr
				else:
					# C'est un dict imbriqué
					var nested = {}
					i = _parse_block(lines, i + 1, indent + 2, nested)
					target[key] = nested
			else:
				target[key] = {}
				i += 1
		else:
			target[key] = _parse_value(rest)
			i += 1

	return i

static func _parse_array(lines: Array, start: int, base_indent: int, target: Array) -> int:
	var i = start
	while i < lines.size():
		var line = lines[i]
		var stripped = line.strip_edges()

		if stripped == "" or stripped.begins_with("#"):
			i += 1
			continue

		var indent = _get_indent(line)
		if indent < base_indent - 2:
			return i

		if not stripped.begins_with("- "):
			return i

		# Enlever le "- " du début
		var item_content = stripped.substr(2).strip_edges()

		# Déterminer si c'est un dict item ou un scalar
		var colon_pos = item_content.find(":")
		if colon_pos > 0:
			# C'est un dict item
			var item_dict = {}
			var item_key = item_content.substr(0, colon_pos).strip_edges()
			var item_rest = item_content.substr(colon_pos + 1).strip_edges()
			item_dict[item_key] = _parse_value(item_rest)

			# Lire les lignes suivantes du même item
			i += 1
			while i < lines.size():
				var next_line = lines[i]
				var next_stripped = next_line.strip_edges()
				if next_stripped == "":
					i += 1
					continue
				var next_indent = _get_indent(next_line)
				# Les propriétés de l'item sont indentées de 2 de plus que le "-"
				if next_indent < base_indent or next_stripped.begins_with("- "):
					break
				var nc = next_stripped.find(":")
				if nc > 0:
					var nk = next_stripped.substr(0, nc).strip_edges()
					var nv = next_stripped.substr(nc + 1).strip_edges()
					if nv == "":
						# Sous-bloc dans l'array item
						if i + 1 < lines.size() and lines[i + 1].strip_edges().begins_with("- "):
							var sub_arr = []
							i = _parse_array(lines, i + 1, next_indent + 2, sub_arr)
							item_dict[nk] = sub_arr
						else:
							var sub_dict = {}
							i = _parse_block(lines, i + 1, next_indent + 2, sub_dict)
							item_dict[nk] = sub_dict
					else:
						item_dict[nk] = _parse_value(nv)
						i += 1
				else:
					i += 1
			target.append(item_dict)
		else:
			target.append(_parse_value(item_content))
			i += 1

	return i

static func _parse_value(s: String):
	if s == "":
		return ""

	# Dict vide
	if s == "{}":
		return {}

	# Array vide
	if s == "[]":
		return []

	# Dict inline { key: val, ... }
	if s.begins_with("{") and s.ends_with("}"):
		return _parse_inline_dict(s)

	# String entre guillemets
	if s.begins_with('"') and s.ends_with('"'):
		return s.substr(1, s.length() - 2).replace('\\"', '"')

	# String entre guillemets simples
	if s.begins_with("'") and s.ends_with("'"):
		return s.substr(1, s.length() - 2)

	# Boolean
	if s == "true":
		return true
	if s == "false":
		return false

	# Null
	if s == "null":
		return null

	# Nombre — int ou float
	if s.is_valid_int():
		return s.to_int()
	if s.is_valid_float():
		return s.to_float()

	# String non-quotée
	return s

static func _parse_inline_dict(s: String) -> Dictionary:
	var content = s.substr(1, s.length() - 2).strip_edges()
	if content == "":
		return {}
	var d = {}
	var parts = content.split(",")
	for part in parts:
		var kv = part.strip_edges()
		var colon = kv.find(":")
		if colon > 0:
			var k = kv.substr(0, colon).strip_edges()
			var v = kv.substr(colon + 1).strip_edges()
			d[k] = _parse_value(v)
	return d

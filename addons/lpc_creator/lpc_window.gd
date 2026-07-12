@tool
extends Window

# ── Constants ─────────────────────────────────────────────────────────────────
const FRAME_W := 64
const FRAME_H := 64

const SLOT_ORDER := ["body","head","expression","hair","beard","hat","armour",
		"shoulders","arms","wrists","belt","legs","shoes","weapon","back","accessory"]

const ANIMS    := ["idle","walk","run","hurt","slash","spellcast","thrust","shoot"]
const ANIM_FPS := {"idle":2,"walk":8,"run":8,"hurt":6,"slash":8,"spellcast":7,"thrust":8,"shoot":13}

const TYPE_ANIMS := {
	"guerrier": {"standard":["idle","run","hurt","slash","walk","spellcast"],"slash_128":true},
	"elf":      {"standard":["walk","shoot","hurt","idle"],"slash_128":false},
	"mage":     {"standard":["idle","run","spellcast","hurt","walk"],"slash_128":false},
	"paladin":  {"standard":["walk","thrust","hurt","idle","slash"],"slash_128":false},
	"gobelin":  {"standard":["walk","hurt","idle","slash"],"slash_128":false},
	"generic":  {"standard":["idle","walk","run","hurt","slash","spellcast","thrust","shoot"],"slash_128":false},
}

const ANIM_FALLBACKS := {
	"idle":["walk"],"walk":["idle"],"run":["walk","idle"],
	"spellcast":["thrust","walk","idle"],"thrust":["walk","idle"],
	"slash":["walk","idle"],"shoot":["walk","idle"],"hurt":["walk","idle"],
	"backslash":["slash","walk","idle"],"halfslash":["slash","walk","idle"],
}

const TYPE_NAMES  := ["guerrier","elf","mage","paladin","gobelin","generic"]
const TYPE_LABELS := ["Guerrier","Elf","Mage","Paladin","Gobelin","Generique"]
const SEX_PREFS   := ["male","muscular","female","teen","child"]

# ── State ─────────────────────────────────────────────────────────────────────
var catalog    : Dictionary = {}
var slots      : Dictionary = {}
var cur_anim   := "idle"
var cur_dir    := 2
var cur_frame  := 0
var frame_time := 0.0
var tex_cache  : Dictionary = {}

var ulpc_sprites : String
var assets_abs   : String

# ── UI refs ───────────────────────────────────────────────────────────────────
var viewport      : SubViewport
var layer_root    : Node2D
var slot_vbox     : VBoxContainer
var status_lbl    : Label
var prefix_input  : LineEdit
var type_opt      : OptionButton
var import_opt    : OptionButton
var dest_lbl      : Label
var dir_group     : ButtonGroup
var anim_group    : ButtonGroup

var layer_sprites   : Dictionary = {}
var _import_folders : Array = []
var slot_item_lbl : Dictionary = {}
var slot_var_row  : Dictionary = {}
var slot_var_hbx  : Dictionary = {}

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	title = "LPC Character Creator"
	min_size = Vector2i(700, 500)
	close_requested.connect(hide)

	var root     = ProjectSettings.globalize_path("res://")
	ulpc_sprites = root + "tools/lpc_creator/ulpc/spritesheets/"
	assets_abs   = root + "assets/"

	_build_ui()
	call_deferred("_on_win_resized")
	_load_catalog()
	set_process(true)

func _process(delta: float) -> void:
	if not visible or slots.is_empty(): return
	frame_time += delta
	var fps := float(ANIM_FPS.get(cur_anim, 6))
	if frame_time >= 1.0 / fps:
		frame_time -= 1.0 / fps
		cur_frame += 1
		_redraw_frames()

# ── Catalog ───────────────────────────────────────────────────────────────────
func _load_catalog() -> void:
	status_lbl.text = "Chargement..."
	var path = ProjectSettings.globalize_path("res://") + "tools/lpc_creator/catalog.json"
	var f = FileAccess.open(path, FileAccess.READ)
	if not f:
		status_lbl.text = "catalog.json introuvable — lancez tools/lpc_creator/start.bat"
		return
	var data = JSON.parse_string(f.get_as_text())
	if not data is Dictionary:
		status_lbl.text = "Erreur lecture catalog.json"
		return
	catalog = data
	_populate_slots()
	_suggest_dest()
	_refresh_import_opt()
	var has_local = FileAccess.file_exists(ulpc_sprites + "body/bodies/male/idle.png")
	status_lbl.text = "%d items | sprites %s" % [
		catalog.get("total", 0),
		"locaux OK" if has_local else "! ulpc/ absent — download_ulpc.bat"
	]

# ── Slots ─────────────────────────────────────────────────────────────────────
func _populate_slots() -> void:
	for c in slot_vbox.get_children(): c.queue_free()
	for c in layer_root.get_children(): c.queue_free()
	slots.clear(); layer_sprites.clear()
	slot_item_lbl.clear(); slot_var_row.clear(); slot_var_hbx.clear()
	tex_cache.clear()

	var bg = ColorRect.new()
	bg.color = Color(0.12, 0.12, 0.15)
	bg.size  = Vector2(FRAME_W, FRAME_H)
	layer_root.add_child(bg)

	var cat_slots: Dictionary = catalog.get("slots", {})
	for slot_name in SLOT_ORDER:
		if not cat_slots.has(slot_name): continue
		var items: Array = [null] + cat_slots[slot_name]
		slots[slot_name] = {"items": items, "idx": 0, "variant_idx": 0}

		var spr = Sprite2D.new()
		spr.centered       = false
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		layer_root.add_child(spr)
		layer_sprites[slot_name] = spr

		_make_slot_row(slot_name)

func _make_slot_row(slot_name: String) -> void:
	var row = HBoxContainer.new()

	var lbl = Label.new()
	lbl.text = slot_name
	lbl.custom_minimum_size.x = 80
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.clip_text = true
	row.add_child(lbl)

	var btn_l = Button.new()
	btn_l.text = "<"
	btn_l.flat = true
	btn_l.custom_minimum_size = Vector2(24, 0)
	btn_l.pressed.connect(_prev_item.bind(slot_name))
	row.add_child(btn_l)

	var item_lbl = Label.new()
	item_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_lbl.add_theme_font_size_override("font_size", 11)
	item_lbl.clip_text = true
	item_lbl.text = "(aucun)"
	row.add_child(item_lbl)
	slot_item_lbl[slot_name] = item_lbl

	var btn_r = Button.new()
	btn_r.text = ">"
	btn_r.flat = true
	btn_r.custom_minimum_size = Vector2(24, 0)
	btn_r.pressed.connect(_next_item.bind(slot_name))
	row.add_child(btn_r)

	slot_vbox.add_child(row)

	# Variant row
	var var_cont = HBoxContainer.new()
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y  = 28
	scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_DISABLED
	var var_hbx = HBoxContainer.new()
	var_hbx.add_theme_constant_override("separation", 4)
	scroll.add_child(var_hbx)
	var_cont.add_child(scroll)
	var_cont.visible = false
	slot_vbox.add_child(var_cont)
	slot_var_row[slot_name] = var_cont
	slot_var_hbx[slot_name] = var_hbx

	slot_vbox.add_child(HSeparator.new())

# ── Navigation ────────────────────────────────────────────────────────────────
func _prev_item(slot_name: String) -> void:
	var s = slots[slot_name]
	s.idx = (s.idx - 1 + s.items.size()) % s.items.size()
	s.variant_idx = 0
	_refresh_row(slot_name); _update_sprite(slot_name)

func _next_item(slot_name: String) -> void:
	var s = slots[slot_name]
	s.idx = (s.idx + 1) % s.items.size()
	s.variant_idx = 0
	_refresh_row(slot_name); _update_sprite(slot_name)

func _on_variant_toggled(pressed: bool, slot_name: String, vi: int) -> void:
	if not pressed: return
	slots[slot_name].variant_idx = vi
	_update_sprite(slot_name)

func _refresh_row(slot_name: String) -> void:
	var s    = slots[slot_name]
	var item = s.items[s.idx]
	slot_item_lbl[slot_name].text = item.get("name", "?") if item else "(aucun)"

	var hbx: HBoxContainer = slot_var_hbx[slot_name]
	for c in hbx.get_children(): c.queue_free()

	var variants: Array = item.get("variants", []) if item else []
	if item and not variants.is_empty():
		slot_var_row[slot_name].visible = true
		var vg = ButtonGroup.new()
		for i in variants.size():
			var btn = Button.new()
			btn.text          = str(variants[i])
			btn.toggle_mode   = true
			btn.button_group  = vg
			btn.button_pressed = (i == s.variant_idx)
			btn.add_theme_font_size_override("font_size", 10)
			btn.toggled.connect(_on_variant_toggled.bind(slot_name, i))
			hbx.add_child(btn)
	else:
		slot_var_row[slot_name].visible = false

# ── Sprite rendering ──────────────────────────────────────────────────────────
func _get_sprite_path(item: Dictionary, anim: String, variant) -> String:
	var paths: Dictionary = item.get("paths", {})
	var base := ""
	for pref in SEX_PREFS:
		if paths.has(pref): base = paths[pref]; break
	if base.is_empty() and not paths.is_empty():
		base = paths.values()[0]
	if base.is_empty(): return ""
	if not base.ends_with("/"): base += "/"
	if variant:
		return ulpc_sprites + base + anim + "/" + str(variant) + ".png"
	return ulpc_sprites + base + anim + ".png"

func _anim_chain(anim: String) -> Array:
	var seen  := {anim: true}
	var chain := [anim]
	for fb in ANIM_FALLBACKS.get(anim, []):
		if not seen.has(fb): seen[fb] = true; chain.append(fb)
	for last in ["idle", "walk"]:
		if not seen.has(last): seen[last] = true; chain.append(last)
	return chain

func _load_tex(path: String) -> ImageTexture:
	if tex_cache.has(path): return tex_cache[path]
	if not FileAccess.file_exists(path):
		tex_cache[path] = null; return null
	var img = Image.load_from_file(path)
	if not img: tex_cache[path] = null; return null
	var tex = ImageTexture.create_from_image(img)
	tex_cache[path] = tex
	return tex

func _find_tex(item: Dictionary, anim: String, variant) -> ImageTexture:
	for a in _anim_chain(anim):
		var p = _get_sprite_path(item, a, variant)
		if not p.is_empty():
			var t = _load_tex(p)
			if t: return t
	return null

func _update_sprite(slot_name: String) -> void:
	var spr: Sprite2D = layer_sprites.get(slot_name)
	if not spr: return
	var s    = slots[slot_name]
	var item = s.items[s.idx]
	if not item: spr.texture = null; return
	var variants: Array = item.get("variants", [])
	var variant          = variants[s.variant_idx] if not variants.is_empty() else null
	spr.texture = _find_tex(item, cur_anim, variant)
	spr.z_index = item.get("zPos", 50)
	_set_frame_on(spr)

func _update_all_sprites() -> void:
	for slot_name in slots: _update_sprite(slot_name)

func _set_frame_on(spr: Sprite2D) -> void:
	if not spr.texture: return
	spr.region_enabled = true
	var cols: int = max(1, spr.texture.get_width() / FRAME_W)
	var f: int    = cur_frame % cols
	spr.region_rect = Rect2(f * FRAME_W, cur_dir * FRAME_H, FRAME_W, FRAME_H)

func _redraw_frames() -> void:
	for spr in layer_sprites.values(): _set_frame_on(spr)

# ── Direction / Animation ─────────────────────────────────────────────────────
func _on_dir_toggled(pressed: bool, d: int) -> void:
	if not pressed: return
	cur_dir = d; cur_frame = 0; _redraw_frames()

func _on_anim_toggled(pressed: bool, anim: String) -> void:
	if not pressed: return
	cur_anim = anim; cur_frame = 0; frame_time = 0.0
	_update_all_sprites()

# ── Export ────────────────────────────────────────────────────────────────────
func _get_next_char_name() -> String:
	var prefix = prefix_input.text.strip_edges()
	if prefix.is_empty(): return ""
	var max_lvl := 0
	var d = DirAccess.open("res://assets/")
	if d:
		for folder in d.get_directories():
			var norm = folder.replace("-", "_")
			if norm.begins_with(prefix + "_lvl_"):
				var n = norm.split("_lvl_")[1].to_int()
				if n > max_lvl: max_lvl = n
	return "%s_lvl_%d" % [prefix, max_lvl + 1]

func _suggest_dest() -> void:
	if not prefix_input or not dest_lbl: return
	var prefix = prefix_input.text.strip_edges()
	if prefix.is_empty() and type_opt:
		prefix = TYPE_NAMES[type_opt.selected]
		prefix_input.text = prefix
	var char_name = _get_next_char_name()
	dest_lbl.text = ("res://assets/%s/" % char_name) if char_name else ""

func _on_type_selected(_i: int) -> void:
	if prefix_input.text.strip_edges() in TYPE_NAMES or prefix_input.text.is_empty():
		prefix_input.text = TYPE_NAMES[type_opt.selected]
	_suggest_dest()

func _on_prefix_changed(_txt: String) -> void:
	_suggest_dest()

func _on_export() -> void:
	var char_name = _get_next_char_name()
	if char_name.is_empty(): status_lbl.text = "Archétype vide"; return

	var type_name = TYPE_NAMES[type_opt.selected]
	var type_cfg  = TYPE_ANIMS[type_name]

	var active: Array = []
	for slot_name in SLOT_ORDER:
		if not slots.has(slot_name): continue
		var s    = slots[slot_name]
		var item = s.items[s.idx]
		if not item: continue
		var variants: Array = item.get("variants", [])
		var variant          = variants[s.variant_idx] if not variants.is_empty() else null
		active.append({"item": item, "variant": variant, "zPos": item.get("zPos", 50)})

	if active.is_empty(): status_lbl.text = "Aucun element selectionne"; return
	active.sort_custom(func(a, b): return a.zPos < b.zPos)

	var dest = assets_abs + char_name + "/"
	DirAccess.make_dir_recursive_absolute(dest + "standard/")
	status_lbl.text = "Export en cours..."

	var exported := 0
	for anim in type_cfg.standard:
		var img = _composite(active, anim)
		if img:
			img.save_png(dest + "standard/" + anim + ".png")
			exported += 1

	if type_cfg.get("slash_128", false):
		DirAccess.make_dir_recursive_absolute(dest + "custom/")
		var slash_src = dest + "standard/slash.png"
		if FileAccess.file_exists(slash_src):
			var si = Image.load_from_file(slash_src)
			si.resize(si.get_width() * 2, si.get_height() * 2, Image.INTERPOLATE_NEAREST)
			si.save_png(dest + "custom/slash_128.png")
			exported += 1

	_save_config(dest, type_name)
	_suggest_dest()
	_refresh_import_opt()
	EditorInterface.get_resource_filesystem().scan()
	status_lbl.text = "%d PNGs -> assets/%s/\nLancez generate_all_frames.gd pour les .tres" % [
		exported, char_name
	]

func _composite(layers: Array, anim: String) -> Image:
	var result: Image = null
	for layer in layers:
		var path := ""
		for a in _anim_chain(anim):
			var p = _get_sprite_path(layer.item, a, layer.variant)
			if not p.is_empty() and FileAccess.file_exists(p):
				path = p; break
		if path.is_empty(): continue
		var img = Image.load_from_file(path)
		if not img: continue
		if result == null:
			result = Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
		result.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
	return result

# ── Reset / Import / Config ───────────────────────────────────────────────────
func _on_reset() -> void:
	for slot_name in SLOT_ORDER:
		if not slots.has(slot_name): continue
		slots[slot_name]["idx"] = 0
		slots[slot_name]["variant_idx"] = 0
		_refresh_row(slot_name)
		_update_sprite(slot_name)
	status_lbl.text = "Slots réinitialisés (%d)" % slots.size()

func _save_config(dest: String, type_name: String) -> void:
	var slot_data := {}
	for slot_name in SLOT_ORDER:
		if not slots.has(slot_name): continue
		var s    = slots[slot_name]
		var item = s.items[s.idx]
		if not item: continue
		slot_data[slot_name] = {"item_id": item.get("id",""), "variant_idx": s.variant_idx}
	var config = {
		"type":   type_name,
		"prefix": prefix_input.text.strip_edges(),
		"slots":  slot_data
	}
	var f = FileAccess.open(dest + "standard/_lpc_config.json", FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(config, "\t"))

func _refresh_import_opt() -> void:
	if not import_opt: return
	import_opt.clear()
	import_opt.add_item("↓ Importer un perso…")
	var d = DirAccess.open(assets_abs)
	if not d: return
	for folder in d.get_directories():
		if DirAccess.dir_exists_absolute(assets_abs + folder + "/standard/"):
			import_opt.add_item(folder)

func _on_import_opt(idx: int) -> void:
	if idx == 0: return
	var folder = import_opt.get_item_text(idx)
	_on_import(folder)
	import_opt.select(0)

func _on_import(folder_name: String) -> void:
	var config_abs = assets_abs + folder_name + "/standard/_lpc_config.json"
	var data: Dictionary = {}
	if FileAccess.file_exists(config_abs):
		var f = FileAccess.open(config_abs, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary: data = parsed

	# Déduire le préfixe depuis le nom du dossier si pas de config
	var prefix = data.get("prefix", folder_name.split("_lvl_")[0].replace("-","_"))
	prefix_input.text = prefix

	# Type
	var type_name = data.get("type", "")
	var ti = TYPE_NAMES.find(type_name)
	if ti < 0:
		# Essayer depuis le nom du dossier
		for i in TYPE_NAMES.size():
			if folder_name.begins_with(TYPE_NAMES[i]): ti = i; break
	if ti >= 0: type_opt.select(ti)

	_suggest_dest()

	# Restaurer les slots si config présente
	var slot_data: Dictionary = data.get("slots", {})
	if slot_data.is_empty():
		status_lbl.text = "Importé (sans config layers) : " + folder_name; return
	var cat_slots: Dictionary = catalog.get("slots", {})
	for slot_name in slot_data:
		if not slots.has(slot_name) or not cat_slots.has(slot_name): continue
		var item_id    = slot_data[slot_name].get("item_id", "")
		var variant_idx: int = slot_data[slot_name].get("variant_idx", 0)
		var items: Array = [null] + cat_slots[slot_name]
		for i in items.size():
			if items[i] and items[i].get("id","") == item_id:
				slots[slot_name].idx         = i
				slots[slot_name].variant_idx = variant_idx
				_refresh_row(slot_name)
				_update_sprite(slot_name)
				break
	status_lbl.text = "Importé : " + folder_name

# ── UI ────────────────────────────────────────────────────────────────────────
var _root_panel : HBoxContainer

func _on_win_resized() -> void:
	if _root_panel:
		_root_panel.position = Vector2.ZERO
		_root_panel.size = Vector2(size)

func _build_ui() -> void:
	_root_panel = HBoxContainer.new()
	_root_panel.add_theme_constant_override("separation", 0)
	add_child(_root_panel)
	size_changed.connect(_on_win_resized)

	# ── Colonne gauche : Slots ────────────────────────────────────────────────
	var left = VBoxContainer.new()
	left.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	left.custom_minimum_size.x = 260
	left.add_theme_constant_override("separation", 4)
	_root_panel.add_child(left)

	var m_left = MarginContainer.new()
	for s in ["margin_left","margin_right","margin_top","margin_bottom"]:
		m_left.add_theme_constant_override(s, 6)
	m_left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(m_left)

	var left_vbox = VBoxContainer.new()
	left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m_left.add_child(left_vbox)

	var slots_lbl = Label.new()
	slots_lbl.text = "Couches"
	slots_lbl.add_theme_font_size_override("font_size", 13)
	left_vbox.add_child(slots_lbl)
	left_vbox.add_child(HSeparator.new())

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical    = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_vbox.add_child(scroll)

	slot_vbox = VBoxContainer.new()
	slot_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_vbox.add_theme_constant_override("separation", 1)
	scroll.add_child(slot_vbox)

	_root_panel.add_child(VSeparator.new())

	# ── Colonne centrale : Preview ────────────────────────────────────────────
	var center = VBoxContainer.new()
	center.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 6)
	_root_panel.add_child(center)

	var m_center = MarginContainer.new()
	for s in ["margin_left","margin_right","margin_top","margin_bottom"]:
		m_center.add_theme_constant_override(s, 8)
	m_center.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	m_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(m_center)

	var center_vbox = VBoxContainer.new()
	center_vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	center_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_center.add_child(center_vbox)

	# SubViewport 256×256 (sprites scalés 4× dedans → rendu net, puis affiché lissé)
	viewport = SubViewport.new()
	viewport.size                       = Vector2i(FRAME_W * 8, FRAME_H * 8)
	viewport.transparent_bg             = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)

	layer_root = Node2D.new()
	layer_root.scale = Vector2(8.0, 8.0)
	viewport.add_child(layer_root)
	var bg = ColorRect.new()
	bg.color = Color(0.12, 0.12, 0.15)
	bg.size  = Vector2(FRAME_W, FRAME_H)
	layer_root.add_child(bg)

	# TextureRect avec filtre linéaire : lisse le 256×256 sans gros pixels
	var preview_rect = TextureRect.new()
	preview_rect.texture                = viewport.get_texture()
	preview_rect.expand_mode            = TextureRect.EXPAND_IGNORE_SIZE
	preview_rect.stretch_mode           = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_rect.texture_filter         = CanvasItem.TEXTURE_FILTER_LINEAR
	preview_rect.custom_minimum_size    = Vector2(320, 320)
	preview_rect.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
	preview_rect.size_flags_vertical    = Control.SIZE_EXPAND_FILL
	center_vbox.add_child(preview_rect)

	# Direction (sous le preview)
	dir_group = ButtonGroup.new()
	var dir_row = HBoxContainer.new()
	dir_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center_vbox.add_child(dir_row)
	for pair in [["Haut",0],["Gauche",1],["Bas",2],["Droite",3]]:
		var btn = Button.new()
		btn.text           = pair[0]
		btn.toggle_mode    = true
		btn.button_group   = dir_group
		btn.button_pressed = (pair[1] == 2)
		btn.custom_minimum_size = Vector2(60, 0)
		btn.toggled.connect(_on_dir_toggled.bind(pair[1]))
		dir_row.add_child(btn)

	# Animations (grille 4×2 sous direction)
	anim_group = ButtonGroup.new()
	var anim_grid = GridContainer.new()
	anim_grid.columns = 4
	anim_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center_vbox.add_child(anim_grid)
	for a in ANIMS:
		var btn = Button.new()
		btn.text           = a
		btn.toggle_mode    = true
		btn.button_group   = anim_group
		btn.button_pressed = (a == "idle")
		btn.custom_minimum_size = Vector2(60, 0)
		btn.toggled.connect(_on_anim_toggled.bind(a))
		anim_grid.add_child(btn)

	_root_panel.add_child(VSeparator.new())

	# ── Colonne droite : Export ───────────────────────────────────────────────
	var right = VBoxContainer.new()
	right.custom_minimum_size.x = 240
	right.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_root_panel.add_child(right)

	var m_right = MarginContainer.new()
	for s in ["margin_left","margin_right","margin_top","margin_bottom"]:
		m_right.add_theme_constant_override(s, 8)
	m_right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(m_right)

	var right_vbox = VBoxContainer.new()
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 6)
	m_right.add_child(right_vbox)

	var exp_lbl = Label.new()
	exp_lbl.text = "Export"
	exp_lbl.add_theme_font_size_override("font_size", 13)
	right_vbox.add_child(exp_lbl)
	right_vbox.add_child(HSeparator.new())

	# Bouton Annuler
	var reset_btn = Button.new()
	reset_btn.text = "Annuler (reset)"
	reset_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_btn.pressed.connect(_on_reset)
	right_vbox.add_child(reset_btn)

	# OptionButton Importer
	import_opt = OptionButton.new()
	import_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	import_opt.item_selected.connect(_on_import_opt)
	right_vbox.add_child(import_opt)
	right_vbox.add_child(HSeparator.new())

	# Type (détermine le set d'animations exportées)
	var row2 = HBoxContainer.new()
	var l2 = Label.new(); l2.text = "Type:"; l2.custom_minimum_size.x = 60
	row2.add_child(l2)
	type_opt = OptionButton.new()
	type_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for lbl in TYPE_LABELS: type_opt.add_item(lbl)
	type_opt.item_selected.connect(_on_type_selected)
	row2.add_child(type_opt)
	right_vbox.add_child(row2)

	# Archétype (préfixe libre du dossier cible)
	var row1 = HBoxContainer.new()
	var l1 = Label.new(); l1.text = "Archétype:"; l1.custom_minimum_size.x = 60
	row1.add_child(l1)
	prefix_input = LineEdit.new()
	prefix_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prefix_input.placeholder_text = "ex: ninja, ork…"
	prefix_input.text_changed.connect(_on_prefix_changed)
	row1.add_child(prefix_input)
	right_vbox.add_child(row1)

	dest_lbl = Label.new()
	dest_lbl.add_theme_font_size_override("font_size", 10)
	dest_lbl.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
	dest_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_vbox.add_child(dest_lbl)

	right_vbox.add_child(HSeparator.new())

	var gen_btn = Button.new()
	gen_btn.text = "Generer sprites + .tres"
	gen_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gen_btn.pressed.connect(_on_export)
	right_vbox.add_child(gen_btn)

	status_lbl = Label.new()
	status_lbl.text          = "Chargement..."
	status_lbl.add_theme_font_size_override("font_size", 10)
	status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_vbox.add_child(status_lbl)

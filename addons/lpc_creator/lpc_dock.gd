@tool
extends Control

# ── Constants ─────────────────────────────────────────────────────────────────
const FRAME_W      := 64
const FRAME_H      := 64
const PREVIEW_SCALE := 3   # 192×192 px

const SLOT_ORDER := ["body","head","expression","hair","beard","hat","armour",
		"shoulders","arms","wrists","belt","legs","shoes","weapon","back","accessory"]

const ANIMS := ["idle","walk","run","hurt","slash","spellcast","thrust","shoot"]

const ANIM_FPS := {
	"idle":2,"walk":8,"run":8,"hurt":6,"slash":8,"spellcast":7,"thrust":8,"shoot":13
}

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
const TYPE_LABELS := ["Guerrier","Elf","Mage","Paladin","Gobelin","Générique"]
const SEX_PREFS   := ["male","muscular","female","teen","child"]

# ── State ─────────────────────────────────────────────────────────────────────
var catalog    : Dictionary = {}
var slots      : Dictionary = {}   # slot_name → {items, idx, variant_idx}
var cur_anim   := "idle"
var cur_dir    := 2                # 0=up 1=left 2=down 3=right
var cur_frame  := 0
var frame_time := 0.0
var tex_cache  : Dictionary = {}   # abs_path → ImageTexture|null

# ── Paths ─────────────────────────────────────────────────────────────────────
var ulpc_sprites : String          # .../ulpc/spritesheets/
var assets_abs   : String          # .../assets/

# ── UI refs ───────────────────────────────────────────────────────────────────
var viewport      : SubViewport
var layer_root    : Node2D
var slot_vbox     : VBoxContainer
var status_lbl    : Label
var name_input    : LineEdit
var type_opt      : OptionButton
var dest_lbl      : Label
var dir_group     : ButtonGroup
var anim_group    : ButtonGroup

var layer_sprites : Dictionary = {}   # slot → Sprite2D
var slot_item_lbl : Dictionary = {}   # slot → Label
var slot_var_row  : Dictionary = {}   # slot → Control (variant row)
var slot_var_hbx  : Dictionary = {}   # slot → HBoxContainer

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	var root      = ProjectSettings.globalize_path("res://")
	ulpc_sprites  = root + "tools/lpc_creator/ulpc/spritesheets/"
	assets_abs    = root + "assets/"
	custom_minimum_size = Vector2(240, 0)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_ui()
	_load_catalog.call_deferred()
	set_process(Engine.is_editor_hint())

func _process(delta: float) -> void:
	if slots.is_empty(): return
	frame_time += delta
	var fps := float(ANIM_FPS.get(cur_anim, 6))
	if frame_time >= 1.0 / fps:
		frame_time -= 1.0 / fps
		cur_frame += 1
		_redraw_frames()

# ── Catalog ───────────────────────────────────────────────────────────────────
func _load_catalog() -> void:
	var path = ProjectSettings.globalize_path("res://") + "tools/lpc_creator/catalog.json"
	var f = FileAccess.open(path, FileAccess.READ)
	if not f:
		status_lbl.text = "catalog.json introuvable\n→ Lancez tools/lpc_creator/start.bat"
		return
	var data = JSON.parse_string(f.get_as_text())
	if not data is Dictionary:
		status_lbl.text = "Erreur lecture catalog.json"
		return
	catalog = data
	_populate_slots()
	_suggest_dest()
	var has_local = FileAccess.file_exists(ulpc_sprites + "body/bodies/male/idle.png")
	status_lbl.text = "%d items | sprites %s" % [
		catalog.get("total", 0),
		"locaux OK" if has_local else "! ulpc/ absent — lancez download_ulpc.bat"
	]

# ── Slots ─────────────────────────────────────────────────────────────────────
func _populate_slots() -> void:
	for c in slot_vbox.get_children(): c.queue_free()
	for c in layer_root.get_children(): c.queue_free()
	slots.clear()
	layer_sprites.clear()
	slot_item_lbl.clear()
	slot_var_row.clear()
	slot_var_hbx.clear()
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
	lbl.custom_minimum_size.x = 70
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.clip_text = true
	row.add_child(lbl)

	var btn_l = Button.new()
	btn_l.text = "◀"
	btn_l.flat = true
	btn_l.custom_minimum_size = Vector2(20, 0)
	btn_l.pressed.connect(_prev_item.bind(slot_name))
	row.add_child(btn_l)

	var item_lbl = Label.new()
	item_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_lbl.add_theme_font_size_override("font_size", 9)
	item_lbl.clip_text = true
	item_lbl.text = "—"
	row.add_child(item_lbl)
	slot_item_lbl[slot_name] = item_lbl

	var btn_r = Button.new()
	btn_r.text = "▶"
	btn_r.flat = true
	btn_r.custom_minimum_size = Vector2(20, 0)
	btn_r.pressed.connect(_next_item.bind(slot_name))
	row.add_child(btn_r)

	slot_vbox.add_child(row)

	var var_cont = HBoxContainer.new()
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y  = 24
	scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_DISABLED
	var var_hbx = HBoxContainer.new()
	scroll.add_child(var_hbx)
	var_cont.add_child(scroll)
	var_cont.visible = false
	slot_vbox.add_child(var_cont)
	slot_var_row[slot_name] = var_cont
	slot_var_hbx[slot_name] = var_hbx

# ── Navigation ────────────────────────────────────────────────────────────────
func _prev_item(slot_name: String) -> void:
	var s = slots[slot_name]
	s.idx = (s.idx - 1 + s.items.size()) % s.items.size()
	s.variant_idx = 0
	_refresh_row(slot_name)
	_update_sprite(slot_name)

func _next_item(slot_name: String) -> void:
	var s = slots[slot_name]
	s.idx = (s.idx + 1) % s.items.size()
	s.variant_idx = 0
	_refresh_row(slot_name)
	_update_sprite(slot_name)

func _on_variant_toggled(pressed: bool, slot_name: String, vi: int) -> void:
	if not pressed: return
	slots[slot_name].variant_idx = vi
	_update_sprite(slot_name)

func _refresh_row(slot_name: String) -> void:
	var s    = slots[slot_name]
	var item = s.items[s.idx]
	slot_item_lbl[slot_name].text = item.get("name", "?") if item else "—"

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
			btn.add_theme_font_size_override("font_size", 8)
			btn.custom_minimum_size = Vector2(0, 18)
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
	cur_dir = d; cur_frame = 0
	_redraw_frames()

func _on_anim_toggled(pressed: bool, anim: String) -> void:
	if not pressed: return
	cur_anim = anim; cur_frame = 0; frame_time = 0.0
	_update_all_sprites()

# ── Export ────────────────────────────────────────────────────────────────────
func _suggest_dest() -> void:
	var type_name = TYPE_NAMES[type_opt.selected]
	var max_lvl   := 0
	var d = DirAccess.open("res://assets/")
	if d:
		for folder in d.get_directories():
			var norm = folder.replace("-", "_")
			if norm.begins_with(type_name + "_lvl_"):
				var n = norm.split("_lvl_")[1].to_int()
				if n > max_lvl: max_lvl = n
	var suggested = "%s_lvl_%d" % [type_name, max_lvl + 1]
	name_input.text = suggested
	dest_lbl.text   = "res://assets/" + suggested + "/"

func _on_name_changed(txt: String) -> void:
	dest_lbl.text = "res://assets/" + txt + "/"

func _on_export() -> void:
	var char_name = name_input.text.strip_edges()
	if char_name.is_empty():
		status_lbl.text = "Nom vide"; return

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

	if active.is_empty():
		status_lbl.text = "Aucun élément sélectionné"; return
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

	EditorInterface.get_resource_filesystem().scan()

	var gen_ok := false
	var gen_path := "res://Scripts/generate_all_frames.gd"
	if ResourceLoader.exists(gen_path):
		var gen = load(gen_path).new()
		if gen.has_method("_run"):
			gen._run()
			gen_ok = true

	status_lbl.text = "%d PNGs exports -> assets/%s/\n%s" % [
		exported, char_name,
		".tres generes" if gen_ok else "-> Lancez generate_all_frames.gd"
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

# ── UI construction ───────────────────────────────────────────────────────────
func _build_ui() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(260, 0)

	var tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(tabs)

	# ── Tab 0 : Preview ───────────────────────────────────────────────────────
	var tab_preview = VBoxContainer.new()
	tab_preview.name = "Preview"
	tab_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(tab_preview)

	# Viewport 2× (128 px) centré
	var vp_cont = SubViewportContainer.new()
	vp_cont.custom_minimum_size   = Vector2(FRAME_W * 2, FRAME_H * 2)
	vp_cont.stretch               = true
	vp_cont.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tab_preview.add_child(vp_cont)

	viewport = SubViewport.new()
	viewport.size                       = Vector2i(FRAME_W, FRAME_H)
	viewport.transparent_bg             = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp_cont.add_child(viewport)

	layer_root = Node2D.new()
	viewport.add_child(layer_root)
	var init_bg = ColorRect.new()
	init_bg.color = Color(0.12, 0.12, 0.15)
	init_bg.size  = Vector2(FRAME_W, FRAME_H)
	layer_root.add_child(init_bg)

	# Direction
	dir_group = ButtonGroup.new()
	var dir_row = HBoxContainer.new()
	dir_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tab_preview.add_child(dir_row)
	for pair in [["Haut",0],["Gauche",1],["Bas",2],["Droite",3]]:
		var btn = Button.new()
		btn.text           = pair[0]
		btn.toggle_mode    = true
		btn.button_group   = dir_group
		btn.button_pressed = (pair[1] == 2)
		btn.add_theme_font_size_override("font_size", 10)
		btn.toggled.connect(_on_dir_toggled.bind(pair[1]))
		dir_row.add_child(btn)

	# Animation (grille 4×2)
	anim_group = ButtonGroup.new()
	var anim_grid = GridContainer.new()
	anim_grid.columns = 4
	tab_preview.add_child(anim_grid)
	for a in ANIMS:
		var btn = Button.new()
		btn.text           = a
		btn.toggle_mode    = true
		btn.button_group   = anim_group
		btn.button_pressed = (a == "idle")
		btn.add_theme_font_size_override("font_size", 10)
		btn.toggled.connect(_on_anim_toggled.bind(a))
		anim_grid.add_child(btn)

	# Placeholder status (sera affiche dans tab Export)

	# ── Tab 1 : Slots ─────────────────────────────────────────────────────────
	var tab_slots = VBoxContainer.new()
	tab_slots.name = "Slots"
	tab_slots.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(tab_slots)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical    = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tab_slots.add_child(scroll)

	slot_vbox = VBoxContainer.new()
	slot_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(slot_vbox)

	# ── Tab 2 : Export ────────────────────────────────────────────────────────
	var tab_exp = VBoxContainer.new()
	tab_exp.name = "Export"
	tabs.add_child(tab_exp)

	var row1 = HBoxContainer.new()
	var l1 = Label.new()
	l1.text = "Nom:"; l1.custom_minimum_size.x = 40
	row1.add_child(l1)
	name_input = LineEdit.new()
	name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_input.placeholder_text      = "guerrier_lvl_2"
	name_input.text_changed.connect(_on_name_changed)
	row1.add_child(name_input)
	tab_exp.add_child(row1)

	var row2 = HBoxContainer.new()
	var l2 = Label.new()
	l2.text = "Type:"; l2.custom_minimum_size.x = 40
	row2.add_child(l2)
	type_opt = OptionButton.new()
	type_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for lbl in TYPE_LABELS: type_opt.add_item(lbl)
	type_opt.item_selected.connect(func(_i): _suggest_dest())
	row2.add_child(type_opt)
	tab_exp.add_child(row2)

	dest_lbl = Label.new()
	dest_lbl.add_theme_font_size_override("font_size", 9)
	dest_lbl.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
	dest_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tab_exp.add_child(dest_lbl)

	tab_exp.add_child(HSeparator.new())

	var gen_btn = Button.new()
	gen_btn.text = "Generer sprites + .tres"
	gen_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gen_btn.pressed.connect(_on_export)
	tab_exp.add_child(gen_btn)

	status_lbl = Label.new()
	status_lbl.text          = "Chargement du catalogue..."
	status_lbl.add_theme_font_size_override("font_size", 9)
	status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tab_exp.add_child(status_lbl)

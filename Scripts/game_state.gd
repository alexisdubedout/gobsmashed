extends Node

const SAVE_PATH = "user://save.cfg"

# Monnaies
var or_total: int = 0
var xp_total: int = 0

# Arbre de stats — niveau de chaque upgrade
var stats = {
	"hp_max": 0,
	"degats": 0,
	"vitesse": 0,
	"attaque": 0,
}

# Objets achetés pour la base
var objets_base = {
	"lit": false,
	"tourelle": false,
	"piege": false,
}

# Coûts des upgrades de stats (or par niveau, multiplié par niveau actuel)
const COUT_STATS = {
	"hp_max": 50,
	"degats": 75,
	"vitesse": 60,
	"attaque": 80,
}

# Coûts des objets de base
const COUT_OBJETS = {
	"lit": 200,
	"tourelle": 350,
	"piege": 150,
}

# Bonus par niveau de stat
const BONUS_STATS = {
	"hp_max": 10,
	"degats": 0.05,
	"vitesse": 0.05,
	"attaque": 0.05,
}

const MAX_NIVEAU_STAT = 10

func _ready():
	charger()

func ajouter_recompense(kills: int, temps: float):
	or_total += kills * 5
	xp_total += int(temps * 2)
	sauvegarder()
	print("Or: ", GameState.or_total, " XP: ", GameState.xp_total)

func acheter_stat(stat: String) -> bool:
	var cout = COUT_STATS[stat] * (stats[stat] + 1)
	if xp_total >= cout and stats[stat] < MAX_NIVEAU_STAT:
		xp_total -= cout
		stats[stat] += 1
		sauvegarder()
		return true
	return false

func acheter_objet(objet: String) -> bool:
	if objets_base.has(objet) and not objets_base[objet]:
		if or_total >= COUT_OBJETS[objet]:
			or_total -= COUT_OBJETS[objet]
			objets_base[objet] = true
			sauvegarder()
			return true
	return false

func get_hp_max_bonus() -> int:
	return stats["hp_max"] * BONUS_STATS["hp_max"]

func get_degats_bonus() -> float:
	return 1.0 + stats["degats"] * BONUS_STATS["degats"]

func get_vitesse_bonus() -> float:
	return 1.0 + stats["vitesse"] * BONUS_STATS["vitesse"]

func get_attaque_bonus() -> float:
	return 1.0 + stats["attaque"] * BONUS_STATS["attaque"]

func sauvegarder():
	var config = ConfigFile.new()
	config.set_value("monnaies", "or", or_total)
	config.set_value("monnaies", "xp", xp_total)
	for stat in stats:
		config.set_value("stats", stat, stats[stat])
	for objet in objets_base:
		config.set_value("objets", objet, objets_base[objet])
	config.save(SAVE_PATH)

func charger():
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	or_total = config.get_value("monnaies", "or", 0)
	xp_total = config.get_value("monnaies", "xp", 0)
	for stat in stats:
		stats[stat] = config.get_value("stats", stat, 0)
	for objet in objets_base:
		objets_base[objet] = config.get_value("objets", objet, false)

func reset_save():
	or_total = 0
	xp_total = 0
	for stat in stats:
		stats[stat] = 0
	for objet in objets_base:
		objets_base[objet] = false
	sauvegarder()

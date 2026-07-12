extends Node

const SAVE_PATH = "user://save.cfg"

# Monnaies
var or_total: int = 0
var xp_total: int = 0

# Skills débloquables (achetés dans Savoirs Douteux)
var skills_debloques: Dictionary = {
	"Attack speed":  true,
	"Avarice":       true,
	"Rage gobeline": true,
}

const COUT_SKILLS = {
	"Pièces lourdes":    400,
	"Flaque de poison":  600,
	"Fortification":     700,
	"Multi-shot":        800,
	"Collègue gobelin":  900,
	"Dash éclair":       950,
	"Drain vital":       1200,
	"Pièces explosives": 1400,
}

# Progression de difficulté
var niveau_difficulte: int = 1
var niveaux_debloques: int = 1

# Stats persistantes (toutes runs)
var morts_totales: int = 0
var or_cumule: int = 0
var dommages_cumules: Dictionary = {}

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
	"bouclier": false,
	"bouclier_magique": false,
}

# Coûts des upgrades de stats (xp par niveau, multiplié par niveau actuel)
const COUT_STATS = {
	"hp_max": 200,
	"degats": 300,
	"vitesse": 250,
	"attaque": 300,
}

# Coûts des objets de base
const COUT_OBJETS = {
	"lit": 800,
	"tourelle": 1500,
	"piege": 600,
	"bouclier": 6000,
	"bouclier_magique": 14000,
}

# Bonus par niveau de stat
const BONUS_STATS = {
	"hp_max": 10,
	"degats": 0.05,
	"vitesse": 0.05,
	"attaque": 0.05,
}

const MAX_NIVEAU_STAT = 10

# Dé de destin (reset à chaque run)
const DE_POOL_MAUVAIS := [
	{"nom": "La Tempête",     "desc": "Les ennemis chargent plus vite et arrivent en surnombre.", "qualite": "mauvais", "speed_mult": 1.4, "count_mult": 1.3},
	{"nom": "La Marée",       "desc": "Des vagues d'ennemis bien plus denses déferlent.",          "qualite": "mauvais", "count_mult": 1.25},
	{"nom": "La Malédiction", "desc": "Vous encaissez 20% de dégâts supplémentaires.",              "qualite": "mauvais", "dmg_taken_mult": 1.2},
	{"nom": "Le Vertige",     "desc": "Votre esquive récupère 50% plus lentement.",                 "qualite": "mauvais", "dash_cd_mult": 1.5},
	{"nom": "La Famine",      "desc": "Vos victoires rapportent 30% d'XP en moins.",                "qualite": "mauvais", "xp_mult": 0.7},
	{"nom": "L'Essaim",       "desc": "Les ennemis surgissent bien plus près de vous.",             "qualite": "mauvais", "spawn_radius_delta": -150.0},
]
const DE_POOL_BON := [
	{"nom": "L'Accalmie",     "desc": "Les vagues ennemies s'allègent nettement.",        "qualite": "bon", "count_mult": 0.75},
	{"nom": "La Pestilence",  "desc": "Une maladie frappe parfois les ennemis au hasard.", "qualite": "bon", "mort_spontanee": true},
	{"nom": "La Bénédiction", "desc": "Vous régénérez un peu de vie au fil du temps.",     "qualite": "bon", "regen_actif": true},
	{"nom": "L'Aubaine",      "desc": "Vos victoires rapportent 50% d'XP en plus.",        "qualite": "bon", "xp_mult": 1.5},
	{"nom": "Le Zéphyr",      "desc": "Vous gagnez en vivacité.",                          "qualite": "bon", "player_speed_mult": 1.15},
]
const DE_NEUTRE := {
	3: {"nom": "Le Calme",    "desc": "6 secondes de répit au début de la prochaine vague... mais elle sera un peu plus dense.",      "qualite": "neutre", "calm_delay": 6.0, "count_mult": 1.15},
	4: {"nom": "L'Équilibre", "desc": "+15 PV maintenant, mais les ennemis avanceront un peu plus vite jusqu'à la fin.",               "qualite": "neutre", "player_hp_bonus": 15, "speed_mult": 1.1},
}

var de_resultat: int = 0
var de_effet: Dictionary = {}
var de_speed_mult: float = 1.0
var de_count_mult: float = 1.0
var de_mort_spontanee: bool = false
var de_dmg_taken_mult: float = 1.0
var de_dash_cd_mult: float = 1.0
var de_xp_mult: float = 1.0
var de_player_speed_mult: float = 1.0
var de_regen_actif: bool = false

func reset_de():
	de_resultat = 0
	de_effet = {}
	de_speed_mult = 1.0
	de_count_mult = 1.0
	de_mort_spontanee = false
	de_dmg_taken_mult = 1.0
	de_dash_cd_mult = 1.0
	de_xp_mult = 1.0
	de_player_speed_mult = 1.0
	de_regen_actif = false

func appliquer_de(resultat: int) -> Dictionary:
	de_resultat = resultat
	var effet: Dictionary
	if resultat <= 2:
		effet = DE_POOL_MAUVAIS[randi() % DE_POOL_MAUVAIS.size()]
	elif resultat >= 5:
		effet = DE_POOL_BON[randi() % DE_POOL_BON.size()]
	else:
		effet = DE_NEUTRE[resultat]
	de_effet = effet
	de_speed_mult = effet.get("speed_mult", 1.0)
	de_count_mult = effet.get("count_mult", 1.0)
	de_mort_spontanee = effet.get("mort_spontanee", false)
	de_dmg_taken_mult = effet.get("dmg_taken_mult", 1.0)
	de_dash_cd_mult = effet.get("dash_cd_mult", 1.0)
	de_xp_mult = effet.get("xp_mult", 1.0)
	de_player_speed_mult = effet.get("player_speed_mult", 1.0)
	de_regen_actif = effet.get("regen_actif", false)
	return effet

# État transporté vers le combat boss
var boss_hp_joueur: int = 0
var boss_type: String = ""
var boss_level: int = 1
var boss_kills_run: int = 0
var boss_temps_run: float = 0.0

func _ready():
	charger()

func ajouter_recompense(kills: int, temps: float):
	var or_gagne = kills * 5
	or_total   += or_gagne
	or_cumule  += or_gagne
	xp_total   += int(temps * 2)
	sauvegarder()

func debloquer_niveau_suivant():
	if niveaux_debloques < 5:
		niveaux_debloques += 1
		sauvegarder()

func ajouter_mort():
	morts_totales += 1
	sauvegarder()

func ajouter_dommages(dommages: Dictionary):
	for type in dommages:
		dommages_cumules[type] = dommages_cumules.get(type, 0) + dommages[type]
	sauvegarder()

func debloquer_skill(skill: String) -> bool:
	var cout = COUT_SKILLS.get(skill, 0)
	if cout == 0 or skills_debloques.get(skill, false):
		return false
	if xp_total >= cout:
		xp_total -= cout
		skills_debloques[skill] = true
		sauvegarder()
		return true
	return false

func acheter_stat(stat: String) -> bool:
	var cout = COUT_STATS[stat] * (stats[stat] + 1)
	if xp_total >= cout and stats[stat] < MAX_NIVEAU_STAT:
		xp_total -= cout
		stats[stat] += 1
		sauvegarder()
		return true
	return false

func acheter_objet(objet: String) -> bool:
	if objet == "bouclier_magique" and not objets_base.get("bouclier", false):
		return false
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
	config.set_value("monnaies", "or_cumule", or_cumule)
	config.set_value("global", "morts", morts_totales)
	config.set_value("global", "niveaux_debloques", niveaux_debloques)
	for stat in stats:
		config.set_value("stats", stat, stats[stat])
	for objet in objets_base:
		config.set_value("objets", objet, objets_base[objet])
	for type in dommages_cumules:
		config.set_value("dommages", type, dommages_cumules[type])
	for skill in COUT_SKILLS:
		config.set_value("skills", skill, skills_debloques.get(skill, false))
	config.save(SAVE_PATH)

func charger():
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	or_total      = config.get_value("monnaies", "or", 0)
	xp_total      = config.get_value("monnaies", "xp", 0)
	or_cumule     = config.get_value("monnaies", "or_cumule", 0)
	morts_totales      = config.get_value("global", "morts", 0)
	niveaux_debloques  = config.get_value("global", "niveaux_debloques", 1)
	for stat in stats:
		stats[stat] = config.get_value("stats", stat, 0)
	for objet in objets_base:
		objets_base[objet] = config.get_value("objets", objet, false)
	for type in ["guerrier", "paladin", "elf", "mage"]:
		var v = config.get_value("dommages", type, 0)
		if v > 0:
			dommages_cumules[type] = v
	for skill in COUT_SKILLS:
		if config.get_value("skills", skill, false):
			skills_debloques[skill] = true

func reset_save():
	or_total       = 0
	xp_total       = 0
	or_cumule      = 0
	morts_totales     = 0
	niveaux_debloques = 1
	niveau_difficulte = 1
	dommages_cumules.clear()
	for stat in stats:
		stats[stat] = 0
	for objet in objets_base:
		objets_base[objet] = false
	for skill in COUT_SKILLS:
		skills_debloques.erase(skill)
	sauvegarder()

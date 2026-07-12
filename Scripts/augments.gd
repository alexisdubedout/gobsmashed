class_name Augments

static var stacks: Dictionary = {}

const LISTE = [
	{"nom": "Multi-shot",        "desc": "Tire 2 pièces à la fois",              "type": "attaque",  "icone": "🪙"},
	{"nom": "Attack speed",      "desc": "Tire plus vite",                        "type": "attaque",  "icone": "⚡"},
	{"nom": "Collègue gobelin",  "desc": "+1 allié qui vous suit",               "type": "renfort",  "icone": "👺"},
	{"nom": "Flaque de poison",  "desc": "Laisse une flaque au sol",             "type": "zone",     "icone": "☠️"},
	{"nom": "Pièces lourdes",    "desc": "Les ennemis ralentissent",             "type": "slow",     "icone": "💰"},
	{"nom": "Avarice",           "desc": "Chaque kill redonne des PV",           "type": "soin",     "icone": "💛"},
	{"nom": "Rage gobeline",     "desc": "Les pièces font plus de dégâts",       "type": "attaque",  "icone": "🔥"},
	{"nom": "Dash éclair",       "desc": "Améliore le dash",                     "type": "mobilité", "icone": "💨"},
	{"nom": "Bouclier forgé",    "desc": "Réduit la recharge du bouclier",       "type": "défense",  "icone": "🛡️", "requires": "bouclier"},
	{"nom": "Renvoi magique",    "desc": "Le renvoi inflige plus de dégâts",     "type": "défense",  "icone": "✨", "requires": "bouclier_magique"},
	{"nom": "Drain vital",       "desc": "Chaque pièce qui touche redonne des PV","type": "soin",    "icone": "🩸"},
	{"nom": "Fortification",     "desc": "Réduit les dégâts reçus",              "type": "défense",  "icone": "🪨"},
	{"nom": "Pièces explosives", "desc": "Les pièces explosent à l'impact",      "type": "attaque",  "icone": "🧨"},
	{"nom": "Grande bourse",     "desc": "Augmente la capacité de la bourse",    "type": "bourse",   "icone": "👜"},
	{"nom": "Filon d'or",        "desc": "Le coffre recharge la bourse plus vite","type": "bourse",  "icone": "⛏️"},
	# Nouveaux skills
	{"nom": "Régénération",       "desc": "Regagne des PV passivement",                           "type": "soin",     "icone": "💚"},
	{"nom": "Aura menaçante",     "desc": "Inflige des dégâts aux ennemis proches chaque seconde","type": "zone",     "icone": "🌀"},
	{"nom": "Frappe critique",    "desc": "Chance de doubler les dégâts d'une pièce",            "type": "attaque",  "icone": "💥"},
	{"nom": "Ruée offensive",     "desc": "Le dash blesse les ennemis traversés",                 "type": "mobilité", "icone": "⚔️"},
	{"nom": "Épines",             "desc": "Renvoie des dégâts aux ennemis qui frappent",         "type": "défense",  "icone": "🌵"},
	{"nom": "Alliés fervents",    "desc": "Les alliés tirent plus vite et plus fort",            "type": "renfort",  "icone": "🏹"},
	{"nom": "Gobelin frénétique", "desc": "Chaque kill booste la vitesse de déplacement",        "type": "mobilité", "icone": "🐾"},
	{"nom": "Pièces empoisonnées","desc": "Les pièces appliquent un poison sur les ennemis",     "type": "attaque",  "icone": "🐍"},
]

static func reset() -> void:
	stacks.clear()

static func is_maxed(nom: String) -> bool:
	return stacks.get(nom, 0) >= 3

static func get_liste_disponible() -> Array:
	return LISTE.filter(func(a):
		if stacks.get(a["nom"], 0) >= 3:
			return false
		if GameState.COUT_SKILLS.has(a["nom"]) and not GameState.skills_debloques.get(a["nom"], false):
			return false
		var req = a.get("requires", "")
		if req != "" and not GameState.objets_base.get(req, false):
			return false
		return true
	)

static func get_desc(augment: Dictionary) -> String:
	var nom = augment["nom"]
	var stack = stacks.get(nom, 0)
	match nom:
		"Attack speed":
			match stack:
				0: return "Tire 15% plus vite"
				1: return "Tire 25% plus vite (2/3)"
				2: return "Tire 50% plus vite (MAX)"
		"Multi-shot":
			match stack:
				0: return "Tire 2 pièces à la fois"
				1: return "Tire 3 pièces à la fois"
				2: return "3 pièces + rebond (MAX)"
		"Collègue gobelin":
			match stack:
				0: return "+1 allié gobelin"
				1: return "+2 alliés goblins"
				2: return "+3 alliés + tirent plus vite (MAX)"
		"Flaque de poison":
			match stack:
				0: return "Flaque basique au sol"
				1: return "Flaque plus grande + ralentit"
				2: return "Flaque massive + slow + dégâts x2 (MAX)"
		"Pièces lourdes":
			match stack:
				0: return "Ralentit les ennemis touchés (1.5s)"
				1: return "Ralentissement plus long (2.5s)"
				2: return "Ralentissement 3.5s + stun bref 0.5s (MAX)"
		"Avarice":
			match stack:
				0: return "+2 PV par kill"
				1: return "+3 PV par kill"
				2: return "+5 PV par kill (MAX)"
		"Rage gobeline":
			match stack:
				0: return "+20% dégâts des pièces"
				1: return "+40% dégâts des pièces"
				2: return "+60% dégâts + pièces traversent (MAX)"
		"Dash éclair":
			match stack:
				0: return "CD dash 1.5s → 1.1s (top-down + boss)"
				1: return "CD 0.7s + I-frames étendus"
				2: return "CD 0.5s + distance max (MAX)"
		"Bouclier forgé":
			match stack:
				0: return "Recharge 8s → 5s"
				1: return "Recharge 5s → 3s"
				2: return "Recharge 3s → 2s + chaque blocage redonne 3 PV (MAX)"
		"Renvoi magique":
			match stack:
				0: return "Le renvoi inflige +50% de dégâts"
				1: return "Le renvoi inflige +100% de dégâts"
				2: return "Dégâts x2 + le renvoi explose en zone (MAX)"
		"Drain vital":
			match stack:
				0: return "+1 PV par pièce qui touche"
				1: return "+2 PV par pièce qui touche"
				2: return "+3 PV par pièce qui touche (MAX)"
		"Fortification":
			match stack:
				0: return "-2 dégâts par coup reçu (min 1)"
				1: return "-4 dégâts par coup reçu (MAX réduction)"
				2: return "-4 dégâts + 15% de tous les dégâts (MAX)"
		"Pièces explosives":
			match stack:
				0: return "Explosion : 30% dégâts dans un rayon de 50px"
				1: return "Explosion : 50% dégâts, rayon 75px"
				2: return "Explosion : 70% dégâts, rayon 100px + les ennemis touchés ralentissent (MAX)"
		"Grande bourse":
			match stack:
				0: return "Capacité : 30 → 40 pièces"
				1: return "Capacité : 40 → 55 pièces (2/3)"
				2: return "Capacité : 55 → 75 pièces (MAX)"
		"Filon d'or":
			match stack:
				0: return "Coffre : 2 → 3,5 pièces/sec"
				1: return "Coffre : 3,5 → 5 pièces/sec (2/3)"
				2: return "Coffre : 5 → 7 pièces/sec + 25% bonus sur ramassage (MAX)"
		"Régénération":
			match stack:
				0: return "+1 PV toutes les 4 secondes"
				1: return "+2 PV toutes les 4 secondes"
				2: return "+3 PV toutes les 4 secondes + 15 PV immédiats (MAX)"
		"Aura menaçante":
			match stack:
				0: return "3 dégâts/s aux ennemis dans un rayon de 60px"
				1: return "5 dégâts/s, rayon 80px"
				2: return "7 dégâts/s, rayon 100px + ralentit les ennemis (MAX)"
		"Frappe critique":
			match stack:
				0: return "15% de chance de doubler les dégâts"
				1: return "25% de chance de doubler les dégâts"
				2: return "35% crit + mini-explosion sur chaque crit (MAX)"
		"Ruée offensive":
			match stack:
				0: return "Le dash inflige 15 dégâts aux ennemis traversés"
				1: return "25 dégâts + repousse"
				2: return "30 dégâts + empoisonne les ennemis touchés (MAX)"
		"Épines":
			match stack:
				0: return "Renvoie 5 dégâts quand touché"
				1: return "Renvoie 10 dégâts quand touché"
				2: return "Renvoie 15 dégâts + ralentit l'ennemi frappeur (MAX)"
		"Alliés fervents":
			match stack:
				0: return "Alliés tirent 30% plus vite + dégâts scalent avec la rage"
				1: return "Alliés tirent 50% plus vite + +5 dégâts par pièce"
				2: return "Alliés tirent 70% plus vite + héritent pierce/rebond (MAX)"
		"Gobelin frénétique":
			match stack:
				0: return "+30% vitesse pendant 2s après chaque kill"
				1: return "+40% vitesse pendant 3s, les kills s'accumulent"
				2: return "+50% vitesse 4s + 3 kills consécutifs rechargent le dash (MAX)"
		"Pièces empoisonnées":
			match stack:
				0: return "2 dégâts/s pendant 2s sur l'ennemi touché"
				1: return "3 dégâts/s pendant 3s"
				2: return "4 dégâts/s pendant 4s + ralentit les ennemis empoisonnés (MAX)"
	return augment["desc"]

static func appliquer(augment: Dictionary, player) -> void:
	var nom = augment["nom"]
	var stack = stacks.get(nom, 0) + 1
	stacks[nom] = stack

	match nom:
		"Attack speed":
			var base_delay = 1.2 / GameState.get_attaque_bonus()
			match stack:
				1: player.ATTACK_DELAY = max(0.2, base_delay * 0.85)
				2: player.ATTACK_DELAY = max(0.2, base_delay * 0.75)
				3: player.ATTACK_DELAY = max(0.2, base_delay * 0.50)
		"Multi-shot":
			if stack < 3:
				player.multi_shot += 1
			if stack == 3:
				player.coin_bounce = true
		"Collègue gobelin":
			player.ajouter_collegue()
			if stack == 3:
				player.ally_fast = true
		"Flaque de poison":
			player.activer_flaque_poison(stack)
		"Pièces lourdes":
			player.pieces_lourdes_niveau = stack
		"Avarice":
			player.avarice_niveau = stack  # valeurs +2/+3/+5 gérées dans gagner_xp()
		"Rage gobeline":
			player.rage_niveau = stack
			if stack == 3:
				player.coin_pierce = true
		"Dash éclair":
			pass  # Lu au démarrage du boss fight par player_platformer._ready()
		"Bouclier forgé":
			match stack:
				1: player.bouclier_cd_dur = 5.0
				2: player.bouclier_cd_dur = 3.0
				3: player.bouclier_cd_dur = 2.0; player.bouclier_soin_actif = true; player.bouclier_parade_melee = true
		"Renvoi magique":
			match stack:
				1: player.bouclier_renvoi_mult = 1.5
				2: player.bouclier_renvoi_mult = 2.0
				3: player.bouclier_renvoi_mult = 2.0; player.bouclier_renvoi_aoe = true
		"Drain vital":
			player.drain_niveau = stack
		"Fortification":
			player.fortification_niveau = stack
		"Pièces explosives":
			player.explosion_niveau = stack
		"Grande bourse":
			var caps = [40, 55, 75]
			player.bourse_max = caps[stack - 1]
			if stack == 3:
				player.bourse_passive_regen = true
		"Filon d'or":
			player.coffre_regen_niveau = stack
			if stack == 3:
				player.filon_bonus_actif = true
		"Régénération":
			player.regen_niveau = stack
			if stack == 3:
				player.current_hp = min(player.max_hp, player.current_hp + 15)
		"Aura menaçante":
			player.aura_niveau = stack
		"Frappe critique":
			var chances = [0.15, 0.25, 0.35]
			player.crit_chance = chances[stack - 1]
		"Ruée offensive":
			player.ruee_niveau = stack
		"Épines":
			player.epines_niveau = stack
		"Alliés fervents":
			player.allies_fervents = stack
		"Gobelin frénétique":
			player.gobelin_frenetic = stack
		"Pièces empoisonnées":
			player.pieces_empoisonnees = stack

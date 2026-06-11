class_name Augments

static var stacks: Dictionary = {}

const LISTE = [
	{"nom": "Multi-shot", "desc": "Tire 2 pièces à la fois", "type": "attaque", "icone": "🪙"},
	{"nom": "Attack speed", "desc": "Tire plus vite", "type": "attaque", "icone": "⚡"},
	{"nom": "Collègue gobelin", "desc": "+1 allié qui vous suit", "type": "renfort", "icone": "👺"},
	{"nom": "Flaque de poison", "desc": "Laisse une flaque au sol", "type": "zone", "icone": "☠️"},
	{"nom": "Pièces lourdes", "desc": "Les ennemis ralentissent", "type": "slow", "icone": "💰"},
	{"nom": "Avarice", "desc": "Chaque kill redonne des PV", "type": "soin", "icone": "💛"},
	{"nom": "Rage gobeline", "desc": "Les pièces font plus de dégâts", "type": "attaque", "icone": "🔥"},
	{"nom": "Dash éclair", "desc": "Améliore le dash du boss fight", "type": "mobilité", "icone": "💨"},
]

static func reset() -> void:
	stacks.clear()

static func is_maxed(nom: String) -> bool:
	return stacks.get(nom, 0) >= 3

static func get_liste_disponible() -> Array:
	return LISTE.filter(func(a): return stacks.get(a["nom"], 0) < 3)

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
				0: return "Ralentit légèrement les ennemis touchés"
				1: return "Ralentissement plus fort + plus long"
				2: return "Stun bref à l'impact (MAX)"
		"Avarice":
			match stack:
				0: return "+1 PV par kill"
				1: return "+2 PV par kill"
				2: return "+3 PV par kill (MAX)"
		"Rage gobeline":
			match stack:
				0: return "+20% dégâts des pièces"
				1: return "+40% dégâts des pièces"
				2: return "+60% dégâts + pièces traversent (MAX)"
		"Dash éclair":
			match stack:
				0: return "Cooldown réduit (1.5s → 1.1s)"
				1: return "I-frames étendus + cooldown 0.7s"
				2: return "Distance max + cooldown 0.5s (MAX)"
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
			player.avarice_niveau = stack
		"Rage gobeline":
			player.rage_niveau = stack
			if stack == 3:
				player.coin_pierce = true
		"Dash éclair":
			pass  # Lu au démarrage du boss fight par player_platformer._ready()

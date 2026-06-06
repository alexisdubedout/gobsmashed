class_name Augments

const LISTE = [
	{"nom": "Multi-shot", "desc": "Tire 2 pièces à la fois", "type": "attaque", "icone": "🪙"},
	{"nom": "Attack speed", "desc": "Tire 50% plus vite", "type": "attaque", "icone": "⚡"},
	{"nom": "Collègue gobelin", "desc": "+1 allié qui vous suit", "type": "renfort", "icone": "👺"},
	{"nom": "Flaque de poison", "desc": "Laisse une flaque au sol", "type": "zone", "icone": "☠️"},
	{"nom": "Pièces lourdes", "desc": "Les ennemis ramassant l'or ralentissent", "type": "slow", "icone": "💰"},
	{"nom": "Trappe à ours", "desc": "Pose un piège qui immobilise", "type": "root", "icone": "🪤"},
]

static func appliquer(augment: Dictionary, player) -> void:
	match augment["nom"]:
		"Attack speed":
			player.ATTACK_DELAY = max(0.2, player.ATTACK_DELAY - 0.3)
		"Multi-shot":
			player.multi_shot += 1
		"Collègue gobelin":
			player.ajouter_collegue()
		"Flaque de poison":
			player.activer_flaque_poison()
		"Pièces lourdes":
			player.activer_pieces_lourdes()
		"Trappe à ours":
			player.activer_trappe()

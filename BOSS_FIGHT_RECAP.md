# Gobsmashed — Récap Boss Fight

Résumé des choix techniques et de design pour la deuxième boucle de gameplay (combat de boss en plateforme). Rédigé pour permettre à un nouveau contributeur de comprendre l'état du projet.

---

## Vue d'ensemble

Le jeu comporte deux boucles enchaînées :

1. **Vague (top-down)** — le joueur défend des vagues d'ennemis, accumule des augments
2. **Combat de boss (plateforme)** — déclenché après la vague 6, combat 1v1 style Cuphead/Dark Souls

Les HP et augments de la vague sont transférés au combat de boss via deux singletons : `GameState` et `Augments`.

---

## Transition vague → boss fight

- À la vague 6, `spawner.gd` vide les ennemis et spawn un boss en top-down
- Le boss a un indicateur visuel (aura rouge pulsée + label "★ BOSS ★")
- Il s'approche du joueur sans attaquer ; au contact → `get_tree().change_scene_to_file("res://scenes/boss_fight/boss_fight.tscn")`
- `GameState` transporte `boss_type`, `boss_hp_joueur`, `boss_kills_run`, `boss_temps_run`
- `Augments.stacks` est statique et survit naturellement aux changements de scène

---

## Architecture des scènes boss fight

```
scenes/boss_fight/
├── boss_fight.tscn / .gd      — orchestrateur (arène, HUD, spawn)
├── player_platformer.tscn/.gd — joueur plateforme
├── boss_platformer.tscn/.gd   — IA boss
scenes/enemies/
├── boss.tscn / .gd            — boss top-down (transition uniquement)
scenes/projectiles/
├── coin.gd                    — réutilisé avec hit_radius configurable
├── magic_orb.gd               — projectile mage
```

---

## Système de collision (layers)

| Entité | collision_layer | collision_mask |
|---|---|---|
| Sol | 1 | — |
| Plateformes flottantes | 2 | — |
| Joueur (plateforme) | 8 | 3 (sol + plateformes) |
| Boss | 4 | 3 (sol + plateformes) |

Le joueur est sur le layer 8, le boss sur le layer 4 — ils ne se détectent pas mutuellement : le joueur traverse le boss physiquement. Les projectiles utilisent une détection par distance (`global_position.distance_to()`), pas la physique, donc insensibles aux layers.

Les plateformes flottantes ont `one_way_collision = true`. Le boss peut les traverser par le bas via `set_collision_mask_value(2, false)` temporairement (coroutine `_descendre()`).

---

## Génération d'arène procédurale

Chaque boss a un profil dans `BOSS_ARENA_PROFILES` (dans `boss_fight.gd`) qui encode les contraintes d'arène déduites de ses attaques.

**Mage** — exemple de raisonnement :

| Attaque | Ce qui amplifie le danger | Contrainte d'arène |
|---|---|---|
| Spirale (radiale) | Joueur proche du mage | Plateformes côté joueur uniquement (gauche) |
| Pluie (aléatoire sur x) | Grande arène = plus de zone couverte | `arena_w` : 950–1100px |
| Vise / Homing (ciblés) | Plateforme étroite = pas de dodge latéral | `plat_width` : 80–115px |
| Kiting (mage à 250px idéal) | Grande arène = mage kite librement | `arena_w` : 950–1100px |

L'arène est générée aléatoirement à chaque combat dans l'espace de paramètres du profil. Le nombre, la taille et la position des plateformes varient à chaque run.

---

## IA des boss (style Dark Souls)

**Principe** : séquences d'attaques fixes par boss et par phase. Le joueur peut apprendre les patterns. Pas d'aléatoire dans l'ordre des attaques, seulement dans certains paramètres (nb de projectiles, positions).

```
SEQUENCES = {
    "mage": [
        ["spirale", "vise", "pluie_mage"],          # phase 1
        ["spirale", "homing", "vise", "pluie_mage"], # phase 2
    ],
    ...
}
```

**Mouvement par boss** :
- Guerrier : fonce directement vers le joueur (130px/s)
- Paladin : lent et imposant (80px/s), frappe en zone
- Elfe : kite (s'éloigne si joueur trop proche, s'approche si trop loin)
- Mage : maintient une distance idéale de 250px

**Anti-cheese** : si le joueur est en dessous d'une plateforme occupée par le boss, le boss descend (`set_collision_mask_value(2, false)` + `velocity.y = 100`, restaure après 0.45s).

**Phase 2** : déclenché à 50% HP. Flash visuel, séquence d'attaques changée, timers plus courts.

---

## Téléportation du mage (phase 2)

Déclenchée après chaque attaque si le cooldown est écoulé (7–11s entre deux). 3 zones fixes : gauche (18%), centre (50%), droite (80%) de l'arène. Le mage ne téléporte jamais deux fois dans la même zone.

**3 phases visuelles** (obligatoire pour permettre au joueur de réagir) :
1. **Cast** 0.9s — mage scintille doré (joueur peut punir pendant ce temps)
2. **Fantôme** 0.55s — silhouette bleue pulsée à la destination
3. **Apparition** 0.35s — flash blanc → fondu

Le timer d'attaque est suspendu pendant toute la téléportation (`en_teleportation` bloque le check d'attaque dans `_physics_process`).

---

## Joueur en boss fight

**Contrôles** :
- Déplacement : gauche/droite
- Saut : `move_up`
- Dash : bouton 💨 (mobile) ou `move_down` (clavier)
- Attaque : automatique, vise le boss

**Dash** :
- 550px/s, durée 0.18s de base (≈100px)
- I-frames pendant le dash : les projectiles ne se détruisent pas si le joueur est invincible (`take_damage()` retourne `false`)
- Squish sprite au déclenchement (scale 1.5×0.6)
- Cooldown affiché sur le bouton : vert = prêt, bleu sombre + countdown = recharge, flash cyan = disponible

**Augment "Dash éclair"** (accessible dans la vague) :
| Stack | Cooldown | I-frames | Distance |
|---|---|---|---|
| Base | 1.5s | 0.18s | 0.18s |
| 1 | 1.1s | 0.22s | 0.18s |
| 2 | 0.7s | 0.28s | 0.22s |
| 3 | 0.5s | 0.35s | 0.26s |

---

## Augments (persistance vague → boss)

`Augments` est une classe statique avec `stacks: Dictionary`. Les stacks survivent au changement de scène sans reset. Les augments lus dans `player_platformer._ready()` :

| Augment | Effet en boss fight |
|---|---|
| Multi-shot | Pièces supplémentaires avec dispersion |
| Attack speed | Délai d'attaque réduit |
| Rage gobeline | +20/40/60% dégâts, stack 3 = perce |
| Pièces lourdes | Slow/root sur boss |
| Dash éclair | Stats du dash améliorées |

Les augments liés au monde top-down (Collègue gobelin, Flaque de poison, Trappe) sont ignorés en boss fight.

---

## Fichiers modifiés / créés

**Créés** :
- `scenes/boss_fight/boss_fight.tscn` + `.gd`
- `scenes/boss_fight/player_platformer.tscn` + `.gd`
- `scenes/boss_fight/boss_platformer.tscn` + `.gd`
- `scenes/enemies/boss.tscn` + `.gd`

**Modifiés** :
- `Scripts/game_state.gd` — 4 variables de transport boss
- `Scripts/augments.gd` — augment "Dash éclair" ajouté
- `scenes/world/spawner.gd` — spawn du boss top-down à la vague 6
- `scenes/world/hud.gd` — annonce boss + bouton dash
- `scenes/player/player.gd` — dash top-down + i-frames + take_damage retourne bool
- `scenes/projectiles/coin.gd` — `hit_radius` configurable, `take_damage` vérifié avant queue_free

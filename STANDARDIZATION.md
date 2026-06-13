# Standardisation des assets — gobsmashed

**Date :** 2026-06-13  
**Standard cible :** canvas 64×64 px/frame, top-down 4 directions, couches visuelles séparées

---

## Standard défini

### Canvas
| Paramètre | Valeur |
|---|---|
| Frame size | **64 × 64 px** |
| Pivot point | Centre-bas (offset AnimatedSprite2D = `(0, -32)`) |
| Vue | Top-down isométrique 4 directions |

### Animations par personnage
| Nom base | Frames | Directions | Exemples de noms |
|---|---|---|---|
| idle | 4 | up/down/left/right | `idle_down`, `idle_up`… |
| run | 6 | up/down/left/right | `run_left`, `run_right`… |
| attack | 5 | up/down/left/right | `attack_up`, `attack_down`… |
| hurt | 2 | up/down/left/right | `hurt_left`… |
| die | 6 | up/down/left/right | `die_down`… |

**Total : 20 animations × N couches par personnage.**

### Hiérarchie de nœuds (CharacterBody2D)
```
CharacterBody2D
├── CollisionShape2D          capsule radius=6, height=20
├── Sprite2D                  CONSERVÉ — animation legacy (code existant)
├── AnimatedSprite2D "shadow"       z_index: -1  visible: false*
├── AnimatedSprite2D "body"         z_index: 0   visible: false*
├── AnimatedSprite2D "clothes"      z_index: 1   visible: false*
├── AnimatedSprite2D "armor_chest"  z_index: 2   visible: false*
├── AnimatedSprite2D "armor_legs"   z_index: 3   visible: false*
├── AnimatedSprite2D "helmet"       z_index: 4   visible: false*
└── AnimatedSprite2D "weapon"       z_index: 5   visible: false*
```
*`visible = false` jusqu'à ce que les sprites 64×64 soient produits.  
Le `Sprite2D` existant continue de piloter le rendu en attendant.

### CollisionShape2D
| Paramètre | Valeur |
|---|---|
| Type | CapsuleShape2D |
| Radius | 6.0 px |
| Height | 20.0 px (total, hémisphères inclus) |

---

## Sprites existants

### Personnages

| Fichier | Dimensions originales | Frame size | Grille | Conforme 64×64 | Action |
|---|---|---|---|---|---|
| `assets/characters/Gobelin.png` | 144 × 192 px | 48 × 48 px | 3×4 | ❌ | À refaire en 192×256 (3×4 grille de 64×64) |
| `assets/characters/Guerrier.png` | 616 × 308 px | 77 × 77 px | 8×4 | ❌ | À refaire en 512×256 (8×4 grille de 64×64) |
| `assets/characters/Elf.png` | 616 × 308 px | 77 × 77 px | 8×4 | ❌ | À refaire en 512×256 |
| `assets/characters/Mage.png` | 616 × 308 px | 77 × 77 px | 8×4 | ❌ | À refaire en 512×256 |
| `assets/characters/Paladin.png` | 616 × 308 px | 77 × 77 px | 8×4 | ❌ | À refaire en 512×256 |

**Note :** Les sprites actuels (8×4 = 32 frames) ne correspondent pas au standard cible (5 types × 4 directions = 20 animations). La grille cible sera **une texture par animation** ou **une spritesheet par couche** selon le pipeline de production.

### Projectiles & effets (hors standard personnage)

| Fichier | Dimensions | Frame size | Statut |
|---|---|---|---|
| `assets/projectiles/Gold coin.png` | 792 × 99 px | 99 × 99 px | Non concerné (projectile) |
| `assets/projectiles/magic/Water Ball_Frame_01-12.png` | 640 × 640 px × 12 | 640 × 640 px | Non concerné (projectile) |
| `assets/effects/poison.png` | 500 × 500 px | 167 × 167 px | Non concerné (effet zone) |
| `assets/effects/trap/Calque 1-6.png` | Dimensions hétérogènes | — | Non concerné (effet) |

### Tilesets (hors standard personnage)

| Fichier | Dimensions | Tiles | Statut |
|---|---|---|---|
| `assets/tileset/Isometric Assets 1-3.png` | 2560 × 2560 px | 256 × 256 px | Non concerné |
| `assets/tileset/Isometric Assets 4.png` | 1536 × 512 px | 256 × 256 px | Non concerné |
| `assets/tileset/walls_floor.png` | 272 × 464 px | — | Non concerné |

---

## Scènes modifiées

### player.tscn
- **CollisionShape2D** : `RectangleShape2D` (taille indéfinie) → `CapsuleShape2D(radius=6, height=20)`
- **Ajouté** : 7 nœuds `AnimatedSprite2D` (shadow → weapon), tous `visible=false`
- **Conservé** : `Sprite2D` legacy, `Camera2D`, logique `player.gd` intacte

### ally.tscn
- **CollisionShape2D** : `RectangleShape2D` (taille indéfinie, disabled) → `CapsuleShape2D(radius=6, height=20, disabled=true)`
- **Ajouté** : 7 nœuds `AnimatedSprite2D`, tous `visible=false`
- **Conservé** : `Sprite2D` legacy, logique `ally.gd` intacte

### guerrier.tscn *(scène de base pour elf, mage, paladin)*
- **CollisionShape2D** (CharacterBody2D) : `RectangleShape2D(32×32)` → `CapsuleShape2D(radius=6, height=20)`
- **Area2D/CollisionShape2D** : inchangé `RectangleShape2D(32×32)` — hitbox de réception de dégâts, hors scope
- **Ajouté** : 7 nœuds `AnimatedSprite2D`, tous `visible=false` — **hérités automatiquement par elf, mage, paladin**
- **Conservé** : `Sprite2D` legacy, `Area2D`, logique `guerrier.gd` intacte

### elf.tscn *(instance de guerrier.tscn)*
- **CollisionShape2D override** : `RectangleShape2D(32×32)` → `CapsuleShape2D(radius=6, height=20)`
- **Hérité de guerrier.tscn** : 7 nœuds AnimatedSprite2D (pas besoin de les redéclarer)
- **Conservé** : override `Sprite2D` texture, logique `elf.gd` intacte

### mage.tscn *(instance de guerrier.tscn)*
- **Aucune modification** — pas d'override CollisionShape2D → hérite directement le CapsuleShape2D de guerrier
- Hérite des 7 AnimatedSprite2D automatiquement

### paladin.tscn *(instance de guerrier.tscn)*
- **Aucune modification** — même raison que mage
- Hérite des 7 AnimatedSprite2D automatiquement

### boss.tscn
- **CollisionShape2D** : `RectangleShape2D(36×40)` → `CapsuleShape2D(radius=6, height=20)`
- **Ajouté** : 7 nœuds `AnimatedSprite2D`, tous `visible=false`
- **Conservé** : `Sprite2D` legacy, logique `boss.gd` intacte

### Scènes NON modifiées
| Scène | Raison |
|---|---|
| `boss_fight/boss_platformer.tscn` | Vue side-scroller, pas top-down |
| `boss_fight/player_platformer.tscn` | Vue side-scroller, pas top-down |
| `projectiles/coin.tscn` | Projectile, hors scope |
| `projectiles/magic_orb.tscn` | Projectile, hors scope |
| `effects/poison_pool.tscn` | Effet zone, hors scope |
| `effects/trap.tscn` | Effet, hors scope |
| `world/*.tscn` | Décor statique, hors scope |

---

## Scripts créés

### `scenes/characters/character_animator.gd`
Classe `CharacterAnimator extends RefCounted`.  
Usage : instancier dans `_ready()`, appeler `play("run", "left")`.

```gdscript
var _animator := CharacterAnimator.new()
_animator.init(self)           # self = CharacterBody2D
_animator.play("run", "left")  # joue run_left sur toutes les couches visibles
```

**API publique :**
- `init(character: CharacterBody2D)` — attache l'animator au personnage
- `play(anim, direction)` — joue `anim_direction` sur toutes les couches visibles avec ce nom
- `stop()` — arrête toutes les couches
- `is_playing() -> bool`
- `is_finished() -> bool`
- `current_animation() -> String`
- `expected_animations() -> Array[String]` *(static)* — liste les 20 noms attendus
- `expected_frame_count(anim_base) -> int` *(static)*

### `scenes/characters/character_base.gd`
Classe `CharacterBase extends CharacterBody2D`.  
Base pour les futurs scripts de personnage. N'affecte pas les scripts existants.

**Ce qu'elle fournit :**
- HP : `take_damage(amount)`, `heal(amount)`, `is_alive()`, `hp_ratio()`
- Direction : `update_direction(move_vec: Vector2)` → met à jour `direction` (up/down/left/right)
- État : `set_state(state)` → joue l'animation correspondante via CharacterAnimator
- Hooks : `_on_hurt()`, `_on_die()` à surcharger

---

## Prochaines étapes (hors scope de cette standardisation)

1. **Produire les sprites 64×64** pour chaque personnage, organisés en 5 types × 4 directions
2. **Créer les SpriteFrames** (`.tres`) pour chaque couche de chaque personnage
3. **Activer les AnimatedSprite2D** (`visible = true`) et désactiver le `Sprite2D` legacy
4. **Migrer les scripts** existants vers `CharacterBase` si souhaité (optionnel)
5. **Valider le pivot centre-bas** sur chaque sprite produit avec un repère visuel en scène

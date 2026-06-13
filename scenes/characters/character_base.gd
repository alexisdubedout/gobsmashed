class_name CharacterBase
extends CharacterBody2D

## Classe de base pour joueur et ennemis.
## Gère HP, direction cardinale, et machine à états d'animation.
## Les scripts existants n'ont pas besoin d'en hériter immédiatement —
## cette classe est la fondation pour les futurs scripts.

# ── États ───────────────────────────────────────────────────────
const STATE_IDLE   := "idle"
const STATE_RUN    := "run"
const STATE_ATTACK := "attack"
const STATE_HURT   := "hurt"
const STATE_DIE    := "die"

# ── Exports ─────────────────────────────────────────────────────
@export_group("Stats")
@export var max_hp: int = 100

@export_group("Animation")
@export var default_direction: String = "down"

# ── État courant ─────────────────────────────────────────────────
var current_hp: int    = 0
var direction:  String = "down"
var state:      String = STATE_IDLE

var _animator: CharacterAnimator = null

# ── Init ─────────────────────────────────────────────────────────
func _ready() -> void:
	current_hp = max_hp
	direction  = default_direction
	state      = STATE_IDLE
	_animator  = CharacterAnimator.new()
	_animator.init(self)

# ── HP ───────────────────────────────────────────────────────────
func take_damage(amount: int) -> void:
	if state == STATE_DIE:
		return
	current_hp -= amount
	if current_hp <= 0:
		current_hp = 0
		_on_die()
	else:
		_on_hurt()

func heal(amount: int) -> void:
	current_hp = min(current_hp + amount, max_hp)

func is_alive() -> bool:
	return current_hp > 0

func hp_ratio() -> float:
	return float(current_hp) / float(max_hp) if max_hp > 0 else 0.0

# ── Direction ────────────────────────────────────────────────────
## Met à jour la direction cardinale depuis un vecteur de déplacement 2D.
## À appeler chaque frame avec la vélocité ou l'input avant move_and_slide().
func update_direction(move_vec: Vector2) -> void:
	if move_vec == Vector2.ZERO:
		return
	if abs(move_vec.x) >= abs(move_vec.y):
		direction = "right" if move_vec.x > 0.0 else "left"
	else:
		direction = "down" if move_vec.y > 0.0 else "up"

# ── État / Animation ─────────────────────────────────────────────
func set_state(new_state: String) -> void:
	if state == new_state:
		return
	state = new_state
	if _animator:
		_animator.play(state, direction)

## Raccourci : joue directement une animation sur toutes les couches visibles.
func play_anim(anim: String, dir: String = "") -> void:
	if _animator:
		_animator.play(anim, dir if dir != "" else direction)

## À surcharger dans les classes enfants pour réagir aux transitions d'état.
func _on_hurt() -> void:
	set_state(STATE_HURT)

func _on_die() -> void:
	set_state(STATE_DIE)

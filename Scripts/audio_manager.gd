extends Node

@onready var players = []
const NB_PLAYERS = 8

func _ready():
	for i in NB_PLAYERS:
		var ap = AudioStreamPlayer.new()
		add_child(ap)
		players.append(ap)

func jouer(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0):
	# Trouve un player libre
	for ap in players:
		if not ap.playing:
			ap.stream = stream
			ap.volume_db = volume_db
			ap.pitch_scale = pitch_scale
			ap.play()
			return

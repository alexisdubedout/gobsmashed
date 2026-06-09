extends Node

var music: AudioStreamPlayer

func _ready():
	music = AudioStreamPlayer.new()
	music.stream = preload("res://assets/sounds/music_bg.wav")
	music.volume_db = -10.0
	music.autoplay = true
	add_child(music)
	music.finished.connect(_on_music_finished)

func _on_music_finished():
	music.play()

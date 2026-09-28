extends Node
## 開発用：ミニコートを単体で動かして、ゴールが正しい向きに入るか調べる
## （ゴールの瞬間に、得点した側の選手がボールを蹴っているか・相手ゴールに向かっているか）

const MiniCourt = preload("res://scripts/ui/MiniCourt.gd")


func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH))
	Game.load_game()
	var bad := 0
	var total := 0
	var held_ok := 0
	var far := 0
	for n in 30:
		var mine := Game.formation_entries()
		var opp := Game.lineup(1 + n % 5)
		var res := Game.simulate(mine, opp)
		var court = MiniCourt.new()
		court.size = Vector2(340, 150)
		add_child(court)
		court.setup(mine, opp)
		court.set_plan(res.events)
		var events: Array = res.events.duplicate()
		var minute := 0.0
		var dt := 1.0 / 60.0
		while minute < 95.0:
			minute += dt * 90.0 / 12.0
			court.tick(minute)
			while not events.is_empty() and events[0].min <= minute:
				var e: Dictionary = events.pop_front()
				match e.get("kind", ""):
					"goal":
						total += 1
						# シュート直前にボールを持っていたのが得点側か
						if court.holder.x == e.team:
							held_ok += 1
						court.goal(e.team)
						# シュートの向きが得点側の攻めるゴールか
						var dir: float = court.flight.target.x - court.ball.x
						if (e.team == 0 and dir < 0) or (e.team == 1 and dir > 0):
							bad += 1
					"cancel": court.save_shot(e.team)
					"steal", "chance": court.steal(e.team)
			court._process(dt)
		far += court.far_shots
		court.queue_free()
	print("goals=%d  wrong direction=%d  scorer side had the ball=%d  shot from own half=%d" % [total, bad, held_ok, far])
	get_tree().quit()

extends SceneTree
## اختبار تشغيل آلي: يحمّل المشهد الرئيسي، يبدأ المهمة الأولى،
## ويشغّل عدداً من الإطارات للتأكد من عدم وجود أخطاء وقت التشغيل.

func _initialize() -> void:
	_run()


func _run() -> void:
	var scene_resource = load("res://scenes/main/main.tscn")

	if scene_resource == null:
		push_error("SMOKE: تعذر تحميل المشهد الرئيسي.")
		quit(1)
		return

	var main = scene_resource.instantiate()
	root.add_child(main)

	for _index in 5:
		await process_frame

	main._start_mission(0)

	for _index in 240:
		await process_frame

	var ok := main.player != null and main.world != null
	var alive: int = main.mission_manager.enemies_alive
	var spawned: int = main.world.get_child_count()

	if not ok:
		push_error("SMOKE: اللاعب أو العالم لم يُنشأ.")
		quit(1)
		return

	if spawned < 3:
		push_error("SMOKE: لم تُنشأ عناصر الخريطة.")
		quit(1)
		return

	print("SMOKE OK | enemies_alive=%d | nodes=%d | health=%.0f" % [
		alive, spawned, main.player.health
	])
	quit(0)

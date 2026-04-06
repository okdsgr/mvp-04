@tool
extends EditorScript

## Claude が MCP 経由で呼ぶ git 同期ユーティリティ
## 使い方: execute_editor_script で action を変えて呼ぶ
## action: "push" / "pull" / "status"

const ACTION = "push"  # ← Claude が書き換えて使う

func _run() -> void:
	var path = ProjectSettings.globalize_path("res://")
	var out := []

	match ACTION:
		"push":
			OS.execute("git", ["-C", path, "add", "-A"], out, true)
			out.clear()
			OS.execute("git", ["-C", path, "commit", "-m", "sync: %s" % Time.get_datetime_string_from_system()], out, true)
			out.clear()
			var ret = OS.execute("git", ["-C", path, "push"], out, true)
			print("[git_sync] push exit: ", ret, " | ", out)
		"pull":
			var ret = OS.execute("git", ["-C", path, "pull"], out, true)
			print("[git_sync] pull exit: ", ret, " | ", out)
		"status":
			OS.execute("git", ["-C", path, "status", "--short"], out, true)
			print("[git_sync] status: ", out)

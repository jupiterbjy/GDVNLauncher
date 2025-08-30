class_name ActiveProcesses
## Fetches active processes


# --- Attributes ---

## (cmd_path, [params...])
static var _PROC_LIST_CMD: Array = {
	"Windows": [
		"powershell", [
			"-NoProfile",
			"-Command",
			'"Get-Process | Select-Object -ExpandProperty Path"',
		],
		#"tasklist", [
			#"/FO",
			#"CSV",
		#],
	],
	"Linux": [
		"ps",
		"-u $(whoami) -o pid= | xargs -I {} readlink /proc/{}/exe".split(" "),
	],
}[OS.get_name()]
# can't go const, https://github.com/godotengine/godot/issues/67873

var process

# --- Methods ---

## Poll unique process pathes, returns Dict as hashmap(ignores value).
static func poll() -> PackedStringArray:
	var output: Array
	OS.execute(_PROC_LIST_CMD[0], _PROC_LIST_CMD[1], output)

	return (output[0] as String).split("\n")


## Poll unique process pathes, returns Dict as hashmap(ignores value).
static func poll_unique() -> Dictionary[String, int]:
	var output: Array
	OS.execute(_PROC_LIST_CMD[0], _PROC_LIST_CMD[1], output)

	var _set: Dictionary[String, int]
	for proc in (output[0] as String).split("\n"):
		_set[proc] = 0

	return _set

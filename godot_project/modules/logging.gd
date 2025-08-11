class_name Logging extends Node
## Colorful (World) Logger
##
## Example usage: `static _LOGGER := Logging.get_logger("SomeName")`
##
## Recommended one static logger per script - reusing is supported tho (and untested).
##
## Since there's no file logging just pipe it to file (`bla >> log.txt`).
##
## :Author: jupiterbjy@gmail.com


# --- Classes ---

## Logger base Used for log suppression
@abstract class _BaseLogger:
	var _name: String

	func _init(logged_name: String) -> void:
		self._name = logged_name

	func debug(_msg: Variant) -> void:
		pass

	func info(_msg: Variant) -> void:
		pass

	func warn(_msg: Variant) -> void:
		pass

	func error(_msg: Variant) -> void:
		pass


## Debug logger with expensive rich output for debug and warning.
class DebugLogger extends _BaseLogger:

	func _print_colored(msg: Variant, color: String = "white") -> void:
		print_rich(
			"%s [color=%s][%s] %s[/color]" % [
				Time.get_time_string_from_system(), color, self._name, msg
			]
		)

	func debug(msg: Variant) -> void:
		self._print_colored(msg, "cyan")

	func info(msg: Variant) -> void:
		self._print_colored(msg, "white")

	func warn(msg: Variant) -> void:
		self._print_colored(msg, "yellow")
		push_warning("[%s] %s" % [self._name, msg])

	func error(msg: Variant) -> void:
		self._print_colored(msg, "crimson")
		push_error("[%s] %s" % [self._name, msg])


## Release Logger with log level of info.
class ReleaseLogger extends _BaseLogger:

	func _print(msg: Variant) -> void:
		print("%s [%s] %s" % [Time.get_time_string_from_system(), self._name, msg])

	func info(msg: Variant) -> void:
		self._print(msg)

	func warn(msg: Variant) -> void:
		self._print(msg)
		push_warning(msg)

	func error(msg: Variant) -> void:
		self._print(msg)
		push_error(msg)


# --- Attritbutes ---

## Change to false to use release logger
static var IS_DEBUG := true


## Created Loggers. Dict[String, _BaseLogger]
static var _LOGGERS: Dictionary[StringName, _BaseLogger] = {}


# --- Methods ---

## Debugger fetcher. If same named logger exists, pulls it.
static func get_logger(logger_name: StringName) -> _BaseLogger:

	# create new if missing
	if logger_name not in _LOGGERS:
		_LOGGERS[logger_name] = (
			(DebugLogger.new(logger_name) as _BaseLogger)
			if IS_DEBUG else (ReleaseLogger.new(logger_name) as _BaseLogger)
		)

	return _LOGGERS[logger_name]

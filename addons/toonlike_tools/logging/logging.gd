@icon("res://addons/toonlike_tools/logging/GuiTabMenu.png")
extends Node
## Global logging with debug/info/warning/error log types
## Instantiates a global logger instance that tracks this

enum LogLevel { DEBUG, INFO, WARNING, ERROR }

const LogLevelString: Dictionary = {
	LogLevel.DEBUG: 'Debug',
	LogLevel.INFO: 'Info',
	LogLevel.WARNING: 'Warning',
	LogLevel.ERROR: 'Error',
}

const LogLevelColor: Dictionary[Logging.LogLevel, Color] = {
	LogLevel.DEBUG: 'eeeeee',
	LogLevel.INFO: 'eeeeee',
	LogLevel.WARNING: 'ffff00',
	LogLevel.ERROR: 'ff0000',
}

const ObjectNameColor := 'ddddff'

const GlobalLogLevel := LogLevel.INFO

var _obj_logging_level: Dictionary = {}
var global_logger := Logger.new(self, LogLevel.DEBUG, false, false)


## Is the given log level good to go on the Global Logger?
func is_loggable(obj: Variant, level: LogLevel) -> bool:
	if obj in _obj_logging_level.keys():
		return level >= _obj_logging_level[obj]
	return level >= GlobalLogLevel

## Includes class and log level in the message name if wanted
func _get_full_message(obj: Variant, message: String, level: LogLevel) -> String:
	var message_base: String = ""
	message_base += "[color=%s][i]%s[/i][/color]" % [ObjectNameColor, ToonUtils.get_object_name(obj)]
	message_base += "[color=%s][i](%s)[/i][/color]: " % [LogLevelColor[level], LogLevelString[level]]
	return message_base + message

## Set the minimum logging level for a given object for the global logger
func set_level(obj: Variant, level: LogLevel) -> void:
	_obj_logging_level[obj] = level

## Log a debug message if our log level allows
func debug(obj: Variant, message: String) -> void:
	if is_loggable(obj, LogLevel.DEBUG):
		global_logger.debug(_get_full_message(obj, message, LogLevel.DEBUG))

## Log an info message if our log level allows
func info(obj: Variant, message: String) -> void:
	if is_loggable(obj, Logging.LogLevel.INFO):
		global_logger.info(_get_full_message(obj, message, LogLevel.INFO))

## Log a warning message if our log level allows
func warning(obj: Variant, message: String) -> void:
	if is_loggable(obj, Logging.LogLevel.WARNING):
		global_logger.warning(_get_full_message(obj, message, LogLevel.WARNING))

## Log an error message (and crash)
func error(obj: Variant, message: String) -> void:
	if is_loggable(obj, Logging.LogLevel.ERROR):
		assert(false, _get_full_message(obj, message, LogLevel.ERROR))

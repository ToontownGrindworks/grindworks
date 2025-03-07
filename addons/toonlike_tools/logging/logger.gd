extends RefCounted
class_name Logger
## A logger instance that is tied to an object and will log debug messages from it.

var owner_obj: Variant
var log_level := Logging.GlobalLogLevel
var include_class: bool = true
var include_level: bool = true


func _init(p_owner_obj: Variant, p_log_level := Logging.GlobalLogLevel, p_include_class: bool = true, p_include_level: bool = true) -> void:
	owner_obj = p_owner_obj
	log_level = p_log_level
	include_class = p_include_class
	include_level = p_include_level

## Need this unfortunately til the .new() autocomplete bug is fixed
static func make(p_owner_obj: Variant, p_log_level := Logging.GlobalLogLevel, p_include_class: bool = true, p_include_level: bool = true) -> Logger:
	return Logger.new(p_owner_obj, p_log_level, p_include_class, p_include_level)

## Is the given log level good to go on this Logger?
func is_loggable(level: Logging.LogLevel) -> bool:
	return level >= log_level

## Includes class and log level in the message name if wanted
func _get_full_message(message: String, level: Logging.LogLevel) -> String:
	var message_base: String = ""
	if include_class:
		message_base += "[color=%s][i]%s[/i][/color]" % [Logging.ObjectNameColor, ToonUtils.get_object_name(owner_obj)]
	if include_level:
		message_base += "[color=%s][i](%s)[/i][/color]" % [Logging.LogLevelColor[level], Logging.LogLevelString[level]]
	if include_class or include_level:
		message_base += ": "
	return message_base + message

## Log a debug message if our log level allows
func debug(message: String) -> void:
	if is_loggable(Logging.LogLevel.DEBUG):
		print_rich(_get_full_message(message, Logging.LogLevel.DEBUG))

## Log an info message if our log level allows
func info(message: String) -> void:
	if is_loggable(Logging.LogLevel.INFO):
		print_rich(_get_full_message(message, Logging.LogLevel.INFO))

## Log a warning message if our log level allows
func warning(message: String) -> void:
	if is_loggable(Logging.LogLevel.WARNING):
		print_rich(_get_full_message(message, Logging.LogLevel.WARNING))

## Log an error message (and crash)
func error(message: String) -> void:
	if is_loggable(Logging.LogLevel.ERROR):
		print_rich(_get_full_message(message, Logging.LogLevel.WARNING))

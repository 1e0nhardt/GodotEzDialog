@tool
extends Node

const MESSAGE_LENGTH = 130

enum LogLevel {
    DEBUG,
    INFO,
    WARN,
    ERROR,
    FATAL,
}

var CURRENT_LOG_LEVEL = LogLevel.DEBUG
var disabled = false
var write_logs: bool = false
var log_path: String = "res://game.log"
var _file
# var text_color_str = "\\033[38;2;r;g;bmYourText\\033[0m"

func _ready():
    # set_loglevel("info")
    pass


func set_loglevel(level: String):
    info("setting log level", {"level": level})
    match level.to_lower():
        "debug":
            CURRENT_LOG_LEVEL = LogLevel.DEBUG
        "info":
            CURRENT_LOG_LEVEL = LogLevel.INFO
        "warn":
            CURRENT_LOG_LEVEL = LogLevel.WARN
        "error":
            CURRENT_LOG_LEVEL = LogLevel.ERROR
        "fatal":
            CURRENT_LOG_LEVEL = LogLevel.FATAL


func _get_color_str(log_level=LogLevel.INFO):
    match log_level:
        LogLevel.DEBUG:
            return "green"
        LogLevel.INFO:
            return "cyan"
        LogLevel.WARN:
            return "yellow"
        LogLevel.ERROR:
            return "red"
        LogLevel.FATAL:
            return "red"
        _:
            return "gray"


func logger(message: String, values, log_level=LogLevel.INFO, node_name=""):
    if disabled:
        return

    if CURRENT_LOG_LEVEL > log_level:
        return

    var postfix = ""
    if Engine.is_editor_hint():
        postfix = ""
    else:
        var stack_array = get_stack()
        var desired_stack_index = 2 if stack_array.size() >= 2 else 1
        if node_name != "":
            node_name += ":"
        postfix = "%s%s:%d" % [node_name, stack_array[desired_stack_index]["source"].split("/")[-1], stack_array[desired_stack_index]["line"]]

    var color_str = _get_color_str(log_level)
    var log_msg_format = "[color=orange][{time}][/color] [color=%s][b]{level}[/b][/color]    {message} [color=white]{postfix}[/color]" % color_str
    var log_file_format = "[{time}] {level}    {message} {postfix}"
    var now = Time.get_datetime_dict_from_system(false)
    var values_str = ""

    match typeof(values):
        TYPE_ARRAY:
            if values.size() > 0:
                values_str += "["
                for k in values:
                    values_str += "{k}, ".format({"k": JSON.stringify(k)})
                values_str = values_str.left(-2)+"]"
        TYPE_DICTIONARY:
            if values.size() > 0:
                values_str += "{"
                for k in values:
                    if typeof(values[k]) == TYPE_OBJECT && values[k] != null:
                        values_str += '"{k}": {v}, '.format({"k": k, "v": values[k]})
                    else:
                        values_str += '"{k}": {v}, '.format({"k": k, "v": JSON.stringify(values[k])})
                values_str = values_str.left(-2)+"}"
        TYPE_NIL:
            values_str += JSON.stringify(null)
        _:
            values_str += str(values)

    if values_str != "":
        values_str = ": " + values_str

    var msg = ""
    if write_logs:
        msg = log_file_format.format(
            {
                "postfix": "%s" % postfix,
                "message": "%-*s" % [MESSAGE_LENGTH - postfix.length(), (message + values_str)],
                "time": "{0}:{1}:{2}".format({
                                0: "%02d" % now["hour"],
                                1: "%02d" % now["minute"],
                                2: "%02d" % now["second"],
                            }),
                "level": "%-5s" % LogLevel.keys()[log_level],
            })
        _write_logs(msg)

    msg = log_msg_format.format(
        {
            "postfix": "%s" % postfix,
            # 如果*对应的数大于行宽，会在第二行也有占位，如果内容长度较小，则会将最后一个空白符后的内容移到下一行。
            # 如果有实例内容较短，但数组，字典的最后一个值出现在第二行的情况，将MESSAGE_LENGTH设小一点，或增加输出栏宽度。
            "message": "%-*s" % [MESSAGE_LENGTH - postfix.length(), (message + values_str)],
            "time": "{0}:{1}:{2}".format({
                                0: "%02d" % now["hour"],
                                1: "%02d" % now["minute"],
                                2: "%02d" % now["second"],
                            }),
            "level": LogLevel.keys()[log_level],
        })

    if OS.get_main_thread_id() != OS.get_thread_caller_id() and log_level == LogLevel.DEBUG:
        print("[%d]Cannot retrieve debug info outside the main thread:\n\t%s" % [OS.get_thread_caller_id(),msg])
        return

    match log_level:
        LogLevel.DEBUG:
            print_rich(msg)
        LogLevel.INFO:
            print_rich(msg)
        LogLevel.WARN:
            print_rich(msg)
        LogLevel.ERROR:
            push_error(msg)
            printerr(msg)
            print_stack()
            print_tree()
        LogLevel.FATAL:
            push_error(msg)
            printerr(msg)
            print_stack()
            print_tree()
            get_tree().quit()
        _:
            print(msg)


func debug(message: String, values={}, node_name=""):
    call_thread_safe("logger",message,values,LogLevel.DEBUG, node_name)


func info(message: String, values={}, node_name=""):
    call_thread_safe("logger",message,values, LogLevel.INFO, node_name)


func warn(message: String, values={}, node_name=""):
    call_thread_safe("logger",message,values,LogLevel.WARN, node_name)


func error(message: String, values={}, node_name=""):
    call_thread_safe("logger",message,values,LogLevel.ERROR, node_name)


func fatal(message: String, values={}, node_name=""):
    call_thread_safe("logger",message,values,LogLevel.FATAL, node_name)


func _write_logs(message:String):
    if _file == null:
        _file = FileAccess.open(log_path,FileAccess.WRITE)
    _file.store_line(message)
    pass

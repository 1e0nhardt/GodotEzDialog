class_name DialogResponse
extends RefCounted

var text: String = ""
var choices: Array[String] = []
var eod_reached: bool = false
var should_pause: bool = false

func append_text(_text: String):
    if (!text.is_empty()):
        text += "\n" + _text
    else:
        text += _text

func append_choice(_choice: String):
    choices.push_back(_choice)
        
func is_empty():
    return text.length() == 0 && choices.size() == 0

func _to_string():
    return "PAUSED:%s, EOD_REACHED:%s, %s--%s" % [should_pause, eod_reached, text, choices]
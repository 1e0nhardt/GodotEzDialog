@tool
class_name Token 
extends RefCounted

enum Type {
    TEXT,
    PAGE_BREAK,
    IF,
    ELIF,
    ELSE,
    ENDIF,
    COLON,
    GOTO,
    PROMPT,
    SIGNAL,
    SIGNAL_END,
    EOF
}

var lineno: int
var column: int
var value: String
var type: Type


func _init(t: Type, v: String, l: int, c: int):
    type = t
    value = v
    lineno = l
    column = c


func _to_string():
    return "%s: %s" %[Type.keys()[type], value]
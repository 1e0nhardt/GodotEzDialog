@tool
class_name DialogCommand
extends RefCounted

var lineno: int = 0
var column: int = 0
var type: Type = Type.EOF
var values: Array = []
var children: Array[DialogCommand] = []

enum Type {
    EOF, #0
    DISPLAY_TEXT, #1
    PAGE_BREAK, #2
    PROMPT, #3
    GOTO, #4
    IF, #5
    ROOT, #6
    SIGNAL, #7
    ELSE, #8
	ELIF, #9
    COLON, #10
}

func _init(_line: int= 0,
    _pos: int = 0,
    _type: Type = Type.EOF,
    _values = [],
    _children: Array[DialogCommand] = []):
    lineno = _line
    column = _pos
    type = _type
    values = _values
    children = _children


func _to_string() -> String:
    #return "%s:%s" % [Type.keys()[type], children]
    if children.is_empty() and values.is_empty():
        return Type.keys()[type]
    if children.is_empty():
        return "%s:%s" % [Type.keys()[type], values]
    if values.is_empty():
        return "%s:%s" % [Type.keys()[type], children]
    return "%s:%s-%s" % [Type.keys()[type], values, children]
    # return "%d:%d-%s-(%s)-(%s)" % [lineno, column, Type.keys()[type], ",".join(values), children]

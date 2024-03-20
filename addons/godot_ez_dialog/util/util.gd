@tool
extends Node

enum MethodType {
    SET,
    ADD,
    MINUS,
    MUL
}

var BUILT_IN_METHOD_IN_SIGNAL : Array= ["set", "add", "minus", "mul"]


func load_json_file(filepath: String):
    if FileAccess.file_exists(filepath):
        var json_string = FileAccess.get_file_as_string(filepath)
        var json = JSON.new()
        var error = json.parse(json_string)
        if error == OK:
            return json.data
        else:
            Logger.error("JSON Parse Error: " + json.get_error_message() + " in " + json_string + " at line " + json.get_error_line())
    else:
        Logger.error("File not exists: %s" % filepath)


func create_style_box_flat(color: Color, corner_radius=2) -> StyleBoxFlat:
    var style_box_flat = StyleBoxFlat.new()
    style_box_flat.bg_color = color
    style_box_flat.corner_radius_top_left = corner_radius
    style_box_flat.corner_radius_top_right = corner_radius
    style_box_flat.corner_radius_bottom_left = corner_radius
    style_box_flat.corner_radius_bottom_right = corner_radius
    return style_box_flat
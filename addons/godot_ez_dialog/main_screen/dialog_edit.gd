@tool
extends CodeEdit

const highlight_and_snippet_file = "res://addons/godot_ez_dialog/highlight_and_snippets.json"

var highlight_dict
var snippets_dict

var inject_color = Color("d22d72", 1.0)
var goto_color = Color("2d8f6f", 1.0)
var signal_color = Color("d22d72", 1.0)
var number_color = Color("568c3b", 1.0)
var symbol_color = Color("6b6bb8", 1.0)


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


func _ready():
    var json_dict = load_json_file(highlight_and_snippet_file)
    highlight_dict = json_dict.get("highlight", {})
    snippets_dict = json_dict.get("snippets", {})

    # 关键词高亮
    for color_string in highlight_dict:
        for keyword in highlight_dict[color_string]:
            syntax_highlighter.add_keyword_color(keyword, Color(color_string, 1.0))

    # ${}, ->, signal(...)
    syntax_highlighter.add_color_region("${", "}", inject_color)
    syntax_highlighter.add_color_region("->", "", goto_color)
    syntax_highlighter.add_color_region("(", ")", signal_color)

    syntax_highlighter.number_color = number_color
    syntax_highlighter.symbol_color = symbol_color

    # 右键菜单
    var menu = get_menu()
    # Remove all items after "Redo".
    menu.item_count = menu.get_item_index(MENU_REDO) + 1
    # Add custom items.
    # menu.add_separator()
    # menu.add_item("Save", MENU_MAX + 1, KEY_MASK_CTRL | KEY_S)
    # # Connect callback.
    # menu.id_pressed.connect(
    #     func(id):
    #         if id == MENU_MAX + 1:
    #             save_requested.emit()
    #             Logger.debug("Saving")
    # )


func get_current_word():
    var current_line := get_line(get_caret_line())
    if current_line.ends_with(" "):
        return " "
    return current_line.substr(0, get_caret_column()).split(" ")[-1].split("(")[-1]


func update_current_completion_options(word: String):
    # Logger.debug("current word", word)
    if word == "" or word == " ":
        update_code_completion_options(false)
        return

    for key in snippets_dict["keywords"]:
        if key.matchn(word + "*"):
            add_code_completion_option(CodeCompletionKind.KIND_PLAIN_TEXT, key, key, Color.GRAY)

    for key in snippets_dict["snippets"]:
        if key.matchn(word + "*"):
            add_code_completion_option(CodeCompletionKind.KIND_FUNCTION, key + "□", snippets_dict["snippets"][key], Color.GRAY)

    update_code_completion_options(true)


func _on_text_changed():
    update_current_completion_options(get_current_word())

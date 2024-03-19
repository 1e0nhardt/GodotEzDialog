extends VBoxContainer

@export var dialog_json: JSON

@onready var dialog_reader: DialogReader = %DialogReader

var state = {
    "foo": "bar",
    "success": true,
    "apple_count": 0,
    "smell_count": 0,
    "barbell_count": 0,
    "light_on": true,
    "has_flower": false,
    "show_letter": false,
    "shark_has_flower": false,
    "sleep_count": 0,
    "sleep_enough": 0,
    "last_end": -1,
    "end_1": false,
    "end_2": false,
    "end_3": false,
    "end_4": false,
    "end_5": false,
    "end_6": false,
    "end_7": false,
    "end_8": false,
    "to_end_9": false,
    "end_9": false,
    "end_10": false,
    "end_11": false,
}
var custom_font = preload("res://addons/godot_ez_dialog/font/smiley-sans-v2.0.1/SmileySans-Oblique.ttf")


func _ready():
    dialog_reader.dialog_generated.connect(on_dialog_generated)
    dialog_reader.custom_signal_received.connect(on_custom_signal_received)
    dialog_reader.start_dialog(dialog_json, state, "start")


func clear_dialog():
    for child in get_children():
        if child == dialog_reader:
            continue
        child.queue_free()


func add_text(text: String):
    var label = Label.new()
    label.text = text
    label.set("theme_override_font_sizes/font_size", 28)
    label.set("theme_override_fonts/font", custom_font)
    add_child(label)


func add_choice(text: String, index: int):
    var button = Button.new()
    button.text = text
    button.set("theme_override_font_sizes/font_size", 28)
    button.set("theme_override_fonts/font", custom_font)
    add_child(button)
    button.pressed.connect(func(): dialog_reader.next(index))


func on_dialog_generated(response: DialogResponse):
    clear_dialog()
    Logger.info("Response", response)
    if response.eod_reached:
        Logger.info("Dialog Ended!")
        return

    add_text(response.text)
    if not response.choices.is_empty():
        for i in response.choices.size():
            add_choice(response.choices[i], i)
    else:
        await get_tree().create_timer(1.3).timeout
        dialog_reader.next()


func on_custom_signal_received(param_string: String):
    var params = param_string.split(",")
    if params[0].strip_edges() == "set":
        state[params[1].strip_edges()] = params[2].strip_edges()

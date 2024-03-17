extends VBoxContainer

@export var dialog_json: JSON

@onready var dialog_reader: DialogReader = %DialogReader

var state = {
    "foo": "bar",
    "success": true
}


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
    add_child(label)


func add_choice(text: String, index: int):
    var button = Button.new()
    button.text = text
    button.set("theme_override_font_sizes/font_size", 28)
    add_child(button)
    button.pressed.connect(func(): dialog_reader.next(index))


func on_dialog_generated(response: DialogResponse):
    clear_dialog()
    if response.text.is_empty():
        Logger.info("Dialog Ended!")
        return
        
    add_text(response.text)
    if not response.choices.is_empty():
        for i in response.choices.size():
            add_choice(response.choices[i], i)
    else:
        await get_tree().create_timer(2.).timeout
        dialog_reader.next()


func on_custom_signal_received(param_string: String):
    var params = param_string.split(",")
    if params[0].strip_edges() == "set":
        print(state)
        print(params[1])
        state[params[1].strip_edges()] = params[2].strip_edges()
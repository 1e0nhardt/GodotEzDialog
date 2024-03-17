@tool
class_name MainDialogPanel
extends Panel

@onready var dialog_graph_edit: DialogGraphEdit = %DialogGraphEdit
@onready var title_edit: LineEdit = %TitleEdit
@onready var content_edit: CodeEdit = %DialogEdit
@onready var save_btn: Button = %SaveBtn
@onready var working_path_label: Label = %DialogNameLabel
@onready var dirty_mark: Label = %DirtyMark

var dialog_resource: DialogResource
var last_parse_updated_time := 0.0
var config := {
    "PARSE_UPDATE_WAIT_TIME_IN_MS": 1000
}

var working_path = "":
    set(value):
        working_path = value
        if value == "":
            working_path_label.text = "[untitled]"
        else:
            working_path_label.text = value

var is_dirty = false:
    set(value):
        is_dirty = value
        dirty_mark.visible = value
        save_btn.disabled = !value


func _ready():
    dialog_resource = DialogResource.new()
    dialog_graph_edit.set_dialog_graph(dialog_resource)
    is_dirty = false


func _process(delta):
    var time_since_last_update = Time.get_ticks_msec() - last_parse_updated_time
    if time_since_last_update > config["PARSE_UPDATE_WAIT_TIME_IN_MS"]:
        update_parse()
        last_parse_updated_time = Time.get_ticks_msec()


func save():
    if !is_dirty:
        return

    update_parse()
    if working_path.is_empty():
        $SaveFileDialog.popup()
    else:
        var save_file = FileAccess.open(working_path, FileAccess.WRITE)
        save_file.store_string(dialog_resource.serialize())
        is_dirty = false


func reset():
    working_path = ""
    dialog_resource.reset()
    dialog_graph_edit.redraw_dialog_graph()
    _populate_editor_from_selected_node()
    is_dirty = false


func add_node(node_name = "Dialog Node"):
    var dialog_node = DialogNode.new()
    dialog_node.name = dialog_resource.validate_name(node_name)
    dialog_resource.add_dialog_node(dialog_node)
    dialog_graph_edit.add_graph_node(dialog_node, true)


func update_parse():
    var selected_dn = dialog_graph_edit.selected_dialog_node
    if not selected_dn:
        return

    var editing_node = dialog_graph_edit.selected_nodes[0]
    selected_dn.clear_parse()
    selected_dn.get_parse()

    var old_outputs = editing_node.get_meta("output_connections")
    var new_outputs = selected_dn.get_destination_nodes()
    Logger.debug("GOTO", new_outputs)
    editing_node.set_meta("output_connections", new_outputs)

    #TODO 环?
    if editing_node.get_meta("input_connections").has(editing_node.name) and not new_outputs.has(editing_node.name):
        editing_node.get_meta("input_connections").erase(editing_node.name)

    for node_name in new_outputs:
        # 尚未添加的目标节点
        if not dialog_graph_edit.has_node(node_name):
            continue
        var gnode = dialog_graph_edit.get_node(node_name)
        var gnode_input_connections = gnode.get_meta("input_connections")
        if not gnode_input_connections.has(editing_node.name):
            gnode_input_connections.append(editing_node.name)

    dialog_graph_edit.process_node_outgoing_connections(selected_dn)


func _populate_editor_from_selected_node():
    var dialog_node := dialog_graph_edit.selected_dialog_node
    if dialog_node:
        title_edit.text = dialog_node.name
        content_edit.text = dialog_node.commands_raw
    title_edit.visible = (dialog_node != null)
    content_edit.visible = (dialog_node != null)


func _delete_node_by_name(node_name: String):
    var graph_node = dialog_graph_edit.get_node("%s" % node_name)
    dialog_resource.delete_dialog_node_by_name(graph_node.name)
    dialog_graph_edit.remove_node(graph_node)


#region TopBar Buttons
func _on_add_pressed():
    add_node()

func _on_delete_pressed():
    for node in dialog_graph_edit.selected_nodes:
        _delete_node_by_name(node.name)
    _populate_editor_from_selected_node()

func _on_new_btn_pressed():
    save()
    reset()

func _on_save_btn_pressed():
    save()

func _on_open_btn_pressed():
    $OpenFileDialog.popup()


func _on_save_file_dialog_file_selected(path):
    working_path = path
    var save_file = FileAccess.open(working_path, FileAccess.WRITE)
    save_file.store_string(dialog_resource.serialize())
    is_dirty = false


func _on_open_file_dialog_file_selected(path):
    # Load DialogResource
    var file = FileAccess.open(path, FileAccess.READ)
    var content = file.get_as_text()
    dialog_resource.reset()
    dialog_resource.loadFromText(content)
    dialog_graph_edit.redraw_dialog_graph()

    _populate_editor_from_selected_node()

    is_dirty = false
    working_path = path
#endregion

#region Dialog Graph Signals
func _on_dialog_graph_edit_node_selected(node: Node):
    Logger.debug("Selected Node: %s" % node.name)
    Logger.debug("Selected Node In", node.get_meta("input_connections"))
    Logger.debug("Selected Node Out", node.get_meta("output_connections"))
    dialog_graph_edit.select_node(node)
    _populate_editor_from_selected_node()


func _on_dialog_graph_edit_node_deselected(node: Node):
    Logger.debug("Deselected Node: %s" % node.name)
    dialog_graph_edit.deselect_node(node)
    _populate_editor_from_selected_node()


func _on_dialog_graph_edit_end_node_move():
    for node in dialog_graph_edit.selected_nodes:
        Logger.debug("%s position_offset" % node.name, node.position_offset)
        dialog_resource.get_node_by_name(node.name).position = node.position_offset

    is_dirty = true


func _on_dialog_graph_edit_delete_nodes_request(nodes: Array[StringName]):
    for node_name in nodes:
        Logger.debug("Delete Node Name", node_name)
        _delete_node_by_name(node_name)
    _populate_editor_from_selected_node()
#endregion

#region Text Edit Signals
func _on_title_edit_text_submitted(new_text):
    var valid_name = dialog_resource.validate_name(new_text)
    dialog_graph_edit.update_selected_node(valid_name)
    if new_text != valid_name:
        push_warning("Name [%s] existing, change to [%s]." % [new_text, valid_name])
        title_edit.text = valid_name


func _on_dialog_edit_code_completion_requested():
    pass # Replace with function body.


func _on_dialog_edit_text_changed():
    if content_edit.has_focus():
        is_dirty = true
        dialog_graph_edit.selected_dialog_node.commands_raw = content_edit.text
#endregion

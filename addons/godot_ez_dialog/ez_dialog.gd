@tool
extends EditorPlugin

const MainPanel = preload("res://addons/godot_ez_dialog/main_screen/main.tscn")
const PLUGIN_NAME = "EzDialog"
const DIALOGUE_NODE_NAME = "EzDialogReader"
const ICON = preload("icon.svg")
const AUTOLOAD_LOGGER = "Logger"
const AUTOLOAD_UTIL = "Util"

var main_panel_instance: MainDialogPanel


func _enter_tree():
    add_custom_type(DIALOGUE_NODE_NAME, "Node", preload("dialog_reader.gd"), ICON)
    add_autoload_singleton(AUTOLOAD_LOGGER, "res://addons/godot_ez_dialog/util/logger.gd")
    add_autoload_singleton(AUTOLOAD_UTIL, "res://addons/godot_ez_dialog/util/util.gd")

    main_panel_instance = MainPanel.instantiate()

    # Add the main panel to the editor's main viewport.
    EditorInterface.get_editor_main_screen().add_child(main_panel_instance)

    # Hide the main panel
    _make_visible(false)


func _exit_tree():
    remove_custom_type(DIALOGUE_NODE_NAME)
    remove_autoload_singleton(AUTOLOAD_LOGGER)
    remove_autoload_singleton(AUTOLOAD_UTIL)
    if main_panel_instance:
        main_panel_instance.queue_free()


func _ready():
    pass


func _has_main_screen():
    return true


func _make_visible(visible):
    if main_panel_instance:
        main_panel_instance.visible = visible


func _get_plugin_name():
    return PLUGIN_NAME


func _get_plugin_icon():
    return ICON


func _save_external_data():
    main_panel_instance.save()

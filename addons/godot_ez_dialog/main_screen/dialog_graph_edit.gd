@tool
class_name DialogGraphEdit
extends GraphEdit

var dialog_resource: DialogResource
var selected_nodes: Array[GraphNode] = []
var selected_dialog_node: DialogNode = null:
    get:
        if dialog_resource and selected_nodes.size() == 1:
            return dialog_resource.get_node_by_name(selected_nodes[0].name)
        else:
            return null

var in_style_box: StyleBoxFlat
var out_style_box: StyleBoxFlat
var default_style_box: StyleBoxFlat
var selected_style_box: StyleBoxFlat


func _ready():
    set("theme_override_colors/activity", Color.GREEN)
    in_style_box = Util.create_style_box_flat(Color("2e5c99"))
    out_style_box = Util.create_style_box_flat(Color("2e9967"))
    default_style_box = Util.create_style_box_flat(Color("464646"))
    selected_style_box = Util.create_style_box_flat(Color("b35d36"))


func set_dialog_graph(dg: DialogResource):
    dialog_resource = dg


func redraw_dialog_graph():
    clear_selection()

    # clear graph
    clear_connections()
    for childNode in get_children():
        remove_child(childNode)
        childNode.queue_free()

    # redraw graph
    # 添加所有节点
    for dialog_node in dialog_resource.dialog_nodes:
        add_graph_node(dialog_node, false, dialog_node.position)

    # 添加outgoing_connection
    for dialog_node in dialog_resource.dialog_nodes:
        process_node_outgoing_connections(dialog_node)

    # 设置input_connections
    for dialog_node in dialog_resource.dialog_nodes:
        var gn = get_node(dialog_node.name)
        var output_connections = gn.get_meta("output_connections")
        for node_name in output_connections:
            # 尚未添加的目标节点
            if not has_node(node_name):
                continue
            var gnode = get_node(node_name)
            var gnode_input_connections = gnode.get_meta("input_connections")
            if not gnode_input_connections.has(gn.name):
                gnode_input_connections.append(str(gn.name)) # gn.name 是StringName类型

    Logger.info("Redraw Dialog Grpah End!")

func add_graph_node(dialog_node: DialogNode, focus = false, position = null):
    var graph_node = GraphNode.new()
    graph_node.set_meta("input_connections", [])
    graph_node.set_meta("output_connections", dialog_node.get_destination_nodes())
    graph_node.title = dialog_node.name
    graph_node.name = dialog_node.name
    add_child(graph_node)

     # 向节点中添加组件。每增加一个组件可以使用的slot就多一个。
    var place_holder = Container.new()
    place_holder.custom_minimum_size.y = 10
    graph_node.add_child(place_holder)

    # 手动启用slot的两个port
    graph_node.set_slot_enabled_left(0, true)
    graph_node.set_slot_enabled_right(0, true)
    # graph_node.set_slot(1, true, 0, Color.RED, false, 0, Color.ALICE_BLUE)

    if position:
        graph_node.position_offset = position
    else:
        # 设置节点位置 (+scroll_offset相当于以视口左上角为锚点定位)
        graph_node.position_offset = scroll_offset + size*0.5 + Vector2(20, 20)

    reconnect_valid_connection(graph_node.name)

    # 设置单一节点被选中
    if focus:
        set_selected(null)
    graph_node.selected = focus

    # theme
    # graph_node.set("theme_override_styles/panel", preload("res://play/test_graph_edit.tres"))
    # graph_node.set("theme_override_styles/panel_selected", preload("res://play/test_graph_edit.tres"))
    graph_node.set("theme_override_styles/titlebar", default_style_box)
    graph_node.set("theme_override_styles/titlebar_selected", selected_style_box)


func remove_out_going_connection(node_name: String):
    # Logger.info("%s Remove Out From" % node_name, get_connection_list())
    for connection in get_connection_list():
        if connection["from_node"] == node_name:
            # Logger.debug("Disconnect %s -> %s" % [node_name, connection["to_node"]])
            disconnect_node(node_name, 0, connection["to_node"], 0)


func remove_in_going_connection(node_name: String):
    return
    var graph_node = get_node(NodePath(node_name))
    var input_nodes = graph_node.get_meta("input_connections")
    # Logger.debug("%s Remove In From" % node_name, input_nodes)
    if len(input_nodes) > 0:
        for in_name in input_nodes:
            if not has_node(NodePath(in_name)):
                continue
            var in_node = get_node(NodePath(in_name))
            var output_nodes = in_node.get_meta("output_connections")
            output_nodes.erase(node_name)
            disconnect_node(in_name, 0, node_name, 0)


func process_node_outgoing_connections(dialog_node: DialogNode):
    remove_out_going_connection(dialog_node.name)
    for out_node in dialog_node.get_destination_nodes():
        if has_node(NodePath(out_node)):
            connect_node(dialog_node.name, 0, out_node, 0)


func color_nodes_and_connections(node: Node, amount: float, set_color: bool):
    var in_conns = node.get_meta("input_connections")
    var out_conns = node.get_meta("output_connections")

    var isb = in_style_box
    var osb = out_style_box
    if !set_color:
        isb = default_style_box
        osb = default_style_box
    
    var gnode: GraphNode
    # out_conns放前面，因为如果存在环(a->b->a)，希望a被视为入边对应的节点。
    for gname in out_conns:
        if has_node(NodePath(gname)) and gname != node.name:
            gnode = get_node(NodePath(gname)) as GraphNode
            gnode.set("theme_override_styles/titlebar", osb)
            set_connection_activity(node.name, 0, gname, 0, amount * 0.2)

    for gname in in_conns:
        if has_node(NodePath(gname)) and gname != node.name:
            gnode = get_node(NodePath(gname))
            gnode.set("theme_override_styles/titlebar", isb)
            set_connection_activity(gname, 0, node.name, 0, amount)
            

func select_node(node: Node):
    selected_nodes.push_front(node)
    color_nodes_and_connections(node, 1, true)


func deselect_node(node: Node):
    selected_nodes.erase(node)
    color_nodes_and_connections(node, 0, false)


func remove_node(node: Node):
    Logger.debug("Remove Node %s" % node.name)
    selected_nodes.erase(node)
    remove_in_going_connection(node.name)
    remove_out_going_connection(node.name)
    node.queue_free()
    # notify_property_list_changed()


func clear_selection():
    selected_nodes.clear()


func update_selected_node(new_name: String):
    # 响应文本的变化
    var graph_node = selected_nodes[0]
    var dialog_node = selected_dialog_node
    var old_name = graph_node.name
    remove_in_going_connection(old_name)
    graph_node.title = new_name
    graph_node.name = new_name
    dialog_node.name = new_name
    # 先改名，再reconnect。否则新建节点重命名时new_name节点为空
    reconnect_valid_connection(new_name)


func reconnect_valid_connection(new_name: String):
    var new_node = get_node(NodePath(new_name))
    for node in dialog_resource.dialog_nodes:
        if not has_node(NodePath(node.name)):
            continue

        var gn = get_node(NodePath(node.name))
        if gn.get_meta("output_connections").has(new_name):
            connect_node(node.name, 0, new_name, 0)
            if not new_node.get_meta("input_connections").has(node.name):
                new_node.get_meta("input_connections").append(str(node.name))


func remove_old_connections(old_name: String):
    for con in get_connection_list():
        if con["from_node"] == old_name or con["to_node"] == old_name:
            disconnect_node(con["from_node"], con["from_port"], con["to_node"], con["to_port"])

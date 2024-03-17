@tool
class_name DialogResource extends Resource

var dialog_nodes: Array[DialogNode] = []

var _name_to_node_cache = {}


func reset():
    dialog_nodes = []
    _name_to_node_cache = {}


func add_dialog_node(dialog_node: DialogNode):
    dialog_nodes.push_back(dialog_node)


func delete_dialog_node_by_name(node_name: String):
    for node in dialog_nodes:
        if node.name == node_name:
            dialog_nodes.erase(node)
            return
            

func serialize():
    var res = "["
    for i in dialog_nodes.size():
        res += dialog_nodes[i].serialize()
        if (i < dialog_nodes.size() - 1):
            res += ","
    res += "]"
    return res


func loadFromJson(serialized):
    dialog_nodes = []
    for nodeJson in serialized:
        var node = DialogNode.new()
        node.loadFromJson(nodeJson)
        dialog_nodes.push_back(node)
        

func loadFromText(serialized: String):
    loadFromJson(JSON.parse_string(serialized))


# func get_node_by_name(name: String) -> DialogNode:
#     var sanitizedQuery = name.strip_edges(true, true).to_lower()
#     if !_name_to_node_cache.has(sanitizedQuery):
#         for node in dialog_nodes:
#             var sanitizedName = node.name.strip_edges(true, true).to_lower()
#             _name_to_node_cache[sanitizedName] = node
        
#     return _name_to_node_cache[sanitizedQuery]


# @deprecated
func generate_id() -> int:
    if dialog_nodes.is_empty():
        return 0
    else:
        return dialog_nodes[-1].id + 1


func validate_name(raw_name: String) -> String:
    var repeat_count = 1
    var node_name = raw_name
    while (get_node_by_name(node_name) != null):
        node_name = raw_name + "_" + str(repeat_count)
        repeat_count += 1
    return node_name
	

func get_node_by_name(node_name: String) -> DialogNode:
    for node in dialog_nodes:
        if node.name == node_name:
            return node

    return null


# @deprecated
func get_node_by_id(node_id: int) -> DialogNode:
    for node in dialog_nodes:
        if node.id == node_id:
            return node

    return null
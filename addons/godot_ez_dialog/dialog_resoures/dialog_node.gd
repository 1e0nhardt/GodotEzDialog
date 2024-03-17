@tool
class_name DialogNode extends Resource

var name: String = ""
var commands_raw: String = ""
var position: Vector2 = Vector2(0, 0)
var _parsed: Array[DialogCommand] = []


func get_parse() -> Array[DialogCommand]:
    if _parsed.is_empty():
        _parsed = DialogParser.new(commands_raw).parse()

    return _parsed.duplicate()


func clear_parse():
    _parsed = []


# Serialize the dialog node resource in JSON format.
func serialize() -> String:
    var res = {
        # "id": id,
        "name": name,
        "commands_raw": commands_raw,
        "position": [position.x, position.y]
    }
    return JSON.stringify(res)


func loadFromJson(jsonObj):
    # id = jsonObj["id"]
    name = jsonObj["name"]
    commands_raw = jsonObj["commands_raw"]
    if jsonObj.has("position"):
        position = Vector2(jsonObj["position"][0], jsonObj["position"][1])
    # _parsed = []


# 获取当前节点脚本中的所有GOTO节点的值。
func get_destination_nodes() -> Array[String]:
    var result: Array[String] = []
    var command_sequence := get_parse()
    while  not command_sequence.is_empty():
        var command = command_sequence.pop_front()
        for child in command.children:
            command_sequence.push_front(child)

        if command.type == DialogCommand.Type.GOTO:
            if not command.values.is_empty():
                result.push_back(command.values[0])
    return result

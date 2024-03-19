extends Node

@export var test_json: JSON

func _ready():
    var tokenizer = DialogTokenizer.new(test_json.data[6]["commands_raw"])
    Logger.info("Tokens", tokenizer.get_tokens())
    var parser = DialogParser.new(test_json.data[6]["commands_raw"])
    Logger.info("Commands", parser.parse())

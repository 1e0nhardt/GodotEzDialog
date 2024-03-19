@tool
class_name DialogParser
extends RefCounted

var tokenizer: DialogTokenizer
var tokens: Array[Token]
var index: int


func _init(text: String):
    tokenizer = DialogTokenizer.new(text)
    tokens = tokenizer.get_tokens()
    index = 0


func parse() -> Array[DialogCommand]:
    var root_command := DialogCommand.new(0, 0, DialogCommand.Type.ROOT)
    while index < len(tokens):
        _parse([root_command])
    return [root_command]


func advance():
    index += 1
    if index + 1 > len(tokens):
        return


func peek_type_match(t: Token.Type):
    if index + 1 > len(tokens):
        return false
    return tokens[index + 1].type == t


func search_correct_conditional_end_index() -> int:
    var current_token
    var depth = 1
    var temp_index = index - 1
    while temp_index + 1 < len(tokens):
        temp_index += 1
        current_token = tokens[temp_index]
        if current_token.type == Token.Type.IF:
            depth += 1
        elif current_token.type == Token.Type.ENDIF:
            depth -= 1

        if depth == 0:
            break
        if depth == 1 and (current_token.type == Token.Type.ELIF
            or current_token.type == Token.Type.ELSE):
            break
    return temp_index


func _parse(root: Array[DialogCommand]):
    if index + 1 > len(tokens):
        return

    var current_token := tokens[index]
    var lineno = current_token.lineno
    var column = current_token.column
    var value = current_token.value

    match current_token.type:
        Token.Type.TEXT:
            advance()
            root[0].children.append(DialogCommand.new(lineno, column, DialogCommand.Type.DISPLAY_TEXT, [value]))
        Token.Type.PAGE_BREAK:
            advance()
            root[0].children.append(DialogCommand.new(lineno, column, DialogCommand.Type.PAGE_BREAK, [value]))
        Token.Type.IF:
            parse_conditional_body(root, current_token)
        Token.Type.ELIF:
            parse_conditional_body(root, current_token)
        Token.Type.ELSE:
            parse_conditional_body(root, current_token)
        Token.Type.GOTO:
            var cmd = DialogCommand.new(lineno, column, DialogCommand.Type.GOTO, [value])
            root[0].children.append(cmd)
            advance()
        Token.Type.PROMPT: # (- prompt text -> node) | (- prompt text -> signal()... node)
            var cmd = DialogCommand.new(lineno, column, DialogCommand.Type.PROMPT, [value])
            root[0].children.append(cmd)
            if peek_type_match(Token.Type.EOF):
                advance()
                return
            if peek_type_match(Token.Type.TEXT):
                cmd.values = [tokens[index + 1].value]
                advance()
            while peek_type_match(Token.Type.SIGNAL):
                cmd.children.append(DialogCommand.new(lineno, column, DialogCommand.Type.SIGNAL, [tokens[index + 1].value]))
                advance()
                if peek_type_match(Token.Type.SIGNAL_END):
                    advance()
            if peek_type_match(Token.Type.GOTO):
                cmd.children.append(DialogCommand.new(lineno, column, DialogCommand.Type.GOTO, [tokens[index + 1].value]))
                advance()
            advance()
        Token.Type.SIGNAL:
            var cmd = DialogCommand.new(lineno, column, DialogCommand.Type.SIGNAL, [value])
            root[0].children.append(cmd)
            if peek_type_match(Token.Type.SIGNAL_END):
                advance()
                advance()
            else:
                Logger.warn("[%s:%s] %s" % [lineno, column, "Signal should end with ')'!"])
        _:
            advance()


func parse_conditional_body(root: Array[DialogCommand], token: Token):
    var cmd_type
    match token.type:
        Token.Type.IF:
            cmd_type = DialogCommand.Type.IF
        Token.Type.ELIF:
            cmd_type = DialogCommand.Type.ELIF
        Token.Type.ELSE:
            cmd_type = DialogCommand.Type.ELSE
    var cmd = DialogCommand.new(token.lineno, token.column, cmd_type, [token.value])
    root[0].children.append(cmd)
    if peek_type_match(Token.Type.COLON):
        advance()
        advance()
        var target_index = search_correct_conditional_end_index()
        while index < target_index:
            _parse([cmd])
    else:
        advance()
        Logger.warn("[%s:%s] %s" % [token.lineno, token.column, "Missing ':' after %s" % DialogCommand.Type.keys()[cmd_type]])
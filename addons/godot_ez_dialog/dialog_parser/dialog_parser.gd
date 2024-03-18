@tool
class_name DialogParser
extends RefCounted

var tokenizer: DialogTokenizer
var tokens: Array[Token]
var index: int


func _init(text: String):
    tokenizer = DialogTokenizer.new(text)
    tokens = tokenizer.get_tokens()
    index = -1


func parse() -> Array[DialogCommand]:
    var root_command := DialogCommand.new(0, 0, DialogCommand.Type.ROOT)
    while index < len(tokens):
        _parse(root_command)
    return [root_command]


func advance():
    index += 1
    if index + 1 > len(tokens):
        return


func peek_type_match(t: Token.Type):
    if index + 1 > len(tokens):
        return false
    return tokens[index + 1].type == t


func peek_in_body():
    return (tokens[index + 1].type != Token.Type.ENDIF
            and tokens[index + 1].type != Token.Type.ELIF
            and tokens[index + 1].type != Token.Type.ELSE
            and tokens[index + 1].type != Token.Type.EOF)


func _parse(root: DialogCommand):
    index += 1
    if index + 1 > len(tokens):
        return

    var current_token := tokens[index]
    var lineno = current_token.lineno
    var column = current_token.column
    var value = current_token.value

    match current_token.type:
        Token.Type.TEXT:
            root.children.append(DialogCommand.new(lineno, column, DialogCommand.Type.DISPLAY_TEXT, [value]))
        Token.Type.PAGE_BREAK:
            root.children.append(DialogCommand.new(lineno, column, DialogCommand.Type.PAGE_BREAK, [value]))
        Token.Type.IF:
            var cmd = DialogCommand.new(lineno, column, DialogCommand.Type.IF, [value])
            root.children.append(cmd)
            if peek_type_match(Token.Type.COLON):
                advance()
                while peek_in_body():
                    _parse(cmd)
            else:
                Logger.warn("[%s:%s] %s" % [lineno, column, "Missing ':' after if"])
        Token.Type.ELIF:
            var cmd = DialogCommand.new(lineno, column, DialogCommand.Type.ELIF, [value])
            root.children.append(cmd)
            if tokens[index + 1].type == Token.Type.COLON:
                advance()
                while peek_in_body():
                    _parse(cmd)
            else:
                Logger.warn("[%s:%s] %s" % [lineno, column, "Missing ':' after elif"])
        Token.Type.ELSE:
            var cmd = DialogCommand.new(lineno, column, DialogCommand.Type.ELSE, [value])
            root.children.append(cmd)
            if peek_type_match(Token.Type.COLON):
                advance()
                while tokens[index + 1].type != Token.Type.ENDIF and tokens[index + 1].type != Token.Type.EOF:
                    _parse(cmd)
            else:
                Logger.warn("[%s:%s] %s" % [lineno, column, "Missing ':' after else"])
        Token.Type.GOTO:
            var cmd = DialogCommand.new(lineno, column, DialogCommand.Type.GOTO, [value])
            root.children.append(cmd)
        Token.Type.PROMPT: # (- prompt text -> node) | (- prompt text -> signal()... node)
            var cmd = DialogCommand.new(lineno, column, DialogCommand.Type.PROMPT, [value])
            root.children.append(cmd)
            if peek_type_match(Token.Type.EOF):
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
        Token.Type.SIGNAL:
            var cmd = DialogCommand.new(lineno, column, DialogCommand.Type.SIGNAL, [value])
            root.children.append(cmd)
            if peek_type_match(Token.Type.SIGNAL_END):
                advance()
            else:
                Logger.warn("[%s:%s] %s" % [lineno, column, "Signal should end with ')'!"])
        _:
            pass

@tool
class_name DialogTokenizer
extends RefCounted


var text: String
var pos: int
var current_char: String
var lineno: int
var column: int
var signal_end_regex = RegEx.new()
var line_end_regex = RegEx.new()
var colon_regex = RegEx.new()
var spacial_token_regex = RegEx.new()


func _init(t: String):
    text = t
    pos = 0
    lineno = 1
    column = 1
    if text != "":
        current_char = text[pos]
        signal_end_regex.compile("\\)")
        line_end_regex.compile("\\n")
        colon_regex.compile(":")
        spacial_token_regex.compile("(if|elif|else|endif|\\-\\-\\-|\\- |signal\\(|\\->|:\\n)")


func advance(len=1):
    # Advance the `pos` pointer and set the `current_char` variable.
    if current_char == '\n':
        lineno += 1
        column = 0

    pos += len
    if pos > len(text) - 1:
        current_char = ""  # Indicates end of input
    else:
        current_char = text[pos]
        column += len


func peek():
    var peek_pos = pos + 1
    if peek_pos > len(text) - 1:
        return ""
    else:
        return text[peek_pos]


func match_then_advance(find: String) -> bool:
    if (text.substr(pos, find.length()).to_lower() == find.to_lower()):
        advance(find.length())
        return true
    else: # 1.不匹配 2.pos > len(text)时返回空
        return false


func skip_space():
    while current_char in " \t\r\n":
        advance()


func advance_to_next_line():
    while current_char and current_char != "\n":
        advance()
    advance() # \n


func collect_characters_then_advance(terminating: RegEx):
    var result = ""
    var match_result = terminating.search(text, pos)

    if match_result:
        var match_length = match_result.get_start() - pos
        result = text.substr(pos, match_length)
        advance(match_length)
    else:
        result = text.substr(pos)
        # advance_to_next_line() 
        # to End
        pos = len(text)
        current_char = ""


    return result.strip_edges()


func get_matched_string_then_advance(terminating: RegEx):
    var match_result = terminating.search(text, pos)
    if match_result:
        advance(match_result.get_string().length())
        return match_result.get_string()


func add_signal_tokens(tokens: Array[Token]):
    var value_string = collect_characters_then_advance(signal_end_regex)
    tokens.push_back(Token.new(Token.Type.SIGNAL, value_string, lineno, column))
    if current_char == ")":
        tokens.push_back(Token.new(Token.Type.SIGNAL_END, "", lineno, pos))
        advance()


func get_tokens() -> Array[Token]:
    var tokens: Array[Token] = []
    while current_char != "":
        skip_space() # 处理 if 后的缩进
        if match_then_advance("---"):
            advance_to_next_line()
            tokens.push_back(Token.new(Token.Type.PAGE_BREAK, "", lineno, column))
        elif match_then_advance("- "): # 行首的'- '表示选项
            tokens.push_back(Token.new(Token.Type.PROMPT, "", lineno, column))
        elif match_then_advance("if"):
            var expr = collect_characters_then_advance(colon_regex)
            tokens.push_back(Token.new(Token.Type.IF, expr, lineno, column))
        elif match_then_advance("elif"):
            var expr = collect_characters_then_advance(colon_regex)
            tokens.push_back(Token.new(Token.Type.ELIF, expr, lineno, column))
        elif match_then_advance("else"):
            tokens.push_back(Token.new(Token.Type.ELSE, "", lineno, column))
        elif match_then_advance("endif"):
            tokens.push_back(Token.new(Token.Type.ENDIF, "", lineno, column))
        elif match_then_advance("signal("):
                add_signal_tokens(tokens)
        elif match_then_advance(":\n"):
            tokens.push_back(Token.new(Token.Type.COLON, "", lineno, column))
        elif match_then_advance("->"): # -> node | -> signal()... node
            skip_space()
            while match_then_advance("signal("):
                add_signal_tokens(tokens)
            var goto_node = collect_characters_then_advance(line_end_regex)
            tokens.push_back(Token.new(Token.Type.GOTO, goto_node, lineno, column))
        else: # 普通文本
            var plain_text = collect_characters_then_advance(spacial_token_regex)
            while plain_text.right(1) == "\\":
                plain_text[-1] = "" # 去掉 '\'
                plain_text += get_matched_string_then_advance(spacial_token_regex) # 加上匹配到的字符
            var text_token = Token.new(Token.Type.TEXT, plain_text, lineno, column)
            if text_token.value != "":
                tokens.push_back(text_token)
    tokens.push_back(Token.new(Token.Type.EOF, "", -1, -1))
    return tokens

@tool
class_name DialogParser
extends RefCounted

var text: String
var pos: int
var current_char: String
var lineno: int
var column: int


func _init(t: String):
    text = t
    pos = 0
    lineno = 1
    column = 1
    if text != "":
        current_char = text[pos]


func error(msg: String):
    # Logger.error("Error at (line:%d column:%d): %s" % [lineno, column, msg])
    pass


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


func match_then_advance(find: String) -> bool:
    if (text.substr(pos, find.length()) == find):
        advance(find.length())
        return true
    else: # 1.不匹配 2.pos > len(text)时返回空
        return false


func skip_space():
    while current_char in " \t\r\n":
        advance()


func parse():
    var root_sequence: Array[DialogCommand] = []
    root_sequence.push_back(DialogCommand.new(0, 0, DialogCommand.Type.ROOT))
    var start_time = Time.get_ticks_msec()
    while not current_char.is_empty():
        # if pos > 200:
        # Logger.debug("Current Char", text.substr(pos, 3))
        _parse_statement(root_sequence)
        # Logger.debug("Root",root_sequence)
    Logger.debug("Parse Time Cost", Time.get_ticks_msec() - start_time)
    return root_sequence


#This method is responsible for breaking a dialog text apart into commands.
func _parse_statement(parent_sequence: Array[DialogCommand]):
    if current_char in "?-$s{}": # 特殊命令
        if match_then_advance("---"):
            parent_sequence[0].children.push_back(
                DialogCommand.new(lineno, column, DialogCommand.Type.PAGE_BREAK)
            )
        if match_then_advance("signal("):
            var param_string = get_string_before_char(")")
            advance()
            skip_space()
            parent_sequence[0].children.push_back(
                DialogCommand.new(lineno, column, DialogCommand.Type.SIGNAL, [param_string.strip_edges()])
            )
        elif match_then_advance("?>"):
            skip_space()
            if current_char == "":
                return
            var choice_string = get_string_before_char()
            parse_body(parent_sequence, DialogCommand.Type.PROMPT, choice_string.strip_edges())
        elif match_then_advance("$if"):
            var expr = get_string_before_char()
            parse_body(parent_sequence, DialogCommand.Type.IF, expr.strip_edges())
        elif match_then_advance("$else"):
            if parent_sequence[0].children and parent_sequence[0].children[-1].type == DialogCommand.Type.IF:
                skip_space()
                parse_body(parent_sequence, DialogCommand.Type.ELSE, "")
            else:
                error("'$else' can only be used after '$if'")
        elif match_then_advance("->"):
            var goto_node = get_node_name_then_advance()
            var goto_cmd = DialogCommand.new(lineno, column, DialogCommand.Type.GOTO, [goto_node])
            Logger.info("GOTO", goto_cmd)
            parent_sequence[0].children.push_back(goto_cmd)
        elif match_then_advance("${"):
            pos -= 2
            current_char = text[pos]
            add_letter(parent_sequence[0].children)
            add_letter(parent_sequence[0].children)
        elif match_then_advance("{"): # 感觉有点多余
            skip_space()
            var open_bracket_cmd = DialogCommand.new(lineno, column, DialogCommand.Type.BRACKET)
            parent_sequence[0].children.push_back(open_bracket_cmd)
            parent_sequence.push_front(open_bracket_cmd)
        elif match_then_advance("}"):
            if parent_sequence[0].type == DialogCommand.Type.BRACKET:
                parent_sequence.pop_front()
                skip_space()
            elif parent_sequence[0].children[-1].type == DialogCommand.Type.DISPLAY_TEXT:
                pos -= 1
                current_char = text[pos]
                add_letter(parent_sequence[0].children)
        else:
            # ${xxx}
            add_letter(parent_sequence[0].children)

    else: # 普通文本
        if current_char == "\\":
            advance()
        add_letter(parent_sequence[0].children)


func add_letter(cur_sequence: Array[DialogCommand]):
    if cur_sequence.is_empty():
        cur_sequence.append(DialogCommand.new(lineno, column, DialogCommand.Type.DISPLAY_TEXT, [current_char]))
    elif cur_sequence[-1].type != DialogCommand.Type.DISPLAY_TEXT:
        cur_sequence.append(DialogCommand.new(lineno, column, DialogCommand.Type.DISPLAY_TEXT, [current_char]))
    else:
        cur_sequence[-1].values[0] += current_char
    advance()


func get_node_name_then_advance() -> String:
    var node_name = ""
    while current_char != "\n" and current_char != "":
        node_name += current_char
        advance()
    skip_space()

    if node_name == "":
        Logger.warn("Goto Empty Node Name!")

    return node_name.strip_edges()


func get_string_before_char(next_char: String="-{") -> String:
    var expr = ""
    while current_char not in next_char:
        if pos + 1 > len(text) - 1:
            break
        if current_char + text[pos+1] == "${":
            expr += "${"
            advance()
            advance()
        else:
            expr += current_char
            advance()
        if current_char == "":
            error("Expected '%s' as next!" % next_char)
            break
    return expr.strip_edges()


# -> node | {...}
func parse_body(p: Array[DialogCommand], t: DialogCommand.Type, expr: String=""):
    if p.is_empty():
        return

    var cmd = DialogCommand.new(
        lineno, column, t, [expr], []
    )

    p[0].children.push_back(cmd)
    if match_then_advance("->"):
        var goto_node = get_node_name_then_advance()
        var goto_cmd = DialogCommand.new(lineno, column, DialogCommand.Type.GOTO, [goto_node])
        cmd.children.push_back(goto_cmd)
    elif match_then_advance("{"):
        skip_space()
        var open_bracket_cmd = DialogCommand.new(lineno, column, DialogCommand.Type.BRACKET)
        cmd.children.push_back(open_bracket_cmd)
        p.push_front(open_bracket_cmd)
    else:
        var type_str = DialogCommand.Type.keys()[t]
        error("Missing '{' or '->' after '%s'." % type_str)

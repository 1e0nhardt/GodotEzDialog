@tool
class_name DialogReader
extends Node

signal dialog_generated(response: DialogResponse)
signal custom_signal_received(value: String)

@onready var is_running = false
@onready var resource_cache: Dictionary = {}
@onready var history_stack_size = 100

var processing_dialog: DialogResource
var executing_command_stack: Array[DialogCommand]
var dialog_visit_history: Array[String]
var pending_choice_actions: Array
var state_reference: Dictionary


# 根据命令序列逐步生成对话内容
func _process(delta):
    if is_running:
        var response = DialogResponse.new()
        while is_running:
            if response.should_pause:
                is_running = false
                break

            if executing_command_stack.is_empty():
                is_running = false
                if pending_choice_actions.is_empty() and response.text.is_empty():
                    response.eod_reached = true
                break

            _process_command(executing_command_stack.pop_front(), response)

        dialog_generated.emit(response)


# 加载初始对话节点
func start_dialog(dialog: JSON, state: Dictionary, starting_node_name = "start"):
    _load_dialog(dialog)
    var starting_node = processing_dialog.get_node_by_name(starting_node_name)
    executing_command_stack = starting_node.get_parse()
    pending_choice_actions = []
    dialog_visit_history = [starting_node.name]
    state_reference = state
    is_running = true


# 缓存+反序列化
func _load_dialog(dialog: JSON):
    if !resource_cache.has(dialog.resource_path):
        var dialog_graph = DialogResource.new()
        dialog_graph.loadFromJson(dialog.data)
        resource_cache[dialog.resource_path] = dialog_graph
    processing_dialog = resource_cache[dialog.resource_path]


# 继续请求解析命令，生成对话内容
func next(choice_index: int = 0):
    if is_running:
        return

    dialog_visit_history = []
    if choice_index >= 0 && choice_index < pending_choice_actions.size():
        # select a choice
        var commands = pending_choice_actions[choice_index] as Array[DialogCommand]
        commands.append_array(executing_command_stack)
        executing_command_stack = commands

        # clear pending choices for new execution
        pending_choice_actions = []
        is_running = true
    else:
        # resume executing existing commmand stack
        is_running = true


# 处理命令
func _process_command(command: DialogCommand, response: DialogResponse):
    if command.type == DialogCommand.Type.ROOT:
        _queue_executing_commands(command.children)
    elif command.type == DialogCommand.Type.SIGNAL: # 发送一次信号
        var signal_value = command.values[0]
        if not built_in_signal_process(signal_value):
            custom_signal_received.emit(signal_value)
    elif command.type == DialogCommand.Type.DISPLAY_TEXT: # 生成变量注入后的文本
        var display_text: String = _inject_variable_to_text(command.values[0].strip_edges(true,true))
        display_text = remove_spaces_after_line_end(display_text)
        # normal text display
        response.append_text(display_text)
    elif command.type == DialogCommand.Type.PAGE_BREAK: # 停止命令处理，直接输出已处理的对话
        # page break. stop processing until further user input
        is_running = false
    elif command.type == DialogCommand.Type.PROMPT: # 生成选择文本，并将其子命令数组放到pending_choice_actions数组的相应位置
        # choice item
        var actions: Array[DialogCommand] = []
        var prompt: String = _inject_variable_to_text(command.values[0])
        actions.append_array(command.children)
        # 标记PROMPT中的GOTO。
        for cmd in command.children:
            if cmd.type == DialogCommand.Type.GOTO:
                cmd.values.append("prompt_goto")
        response.append_choice(prompt.strip_edges())
        pending_choice_actions.push_back(actions)
    elif command.type == DialogCommand.Type.GOTO: # 获取并解析目标节点，用新的命令流取代老的。
        var destination_node = processing_dialog.get_node_by_name(command.values[0])
        executing_command_stack = destination_node.get_parse()
        dialog_visit_history.push_front(destination_node.name)
        if command.values.size() == 1: # 没有添加prompt_goto标记
            response.should_pause = true
        if dialog_visit_history.size() > history_stack_size:
            dialog_visit_history.remove_at(-1)
    elif command.type == DialogCommand.Type.IF or command.type == DialogCommand.Type.ELIF: # 表达式估值，丢弃目标命令
        var expression = command.values[0]
        var result = _evaluate_conditional_expression(expression)
        if result:
            while (!executing_command_stack.is_empty() and
                (executing_command_stack[0].type == DialogCommand.Type.ELSE
                or executing_command_stack[0].type == DialogCommand.Type.ELIF)):
                executing_command_stack.pop_front()
            _queue_executing_commands(command.children)
    elif command.type == DialogCommand.Type.ELSE:
        _queue_executing_commands(command.children)


# 将${var}替换为变量值 用正则匹配所有var，然后从_state_refence(用户传入)从读值。
func _inject_variable_to_text(text: String) -> String:
    var required_variables: Array[String] = []
    var variable_placeholder_regex = RegEx.new()
    variable_placeholder_regex.compile("\\${(\\S+?)}")
    var final_text = text
    var matchResults = variable_placeholder_regex.search_all(final_text)
    for result in matchResults:
        required_variables.push_back(result.get_string(1))

    for variable in required_variables:
        var value = state_reference.get(variable)
        if not value is String:
            value = str(value)
        final_text = final_text.replace(
            "${%s}" % variable, value)
    return final_text


func remove_spaces_after_line_end(text: String) -> String:
    var splits = text.split("\n") as Array
    splits = splits.map(func(s): return s.strip_edges())
    return "\n".join(splits)


# 将if-else {}内的子命令加入执行队列
func _queue_executing_commands(commands: Array[DialogCommand]):
    var copy = commands.duplicate(true)
    copy.append_array(executing_command_stack)
    executing_command_stack = copy


func _evaluate_conditional_expression(expression: String):
    # initial version of conditional expression...
    # only handle order of operation and && and ||
    var properties = state_reference.keys()
    var evaluation = Expression.new()
    var available_variables: Array[String] = []
    var variable_values = []
    for property in properties:
        available_variables.push_back(property)
        variable_values.push_back(state_reference.get(property))

    var parse_error = evaluation.parse(expression, PackedStringArray(available_variables))
    var result = evaluation.execute(variable_values)
    if evaluation.has_execute_failed() or evaluation.get_error_text():
        printerr("Conditional expression '%s' did not parse/execute correctly with state: %s"%[expression, variable_values])
        # failed expression statement is assumed falsy.
        return false
    return result


func built_in_signal_process(signal_value: String):
    var params = signal_value.split(",")
    if params.size() != 3:
        return false

    var method_name = params[0].strip_edges()
    var variable_name = params[1].strip_edges()
    var value_string = params[2].strip_edges()

    if Util.BUILT_IN_METHOD_IN_SIGNAL.find(method_name) == -1:
        return false

    if not state_reference.has(variable_name):
        Logger.warn("invalid variable name '%s', '%s' will send by signal." % [variable_name, signal_value])
        return false

    var expression = Expression.new()
    expression.parse(value_string)
    var value = _evaluate_conditional_expression(value_string)

    if !value and typeof(value) == TYPE_BOOL:
        Logger.warn("expression '%s' did not parse/execute correctly, '%s' will send by signal." % [value_string, signal_value])
        return false

    match Util.BUILT_IN_METHOD_IN_SIGNAL.find(method_name):
        Util.MethodType.SET:
            state_reference[variable_name] = value
        Util.MethodType.ADD:
            state_reference[variable_name] += value
        Util.MethodType.MINUS:
            state_reference[variable_name] -= value
        Util.MethodType.MUL:
            state_reference[variable_name] *= value
        _:
            return false

    return true
extends Node


func _ready():
    var fake_dialog = "hello! I need more power!\n---\nI'm the strom that is coming! Prevoking...\n-> next node"
    var fake_dialog2 = "hello\nIf you are dragon.If you are dragon.If you are dragon.If you are dragon.If you are dragon.If you are dragon.If you are dragon.If you are dragon.If you are dragon.More dragon than ${player}.\n\n$if dragon {\n\tAro....\n} $else {\n\thaha...\n}\n\n-> next"
    var fake_dialog3 = "If you are dragon. More dragon than I.\n?> yes, indeed -> kill node\n?> no, thanks {\n\tsignal(set, love, 100)\n\t-> node1\n}\n?> dj.... {\n\tR.I.P\n\t-> node2\n}"
    var parser = DialogParser.new(fake_dialog3)
    var ret = parser.parse()
    Logger.debug("Final Sequence", ret)

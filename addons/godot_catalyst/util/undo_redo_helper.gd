@tool
class_name CatalystUndoRedoHelper
extends RefCounted
## Helper to wrap editor operations with UndoRedo for full undo support.


static func get_undo_redo() -> EditorUndoRedoManager:
	return EditorInterface.get_editor_undo_redo()


static func do_action(action_name: String, do_callable: Callable, undo_callable: Callable) -> void:
	var ur := get_undo_redo()
	ur.create_action(action_name)
	ur.add_do_method(do_callable)
	ur.add_undo_method(undo_callable)
	ur.commit_action()

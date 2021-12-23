#### use this singleton to tell and update what values the Graphtastic Plugin can use
#### also forwards all signals used
signal GT_choice_made
signal GT_dialog_started
signal GT_dialog_finished
signal GT_set_choices
signal GT_set_pictures
signal GT_set_speaker
signal GT_text_animation_finished
signal GT_text_animation_started
signal GT_variables_were_changed
signal GT_preparing_chapter_change_to
signal GT_custom_signal					###(signalkey) OR (signalkey, value)

extends Node
var variables: Dictionary = {
	"health": 150,
	"mana": 55,
	"playername": "paul",
	
}
var pictures: Dictionary = {
	"hil": "res://mockupProject/Hills Free (update 3.0).png",
	"hill": {"happy": "res://mockupProject/Hills Free (update 3.0).png", "angry": "res://mockupProject/Hills Free (update 3.0).png",}
	
}

######						just forward these signals			#########
func _on_GT_choice_made(next_nID):
	emit_signal("GT_choice_made", next_nID)
func _on_GT_dialog_started():
	emit_signal("GT_dialog_started")
func _on_GT_set_choices(graphs):
	emit_signal("GT_set_choices", graphs)
func _on_GT_set_pictures(pictures):
	emit_signal("GT_set_pictures", pictures)
func _on_GT_set_speaker(speaker):
	emit_signal("GT_set_speaker", speaker)
func _on_GT_dialog_finished():
	emit_signal("GT_dialog_finished")
func _on_GT_text_animation_started():
	emit_signal("GT_text_animation_started")
func _on_GT_text_animation_finished():
	emit_signal("GT_text_animation_finished")
func _on_GT_variables_were_changed(changes:Array):
	emit_signal("GT_variables_were_changed", changes)
func _on_GT_custom_signal(signalkey, value="default"):
	if String(value)=="default": emit_signal("GT_custom_signal", signalkey)
	else: emit_signal("GT_custom_signal", signalkey, value)
func _on_GT_preparing_chapter_change_to(chapter:int, next_nID:int):
	emit_signal("GT_preparing_chapter_change_to", chapter, next_nID)


func lookup(key : String):
	if variables.has(key):
		return variables[key]
	else:
		return "'"+key+"' :VariableNotFound"


func change_variable_to(key : String, expr : String):
	if key in variables:
		var expression = Expression.new()
		var variables_pool= PoolStringArray (variables.keys())
		var error = expression.parse(expr, variables_pool)
		if error != OK:
			print("GT error: expression checking went wrong: "+String(expr) +" coulnt be parsed. Errortext: "+ expression.parse(expr, variables_pool))
			return false
		var result = expression.execute(variables.values(), null, true)
		if not expression.has_execute_failed():
			variables[key] = result
			return true
	else:
		print("GT error: cant change variable, not in variables "+ key + "by" + expr)
		return false


func check_if(tocheck : String):
	#print("checking if: " +String(tocheck))
	if tocheck == "" or tocheck == " " or tocheck == "   " or tocheck=="#":
		return true
	var expression = Expression.new()
	var variables_pool= PoolStringArray (variables.keys())
	var error = expression.parse(tocheck, variables_pool)
	if error != OK:
		print("GT error: expression checking went wrong: "+String(tocheck) +" is no valid statement. Errortext: "+ expression.get_error_text())
		return "error"
	var result = expression.execute(variables.values(), null, true)
	if result: return true
	else: return false


func inject_variables(text : String) -> String:
	var variable_count = text.count(")#")

	for _i in range(variable_count):
		var start_tag = "#("
		var end_tag = ")#"
		var start_index = text.find(start_tag)+start_tag.length()
		var end_index = text.find(end_tag)
		var subst_length = end_index - start_index
		var variable_key = text.substr(start_index, subst_length)
		var variable_value = lookup(variable_key)
		start_index = text.find("#(")
		end_index = text.find(")#") + ")#".length()
		subst_length = end_index - start_index
		text.erase(start_index, subst_length)
		text = text.insert(start_index, str(variable_value))
	return text


func parse_expr(tocheck : String):
	#print("checking if: " +String(tocheck))
	var expression = Expression.new()
	var variables_pool= PoolStringArray (variables.keys())
	var error = expression.parse(tocheck, variables_pool)
	if error != OK:
		print("GT error: expression checking went wrong: "+String(tocheck) +" is no valid statement. Errortext: "+ expression.get_error_text())
		return "error"
	var result = expression.execute(variables.values(), null, true)
	return result

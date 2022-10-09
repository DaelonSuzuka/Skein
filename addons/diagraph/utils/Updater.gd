tool
extends Node

# ******************************************************************************

signal download_complete
signal update_complete
signal file_updated

# ******************************************************************************

var file_list_url = 'https://github.com/DaelonSuzuka/Diagraph/raw/file_list/file_list.json'
var base_url = 'https://github.com/DaelonSuzuka/Diagraph/raw/master/'

func send_request(request, callback, args=[]):
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.use_threads = true

	if !(args is Array):
		args = [args]

	http_request.connect("request_completed", self, callback, args)
	http_request.request(request)

var file_list = []
var file_data = {}
var current_file = 0
var number_of_files = 0
var active = false
var status_label = null
var progress_bar = null

func _process(delta: float) -> void:
	if !active:
		return

	number_of_files = len(file_data)

	if len(file_data) == len(file_list):
		active = false
		
		status_label.text = 'Download complete, applying update'
		unzip_and_apply_update()
		return

	if current_file < len(file_list):
		var file = file_list[current_file]
		send_request(base_url + file.path, 'recieve_file', file.path)	

		current_file += 1
		progress_bar.value = current_file

func get_file_list(label, progress):
	status_label = label
	progress_bar = progress
	send_request(file_list_url, 'recieve_file_list')
	
	status_label.text = 'Downloading file list...'

func recieve_file_list(result, response_code, headers, body):
	var parse = JSON.parse(body.get_string_from_ascii())
	if parse.result is Array:
		file_list = parse.result

		current_file = 0
		active = true
		status_label.text = 'Downloading files...'
		progress_bar.max_value = len(file_list)

func recieve_file(result, response_code, headers, body, path):
	file_data['res://' + path] = body

# ******************************************************************************

func unzip_and_apply_update():
	var existing_files = Diagraph.files.get_all_files('res://addons/diagraph')
	var checked_files = []

	for f in file_data:
		checked_files.append(f)

		var file = File.new()
		if file.file_exists(f):
			if file.open(f, File.READ) == OK:
				var new = file_data[f]
				var existing = file.get_buffer(file.get_len())

				if new == existing:
					continue

				if file.open(f, File.WRITE) == OK:
					file.store_buffer(file_data[f])
		else:
			if file.open(f, File.WRITE) == OK:
				file.store_buffer(file_data[f])

		file.close()

	var dir = Directory.new()
	for f in existing_files:
		if not(f in checked_files):
			dir.remove(f)

	emit_signal('update_complete')

tool
extends Node

# ******************************************************************************

const master_zip_url = 'https://github.com/DaelonSuzuka/Diagraph/archive/refs/heads/master.zip'
const master_zip_path = 'res://master.zip'

signal download_complete
signal update_complete
signal file_decompressed
signal file_updated

# ******************************************************************************

func download_update():
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.download_file = master_zip_path
	http_request.use_threads = true
	http_request.connect("request_completed", self, "_http_request_completed")

	var error = http_request.request(master_zip_url)
	if error != OK:
		push_error("An error occurred in the HTTP request.")

func _http_request_completed(result, response_code, headers, body):
	emit_signal('download_complete')

func unzip_and_apply_update():
	var unzip = load('res://addons/diagraph/utils/GDUnzip.gd').new()
	var loaded = unzip.load(master_zip_path)

	var existing_files = Diagraph.files.get_all_files('res://addons/diagraph')
	var checked_files = []
	var files = {}

	for f in unzip.files:
		if 'addons/diagraph' in f:
			if f.ends_with('/'): # skip folders
				continue
			files[f] = unzip.uncompress(f)

	for f in files:
		var path = f.replace('Diagraph-master/', 'res://')
		checked_files.append(path)

		var file = File.new()
		if file.file_exists(path):
			if file.open(path, File.READ) == OK:
				var new = files[f]
				var existing = file.get_buffer(file.get_len())

				if new == existing:
					continue

				if file.open(path, File.WRITE) == OK:
					file.store_buffer(files[f])
		else:
			if file.open(path, File.WRITE) == OK:
				file.store_buffer(files[f])

		file.close()

	var dir = Directory.new()
	for f in existing_files:
		if not(f in checked_files):
			dir.remove(f)

	dir.remove(master_zip_path)

	emit_signal('update_complete')

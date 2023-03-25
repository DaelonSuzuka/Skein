extends Node

# ******************************************************************************

signal completed
signal error

var _secret: String = ''

# ******************************************************************************

func send_report(report_text: String, attachments: PoolStringArray=[]) -> void:
	var request = Request.new()
	add_child(request)
	request.requested_attachments = attachments
	request._secret = _secret

	request.connect('completed', self, 'emit_signal', ['completed'])
	request.connect('error', self, 'emit_signal', ['error'])

	request.post(report_text, attachments)

class Request:
	extends Node

	signal completed
	signal error

	var _headers: PoolStringArray = ['Content-Type: application/json', 'Accept: application/json']
	var _secret: String = ''
	var _handler: HTTPRequest = null
	var response_report_id: String = ''
	var requested_attachments: PoolStringArray = []
	const api_url = 'https://api.playerloop.io'

	func post(report_text: String, attachments: PoolStringArray=[]) -> void:
		requested_attachments = attachments

		var request = Request.new()

		var http_request = HTTPRequest.new()
		add_child(http_request)
		http_request.connect('request_completed', self, '_http_request_completed')

		_headers.append('Authorization: %s' % [_secret])

		var body: Dictionary = {
			'text': report_text,
			'type': 'bug',
			'accepted_privacy': true,
			'client': 'godot',
			'player': {'id': OS.get_unique_id()}
		}
		var error = http_request.request(
			api_url + '/reports', _headers, false, HTTPClient.METHOD_POST, JSON.print(body)
		)
		if error != OK:
			push_error('An error occurred in the HTTP request.')
			return

	# Called when the HTTP request is completed.
	func _http_request_completed(result, response_code, headers, body):
		if response_code > 300:
			push_error('An error occurred in the HTTP request.')
			return
		var response = parse_json(body.get_string_from_utf8())
		response_report_id = response.data.id
		if requested_attachments.size() > 0:
			self.upload_attachment(response_report_id, requested_attachments[0])
		else:
			self._report_sent_successfully()



# ******************************************************************************

	func upload_attachment(report_id: String, file_path: String) -> void:
		var upload_headers: PoolStringArray = [
			#"Content-Disposition: form-data",
			'Content-Type: multipart/form-data; boundary="WebKitFormBoundaryePkpFF7tjBAqx29L"',
			'Authorization: ' + _secret,
			#"filename: test.txt",
			#"name: file"
		]
		var file = File.new()
		file.open(file_path, File.READ)
		var file_content = file.get_buffer(file.get_len())
		var body_a = PoolByteArray()
		body_a.append_array('\r\n--WebKitFormBoundaryePkpFF7tjBAqx29L\r\n'.to_utf8())
		var file_complete: String = (
			'Content-Disposition: form-data; name="file"; filename="'
			+ file_path.get_file()
			+ '"\r\n'
		)
		body_a.append_array(file_complete.to_utf8())
		body_a.append_array('Content-Type: application/octotet-stream\r\n\r\n'.to_utf8())
		body_a.append_array(file_content)
		body_a.append_array('\r\n--WebKitFormBoundaryePkpFF7tjBAqx29L--\r\n'.to_utf8())

		var http = HTTPClient.new()

		http.connect_to_host('https://api.playerloop.io', 443, false)

		while (
			http.get_status() == HTTPClient.STATUS_CONNECTING
			or http.get_status() == HTTPClient.STATUS_RESOLVING
		):
			http.poll()
			OS.delay_msec(10)

		#assert(http.get_status() == HTTPClient.STATUS_CONNECTED) # Could not connect

		#http.connect("request_completed", self, "_upload_completed")
		var err = http.request_raw(
			HTTPClient.METHOD_POST, '/reports/' + report_id + '/attachments', upload_headers, body_a
		)

		#assert(err == OK) # Make sure all is OK.

		var _reading_body = false
		var _response_headers: PoolStringArray
		var _response_data: PoolByteArray
		var _content_length: int
		var _response_code: int

		while http.get_status() != HTTPClient.STATUS_BODY:
			http.poll()
			OS.delay_msec(10)

		while http.get_status() == HTTPClient.STATUS_BODY:
			match http.get_status():
				HTTPClient.STATUS_DISCONNECTED:
					#http.connect_to_host(_config.supabaseUrl, 443, true)
					emit_signal('error')

				HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_REQUESTING, HTTPClient.STATUS_CONNECTING:
					http.poll()
					#var err : int = _http_client.request_raw(task._method, task._endpoint.replace(_config.supabaseUrl, ""), task._headers, task._bytepayload)
					#if err :
					#	task.error = SupabaseStorageError.new({statusCode = HTTPRequest.RESULT_CONNECTION_ERROR})
					#	_on_task_completed(task)

				HTTPClient.STATUS_BODY:
					if http.has_response() or _reading_body:
						_reading_body = true

						# If there is a response...
						if _response_headers.empty():
							_response_headers = http.get_response_headers()  # Get response headers.
							_response_code = http.get_response_code()

							for header in _response_headers:
								if 'Content-Length' in header:
									_content_length = header.trim_prefix('Content-Length: ').to_int()
									print(_content_length)

						http.poll()
						var chunk: PoolByteArray = http.read_response_body_chunk()  # Get a chunk.
						if chunk.size() == 0:
							# Got nothing, wait for buffers to fill a bit.
							pass
							OS.delay_msec(10)
						else:
							_response_data += chunk  # Append to read buffer.
							if _content_length != 0:
								pass
							OS.delay_msec(10)
							self._upload_completed(0, _response_code, _response_headers, _response_data)
							#self._upload_completed(0, _response_code, _response_headers, [])
					else:
						OS.delay_msec(10)
						#self._upload_completed(0, _response_code, _response_headers, [])

	func _upload_completed(result, response_code, headers, body):
		if response_code > 300:
			push_error('An error occurred in the HTTP request.')
			return
		var response = parse_json(body.get_string_from_utf8())
		# Will print the user agent string used by the HTTPRequest node (as recognized by httpbin.org).
		self._report_sent_successfully()

	func _report_sent_successfully():
		emit_signal('completed')

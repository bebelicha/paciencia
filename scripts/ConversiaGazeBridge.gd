extends Node

var gaze_data = {
	'headYaw': 0.5,
	'headPitch': 0.5,
	'headRoll': 0.5
}
var is_ready = false
var conversia_connected = false
var last_analog_update = 0
var analog_count = 0
var last_snapshot_str = ""
var recent_logs: Array[String] = []
var _ready_ping_timer: Timer

func _init():
	if OS.get_name() == "Web":
		JavaScriptBridge.eval("window.EngineJS = window.EngineJS || {}; window.EngineJS.GazeBridge = window.EngineJS.GazeBridge || {}; if (!window.EngineJS.GazeBridge._bootstrap) { window.EngineJS.GazeBridge._bootstrap = true; window.EngineJS.GazeBridge.connected = false; window.EngineJS.GazeBridge.lastAnalog = {}; }")

func _ready():
	if OS.get_name() == "Web":
		JavaScriptBridge.eval("""
			window.EngineJS = window.EngineJS || {};
			window.EngineJS.GazeBridge = window.EngineJS.GazeBridge || {};
			if (!window.EngineJS.GazeBridge._listenerAttached) {
				window.EngineJS.GazeBridge._listenerAttached = true;
				window.EngineJS.GazeBridge.lastAnalog = {};
				window.addEventListener('message', function(ev) {
					var msg = ev.data;
					if (!msg || typeof msg.type !== 'string') return;
					if (msg.type === 'init') {
						window.EngineJS.GazeBridge.connected = true;
						try {
							window.parent.postMessage({ type: 'ready', timestamp: Date.now() }, '*');
						} catch (e) {}
						return;
					}
					if (msg.type === 'analog' && Array.isArray(msg.channels)) {
						var snapshot = {};
						for (var i = 0; i < msg.channels.length; i++) {
							var ch = msg.channels[i];
							if (ch && ch.name) {
								snapshot[ch.name] = ch.value;
							}
						}
						window.EngineJS.GazeBridge.lastAnalog = snapshot;
						window.__conversiaAnalog = snapshot; // compat
					}
				}, false);
			}
		""")
		await get_tree().process_frame
		is_ready = true
		_start_ready_ping()

func _process(_delta):
	if OS.get_name() != "Web":
		return
	conversia_connected = JavaScriptBridge.eval("(window.EngineJS && window.EngineJS.GazeBridge && window.EngineJS.GazeBridge.connected) ? true : false")
	var snap = _get_snapshot()
	if snap == null:
		return
	conversia_connected = true
	_stop_ready_ping()
	last_snapshot_str = str(snap)
	var now = Time.get_ticks_msec()
	if snap.has("headYaw"):
		gaze_data['headYaw'] = snap['headYaw']
		last_analog_update = now
	if snap.has("headPitch"):
		gaze_data['headPitch'] = snap['headPitch']
		last_analog_update = now
	if snap.has("headRoll"):
		gaze_data['headRoll'] = snap['headRoll']
		last_analog_update = now
	analog_count += 1
	_push_log(now)

func receiveAnalogData(data: Dictionary):
	if data.has('name') and data.has('value'):
		gaze_data[data['name']] = data['value']
		if data['name'] == 'headYaw' or data['name'] == 'headPitch' or data['name'] == 'headRoll':
			last_analog_update = Time.get_ticks_msec()

func is_head_tracking_active() -> bool:
	var current_time = Time.get_ticks_msec()
	return (current_time - last_analog_update) < 500

func send_stats(score: int, level: String = "1"):
	if is_ready:
		JavaScriptBridge.eval("""
			window.parent.postMessage({
				type: 'stats',
				score: %d,
				level: '%s',
				timestamp: Date.now()
			}, '*');
		""" % [score, level])

func get_last_snapshot_text() -> String:
	return last_snapshot_str

func get_last_update_age_ms() -> int:
	if last_analog_update == 0:
		return 999999
	return Time.get_ticks_msec() - last_analog_update

func get_recent_logs_text() -> String:
	return "\n".join(recent_logs)

func _push_log(timestamp_ms: int):
	var yaw = gaze_data.get('headYaw', 0)
	var pitch = gaze_data.get('headPitch', 0)
	var roll = gaze_data.get('headRoll', 0)
	var entry = "t=%d yaw=%.3f pitch=%.3f roll=%.3f" % [timestamp_ms, yaw, pitch, roll]
	recent_logs.append(entry)
	if recent_logs.size() > 5:
		recent_logs.pop_front()

func _start_ready_ping():
	if _ready_ping_timer:
		_ready_ping_timer.queue_free()
	_ready_ping_timer = Timer.new()
	_ready_ping_timer.wait_time = 1.0
	_ready_ping_timer.one_shot = false
	_ready_ping_timer.autostart = true
	_ready_ping_timer.timeout.connect(func(): _send_ready_ping())
	add_child(_ready_ping_timer)

func _stop_ready_ping():
	if _ready_ping_timer:
		_ready_ping_timer.stop()
		_ready_ping_timer.queue_free()
		_ready_ping_timer = null

func _send_ready_ping():
	if OS.get_name() != "Web":
		return
	JavaScriptBridge.eval("""
		try { window.parent.postMessage({ type: 'ready', timestamp: Date.now() }, '*'); } catch (e) {}
	""")

func _get_snapshot():
	var snap_json = JavaScriptBridge.eval("(window.EngineJS && window.EngineJS.GazeBridge && window.EngineJS.GazeBridge.lastAnalog) ? JSON.stringify(window.EngineJS.GazeBridge.lastAnalog) : (window.__conversiaAnalog ? JSON.stringify(window.__conversiaAnalog) : null)")
	if snap_json == null:
		return null
	var parsed = JSON.parse_string(snap_json)
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return null
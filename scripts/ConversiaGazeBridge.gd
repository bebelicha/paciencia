extends Node

var gazeData = {
	'headYaw': 0.5,
	'headPitch': 0.5,
	'headRoll': 0.5
}
var isReady = false
var conversiaConnected = false
var lastAnalogUpdate = 0
var analogCount = 0
var lastSnapshotStr = ""
var recentLogs: Array[String] = []
var readyPingTimer: Timer

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
		isReady = true
		startReadyPing()

func _process(_delta):
	if OS.get_name() != "Web":
		return
	conversiaConnected = JavaScriptBridge.eval("(window.EngineJS && window.EngineJS.GazeBridge && window.EngineJS.GazeBridge.connected) ? true : false")
	var snap = getSnapshot()
	if snap == null:
		return
	conversiaConnected = true
	stopReadyPing()
	lastSnapshotStr = str(snap)
	var now = Time.get_ticks_msec()
	if snap.has("headYaw"):
		gazeData['headYaw'] = snap['headYaw']
		lastAnalogUpdate = now
	if snap.has("headPitch"):
		gazeData['headPitch'] = snap['headPitch']
		lastAnalogUpdate = now
	if snap.has("headRoll"):
		gazeData['headRoll'] = snap['headRoll']
		lastAnalogUpdate = now
	analogCount += 1
	pushLog(now)

func receiveAnalogData(data: Dictionary):
	if data.has('name') and data.has('value'):
		gazeData[data['name']] = data['value']
		if data['name'] == 'headYaw' or data['name'] == 'headPitch' or data['name'] == 'headRoll':
			lastAnalogUpdate = Time.get_ticks_msec()

func isHeadTrackingActive() -> bool:
	var currentTime = Time.get_ticks_msec()
	return (currentTime - lastAnalogUpdate) < 500

func sendStats(score: int, level: String = "1"):
	if isReady:
		JavaScriptBridge.eval("""
			window.parent.postMessage({
				type: 'stats',
				score: %d,
				level: '%s',
				timestamp: Date.now()
			}, '*');
		""" % [score, level])

func getLastSnapshotText() -> String:
	return lastSnapshotStr

func getLastUpdateAgeMs() -> int:
	if lastAnalogUpdate == 0:
		return 999999
	return Time.get_ticks_msec() - lastAnalogUpdate

func getRecentLogsText() -> String:
	return "\n".join(recentLogs)

func pushLog(timestampMs: int):
	var yaw = gazeData.get('headYaw', 0)
	var pitch = gazeData.get('headPitch', 0)
	var roll = gazeData.get('headRoll', 0)
	var entry = "t=%d yaw=%.3f pitch=%.3f roll=%.3f" % [timestampMs, yaw, pitch, roll]
	recentLogs.append(entry)
	if recentLogs.size() > 5:
		recentLogs.pop_front()

func startReadyPing():
	if readyPingTimer:
		readyPingTimer.queue_free()
	readyPingTimer = Timer.new()
	readyPingTimer.wait_time = 1.0
	readyPingTimer.one_shot = false
	readyPingTimer.autostart = true
	readyPingTimer.timeout.connect(func(): sendReadyPing())
	add_child(readyPingTimer)

func stopReadyPing():
	if readyPingTimer:
		readyPingTimer.stop()
		readyPingTimer.queue_free()
		readyPingTimer = null

func sendReadyPing():
	if OS.get_name() != "Web":
		return
	JavaScriptBridge.eval("""
		try { window.parent.postMessage({ type: 'ready', timestamp: Date.now() }, '*'); } catch (e) {}
	""")

func getSnapshot():
	var snapJson = JavaScriptBridge.eval("(window.EngineJS && window.EngineJS.GazeBridge && window.EngineJS.GazeBridge.lastAnalog) ? JSON.stringify(window.EngineJS.GazeBridge.lastAnalog) : (window.__conversiaAnalog ? JSON.stringify(window.__conversiaAnalog) : null)")
	if snapJson == null:
		return null
	var parsed = JSON.parse_string(snapJson)
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return null
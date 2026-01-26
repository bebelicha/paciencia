extends Node

var gazeData = {
	'headYaw': 0.5,
	'headPitch': 0.5,
	'headRoll': 0.5
}
var gazePoint: Vector2 = Vector2(0.5, 0.5)
var gazeStatus: String = ""
var isReady = false
var conversiaConnected = false
var lastAnalogUpdate = 0
var lastGazeUpdate = 0
var analogCount = 0
var lastSnapshotStr = ""
var recentLogs: Array[String] = []
var readyPingTimer: Timer
var lastSelectSeq = -1
var selectQueue:Array = []
const selectQueueMax:=32
var recentSelectSeqs:Array = []
const recentSelectSeqsMax:=20
var preferredTriggerName: String = ""

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
				window.EngineJS.GazeBridge.lastAnalog = window.EngineJS.GazeBridge.lastAnalog || {};
				window.EngineJS.GazeBridge.lastGaze = window.EngineJS.GazeBridge.lastGaze || { x: 0.5, y: 0.5, status: '', timestamp: Date.now() };
				window.EngineJS.GazeBridge.lastSelect = window.EngineJS.GazeBridge.lastSelect || null;
				window.EngineJS.GazeBridge.lastSelectSeq = window.EngineJS.GazeBridge.lastSelectSeq || 0;
				window.EngineJS.GazeBridge.selectQueue = window.EngineJS.GazeBridge.selectQueue || [];
				window.EngineJS.GazeBridge.primaryTrigger = window.EngineJS.GazeBridge.primaryTrigger || '';
				window.addEventListener('message', function(ev) {
					var msg = ev.data;
					if (!msg || typeof msg.type !== 'string') return;
					if (msg.type === 'init') {
						window.EngineJS.GazeBridge.connected = true;
						if (Array.isArray(msg.triggers)) {
							for (var i = 0; i < msg.triggers.length; i++) {
								var trig = msg.triggers[i];
								if (trig && trig.primary) {
									window.EngineJS.GazeBridge.primaryTrigger = trig.id || '';
									break;
								}
							}
						}
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
						return;
					}
					if (msg.type === 'gazeData' && msg.data) {
						var gx = Number(msg.data.x);
						var gy = Number(msg.data.y);
						if (isFinite(gx) && isFinite(gy)) {
							window.EngineJS.GazeBridge.lastGaze = { x: gx, y: gy, status: msg.data.status || '', timestamp: Date.now() };
						}
						return;
					}
					if (msg.type === 'trigger') {
						var seq = Number(msg.seq);
						if (!isFinite(seq)) {
							seq = (window.EngineJS.GazeBridge.lastSelectSeq || 0) + 1;
						}
						var nowTs = Date.now();
						var payload = {
							seq: seq,
							name: msg.name || '',
							state: msg.state || '',
							kind: msg.kind || '',
							label: msg.label || '',
							level: msg.level,
							primary: window.EngineJS.GazeBridge.primaryTrigger || '',
							timestamp: msg.timestamp || nowTs,
							recvTimestamp: nowTs,
							latencyMs: nowTs - (msg.timestamp || nowTs)
						};
						window.EngineJS.GazeBridge.lastSelectSeq = seq;
						window.EngineJS.GazeBridge.lastSelect = payload;
						window.EngineJS.GazeBridge.selectQueue.push(payload);
						try {
							window.parent.postMessage({ type: 'triggerAck', seq: seq, timestamp: Date.now(), triggerTimestamp: msg.timestamp || 0 }, '*');
						} catch (e) {}
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
		snap = {}
	if snap.size() > 0:
		lastAnalogUpdate = Time.get_ticks_msec()
	if conversiaConnected:
		stopReadyPing()
	lastSnapshotStr = str(snap)
	var now = Time.get_ticks_msec()
	var yawVal = null
	if snap.has("headYaw"):
		yawVal = snap["headYaw"]
	elif snap.has("headRoll"):
		yawVal = snap["headRoll"]
	var pitchVal = null
	if snap.has("headPitch"):
		pitchVal = snap["headPitch"]
	elif snap.has("headYaw"):
		pitchVal = snap["headYaw"]
	if yawVal != null:
		gazeData['headYaw'] = yawVal
		lastAnalogUpdate = now
	if pitchVal != null:
		gazeData['headPitch'] = pitchVal
		lastAnalogUpdate = now
	if snap.has("headRoll"):
		gazeData['headRoll'] = snap['headRoll']
		lastAnalogUpdate = now
	if snap.size() > 0:
		analogCount += 1
	pushLog(now)
	pullGazeSnapshot()
	pullSelectEvent()

func receiveAnalogData(data: Dictionary):
	if data.has('name') and data.has('value'):
		gazeData[data['name']] = data['value']
		if data['name'] == 'headYaw' or data['name'] == 'headPitch' or data['name'] == 'headRoll':
			lastAnalogUpdate = Time.get_ticks_msec()

func isHeadTrackingActive() -> bool:
	var currentTime = Time.get_ticks_msec()
	return (currentTime - lastAnalogUpdate) < 2500

func isGazeReliable() -> bool:
	if not conversiaConnected:
		return false
	var currentTime = Time.get_ticks_msec()
	if (currentTime - lastGazeUpdate) > 700:
		return false
	var statusLower = gazeStatus.to_lower()
	if statusLower == "ok" or statusLower == "tracking":
		return true
	return statusLower == ""

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

func isGazeActive() -> bool:
	var currentTime = Time.get_ticks_msec()
	return (currentTime - lastGazeUpdate) < 500

func getGazePoint() -> Vector2:
	return gazePoint

func popSelectEvent() -> Dictionary:
	if selectQueue.size() == 0:
		return {}
	return selectQueue.pop_front()

func enqueueSelectEvent(evt: Dictionary):
	selectQueue.append(evt)
	if selectQueue.size() > selectQueueMax:
		selectQueue.pop_front()

func getSnapshot():
	var snapJson = JavaScriptBridge.eval("(window.EngineJS && window.EngineJS.GazeBridge && window.EngineJS.GazeBridge.lastAnalog) ? JSON.stringify(window.EngineJS.GazeBridge.lastAnalog) : (window.__conversiaAnalog ? JSON.stringify(window.__conversiaAnalog) : null)")
	if snapJson == null:
		return null
	var parsed = JSON.parse_string(snapJson)
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return null

func pullGazeSnapshot():
	var gazeJson = JavaScriptBridge.eval("(window.EngineJS && window.EngineJS.GazeBridge && window.EngineJS.GazeBridge.lastGaze) ? JSON.stringify(window.EngineJS.GazeBridge.lastGaze) : null")
	if gazeJson == null:
		return
	var parsed = JSON.parse_string(gazeJson)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	if not parsed.has("x") or not parsed.has("y"):
		return
	var gx = clamp(float(parsed.get("x", 0.5)), 0.0, 1.0)
	var gy = clamp(float(parsed.get("y", 0.5)), 0.0, 1.0)
	gazePoint = Vector2(gx, gy)
	gazeStatus = str(parsed.get("status", ""))
	lastGazeUpdate = Time.get_ticks_msec()

func pullSelectEvent():
	var selectJson = JavaScriptBridge.eval("(window.EngineJS && window.EngineJS.GazeBridge && window.EngineJS.GazeBridge.selectQueue && window.EngineJS.GazeBridge.selectQueue.length) ? JSON.stringify(window.EngineJS.GazeBridge.selectQueue.shift()) : null")
	if selectJson == null:
		return
	var parsed = JSON.parse_string(selectJson)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var seq = int(parsed.get("seq", -1))
	if seq == -1:
		return
	lastSelectSeq = seq
	if recentSelectSeqs.has(seq):
		return
	recentSelectSeqs.append(seq)
	if recentSelectSeqs.size() > recentSelectSeqsMax:
		recentSelectSeqs.pop_front()
	var primaryVal = parsed.get("primary", "")
	if typeof(primaryVal) == TYPE_STRING:
		var cleaned = primaryVal.strip_edges()
		if cleaned.length() > 0:
			preferredTriggerName = cleaned
	if preferredTriggerName == "":
		pass
	var state = str(parsed.get("state", ""))
	var name = str(parsed.get("name", ""))
	var kind = str(parsed.get("kind", ""))
	if preferredTriggerName == "" or name != preferredTriggerName:
		return
	if kind != "" and kind != "movement":
		return
	if state == "start" or state == "end":
		var evtTimestamp = int(parsed.get("timestamp", 0))
		enqueueSelectEvent({
			"seq": seq,
			"timestamp": evtTimestamp,
			"latencyMs": int(parsed.get("latencyMs", -1)),
			"name": name,
			"kind": kind,
			"state": state,
			"level": parsed.get("level", null),
			"label": parsed.get("label", "")
		})
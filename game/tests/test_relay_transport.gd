@warning_ignore_start("untyped_declaration")
extends RefCounted

const RelayTransport = preload("res://scripts/net/relay_transport.gd")
const Wire = preload("res://scripts/net/wire.gd")

func cases() -> Array[Callable]:
	return [test_never_connected, test_ping_due, test_pong_recorded, test_buffers_fit_frame_cap, test_silence, test_patient_silence, test_refused_send_closes]

func test_never_connected(runner) -> bool:
	var transport = RelayTransport.new()
	runner.check(transport.poll().is_empty(), "T1 poll on never-connected is empty")
	runner.check(not transport.closed() and not transport.is_open(), "T1 never-connected is neither open nor closed")
	transport.send_text("x")
	transport.close()
	runner.check(transport.take_ping(10_000_000) == "", "T1 no ping without an open socket")
	return true

func test_ping_due(runner) -> bool:
	var transport = RelayTransport.new()
	runner.check(not transport.ping_due(5_000_000), "T2 no ping before the first send")
	transport._sent_any = true
	runner.check(transport.ping_due(1_000_000), "T2 first ping due after 1 s")
	transport._last_ping = 1_000_000
	runner.check(not transport.ping_due(1_999_999) and transport.ping_due(2_000_000), "T2 pings are 1 s apart")
	return true

func test_pong_recorded(runner) -> bool:
	var now := [1000]
	var transport = RelayTransport.new(func() -> int: return now[0])
	now[0] = 1500
	runner.check(transport._take_pong(Wire.encode({"type": "pong", "t": 1000})), "T3 pong consumed")
	runner.check(transport.rtt_samples() == PackedInt64Array([500]), "T3 rtt is clock difference in microseconds")
	runner.check(not transport._take_pong(Wire.encode({"type": "left", "seat": 2, "after_tick": 5})), "T3 other frames pass through")
	return true

func test_buffers_fit_frame_cap(runner) -> bool:
	var transport = RelayTransport.new()
	runner.check(transport._peer.inbound_buffer_size >= Wire.MAX_FRAME_BYTES and transport._peer.outbound_buffer_size >= Wire.MAX_FRAME_BYTES, "T4 WebSocket buffers hold a 65,536-byte frame")
	return true

func test_silence(runner) -> bool:
	var transport = RelayTransport.new()
	runner.check(not transport.silent(60_000_000), "T5 never sent is never silent")
	transport._sent_any = true
	transport._last_rx = 1_000_000
	runner.check(not transport.silent(5_999_999) and transport.silent(6_000_000), "T5 silent after exactly 5 s without a frame")
	transport._last_rx = 6_000_000
	runner.check(not transport.silent(10_999_999), "T5 a received frame restarts the window")
	return true

func test_patient_silence(runner) -> bool:
	var transport = RelayTransport.new()
	transport._sent_any = true
	transport._last_rx = 0
	transport.patient = true
	runner.check(not transport.silent(5_000_000) and not transport.silent(899_999_999), "T6 patient waits out a quiet lobby")
	runner.check(transport.silent(900_000_000), "T6 patient is silent at the lobby expiry")
	transport.patient = false
	runner.check(transport.silent(5_000_000), "T6 normal rule is 5 s again")
	return true

func _stalled_pair(runner, server: TCPServer, now: Array) -> Array:
	var transport = RelayTransport.new(func() -> int: return now[0])
	transport.connect_to("ws://127.0.0.1:%d/ws" % server.get_local_port())
	var peer := WebSocketPeer.new()
	var accepted: bool = false
	for i in 400:
		transport.poll()
		if not accepted and server.is_connection_available():
			peer.accept_stream(server.take_connection())
			accepted = true
		if accepted: peer.poll()
		if transport.is_open(): break
		OS.delay_msec(5)
	runner.check(transport.is_open(), "T7 handshake")
	return [transport, peer]

func test_refused_send_closes(runner) -> bool:
	var server := TCPServer.new()
	runner.check(server.listen(0, "127.0.0.1") == OK, "T7 test server listens")
	var now := [0]
	var big: String = "x".repeat(60000)
	var first: Array = _stalled_pair(runner, server, now)
	Engine.print_error_messages = false
	for i in 2000:
		first[0].send_text(big)
		if first[0].closed(): break
	Engine.print_error_messages = true
	runner.check(first[0].closed() and not first[0].is_open(), "T7 a refused send closes the socket, so the match ends as relay lost")
	first[0].close()
	first[1].close()
	var second: Array = _stalled_pair(runner, server, now)
	var transport = second[0]
	var ping: String = Wire.encode({"type": "ping", "t": 2_000_000})
	# Each send also writes to the socket, so a fill is refused only once the kernel's self-growing buffers are full; a zero queue refuses every frame on any host.
	transport._peer.max_queued_packets = 0
	Engine.print_error_messages = false
	var raw: Error = transport._peer.send_text(ping)
	Engine.print_error_messages = true
	runner.check(raw != OK, "T7 a zero queue refuses the ping")
	runner.check(not transport.closed(), "T7 raw sends alone do not close the transport")
	transport._sent_any = true
	transport._last_ping = 0
	now[0] = 2_000_000
	Engine.print_error_messages = false
	transport.poll()
	Engine.print_error_messages = true
	runner.check(transport.closed(), "T7 a refused ping closes the transport too")
	transport.close()
	second[1].close()
	server.stop()
	return true

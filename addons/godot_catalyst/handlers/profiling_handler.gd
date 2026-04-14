@tool
class_name CatalystProfilingHandler
extends RefCounted
## Handles performance monitoring, profiling, and bottleneck detection.

var _plugin: EditorPlugin
var _monitor_thresholds := {}


func setup(plugin: EditorPlugin) -> void:
	_plugin = plugin


# --- profiling.get_metrics ---
func get_metrics(params: Dictionary) -> Dictionary:
	var metrics := {
		"fps": Performance.get_monitor(Performance.TIME_FPS),
		"frame_time_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_time_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"navigation_time_ms": Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS) * 1000.0,
		"memory": {
			"static_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / (1024.0 * 1024.0),
			"static_max_mb": Performance.get_monitor(Performance.MEMORY_STATIC_MAX) / (1024.0 * 1024.0),
			"message_buffer_max_kb": Performance.get_monitor(Performance.MEMORY_MESSAGE_BUFFER_MAX) / 1024.0,
		},
		"objects": {
			"count": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
			"resource_count": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
			"node_count": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			"orphan_node_count": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		},
		"render": {
			"total_objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
			"total_primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
			"total_draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			"video_memory_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / (1024.0 * 1024.0),
		},
		"physics": {
			"active_2d_objects": int(Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS)),
			"collision_2d_pairs": int(Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS)),
			"island_2d_count": int(Performance.get_monitor(Performance.PHYSICS_2D_ISLAND_COUNT)),
			"active_3d_objects": int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)),
			"collision_3d_pairs": int(Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS)),
			"island_3d_count": int(Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT)),
		},
		"audio": {
			"output_latency_ms": Performance.get_monitor(Performance.AUDIO_OUTPUT_LATENCY) * 1000.0,
		},
		"navigation": {
			"active_maps": int(Performance.get_monitor(Performance.NAVIGATION_ACTIVE_MAPS)),
			"region_count": int(Performance.get_monitor(Performance.NAVIGATION_REGION_COUNT)),
			"agent_count": int(Performance.get_monitor(Performance.NAVIGATION_AGENT_COUNT)),
			"link_count": int(Performance.get_monitor(Performance.NAVIGATION_LINK_COUNT)),
			"obstacle_count": int(Performance.get_monitor(Performance.NAVIGATION_OBSTACLE_COUNT)),
		},
	}
	return {"success": true, "metrics": metrics}


# --- profiling.get_profiler_data ---
func get_profiler_data(params: Dictionary) -> Dictionary:
	# Gather a snapshot of performance data
	var data := {
		"process_time_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_process_time_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"navigation_process_time_ms": Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS) * 1000.0,
		"fps": Performance.get_monitor(Performance.TIME_FPS),
		"render": {
			"objects_in_frame": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
			"primitives_in_frame": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
			"draw_calls_in_frame": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			"video_mem_used_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / (1024.0 * 1024.0),
		},
	}
	return {"success": true, "profiler_data": data}


# --- profiling.detect_bottlenecks ---
func detect_bottlenecks(params: Dictionary) -> Dictionary:
	var issues := []
	var fps := Performance.get_monitor(Performance.TIME_FPS)
	var frame_time := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics_time := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var draw_calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var primitives := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var objects := int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var node_count := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var static_mem_mb := Performance.get_monitor(Performance.MEMORY_STATIC) / (1024.0 * 1024.0)
	var video_mem_mb := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / (1024.0 * 1024.0)

	# FPS check
	if fps < 30:
		issues.append({"severity": "critical", "category": "fps", "message": "FPS is %.1f (below 30)" % fps})
	elif fps < 60:
		issues.append({"severity": "warning", "category": "fps", "message": "FPS is %.1f (below 60)" % fps})

	# Frame time
	if frame_time > 33:
		issues.append({"severity": "critical", "category": "frame_time", "message": "Frame time %.1fms exceeds 33ms budget" % frame_time})
	elif frame_time > 16.6:
		issues.append({"severity": "warning", "category": "frame_time", "message": "Frame time %.1fms exceeds 16.6ms budget (60fps)" % frame_time})

	# Physics
	if physics_time > 16:
		issues.append({"severity": "warning", "category": "physics", "message": "Physics process time %.1fms is high" % physics_time})

	# Draw calls
	if draw_calls > 2000:
		issues.append({"severity": "critical", "category": "draw_calls", "message": "%d draw calls — consider batching, instancing, or reducing objects" % draw_calls})
	elif draw_calls > 500:
		issues.append({"severity": "warning", "category": "draw_calls", "message": "%d draw calls — monitor for performance impact" % draw_calls})

	# Primitives
	if primitives > 1000000:
		issues.append({"severity": "warning", "category": "primitives", "message": "%d primitives in frame — consider LOD or mesh simplification" % primitives})

	# Orphan nodes
	if orphans > 0:
		issues.append({"severity": "warning", "category": "memory_leak", "message": "%d orphan nodes detected — possible memory leak" % orphans})

	# Node count
	if node_count > 10000:
		issues.append({"severity": "warning", "category": "node_count", "message": "%d nodes in tree — consider object pooling or LOD" % node_count})

	# Memory
	if static_mem_mb > 512:
		issues.append({"severity": "warning", "category": "memory", "message": "Static memory %.0fMB — high usage" % static_mem_mb})

	if video_mem_mb > 1024:
		issues.append({"severity": "warning", "category": "video_memory", "message": "Video memory %.0fMB — consider texture compression or resolution reduction" % video_mem_mb})

	var overall := "healthy"
	if issues.any(func(i): return i["severity"] == "critical"):
		overall = "critical"
	elif issues.size() > 0:
		overall = "needs_attention"

	return {
		"success": true,
		"overall_status": overall,
		"issue_count": issues.size(),
		"issues": issues,
		"summary": {
			"fps": fps,
			"frame_time_ms": frame_time,
			"draw_calls": draw_calls,
			"node_count": node_count,
			"orphan_nodes": orphans,
			"static_memory_mb": static_mem_mb,
			"video_memory_mb": video_mem_mb,
		},
	}


# --- profiling.monitor ---
func monitor(params: Dictionary) -> Dictionary:
	_monitor_thresholds = {
		"fps_min": params.get("fps_min", 30),
		"frame_time_max_ms": params.get("frame_time_max_ms", 33),
		"memory_max_mb": params.get("memory_max_mb", 512),
		"draw_calls_max": params.get("draw_calls_max", 1000),
	}

	# Return current snapshot with threshold comparison
	var fps := Performance.get_monitor(Performance.TIME_FPS)
	var frame_time := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var memory_mb := Performance.get_monitor(Performance.MEMORY_STATIC) / (1024.0 * 1024.0)
	var draw_calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))

	var alerts := []
	if fps < float(_monitor_thresholds["fps_min"]):
		alerts.append("FPS %.1f below threshold %d" % [fps, _monitor_thresholds["fps_min"]])
	if frame_time > float(_monitor_thresholds["frame_time_max_ms"]):
		alerts.append("Frame time %.1fms exceeds threshold %dms" % [frame_time, _monitor_thresholds["frame_time_max_ms"]])
	if memory_mb > float(_monitor_thresholds["memory_max_mb"]):
		alerts.append("Memory %.0fMB exceeds threshold %dMB" % [memory_mb, _monitor_thresholds["memory_max_mb"]])
	if draw_calls > int(_monitor_thresholds["draw_calls_max"]):
		alerts.append("Draw calls %d exceeds threshold %d" % [draw_calls, _monitor_thresholds["draw_calls_max"]])

	return {
		"success": true,
		"thresholds": _monitor_thresholds,
		"current": {
			"fps": fps,
			"frame_time_ms": frame_time,
			"memory_mb": memory_mb,
			"draw_calls": draw_calls,
		},
		"alerts": alerts,
		"alert_count": alerts.size(),
	}


# ---------- Helpers ----------

func _error(code: int, message: String, data: Variant = null) -> Dictionary:
	var err := {"error": {"code": code, "message": message}}
	if data != null:
		err["error"]["data"] = data
	return err

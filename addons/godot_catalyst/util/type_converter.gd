@tool
class_name CatalystTypeConverter
extends RefCounted
## Converts between JSON representations and Godot Variant types.
##
## JSON encoding: complex types use { "type": "TypeName", "value": [...] }
## Simple types (int, float, String, bool) pass through as native JSON.


static func json_to_variant(json_value: Variant) -> Variant:
	if json_value is Dictionary:
		var dict: Dictionary = json_value
		if dict.has("type") and dict.has("value"):
			return _typed_to_variant(str(dict["type"]), dict["value"])
		# Plain dictionary — recurse on values
		var result := {}
		for key in dict:
			result[key] = json_to_variant(dict[key])
		return result
	elif json_value is Array:
		var arr: Array = json_value
		var result := []
		for item in arr:
			result.append(json_to_variant(item))
		return result
	else:
		return json_value


static func variant_to_json(value: Variant) -> Variant:
	match typeof(value):
		TYPE_VECTOR2:
			var v: Vector2 = value
			return {"type": "Vector2", "value": [v.x, v.y]}
		TYPE_VECTOR2I:
			var v: Vector2i = value
			return {"type": "Vector2i", "value": [v.x, v.y]}
		TYPE_VECTOR3:
			var v: Vector3 = value
			return {"type": "Vector3", "value": [v.x, v.y, v.z]}
		TYPE_VECTOR3I:
			var v: Vector3i = value
			return {"type": "Vector3i", "value": [v.x, v.y, v.z]}
		TYPE_VECTOR4:
			var v: Vector4 = value
			return {"type": "Vector4", "value": [v.x, v.y, v.z, v.w]}
		TYPE_VECTOR4I:
			var v: Vector4i = value
			return {"type": "Vector4i", "value": [v.x, v.y, v.z, v.w]}
		TYPE_COLOR:
			var c: Color = value
			return {"type": "Color", "value": [c.r, c.g, c.b, c.a]}
		TYPE_RECT2:
			var r: Rect2 = value
			return {"type": "Rect2", "value": [r.position.x, r.position.y, r.size.x, r.size.y]}
		TYPE_RECT2I:
			var r: Rect2i = value
			return {"type": "Rect2i", "value": [r.position.x, r.position.y, r.size.x, r.size.y]}
		TYPE_TRANSFORM2D:
			var t: Transform2D = value
			return {"type": "Transform2D", "value": [t.x.x, t.x.y, t.y.x, t.y.y, t.origin.x, t.origin.y]}
		TYPE_TRANSFORM3D:
			var t: Transform3D = value
			var b := t.basis
			return {"type": "Transform3D", "value": {
				"basis": [b.x.x, b.x.y, b.x.z, b.y.x, b.y.y, b.y.z, b.z.x, b.z.y, b.z.z],
				"origin": [t.origin.x, t.origin.y, t.origin.z],
			}}
		TYPE_BASIS:
			var b: Basis = value
			return {"type": "Basis", "value": [b.x.x, b.x.y, b.x.z, b.y.x, b.y.y, b.y.z, b.z.x, b.z.y, b.z.z]}
		TYPE_QUATERNION:
			var q: Quaternion = value
			return {"type": "Quaternion", "value": [q.x, q.y, q.z, q.w]}
		TYPE_AABB:
			var a: AABB = value
			return {"type": "AABB", "value": [a.position.x, a.position.y, a.position.z, a.size.x, a.size.y, a.size.z]}
		TYPE_PLANE:
			var p: Plane = value
			return {"type": "Plane", "value": [p.normal.x, p.normal.y, p.normal.z, p.d]}
		TYPE_NODE_PATH:
			return {"type": "NodePath", "value": str(value)}
		TYPE_STRING_NAME:
			return str(value)
		TYPE_DICTIONARY:
			var dict: Dictionary = value
			var result := {}
			for key in dict:
				result[str(key)] = variant_to_json(dict[key])
			return result
		TYPE_ARRAY:
			var arr: Array = value
			var result := []
			for item in arr:
				result.append(variant_to_json(item))
			return result
		_:
			return value


static func _typed_to_variant(type_name: String, val: Variant) -> Variant:
	match type_name:
		"Vector2":
			var a: Array = val
			return Vector2(a[0], a[1])
		"Vector2i":
			var a: Array = val
			return Vector2i(int(a[0]), int(a[1]))
		"Vector3":
			var a: Array = val
			return Vector3(a[0], a[1], a[2])
		"Vector3i":
			var a: Array = val
			return Vector3i(int(a[0]), int(a[1]), int(a[2]))
		"Vector4":
			var a: Array = val
			return Vector4(a[0], a[1], a[2], a[3])
		"Vector4i":
			var a: Array = val
			return Vector4i(int(a[0]), int(a[1]), int(a[2]), int(a[3]))
		"Color":
			var a: Array = val
			return Color(a[0], a[1], a[2], a[3] if a.size() > 3 else 1.0)
		"Rect2":
			var a: Array = val
			return Rect2(a[0], a[1], a[2], a[3])
		"Rect2i":
			var a: Array = val
			return Rect2i(int(a[0]), int(a[1]), int(a[2]), int(a[3]))
		"Transform2D":
			var a: Array = val
			return Transform2D(Vector2(a[0], a[1]), Vector2(a[2], a[3]), Vector2(a[4], a[5]))
		"Transform3D":
			if val is Dictionary:
				var d: Dictionary = val
				var b: Array = d.get("basis", [1,0,0, 0,1,0, 0,0,1])
				var o: Array = d.get("origin", [0,0,0])
				return Transform3D(
					Basis(Vector3(b[0], b[1], b[2]), Vector3(b[3], b[4], b[5]), Vector3(b[6], b[7], b[8])),
					Vector3(o[0], o[1], o[2]),
				)
			return Transform3D()
		"Basis":
			var a: Array = val
			return Basis(Vector3(a[0], a[1], a[2]), Vector3(a[3], a[4], a[5]), Vector3(a[6], a[7], a[8]))
		"Quaternion":
			var a: Array = val
			return Quaternion(a[0], a[1], a[2], a[3])
		"AABB":
			var a: Array = val
			return AABB(Vector3(a[0], a[1], a[2]), Vector3(a[3], a[4], a[5]))
		"Plane":
			var a: Array = val
			return Plane(Vector3(a[0], a[1], a[2]), a[3])
		"NodePath":
			return NodePath(str(val))
		_:
			push_warning("[Godot Catalyst] Unknown type '%s' in type conversion" % type_name)
			return val

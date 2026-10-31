class_name MultiMeshCopy
extends RefCounted

# Godot 4.7.2 MultiMesh.duplicate() assigns the buffer before instance_count, so
# the copy is built explicitly: format flags first, then the count, then the data.
static func of(source: MultiMesh) -> MultiMesh:
	var copy := MultiMesh.new()
	copy.transform_format = source.transform_format
	copy.use_colors = source.use_colors
	copy.use_custom_data = source.use_custom_data
	copy.mesh = source.mesh
	copy.instance_count = source.instance_count
	copy.visible_instance_count = source.visible_instance_count
	copy.custom_aabb = source.custom_aabb
	# The dummy renderer keeps no buffer, and set_buffer rejects an empty one for a sized copy.
	var data := source.buffer
	if not data.is_empty():
		copy.buffer = data
	return copy

class_name MultiMeshCopy
extends RefCounted

# Godot 4.7.2 MultiMesh.duplicate() applies the buffer before instance_count,
# which drops instance transforms. Copy the properties in a safe order instead.
static func duplicate_multimesh(source: MultiMesh) -> MultiMesh:
	if source == null:
		return null
	var copy := MultiMesh.new()
	copy.transform_format = source.transform_format
	copy.use_colors = source.use_colors
	copy.use_custom_data = source.use_custom_data
	copy.mesh = source.mesh
	copy.instance_count = source.instance_count
	copy.visible_instance_count = source.visible_instance_count
	copy.custom_aabb = source.custom_aabb
	# A renderer without instance storage (the headless dummy) reports an empty
	# buffer; there is nothing to copy, and setting it would log a size mismatch.
	var buffer := source.buffer
	if not buffer.is_empty():
		copy.buffer = buffer
	return copy

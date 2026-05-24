extends RefCounted
class_name MeshFactory

# ╔══════════════════════════════════════════════════════════════╗
# ║  程序化网格工厂                                                ║
# ║  两条路:                                                     ║
# ║   A) SurfaceTool — 命令式,像 OpenGL 立即模式,自动算法线/索引   ║
# ║   B) ArrayMesh + PackedArray — 直接喂顶点数组,最快最底层        ║
# ╚══════════════════════════════════════════════════════════════╝

# ── A. SurfaceTool:手搓立方体 ───────────────────────────────

static func make_cube(size: float = 1.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var s := size * 0.5
	# 8 个角
	var v := [
		Vector3(-s, -s, -s), Vector3(s, -s, -s), Vector3(s, s, -s), Vector3(-s, s, -s),
		Vector3(-s, -s, s), Vector3(s, -s, s), Vector3(s, s, s), Vector3(-s, s, s),
	]
	# 6 个面,每面两个三角(逆时针朝外)
	var faces := [
		[0, 1, 2, 3], [5, 4, 7, 6], [4, 0, 3, 7],
		[1, 5, 6, 2], [4, 5, 1, 0], [3, 2, 6, 7],
	]
	for f in faces:
		_add_quad(st, v[f[0]], v[f[1]], v[f[2]], v[f[3]])
	st.generate_normals()    # 自动算法线
	return st.commit()

static func _add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	st.set_uv(Vector2(0, 0)); st.add_vertex(a)
	st.set_uv(Vector2(1, 0)); st.add_vertex(b)
	st.set_uv(Vector2(1, 1)); st.add_vertex(c)
	st.set_uv(Vector2(0, 0)); st.add_vertex(a)
	st.set_uv(Vector2(1, 1)); st.add_vertex(c)
	st.set_uv(Vector2(0, 1)); st.add_vertex(d)

# ── B. UV 球(经纬度细分)────────────────────────────────────

static func make_sphere(radius: float = 1.0, rings: int = 24, segments: int = 32, displace := 0.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var noise: FastNoiseLite
	if displace > 0.0:
		noise = FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
		noise.frequency = 1.2

	# 生成顶点网格(rings+1) x (segments+1)
	var verts := []
	for r in rings + 1:
		var phi := PI * float(r) / rings           # 0..PI
		var row := []
		for sgmt in segments + 1:
			var theta := TAU * float(sgmt) / segments   # 0..2PI
			var dir := Vector3(
				sin(phi) * cos(theta),
				cos(phi),
				sin(phi) * sin(theta)
			)
			var rad := radius
			if noise:
				rad += noise.get_noise_3dv(dir * 2.0) * displace
			row.append(dir * rad)
		verts.append(row)

	# 连三角
	for r in rings:
		for sgmt in segments:
			var a: Vector3 = verts[r][sgmt]
			var b: Vector3 = verts[r][sgmt + 1]
			var c: Vector3 = verts[r + 1][sgmt + 1]
			var d: Vector3 = verts[r + 1][sgmt]
			_tri(st, a, b, c)
			_tri(st, a, c, d)

	st.generate_normals()
	return st.commit()

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)

# ── C. ArrayMesh 直接构造:波浪地形(展示最底层 API)─────────────

static func make_terrain(grid: int = 64, scale: float = 6.0, height: float = 1.2) -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.08

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	# 顶点:grid x grid
	for z in grid:
		for x in grid:
			var fx := (float(x) / (grid - 1) - 0.5) * scale
			var fz := (float(z) / (grid - 1) - 0.5) * scale
			var h := noise.get_noise_2d(x, z) * height
			verts.append(Vector3(fx, h, fz))
			uvs.append(Vector2(float(x) / grid, float(z) / grid))
			normals.append(Vector3.UP)   # 占位,下面重算

	# 索引:每格两个三角
	for z in grid - 1:
		for x in grid - 1:
			var i := z * grid + x
			indices.append(i); indices.append(i + grid); indices.append(i + 1)
			indices.append(i + 1); indices.append(i + grid); indices.append(i + grid + 1)

	# 重算法线(用相邻顶点叉乘)
	for z in grid:
		for x in grid:
			var i := z * grid + x
			var here := verts[i]
			var right := verts[i + 1] if x < grid - 1 else here
			var down := verts[i + grid] if z < grid - 1 else here
			var n := (right - here).cross(down - here).normalized()
			if n.length() > 0:
				normals[i] = -n if n.y < 0 else n

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

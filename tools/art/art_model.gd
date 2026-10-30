class_name ArtModel
extends RefCounted
## A model for the offline merge-art renderer (sdf_render.gdshader): a list of
## primitives combined in order — smooth union by default, or cut / intersect /
## paint — each with a colour and gloss. Units: the model sits around the origin
## within a radius of about 1 (y is up, +z faces the camera).
##
##   var m := ArtModel.new()
##   m.ell(Vector3(0, 0, 0), Vector3(0.6, 0.45, 0.5), "a0582c").k(0.1)
##   m.sphere(Vector3(0.3, 0.2, 0.4), 0.08, "ffffff").mirror()

const MAXP := 128
const T_SPHERE := 0
const T_ELLIPSOID := 1
const T_BOX := 2
const T_CAPSULE := 3
const T_TORUS := 4
const T_CYLINDER := 5
const T_CONE := 6
const T_PLANE := 7
const T_TAPER := 8

var prims: Array[Prim] = []
var cam_pos := Vector3(0, 1.35, 3.6)
var cam_target := Vector3.ZERO
var fov := 0.36
var bound := 1.6
var exposure := 1.0
var _group_next := false


class Prim:
	extends RefCounted
	var type := 0
	var pos := Vector3.ZERO
	var r := 0.0
	var size := Vector3.ONE
	var shell_t := 0.0
	var rot := Quaternion.IDENTITY
	var col := Color.WHITE
	var gloss_v := 0.35
	var op := 0
	var blend := 0.0
	var mirror_x := false

	## Smooth blending radius with what came before.
	func k(v: float) -> Prim:
		blend = v
		return self

	## Cut this shape out of the model (the cut surface takes this colour unless keep_colour).
	func sub(v := 0.0, keep_colour := false) -> Prim:
		op = 1
		blend = v
		if keep_colour:
			col = Color(-1, 0, 0)
		return self

	## Keep only the part of the model inside this shape.
	func inter(v := 0.0) -> Prim:
		op = 2
		blend = v
		return self

	## Paint the model's surface inside this shape (shape unchanged); v = soft edge.
	func paint(v := 0.01) -> Prim:
		op = 3
		blend = v
		return self

	## Also place a copy mirrored at -x.
	func mirror() -> Prim:
		mirror_x = true
		return self

	## Hollow it to a shell of this thickness.
	func shell(t: float) -> Prim:
		shell_t = t
		return self

	func gloss(g: float) -> Prim:
		gloss_v = g
		return self

	## Rotation in degrees (x, y, z), applied to the primitive about its centre.
	func rot_deg(e: Vector3) -> Prim:
		rot = Quaternion.from_euler(Vector3(deg_to_rad(e.x), deg_to_rad(e.y), deg_to_rad(e.z)))
		return self

	## Points the primitive's local +y along dir.
	func along(dir: Vector3) -> Prim:
		var d := dir.normalized()
		var axis := Vector3.UP.cross(d)
		if axis.length() < 1e-5:
			rot = Quaternion.IDENTITY if d.y > 0 else Quaternion(Vector3.RIGHT, PI)
		else:
			rot = Quaternion(axis.normalized(), Vector3.UP.angle_to(d))
		return self


static func c(v) -> Color:
	return v if v is Color else Color(str(v))


func _add(type: int, p: Vector3, col) -> Prim:
	var pr := Prim.new()
	pr.type = type
	pr.pos = p
	pr.col = c(col)
	if _group_next:
		pr.op = 4
		_group_next = false
	prims.append(pr)
	return pr


## Shapes added between begin() and end() are combined on their own (cuts and
## intersections only affect the group), then blended into the model with k.
func begin() -> void:
	_group_next = true


func end(k := 0.0) -> void:
	var pr := Prim.new()
	pr.op = 5
	pr.blend = k
	prims.append(pr)


func sphere(p: Vector3, radius: float, col) -> Prim:
	var pr := _add(T_SPHERE, p, col)
	pr.r = radius
	return pr


## Ellipsoid with half axes `half`.
func ell(p: Vector3, half: Vector3, col) -> Prim:
	var pr := _add(T_ELLIPSOID, p, col)
	pr.size = half
	return pr


## Box with half extents `half` and edge rounding `round`.
func box(p: Vector3, half: Vector3, round: float, col) -> Prim:
	var pr := _add(T_BOX, p, col)
	pr.size = half
	pr.r = round
	return pr


## Capsule along y: half length of the straight part, radius.
func capsule(p: Vector3, half_len: float, radius: float, col) -> Prim:
	var pr := _add(T_CAPSULE, p, col)
	pr.size = Vector3(0, half_len, 0)
	pr.r = radius
	return pr


## Capsule between two points.
func segment(a: Vector3, b: Vector3, radius: float, col) -> Prim:
	return capsule((a + b) * 0.5, a.distance_to(b) * 0.5, radius, col).along(b - a)


## Torus lying in the xz plane.
func torus(p: Vector3, major: float, minor: float, col) -> Prim:
	var pr := _add(T_TORUS, p, col)
	pr.size = Vector3(major, 0, 0)
	pr.r = minor
	return pr


## Cylinder along y with rounded edges.
func cyl(p: Vector3, radius: float, half_h: float, round: float, col) -> Prim:
	var pr := _add(T_CYLINDER, p, col)
	pr.size = Vector3(radius, half_h, 0)
	pr.r = round
	return pr


## Cone frustum along y (bottom radius, top radius) with rounded edges.
func cone(p: Vector3, r_bottom: float, r_top: float, half_h: float, round: float, col) -> Prim:
	var pr := _add(T_CONE, p, col)
	pr.size = Vector3(r_bottom, half_h, r_top)
	pr.r = round
	return pr


## Capsule whose radius changes from bottom to top (limbs, horns, carrots).
func taper(p: Vector3, r_bottom: float, r_top: float, half_len: float, col) -> Prim:
	var pr := _add(T_TAPER, p, col)
	pr.size = Vector3(r_bottom, half_len, r_top)
	return pr


## Half space below the plane through p (rotate it to tilt); use with sub()/inter().
func plane(p: Vector3, col = "ffffff") -> Prim:
	return _add(T_PLANE, p, col)


func apply(mat: ShaderMaterial) -> void:
	assert(prims.size() <= MAXP, "too many primitives")
	var a_pos := PackedVector4Array()
	var a_size := PackedVector4Array()
	var a_rot := PackedVector4Array()
	var a_col := PackedVector4Array()
	var a_info := PackedVector4Array()
	for pr in prims:
		a_pos.append(Vector4(pr.pos.x, pr.pos.y, pr.pos.z, pr.r))
		a_size.append(Vector4(pr.size.x, pr.size.y, pr.size.z, pr.shell_t))
		var inv := pr.rot.inverse()
		a_rot.append(Vector4(inv.x, inv.y, inv.z, inv.w))
		a_col.append(Vector4(pr.col.r, pr.col.g, pr.col.b, pr.gloss_v))
		a_info.append(Vector4(pr.type, pr.op, pr.blend, 1.0 if pr.mirror_x else 0.0))
	for i in MAXP - prims.size():
		for arr in [a_pos, a_size, a_rot, a_col, a_info]:
			arr.append(Vector4.ZERO)
	mat.set_shader_parameter("count", prims.size())
	mat.set_shader_parameter("p_pos", a_pos)
	mat.set_shader_parameter("p_size", a_size)
	mat.set_shader_parameter("p_rot", a_rot)
	mat.set_shader_parameter("p_col", a_col)
	mat.set_shader_parameter("p_info", a_info)
	mat.set_shader_parameter("cam_pos", cam_pos)
	mat.set_shader_parameter("cam_target", cam_target)
	mat.set_shader_parameter("fov", fov)
	mat.set_shader_parameter("bound", bound)
	mat.set_shader_parameter("exposure", exposure)

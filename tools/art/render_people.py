"""Realistic busts of the merge characters, rendered with Blender (Cycles) from
MakeHuman models (MPFB 2 and the CC0 MakeHuman system assets and faceunits).

    tools/art/setup_people_renderer.sh            # once: Blender as a Python module, MPFB, assets
    ~/.cache/luma-people/venv/bin/python tools/art/render_people.py [who ...]
                                                  # -> assets/merge/art/bust_<who>.png, face_<who>.png (~7 min)
    python3 tools/finish_merge_art.py             # round portraits + asset manifest

Each person: phenotype (gender, age, ethnicity, build), a skin, eyes, brows, hair
with a colour, clothes tinted to the character's colour, an optional hat or glasses,
and a friendly smile (faceunits), arms relaxed. The pets stay with the SDF renderer
(tools/art/character_3d.gd).
"""
import math
import os
import sys

import bpy  # noqa: I001  (bpy first: it provides addon_utils and mathutils)
import addon_utils
import mathutils

addon_utils.enable("bl_ext.user_default.mpfb", default_set=True)
from bl_ext.user_default.mpfb.services.humanservice import HumanService  # noqa: E402
from bl_ext.user_default.mpfb.services.locationservice import LocationService  # noqa: E402
from bl_ext.user_default.mpfb.services.targetservice import TargetService  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.environ.get("LUMA_ART_OUT") or os.path.join(ROOT, "assets", "merge", "art")
SIZE = 384

# race: (asian, caucasian, african)
PEOPLE = {
    "nell": dict(g=0.0, age=0.45, race=(0, 1, 0), skin="young_caucasian_female/young_caucasian_female.mhmat",
                 hair="ponytail01", hair_col="c0602e", brows="eyebrow006", eyes="green",
                 clothes=["female_casualsuit02"], tint="e8875f"),
    "tobias": dict(g=1.0, age=0.92, race=(0, 1, 0), skin="old_caucasian_male/old_caucasian_male.mhmat",
                   hair="short04", hair_col="d8d4cc", brows="eyebrow010", eyes="blue",
                   clothes=["male_worksuit01"], tint="3d6fb0", hat="fedora01", hat_col="2f4f7a", weight=0.65),
    "ada": dict(g=0.0, age=0.5, race=(0, 0.25, 0.75), skin="middleage_african_female/middleage_african_female.mhmat",
                hair="ponytail01", hair_col="2a1a12", brows="eyebrow002", eyes="brown",
                clothes=["female_casualsuit02"], tint="f2c14e", chef=True),
    "rafe": dict(g=1.0, age=0.55, race=(0, 1, 0), skin="middleage_caucasian_male/middleage_caucasian_male.mhmat",
                 hair="short02", hair_col="5e4a3a", brows="eyebrow009", eyes="brownlight",
                 clothes=["male_elegantsuit01"], tint="7d5ba6"),
    "juno": dict(g=0.0, age=0.4, race=(0, 0.1, 0.9), skin="young_african_female/young_african_female.mhmat",
                 hair="afro01", hair_col="1e140e", brows="eyebrow002", eyes="brown",
                 clothes=["female_casualsuit02"], tint="4fa37a", glasses=True),
    "marisol": dict(g=0.0, age=0.42, race=(0.1, 0.6, 0.3), skin="young_caucasian_female2/young_caucasian_female2.mhmat",
                    hair="ponytail01", hair_col="1e140e", brows="eyebrow001", eyes="brown",
                    clothes=["female_sportsuit01"], tint="e8744f"),
    "kai": dict(g=1.0, age=0.38, race=(0.6, 0.1, 0.3), skin="young_asian_male/young_asian_male.mhmat",
                hair="short02", hair_col="15141a", brows="eyebrow007", eyes="brown",
                clothes=["male_casualsuit04"], tint="3f9fbf"),
    "ula": dict(g=0.0, age=0.9, race=(0, 0.2, 0.8), skin="old_african_female/old_african_female.mhmat",
                hair="short03", hair_col="e6e2da", brows="eyebrow004", eyes="brown",
                clothes=["female_elegantsuit01"], tint="8a6fb0"),
    "isolde": dict(g=0.0, age=0.35, race=(0, 1, 0), skin="young_caucasian_female/young_caucasian_female.mhmat",
                   hair="braid01", hair_col="e0b860", brows="eyebrow006", eyes="lightblue",
                   clothes=["female_casualsuit02"], tint="f2c14e"),
    "bram": dict(g=1.0, age=0.5, race=(0, 1, 0), skin="middleage_caucasian_male/middleage_caucasian_male.mhmat",
                 hair="short03", hair_col="8a4a22", brows="eyebrow010", eyes="bluegreen",
                 clothes=["male_worksuit01"], tint="5b86b5", weight=0.6),
    "hana": dict(g=0.0, age=0.4, race=(1, 0, 0), skin="young_asian_female/young_asian_female.mhmat",
                 hair="ponytail01", hair_col="15141a", brows="eyebrow001", eyes="brown",
                 clothes=["female_elegantsuit01"], tint="6f9a4a"),
    "toma": dict(g=1.0, age=0.4, race=(1, 0, 0), skin="young_asian_male/young_asian_male.mhmat",
                 hair="short01", hair_col="1e140e", brows="eyebrow007", eyes="brown",
                 clothes=["male_casualsuit02"], tint="b4643c"),
    "vesna": dict(g=0.0, age=0.45, race=(0, 1, 0), skin="middleage_caucasian_female/middleage_caucasian_female.mhmat",
                  hair="long01", hair_col="6b3a26", brows="eyebrow003", eyes="grey",
                  clothes=["female_elegantsuit01"], tint="7d5ba6"),
    "ines": dict(g=0.0, age=0.42, race=(0, 0.6, 0.4), skin="young_caucasian_female2/young_caucasian_female2.mhmat",
                 hair="long01", hair_col="3a2418", brows="eyebrow001", eyes="brown",
                 clothes=["female_casualsuit02"], tint="5b86b5"),
    "marek": dict(g=1.0, age=0.48, race=(0, 1, 0), skin="young_caucasian_male2/young_caucasian_male2.mhmat",
                  hair="short02", hair_col="c9a265", brows="eyebrow009", eyes="blue",
                  clothes=["male_casualsuit03"], tint="c0473e"),
    "luna": dict(g=0.0, age=0.5, race=(0, 0, 1), skin="middleage_african_female/middleage_african_female.mhmat",
                 hair="afro01", hair_col="15141a", brows="eyebrow002", eyes="brown",
                 clothes=["female_casualsuit02"], tint="7d5ba6", chef=True),
    "silas": dict(g=1.0, age=0.88, race=(0, 1, 0), skin="old_caucasian_male/old_caucasian_male.mhmat",
                  hair="short04", hair_col="9a9a9a", brows="eyebrow010", eyes="grey",
                  clothes=["male_elegantsuit01"], tint="5a5f7a", glasses=True),
}


def srgb(hexcol):
    c = [int(hexcol[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c) + (1.0,)


def recolour(obj, hexcol):
    """Clothes: a plain fabric colour instead of the printed texture (no logos), keeping
    the ambient occlusion and normal maps for the folds."""
    for slot in obj.material_slots:
        mat = slot.material
        if not mat or not mat.node_tree:
            continue
        nt = mat.node_tree
        tex = nt.nodes.get("diffuseTexture")
        if tex is None:
            continue
        rgb = nt.nodes.new("ShaderNodeRGB")
        rgb.outputs[0].default_value = srgb(hexcol)
        for link in list(tex.outputs["Color"].links):
            to = link.to_socket
            nt.links.remove(link)
            nt.links.new(rgb.outputs[0], to)
        p = nt.nodes.get("Principled BSDF")
        if p:
            p.inputs["Roughness"].default_value = 0.85


def tint(obj, hexcol, strength=1.0):
    """Hair and brows: keeps the strands' light and dark (texture brightness) and maps it
    onto the wanted colour, from a deep shade of it to a light one."""
    base = srgb(hexcol)
    dark = tuple(c * 0.22 for c in base[:3]) + (1.0,)
    light = tuple(min(1.0, c * 1.5 + 0.04) for c in base[:3]) + (1.0,)
    for slot in obj.material_slots:
        mat = slot.material
        if not mat or not mat.node_tree:
            continue
        nt = mat.node_tree
        tex = nt.nodes.get("diffuseTexture")
        if tex is None:
            continue
        for link in list(tex.outputs["Color"].links):
            bw = nt.nodes.new("ShaderNodeRGBToBW")
            ramp = nt.nodes.new("ShaderNodeValToRGB")
            ramp.color_ramp.elements[0].position = 0.0
            ramp.color_ramp.elements[0].color = dark
            ramp.color_ramp.elements[1].position = 0.75
            ramp.color_ramp.elements[1].color = light
            mid = ramp.color_ramp.elements.new(0.38)
            mid.color = base
            to = link.to_socket
            nt.links.remove(link)
            nt.links.new(tex.outputs["Color"], bw.inputs[0])
            nt.links.new(bw.outputs[0], ramp.inputs[0])
            if strength >= 1.0:
                nt.links.new(ramp.outputs[0], to)
            else:
                mix = nt.nodes.new("ShaderNodeMixRGB")
                mix.inputs["Fac"].default_value = strength
                nt.links.new(tex.outputs["Color"], mix.inputs["Color1"])
                nt.links.new(ramp.outputs[0], mix.inputs["Color2"])
                nt.links.new(mix.outputs["Color"], to)


def material(name, hexcol, rough=0.5, sss=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = srgb(hexcol)
    p.inputs["Roughness"].default_value = rough
    if sss > 0:
        p.inputs["Subsurface Weight"].default_value = sss
    return m


def bounds(obj):
    pts = [obj.matrix_world @ v.co for v in obj.data.vertices]
    lo = mathutils.Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = mathutils.Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def add_glasses(eyes_obj):
    lo, hi = bounds(eyes_obj)
    c = (lo + hi) * 0.5
    half = (hi.x - lo.x) * 0.5
    frame = material("glasses", "2a2a30", 0.25)
    lens = bpy.data.materials.new("lens")
    lens.use_nodes = True
    lp = lens.node_tree.nodes["Principled BSDF"]
    lp.inputs["Transmission Weight"].default_value = 1.0
    lp.inputs["Roughness"].default_value = 0.0
    lp.inputs["IOR"].default_value = 1.05
    y = lo.y - 0.012
    r = half * 0.4
    for sx in (-1, 1):
        x = c.x + sx * half * 0.52
        bpy.ops.mesh.primitive_torus_add(major_radius=r, minor_radius=0.0022, location=(x, y, c.z),
                                         rotation=(math.radians(90), 0, 0), major_segments=48, minor_segments=8)
        bpy.context.object.data.materials.append(frame)
        bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=0.001, location=(x, y, c.z), rotation=(math.radians(90), 0, 0), vertices=48)
        bpy.context.object.data.materials.append(lens)
        bpy.ops.mesh.primitive_cylinder_add(radius=0.0018, depth=0.075, location=(c.x + sx * (half * 0.52 + r), y + 0.038, c.z + 0.004),
                                            rotation=(math.radians(90), 0, 0))
        bpy.context.object.data.materials.append(frame)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.002, depth=half * 0.1, location=(c.x, y, c.z + 0.004), rotation=(0, math.radians(90), 0))
    bpy.context.object.data.materials.append(frame)


def add_chef_hat(top, y0):
    white = material("chef", "f6f4ef", 0.8, 0.0)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.094, depth=0.06, location=(0, y0, top - 0.035), vertices=64)
    band = bpy.context.object
    band.data.materials.append(white)
    bpy.ops.object.shade_smooth()
    for (x, y, z, r) in [(-0.05, y0, top + 0.03, 0.065), (0.05, y0, top + 0.03, 0.065), (0.0, y0 - 0.03, top + 0.045, 0.07),
                         (0.0, y0 + 0.04, top + 0.04, 0.065)]:
        bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=(x, y, z), segments=48, ring_count=24)
        bpy.context.object.data.materials.append(white)
        bpy.ops.object.shade_smooth()


def build(who, spec):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    info = HumanService._create_default_human_info_dict()
    a, c, af = spec["race"]
    info["phenotype"].update({"gender": spec["g"], "age": spec["age"], "muscle": 0.5, "weight": spec.get("weight", 0.5),
                              "proportions": 0.75, "height": 0.5, "race": {"asian": a, "caucasian": c, "african": af}})
    info["skin_mhmat"] = spec["skin"]
    info["skin_material_type"] = "ENHANCED_SSS"
    info["eyes"] = "high-poly/high-poly.mhclo"
    info["eyebrows"] = "%s/%s.mhclo" % (spec["brows"], spec["brows"])
    info["eyelashes"] = "eyelashes01/eyelashes01.mhclo"
    info["teeth"] = "teeth_base/teeth_base.mhclo"
    info["tongue"] = "tongue01/tongue01.mhclo"
    info["hair"] = "%s/%s.mhclo" % (spec["hair"], spec["hair"])
    info["clothes"] = ["%s/%s.mhclo" % (x, x) for x in spec["clothes"]]
    if spec.get("hat"):
        info["clothes"].append("%s/%s.mhclo" % (spec["hat"], spec["hat"]))
    info["rig"] = "default"
    settings = HumanService.get_default_deserialization_settings()
    settings["subdiv_levels"] = 1
    body = HumanService.deserialize_from_dict(info, settings)

    fu = os.path.join(LocationService.get_user_data(), "targets", "faceunits")
    for name, w in [("mouthSmileLeft", 1.0), ("mouthSmileRight", 1.0), ("cheekSquintLeft", 0.5), ("cheekSquintRight", 0.5),
                    ("eyeSquintLeft", 0.18), ("eyeSquintRight", 0.18), ("jawOpen", 0.1), ("mouthUpperUpLeft", 0.25),
                    ("mouthUpperUpRight", 0.25), ("mouthLowerDownLeft", 0.2), ("mouthLowerDownRight", 0.2)]:
        p = os.path.join(fu, name + ".target")
        if os.path.exists(p):
            TargetService.load_target(body, p, weight=w, name=name)

    for o in bpy.data.objects:
        n = o.name.lower()
        if o.type != "MESH":
            continue
        if spec["hair"] in n:
            tint(o, spec["hair_col"])
        elif spec["brows"] in n:
            tint(o, spec["hair_col"], 0.8)
        elif spec.get("hat") and spec["hat"] in n:
            tint(o, spec.get("hat_col", "444444"))
        elif any(x in n for x in spec["clothes"]):
            recolour(o, spec["tint"])
        elif "high-poly" in n:
            eyes_obj = o
    # eye colour: swap the iris texture
    eye_tex = os.path.join(LocationService.get_user_data(), "eyes", "materials", spec["eyes"] + "_eye.png")
    if os.path.exists(eye_tex):
        for slot in eyes_obj.material_slots:
            node = slot.material.node_tree.nodes.get("diffuseTexture")
            if node:
                node.image = bpy.data.images.load(eye_tex)

    # arms down, relaxed
    rig = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
    for side, sgn in (("L", 1), ("R", -1)):
        b = rig.pose.bones["upperarm01." + side]
        b.rotation_mode = "XYZ"
        b.rotation_euler = (0.0, 0.0, -math.radians(55) * sgn)
        lb = rig.pose.bones["lowerarm01." + side]
        lb.rotation_mode = "XYZ"
        lb.rotation_euler = (math.radians(12), 0.0, 0.0)
    bpy.context.view_layer.update()

    elo, ehi = bounds(eyes_obj)
    eye_c = (elo + ehi) * 0.5
    top = eye_c.z + 0.11   # the crown of the head (the body mesh also holds hidden helpers)
    if spec.get("glasses"):
        add_glasses(eyes_obj)
    if spec.get("chef"):
        add_chef_hat(top, eye_c.y + 0.03)
    return top


def light_and_render(top, path, close):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 128
    scene.cycles.use_denoising = True
    scene.render.film_transparent = True
    scene.render.resolution_x = SIZE
    scene.render.resolution_y = SIZE
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Base Contrast"
    scene.view_settings.exposure = -0.35
    cam_data = bpy.data.cameras.new("cam")
    cam_data.lens = 85
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    if close:
        target = mathutils.Vector((0, 0, top - 0.17))
        dist = 1.25
    else:
        target = mathutils.Vector((0, 0, top - 0.25))
        dist = 1.45
    cam.location = target + mathutils.Vector((0.0, -dist, 0.06))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam

    def area(name, loc, energy, size, color):
        d = bpy.data.lights.new(name, "AREA")
        d.energy = energy
        d.size = size
        d.color = color
        o = bpy.data.objects.new(name, d)
        o.location = target + mathutils.Vector(loc)
        o.rotation_euler = (target - o.location).to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(o)

    area("key", (-1.3, -1.7, 0.9), 150, 1.6, (1.0, 0.94, 0.86))
    area("fill", (1.5, -1.5, 0.1), 55, 2.2, (0.86, 0.92, 1.0))
    area("rim", (0.9, 1.4, 0.8), 140, 1.0, (1.0, 0.96, 0.9))
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.62, 0.7, 0.8, 1)
    bg.inputs[1].default_value = 0.35
    scene.world = world
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    names = [a for a in args if a in PEOPLE] or list(PEOPLE)
    os.makedirs(OUT, exist_ok=True)
    for who in names:
        top = build(who, PEOPLE[who])
        if "--faces-only" not in args:
            light_and_render(top, os.path.join(OUT, "bust_%s.png" % who), False)
        if "--busts-only" not in args:
            top = build(who, PEOPLE[who])
            light_and_render(top, os.path.join(OUT, "face_%s.png" % who), True)
        print("rendered", who)


if __name__ == "__main__":
    main()

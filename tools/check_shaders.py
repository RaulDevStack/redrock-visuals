"""Preprocesa el shaderpack (includes + variantes de opciones) y lo compila con el
driver OpenGL real usando LWJGL de la cache de Gradle.

Uso: python tools/check_shaders.py <directorio_temporal>
"""
import glob
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SHADERS = os.path.join(HERE, "..", "shaders")
GRADLE = os.path.expanduser("~/.gradle/caches/modules-2/files-2.1/org.lwjgl")

IRIS_DEFINES = """#define MC_VERSION 12101
#define IRIS_VERSION 10800
#define IRIS_FEATURE_CUSTOM_IMAGES
#define MC_GL_RENDERER_NVIDIA
#define MC_RENDER_STAGE_NONE 0
#define MC_RENDER_STAGE_SKY 1
#define MC_RENDER_STAGE_SUNSET 2
#define MC_RENDER_STAGE_CUSTOM_SKY 3
#define MC_RENDER_STAGE_SUN 4
#define MC_RENDER_STAGE_MOON 5
#define MC_RENDER_STAGE_STARS 6
#define MC_RENDER_STAGE_VOID 7
#define MC_RENDER_STAGE_TERRAIN_SOLID 8
#define MC_RENDER_STAGE_TERRAIN_CUTOUT_MIPPED 9
#define MC_RENDER_STAGE_TERRAIN_CUTOUT 10
"""

VARIANTS = {
    "default": {},
    "low": {"SHADOW_FILTER": "0", "SSR": None, "CLOUD_SHADOWS": None, "DUST_NOISE": None, "VL_RES": "0.25"},
    "ultra": {"VOXEL_REFLECTIONS": "", "VOXEL_STEPS": "128", "SHADOW_FILTER": "2"},
    "high": {"SHADOW_FILTER": "2", "VL_STEPS": "16", "CLOUD_STEPS": "24", "CLOUD_LIGHT_STEPS": "4", "VL_RES": "1.0"},
    "alloff": {"SHADOWS": None, "VOLUMETRIC_FOG": None, "VOLUMETRIC_CLOUDS": None, "BLOOM": None,
               "WAVING_PLANTS": None, "WAVING_LEAVES": None, "WAVING_WATER": None, "WAVING_LAVA": None, "HANDHELD_LIGHT": None, "BORDER_FOG": None, "MORNING_FOG": None, "SSR": None},
}


OPTION_FILES = ("lib/settings.glsl", "lib/voxel_opts.glsl")


def settings_text(variant):
    """Devuelve {ruta: texto} de los ficheros de opciones con la variante aplicada."""
    files = {p: open(os.path.join(SHADERS, p), encoding="utf-8").read() for p in OPTION_FILES}
    for name, value in variant.items():
        pat = re.compile(r"^(//)?#define " + name + r"\b.*$", re.M)
        repl = ("// disabled " + name) if value is None else ("#define %s %s" % (name, value))
        hits = 0
        for p in files:
            files[p], n = pat.subn(repl, files[p])
            hits += n
        assert hits == 1, name
    return files


def expand(path, settings):
    out = []
    for line in open(path, encoding="utf-8").read().splitlines():
        m = re.match(r'\s*#include\s+"(/[^"]+)"', line)
        if m:
            rel = m.group(1).lstrip("/")
            if rel in settings:
                out.append(expand_text(settings[rel], settings))
            else:
                out.append(expand(os.path.join(SHADERS, rel), settings))
        else:
            out.append(line)
    return "\n".join(out)


def expand_text(text, settings):
    out = []
    for line in text.splitlines():
        m = re.match(r'\s*#include\s+"(/[^"]+)"', line)
        if m:
            rel = m.group(1).lstrip("/")
            out.append(expand_text(settings[rel], settings) if rel in settings
                       else expand(os.path.join(SHADERS, rel), settings))
        else:
            out.append(line)
    return "\n".join(out)


def jar(pattern):
    hits = glob.glob(os.path.join(GRADLE, pattern), recursive=True)
    if not hits:
        raise SystemExit("no jar " + pattern)
    return hits[0]


def main():
    tmp = sys.argv[1]
    cp = os.pathsep.join([
        jar("lwjgl/3.3.3/*/lwjgl-3.3.3.jar"), jar("lwjgl/3.3.3/*/lwjgl-3.3.3-natives-windows.jar"),
        jar("lwjgl-glfw/3.3.3/*/lwjgl-glfw-3.3.3.jar"), jar("lwjgl-glfw/3.3.3/*/lwjgl-glfw-3.3.3-natives-windows.jar"),
        jar("lwjgl-opengl/3.3.3/*/lwjgl-opengl-3.3.3.jar"), jar("lwjgl-opengl/3.3.3/*/lwjgl-opengl-3.3.3-natives-windows.jar"),
    ])
    ok = True
    for vname, variant in VARIANTS.items():
        settings = settings_text(variant)
        for dim in ("", "world-1", "world1"):
            src_dir = os.path.join(SHADERS, dim)
            out_dir = os.path.join(tmp, vname, dim or "world0")
            os.makedirs(out_dir, exist_ok=True)
            for f in glob.glob(os.path.join(src_dir, "*.[vf]sh")):
                body = expand(f, settings)
                first, rest = body.split("\n", 1)
                with open(os.path.join(out_dir, os.path.basename(f)), "w", encoding="utf-8") as o:
                    o.write(first + "\n" + IRIS_DEFINES + rest)
            print("== %s / %s" % (vname, dim or "world0"), flush=True)
            r = subprocess.run(["java", "-cp", cp, os.path.join(HERE, "ShaderCheck.java"), out_dir],
                               capture_output=True, text=True)
            print(r.stdout + r.stderr, flush=True)
            ok = ok and r.returncode == 0
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()

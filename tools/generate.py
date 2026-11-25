"""Genera los ficheros de entrada (.vsh/.fsh) por dimension y la textura de ruido.

Uso:  python tools/generate.py
Los programas reales estan en shaders/program/*.glsl; aqui solo se crean los
envoltorios que fijan #version, la etapa (VSH/FSH), la dimension y el modo.
"""
import os
import random
import struct
import zlib

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "shaders")

# nombre de programa Iris -> (fichero en program/, defines extra)
PROGRAMS = {
    "shadow":               ("shadow", []),
    "gbuffers_basic":       ("gbuffers_simple", ["BASIC"]),
    "gbuffers_line":        ("gbuffers_simple", ["BASIC"]),
    "gbuffers_textured":    ("gbuffers_simple", ["PARTICLES"]),
    "gbuffers_textured_lit": ("gbuffers_simple", ["PARTICLES"]),
    "gbuffers_weather":     ("gbuffers_simple", ["WEATHER"]),
    "gbuffers_skybasic":    ("gbuffers_simple", ["SKYBASIC"]),
    "gbuffers_skytextured": ("gbuffers_simple", ["SKYTEXTURED"]),
    "gbuffers_clouds":      ("gbuffers_simple", ["CLOUDS"]),
    "gbuffers_spidereyes":  ("gbuffers_simple", ["EMISSIVE"]),
    "gbuffers_beaconbeam":  ("gbuffers_simple", ["EMISSIVE"]),
    "gbuffers_armor_glint": ("gbuffers_simple", ["GLINT"]),
    "gbuffers_damagedblock": ("gbuffers_simple", ["DAMAGED"]),
    "gbuffers_terrain":     ("gbuffers_lit", ["TERRAIN"]),
    "gbuffers_entities":    ("gbuffers_lit", ["ENTITIES"]),
    "gbuffers_block":       ("gbuffers_lit", []),
    "gbuffers_hand":        ("gbuffers_lit", ["HAND"]),
    "gbuffers_hand_water":  ("gbuffers_lit", ["HAND"]),
    "gbuffers_water":       ("gbuffers_water", []),
    "deferred":             ("deferred", []),
    "composite":            ("composite", []),
    "composite1":           ("composite1", []),
    "final":                ("final", []),
}

DIMENSIONS = {
    "": "OVERWORLD",
    "world-1": "NETHER",
    "world1": "END",
}

NO_SHADOW_DIMS = {"world-1", "world1"}


def write_wrappers():
    for folder, dim in DIMENSIONS.items():
        out_dir = os.path.join(ROOT, folder) if folder else ROOT
        os.makedirs(out_dir, exist_ok=True)
        for name, (src, defines) in PROGRAMS.items():
            if name == "shadow" and folder in NO_SHADOW_DIMS:
                continue
            for stage, ext in (("VSH", "vsh"), ("FSH", "fsh")):
                lines = ["#version 330 compatibility", f"#define {stage}", f"#define {dim}"]
                lines += [f"#define {d}" for d in defines]
                lines.append(f'#include "/program/{src}.glsl"')
                with open(os.path.join(out_dir, f"{name}.{ext}"), "w", newline="\n") as f:
                    f.write("\n".join(lines) + "\n")


def png_rgba(path, w, h, pixels):
    raw = b"".join(b"\x00" + bytes(pixels[y * w * 4:(y + 1) * w * 4]) for y in range(h))

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)))
        f.write(chunk(b"IDAT", zlib.compress(raw, 9)))
        f.write(chunk(b"IEND", b""))


def write_noise():
    n = 256
    rng = random.Random(1885)  # ano de la fiebre del oro, por poner algo
    r = [[rng.randrange(256) for _ in range(n)] for _ in range(n)]
    px = []
    for y in range(n):
        for x in range(n):
            # G = R desplazado (37, 17): permite ruido 3D con una sola lectura
            px += [r[y][x], r[(y + 17) % n][(x + 37) % n], rng.randrange(256), 255]
    tex_dir = os.path.join(ROOT, "tex")
    os.makedirs(tex_dir, exist_ok=True)
    png_rgba(os.path.join(tex_dir, "noise.png"), n, n, px)
    with open(os.path.join(tex_dir, "noise.png.mcmeta"), "w", newline="\n") as f:
        f.write('{\n  "texture": {\n    "blur": true,\n    "clamp": false\n  }\n}\n')


if __name__ == "__main__":
    write_wrappers()
    write_noise()
    print("ok")

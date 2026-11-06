# Synthetic periapical radiographs for the demo (generated, no patient data).
import numpy as np, sys, os
from PIL import Image, ImageDraw, ImageFilter

def noise(h, w, scale, seed):
    r = np.random.default_rng(seed)
    small = r.random((max(2, h // scale), max(2, w // scale)))
    return np.asarray(Image.fromarray((small * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)).astype(np.float32) / 255

def crspline(pts, n=12):
    pts = [pts[0]] + list(pts) + [pts[-1]]; out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = map(np.array, pts[i - 1:i + 3])
        for t in np.linspace(0, 1, n, endpoint=False):
            out.append(tuple(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3)))
    out.append(tuple(pts[-2])); return out

def mask(w, h, polys, blur=0):
    m = Image.new('L', (w, h), 0); d = ImageDraw.Draw(m)
    for p in polys: d.polygon(p, fill=255)
    if blur: m = m.filter(ImageFilter.GaussianBlur(blur))
    return np.asarray(m).astype(np.float32) / 255

def grow(m, px):
    im = Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(px | 1))
    return np.asarray(im).astype(np.float32) / 255

def shrink(m, px):
    im = Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(px | 1))
    return np.asarray(im).astype(np.float32) / 255

def tooth(cx, cej, cw, ch, rl, roots, s, spread=0.0):
    # s = +1 lower (crown above cej, roots below), -1 upper
    up = -s
    occl = cej + up * ch
    cusps = 2 if roots >= 2 else 1
    top = []
    for i in range(9):
        t = i / 8; x = cx - cw / 2 + cw * t
        bump = (abs(np.sin(np.pi * t * cusps)) * 0.12 + np.sin(np.pi * t) * 0.1) * ch
        top.append((x, occl - up * (0.12 * ch) + up * bump))
    crown = crspline([(cx - cw * 0.42, cej)] + [(cx - cw * 0.52, cej + up * ch * 0.45)] + top + [(cx + cw * 0.52, cej + up * ch * 0.45), (cx + cw * 0.42, cej)], 8)
    neck = cw * 0.84
    rts, canals = [], []
    for k in range(roots):
        frac = (k + 0.5) / roots
        bx = cx - neck / 2 + neck * frac
        rw = neck / roots * (0.95 if roots > 1 else 0.7)
        tipx = bx + (frac - 0.5) * spread * cw + (cw * 0.04 if k == roots - 1 else 0)
        tipy = cej + s * rl * (0.92 + 0.08 * (k % 2))
        r = crspline([(bx - rw / 2, cej - s * 6), (bx - rw * 0.42, cej + s * rl * 0.35), (tipx - rw * 0.18, cej + s * rl * 0.8), (tipx, tipy), (tipx + rw * 0.18, cej + s * rl * 0.8), (bx + rw * 0.42, cej + s * rl * 0.35), (bx + rw / 2, cej - s * 6)], 10)
        rts.append(r)
        canals.append(crspline([(bx, cej + s * ch * 0.05), (bx + (tipx - bx) * 0.5, cej + s * rl * 0.5), (tipx, tipy - s * 10)], 10))
    pulp = crspline([(cx - neck * 0.3, cej + s * 8), (cx - neck * 0.28, cej + up * ch * 0.35), (cx, cej + up * ch * 0.45), (cx + neck * 0.28, cej + up * ch * 0.35), (cx + neck * 0.3, cej + s * 8)], 8)
    return crown, rts, pulp, canals, occl

def render(path, teeth, lower, size=(1200, 800), seed=0):
    w, h = size; s = 1 if lower else -1
    yy, xx = np.mgrid[0:h, 0:w]
    crest = h * (0.42 if lower else 0.58)
    bone = (yy > crest).astype(np.float32) if lower else (yy < crest).astype(np.float32)
    bone = np.asarray(Image.fromarray((bone * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(28))).astype(np.float32) / 255
    trab = 0.55 * noise(h, w, 4, seed + 1) + 0.45 * noise(h, w, 11, seed + 2)
    trab = np.clip((trab - 0.42) * 2.6, 0, 1)
    img = 0.12 + 0.06 * noise(h, w, 80, seed + 3) + bone * (0.2 + 0.2 * trab)
    dentin_p, enamel_p, root_p, pulp_p, canal_l, rct_l, metal_p, lesion = [], [], [], [], [], [], [], []
    for t in teeth:
        cx = t['x'] * w; cw = t['w'] * w; ch = 0.26 * h; rl = 0.42 * h
        cej = crest - s * 0.03 * h
        crown, rts, pulp, canals, occl = tooth(cx, cej, cw, ch, rl, t.get('roots', 2), s, t.get('spread', 0.25))
        if t.get('implant'):
            body = crspline([(cx - cw * 0.17, cej), (cx - cw * 0.16, cej + s * rl * 0.8), (cx, cej + s * rl * 0.92), (cx + cw * 0.16, cej + s * rl * 0.8), (cx + cw * 0.17, cej)], 8)
            metal_p.append(body); metal_p.append(crown)
            for i in range(12):
                y = cej + s * rl * (0.05 + 0.07 * i); metal_p.append([(cx - cw * 0.21, y), (cx + cw * 0.21, y), (cx + cw * 0.18, y + s * 9), (cx - cw * 0.18, y + s * 9)])
            continue
        dentin_p.append(crown); root_p += rts; pulp_p.append(pulp); canal_l += canals
        if t.get('rct'): rct_l += canals
        if t.get('crown'): metal_p.append(crown)
        if t.get('fill'):
            fw = cw * t['fill']; fy = occl - (-s) * (-0.02 * h)
            metal_p.append(crspline([(cx - fw, fy - s * 4), (cx - fw * 0.8, fy + s * ch * 0.38), (cx + fw * 0.8, fy + s * ch * 0.38), (cx + fw, fy - s * 4)], 6))
        if t.get('lesion'):
            ty = cej + s * rl; lesion.append([(cx - cw * 0.25, ty - 40), (cx + cw * 0.25, ty - 40), (cx + cw * 0.25, ty + 50), (cx - cw * 0.25, ty + 50)])
    crown_m = mask(w, h, dentin_p); root_m = mask(w, h, root_p); tooth_m = np.maximum(crown_m, root_m)
    pdl = np.clip(grow(root_m, 9) - root_m, 0, 1); lam = np.clip(grow(root_m, 17) - grow(root_m, 9), 0, 1)
    enamel = np.clip(crown_m - shrink(crown_m, 25), 0, 1) * crown_m
    pulp_m = mask(w, h, pulp_p)
    cm = Image.new('L', (w, h), 0); dc = ImageDraw.Draw(cm)
    for c in canal_l: dc.line(c, fill=255, width=8)
    canal_m = np.asarray(cm).astype(np.float32) / 255
    rm = Image.new('L', (w, h), 0); dr = ImageDraw.Draw(rm)
    for c in rct_l: dr.line(c, fill=255, width=11)
    rct_m = np.asarray(rm.filter(ImageFilter.GaussianBlur(1.2))).astype(np.float32) / 255
    metal_m = mask(w, h, metal_p, 1.2)
    les = mask(w, h, lesion, 22) if lesion else 0
    B = lambda m, r: np.asarray(Image.fromarray((np.clip(m, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(r))).astype(np.float32) / 255
    img = img * (1 - B(tooth_m, 2) * 0.7) + B(tooth_m, 2) * (0.5 + 0.06 * noise(h, w, 30, seed + 5))
    img += B(enamel, 3) * 0.28
    img -= B(np.maximum(pulp_m, canal_m), 3) * 0.26
    img -= B(pdl, 2) * 0.12 * bone
    img += B(lam, 3) * 0.1 * bone
    img -= les * 0.22 if lesion else 0
    img = np.maximum(img, np.maximum(rct_m * 0.97, metal_m * 0.93))
    img += (noise(h, w, 1, seed + 9) - 0.5) * 0.05
    vig = 1 - 0.3 * (((xx - w / 2) / (w / 2)) ** 2 + ((yy - h / 2) / (h / 2)) ** 2)
    img = np.clip(img * vig, 0, 1)
    out = Image.fromarray((img ** 0.95 * 255).astype(np.uint8), 'L')
    m = Image.new('L', (w, h), 255); dm = ImageDraw.Draw(m); c = 64
    for poly in [[(0, 0), (c, 0), (0, c)], [(w, 0), (w - c, 0), (w, c)], [(0, h), (c, h), (0, h - c)], [(w, h), (w - c, h), (w, h - c)]]: dm.polygon(poly, fill=0)
    Image.composite(out, Image.new('L', (w, h), 6), m).convert('RGB').save(path, quality=90)

if __name__ == '__main__':
    od = sys.argv[1]; os.makedirs(od, exist_ok=True)
    render(f'{od}/xr_lower_molars.jpg', [dict(x=0.15, w=0.27, roots=2, fill=0.22), dict(x=0.47, w=0.31, roots=2), dict(x=0.8, w=0.29, roots=2)], True, seed=1)
    render(f'{od}/xr_lower_molar_rct.jpg', [dict(x=0.17, w=0.27, roots=2, fill=0.25), dict(x=0.5, w=0.32, roots=2, rct=True, crown=True), dict(x=0.84, w=0.24, roots=1)], True, seed=2)
    render(f'{od}/xr_upper_molars.jpg', [dict(x=0.16, w=0.28, roots=3, spread=0.4), dict(x=0.49, w=0.3, roots=3, spread=0.4, fill=0.25), dict(x=0.81, w=0.26, roots=2)], False, seed=3)
    render(f'{od}/xr_upper_premolars.jpg', [dict(x=0.15, w=0.2, roots=1), dict(x=0.39, w=0.21, roots=2, spread=0.15, rct=True), dict(x=0.63, w=0.21, roots=1, fill=0.2), dict(x=0.87, w=0.22, roots=1)], False, seed=4)
    render(f'{od}/xr_lower_implant.jpg', [dict(x=0.18, w=0.25, roots=1), dict(x=0.5, w=0.3, implant=True), dict(x=0.82, w=0.29, roots=2)], True, seed=5)
    render(f'{od}/xr_lower_lesion.jpg', [dict(x=0.18, w=0.28, roots=2), dict(x=0.51, w=0.31, roots=2, lesion=True, fill=0.3), dict(x=0.84, w=0.25, roots=1)], True, seed=6)
    print('ok')

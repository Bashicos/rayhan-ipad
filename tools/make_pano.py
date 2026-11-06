# Synthetic panoramic X-ray for the demo (generated, no patient data).
import sys, os, numpy as np
sys.path.insert(0, os.path.dirname(__file__))
from PIL import Image, ImageDraw, ImageFilter
import make_xrays as M

W, H = 2400, 1150
yy, xx = np.mgrid[0:H, 0:W]
u = (xx - W / 2) / (W / 2)
img = 0.10 + 0.05 * M.noise(H, W, 90, 11)
# jaw bones: two smile-shaped bands
up_c = H * 0.40 - 70 * (1 - u ** 2) + 40 * u ** 4
lo_c = H * 0.60 + 70 * (1 - u ** 2) - 40 * u ** 4
jaw = ((yy < up_c + 40) & (yy > up_c - 330)) | ((yy > lo_c - 40) & (yy < lo_c + 360))
jaw = np.asarray(Image.fromarray((jaw * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(45))).astype(np.float32) / 255
trab = 0.55 * M.noise(H, W, 5, 12) + 0.45 * M.noise(H, W, 13, 13)
img += jaw * (0.22 + 0.18 * np.clip((trab - 0.42) * 2.6, 0, 1))
# sinuses and nasal cavity (darker), mandibular canal (dark line)
for cx in (0.27, 0.73):
    m = ((xx - W * cx) / (W * 0.13)) ** 2 + ((yy - H * 0.17) / (H * 0.11)) ** 2 < 1
    img -= np.asarray(Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(30))).astype(np.float32) / 255 * 0.12
can = Image.new('L', (W, H), 0); d = ImageDraw.Draw(can)
for side in (-1, 1):
    pts = [(W / 2 + side * W * t, lo_c[0, 0] * 0 + H * 0.84 - 60 * (1 - t ** 2) + 90 * t ** 3) for t in np.linspace(0.12, 0.48, 30)]
    d.line(pts, fill=255, width=16)
img -= np.asarray(can.filter(ImageFilter.GaussianBlur(5))).astype(np.float32) / 255 * 0.12
tooth_m = Image.new('L', (W, H), 0); dt = ImageDraw.Draw(tooth_m)
pulp_m = Image.new('L', (W, H), 0); dp = ImageDraw.Draw(pulp_m)
metal = Image.new('L', (W, H), 0); dm = ImageDraw.Draw(metal)
def row(lower):
    s = 1 if lower else -1
    for k in range(16):
        t = (k + 0.5) / 16 * 2 - 1  # -1..1
        idx = 8 - abs(int((k if k < 8 else 15 - k)))  # 1..8 from the middle
        n = 8 - (k if k < 8 else 15 - k)  # 8 = wisdom at edges
        widths = [0.030, 0.028, 0.032, 0.034, 0.034, 0.046, 0.046, 0.042]  # 1..8 from the middle
        widths = [w * 1.32 for w in widths]
        cw = widths[n - 1] * W * 0.9
        side = -1 if k < 8 else 1
        cx = W / 2 + side * (sum(widths[:n - 1]) + widths[n - 1] / 2) * W
        base = (lo_c[0, int(cx)] - 34) if lower else (up_c[0, int(cx)] + 34)
        ch, rl = 0.11 * H, (0.19 if n >= 6 else 0.22) * H
        roots = (3 if not lower else 2) if n >= 6 else (2 if n == 4 and not lower else 1)
        if (lower and k == 2) : continue  # a missing tooth
        cr, rts, pul, can_, occl = M.tooth(cx, base, cw, ch, rl, roots, s, 0.25)
        dt.polygon(cr, fill=255); [dt.polygon(r, fill=200) for r in rts]
        dp.polygon(pul, fill=255); [dp.line(c, fill=255, width=6) for c in can_]
        if lower and k == 13: [dm.line(c, fill=255, width=9) for c in can_]; dm.polygon(cr, fill=235)  # RCT + crown 36
        if not lower and k == 12: dm.ellipse([cx - cw * 0.22, occl - 10, cx + cw * 0.22, occl + ch * 0.35], fill=245)  # filling 26
        if lower and k == 3:  # implant 45 region
            pass
row(False); row(True)
B = lambda im, r: np.asarray(im.filter(ImageFilter.GaussianBlur(r))).astype(np.float32) / 255
tm = B(tooth_m, 2.5)
img = img * (1 - tm * 0.6) + tm * (0.52 + 0.06 * M.noise(H, W, 30, 14))
img -= B(pulp_m, 3) * 0.24
img = np.maximum(img, B(metal, 1.3) * 0.95)
img += (M.noise(H, W, 1, 15) - 0.5) * 0.045
vig = 1 - 0.45 * (u ** 2) - 0.25 * ((yy - H / 2) / (H / 2)) ** 2
img = np.clip(img * vig, 0, 1)
out = sys.argv[1]
Image.fromarray((img ** 0.95 * 255).astype(np.uint8), 'L').convert('RGB').save(out, quality=88)
print('ok', out)

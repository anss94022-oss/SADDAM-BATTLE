#!/usr/bin/env python3
"""SADDAM BATTLE — مولّد الخامات الأصلي.

ينشئ خامات قابلة للتكرار (tileable) مع خرائط نتوءات، كلها مولّدة رياضياً
من ضجيج طيفي دوري — لا صور محمية من الإنترنت، الترخيص للمشروع نفسه.

التشغيل:  python3 tools/gen_textures.py
النتيجة:  assets/textures/*.png  (albedo)  و *_normal.png
"""
from __future__ import annotations

import os

import numpy as np
from PIL import Image

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "textures")
SIZE = 512


def spectral_noise(size: int, beta: float, seed: int) -> np.ndarray:
    """ضجيج دوري (tileable) عبر ترشيح الطيف بالترددات."""
    rng = np.random.default_rng(seed)
    white = rng.normal(size=(size, size))
    freq = np.fft.fft2(white)
    fy = np.fft.fftfreq(size)[:, None]
    fx = np.fft.fftfreq(size)[None, :]
    radius = np.sqrt(fx ** 2 + fy ** 2)
    radius[0, 0] = 1e-6
    freq *= 1.0 / (radius ** beta)
    out = np.real(np.fft.ifft2(freq))
    out -= out.min()
    peak = out.max()
    return out / peak if peak > 1e-9 else out


def fbm(size: int, seed: int, octaves: int = 5, beta: float = 2.0,
        gain: float = 0.5) -> np.ndarray:
    """مجموع طبقات ضجيج بنسب مختلفة — يعطي تفاصيل طبيعية."""
    total = np.zeros((size, size))
    amplitude = 1.0
    norm = 0.0
    for octave in range(octaves):
        total += amplitude * spectral_noise(size, beta, seed + octave * 977)
        norm += amplitude
        amplitude *= gain
    total /= norm
    return (total - total.min()) / max(1e-9, float(total.max() - total.min()))


def colorize(height: np.ndarray, low: tuple, high: tuple,
             tint: np.ndarray | None = None) -> np.ndarray:
    """تحويل خريطة ارتفاع 0..1 إلى صورة RGB مع تدرّج لوني."""
    low_c = np.array(low, dtype=np.float64)
    high_c = np.array(high, dtype=np.float64)
    t = height[..., None]
    rgb = low_c * (1.0 - t) + high_c * t
    if tint is not None:
        rgb *= tint[..., None]
    return np.clip(rgb, 0, 255).astype(np.uint8)


def normal_map(height: np.ndarray, strength: float = 3.0) -> np.ndarray:
    """خريطة نتوءات تفاضلية متوافقة مع التكرار."""
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * strength
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * strength
    nx = -dx
    ny = -dy
    nz = np.ones_like(height)
    length = np.sqrt(nx ** 2 + ny ** 2 + nz ** 2)
    out = np.stack([nx / length, ny / length, nz / length], axis=-1)
    return ((out * 0.5 + 0.5) * 255).astype(np.uint8)


def save(name: str, albedo: np.ndarray, height: np.ndarray,
         strength: float = 3.0) -> None:
    Image.fromarray(albedo, "RGB").save(os.path.join(OUT_DIR, f"{name}.png"),
                                        optimize=True)
    Image.fromarray(normal_map(height, strength), "RGB").save(
        os.path.join(OUT_DIR, f"{name}_normal.png"), optimize=True)


def sand() -> None:
    base = fbm(SIZE, 11, octaves=6, beta=2.1)
    ripples = 0.5 + 0.5 * np.sin(
        np.linspace(0, 12 * np.pi, SIZE)[None, :]
        + 6.0 * fbm(SIZE, 31, octaves=3, beta=2.4)
    )
    height = np.clip(base * 0.72 + ripples * 0.28, 0, 1)
    grain = spectral_noise(SIZE, 0.6, 501)
    height = np.clip(height * 0.9 + grain * 0.1, 0, 1)
    save("sand", colorize(height, (150, 124, 84), (214, 190, 146)), height, 2.4)

    gravel = fbm(SIZE, 77, octaves=5, beta=1.9)
    save("sand_rock", colorize(gravel, (96, 86, 72), (168, 156, 134)), gravel, 4.0)


def concrete() -> None:
    height = fbm(SIZE, 23, octaves=7, beta=1.5)
    stains = fbm(SIZE, 91, octaves=3, beta=2.6)
    height = np.clip(height * 0.8 + stains * 0.2, 0, 1)
    rgb = colorize(height, (118, 114, 104), (190, 186, 174))
    # حصى ناعم داخل الخرسانة
    grit = spectral_noise(SIZE, 0.35, 616)
    rgb = np.clip(rgb.astype(np.float64) * (0.86 + grit[..., None] * 0.28), 0, 255)
    rgb = rgb.astype(np.uint8)
    # شقوق رقيقة
    cracks = spectral_noise(SIZE, 1.1, 404)
    mask = cracks > 0.78
    rgb[mask] = (rgb[mask] * 0.55).astype(np.uint8)
    height = np.where(mask, height * 0.4, height)
    save("concrete", rgb, height, 3.2)


def asphalt() -> None:
    height = fbm(SIZE, 55, octaves=7, beta=1.3)
    rgb = colorize(height, (44, 44, 46), (96, 96, 100))
    speck = spectral_noise(SIZE, 0.5, 888) > 0.82
    rgb[speck] = (150, 148, 142)
    save("asphalt", rgb, height, 3.0)


def metal() -> None:
    height = fbm(SIZE, 133, octaves=7, beta=1.4)
    rust = fbm(SIZE, 171, octaves=5, beta=1.9)
    scratches = spectral_noise(SIZE, 0.4, 719)
    rgb = colorize(height, (86, 92, 96), (150, 156, 160))
    rust_mask = np.clip((rust - 0.68) * 3.4, 0, 1)[..., None]
    rust_color = np.array([142, 78, 44], dtype=np.float64)
    rgb = rgb * (1 - rust_mask) + rust_color * rust_mask
    rgb = np.clip(rgb * (0.9 + scratches[..., None] * 0.22), 0, 255).astype(np.uint8)
    save("metal", rgb, height, 2.6)


def plaster() -> None:
    height = fbm(SIZE, 202, octaves=6, beta=1.8)
    rgb = colorize(height, (176, 154, 122), (226, 208, 178))
    chipped = spectral_noise(SIZE, 1.3, 303) > 0.76
    rgb[chipped] = np.array([150, 128, 102], dtype=np.uint8)
    save("plaster", rgb, height, 3.0)


def wood() -> None:
    stripes = 0.5 + 0.5 * np.sin(
        np.linspace(0, 26 * np.pi, SIZE)[None, :]
        + 3.0 * fbm(SIZE, 404, octaves=3, beta=2.2)
    )
    grain = fbm(SIZE, 411, octaves=6, beta=1.2)
    height = np.clip(stripes * 0.65 + grain * 0.35, 0, 1)
    save("wood", colorize(height, (86, 60, 38), (150, 112, 72)), height, 3.4)


def camo() -> None:
    """قماش تمويه عسكري للزيّ (يُستخدم على مجسمات الجنود)."""
    a = fbm(SIZE, 601, octaves=4, beta=2.4)
    b = fbm(SIZE, 707, octaves=4, beta=2.4)
    rgb = np.empty((SIZE, SIZE, 3), dtype=np.float64)
    rgb[:] = (78, 82, 56)
    rgb[(a > 0.5)] = (54, 60, 40)
    rgb[(b > 0.62)] = (96, 92, 64)
    rgb[(a < 0.28)] = (36, 40, 30)
    grain = spectral_noise(SIZE, 0.7, 909)[..., None]
    rgb = np.clip(rgb * (0.85 + grain * 0.3), 0, 255).astype(np.uint8)
    save("camo", rgb, a, 1.2)


def rock() -> None:
    layered = fbm(SIZE, 808, octaves=7, beta=1.3)
    crack = spectral_noise(SIZE, 1.0, 121) > 0.8
    rgb = colorize(layered, (74, 70, 64), (146, 138, 126))
    rgb[crack] = (rgb[crack] * 0.5).astype(np.uint8)
    layered = np.where(crack, layered * 0.5, layered)
    save("rock", rgb, layered, 5.0)


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    sand()
    concrete()
    asphalt()
    metal()
    plaster()
    wood()
    camo()
    rock()
    print("textures written to", os.path.abspath(OUT_DIR))


if __name__ == "__main__":
    main()

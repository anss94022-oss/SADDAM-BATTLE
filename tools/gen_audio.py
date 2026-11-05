#!/usr/bin/env python3
"""SADDAM BATTLE — مولّد المؤثرات الصوتية والموسيقى الأصلي.

كل الأصوات مخلّقة رقمياً (تركيب موجات وضجيج) داخل هذا السكربت، بلا أي
مصادر خارجية — تُرخَّص مع المشروع.

التشغيل:  python3 tools/gen_audio.py
النتيجة:  assets/audio/sfx/*.wav و assets/audio/music/*.wav
"""
from __future__ import annotations

import os
import wave

import numpy as np

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX_DIR = os.path.join(ROOT, "assets", "audio", "sfx")
MUSIC_DIR = os.path.join(ROOT, "assets", "audio", "music")
RNG = np.random.default_rng(20261105)


# ----------------------------------------------------------------- أدوات
def t(seconds: float) -> np.ndarray:
    return np.linspace(0.0, seconds, int(SR * seconds), endpoint=False)


def noise(seconds: float) -> np.ndarray:
    return RNG.normal(size=int(SR * seconds))


def lowpass(signal: np.ndarray, cutoff: float) -> np.ndarray:
    """مرشّح أحادي القطب (one-pole) — كافٍ لصناعة أطياف الأسلحة."""
    alpha = np.exp(-2.0 * np.pi * cutoff / SR)
    out = np.empty_like(signal)
    acc = 0.0
    for index in range(signal.size):
        acc = (1.0 - alpha) * signal[index] + alpha * acc
        out[index] = acc
    return out


def lowpass_fast(signal: np.ndarray, cutoff: float) -> np.ndarray:
    """مرشّح تمرير منخفض بضرب طيفي (أسرع بكثير على الإشارات الطويلة)."""
    spectrum = np.fft.rfft(signal)
    freqs = np.fft.rfftfreq(signal.size, 1.0 / SR)
    gain = 1.0 / (1.0 + (freqs / max(1.0, cutoff)) ** 2)
    return np.fft.irfft(spectrum * gain, n=signal.size)


def highpass_fast(signal: np.ndarray, cutoff: float) -> np.ndarray:
    spectrum = np.fft.rfft(signal)
    freqs = np.fft.rfftfreq(signal.size, 1.0 / SR)
    gain = (freqs / max(1.0, cutoff)) ** 2
    gain = gain / (1.0 + gain)
    return np.fft.irfft(spectrum * gain, n=signal.size)


def env(signal: np.ndarray, attack: float, decay: float,
        curve: float = 2.0) -> np.ndarray:
    n = signal.size
    a = max(1, int(SR * attack))
    ramp_up = np.linspace(0.0, 1.0, a) ** 0.6
    tail = np.linspace(0.0, 1.0, n - a) if n > a else np.array([])
    ramp_down = np.exp(-decay * tail * (1.0 + curve))
    return signal * np.concatenate([ramp_up, ramp_down])


def normalize(signal: np.ndarray, peak: float = 0.92) -> np.ndarray:
    top = np.max(np.abs(signal))
    if top < 1e-9:
        return signal
    return signal / top * peak


def write_wav(path: str, signal: np.ndarray, peak: float = 0.92) -> None:
    data = normalize(np.asarray(signal, dtype=np.float64), peak)
    pcm = np.clip(data, -1.0, 1.0)
    pcm = (pcm * 32767.0).astype("<i2")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SR)
        handle.writeframes(pcm.tobytes())
    print(f"{os.path.relpath(path, ROOT):48s} {signal.size / SR:5.2f}s")


def make_loop(signal: np.ndarray, fade: float = 0.12) -> np.ndarray:
    """يجعل المقطع قابلاً للتكرار عبر مزج الذيل مع البداية."""
    n = int(SR * fade)
    if signal.size <= 2 * n:
        return signal
    head = signal[:n].copy()
    tail = signal[-n:].copy()
    ramp = np.linspace(0.0, 1.0, n)
    signal = signal[:-n].copy()
    signal[:n] = head * ramp + tail * (1.0 - ramp)
    return signal


# --------------------------------------------------------------- الأسلحة
def gunshot(seconds: float, body_hz: float, crack_hz: float,
            decay: float, noise_mix: float = 1.0) -> np.ndarray:
    duration = t(seconds)
    body = np.sin(2 * np.pi * body_hz * duration) * np.exp(-decay * 2.2 * duration)
    crack = highpass_fast(noise(seconds), crack_hz *
                          (0.6 + 0.4 * RNG.random())) * np.exp(-decay * 9.0 * duration)
    rumble = lowpass_fast(noise(seconds), 220.0) * np.exp(-decay * 1.1 * duration)
    mixed = body * 0.55 + crack * noise_mix + rumble * 0.5
    return mixed - np.mean(mixed)


def build_weapons() -> None:
    write_wav(os.path.join(SFX_DIR, "shot_rifle.wav"),
              gunshot(0.34, 96.0, 900.0, 7.0), 0.88)
    write_wav(os.path.join(SFX_DIR, "shot_lmg.wav"),
              gunshot(0.40, 78.0, 700.0, 6.0), 0.9)
    write_wav(os.path.join(SFX_DIR, "shot_hmg.wav"),
              gunshot(0.52, 64.0, 520.0, 5.0), 0.93)
    write_wav(os.path.join(SFX_DIR, "shot_pistol.wav"),
              gunshot(0.22, 148.0, 1400.0, 11.0), 0.8)
    write_wav(os.path.join(SFX_DIR, "shot_smg.wav"),
              gunshot(0.26, 118.0, 1100.0, 9.5), 0.82)
    write_wav(os.path.join(SFX_DIR, "shot_shotgun.wav"),
              gunshot(0.62, 52.0, 480.0, 5.0), 0.95)
    write_wav(os.path.join(SFX_DIR, "shot_sniper.wav"),
              gunshot(1.35, 44.0, 1200.0, 2.6), 0.98)
    write_wav(os.path.join(SFX_DIR, "shot_silenced.wav"),
              gunshot(0.20, 210.0, 1900.0, 14.0, 0.45), 0.55)

    # صاروخ: هسهسة دفع ثم انفجار.
    launch = t(0.9)
    hiss = highpass_fast(noise(0.9), 1400.0) * np.exp(-2.0 * launch)
    thrust = np.sin(2 * np.pi * (140 - 60 * launch) * launch) * np.exp(-3.0 * launch)
    write_wav(os.path.join(SFX_DIR, "rpg_launch.wav"), hiss * 0.7 + thrust * 0.5, 0.9)


def build_explosions() -> None:
    duration = t(2.2)
    boom = lowpass_fast(noise(2.2), 160.0) * np.exp(-1.6 * duration)
    crack = highpass_fast(noise(2.2), 2200.0) * np.exp(-16.0 * duration)
    sub = np.sin(2 * np.pi * (58 - 22 * duration) * duration) * np.exp(-2.2 * duration)
    rumble = lowpass_fast(noise(2.2), 60.0) * np.exp(-0.9 * duration)
    write_wav(os.path.join(SFX_DIR, "explosion.wav"),
              boom * 1.0 + crack * 0.45 + sub * 0.8 + rumble * 1.4, 0.98)

    small = t(1.1)
    write_wav(os.path.join(SFX_DIR, "explosion_small.wav"),
              lowpass_fast(noise(1.1), 220.0) * np.exp(-3.0 * small)
              + highpass_fast(noise(1.1), 2600.0) * np.exp(-20.0 * small) * 0.5
              + np.sin(2 * np.pi * 70 * small) * np.exp(-4.0 * small) * 0.6, 0.94)

    # رصاصة تصيب معدناً/حجراً.
    clink = t(0.18)
    ring = (np.sin(2 * np.pi * 1750 * clink) + 0.6 * np.sin(2 * np.pi * 2620 * clink))
    write_wav(os.path.join(SFX_DIR, "impact_metal.wav"),
              ring * np.exp(-26.0 * clink) + noise(0.18) * np.exp(-40.0 * clink) * 0.4, 0.7)
    thud = t(0.16)
    write_wav(os.path.join(SFX_DIR, "impact_dirt.wav"),
              lowpass_fast(noise(0.16), 900.0) * np.exp(-30.0 * thud), 0.6)
    flesh = t(0.20)
    write_wav(os.path.join(SFX_DIR, "impact_flesh.wav"),
              lowpass_fast(noise(0.20), 500.0) * np.exp(-24.0 * flesh), 0.65)


def build_player_sfx() -> None:
    for index in range(1, 4):
        step = t(0.16)
        body = lowpass_fast(noise(0.16), 380.0 + index * 90) * np.exp(-34.0 * step)
        grit = highpass_fast(noise(0.16), 2600.0) * np.exp(-60.0 * step) * 0.25
        write_wav(os.path.join(SFX_DIR, f"footstep_{index}.wav"),
                  body + grit, 0.45)

    # تلقيم: إخراج المخزن، إدخاله، ثم تثبيت.
    code = np.zeros(int(SR * 1.05))
    for start, level in ((0.02, 0.9), (0.42, 0.75), (0.75, 0.6)):
        click = t(0.09)
        burst = highpass_fast(noise(0.09), 1500.0) * np.exp(-55.0 * click)
        tone = np.sin(2 * np.pi * 300 * click) * np.exp(-45.0 * click) * 0.5
        offset = int(start * SR)
        code[offset:offset + burst.size] += (burst + tone) * level
    write_wav(os.path.join(SFX_DIR, "reload.wav"), code, 0.7)

    swap = t(0.22)
    write_wav(os.path.join(SFX_DIR, "weapon_switch.wav"),
              highpass_fast(noise(0.22), 1200.0) * np.exp(-22.0 * swap), 0.5)

    heal = t(0.7)
    write_wav(os.path.join(SFX_DIR, "heal.wav"),
              np.sin(2 * np.pi * (420 + 260 * heal) * heal) * np.exp(-3.2 * heal), 0.5)

    hurt = t(0.35)
    write_wav(os.path.join(SFX_DIR, "player_hurt.wav"),
              lowpass_fast(noise(0.35), 700.0) * np.exp(-9.0 * hurt)
              + np.sin(2 * np.pi * 95 * hurt) * np.exp(-8.0 * hurt) * 0.6, 0.7)


def build_ui() -> None:
    click_s = t(0.09)
    write_wav(os.path.join(SFX_DIR, "ui_click.wav"),
              np.sin(2 * np.pi * 720 * click_s) * np.exp(-24.0 * click_s), 0.45)
    hover_s = t(0.06)
    write_wav(os.path.join(SFX_DIR, "ui_hover.wav"),
              np.sin(2 * np.pi * 1180 * hover_s) * np.exp(-40.0 * hover_s), 0.25)
    ready = t(0.9)
    write_wav(os.path.join(SFX_DIR, "ui_confirm.wav"),
              np.sin(2 * np.pi * (520 + 320 * ready) * ready) * np.exp(-3.4 * ready), 0.55)
    fail = t(1.0)
    write_wav(os.path.join(SFX_DIR, "ui_fail.wav"),
              np.sin(2 * np.pi * (320 - 140 * fail) * fail) * np.exp(-2.6 * fail), 0.55)


# ------------------------------------------------------- المحركات والمروحيات
def build_engines() -> None:
    def engine(seconds: float, base: float, harmonics: tuple,
               jitter: float, filt: float) -> np.ndarray:
        duration = t(seconds)
        wave_acc = np.zeros_like(duration)
        for index, amplitude in enumerate(harmonics):
            wave_acc += amplitude * np.sin(
                2 * np.pi * base * (index + 1) * duration
                + 0.4 * np.sin(2 * np.pi * 3.0 * duration)
            )
        wave_acc *= 1.0 + 0.08 * np.sin(2 * np.pi * jitter * duration)
        rumble = lowpass_fast(noise(seconds), filt) * 0.35
        return make_loop(lowpass_fast(wave_acc * 0.6 + rumble, 2600.0))

    write_wav(os.path.join(SFX_DIR, "engine_car_loop.wav"),
              engine(2.0, 68.0, (1.0, 0.5, 0.3, 0.18), 7.0, 320.0), 0.8)
    write_wav(os.path.join(SFX_DIR, "engine_truck_loop.wav"),
              engine(2.0, 48.0, (1.0, 0.6, 0.35, 0.22), 5.0, 220.0), 0.85)
    write_wav(os.path.join(SFX_DIR, "engine_bike_loop.wav"),
              engine(1.5, 105.0, (1.0, 0.55, 0.4, 0.25, 0.12), 11.0, 520.0), 0.75)

    # مروحية: دفعات مراوح + عويل توربين.
    seconds = 2.0
    duration = t(seconds)
    thump = np.sin(2 * np.pi * 17.0 * duration)
    thump = np.clip(thump, 0.0, None) ** 1.6
    turbine = np.sin(2 * np.pi * 210 * duration + 2.0 * np.sin(2 * np.pi * 2 * duration))
    wash = lowpass_fast(noise(seconds), 900.0)
    write_wav(os.path.join(SFX_DIR, "rotor_loop.wav"),
              make_loop(thump * 0.5 + turbine * 0.22 + wash * 0.4), 0.85)


def build_ambience() -> None:
    seconds = 6.0
    duration = t(seconds)
    wind = lowpass_fast(noise(seconds), 520.0)
    gust = 0.55 + 0.45 * np.sin(2 * np.pi * 0.11 * duration)
    whistle = np.sin(2 * np.pi * (420 + 40 * np.sin(2 * np.pi * 0.07 * duration)) * duration)
    write_wav(os.path.join(SFX_DIR, "ambience_wind_loop.wav"),
              make_loop(wind * gust * 0.9 + whistle * 0.03, 0.4), 0.5)

    seconds = 5.0
    duration = t(seconds)
    night = lowpass_fast(noise(seconds), 260.0) * 0.7
    crickets = np.zeros_like(duration)
    for start in np.arange(0.0, seconds, 0.22):
        offset = int(start * SR)
        length = int(0.06 * SR)
        if offset + length >= crickets.size:
            break
        chirp = np.sin(2 * np.pi * 4200 * np.linspace(0, 0.06, length))
        crickets[offset:offset + length] += chirp * np.hanning(length) * 0.12
    write_wav(os.path.join(SFX_DIR, "ambience_night_loop.wav"),
              make_loop(night + crickets, 0.3), 0.45)


# ------------------------------------------------------------------ الموسيقى
def note(freq: float, seconds: float, kind: str = "sine") -> np.ndarray:
    duration = t(seconds)
    if kind == "saw":
        wave_f = 2.0 * ((freq * duration) % 1.0) - 1.0
    elif kind == "tri":
        wave_f = 2.0 * np.abs(2.0 * ((freq * duration) % 1.0) - 1.0) - 1.0
    else:
        wave_f = np.sin(2 * np.pi * freq * duration)
    return wave_f


def build_music() -> None:
    # مقام شرقي (حجاز) — درون + إيقاع بطيء.
    scale = [220.0, 233.1, 277.2, 293.7, 329.6, 349.2, 415.3, 440.0]

    def pad(seconds: float, tones: list, drone_hz: float) -> np.ndarray:
        out = np.zeros(int(SR * seconds))
        for index, freq in enumerate(tones):
            voice = note(freq, seconds, "saw") * 0.10
            voice += note(freq * 1.005, seconds, "tri") * 0.07
            swell = 0.55 + 0.45 * np.sin(2 * np.pi * (0.05 + 0.02 * index) *
                                          np.linspace(0, seconds, out.size))
            out += lowpass_fast(voice * swell, 1800.0)
        out += lowpass_fast(note(drone_hz, seconds, "tri"), 400.0) * 0.28
        return out

    def darbuka(seconds: float, hits: list) -> np.ndarray:
        out = np.zeros(int(SR * seconds))
        for when, level, pitch in hits:
            length = int(0.12 * SR)
            offset = int(when * SR)
            if offset + length >= out.size:
                continue
            hit_t = np.linspace(0, 0.12, length)
            hit = np.sin(2 * np.pi * (pitch - pitch * 2.5 * hit_t) * hit_t)
            hit = hit * np.exp(-32.0 * hit_t) + noise(0.12) * np.exp(-70.0 * hit_t) * 0.3
            out[offset:offset + length] += hit * level
        return out

    # موسيقى القائمة — 24 ثانية، حالة تأهب هادئة.
    seconds = 24.0
    menu = pad(seconds, [scale[0], scale[2], scale[4]], 110.0) * 0.55
    hits = [(i * 0.75, 0.35 if i % 4 else 0.6, 180.0 if i % 4 else 92.0)
            for i in range(int(seconds / 0.75))]
    menu += darbuka(seconds, hits) * 0.5
    melody = np.zeros_like(menu)
    sequence = [0, 2, 1, 3, 2, 4, 3, 5, 4, 3, 2, 1]
    for index, step in enumerate(sequence * 2):
        start = index * 1.0
        length = 0.95
        offset = int(start * SR)
        n = int(length * SR)
        if offset + n >= melody.size:
            break
        tone = note(scale[step] * 2.0, length, "tri")
        tone = tone * np.exp(-2.4 * np.linspace(0, length, n))
        melody[offset:offset + n] += tone * 0.14
    write_wav(os.path.join(MUSIC_DIR, "menu_theme.wav"),
              make_loop(menu + melody, 0.6), 0.75)

    # موسيقى القتال — 16 ثانية، إيقاع أسرع.
    seconds = 16.0
    action = pad(seconds, [scale[0], scale[3], scale[5]], 82.0) * 0.4
    hits = []
    for index in range(int(seconds / 0.25)):
        when = index * 0.25
        if index % 4 == 0:
            hits.append((when, 0.7, 88.0))
        elif index % 2 == 0:
            hits.append((when, 0.35, 200.0))
        else:
            hits.append((when, 0.18, 320.0))
    action += darbuka(seconds, hits)
    # نبض بيس خفيف
    bass = np.zeros(int(SR * seconds))
    for index in range(int(seconds / 1.0)):
        start = index * 1.0
        n = int(0.9 * SR)
        offset = int(start * SR)
        if offset + n >= bass.size:
            break
        tone = note(scale[0] / 2.0, 0.9, "saw")
        bass[offset:offset + n] += tone * np.exp(-1.8 * np.linspace(0, 0.9, n)) * 0.2
    write_wav(os.path.join(MUSIC_DIR, "battle_theme.wav"),
              make_loop(action + bass, 0.5), 0.8)


def main() -> None:
    build_weapons()
    build_explosions()
    build_player_sfx()
    build_ui()
    build_engines()
    build_ambience()
    build_music()


if __name__ == "__main__":
    main()

"""Buat nada alarm aplikasi tanpa pustaka audio eksternal.

Jalankan: python android/tool/buat_nada_alarm.py [lonceng|gamelan|marimba|beep]
Tanpa argumen memakai `gamelan`. Hasil ditulis ke android/app/src/main/res/raw/agenda_alarm.wav
(mono 44.1 kHz, 16-bit) sehingga langsung dipakai AlarmReceiver.
"""
import math
import struct
import sys
import wave

SR = 44100
TUJUAN = "android/app/src/main/res/raw/agenda_alarm.wav"


def nada(freq: float, dur: float, rasio: list[float], amp: list[float], tau: float, gemerik: float = 0.0) -> list[float]:
    """Satu ketuk: partial (rasio kali frekuensi dasar) dengan pudar eksponensial dan gemerik logam."""
    n = int(SR * dur)
    keluaran = []
    for i in range(n):
        t = i / SR
        v = 0.0
        for j, (r, a) in enumerate(zip(rasio, amp)):
            # Partial atas pudar lebih cepat, seperti logam gamelan.
            tt = tau * (0.9 - 0.28 * j)
            v += a * math.sin(2 * math.pi * freq * r * t) * math.exp(-t / tt)
        if gemerik:
            v *= 1.0 + gemerik * math.sin(2 * math.pi * 5.5 * t)
        keluaran.append(v)
    return keluaran


def gabung(pola: list[tuple[float, float, float]], dur_total: float, rasio, amp, tau, gemerik, echo_gain: float, pad_gain: float) -> list[float]:
    sig = [0.0] * int(SR * dur_total)
    for mulai, freq, g in pola:
        b = nada(freq, 1.5, rasio, amp, tau, gemerik)
        mulai_i = int(mulai * SR)
        for i, v in enumerate(b):
            if mulai_i + i < len(sig):
                sig[mulai_i + i] += v * g
    delay = int(0.28 * SR)
    for i in range(len(sig) - delay):
        sig[i + delay] += sig[i] * echo_gain
    for i in range(len(sig)):
        sig[i] += pad_gain * math.sin(2 * math.pi * 220 * i / SR) * math.exp(-i / SR / 0.9)
    return sig


def rapih(sig: list[float], puncak_target: float) -> list[float]:
    halus = [0.25, 0.5, 0.25]
    sig = [sum(sig[j - 2 + k] * halus[k] for k in range(3)) for j in range(2, len(sig) - 2)]
    puncak = max(abs(v) for v in sig)
    sig = [v / puncak * puncak_target for v in sig]
    fade = int(0.03 * SR)
    for i in range(fade):
        sig[i] *= i / fade
        sig[-1 - i] *= i / fade
    return sig


JENIS = {
    # Lonceng Barat: triad naik, dua rangkaian.
    "lonceng": dict(
        dur=3.0,
        pola=[(0.0, 440.0, 0.95), (0.48, 523.25, 0.90), (0.96, 659.25, 0.85), (1.72, 659.25, 0.62), (2.20, 783.99, 0.55)],
        rasio=[1.0, 2.0, 2.76, 4.6], amp=[1.0, 0.42, 0.22, 0.11], tau=0.42, gemerik=0.0, echo=0.26, pad=0.10, puncak=0.85,
    ),
    # Gamelan slendro: lima nada per oktaf kira-kira sama jarak, ketuk logam dengan gemerik.
    "gamelan": dict(
        dur=3.4,
        pola=[
            (0.0, 470.0, 0.95), (0.42, 539.9, 0.9), (0.84, 620.2, 0.85),
            (1.55, 620.2, 0.6), (2.02, 714.9, 0.55), (2.5, 824.3, 0.45),
        ],
        rasio=[1.0, 1.62, 2.42, 3.3], amp=[1.0, 0.5, 0.3, 0.16], tau=0.5, gemerik=0.06, echo=0.24, pad=0.12, puncak=0.82,
    ),
    # Marimba: nada hangat, pudar cepat, tiga ketuk.
    "marimba": dict(
        dur=2.6,
        pola=[(0.0, 523.25, 0.95), (0.34, 659.25, 0.9), (0.68, 783.99, 0.85), (1.5, 659.25, 0.55)],
        rasio=[1.0, 3.0, 5.0], amp=[1.0, 0.25, 0.12], tau=0.28, gemerik=0.0, echo=0.2, pad=0.06, puncak=0.85,
    ),
    # Beep kantor: dua ketuk tegas per rangkaian, paling jelas di ruang berisik.
    "beep": dict(
        dur=2.2,
        pola=[(0.0, 880.0, 0.9), (0.28, 880.0, 0.9), (1.1, 988.0, 0.85), (1.38, 988.0, 0.85)],
        rasio=[1.0, 2.0], amp=[1.0, 0.3], tau=0.14, gemerik=0.0, echo=0.12, pad=0.04, puncak=0.9,
    ),
}


def tulis(sig: list[float]) -> None:
    pcm = b"".join(struct.pack("<h", int(round(v * 32767))) for v in sig)
    with wave.open(TUJUAN, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(pcm)
    print(f"nada alarm ditulis ke {TUJUAN} ({len(pcm)} byte, {len(sig) / SR:.1f} detik)")


if __name__ == "__main__":
    jenis = sys.argv[1] if len(sys.argv) > 1 else "gamelan"
    if jenis not in JENIS:
        print(f"jenis tidak dikenal: {jenis} (pilih: {', '.join(sorted(JENIS))})")
        raise SystemExit(1)
    k = JENIS[jenis]
    tulis(rapih(gabung(k["pola"], k["dur"], k["rasio"], k["amp"], k["tau"], k["gemerik"], k["echo"], k["pad"]), k["puncak"]))
    print(f"jenis: {jenis}")

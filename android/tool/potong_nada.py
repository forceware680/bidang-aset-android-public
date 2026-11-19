"""Potong nada dering eksternal jadi nada alarm aplikasi.

Jalankan: python android/tool/potong_nada.py "<file.wav>" [detik] [fade_keluar]
Default 30 detik dengan fade keluar 2.5 detik. Hasil: mono, sama frekuensi sampel sumber,
16-bit, ditulis ke android/app/src/main/res/raw/agenda_alarm.wav.
"""
import sys
import wave

import numpy as np

TUJUAN = "android/app/src/main/res/raw/agenda_alarm.wav"


def potong(sumber: str, detik: float, fade: float) -> None:
    with wave.open(sumber, "rb") as w:
        rate = w.getframerate()
        ch = w.getnchannels()
        if w.getsampwidth() != 2:
            raise SystemExit("hanya mendukung WAV 16-bit")
        frames = w.readframes(int(detik * rate))
    data = np.frombuffer(frames, dtype=np.int16).astype(np.float64) / 32768.0
    if ch == 2:
        data = (data[0::2] + data[1::2]) / 2.0
    elif ch > 2:
        data = data.reshape(-1, ch).mean(axis=1)

    n = len(data)
    # Fade masuk singkat supaya tidak ada klik di awal.
    masuk = int(0.05 * rate)
    if masuk > 0:
        data[:masuk] *= np.linspace(0, 1, masuk)
    # Fade keluar halus (raised cosine), bukan linear, supaya ujungnya tidak terpotong mendadak.
    keluar = int(fade * rate)
    if keluar > 0:
        ujung = min(keluar, n)
        data[n - ujung:] *= 0.5 * (1 + np.cos(np.linspace(0, np.pi, ujung)))

    puncak = np.max(np.abs(data)) or 1.0
    data = data / puncak * 0.85
    pcm = (data * 32767).astype(np.int16).tobytes()

    with wave.open(TUJUAN, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(rate)
        f.writeframes(pcm)
    print(f"nada alarm ditulis ke {TUJUAN}: {len(pcm) / 2 / rate:.1f} detik, {rate} Hz mono, {len(pcm)} byte")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit("pakai: python android/tool/potong_nada.py <sumber.wav> [detik] [fade_keluar]")
    potong(sys.argv[1], float(sys.argv[2]) if len(sys.argv) > 2 else 30.0, float(sys.argv[3]) if len(sys.argv) > 3 else 2.5)

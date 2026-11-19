# Generate ikon notifikasi dari assets/logo.png ke android res drawable.
# - notification_small.png : siluet putih, glyph di-crop ke bounding-box asli lalu DI-FILL penuh 72px
#   (logo punya padding transparan besar; tanpa crop glyph tenggelam ~60% di dalam kotak),
#   garis asli logo dipertahankan tipis — pengisian penuh kotak yang bikin ikon terbaca.
# - notification_large.png : logo warna penuh.
# Jalankan ulang kalau logo berubah: python scripts/bikin_ikon_notif.py
from PIL import Image, ImageFilter

RES = "android/app/src/main/res/drawable"
src = Image.open("assets/logo.png").convert("RGBA")
a = src.split()[3]
bb = a.getbbox()
glyph = src.crop(bb)

# kecil: isi penuh kotak 72px + garis tebal
skala = 72 / max(glyph.width, glyph.height)
kecil = glyph.resize((round(glyph.width * skala), round(glyph.height * skala)), Image.Resampling.LANCZOS)
kanvas = Image.new("RGBA", (72, 72), (0, 0, 0, 0))
kanvas.paste(kecil, ((72 - kecil.width) // 2, (72 - kecil.height) // 2))
# tanpa dilate: garis asli logo sudah tipis; pengisian penuh kotak yang bikin ikon terbaca
alpha = kanvas.split()[3]
siluet = Image.composite(
    Image.new("RGBA", kanvas.size, (255, 255, 255, 255)),
    Image.new("RGBA", kanvas.size, (255, 255, 255, 0)),
    alpha,
)
siluet.save(f"{RES}/notification_small.png")

# besar: logo warna penuh, proporsional (jangan stretch ke kotak — glyph 120x134 di-fit tinggi 72)
skala_b = 72 / max(glyph.width, glyph.height)
besar = glyph.resize((round(glyph.width * skala_b), round(glyph.height * skala_b)), Image.Resampling.LANCZOS)
kanvas_b = Image.new("RGBA", (72, 72), (0, 0, 0, 0))
kanvas_b.paste(besar, ((72 - besar.width) // 2, (72 - besar.height) // 2))
kanvas_b.save(f"{RES}/notification_large.png")
print("small:", siluet.size, "| large:", besar.size)

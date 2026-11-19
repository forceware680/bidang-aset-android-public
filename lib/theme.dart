import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pengingat.dart';

/// Identitas merek: karang sama dengan aplikasi web Bidang Aset.
/// Dari seed ini Material 3 menurunkan palet tonal (netral dan container), lalu
/// peran utama dikunci ke merek supaya aplikasi HP dan web terasa satu produk.
const Color kar = Color(0xFFF87D3B);
const Color karTeks = Color(0xFF361405);
const Color kanvas = Color(0xFF140E0B);
const Color kartu = Color(0xFF1E1815);
const Color lapis = Color(0xFF231C1A);
const Color hover = Color(0xFF302623);
const Color garis = Color(0xFF3A302D);
const Color garisIsian = Color(0xFF7D6E67);
const Color teks = Color(0xFFEFEEEA);
const Color redup = Color(0xFFB2A99F);

/// Skala bentuk Material 3.
const double ekstraKecil = 4;
const double kecil = 8;
const double sedang = 12;
const double besar = 16;
const double ekstraBesar = 28;

BorderRadius bentuk(double radius) => BorderRadius.circular(radius);
BorderRadius pil() => BorderRadius.circular(999);

/// Duo warna satu makna: teks di atas latar. Batas lencana memakai peran
/// `outline` netral supaya kontrasnya seragam di semua latar status.
class Trio {
  final Color teks;
  final Color latar;
  const Trio(this.teks, this.latar);

  Trio lerp(Trio other, double t) => Trio(
        Color.lerp(teks, other.teks, t)!,
        Color.lerp(latar, other.latar, t)!,
      );
}

/// Makna status agenda di luar peran warna M3 standar (success / warning / danger).
/// Widget membaca peran ini, tidak menulisi hex mentah.
class EkstensiWarana extends ThemeExtension<EkstensiWarana> {
  final Trio selesai;
  final Trio berjalan;
  final Trio bahaya;
  final Trio netral;

  const EkstensiWarana({
    required this.selesai,
    required this.berjalan,
    required this.bahaya,
    required this.netral,
  });

  static const gelap = EkstensiWarana(
    selesai: Trio(Color(0xFF84CC87), Color(0xFF102511)),
    berjalan: Trio(Color(0xFFF8C479), Color(0xFF331F00)),
    bahaya: Trio(Color(0xFFFFAEAA), Color(0xFF331612)),
    netral: Trio(Color(0xFFD4BAD8), Color(0xFF261F27)),
  );

  @override
  EkstensiWarana copyWith({Trio? selesai, Trio? berjalan, Trio? bahaya, Trio? netral}) {
    return EkstensiWarana(
      selesai: selesai ?? this.selesai,
      berjalan: berjalan ?? this.berjalan,
      bahaya: bahaya ?? this.bahaya,
      netral: netral ?? this.netral,
    );
  }

  @override
  EkstensiWarana lerp(EkstensiWarana? other, double t) {
    if (other == null) return this;
    return EkstensiWarana(
      selesai: selesai.lerp(other.selesai, t),
      berjalan: berjalan.lerp(other.berjalan, t),
      bahaya: bahaya.lerp(other.bahaya, t),
      netral: netral.lerp(other.netral, t),
    );
  }
}

/// Trio untuk satu kode status agenda.
Trio warnaStatus(BuildContext context, String kode) {
  final e = Theme.of(context).extension<EkstensiWarana>()!;
  switch (kode) {
    case 'selesai':
      return e.selesai;
    case 'berlangsung':
    case 'dijadwalkan_ulang':
      return e.berjalan;
    case 'dibatalkan':
      return e.bahaya;
    default:
      return e.netral;
  }
}

/// Ikon pendamping lencana — warna tidak pernah jadi satu-satunya penanda makna.
IconData ikonStatus(String kode) {
  switch (kode) {
    case 'selesai':
      return Icons.check_circle;
    case 'berlangsung':
      return Icons.play_circle_outline;
    case 'dijadwalkan_ulang':
      return Icons.event_repeat;
    case 'dibatalkan':
      return Icons.cancel;
    default:
      return Icons.calendar_today;
  }
}

/// Durasi animasi; nol bila pengguna mematikan animasi di pengaturan HP.
Duration durasiGerakan(BuildContext context) {
  final ditolak = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  return ditolak ? Duration.zero : const Duration(milliseconds: 200);
}

/// Skala tipografi Material 3. Fonta mengikuti sistem Android (Roboto).
TextTheme tipografiM3(ColorScheme skema) {
  TextStyle t(double ukuran, FontWeight berat, double tinggi, double jarak, Color warna) => TextStyle(
        fontSize: ukuran,
        fontWeight: berat,
        height: tinggi / ukuran,
        letterSpacing: jarak,
        color: warna,
      );

  final kuat = skema.onSurface;
  final sedang = skema.onSurfaceVariant;

  return TextTheme(
    displayLarge: t(57, FontWeight.w400, 64, -0.25, kuat),
    displayMedium: t(45, FontWeight.w400, 52, 0, kuat),
    displaySmall: t(36, FontWeight.w400, 44, 0, kuat),
    headlineLarge: t(32, FontWeight.w400, 40, 0, kuat),
    headlineMedium: t(28, FontWeight.w400, 36, 0, kuat),
    headlineSmall: t(24, FontWeight.w400, 32, 0, kuat),
    titleLarge: t(22, FontWeight.w500, 28, 0, kuat),
    titleMedium: t(16, FontWeight.w500, 24, 0.15, kuat),
    titleSmall: t(14, FontWeight.w500, 20, 0.1, kuat),
    bodyLarge: t(16, FontWeight.w400, 24, 0.5, kuat),
    bodyMedium: t(14, FontWeight.w400, 20, 0.25, sedang),
    bodySmall: t(12, FontWeight.w400, 16, 0.4, sedang),
    labelLarge: t(14, FontWeight.w500, 20, 0.1, kuat),
    labelMedium: t(12, FontWeight.w500, 16, 0.5, sedang),
    labelSmall: t(11, FontWeight.w500, 16, 0.5, sedang),
  );
}

ThemeData temaAplikasi() {
  // Palet tonal M3 dari seed merek; netral dan container adalah turunannya.
  final seed = ColorScheme.fromSeed(seedColor: kar, brightness: Brightness.dark);
  final skema = seed.copyWith(
    primary: kar,
    onPrimary: karTeks,
    surface: kanvas,
    onSurface: teks,
    onSurfaceVariant: redup,
    surfaceContainerLowest: Color(0xFF120B08),
    surfaceContainerLow: kartu,
    surfaceContainer: lapis,
    surfaceContainerHigh: hover,
    surfaceContainerHighest: Color(0xFF3A302C),
    outline: garisIsian,
    outlineVariant: garis,
    error: Color(0xFFFFAEAA),
    onError: Color(0xFF410E0B),
    errorContainer: Color(0xFF331612),
    onErrorContainer: Color(0xFFFFD8D3),
    inverseSurface: teks,
    onInverseSurface: Color(0xFF1A1310),
  );

  final tipografi = tipografiM3(skema);
  final gayaTombol = ButtonStyle(
    shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: pil())),
    textStyle: WidgetStatePropertyAll(tipografi.labelLarge),
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
    minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
  );

  return ThemeData(
    brightness: Brightness.dark,
    colorScheme: skema,
    scaffoldBackgroundColor: skema.surface,
    textTheme: tipografi,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    extensions: const <ThemeExtension<dynamic>>[EkstensiWarana.gelap],
    appBarTheme: AppBarThemeData(
      backgroundColor: skema.surface,
      foregroundColor: skema.onSurface,
      elevation: 0,
      scrolledUnderElevation: 2,
      centerTitle: false,
      titleTextStyle: tipografi.titleLarge,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    cardTheme: CardThemeData(
      color: skema.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: bentuk(sedang)),
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    dividerTheme: DividerThemeData(color: skema.outlineVariant, thickness: 1, space: 1),
    navigationBarTheme: NavigationBarThemeData(
      height: 64,
      backgroundColor: skema.surfaceContainerLow,
      indicatorColor: skema.secondaryContainer,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStatePropertyAll(tipografi.labelMedium),
      iconTheme: WidgetStateProperty.resolveWith((keadaan) => IconThemeData(
            size: 24,
            color: keadaan.contains(WidgetState.selected) ? skema.onSecondaryContainer : skema.onSurfaceVariant,
          )),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: skema.primaryContainer,
      foregroundColor: skema.onPrimaryContainer,
      shape: RoundedRectangleBorder(borderRadius: bentuk(besar)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: gayaTombol.copyWith(
        backgroundColor: WidgetStateProperty.resolveWith((keadaan) =>
            keadaan.contains(WidgetState.disabled) ? skema.onSurfaceVariant.withValues(alpha: 0.2) : skema.primary),
        foregroundColor: WidgetStateProperty.resolveWith((keadaan) =>
            keadaan.contains(WidgetState.disabled) ? skema.onSurfaceVariant : skema.onPrimary),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: gayaTombol.copyWith(
        side: WidgetStateProperty.resolveWith((keadaan) => BorderSide(
              color: keadaan.contains(WidgetState.disabled) ? skema.outlineVariant : skema.outline,
            )),
        foregroundColor: WidgetStateProperty.resolveWith((keadaan) =>
            keadaan.contains(WidgetState.disabled) ? skema.onSurfaceVariant : skema.primary),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: gayaTombol.copyWith(
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
        foregroundColor: WidgetStateProperty.resolveWith((keadaan) =>
            keadaan.contains(WidgetState.disabled) ? skema.onSurfaceVariant : skema.primary),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: bentuk(kecil))),
        side: WidgetStatePropertyAll(BorderSide(color: skema.outline)),
        backgroundColor: WidgetStateProperty.resolveWith((keadaan) =>
            keadaan.contains(WidgetState.selected) ? skema.secondaryContainer : Colors.transparent),
        foregroundColor: WidgetStateProperty.resolveWith((keadaan) =>
            keadaan.contains(WidgetState.selected) ? skema.onSecondaryContainer : skema.onSurfaceVariant),
        textStyle: WidgetStatePropertyAll(tipografi.labelMedium),
        minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
      ),
    ),
    chipTheme: ChipThemeData(
      side: BorderSide(color: skema.outline),
      shape: RoundedRectangleBorder(borderRadius: pil()),
      labelStyle: tipografi.labelMedium!.copyWith(color: skema.onSurface),
      backgroundColor: Colors.transparent,
      iconTheme: IconThemeData(size: 18, color: skema.onSurfaceVariant),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: skema.onSurfaceVariant,
      textColor: skema.onSurface,
      shape: RoundedRectangleBorder(borderRadius: bentuk(kecil)),
      titleTextStyle: tipografi.titleMedium,
      subtitleTextStyle: tipografi.bodyMedium,
      minLeadingWidth: 0,
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(borderRadius: bentuk(kecil), borderSide: BorderSide(color: skema.outlineVariant)),
      enabledBorder: OutlineInputBorder(borderRadius: bentuk(kecil), borderSide: BorderSide(color: skema.outlineVariant)),
      focusedBorder: OutlineInputBorder(borderRadius: bentuk(kecil), borderSide: const BorderSide(color: kar, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: bentuk(kecil), borderSide: const BorderSide(color: Color(0xFFFFAEAA))),
      focusedErrorBorder: OutlineInputBorder(borderRadius: bentuk(kecil), borderSide: const BorderSide(color: Color(0xFFFFAEAA), width: 2)),
      hintStyle: tipografi.bodyMedium,
      labelStyle: tipografi.bodyMedium!.copyWith(color: skema.onSurfaceVariant),
      helperStyle: tipografi.bodySmall,
      errorStyle: tipografi.bodySmall!.copyWith(color: skema.error),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: skema.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: bentuk(ekstraBesar)),
      titleTextStyle: tipografi.headlineSmall,
      contentTextStyle: tipografi.bodyMedium,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: skema.inverseSurface,
      contentTextStyle: tipografi.bodyMedium!.copyWith(color: skema.onInverseSurface),
      actionTextColor: skema.inversePrimary,
      shape: RoundedRectangleBorder(borderRadius: bentuk(kecil)),
      behavior: SnackBarBehavior.floating,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: skema.primary),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: skema.inverseSurface,
        borderRadius: bentuk(ekstraKecil),
      ),
      textStyle: tipografi.labelSmall!.copyWith(color: skema.onInverseSurface),
      waitDuration: const Duration(milliseconds: 600),
    ),
  );
}

/// Tombol Material 3: utama filled, sekunder filled tonal, bahaya outlined merah.
/// Ripple, focus, dan label pembaca layar datang dari widget Material.
class TombolUtama extends StatelessWidget {
  final String label;
  final IconData ikon;
  final VoidCallback? onTap;
  final bool sekunder;
  final bool bahaya;
  final bool garis;
  final bool sedangMemuat;
  /// Label saat memuat: menyebut apa yang sedang dikerjakan (R-27), bukan
  /// spinner telanjang. Default: label asli + elipsis.
  final String? labelMemuat;
  const TombolUtama({
    super.key,
    required this.label,
    required this.ikon,
    this.onTap,
    this.sekunder = false,
    this.bahaya = false,
    this.garis = false,
    this.sedangMemuat = false,
    this.labelMemuat,
  });

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final isi = sedangMemuat
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Text(labelMemuat ?? '$label…'),
            ],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [Icon(ikon, size: 18), const SizedBox(width: 8), Text(label)],
          );

    final ditekan = sedangMemuat ? null : onTap;

    if (bahaya) {
      return OutlinedButton(
        onPressed: ditekan,
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(skema.error),
          side: WidgetStateProperty.resolveWith((keadaan) => BorderSide(
                color: keadaan.contains(WidgetState.disabled) ? skema.outlineVariant : skema.error.withValues(alpha: 0.6),
              )),
        ),
        child: isi,
      );
    }
    if (garis) {
      return OutlinedButton(onPressed: ditekan, child: isi);
    }
    if (sekunder) {
      return FilledButton.tonal(onPressed: ditekan, child: isi);
    }
    return FilledButton(onPressed: ditekan, child: isi);
  }
}

/// Lencana status: ikon + teks, jadi warna bukan satu-satunya penanda makna.
class Lencana extends StatelessWidget {
  final String label;
  final String kode;
  const Lencana({super.key, required this.label, required this.kode});

  @override
  Widget build(BuildContext context) {
    final trio = warnaStatus(context, kode);
    final skema = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Status: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: trio.latar,
          borderRadius: pil(),
          border: Border.all(color: skema.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ikonStatus(kode), size: 14, color: trio.teks),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: trio.teks)),
          ],
        ),
      ),
    );
  }
}

/// Beri tahu petugas bahwa alarm pengingat gagal dijadwalkan. Kalau notifikasi diblokir di HP,
/// tawarkan jalan ke pengaturan notifikasi; kegagalan lain hanya dilaporkan.
void umpanPengingat(BuildContext konteks, Pengingat pengingat, String pesan) {
  ScaffoldMessenger.of(konteks).showSnackBar(
    SnackBar(
      content: Text(pesan),
      action: pesan == pesanNotifikasiDiblokir
          ? SnackBarAction(label: 'Izinkan notifikasi', onPressed: () => pengingat.bukaPengaturanNotifikasi())
          : null,
    ),
  );
}

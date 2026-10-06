# MasterSafety — Autentikasi Biometrik Mata (Flutter)

Layar kunci → verifikasi keaslian (liveness) → pindai mata → embedding →
Cosine Similarity → animasi + SFX → profil + sapaan Text-to-Speech.
Access Denied 3 kali → **alarm sirene**.

## Alur

```
LockScreen (kamera depan, branding)
   │ tekan PINDAI MATA
   ▼
LivenessService (stream kamera + ML Kit)
   │  2 tantangan acak urutannya: KEDIP MATA & TOLEH KEPALA
   │  wajah dilacak (trackingId); berganti wajah -> ulang dari awal
   │  gagal/timeout -> dihitung Access Denied
   ▼
takePicture -> EyeEmbeddingService
   │  ML Kit: kontur mata -> crop kiri/kanan -> embedding (TFLite / LBP demo)
   ▼
MatchService: Cosine Similarity vs SQLite, ambang = 0.90 (bisa dikalibrasi)
   ├─ COCOK  -> "MATCH FOUND" + match_found.wav -> ProfileScreen + TTS
   │            (pemindaian sah juga MEMATIKAN alarm)
   └─ TIDAK  -> "ACCESS DENIED" + access_denied.wav
                 gagal ke-3 berturut-turut -> ALARM (alarm.wav loop + getar
                 + banner merah + layar berkedip) selama 60 dtk; ditolak lagi
                 saat alarm menyala memperpanjang durasi.
```

## Struktur folder

```
lib/
  main.dart
  core/theme.dart
  models/user_profile.dart
  data/user_repository.dart        # SQLite: users, access_log
  services/
    app_services.dart              # kamera, wiring, simpan ambang
    audio_service.dart             # SFX match / denied / scan
    alarm_service.dart             # sirene loop (jalur volume ALARM) + getar
    tts_service.dart               # Text-to-Speech
    liveness_service.dart          # anti-spoofing aktif (kedip + toleh)
    eye_embedding_service.dart     # ML Kit + embedding
    matcher.dart                   # Cosine Similarity + ambang
  screens/ lock_screen  profile_screen  enroll_screen  calibration_screen
  widgets/result_overlay.dart
assets/audio/   match_found  access_denied  scan_beep  alarm  (.wav)
assets/models/  (taruh eye_embedder.tflite di sini)
tool/patch_android.py              # izin kamera, query TTS, minSdk 23
.github/workflows/build_apk.yml    # build APK otomatis di GitHub
```

## Menjalankan lewat GitHub (browser laptop)

Editor web GitHub hanya untuk mengedit; kamera & ML tidak jalan di laptop.

1. Buat repo, upload seluruh isi folder ini (termasuk `.github/`).
2. **Actions → Build APK → Run workflow**.
3. Unduh artifact `mastersafety-apk`, install di HP Android.
4. **Daftarkan pengguna** → **Kalibrasi ambang** → **Pindai Mata**.

iOS: tambahkan `NSCameraUsageDescription` di `ios/Runner/Info.plist`.

## Model embedding terlatih (wajib untuk hasil nyata)

Tanpa `assets/models/eye_embedder.tflite`, aplikasi berjalan dalam **MODE DEMO**
(lencana kuning di layar kunci) memakai deskriptor LBP buatan tangan — hanya
untuk mencoba alur. Model terlatih tidak disertakan; Anda harus menyediakannya.

Spesifikasi: input float32 `[1, H, W, 3]` (dinormalisasi −1..1), output float32
`[1, N]`. Aplikasi memotong mata kiri & kanan, mengubah ukuran sesuai input
model, lalu menggabungkan kedua embedding.

**Kalibrasi ambang** (layar "Kalibrasi ambang"): pilih pengguna, kumpulkan
≥5 skor *pemilik* dan ≥5 skor *penyusup* (orang lain / foto), lalu terapkan
ambang yang disarankan (titik tengah antara skor pemilik terendah dan penyusup
tertinggi). Jika kedua distribusi tumpang tindih, layar akan memperingatkan
bahwa embedding tidak cukup membedakan orang. Ambang disimpan di perangkat.

## Anti-spoofing: apa yang dicakup

Dicakup: foto cetak / foto di layar yang diam (tidak bisa berkedip & menoleh
sesuai perintah acak), pergantian orang di tengah proses (trackingId).

**Tidak dicakup:** video replay, deepfake real-time, topeng 3D. Untuk keamanan
tinggi gunakan sensor khusus (IR / depth) atau SDK liveness tersertifikasi.

## Alarm

- Dipicu setelah 3 Access Denied berturut-turut (konstanta `_alarmAfterFails`
  di `lock_screen.dart`; durasi `_alarmSeconds`).
- Memakai jalur volume **alarm** Android; jika HP dalam mode senyap total,
  bunyi bisa teredam sesuai pengaturan sistem.
- Alarm hanya berbunyi selama aplikasi berjalan; ini bukan alarm tingkat OS.

## Catatan lain

- Layar Daftar & Kalibrasi belum dilindungi; di produksi batasi untuk
  administrator dan enkripsi database (mis. `sqflite_sqlcipher`).
- Foto mentah dihapus setelah diproses; hanya vektor embedding yang disimpan.
- TTS Bahasa Indonesia butuh suara `id-ID` terpasang di HP.
- Kode belum dikompilasi/diuji di perangkat. Jika build gagal, kirim lognya.

## Mengganti ikon aplikasi

- **Ikon peluncur (home screen HP):** edit bagian KONFIGURASI di
  `tool/generate_icon.py` (warna, ukuran perisai, garis pemindai), lalu commit.
  GitHub Actions membuat ulang `assets/icon/*.png` dan memasangnya lewat
  `flutter_launcher_icons` sebelum build. Mau pakai gambar sendiri? Ganti
  `assets/icon/icon.png` (1024x1024) dan `assets/icon/icon_foreground.png`
  (transparan, isi di tengah ~60%) lalu hapus langkah "Buat ikon aplikasi"
  di `.github/workflows/build_apk.yml`.
- **Logo di dalam aplikasi:** `lib/widgets/ms_logo.dart` (digambar dengan kode;
  ubah warna lewat parameter atau bentuk di `_LogoPainter`).
- **Nama aplikasi di HP:** diatur lewat langkah `sed` di workflow
  (`android:label="MasterSafety"`).

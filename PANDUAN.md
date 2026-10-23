# Panduan CapsiScan (Flutter + Codemagic)

## 1. Siapkan model dari Colab
```python
from ultralytics import YOLO
m = YOLO("Training_Cabai/Model_YOLO11n/weights/best.pt")   # ganti dengan model terbaikmu
m.export(format="litert", imgsz=640)   # jika galat, coba format="tflite"
```
Cari file .tflite hasil ekspor (mis. best_float32.tflite / best_float16.tflite), ganti nama menjadi **model.tflite**,
lalu taruh di folder `assets/models/`. Batas unggah web GitHub 25 MB per file; jika lebih, ekspor dengan `half=True`.

## 2. Unggah ke GitHub (repo Tugas)
1. Ekstrak zip ini di komputer.
2. Buka github.com/metrashandy/Tugas > Add file > Upload files.
3. Seret ISI folder hasil ekstrak (lib, assets, pubspec.yaml, codemagic.yaml, dan lainnya), bukan file zip-nya.
4. Commit changes.

## 3. Build di Codemagic
1. Di halaman aplikasi, klik **Check for configuration files** (kanan atas).
2. Klik **Start new build**, pilih workflow `capsiscan-android`.
3. Setelah selesai, unduh APK dari bagian **Artifacts**.
4. Pindahkan ke HP, izinkan instal dari sumber tidak dikenal, lalu pasang.

## 4. Jika build gagal
Salin 30-50 baris terakhir log yang berwarna merah dan kirim ke saya.

## Catatan
- Prapemrosesan (bilateral filter + CLAHE) belum diterapkan; ada fungsi `preprocess` di `lib/detector.dart` sebagai tempatnya.
- Ambang confidence dan mode voting ada di `lib/detector.dart` dan `lib/voting.dart`.
- Ambil foto dengan rasio 1:1 di kamera HP agar mirip data latih.

---
name: checkpoint
description: UniPet'te bir task veya parça bittiğinde kullan — test, commit, push, ROADMAP güncelleme ve Talha'ya rapor.
---

# Task bitişi
1. `godot-dev` skill'indeki test komutlarını çalıştır. Kırmızıysa commit etme, düzelt.
2. `docs/ROADMAP.md`'de task'ı `[x]` yap.
3. Commit mesajı: `<parça>.<task>: <kısa açıklama>` (ör. `1.2: sanal joystick`). Türkçe.
   **Co-Authored-By / "Generated with" satırı EKLEME** (Talha'nın isteği; `.claude/settings.json`'da da kapalı).
4. `git pull --rebase` → `git push`.
5. Talha'ya 2-4 satır: ne yapıldı, nasıl denenir, varsa risk/soru.

# Parça bitişi (ek olarak)
1. Parçanın tüm task'ları `[x]` mi kontrol et.
2. Talha'ya test listesi ver: telefonda/editörde neyi deneyecek, beklenen sonuç ne.
   APK gerekiyorsa GitHub Actions artifact linkini ver (Talha'nın internetini düşün).
3. **Dur.** Talha "onay" demeden sonraki parçaya geçme.
4. Onay gelince `docs/ROADMAP.md`'de parça başlığına ✅ ekle, git tag: `parca-<n>`.

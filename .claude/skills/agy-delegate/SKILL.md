---
name: agy-delegate
description: UniPet'te bir işi Antigravity CLI'ye (agy) devretmek gerektiğinde kullan — Godot editör işi, Android build, ekran görüntüsü, paralel kod işi.
---

# Antigravity'ye iş verme

Talha'nın prompt yazmasını bekleme; işi sen verirsin.

## Ne zaman agy?
- Talha'nın Windows'unda olması gereken işler: Godot editörüyle import/ekran görüntüsü, lokal Docker (Nakama), telefona kurulum.
- Birbirinden bağımsız, iyi tanımlı kod işleri (paralel ilerlemek için).
- **agy'ye verme:** mimari kararlar, servis arayüzleri, güvenlik/auth kodu — bunları sen yaz.

## Nasıl?
1. `agy-tasks/inbox/NNN-kisa-ad.md` dosyası yaz (şablon aşağıda).
2. Çalıştır:
   - **Talha'nın Windows'unda Claude Code ile çalışıyorsan** (PowerShell):
     ```powershell
     powershell -ExecutionPolicy Bypass -File tools/agy-runner/agy-runner.ps1 -Task agy-tasks/inbox/NNN-kisa-ad.md
     ```
   - **Bulut oturumundaysan:** görevi commit+push et; Talha'nın makinesinde `agy-runner.ps1 -Watch` çalışıyorsa kendisi alır.
3. Runner agy'yi ayrı bir konsol penceresinde çalıştırır (agy `-p` modunun Windows'taki pipe/TTY hatasından kaçınmak için),
   bitince değişiklikleri ve raporu commit'leyip push'lar.
4. `agy-tasks/done/NNN-kisa-ad.report.md` raporunu ve diff'i **oku, review et**. Hatalıysa düzelt ya da yeni görev ver.
   agy çıktısını doğrulamadan "tamam" deme.

## Görev şablonu
```markdown
# NNN — <başlık>
## Amaç
<tek paragraf>
## Dokunabileceğin dosyalar
- `game/src/player/x.gd`   (her satırda TAM yol, backtick içinde; "`a.gd`, `b.tscn`" gibi kısaltma YOK — runner sadece bunları commit'ler)
## Yapılacaklar
1. ...
## Kabul kriterleri
- [ ] `godot --headless --path game -s res://tests/run_tests.gd` exit 0
- [ ] ...
## Kurallar
- CLAUDE.md ve docs/DECISIONS.md'ye uy.
- git commit/push YAPMA (runner yapar).
- Testleri hileyle geçirme (başka testin kodunu bellekte değiştirmek, kontrolü atlamak vb.). İzin dışı bir dosyanın değişmesi
  gerekiyorsa DUR ve rapora yaz.
- Bitince raporu agy-tasks/done/NNN-kisa-ad.report.md'ye yaz: ne yaptın, hangi dosyalar, test sonucu, belirsiz kalanlar.
```

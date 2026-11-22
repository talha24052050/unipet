# agy görev kutusu

- `inbox/` — Claude'un Antigravity'ye verdiği görevler (`NNN-kisa-ad.md`)
- `done/` — işlenmiş görevler (`NNN-kisa-ad.md`) + raporları (`NNN-kisa-ad.report.md`)

Çalıştırma ve şablon: `.claude/skills/agy-delegate/SKILL.md`  
Runner: `tools/agy-runner/agy-runner.ps1`

## Runner kuralları ve çalışma şekli

Runner (`tools/agy-runner/agy-runner.ps1`), görevleri Antigravity CLI (`agy`) aracılığıyla çalıştırırken şu kurallarla hareket eder:

1. **Sadece izin verilen dosyalar commit'lenir:**  
   Runner, görev dosyasındaki `## Dokunabileceğin dosyalar` bölümünü ayrıştırır. O satırlardaki backtick (`` ` ``) içindeki **tüm dosya yollarını** (`Get-AllowedPaths`) toplar. Commit adımında sadece bu izinli dosyalar ve `agy-tasks/done/` altındaki görev çıktıları sahneye eklenip commit edilir. Claude'un veya geliştiricinin üzerinde çalıştığı diğer henüz commit'lenmemiş değişiklikler agy commit'ine karışmaz.
2. **Rapor her durumda zorunludur:**  
   Görev başarılı tamamlansa da, yarım kalsa da veya zaman aşımına (`TimeoutMin`) uğrasa da `agy-tasks/done/<görev-adı>.report.md` rapor dosyası **her durumda** yazılmalıdır. Eğer agy bir rapor üretmeden çıkarsa runner otomatik bir hata/uyarı raporu oluşturur. Agy görev bittiğinde ne yaptığını, hangi dosyaların değiştiğini, test sonuçlarını ve belirsizlikleri mutlaka bu rapora yazmalıdır.

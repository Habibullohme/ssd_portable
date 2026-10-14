# Portable Ubuntu SSD — loyiha jurnali

Maqsad: 256 GB tashqi SSD'ga to'liq o'rnatilgan, o'z EFI bootloader'iga ega,
turli x86-64 UEFI kompyuterlarda yuklanadigan Ubuntu.
Asosiy laptop: HP ProBook x360 435 G8 (Windows 11 21H2 saqlanadi).

## Holat (faqat dalil bilan belgilanadi)

| # | Bosqich | Holat |
|---|---------|-------|
| 1 | Read-only diagnostika (`phase1/diagnostics.ps1`) | Kutilmoqda — natijalar yo'q |
| 2 | Backup rejasi va tekshiruvi | Boshlanmagan |
| 3 | Windows yangilash rejasi (BitLocker key backup) | Boshlanmagan |
| 4 | Installer usulini tanlash (A/B/C) | Boshlanmagan |
| 5 | Partition rejasi | Boshlanmagan |
| 6 | Ubuntu o'rnatish + mustaqil EFI (`EFI/BOOT/BOOTX64.EFI`) | Boshlanmagan |
| 7 | Portability testlari (A–E) | Boshlanmagan |
| 8 | Development muhiti | Boshlanmagan |

## Xavfsizlik qoidalari

- Disk faqat Model + Serial + BusType + hajm bo'yicha aniqlanadi, raqami/tartibi bo'yicha emas.
- Destruktiv buyruqlar (`clean`, `format`, `mkfs`, `wipefs`, `parted`, `sgdisk`, `dd`) faqat
  aniq target va egasining tasdig'idan keyin.
- Recovery key, parol, token'lar bu repoga yoki hisobotlarga yozilmaydi.

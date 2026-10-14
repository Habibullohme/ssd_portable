# Phase 2 rejasi — VirtualBox orqali (fleshkasiz) o'rnatish

## G'oya
Ubuntu installer ISO VirtualBox ichida (EFI rejimida) yuklanadi. Tashqi SSD
VM'ga **raw disk** sifatida beriladi. VM ichidagi installer **faqat shu
diskni** ko'radi — ichki Windows diski VM'ga umuman berilmaydi.
O'rnatilgan Ubuntu keyin haqiqiy kompyuterda to'g'ridan-to'g'ri boot qiladi
(Ubuntu initramfs generic, barcha keng tarqalgan driverlar bilan).

## Nega bu ishlaydi / qayerda xavf bor
| Jihat | Izoh |
|-------|------|
| Eng xavfli nuqta | `\\.\PhysicalDriveN` raqamini xato tanlash. Noto'g'ri raqam = ichki Windows diskiga yozish. Faqat FriendlyName + Serial + BusType=USB + Size bo'yicha tasdiqlanadi. |
| Windows bilan to'qnashuv | Windows SSD'dagi volume'ni mount qilib tursa, VM bilan bir vaqtda yozish buzilishga olib keladi. Shuning uchun backupdan keyin disk Windows'da **Offline** qilinadi (qaytariladigan amal). |
| Admin huquqi | Raw disk uchun VirtualBox **Run as administrator** bilan ochilishi kerak. |
| Hyper-V / VBS | Yoqilgan bo'lsa VirtualBox sekinroq ishlaydi, lekin o'rnatish uchun yetarli. |
| Bootloader | VM'ning NVRAM'iga yozilgan boot entry haqiqiy kompyuterga o'tmaydi — shuning uchun `EFI/BOOT/BOOTX64.EFI` fallback **majburiy** va o'rnatishdan keyin tekshiriladi/yaratiladi. |
| Guest Additions | O'rnatilmaydi (tizim real hardware uchun). |

## Qadamlar (har biri alohida tasdiq bilan)
1. **Backup**: Ventoy ISO'larini ichki diskka (yoki boshqa joyga) nusxalash, SHA256 bilan tekshirish.
2. **Tayyorgarlik**: VirtualBox (rasmiy virtualbox.org) va Ubuntu LTS desktop ISO (rasmiy ubuntu.com, SHA256 tekshiruvi) ichki diskka yuklab olinadi.
3. **Diskni aniqlash** (read-only):
   ```powershell
   Get-Disk | Select Number, FriendlyName, SerialNumber, BusType, @{n='GB';e={[math]::Round($_.Size/1GB,1)}}, IsBoot, IsSystem
   ```
   Target: `BusType = USB`, ~238 GB, `IsBoot = False`, `IsSystem = False`.
4. **Diskni Windows'da offline qilish** (DESTRUKTIV EMAS, qaytariladi; tasdiq kerak):
   `Set-Disk -Number <N> -IsOffline $true`
5. **Raw VMDK yaratish** (tasdiq kerak; Administrator PowerShell):
   ```powershell
   & "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" createmedium disk `
     --filename "$env:USERPROFILE\VirtualBox VMs\ssd-raw.vmdk" `
     --format VMDK --variant RawDisk --property RawDrive=\\.\PhysicalDrive<N>
   ```
   (VirtualBox 6.x da: `VBoxManage internalcommands createrawvmdk -filename ... -rawdisk \\.\PhysicalDrive<N>`)
6. **VM**: Linux/Ubuntu 64-bit, **Enable EFI** yoqilgan, RAM 4 GB+, CPU 2-4,
   disk = `ssd-raw.vmdk`, optical = Ubuntu ISO. VirtualBox admin sifatida ochiladi.
7. **Installer ichida**: maqsad disk ~238 GB "VBOX HARDDISK" ekanini tekshirish
   (boshqa disk ko'rinmasligi kerak). Partition rejasi Phase 2 tahlilidan keyin
   tasdiqlanadi (ESP FAT32 ~512 MB-1 GB + ext4 root; LUKS ixtiyoriy).
8. **O'rnatishdan keyin (VM ichida)**: `EFI/BOOT/BOOTX64.EFI` borligini tekshirish;
   yo'q bo'lsa `sudo grub-install --target=x86_64-efi --efi-directory=/boot/efi --removable`
   yoki `grub-efi-amd64/force_extra_removable` orqali. Kerak bo'lsa ESP'ga shim fallback nusxasi.
9. VM'ni o'chirish, diskni Windows'da qayta **Online** qilmaslik (Windows Linux
   partitionlarini o'qiy olmaydi; "Initialize disk" taklif qilsa — RAD ETISH).
10. Haqiqiy boot: HP'da Esc → F9 → SSD.

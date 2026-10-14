<#
  Phase 1 — Read-only diagnostika (Portable Ubuntu SSD loyihasi)

  BU SKRIPT HECH NARSANI O'ZGARTIRMAYDI:
    - disk/partition/format/boot sozlamalariga tegmaydi;
    - faqat Get-* cmdlet'lar, manage-bde -status, bcdedit /enum ishlatadi;
    - BitLocker recovery key'ni CHIQARMAYDI (faqat protector turi).

  Ishga tushirish (Administrator PowerShell'da):
    powershell -NoProfile -ExecutionPolicy Bypass -File .\diagnostics.ps1
  (-ExecutionPolicy Bypass faqat shu bitta jarayon uchun amal qiladi,
   tizim siyosatini doimiy o'zgartirmaydi.)

  Natija: Desktop'da Phase1-Diagnostics-<sana>.txt fayli.
  Ulashishdan oldin seriya raqamlarini xohlasangiz qisman yashiring.
#>

$ErrorActionPreference = 'Continue'
$stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
$report = Join-Path ([Environment]::GetFolderPath('Desktop')) "Phase1-Diagnostics-$stamp.txt"

function Section([string]$title) {
    "`n==================== $title ====================" | Tee-Object -FilePath $report -Append
}
function Out-Report {
    param([Parameter(ValueFromPipeline)]$InputObject)
    begin   { $items = @() }
    process { $items += $InputObject }
    end     { $items | Format-List | Out-String -Width 250 | Tee-Object -FilePath $report -Append }
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
"Phase 1 diagnostika — $(Get-Date)" | Out-File -FilePath $report -Encoding utf8
"Administrator: $isAdmin" | Tee-Object -FilePath $report -Append
if (-not $isAdmin) {
    Write-Warning "Administrator emas: Secure Boot, TPM va BitLocker natijalari to'liq bo'lmaydi."
}

# 1. Windows versiyasi
Section '1. WINDOWS VERSION'
$cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
[pscustomobject]@{
    ProductName    = $cv.ProductName      # Win11 da ham ba'zan "Windows 10" ko'rsatadi — build raqamiga qarang
    EditionID      = $cv.EditionID
    DisplayVersion = $cv.DisplayVersion
    Build          = "$($cv.CurrentBuild).$($cv.UBR)"
    OSCaption      = (Get-CimInstance Win32_OperatingSystem).Caption
    Architecture   = (Get-CimInstance Win32_OperatingSystem).OSArchitecture
} | Out-Report

# 2. Kompyuter, BIOS/UEFI firmware, CPU, RAM
Section '2. HARDWARE / FIRMWARE'
$cs   = Get-CimInstance Win32_ComputerSystem
$bios = Get-CimInstance Win32_BIOS
$cpu  = Get-CimInstance Win32_Processor
[pscustomobject]@{
    Manufacturer    = $cs.Manufacturer
    Model           = $cs.Model
    SystemSKU       = $cs.SystemSKUNumber
    RAM_GB          = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
    CPU             = $cpu.Name
    CPU_Cores       = $cpu.NumberOfCores
    CPU_Threads     = $cpu.NumberOfLogicalProcessors
    BIOS_Version    = $bios.SMBIOSBIOSVersion
    BIOS_Date       = $bios.ReleaseDate
} | Out-Report

# 3. Firmware turi, Secure Boot, TPM
Section '3. UEFI / SECURE BOOT / TPM'
$fw = 'Unknown'
try { $fw = (Get-ComputerInfo -Property BiosFirmwareType).BiosFirmwareType } catch {}
"BIOS firmware type : $fw   (kutilgan: Uefi)" | Tee-Object -FilePath $report -Append
try {
    $sb = Confirm-SecureBootUEFI -ErrorAction Stop
    "Secure Boot enabled: $sb" | Tee-Object -FilePath $report -Append
} catch {
    "Secure Boot        : aniqlab bo'lmadi ($($_.Exception.Message))" | Tee-Object -FilePath $report -Append
}
try {
    Get-Tpm -ErrorAction Stop |
        Select-Object TpmPresent, TpmReady, TpmEnabled, TpmActivated, ManufacturerIdTxt, ManufacturerVersion |
        Out-Report
    (Get-CimInstance -Namespace root\cimv2\Security\MicrosoftTpm -ClassName Win32_Tpm -ErrorAction Stop).SpecVersion |
        ForEach-Object { "TPM SpecVersion    : $_" } | Tee-Object -FilePath $report -Append
} catch {
    "TPM                : aniqlab bo'lmadi ($($_.Exception.Message))" | Tee-Object -FilePath $report -Append
}

# 4. Fizik disklar (tartib raqamiga emas, Model/Serial/BusType ga qarab aniqlaymiz)
Section '4. DISKS'
Get-Disk | Sort-Object Number |
    Select-Object Number, FriendlyName, SerialNumber, BusType, PartitionStyle,
        @{n='Size_GB';e={[math]::Round($_.Size / 1GB, 2)}},
        IsBoot, IsSystem, IsOffline, IsReadOnly, OperationalStatus, HealthStatus, UniqueId, Guid |
    Out-Report

Section '4b. PHYSICAL DISKS'
Get-PhysicalDisk |
    Select-Object DeviceId, FriendlyName, MediaType, BusType, SpindleSpeed,
        @{n='Size_GB';e={[math]::Round($_.Size / 1GB, 2)}}, FirmwareVersion, HealthStatus |
    Out-Report

# 5. Partitionlar
Section '5. PARTITIONS'
Get-Partition | Sort-Object DiskNumber, PartitionNumber |
    Select-Object DiskNumber, PartitionNumber, DriveLetter, Type, GptType, MbrType,
        @{n='Size_GB';e={[math]::Round($_.Size / 1GB, 2)}},
        IsBoot, IsSystem, IsActive, IsHidden |
    Format-Table -AutoSize | Out-String -Width 250 | Tee-Object -FilePath $report -Append

# 6. Volume'lar (fayl tizimi, label, bo'sh joy)
Section '6. VOLUMES'
Get-Volume |
    Select-Object DriveLetter, FileSystemLabel, FileSystem, DriveType,
        @{n='Size_GB';e={[math]::Round($_.Size / 1GB, 2)}},
        @{n='Free_GB';e={[math]::Round($_.SizeRemaining / 1GB, 2)}}, HealthStatus |
    Format-Table -AutoSize | Out-String -Width 250 | Tee-Object -FilePath $report -Append

# 7. BitLocker / Device Encryption (recovery key CHIQARILMAYDI)
Section '7. BITLOCKER'
try {
    Get-BitLockerVolume -ErrorAction Stop |
        Select-Object MountPoint, VolumeType, VolumeStatus, ProtectionStatus, EncryptionPercentage,
            EncryptionMethod, LockStatus,
            @{n='KeyProtectorTypes';e={($_.KeyProtector | ForEach-Object { $_.KeyProtectorType }) -join ', '}} |
        Out-Report
} catch {
    "Get-BitLockerVolume ishlamadi: $($_.Exception.Message)" | Tee-Object -FilePath $report -Append
}
"--- manage-bde -status (faqat holat, kalitsiz) ---" | Tee-Object -FilePath $report -Append
manage-bde -status 2>&1 | Out-String | Tee-Object -FilePath $report -Append

# 8. UEFI NVRAM boot yozuvlari (faqat o'qish)
Section '8. UEFI FIRMWARE BOOT ENTRIES (bcdedit /enum firmware)'
bcdedit /enum firmware 2>&1 | Out-String | Tee-Object -FilePath $report -Append

# 9. Ventoy SSD tarkibi (label bo'yicha topiladi; disk raqami taxmin qilinmaydi)
Section '9. VENTOY / EXTERNAL DATA INVENTORY'
$ventoy = Get-Volume | Where-Object { $_.FileSystemLabel -match 'Ventoy' -and $_.DriveLetter }
if (-not $ventoy) {
    "Ventoy label'li volume topilmadi. Tashqi SSD ulanganmi? Label boshqacha bo'lishi mumkin — 6-bo'limga qarang." |
        Tee-Object -FilePath $report -Append
}
foreach ($v in $ventoy) {
    $root  = "$($v.DriveLetter):\"
    $part  = Get-Partition -DriveLetter $v.DriveLetter
    "Ventoy volume: $root  (DiskNumber=$($part.DiskNumber), FS=$($v.FileSystem))" | Tee-Object -FilePath $report -Append
    $files = Get-ChildItem -LiteralPath $root -Recurse -File -Force -ErrorAction SilentlyContinue
    $files | Sort-Object Length -Descending |
        Select-Object @{n='Size_GB';e={[math]::Round($_.Length / 1GB, 3)}}, LastWriteTime, FullName |
        Format-Table -AutoSize | Out-String -Width 300 | Tee-Object -FilePath $report -Append
    $sum = ($files | Measure-Object Length -Sum).Sum
    "Fayllar soni: $($files.Count)   Jami hajm: $([math]::Round($sum / 1GB, 2)) GB" | Tee-Object -FilePath $report -Append
    "Shundan .iso: $([math]::Round((($files | Where-Object Extension -eq '.iso' | Measure-Object Length -Sum).Sum) / 1GB, 2)) GB" |
        Tee-Object -FilePath $report -Append
}

# 10. Backup uchun joy (ichki C: va boshqa yozish mumkin bo'lgan volume'lar)
Section '10. BACKUP SPACE CANDIDATES'
Get-Volume | Where-Object { $_.DriveLetter -and $_.DriveType -in 'Fixed','Removable' } |
    Select-Object DriveLetter, FileSystemLabel,
        @{n='DiskNumber';e={(Get-Partition -DriveLetter $_.DriveLetter -ErrorAction SilentlyContinue).DiskNumber}},
        @{n='Free_GB';e={[math]::Round($_.SizeRemaining / 1GB, 2)}} |
    Format-Table -AutoSize | Out-String | Tee-Object -FilePath $report -Append

# 11. USB kontrollerlar (tezlikni keyin Linux'da lsusb -t bilan aniqroq tekshiramiz)
Section '11. USB CONTROLLERS'
Get-CimInstance Win32_USBController | Select-Object Name, Manufacturer |
    Format-Table -AutoSize | Out-String -Width 200 | Tee-Object -FilePath $report -Append

"`nTayyor. Hisobot: $report" | Tee-Object -FilePath $report -Append

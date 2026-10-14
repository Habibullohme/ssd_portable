# Project: Portable Ubuntu SSD

You are running in Claude Code ON THE OWNER'S PHYSICAL LAPTOP (Windows).
Communicate with the owner in **Uzbek** (Latin script). Keep technical terms,
commands, file paths and software names in English.

## Goal
Turn the owner's 256 GB external USB SSD into a fully installed (not Live ISO)
Ubuntu LTS system that boots via the standard UEFI boot menu on the HP laptop
and on other x86-64 UEFI computers, with its own ESP and the UEFI fallback
loader `EFI/BOOT/BOOTX64.EFI` (signed shim, Secure Boot compatible).
The HP's internal Windows 11 must stay intact. Windows will also be upgraded
(separate task, via official Microsoft methods).

## Hardware (verified facts only)
- HP ProBook x360 435 G8, Windows 11 21H2 (build 22000.2538 - seen in screenshot).
- CPU: AMD64 Family 25 Model 80 (Zen 3, Ryzen 5000U series), 16 logical processors.
- External SSD: 256 GB, USB, currently Ventoy + 3-4 ISOs (Ubuntu, Kali, Windows, ?).
- No spare USB flash drive.
- NOT yet verified: disk numbers, models, GPT/MBR, Secure Boot, TPM, BitLocker,
  free space, RAM size. Never assume them - read them from diagnostics.

## Chosen install method: VirtualBox raw-disk passthrough
See `phase2/virtualbox-plan.md`. Summary: Ubuntu ISO boots inside an EFI
VirtualBox VM; the external SSD is attached to the VM as a raw disk (VMDK
pointing at `\\.\PhysicalDriveN`); the installer only sees that disk.

## HARD SAFETY RULES
1. Identify disks ONLY by FriendlyName + SerialNumber + BusType (USB) + Size.
   Never by number/position alone. Re-check immediately before any step that
   uses a disk number (numbers can change after replug/reboot).
2. The internal disk (BusType NVMe, IsBoot/IsSystem = True) must NEVER be the
   target of any write, raw VMDK, diskpart, format, Set-Disk, etc.
3. Destructive or state-changing commands (`diskpart`, `clean`, `format`,
   `Clear-Disk`, `Set-Disk`, `Initialize-Disk`, `bcdedit /set`, `mkfs`,
   `wipefs`, `dd`, `VBoxManage createmedium ... RawDisk`) require: exact target
   shown to the owner (model, serial, size, bus) + explicit "ha, tasdiqlayman".
   Propose them one at a time; never chain them.
4. Do not erase the external SSD until the owner confirms the ISO/data backup
   exists on a different disk and has been verified (size and/or SHA256).
5. Never print BitLocker recovery keys (`manage-bde -protectors -get`),
   passwords or tokens. Ask the owner to store the key themselves.
6. Do not reboot, change UEFI/BIOS settings, or disable Secure Boot/BitLocker
   on your own. Give the owner the steps.
7. Never claim a step succeeded without showing the evidence (command output).
8. Work one phase at a time: goal -> risks -> command -> expected result ->
   actual result -> analysis -> ask before continuing.
9. Keep `README.md` status table up to date; commit only non-secret files.
   Do not commit diagnostic outputs that contain serial numbers or keys.

## Phases
1. Read-only diagnostics: `phase1/diagnostics.ps1` (run in elevated PowerShell).
2. Backup ISOs/data off the external SSD; verify.
3. BitLocker recovery key check; Windows upgrade plan (official methods).
4. VirtualBox install of Ubuntu onto the external SSD (`phase2/virtualbox-plan.md`).
5. Verify ESP + `EFI/BOOT/BOOTX64.EFI`; boot on real hardware (HP: Esc -> F9).
6. Portability tests A-E; dev environment (only tools the owner needs).

# windows-bootstrap.ps1 — one-time setup inside the Windows test VM.
# Run in an ELEVATED PowerShell. Installs the CLANG64 toolchain, enables
# ssh-based driving from the host, and mirrors the GitHub-runner security
# policy that surfaces the exact-owner validation class.

$ErrorActionPreference = "Stop"

Write-Host "=== 1/4: msys2 + CLANG64 toolchain ==="
winget install -e --id MSYS2.MSYS2 --accept-source-agreements --accept-package-agreements
& C:\msys64\usr\bin\bash.exe -lc "pacman -S --noconfirm --needed mingw-w64-clang-x86_64-clang mingw-w64-clang-x86_64-compiler-rt mingw-w64-clang-x86_64-zlib mingw-w64-clang-x86_64-ccache make git"

Write-Host "=== 2/4: OpenSSH server (host drives the VM over ssh) ==="
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
Set-Service -Name sshd -StartupType Automatic
Start-Service sshd
New-NetFirewallRule -Name cbm-sshd -DisplayName "OpenSSH (cbm test VM)" `
    -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 `
    -ErrorAction SilentlyContinue | Out-Null

Write-Host "=== 3/4: mirror GitHub-runner security policy ==="
# 'System objects: Default owner for objects created by members of the
# Administrators group' = Administrators (0). This is the policy that makes
# freshly created objects owned by BUILTIN\Administrators instead of the
# user SID — the class the daemon's exact-owner gates must survive.
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" `
    -Name NoDefaultAdminOwner -Value 0 -Type DWord

Write-Host "=== 4/4: workspace ==="
New-Item -ItemType Directory -Path C:\cbm -Force | Out-Null
Write-Host "Done. Reboot once, then from the host: ipconfig -> put"
Write-Host "CBM_WIN_VM_SSH=<user>@<ip> into test-infrastructure/vm/config.env"

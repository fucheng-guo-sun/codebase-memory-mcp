# VM test legs (opt-in)

Two failure classes cannot be reproduced by the container legs and need real
virtual machines. Both stacks are free; the legs activate automatically in
`run.sh` when the tooling and the named VM are detected, and print setup
guidance otherwise.

## Windows VM (`run.sh windows-vm`) — real ACL/token/owner semantics

Wine only compile-checks Windows: kernel-real security semantics (object
ownership, DACLs, token identity — e.g. the Administrators-default-owner
policy on CI runners) need real Windows.

One-time setup (~15 min interactive):

1. `brew install --cask utm crystalfetch` (both free/open source).
2. Open **CrystalFetch** → download the latest **Windows 11 ARM64** ISO
   (fetched directly from Microsoft). Windows runs unactivated for testing
   (cosmetic watermark); add a license if you want it clean.
3. Open **UTM** → New VM → Virtualize → Windows → select the ISO →
   ALL host cores / 16-24 GB. vCPUs are host-scheduled, not pinned: idle
   guest cores cost nothing and nothing is seized from parallel work — no
   artificial limits, speed first. RAM is the one bounded number (Windows
   commits it eagerly). Click through Windows setup (local account, e.g. `dev`).
4. Inside Windows, run `vm/windows-bootstrap.ps1` (elevated PowerShell):
   installs msys2 + CLANG64 toolchain + git, enables OpenSSH server, and
   mirrors the GitHub-runner security policy
   (`NoDefaultAdminOwner=0` → new objects owned by BUILTIN\Administrators —
   the policy that surfaces the exact-owner validation class).
5. Note the VM's IP (`ipconfig`) and write it to `vm/config.env`:
   `CBM_WIN_VM_SSH=dev@<ip>`.

The leg then drives the VM over ssh: sync the worktree, build with the
CLANG64 toolchain, run the requested suites — a debugger-capable local loop
for the class that previously needed blind CI round-trips.

## macOS runner VM (`run.sh mac-vm`) — the GitHub-runner macOS environment

A local Mac is not the GitHub macOS runner (different temp ancestry, ACLs,
policies): failures like the index-supervisor worker exits reproduce only
there. Cirrus Labs publishes runner-equivalent images.

One-time setup (automated, big download):

1. `brew trust cirruslabs/cli && brew install tart` (free OSS).
2. `tart clone ghcr.io/cirruslabs/macos-runner:sequoia cbm-mac-runner`
   (tens of GB, one time).

The leg boots the VM headless (`tart run --no-graphics cbm-mac-runner`),
syncs the worktree over ssh (default credentials admin/admin inside the
runner image), and executes `scripts/test.sh` — the same environment class
GitHub schedules, locally and debuggable.

## Honesty rules

- These legs are OPT-IN: absent tooling prints guidance and exits with a
  distinct status; it is never silently skipped when explicitly requested.
- VM results complement, never replace, the CI matrix on the final SHA.

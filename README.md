# NixOS starter

flake-parts · haumea · home-manager · disko · sops-nix · impermanence
LUKS → btrfs (`root` wiped every boot)

## Layout
```
flake.nix                 haumea auto-loads everything below
modules/nixos/*.nix       applied to EVERY host   (add a file = picked up)
modules/home/*.nix        applied to EVERY user
hosts/<name>/             default.nix + hardware-configuration.nix
users/<name>/default.nix  per-user home-manager config
secrets/common.yaml       sops file (you create it, see below)
```
Add a host: copy `hosts/crazy`. Add a user: copy `users/mohamed`, then set `my.users.<name> = { };`
on the hosts that need them. Per-user options: `admin`, `extraGroups`, `sshKeys`, `persistDirs`.

## Disk
GPT: 1 GB ESP + LUKS (rest) → btrfs subvolumes `root` (wiped each boot), `nix`, `persist`, `log` (/var/log).
Anything outside those and the paths in `modules/nixos/impermanence.nix` (plus
`my.users.<n>.persistDirs`) disappears on reboot. `sudo find / -xdev -newer /etc/machine-id`
helps spot what you'd want to persist.

## Install

Common to both paths. Boot the NixOS installer (get online first: `nmtui` or plain Ethernet), then:

0. Get this repo into the installer. It needs git:
   ```
   nix-shell -p git
   git clone <your-repo-url> nixos-config && cd nixos-config
   ```
   No remote yet? Download/copy the tarball onto the installer (USB, `scp`) and run
   `tar xzf nixos-config.tar.gz && cd nixos-config && git init && git add -A`.
   Everything below is run from inside this directory, and the flake only sees git-tracked files, so `git add -A` after every edit.
1. `lsblk`, then set `my.disk.device` in `hosts/<host>/default.nix`.
2. `nixos-generate-config --no-filesystems --show-hardware-config > hosts/<host>/hardware-configuration.nix`
3. Partition + mount (asks you to choose the LUKS passphrase):
   ```
   sudo nix --experimental-features 'nix-command flakes' run github:nix-community/disko/latest -- \
     --mode destroy,format,mount --flake .#<host>
   ```

Then pick **A** or **B**.

### A. First install, no secrets yet
`secrets/common.yaml` does not exist, so `my.secrets.enable` is off and every user gets the password `changeme`.

```
git add -A
sudo mkdir -p /mnt/persist/etc && sudo cp -r . /mnt/persist/etc/nixos
sudo nixos-install --no-root-passwd --flake .#<host>
reboot
```

After first boot (log in as `changeme`; `passwd` will NOT stick because `users.mutableUsers = false`, so do the next steps right away):

1. sshd created the host key on first boot. Get its age public key and **back up the private key** (see "Host key backup"):
   ```
   nix shell nixpkgs#ssh-to-age -c ssh-to-age -i /persist/etc/ssh/ssh_host_ed25519_key.pub
   ```
2. Get an editable copy of the repo. The installer put a copy at `/etc/nixos` (root-owned, kept across reboots by impermanence). Copy it to your home, which is also persisted:
   ```
   mkdir -p ~/Projects
   cp -r /etc/nixos ~/Projects/nixos-config
   cd ~/Projects/nixos-config
   ```
   (If you cloned from a remote, you can `git clone` it again instead.) From now on, edit and rebuild from `~/Projects/nixos-config`; `/etc/nixos` is only the install-time copy.
3. Create your personal age key (keep it safe, it is how you edit secrets):
   `nix shell nixpkgs#age -c age-keygen -o ~/.config/sops/age/keys.txt` (mkdir the dir first)
4. Put your public key and the host's age key in `.sops.yaml` (one entry per host, all hosts listed under `creation_rules`).
5. Create the secrets:
   ```
   cp secrets/common.yaml.example secrets/common.yaml
   mkpasswd -m yescrypt           # one hash per user, paste into the file; set the emails too
   sops -e -i secrets/common.yaml
   git add -A
   ```
6. `sudo nixos-rebuild switch --flake .#<host>`. Secrets are now on; log out/in with your real password.

### B. Install when secrets already exist
`secrets/common.yaml` is in the repo, encrypted to your admin key + the hosts' keys. The host's SSH key is the identity that decrypts it at boot, so it must be in place **before** `nixos-install`.

**B1. Reinstalling an existing host** (key already in `.sops.yaml`): restore the backed-up key.
```
sudo mkdir -p /mnt/persist/etc/ssh
sudo install -m 600 /path/to/backup/ssh_host_ed25519_key     /mnt/persist/etc/ssh/
sudo install -m 644 /path/to/backup/ssh_host_ed25519_key.pub /mnt/persist/etc/ssh/
```

**B2. Adding a new host**: make a key and give it access to the secrets.
```
sudo mkdir -p /mnt/persist/etc/ssh
sudo ssh-keygen -t ed25519 -N "" -f /mnt/persist/etc/ssh/ssh_host_ed25519_key
nix shell nixpkgs#ssh-to-age -c ssh-to-age -i /mnt/persist/etc/ssh/ssh_host_ed25519_key.pub
```
Add that age key to `.sops.yaml` (new `&host_<name>` anchor + in `creation_rules`), then, on a machine that has your admin age key (`~/.config/sops/age/keys.txt`):
```
sops updatekeys secrets/common.yaml
git add -A && git commit && git push
```
Back in the installer, `git pull` in your checkout to get the updated `.sops.yaml` and `secrets/common.yaml`. Back up the new private key (see below). Add the user/host dirs first if this host has new users (their `passwords/<name>` and `email/<name>` entries must exist in the secrets file).

**Then, both B1 and B2:**
```
git add -A
sudo mkdir -p /mnt/persist/etc && sudo cp -r . /mnt/persist/etc/nixos
sudo nixos-install --no-root-passwd --flake .#<host>
reboot
```
Log in with the password from the secrets file. Later: `sudo nixos-rebuild switch --flake ~/Projects/nixos-config#<host>`.

### Host key backup
`/persist/etc/ssh/ssh_host_ed25519_key` is the only thing that lets a reinstalled host decrypt its secrets (lose it and you must do B2 again). Store the private key somewhere safe and **never in this repo**: a password manager secure note, or an encrypted USB (`sudo cat /persist/etc/ssh/ssh_host_ed25519_key`). Keep your personal `~/.config/sops/age/keys.txt` backed up the same way.

## Notes
- `my.secrets.enable` turns on automatically once `secrets/common.yaml` exists.
- `allowDiscards = true` (TRIM through LUKS) reveals which blocks are used; drop it in `disk.nix` if that matters.
- The rollback unit assumes the LUKS mapping is named `cryptroot`.
- Set `time.timeZone` per host. Bump `stateVersion` only deliberately.
- Untested starter: run `nix flake check` and adjust to your nixpkgs/home-manager versions.

# openknowledge-bin

Packaging and update tooling for [`openknowledge-bin`](https://aur.archlinux.org/packages/openknowledge-bin) on the AUR. It repackages the official [OpenKnowledge](https://openknowledge.ai) `.deb` releases from [inkeep/open-knowledge](https://github.com/inkeep/open-knowledge) for Arch Linux (x86_64 and aarch64).

## Install

```bash
yay -S openknowledge-bin
```

or without an AUR helper:

```bash
git clone https://aur.archlinux.org/openknowledge-bin.git && cd openknowledge-bin && makepkg -si
```

This installs the app to `/opt/OpenKnowledge`, plus the `openknowledge`, `ok` and `open-knowledge` commands. The app's built-in updater is turned off; updates come through pacman.

## Layout

| Path | What it is |
| --- | --- |
| `openknowledge-bin/` | The `PKGBUILD` and `.SRCINFO` published to the AUR |
| `update-aur.sh` | Bumps the package to the latest upstream release, builds it, commits and pushes |
| `scripts/notify-update.sh` | Runs a check and sends a desktop notification if there is a new release |
| `scripts/install-timer.sh` | Installs or removes the daily systemd user timer |
| `systemd/` | Unit templates for the timer |
| `.github/workflows/check-upstream.yml` | Daily GitHub Action that opens an issue when a new release is out |
| `.aur/openknowledge-bin/` | Local clone of the AUR repo (git-ignored, created by `update-aur.sh`) |

## Publishing a new release

```bash
./update-aur.sh --install --push
```

The script:

1. Fetches the latest upstream release and stops if the package is already current.
2. Updates `pkgver`, resets `pkgrel` to 1 and fills in both checksums from GitHub.
3. Builds the package, which checks the x86_64 download against its checksum, and runs `namcap`.
4. Regenerates `.SRCINFO` and commits it to this repo and to the AUR clone.
5. Installs the new build (`--install`) and pushes to the AUR and GitHub (`--push`; without it, the script asks first).

Other options: `--check` only reports whether an update exists (exit code 10 if it does), `--force` rebuilds even when current, and `--no-build` skips the test build.

Read the build output before pushing. A version bump does not cover upstream changing its dependencies or file layout.

### Changing the PKGBUILD itself

For packaging fixes that are not a new upstream version, edit `openknowledge-bin/PKGBUILD`, bump `pkgrel`, then run:

```bash
cd openknowledge-bin && makepkg -f && makepkg --printsrcinfo > .SRCINFO
```

Commit here, copy `PKGBUILD` and `.SRCINFO` into `.aur/openknowledge-bin/`, and commit and push there.

The AUR only accepts pushes to `master`. The local AUR clone works on `main`, and its push refspec maps `main` to `master`, so a plain `git push` does the right thing.

## Update notifications

Both of these only notify you. Neither one builds or publishes anything.

### Desktop notification (systemd timer)

```bash
./scripts/install-timer.sh
```

This runs `update-aur.sh --check` once a day, at a random time within an hour of midnight. If the machine was off at that time, the check runs on the next boot. A new release shows up as a desktop notification, and a failed check shows up as a low-priority one.

```bash
systemctl --user list-timers openknowledge-aur-check.timer
```

```bash
journalctl --user -u openknowledge-aur-check.service
```

```bash
./scripts/install-timer.sh --uninstall
```

The units point at this checkout's path, so re-run `install-timer.sh` if you move the repo.

### GitHub issue (Action)

`.github/workflows/check-upstream.yml` runs daily on GitHub, so it works while your machine is off. When upstream has a release newer than the AUR, it opens an issue titled `openknowledge-bin: OpenKnowledge vX.Y.Z is available`, which GitHub sends you as a notification. Once the AUR has caught up, it closes the issue. You can also run it by hand from the Actions tab.

GitHub disables scheduled workflows in repositories with no activity for 60 days. Each release you publish pushes a commit, which keeps it running. If GitHub disables it anyway, re-enable it from the Actions tab.

#!/usr/bin/env bash
# Bump openknowledge-bin to the latest upstream release, test-build it,
# regenerate .SRCINFO, commit it here and in the AUR clone, and push.
#
# Usage: ./update-aur.sh [--check] [--push] [--install] [--no-build] [--force]
#   --check     only report whether a new version exists (exit 10 if so)
#   --push      push to the AUR (and GitHub, if origin is set) without asking
#   --install   install the freshly built package with pacman -U
#   --no-build  skip the test build (not recommended)
#   --force     rebuild/commit even if pkgver is already current

set -euo pipefail

REPO="inkeep/open-knowledge"
ROOT="$(cd "$(dirname "$0")" && pwd)"
PKGDIR="$ROOT/openknowledge-bin"
AURDIR="$ROOT/.aur/openknowledge-bin"
AUR_REMOTE="ssh://aur@aur.archlinux.org/openknowledge-bin.git"
AUR_FILES=(PKGBUILD .SRCINFO .gitignore)

check=0 push=0 install=0 build=1 force=0
for arg in "$@"; do
  case "$arg" in
    --check) check=1 ;;
    --push) push=1 ;;
    --install) install=1 ;;
    --no-build) build=0 ;;
    --force) force=1 ;;
    -h|--help) sed -n '2,11p' "$0"; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

cd "$PKGDIR"

release="$(curl -fsSL --retry 3 --retry-all-errors "https://api.github.com/repos/$REPO/releases/latest")"
tag="$(jq -r .tag_name <<<"$release")"
new="${tag#v}"
cur="$(sed -n 's/^pkgver=//p' PKGBUILD)"

digest() {
  jq -r --arg n "$1" '.assets[] | select(.name == $n) | .digest // empty' <<<"$release" | sed 's/^sha256://'
}
sum_x86_64="$(digest OpenKnowledge-amd64.deb)"
sum_aarch64="$(digest OpenKnowledge-arm64.deb)"

echo "current: $cur   latest: $new"

if [[ "$(vercmp "$new" "$cur")" -le 0 && $force -eq 0 ]]; then
  echo "Already up to date."
  exit 0
fi
if [[ $check -eq 1 ]]; then
  echo "Update available: $cur -> $new"
  exit 10
fi
if [[ -z "$sum_x86_64" || -z "$sum_aarch64" ]]; then
  echo "Release $tag is missing a .deb asset or its digest." >&2
  exit 1
fi

if [[ "$new" != "$cur" ]]; then
  sed -i \
    -e "s/^pkgver=.*/pkgver=$new/" \
    -e "s/^pkgrel=.*/pkgrel=1/" \
    -e "s/^sha256sums_x86_64=.*/sha256sums_x86_64=('$sum_x86_64')/" \
    -e "s/^sha256sums_aarch64=.*/sha256sums_aarch64=('$sum_aarch64')/" \
    PKGBUILD
fi

# Drop sources and packages from older versions.
find . -maxdepth 1 \( -name 'openknowledge-*.deb' -o -name '*.pkg.tar.zst' \) \
  ! -name "*-$new-*" -delete
rm -rf src pkg

if [[ $build -eq 1 ]]; then
  # Verifies the x86_64 checksum against the real download and builds the package.
  makepkg -f --noconfirm
  namcap PKGBUILD || true
fi

makepkg --printsrcinfo > .SRCINFO

# Commit the package files to this repo.
if git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  git -C "$ROOT" add -- "${AUR_FILES[@]/#/openknowledge-bin/}"
  if ! git -C "$ROOT" diff --cached --quiet -- openknowledge-bin; then
    git -C "$ROOT" commit -q -m "openknowledge-bin: update to $new" -- openknowledge-bin
  fi
fi

# Sync them into the AUR clone. Work on "main" locally; the AUR only
# accepts pushes to master.
if [[ ! -d "$AURDIR/.git" ]]; then
  git clone -q "$AUR_REMOTE" "$AURDIR"
  git -C "$AURDIR" branch -M main
  git -C "$AURDIR" config remote.origin.push refs/heads/main:refs/heads/master
  git -C "$AURDIR" config branch.main.remote origin
  git -C "$AURDIR" config branch.main.merge refs/heads/master
fi
cp -- "${AUR_FILES[@]}" "$AURDIR/"
git -C "$AURDIR" add -- "${AUR_FILES[@]}"
if git -C "$AURDIR" diff --cached --quiet; then
  echo "Nothing to commit for the AUR."
else
  git -C "$AURDIR" commit -q -m "Update to $new"
  git -C "$AURDIR" --no-pager show --stat HEAD
fi

if [[ $install -eq 1 ]]; then
  sudo pacman -U --needed ./openknowledge-bin-"$new"-*-"$(uname -m)".pkg.tar.zst
fi

if [[ $push -eq 0 ]]; then
  read -rp "Push to the AUR now? [y/N] " ans
  [[ "$ans" == [yY]* ]] || { echo "Not pushed. Run: git -C '$AURDIR' push"; exit 0; }
fi
git -C "$AURDIR" push
echo "Published openknowledge-bin $new: https://aur.archlinux.org/packages/openknowledge-bin"

if git -C "$ROOT" remote get-url origin >/dev/null 2>&1; then
  git -C "$ROOT" push
fi

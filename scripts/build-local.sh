#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KERNEL_BRANCH="${KERNEL_BRANCH:-oneplus/sm8550_b_16.0.0_oneplus_11}"
KERNEL_REPO="${KERNEL_REPO:-https://github.com/OnePlusOSS/android_kernel_oneplus_sm8550.git}"
MODULES_REPO="${MODULES_REPO:-https://github.com/OnePlusOSS/android_kernel_modules_and_devicetree_oneplus_sm8550.git}"
DEFCONFIG="${DEFCONFIG:-gki_defconfig}"
KCONFIG_FRAGMENT="${KCONFIG_FRAGMENT:-$ROOT/kernel-configs/local-runner.fragment}"
TARGET="${TARGET:-Image}"
JOBS="${JOBS:-$(nproc)}"
OUT_DIR="${OUT_DIR:-$ROOT/out}"
KERNEL_DIR="$ROOT/kernel/oneplus/sm8550"
MODULES_DIR="$ROOT/kernel/oneplus/sm8550-modules"

log() { printf '\n==> %s\n' "$*"; }

install_deps() {
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y \
      git curl unzip bc bison build-essential libncurses-dev flex libssl-dev \
      libelf-dev wget zip ccache clang lld llvm python3 python3-pip \
      python3-setuptools dwarves rsync cpio
  elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -Syu --noconfirm
    sudo pacman -S --needed --noconfirm \
      git curl unzip bc bison base-devel ncurses flex openssl elfutils \
      wget zip ccache clang lld llvm python python-pip python-setuptools \
      pahole rsync cpio
  else
    echo "Unsupported package manager. Install clang/lld, make, bc, bison, flex, OpenSSL/ELF headers, pahole, rsync, zip, and cpio." >&2
    return 1
  fi
}

clone_or_update() {
  local repo="$1" branch="$2" dir="$3"
  if [ ! -d "$dir/.git" ]; then
    rm -rf "$dir"
    git clone --depth 1 --branch "$branch" "$repo" "$dir"
  else
    git -C "$dir" fetch --depth 1 origin "$branch"
    git -C "$dir" checkout -B "${branch##*/}" FETCH_HEAD
    git -C "$dir" reset --hard FETCH_HEAD
    git -C "$dir" clean -ffd
  fi
}

rel_link() {
  local target="$1" link="$2"
  rm -rf "$link"
  mkdir -p "$(dirname "$link")"
  ln -s "$(realpath --relative-to="$(dirname "$link")" "$target")" "$link"
}

stub_kconfig() {
  local dir="$1"
  rm -rf "$dir"
  mkdir -p "$dir"
  printf 'menu "stub for unavailable downstream module"\nendmenu\n' > "$dir/Kconfig"
}

prepare_tree() {
  mkdir -p "$ROOT/kernel"
  rel_link "$MODULES_DIR/vendor" "$ROOT/kernel/vendor"
  rel_link "$MODULES_DIR/vendor" "$ROOT/kernel/oneplus/vendor"
  rel_link "$MODULES_DIR/kernel_platform" "$ROOT/kernel/oneplus/kernel_platform"

  rel_link "$MODULES_DIR/vendor/oplus/kernel/cpu" "$KERNEL_DIR/kernel/oplus_cpu"
  rel_link "$MODULES_DIR/vendor/oplus/kernel/mm" "$KERNEL_DIR/mm/oplus_mm"
  rel_link "$MODULES_DIR/vendor/oplus/kernel/touchpanel/oplus_touchscreen_v2" "$KERNEL_DIR/drivers/input/touchscreen/oplus_touchscreen_v2"
  rel_link "$MODULES_DIR/vendor/oplus/kernel/touchpanel/synaptics_hbp" "$KERNEL_DIR/drivers/input/touchscreen/synaptics_hbp"
  rel_link "$MODULES_DIR/vendor/oplus/kernel/touchpanel/kernelFwUpdate" "$KERNEL_DIR/drivers/base/kernelFwUpdate"
  rel_link "$MODULES_DIR/vendor/oplus/kernel/device_info/tri_state_key" "$KERNEL_DIR/drivers/misc/tri_state_key"
  rel_link "$MODULES_DIR/vendor/oplus/kernel/vibrator/aw8697_haptic" "$KERNEL_DIR/drivers/misc/aw8697_haptic"
  rel_link "$MODULES_DIR/vendor/oplus/kernel/vibrator/si_haptic" "$KERNEL_DIR/drivers/misc/si_haptic"

  # These Kconfig entries are present in the released common kernel but their
  # module sources are not present in the matching OnePlus module/devicetree drop.
  stub_kconfig "$KERNEL_DIR/drivers/oplus_inject"
  stub_kconfig "$KERNEL_DIR/drivers/nfc/oplus_nfc"
  stub_kconfig "$KERNEL_DIR/drivers/android/oplus_binder"
  stub_kconfig "$KERNEL_DIR/drivers/power/oplus"
  stub_kconfig "$KERNEL_DIR/kernel/locking/oplus_locking"
  stub_kconfig "$KERNEL_DIR/drivers/input/uff_fp_drivers"
}

build_kernel() {
  rm -rf "$OUT_DIR"
  make -C "$KERNEL_DIR" O="$OUT_DIR" ARCH=arm64 LLVM=1 LLVM_IAS=1 "$DEFCONFIG"
  if [ -f "$KCONFIG_FRAGMENT" ]; then
    "$KERNEL_DIR/scripts/kconfig/merge_config.sh" -m -O "$OUT_DIR" "$OUT_DIR/.config" "$KCONFIG_FRAGMENT"
    make -C "$KERNEL_DIR" O="$OUT_DIR" ARCH=arm64 LLVM=1 LLVM_IAS=1 olddefconfig
  fi
  make -C "$KERNEL_DIR" O="$OUT_DIR" ARCH=arm64 LLVM=1 LLVM_IAS=1 -j"$JOBS" "$TARGET"
}

package_anykernel() {
  local image="$OUT_DIR/arch/arm64/boot/Image"
  [ -f "$image" ] || return 0
  rm -rf "$ROOT/AnyKernel3"
  git clone --depth 1 https://github.com/osm0sis/AnyKernel3.git "$ROOT/AnyKernel3"
  cp "$ROOT/anykernel.sh" "$ROOT/AnyKernel3/anykernel.sh"
  cp "$image" "$ROOT/AnyKernel3/Image"
  (cd "$ROOT/AnyKernel3" && zip -r9 "$ROOT/OnePlus11-Kernel.zip" . -x './.git/*' -x './README.md')
}

main() {
  if [ "${SKIP_DEPS:-0}" != "1" ]; then
    log "Installing build dependencies"
    install_deps
  fi
  log "Cloning OnePlus kernel source ($KERNEL_BRANCH)"
  clone_or_update "$KERNEL_REPO" "$KERNEL_BRANCH" "$KERNEL_DIR"
  log "Cloning matching OnePlus module/devicetree source ($KERNEL_BRANCH)"
  clone_or_update "$MODULES_REPO" "$KERNEL_BRANCH" "$MODULES_DIR"
  log "Preparing linked downstream module layout"
  prepare_tree
  log "Building $TARGET with $DEFCONFIG"
  build_kernel
  log "Packaging AnyKernel3 zip"
  package_anykernel
  log "Done: $OUT_DIR/arch/arm64/boot/Image"
}

main "$@"

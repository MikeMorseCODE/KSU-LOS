# KSU-LOS

Local/self-hosted build harness for the OnePlus 11 (`salami`, SM8550) kernel.

The build uses the matching OnePlusOSS kernel and module/devicetree repositories:

- `OnePlusOSS/android_kernel_oneplus_sm8550`
- `OnePlusOSS/android_kernel_modules_and_devicetree_oneplus_sm8550`

By default it builds the Android 16 OnePlus 11 branch:

```bash
scripts/build-local.sh
```

Useful overrides:

```bash
KERNEL_BRANCH=oneplus/sm8550_v_15.0.0_oneplus11 scripts/build-local.sh
SKIP_DEPS=1 JOBS=8 TARGET=Image scripts/build-local.sh
```

The script installs host build dependencies on Ubuntu/Debian or Arch runners,
clones both source drops, links the downstream module/devicetree layout expected
by OnePlus Kconfig files, builds `gki_defconfig`, and packages `Image` into
`OnePlus11-Kernel.zip` with AnyKernel3.

Generated paths are ignored by git:

- `kernel/`
- `out/`
- `AnyKernel3/`
- `OnePlus11-Kernel.zip`

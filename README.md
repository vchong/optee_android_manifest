# Building and Running AOSP with OP-TEE in QEMU

This is a WiP PoC and not guaranteed to work as expected!

It does not have a GUI.

Running Java is not supported and unlikely to work.

FBE is not enabled.

AOSP build is on `master` so it'll be a matter of time before this bitrots!

You've been warned!

## 0. Setup env

**NOTE**
- You **MUST** use the `optee`, `aosp` and `trusty` dir names in 1-3 below!
- All 3 dirs must be under `GROOT`!
- `ROOT` is not used because it interferes with `build.git`'s `ROOT`!

```
export GROOT=$(pwd)
```

## 1. Build qemu_v8 build.git

```
mkdir -p ${GROOT}/optee
cd ${GROOT}/optee
repo init -u https://github.com/OP-TEE/manifest.git -m qemu_v8.xml
```

Below repos are replaced with those from https://github.com/vchong
using local manifest below.

```
# project build/	branch tt
# project optee_os/	branch kmgk_rebase_mbedtls_pie_20210421
# project qemu/		branch tt
```

`qemu.git` branch `tt` tries to cherry pick non-upstream patches from
https://android.googlesource.com/trusty/external/qemu `master` branch
but `7ed6ed9 Remove capstone, dtc and ui/keycodemapdb submodules`
can't be used since it's too old (v3) to build on `build.git`'s qemu v6
so without it, not sure if the other patches are even necessary?

Changes in `optee_os` are to include AOSP related patches.

Changes in `build.git` are to build `kmgk` TAs and install them to the
buildroot root FS. They're also to launch `qemu-system-aarch64` using
trusty's python script `qemu.py` in 3 below.

The local manifest also adds the `kmgk` repo to the source tree.

```
mkdir -p ${GROOT}/optee/.repo/local_manifests
cd ${GROOT}/optee/.repo/local_manifests
wget https://raw.githubusercontent.com/vchong/optee_android_manifest/qemu-optee-arm64/optee_local.xml

cd ${GROOT}/optee
repo sync
cd build
make toolchains

# SDP not supported in kernel 5.10 and above so set CFG_SECURE_DATA_PATH=n
# PKCS11 not built by default so set CFG_PKCS11_TA=y to build it
# set CFG_USER_TA_TARGETS=ta_arm64 to build TAs as 64b
# make -j36 CFG_SECURE_DATA_PATH=n CFG_PKCS11_TA=y CFG_USER_TA_TARGETS=ta_arm64 CFG_TEE_TA_LOG_LEVEL=2
./build.sh
```

## 2. Build qemu trusty arm64 AOSP userspace

This is where you can customize your OP-TEE AOSP userspace.

```
mkdir -p ${GROOT}/aosp
cd ${GROOT}/aosp
repo init -u https://android.googlesource.com/platform/manifest -b master
```

Below repos are replaced with those from https://github.com/vchong
using local manifest below.

```
# project device/generic/trusty/                  branch tt
# project system/core/                            branch tt
```

Changes in `system/core` are to remove trusty kmgk modules so that the
OP-TEE ones become default.

Changes in `device/generic/trusty` are to integrate OP-TEE components
into the build and disable unrequired trusty services.

The local manifest also adds OP-TEE repos to the source tree.

`optee_test` is from https://github.com/vchong/optee_test branch `tt`
due to disablement of TA build and redefinition of `TA_DEV_KIT_DIR`.

`optee_client` is from https://github.com/vchong/optee_client branch
`plugin2` for plugin support.

```
mkdir -p ${GROOT}/optee/.repo/local_manifests
cd ${GROOT}/optee/.repo/local_manifests
wget https://raw.githubusercontent.com/vchong/optee_android_manifest/qemu-optee-arm64/aosp_local.xml

cd ${GROOT}/aosp
repo sync -j8
```

Copy TAs from `build.git` to AOSP userspace

```
mkdir -p ${GROOT}/aosp/out/target/product/trusty/vendor/lib

# If a previous copy exists, delete it first
rm -rf ${GROOT}/aosp/out/target/product/trusty/vendor/lib/optee_armtz

cp -a ${GROOT}/optee/out-br/target/lib/optee_armtz ${GROOT}/aosp/out/target/product/trusty/vendor/lib/
```

Build AOSP userspace

```
. ./build/envsetup.sh
lunch qemu_trusty_arm64-userdebug
make -j24
```

## 3. Build qemu trusty bootloader components

This builds TF-A, QEMU, Linux kernel and other customized components to run
trusty. This is where you can customize your bootloader. E.g. point
to the TF-A build in `build.git` - i.e. using optee rather than trusty,
build kernel with (op)tee configs, use qemu options customized for
optee, etc.

```
mkdir -p ${GROOT}/trusty
cd ${GROOT}/trusty
repo init -u https://android.googlesource.com/trusty/manifest -b master
```

Below repos are replaced with those from https://github.com/vchong
using local manifest below.

```
# project external/linux/                         branch tt
# project trusty/device/arm/generic-arm64/        branch tt
```

Changes in `external/linux` are to add OP-TEE CONFIGs.

Changes in `trusty/device/arm/generic-arm64` are to:
- fix a build error
- change `config.json` to point to build paths in `build.git` and
  `${GROOT}/aosp`
- print all options to `qemu-system-aarch64`
- change some of `qemu-system-aarch64` options to match `build.git` and
  for AOSP debugging

```
mkdir -p ${GROOT}/trusty/.repo/local_manifests
cd ${GROOT}/trusty/.repo/local_manifests
wget https://raw.githubusercontent.com/vchong/optee_android_manifest/qemu-optee-arm64/trusty_local.xml
cd ${GROOT}/trusty

repo sync -j32
./trusty/vendor/google/aosp/scripts/build.py qemu-generic-arm64
```

Copy `RPMB_DATA` and `firmware.android.dts` to `build.git`.

```
cp ${GROOT}/trusty/build-root/build-qemu-generic-arm64/atf/qemu/debug/RPMB_DATA ${GROOT}/optee/out/bin/
cp ${GROOT}/trusty/build-root/build-qemu-generic-arm64/atf/qemu/debug/firmware.android.dts ${GROOT}/optee/out/bin/
```

## 4. Test run

```
cd ${GROOT}/optee/build
make run-only
```

Run `xtest` from the console or `adb` shell.

**NOTE: NOT** all tests pass at the moment!

```
2333 subtests of which 1 failed
19 test cases of which 1 failed
91 test cases were skipped

# As of 20210525
```

To stop the run, issue below command from another terminal:

```
${GROOT}/trusty/build-root/build-qemu-generic-arm64/stop

```


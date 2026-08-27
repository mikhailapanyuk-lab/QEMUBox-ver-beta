# UTM-derived QEMU patches and notes

This document collects a small set of notes and example patches inspired by the UTM project that are useful when building QEMU for running macOS guests on Apple Silicon and x86_64 hosts. These are NOT complete production-ready patches — they are examples and guidance to help you reproduce the UTM approach.

Important: UTM and many macOS-focused changes are the result of community work and must be reviewed and tested on real hardware. Use these notes as a starting point.

1) Why patches are needed
- QEMU upstream builds with many features disabled for iOS cross-builds. UTM applies small configuration changes and local patches to enable required devices, firmware, and to tweak TCG behavior for better performance with macOS guests.
- macOS guests often need support for specific device models, UEFI firmware (OVMF), SMC-like behavior and Apple-friendly device trees or VirtIO tuning.

2) Typical small patches to add (examples)
- Enable UEFI/OVMF support in configure and small path fixes for iOS SDKs.
- Reduce hard-coded alignment assumptions that conflict with iOS platform headers.
- Build fixes for disabling SDL/GTK but keeping required device model code for macOS guests.

Example (pseudo-patch) to adjust configure flags or includes:

--- a/include/some_header.h
+++ b/include/some_header.h
@@ -10,7 +10,8 @@
-#include <linux/special.h>
+#if defined(__APPLE__)
+# include "compat/apple_special.h"
+#else
+# include <linux/special.h>
+#endif
@@

3) TCG tuning ideas
- Increase the number of TCG optimization levels when building (if QEMU supports build-time tuning).
- Ensure QEMU is built with `--enable-tcg` and without `--disable-tcg`.
- Optionally enable LTO or CPU-specific compiler flags for the host (e.g., -mcpu=apple-m1) when cross-compiling for similar targets.

4) Firmware / blobs needed for macOS guests
- macOS guests usually require an EFI firmware and in some setups UEFI variables. UTM provides scripts to produce a working OVMF-like firmware and platform files.
- You may need the following files in your QEMU runtime on-device (place under /usr/local/share/qemu or another path and point QEMU to them with -L or -pflash args):
  - OVMF_CODE.fd
  - OVMF_VARS.fd
  - (optional) Apple-specific firmware blobs if available from community forks

5) Device model recommendations
- For ARM macOS guests: target aarch64-softmmu and use virtual devices that match Apple Silicon guest expectations where possible.
- For Intel macOS guests: use x86_64-softmmu builds and provide appropriate CPU and SMBIOS/device tree options.

6) Where to get references
- UTM repo (look at their qemu-patches and build scripts): https://github.com/utmapp/UTM
- community forks (look at their qemu-patches dir for macOS/Apple Apple Silicon related patches)

7) Testing & iteration
- Build small changes, test on a dedicated machine, collect qemu log output (-d int) and iterate.
- Expect to add or tweak device arguments passed to qemu-system-*- based on kernel panics or firmware errors in the guest.

8) Licensing
- Any redistributed QEMU binaries must include GPLv2 notices and the corresponding source or provide a prominent offer for source code, per GPLv2.

---

This file is a starting point. If you want, I can add sample patch files (real diff files) copied from a UTM commit or provide a more detailed, step-by-step patch application workflow (apply-patches.sh) — tell me which UTM commit or fork you want used as the canonical reference and I will include explicit diffs.

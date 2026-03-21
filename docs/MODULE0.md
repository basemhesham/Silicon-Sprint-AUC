# Module 0: Installation and Setup

**Goal**: Set up the physical design and verification environment and verify toolchain functionality.

## Overview

This module covers the complete setup of your ASIC development environment, including all required tools and dependencies for hardening the AES core. By the end of this module, you will have a working environment capable of running the **LibreLane** infrastructure.

---
## 2. Nix-based Installation

LibreLane uses **Nix** as its primary build system. Nix is a powerful package manager for Linux and macOS that ensures your environment is exactly the same as the developers', allowing for fully cachable and reproducible ASIC builds.

> **Tip for Windows Users**: 
> You can use the Windows Subsystem for Linux (WSL2). Follow the specific WSL setup instructions in the link below.

### Installation Guides by OS
Follow the official guide for your specific operating system to install Nix and configure the LibreLane environment:

* **Windows 10+ (WSL2)**: [Installation Guide](https://librelane.readthedocs.io/en/stable/installation/nix_installation/installation_win.html)
* **macOS 11+**: [Installation Guide](https://librelane.readthedocs.io/en/stable/installation/nix_installation/installation_macos.html)
* **Ubuntu/Other Linux**: [Installation Guide](https://librelane.readthedocs.io/en/stable/installation/nix_installation/installation_linux.html)

### Why Nix?
Unlike traditional package managers, Nix ensures that every tool in the AES hardening flow (from Yosys to Magic) is pinned to a specific, verified version. This prevents the "it works on my machine" problem when sharing your design with the community or submitting to an MPW shuttle.

## 3. Invoking the Environment

Once Nix is installed, you must enter the **nix-shell**. This environment provides all the specialized ASIC tools bundled with LibreLane without requiring a global installation on your host system.

1. **Clone the LibreLane repository:**
   ```console
   $ git clone https://github.com/librelane/librelane/ ~/librelane
   ```
2. **Initialize the Nix-shell:**
Enter the following command to make the LibreLane packages available to your current session:
   ```console
   $ nix-shell --pure ~/librelane/shell.nix
   ```
On the first run, Nix will download approximately 3GiB of data. Once the process completes, your terminal prompt will change to indicate you are inside the environment:

   ```console
   [nix-shell:~/librelane]$
   ```
3. **Verify the Setup:**
Confirm that the environment is active and the tools are accessible by checking the version:
   ```console
   [nix-shell:~/librelane]$ librelane --version
   ```

4. **Smoke Test:**
Now that your environment is active, you are ready to run the Smoke Test to download the Sky130 PDK.
   ```console
   [nix-shell:~/librelane]$ librelane --log-level ERROR --condensed --show-progress-bar --smoke-test
   ```

### Verification of Nix Setup
Once installed, verify that the Nix shell can be initialized by running:
```console
$ nix-shell --run "librelane --version"
```

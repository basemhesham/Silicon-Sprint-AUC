# Module 0: Installation and Setup

**Goal**: Establish a reproducible physical design environment and verify the ASIC toolchain functionality.

---

## 1. Overview
This module guides you through the complete setup of your ASIC development environment. You will install the necessary dependencies for hardening the **AES core** and ensure that the **LibreLane** infrastructure is correctly configured on your system.

---

## 2. Nix-based Installation
LibreLane utilizes **Nix** as its primary build system. Nix is a cross-platform package manager that ensures your local environment perfectly matches the production environment, allowing for fully cacheable and reproducible ASIC builds.

> **Tip for Windows Users**: It is highly recommended to use **Windows Subsystem for Linux (WSL2)** with an Ubuntu 22.04 distribution for the best performance and compatibility.

### Installation Guides by OS
Select the guide corresponding to your operating system to install Nix and configure the LibreLane environment:

* **Windows 10+ (WSL2)**: [WSL2 Installation Guide](https://librelane.readthedocs.io/en/stable/installation/nix_installation/installation_win.html)
* **macOS 11+**: [macOS Installation Guide](https://librelane.readthedocs.io/en/stable/installation/nix_installation/installation_macos.html)
* **Ubuntu/Linux**: [Linux Installation Guide](https://librelane.readthedocs.io/en/stable/installation/nix_installation/installation_linux.html)

### Why use Nix?
Traditional package managers often suffer from "version drift." Nix ensures that every tool in the AES flow—from **Yosys** (Synthesis) to **Magic** (Layout)—is pinned to a specific, verified version. This eliminates "it works on my machine" bugs during the workshop.

---

## 3. Invoking the Environment
Once Nix is installed, you will enter a **Nix-shell**. This creates a virtual environment containing all specialized ASIC tools without cluttering your global system.

### Step 3.1: Clone the Repository
Clone the LibreLane infrastructure into your home directory:
```console
$ git clone https://github.com/librelane/librelane/ ~/librelane
```

### Step 3.2: Switch to LibreLane 3
To use the latest features and improvements in LibreLane 3, switch to the development branch:
```console
$cd ~/librelane$ git checkout dev
```

### Step 3.3: Initialize the Nix-shell
Enter the following command to load the LibreLane packages into your current terminal session:
```console
$ nix-shell --pure ~/librelane/shell.nix
```

```{tip}
On the first execution, Nix will download approximately 3GB of data. Please ensure you have a stable internet connection.
```

Once finished, your terminal prompt will change to indicate you are inside the managed environment:

```console
[nix-shell:~/librelane]$
```

## 4. Verification and Smoke Test
Now that the shell is active, you must verify the toolchain and download the Sky130 PDK.

### Step 4.1: Version Check
Confirm the environment is active by checking the LibreLane version:

   ```console
   [nix-shell:~/librelane]$ librelane --version
   ```

### Running the Smoke Test
Now that your environment is active, you are ready to run the Smoke Test to download the Sky130 PDK.
   ```console
   [nix-shell:~/librelane]$ librelane --log-level ERROR --condensed --show-progress-bar --smoke-test
   ```

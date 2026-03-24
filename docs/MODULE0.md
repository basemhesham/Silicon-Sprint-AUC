# Module 0: Installation & Environment Setup

```{admonition} Module Objective
:class: important

Establish a fully reproducible ASIC physical design environment and verify end-to-end
toolchain functionality before beginning the design flow.
```

---

## Table of Contents

1. [Overview](#overview)
2. [Installing Nix](#installing-nix)
   - [2.1 Installation Guides by OS](#installation-guides-by-os)
   - [2.2 Why Nix?](#why-nix)
3. [Invoking the Environment](#invoking-the-environment)
   - [3.1 Clone the Repository](#step-31-clone-the-librelane-repository)
   - [3.2 Switch to LibreLane 3](#step-32-switch-to-librelane-3)
   - [3.3 Initialize the Nix Shell](#step-33-initialize-the-nix-shell)
4. [Verification & Smoke Test](#verification-and-smoke-test)
   - [4.1 Version Check](#step-41-version-check)
   - [4.2 Running the Smoke Test](#step-42-running-the-smoke-test)
5. [Repository Preparation & SSH Configuration](#repository-preparation-and-ssh-configuration)
   - [5.1 Remote Repository Setup (SSH & Git)](#remote-repository-setup-ssh-and-git)
   - [5.2 Cloning the Project Repositories](#cloning-the-project-repositories)

---

## 1. Overview

This module walks you through the complete setup of your ASIC development environment.
You will install the necessary dependencies for hardening the **AES-128 core**, configure
the **LibreLane** toolchain, and verify the environment is fully operational before
proceeding to the design modules.

By the end of this module, you will have:

- A working Nix-managed ASIC toolchain (Yosys, OpenROAD, Magic, KLayout, Netgen).
- The SkyWater 130nm {term}`PDK` downloaded and verified.
- Both workshop repositories cloned and accessible on your machine.

---

## 2. Installing Nix

```{warning}
Do **not** install Nix using `apt`. The version distributed via `apt` is outdated and
will cause compatibility failures with the LibreLane environment.
Always use the official installer described below.
```

Nix requires `curl` to download the installer. Install it first:

```console
$ sudo apt-get install -y curl
```

Then install Nix using the official Determinate Systems installer:

```console
$ curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install \
    --prefer-upstream-nix \
    --no-confirm \
    --extra-conf "
        extra-substituters = https://nix-cache.fossi-foundation.org
        extra-trusted-public-keys = nix-cache.fossi-foundation.org:3+K59iFwXqKsL7BNu6Guy0v+uTlwsxYQxjspXzqLYQs=
    "
```

Enter your system password if prompted. The installation typically takes a few minutes.

```{admonition} Required Action After Installation
:class: important

**Close all open terminal windows and open a new one** before continuing.
Nix modifies your shell configuration, and the changes only take effect in a fresh session.
```

---

### 2.1 Installation Guides by OS

Select the guide corresponding to your operating system:

| Operating System | Guide |
| :--- | :--- |
| **Ubuntu / Linux** | [Installation on Ubuntu/Linux](https://librelane.readthedocs.io/en/stable/installation/nix_installation/installation_linux.html) |
| **Windows 10+ (WSL2)** | [Installation on Windows via WSL2](https://librelane.readthedocs.io/en/stable/installation/nix_installation/installation_win.html) |
| **macOS 11+** | [Installation on macOS](https://librelane.readthedocs.io/en/stable/installation/nix_installation/installation_macos.html) |

---

### 2.2 Why Nix?

Reproducibility is a foundational requirement in ASIC design flows. Nix creates an
**isolated and deterministic** development environment where every tool is pinned to a
fixed, verified version.

This ensures the entire flow — from RTL synthesis with **Yosys** through layout generation
with **Magic** — executes identically on every machine, eliminating the common failure mode
where a design passes on one workstation but breaks on another due to differing tool versions.

```{note}
The Nix shell does **not** modify your global system. All tools are contained within the
managed environment and disappear when you type `exit`. Your system remains clean.
```

---

## 3. Invoking the Environment

Once Nix is installed, you will work inside a **Nix shell** — an isolated virtual environment
containing all specialized ASIC tools without polluting your global system installation.

Before cloning the required repositories, ensure Git is installed on your system:

```console
$ sudo apt install git
```

---

### Step 3.1 — Clone the LibreLane Repository

Clone the LibreLane infrastructure into your home directory:

```console
$ git clone https://github.com/librelane/librelane/ ~/librelane
```

---

### Step 3.2 — Switch to LibreLane 3

Switch the repository to the development branch to access the latest features and improvements:

```console
$ git -C ~/librelane checkout dev
```

---

### Step 3.3 — Initialize the Nix Shell

Load all LibreLane packages into your current terminal session:

```console
$ nix-shell --pure ~/librelane/shell.nix
```

```{admonition} First-Run Download
:class: note

On the **first execution only**, Nix will download approximately **3 GB** of tool packages.
Ensure you have a stable internet connection before proceeding. Subsequent shell launches
will use the local cache and start in seconds.
```

Once the download completes, your terminal prompt will change to confirm you are inside the
managed environment:

```console
[nix-shell:~]$
```

All `librelane` commands in subsequent modules must be run from within this shell.

---

## 4. Verification and Smoke Test

With the Nix shell active, verify the toolchain installation and download the
SkyWater 130nm {term}`PDK`.

---

### Step 4.1 — Version Check

Confirm the environment is correctly loaded by querying the LibreLane version:

```console
[nix-shell:~]$ librelane --version
```

A version string should be printed to the terminal. If this command fails, do not proceed —
revisit [Section 3.3](#step-33-initialize-the-nix-shell).

---

### Step 4.2 — Running the Smoke Test

The smoke test performs a minimal end-to-end flow run and simultaneously downloads the
SkyWater 130nm {term}`PDK` to your local cache.

```console
[nix-shell:~]$ librelane --log-level ERROR --condensed --show-progress-bar --smoke-test
```

After completing the smoke test — or any work session with the ASIC tools — exit the Nix
environment and return to your standard terminal by running:

```console
[nix-shell:~]$ exit
```
This cleanly releases the managed environment. Your system is unchanged.


```{admonition} Expected Outcome
:class: note

A successful smoke test will print a short summary report with no errors.
The Sky130 {term}`PDK` is now cached locally and will be available for all subsequent runs
without re-downloading.
```

---

## 5. Repository Preparation and SSH Configuration

**Objective:** Establish a secure, authenticated connection to GitHub and clone the
hardware design repositories required for the workshop.

---

### 5.1 Remote Repository Setup (SSH and Git)

To manage design files and interact with GitHub without entering a password for every
operation, you must configure **SSH (Secure Shell)**. This establishes a persistent
encrypted link between your local machine and your GitHub account.

#### Step 1 — Generate an SSH Key

First, check whether an existing key is already present:

```console
$ ls ~/.ssh/id_ed25519.pub
```

If the file does not exist, generate a new key using the **Ed25519** algorithm — the current
recommended standard for security and performance. Replace the placeholder with your
GitHub-registered email address:

```console
$ ssh-keygen -t ed25519 -C "your_email@example.com"
```

When prompted:

| Prompt | Recommended Action |
| :--- | :--- |
| **Save location** | Press **Enter** to accept the default (`~/.ssh/id_ed25519`). |
| **Passphrase** | Enter a passphrase for added security, or press **Enter** twice to leave it empty. |

---

#### Step 2 — Add the Public Key to GitHub

GitHub requires your **public key** to authenticate your machine.

**1. Display the public key:**

```console
$ cat ~/.ssh/id_ed25519.pub
```

**2. Copy the full output** — the entire string beginning with `ssh-ed25519`.

**3. Register the key on GitHub:**

- Navigate to **Settings → SSH and GPG keys → New SSH key**.
- Set a recognizable title (e.g., `Lab_Workstation`).
- Paste the copied key into the **Key** field and click **Add SSH key**.

**4. Verify the connection:**

```console
$ ssh -T git@github.com
```

A successful response will read: `Hi <username>! You've successfully authenticated...`

```{tip}
If the verification step times out or returns a `Permission denied` error, revisit
**Step 1** to confirm the key was generated at the correct path, and **Step 2** to
confirm the correct public key was pasted into GitHub.
```

---

### 5.2 Cloning the Project Repositories

With SSH authentication configured, clone both repositories required for this workshop.

#### Step 1 — Clone the Silicon-Sprint-AUC Project

This repository contains the Caravel user project template pre-configured for the LibreLane flow:

```console
$ git clone git@github.com:basemhesham/Silicon-Sprint-AUC.git ~/Silicon-Sprint-AUC
```

#### Step 2 — Clone the AES Source Code

This repository contains the AES-128 RTL implementation that will be hardened during the workshop:

```console
$ git clone git@github.com:secworks/aes.git ~/secworks_aes
```

#### Step 3 — Verify the Directory Structure

Confirm that both repositories were cloned successfully:

```console
$ ls -d ~/Silicon-Sprint-AUC ~/secworks_aes
```

Expected output:

```text
/home/<user>/Silicon-Sprint-AUC
/home/<user>/secworks_aes
```

```{admonition} Module Complete
:class: tip

Both repositories are now present on your machine. Your environment is fully configured
and ready for **Module 1: RTL Integration & ASIC Flow**.

Proceed to the next module only after confirming:

- ✅ `librelane --version` returns a version string inside the Nix shell.
- ✅ The smoke test completed without errors.
- ✅ Both repository directories exist in your home folder.
```

---

```{glossary}
PDK
  Process Design Kit. A collection of files provided by a semiconductor foundry (in this case, SkyWater) that describes the electrical and physical properties of the manufacturing process, including standard cell libraries, design rules, and SPICE models.
```

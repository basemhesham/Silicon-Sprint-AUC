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
---

## 6. Repository Preparation & SSH Configuration

**Goal**: Establish a secure connection to GitHub and clone the required hardware design repositories.

### 6.1 Remote Repository Setup (SSH & Git)
To manage your design files and collaborate on GitHub securely without entering your password for every action, you must configure SSH (Secure Shell). This establishes an encrypted link between your local machine and your GitHub account.

### Step 1: Generating an SSH Key
First, check if you already have a key. If not, generate a new one using the Ed25519 algorithm, which is the current standard for security and performance.

**Generate the key**: Open your terminal and run the following command (replace the email with your GitHub email):

```console
ssh-keygen -t ed25519 -C "your_email@example.com"
```

* **Save the file**: Press **Enter** to accept the default file location (`~/.ssh/id_ed25519`).
* **Passphrase**: You can enter a passphrase for extra security or press **Enter** twice to leave it empty for convenience.

### Step 2: Adding the Key to GitHub
GitHub needs your **Public Key** to recognize your machine.

**1. Copy the public key**: Run this command to display the key text:
```console
cat ~/.ssh/id_ed25519.pub
```
**2. Copy the output**: Highlight and copy the entire text starting with `ssh-ed25519`.

**3. In GitHub**: 
* Go to **Settings** > **SSH and GPG keys** > **New SSH key**.
* **Paste the key**: Give it a title (e.g., "Lab_Workstation") and paste the copied text into the "Key" field.

---

### 6.2 Cloning the Project Repositories
Once the SSH key is linked, you can "clone" (download) the project files. We will pull both the main Caravel project structure and the specific AES source code used in the workshop.

### Step 1: Clone the Silicon-Sprint-AUC Project
This command clones the Caravel user project template specifically configured for LibreLane into your home directory:
```console
git clone git@github.com:basemhesham/Silicon-Sprint-AUC.git ~/Silicon-Sprint-AUC
```

### Step 2: Clone the AES Source Code
Next, we clone the specific AES hardware implementation (RTL) that we will be hardening during this workshop:
```console
git clone git@github.com:secworks/aes.git ~/secworks_aes
```

### Step 3: Verification
Verify that both directories now exist in your home folder:
```console
ls -d ~/Silicon-Sprint-AUC ~/secworks_aes
```

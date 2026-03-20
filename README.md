<div align="center">

<img src="https://github.com/user-attachments/assets/84028fb9-2e26-4733-af28-c6e825395912" alt="Silicon Sprint Logo" height="140" />

[![Typing SVG](https://readme-typing-svg.demolab.com?font=Inter&size=44&duration=3000&pause=600&color=4C6EF5&center=true&vCenter=true&width=1100&lines=Silicon+Sprint+AUC;LibreLane+Flow+Mastery;AES+Accelerator+Integration)](https://git.io/typing-svg)

# AES-Caravel: Open-Source ASIC Implementation Guide
<p align="center">
    <a href="https://opensource.org/licenses/Apache-2.0"><img src="https://img.shields.io/badge/License-Apache%202.0-blue.svg" alt="License: Apache 2.0"/></a>
    <a href="https://www.python.org"><img src="https://img.shields.io/badge/Python-3.8-3776AB.svg?style=flat&logo=python&logoColor=white" alt="Python 3.8.1 or higher" /></a>
    <a href="https://github.com/psf/black"><img src="https://img.shields.io/badge/code%20style-black-000000.svg" alt="Code Style: black"/></a>
    <a href="https://nixos.org/"><img src="https://img.shields.io/static/v1?logo=nixos&logoColor=white&label=&message=Built%20with%20Nix&color=41439a" alt="Built with Nix"/></a>
</p>
<p align="center">
    <a href="https://github.com/chipfoundry/librelane"><img src="https://img.shields.io/badge/Flow-LibreLane%20v3-FF69B4" alt="LibreLane v3"></a>
    <a href="https://librelane.readthedocs.io/"><img src="https://readthedocs.org/projects/librelane/badge/?version=latest" alt="Documentation Build Status Badge"/></a>
    <a href="https://fossi-chat.org"><img src="https://img.shields.io/badge/Community-FOSSi%20Chat-1bb378?logo=element" alt="Invite to FOSSi Chat"/></a>
</p>
</div>

A comprehensive, modular learning path for mastering the open-source ASIC ecosystem and the **LibreLane** physical implementation flow with progressive complexity levels. This project provides a complete educational resource with hands-on modules, technical clinics, and surgical flow control documentation covering all aspects of hardening an **AES Accelerator** and integrating it into the **Caravel SoC** harness for the free OpenMPW shuttle.

---

## Table of Contents
* [Project Description](#project-description)
* [Caravel SoC](#caravel-soc)
* [LibreLane Framework](#librelane-framework)
* [AES Accelerator Architecture](#aes-accelerator-architecture)
* [Wishbone Communication](#wishbone-communication)
* [Design Implementation](#design-implementation)
* [Design Simulation](#design-simulation)

---

## Project Description
In this project, we build upon the [Caravel User Project](https://github.com/chipfoundry/caravel_user_project) to demonstrate how the SoC template can be used to harden a high-performance **AES (Advanced Encryption Standard) Accelerator** and integrate it within the [Caravel](https://github.com/efabless/caravel) chip. 

While the foundational flow is based on the traditional Caravel tutorial, this implementation leverages the **LibreLane** framework to achieve "surgical" control over the physical design process. This allows us to address complex integration challenges ensuring the cryptographic core is fully compliant with the Sky130 design rules for the OpenMPW shuttle.

---

## Caravel SoC
[Caravel](https://github.com/efabless/caravel) is a template SoC designed for Efabless Open MPW and chipIgnite shuttles, based on the **Sky130 (130nm)** process node from SkyWater Technologies. It acts as a standardized "harness" that surrounds the user’s custom logic, providing all necessary infrastructure for a functional chip.

<p align="center">
  <img width="500" alt="Caravel SoC Structure" src="https://user-images.githubusercontent.com/56173018/182022965-96c2875e-91cf-40fc-8c59-cde0ddeaa16e.png">
</p>

As illustrated above, Caravel consists of a fixed harness frame and two pluggable wrappers:
1. **Management Area:** Contains the RISC-V CPU and system peripherals.
2. **User Project Area:** The sandbox where our **AES Accelerator** is implemented.

Our AES core resides within the `user_project_wrapper` and utilizes the following utilities provided by the management SoC:
* **38 GPIO Ports:** For external data signaling.
* **128 Logic Analyzer Probes:** For real-time hardware debugging.
* **Wishbone Bus Connection:** For high-speed register access between the RISC-V CPU and the AES core.

We utilize the **Wishbone Bus** as the primary communication channel to configure the AES keys and transfer data for encryption/decryption. For more details on the signaling, see the [Wishbone Communication](#wishbone-communication) section.

---

## LibreLane Framework
[LibreLane](https://github.com/chipfoundry/librelane) is an ASIC infrastructure library and orchestration framework currently developed and maintained under the stewardship of the [FOSSi Foundation](https://fossi-foundation.org). 

It is built upon several industry-standard open-source components, including **OpenROAD**, **Yosys**, **Magic**, **Netgen**, **CVC**, and **KLayout**, along with a suite of custom Python scripts designed for advanced design exploration and optimization.

### The "Classic" Reference Flow
LibreLane provides a robust reference flow known as **"Classic"**, which performs all mandated ASIC implementation steps—from RTL synthesis all the way down to a sign-off ready GDSII. Unlike legacy flows, LibreLane leverages **Nix** to provide a 100% reproducible environment, ensuring that every tool in the chain is version-locked and dependency-free.

### Hardening Strategies
When implementing the **AES Accelerator** within the Caravel User Project, LibreLane offers three distinct strategies to optimize physical design and sign-off:

* **Macro-First Hardening:** The user macro is hardened as a standalone block first and then incorporated into the `user_project_wrapper` without additional top-level standard cells. This approach is ideal for smaller designs as it significantly reduces Placement and Routing (PnR) and sign-off time.
* **Full-Wrapper Flattening:** This method merges the user macro(s) directly with the `user_project_wrapper`, covering the entire available area. While this demands more time and iterations for PnR and sign-off, it ultimately enhances overall performance, making it suitable for high-density designs requiring the full wrapper footprint.
* **Top-Level Integration:** The user macro is placed within the wrapper alongside standard cells at the top level. This method is typically chosen when top-level buffering or glue logic is necessary to interface the macro with the Caravel SoC.

---

### Resources & Community
* **Documentation:** Get started with the official [LibreLane Docs](https://librelane.readthedocs.io/en/latest/getting_started/).
* **Community:** Join the technical discussion on the [FOSSi Chat Matrix Server](https://fossi-chat.org).

---



---

## Documentation & Resources
For detailed hardware specifications and register maps, refer to the following official documents:

* **[Caravel Datasheet](https://github.com/chipfoundry/caravel/blob/main/docs/caravel_datasheet_2.pdf)**: Detailed electrical and physical specifications of the Caravel harness.
* **[Caravel Technical Reference Manual (TRM)](https://github.com/chipfoundry/caravel/blob/main/docs/caravel_datasheet_2_register_TRM_r2.pdf)**: Complete register maps and programming guides for the management SoC.
* **[ChipFoundry Marketplace](https://platform.chipfoundry.io/marketplace)**: Access additional IP blocks, EDA tools, and shuttle services.

---

## Prerequisites
Ensure your environment meets the following requirements:

1. **Docker** [Linux](https://docs.docker.com/desktop/setup/install/linux/ubuntu/) | [Windows](https://docs.docker.com/desktop/setup/install/windows-install/) | [Mac](https://docs.docker.com/desktop/setup/install/mac-install/)
2. **Python 3.8+** with `pip`.
3. **Git**: For repository management.

---

## Project Structure
A successful Caravel project requires a specific directory layout for the automated tools to function:

| Directory | Description |
| :--- | :--- |
| `openlane/` | Configuration files for hardening macros and the wrapper. |
| `verilog/rtl/` | Source Verilog code for the project. |
| `verilog/gl/` | Gate-level netlists (generated after hardening). |
| `verilog/dv/` | Design Verification (cocotb and Verilog testbenches). |
| `gds/` | Final GDSII binary files for fabrication. |
| `lef/` | Library Exchange Format files for the macros. |

---

## Starting Your Project

### 1. Repository Setup
Create a new repository based on the `caravel_user_project` template and clone it to your local machine:

```bash
git clone <your-github-repo-URL>
pip install chipfoundry-cli
cd <project_name>
```

### 2. Project Initialization

> [!IMPORTANT]
> Run this first! Initialize your project configuration:

```bash
cf init
```

This creates `.cf/project.json` with project metadata. **This must be run before any other commands** (`cf setup`, `cf gpio-config`, `cf harden`, `cf precheck`, `cf verify`).

### 3. Environment Setup
Install the ChipFoundry CLI tool and set up the local environment (PDKs, OpenLane, and Caravel lite):

```bash
cf setup
```

The `cf setup` command installs:

- Caravel Lite: The Caravel SoC template.
- Management Core: RISC-V management area required for simulation.
- OpenLane: The RTL-to-GDS hardening flow.
- PDK: Skywater 130nm process design kit.
- Timing Scripts: For Static Timing Analysis (STA).

---

## Development Flow

### Hardening the Design
Hardening is the process of synthesizing your RTL and performing Place & Route (P&R) to create a GDSII layout.

#### Macro Hardening
Create a subdirectory for each custom macro under `openlane/` containing your `config.tcl`.

```bash
cf harden --list         # List detected configurations
cf harden <macro_name>   # Harden a specific macro
```

#### Integration
Instantiate your module(s) in `verilog/rtl/user_project_wrapper.v`.

Update `openlane/user_project_wrapper/config.json` environment variables (`VERILOG_FILES_BLACKBOX`, `EXTRA_LEFS`, `EXTRA_GDS_FILES`) to point to your new macros.

#### Wrapper Hardening
Finalize the top-level user project:

```bash
cf harden user_project_wrapper
```

### Verification

#### 1. Simulation
We use cocotb for functional verification. Ensure your file lists are updated in `verilog/includes/`.

**Configure GPIO settings first (required before verification):**

```bash
cf gpio-config
```

This interactive command will:
- Configure all GPIO pins interactively
- Automatically update `verilog/rtl/user_defines.v`
- Automatically run `gen_gpio_defaults.py` to generate GPIO defaults for simulation

GPIO configuration is required before running any verification tests.

Run RTL Simulation:

```bash
cf verify <test_name>
```

Run Gate-Level (GL) Simulation:

```bash
cf verify <test_name> --sim gl
```

Run all tests:

```bash
cf verify --all
```

#### 2. Static Timing Analysis (STA)
Verify that your design meets timing constraints using OpenSTA:

```bash
make extract-parasitics
make create-spef-mapping
make caravel-sta
```

> [!NOTE]
> Run `make setup-timing-scripts` if you need to update the STA environment.

---

## GPIO Configuration
Configure the power-on default configuration for each GPIO using the interactive CLI tool.

**Use the GPIO configuration command:**
```bash
cf gpio-config
```

This command will:
- Present an interactive form for configuring GPIO pins 5-37 (GPIO 0-4 are fixed system pins)
- Show available GPIO modes with descriptions
- Allow selection by number, partial key, or full mode name
- Save configuration to `.cf/project.json` (as hex values)
- Automatically update `verilog/rtl/user_defines.v` with the new configuration
- Automatically run `gen_gpio_defaults.py` to generate GPIO defaults for simulation (if Caravel is installed)

**GPIO Pin Information:**
- GPIO[0] to GPIO[4]: Preset system pins (do not change).
- GPIO[5] to GPIO[37]: User-configurable pins.

**Available GPIO Modes:**
- Management modes: `mgmt_input_nopull`, `mgmt_input_pulldown`, `mgmt_input_pullup`, `mgmt_output`, `mgmt_bidirectional`, `mgmt_analog`
- User modes: `user_input_nopull`, `user_input_pulldown`, `user_input_pullup`, `user_output`, `user_bidirectional`, `user_output_monitored`, `user_analog`

> [!NOTE]
> GPIO configuration is required before running `cf precheck` or `cf verify`. Invalid modes cannot be saved - all GPIOs must have valid configurations.

---

## Local Precheck
Before submitting your design for fabrication, run the local precheck to ensure it complies with all shuttle requirements:

> [!IMPORTANT]
> GPIO configuration is required before running precheck. Make sure you've run `cf gpio-config` first.

```bash
cf precheck
```

You can also run specific checks or disable LVS:

```bash
cf precheck --disable-lvs                    # Skip LVS check
cf precheck --checks license --checks makefile  # Run specific checks only
```
---

## Checklist for Shuttle Submission
- [ ] Top-level macro is named user_project_wrapper.
- [ ] Full Chip Simulation passes for both RTL and GL.
- [ ] Hardened Macros are LVS and DRC clean.
- [ ] user_project_wrapper matches the required pin order/template.
- [ ] Design passes the local cf precheck.
- [ ] Documentation (this README) is updated with project-specific details.

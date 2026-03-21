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

## Caravel
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

## LibreLane
[LibreLane](https://github.com/chipfoundry/librelane) is an automated RTL-to-GDSII flow based on components including OpenROAD, Yosys, Magic, Netgen, CVC, and KLayout. It performs full ASIC implementation from RTL down to GDSII.

Originally started as version 2.0 of OpenLane, LibreLane is a piece of software for ASIC implementation, initially developed by Efabless Corporation, but it is currently maintained under the stewardship of the [FOSSi Foundation](https://fossi-foundation.org). Rather than being a single fixed flow, LibreLane acts as an infrastructure that allows for multiple implementation strategies, including a "Classic" flow for compatibility with earlier OpenLane versions.

<p align="center">
  <img width="686" alt="LibreLane Architecture" src="https://user-images.githubusercontent.com/56173018/182023837-3ec8d154-8c5a-4d47-a80f-3fa4a9959bbd.png">
</p>

When hardening your design using LibreLane, there are three primary options:

* **Macro-First Hardening:** Harden the user macro(s) initially and incorporate them into the wrapper without top-level standard cells. This method significantly reduces PnR and sign-off time.
* **Full-Wrapper Flattening:** Merge the user macro(s) with the `user_project_wrapper` to cover the entire area. This enhances performance but requires more PnR iterations.
* **Top-Level Integration:** Place the user macro(s) within the wrapper alongside top-level standard cells. This is typically chosen to introduce necessary top-level buffering or glue logic.

---

## Wishbone Integration & Wrapper Hierarchy
The integration of the AES core into the Caravel SoC is achieved through a multi-layered hardware hierarchy. This ensures the generic memory interface of the AES core is compatible with the **Wishbone** bus architecture used by the Caravel management SoC.

### 1. AES Wishbone Wrapper (`aes_wb_wrapper.v`)
We begin by using the open-source RTL for AES by [Joachim Strömbergson](https://github.com/secworks/aes/tree/master). Since the original RTL provides a generic memory interface, we implemented a custom Wishbone wrapper. This module acts as the bridge, adding the necessary `ack`, `write_enable`, and `read_enable` logic to handle the Wishbone bus protocol signaling.

<p align="center">
  <img width="680" alt="AES Wishbone Wrapper Diagram" src="https://github.com/user-attachments/assets/4a1da4fa-96f4-4003-94f9-c9451bbbe2cc" />
" />
</p>

### 2. User Project Wrapper (`user_project_wrapper.v`)
The `aes_wb_wrapper` is the top-level module of our project logic, which is then instantiated inside the `user_project_wrapper.v`. Every project submitted to the Caravel harness must use this fixed set of ports to ensure physical and electrical compatibility with the SoC.

In summary, this top-level module is responsible for:
* **Bus Communication:** Interfacing with the Caravel management core via the Wishbone bus.
* **Signal Mapping:** Connecting the AES engine to the Logic Analyzer probes and GPIO pads.
* **System Integration:** Managing the `IRQ` and power connections within the user sandbox.

<p align="center">
  <img width="413" height="372" alt="Screenshot 2026-03-20 195621" src="https://github.com/user-attachments/assets/7357f0e5-acc0-46ff-a6e9-5bc1fcc84813" />
</p>

---

## Wishbone Communication
We implement the AES core in the user project area as a peripheral accessible by firmware on the management SoC. The management core communicates with the AES engine using the **Wishbone bus**. While other communication methods like Logic Analyzer (LA) signals exist, this project focuses exclusively on Wishbone-based memory-mapped I/O.

As shown in the [caravel architecture](#caravel), the management core acts as the **Master**, initiating all read and write operations, while our AES peripheral acts as the **Slave**. The Wishbone bus is a shared interface, meaning the management core communicates with the AES core by addressing the user project memory space.

### Register Interface
The AES engine is controlled through a series of memory-mapped registers that allow the RISC-V core to configure the encryption parameters, load keys, and transfer data blocks. The Wishbone wrapper handles the bus protocol by decoding the address and generating the necessary internal signals for the AES core.

In this implementation, the management core can:
* **Configure the Engine:** Set the key length (128-bit or 256-bit) and choose between encryption or decryption modes.
* **Manage Keys and Data:** Write the encryption keys and input data blocks to the core's internal memory.
* **Control Execution:** Trigger the initialization of key expansion and start the processing of data blocks.
* **Monitor Status:** Read back the status of the engine to determine when the core is ready for new data or when a valid result is available to be read.

By mapping these functions to the Wishbone address space, the AES hardware becomes a seamless extension of the SoC's memory, allowing for simple software-driven cryptographic operations.

There are 10 signals used to write/read to a wishbone slave port that are summarized in the below table:
Signal Name in verilog |	# bits |	Signal meaning |	How is the signal used?
--- | --- | --- | --- 
wb_clk_i |	1 |	Clock |	A square wave that can be at either high or low. Data is read or written at either the posedge (positive edge) or negedge (negative edge)
wb_rst_i | 1 | Reset | A reset restores the status of all registers to the initial value (which is normally zero)
wbs_stb_i/wbs_cyc_i |	1 |	Strobe/Bus Cycle |	If both of these signals are high this means that there is a valid data transfer taking place. The ANDing of those two signals is the enable signal for any slave port register. 
wbs_we_i | 1 |	Write enable for input | If this signal is high, then a write operation is taking place, if it is low, then a read operation is taking place.
wbs_sel_i |	4	| Select for input | If a write operation is taking place, the slave port has a 32-bit register. That register is divided into 4 8-bit units. Each bit on this bus tells if the corresponding 8-bits coming from the wbs_dat_i should be written or not. For example, if wbs_sel_i[0] is 1 and this is a write operation, then the slave register bits 0-7 are going to be updated with the values read from wbs_dat_i[7:0]
wbs_dat_i |	32 | Input data |	This is the data that is written from a master to a slave in a write operation
wbs_adr_i |	32 | Input Address | Each slave port is mapped to an address in memory. wbs_adr_i specifies that address. 
wbs_ack_o |	1	| Acknowledgement |	This signal is set to high following a successful read or write operation. In the case of the SPM, a read operation for the P register is not going to take place until the multiplication is done, which means that wbs_ack_o will stay low until the multiplication is finished.
wbs_dat_o	| 32 | Output Data | At the end of a write operation, the data sent on wbs_dat_o is the same as the input data received from wbs_dat_i which indicates a successful read operation. At the end of a read operation, the data sent on wbs_dat_o is the data stored in slave port with address wbs_adr_i

The above table explains what each signal means in a wishbone slave and how each signal can be used. 

---

## 📖 Documentation

The `docs/` directory contains the complete learning path for hardening and verifying the AES Accelerator within the Caravel SoC:

### Module Documentation

Each module provides a dedicated guide with a step-by-step flow for a specific stage of the ASIC implementation:

- **[MODULE0.md](docs/MODULE0.md)**: Installation and Environment
  - Setting up the LibreLane containerized environment.
  - Caravel User Project repository initialization and Sky130 PDK installation.

- **[MODULE1.md](docs/MODULE1.md)**: RTL Exploration & Simulation
  - Analyzing the Secworks AES RTL architecture and sub-modules.
  - Functional verification using Icarus Verilog and GTKWave.

- **[MODULE2.md](docs/MODULE2.md)**: Wishbone Bus Integration
  - Wrapping the AES core with the Wishbone interface (`aes_wb_wrapper.v`).
  - Signal mapping and handshaking logic (`ack`, `we`, `stb`).

- **[MODULE3.md](docs/MODULE3.md)**: Hardening with LibreLane
  - Running the "Classic" flow: Floorplanning, PDN, and Placement.
  - Generating the GDSII for the standalone AES macro.

- **[MODULE4.md](docs/MODULE4.md)**: Hierarchical Integration
  - Integrating the AES macro into the `user_project_wrapper`.
  - Top-level routing and physical sign-off (LVS/DRC) using Magic and Netgen.

- **[MODULE5.md](docs/MODULE5.md)**: Firmware & Silicon Validation
  - Developing C-firmware for the RISC-V management core to drive the AES engine.
  - Full-chip SoC simulation to verify memory-mapped I/O operations.

### Reference Documentation
- **[LibreLane Documentation](https://librelane.readthedocs.io/en/latest/getting_started/)**: Get started with the official LibreLane Docs.
- **[OpenROAD Documentation](https://openroad.readthedocs.io/en/latest/main/README.html)**: Comprehensive technical documentation for the OpenROAD tool suite.
- **[Efabless Open MPW Video Playlist](https://www.youtube.com/playlist?list=PLZuGFJzpFksB57YCxIQ50DPkvNFMpfCXd)**: Video guides for the Open MPW shuttle program.
- **[Caravel Datasheet](https://github.com/chipfoundry/caravel/blob/main/docs/caravel_datasheet_2.pdf)**: Detailed electrical and physical specifications of the Caravel harness.
- **[Caravel Technical Reference Manual (TRM)](https://github.com/chipfoundry/caravel/blob/main/docs/caravel_datasheet_2_register_TRM_r2.pdf)**: Complete register maps and programming guides for the management SoC.
- **[Community](https://fossi-chat.org)**: Join the technical discussion on the FOSSi Chat Matrix Server.
- **[GLOSSARY.md](docs/GLOSSARY.md)**: Comprehensive glossary of ASIC terms (PnR, GDSII, LVS, DRC) used in this workshop.

---

## 🚀 Start Learning

To begin your journey in ASIC design and AES implementation, follow the modules sequentially. Each module builds upon the previous one, taking you from environment setup to a complete, hardened GDSII.

### [Module 0: Installation and Setup](docs/MODULE0.md)

Before starting the design process, you must configure your local or cloud environment. This module provides a step-by-step flow to ensure all dependencies for the Caravel SoC and LibreLane are correctly installed.

**Key Objectives:**
* **Environment Reproducibility:** Setting up the containerized LibreLane environment to ensure consistent results across different operating systems.
* **PDK Installation:** Downloading and configuring the **SkyWater 130nm (Sky130)** Process Design Kit.
* **Repository Setup:** Initializing your local workspace using the Caravel User Project template.
* **Verification:** Running a basic connectivity check to confirm the toolchain (Yosys, OpenROAD, Magic) is operational.

> **Next Step:** Once your environment is verified, proceed to **Module 1: RTL Exploration & Simulation** to dive into the AES core architecture.

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

<div align="center">

<img src="https://github.com/user-attachments/assets/84028fb9-2e26-4733-af28-c6e825395912" alt="Silicon Sprint Logo" height="140" />

---

[![Typing SVG](https://readme-typing-svg.demolab.com?font=Inter&size=44&duration=3000&pause=600&color=4C6EF5&center=true&vCenter=true&width=1100&lines=Silicon+Sprint+AUC;LibreLane+Flow+Mastery;AES+Accelerator+Integration)](https://git.io/typing-svg)

# Silicon Sprint AUC — Open-Source ASIC Workshop

<p align="center">
    <a href="https://opensource.org/licenses/Apache-2.0"><img src="https://img.shields.io/badge/License-Apache%202.0-blue.svg" alt="License: Apache 2.0"/></a>
    <a href="https://silicon-sprint-auc.readthedocs.io/en/latest/"><img src="https://readthedocs.org/projects/silicon-sprint-auc/badge/?version=latest" alt="Documentation Status"/></a>
    <a href="https://github.com/chipfoundry/librelane"><img src="https://img.shields.io/badge/Flow-LibreLane%20v3-FF69B4" alt="LibreLane v3"/></a>
    <a href="https://nixos.org/"><img src="https://img.shields.io/static/v1?logo=nixos&logoColor=white&label=&message=Built%20with%20Nix&color=41439a" alt="Built with Nix"/></a>
    <a href="https://fossi-chat.org"><img src="https://img.shields.io/badge/Community-FOSSi%20Chat-1bb378?logo=element" alt="FOSSi Chat"/></a>
</p>

**A hands-on journey from RTL to silicon — hardening an AES-128 Accelerator using the open-source LibreLane toolchain on the SkyWater 130nm process node.**

📖 **[Read the Full Documentation →](https://silicon-sprint-auc.readthedocs.io/en/latest/)**

</div>

---

## What Is This Workshop?

This workshop is a complete, modular educational resource for learning **open-source ASIC physical design**. Starting from a working RTL description of an AES-128 encryption core, you will take the design all the way through synthesis, floorplanning, placement, routing, and physical signoff — ending with a verified, manufacturable **GDSII layout** ready for the OpenMPW shuttle.

The workshop is built around **LibreLane**, the open-source RTL-to-GDSII flow maintained by the FOSSi Foundation, and uses the **SkyWater 130nm (Sky130)** PDK throughout. Every module is self-contained with step-by-step instructions, configuration references, and result verification checkpoints.

---

## What You Will Build

An **AES-128 encryption core** encapsulated in a **Wishbone bus wrapper** (`aes_wb_wrapper`), integrated into the **Caravel SoC** harness, and taken through a complete physical implementation flow:

| Stage | Tool |
| :--- | :--- |
| RTL Linting & Synthesis | Yosys / Verilator |
| Floorplan & Power Network | OpenROAD |
| Placement & Clock Tree Synthesis | OpenROAD |
| Global & Detailed Routing | OpenROAD / TritonRoute |
| Physical Signoff (DRC · LVS · GDSII) | Magic / KLayout / Netgen |

---

## What You Will Learn

By completing all modules in this workshop, you will be able to:

- Set up a **fully reproducible ASIC toolchain** using Nix — no version conflicts, no broken environments.
- Understand the **Caravel SoC architecture** and how to integrate a custom design into the `user_project_wrapper`.
- Write a **Wishbone bus wrapper** and connect RTL to an SoC bus interface.
- Drive the **LibreLane Classic Flow** step by step — from RTL to routed layout — with full control over every configuration parameter.
- Diagnose and resolve **timing violations** (setup, hold, max slew, max cap) using targeted ECO buffer insertions.
- Understand and configure **Clock Tree Synthesis**, global routing, detailed routing, and antenna repair.
- Run a complete **physical signoff** flow including fill insertion, parasitic extraction (RCX), multi-corner STA, IR drop analysis, DRC, LVS, and XOR verification.
- Apply **Macro-First, Top-Level Integration, and Full-Wrapper Flattening** strategies for Caravel wrapper hardening.
- Prepare a design for a real **multi-project chip tape-out** on the OpenFrame platform.

---

## Toolchain

| Tool | Role |
| :--- | :--- |
| **Nix** | Reproducible, isolated environment management |
| **LibreLane v3** | RTL-to-GDSII flow orchestrator |
| **Yosys** | Synthesis and technology mapping |
| **Verilator** | RTL linting |
| **OpenROAD** | Floorplan, placement, CTS, routing, and STA |
| **Magic** | Layout editor, DRC, and SPICE extraction |
| **KLayout** | GDSII viewer, DRC, and XOR verification |
| **Netgen** | LVS netlist comparison |
| **SkyWater 130nm PDK** | `sky130_fd_sc_hd` standard cell library |

---

## Workshop Modules

> **Full documentation with step-by-step instructions, configuration references, and results:** [silicon-sprint-auc.readthedocs.io](https://silicon-sprint-auc.readthedocs.io/en/latest/)

---

### [Module 0 — Environment Setup](https://silicon-sprint-auc.readthedocs.io/en/latest/MODULE0.html)

Install and verify a fully reproducible ASIC development environment.

- Install Nix using the official Determinate Systems installer (Linux, WSL2, macOS)
- Initialize the LibreLane Nix shell and understand why reproducibility matters
- Run the LibreLane smoke test to download the SkyWater 130nm PDK and verify all tools
- Clone the `Silicon-Sprint-AUC` project repository and the AES RTL source

> **Start here before any other module.**

---

### [Module 1 — RTL Integration & ASIC Flow to PDN](https://silicon-sprint-auc.readthedocs.io/en/latest/MODULE1.html)

Integrate the AES core into the Caravel SoC via a Wishbone wrapper and execute the LibreLane Classic Flow through Power Distribution Network generation.

- Understand the Wishbone bus protocol and write the `aes_wb_wrapper` Verilog module
- Define timing constraints (SDC files) and create the base LibreLane `config.json`
- Run synthesis exploration to evaluate area, timing, and resource tradeoffs
- Execute the Classic Flow through floorplan and PDN generation
- Inspect layout results in KLayout and the OpenROAD GUI
- Read and interpret synthesis, timing, and PDN integrity reports

---

### [Module 2 — Placement & Clock Tree Synthesis](https://silicon-sprint-auc.readthedocs.io/en/latest/MODULE2.html)

Configure I/O pin placement, run global and detailed placement, synthesize the clock tree, and resolve post-CTS timing violations.

- Constrain all Wishbone I/O pins to the South edge using a custom pin configuration file
- Configure global and detailed placement parameters for the AES wrapper
- Synthesize the clock distribution network (CTS) and understand its role in timing closure
- Run post-CTS timing repair using buffer insertion and gate resizing
- Verify timing closure at the post-CTS checkpoint before proceeding to routing

---

### [Module 3 — Routing & Physical Optimization](https://silicon-sprint-auc.readthedocs.io/en/latest/MODULE3.html)

Run global routing, repair antenna violations, and complete detailed routing with TritonRoute.

- Configure and execute Global Routing (GRT) with congestion and overflow parameters
- Understand antenna violations — why they occur and how to repair them
- Run post-GRT design repair using routing-aware parasitic estimates
- Execute Detailed Routing (DRT) with TritonRoute and verify zero DRC violations
- Inspect routing congestion maps and antenna summary reports in OpenROAD

---

### [Module 4 — Physical Signoff](https://silicon-sprint-auc.readthedocs.io/en/latest/MODULE4.html)

Complete the full signoff flow: parasitic extraction, multi-corner STA, IR drop analysis, ECO buffer insertion, DRC, LVS, and final GDSII generation.

- Insert fill cells and run parasitic extraction (RCX) for accurate timing analysis
- Perform post-PnR Static Timing Analysis across 9 process-voltage-temperature corners
- Analyze IR drop and power reports
- Diagnose and fix remaining max-slew, max-cap, and hold violations using ECO buffer insertions
- Generate the final GDSII with Magic and KLayout stream-out
- Run Design Rule Check (DRC) with both Magic and KLayout
- Verify Layout vs. Schematic (LVS) with Netgen and run XOR geometric comparison
- Confirm formal equivalence between the RTL and the physical netlist

---

### [Module 5 — Caravel User Project Wrapper Integration](https://silicon-sprint-auc.readthedocs.io/en/latest/MODULE5.html)

Integrate the hardened AES macro into the Caravel `user_project_wrapper` using three distinct hardening strategies.

- Understand the physical constraints imposed by the Caravel harness (fixed die area, pin locations, PDN rules)
- **Strategy 1 — Macro-First Hardening:** Place the AES macro as a black-box hard macro inside the wrapper; configure the DEF template, macro LEF/GDS views, and power connections
- **Strategy 2 — Top-Level Integration:** Instantiate the AES macro alongside top-level standard cells to add buffering and glue logic
- **Strategy 3 — Full-Wrapper Flattening:** Merge the AES logic directly into the wrapper for maximum performance at the cost of longer PnR iterations
- Copy macro views, execute wrapper hardening, and verify the complete user project layout

---

### [Module 6 — OpenFrame Multi-Project Chip Tape-Out](https://silicon-sprint-auc.readthedocs.io/en/latest/MODULE6.html)

Prepare and harden your design for integration into a real multi-project chip on the OpenFrame platform.

- Understand OpenFrame — the bare padframe alternative to Caravel — and its direct GPIO model
- Learn how the AUC Silicon Sprint chip partitions the OpenFrame user area into a 4×3 grid of student project slots
- Understand the scan-chain GPIO MUX tree that routes pads to exactly one active project at runtime
- Meet the integration contract: area budget, pin interface, timing requirements, and DRC rules
- Configure and harden your design as a `project_macro` ready for openframe multi-project.

---

## Getting Started

**1. Clone this repository:**
```console
$ git clone https://github.com/basemhesham/Silicon-Sprint-AUC ~/Silicon-Sprint-AUC
```

**2. Clone the AES RTL source:**
```console
$ git clone https://github.com/secworks/aes ~/secworks_aes
```

**3. Follow [Module 0](https://silicon-sprint-auc.readthedocs.io/en/latest/MODULE0.html) to set up your environment.**

---

## License

This project is licensed under the [Apache 2.0 License](LICENSE).

---

## Credits

Developed by **Basem Hesham**
📧 [basemhesham159@gmail.com](mailto:basemhesham159@gmail.com)
💼 [LinkedIn](https://www.linkedin.com/in/basem-hesham1/?skipRedirect=true)

---

<div align="center">
<sub>Built with ❤️ for the open silicon community · Powered by <a href="https://github.com/chipfoundry/librelane">LibreLane</a> & <a href="https://skywater-pdk.readthedocs.io/">SkyWater 130nm</a></sub>
</div>

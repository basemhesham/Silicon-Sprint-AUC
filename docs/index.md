# Silicon Sprint — AUC ASIC Design Workshop

```{admonition} About This Workshop
:class: note

This documentation guides you through the complete **RTL-to-GDSII hardening** of an **AES-128 Accelerator**
using the open-source **LibreLane** toolchain and the **SkyWater 130nm (`sky130_fd_sc_hd`)** process node.

By the end of this workshop, you will have taped out a real, silicon-ready cryptographic accelerator
and gained hands-on experience with every stage of the modern open-source ASIC design flow.
```

---

## What You Will Build

The target design is an **AES-128 encryption core** wrapped in a **Wishbone bus interface**
(`aes_wb_wrapper`), making it compatible with the **Caravel SoC** harness. You will take this
design from a high-level Verilog description all the way to a verified, manufacturable
{term}`GDSII` layout.

The full design journey spans the following stages:

| Stage | Description | Tool |
| :--- | :--- | :--- |
| **RTL Integration** | Wrap the AES core in a Wishbone interface | Verilog |
| **Linting** | Structural and timing construct verification | Verilator |
| **Synthesis** | Technology mapping to `sky130_fd_sc_hd` cells | Yosys |
| **Floorplanning** | Physical area definition and macro placement | OpenROAD |
| **Power Grid** | {term}`PDN` generation and verification | OpenROAD |
| **Placement** | Standard cell placement and design repair | OpenROAD |
| **CTS** | Clock tree synthesis and skew minimization | OpenROAD |
| **Routing** | Global and detailed signal routing | OpenROAD |
| **Physical Signoff** | {term}`DRC`, {term}`LVS`, and {term}`GDSII` export | Magic / KLayout / Netgen |

---

## Workshop Modules

The workshop is structured as a sequence of self-contained modules. Each module builds directly
on the output of the previous one — complete them in order.

```{toctree}
:maxdepth: 2
:caption: Workshop Modules

MODULE0
MODULE1
```

### Module Overview

::::{grid} 1 1 2 2
:gutter: 3

:::{grid-item-card} 📦 Module 0 — Environment Setup
:link: MODULE0
:link-type: doc

Install and configure the LibreLane toolchain, clone the workshop repository, and verify
your Nix shell environment before beginning the ASIC flow.

+++
*Start here — prerequisites for all subsequent modules.*
:::

:::{grid-item-card} 🔧 Module 1 — RTL Integration & ASIC Flow
:link: MODULE1
:link-type: doc

Integrate the AES core with a Wishbone wrapper, configure the LibreLane flow, and execute
the design from synthesis through Power Distribution Network generation.

+++
*Requires completion of Module 0.*
:::

:::{grid-item-card} 🔄 Module 2 — Placement & Clock Tree *(Coming Soon)*
:link: #
:link-type: url

Guided placement optimization, Clock Tree Synthesis ({term}`CTS`), and post-CTS timing
closure using the OpenROAD toolchain.

+++
*Not yet available — check back for updates.*
:::

:::{grid-item-card} 🚦 Module 3 — Routing & Signoff *(Coming Soon)*
:link: #
:link-type: url

Full routing execution, antenna repair, parasitic extraction, and final physical signoff
using Magic, KLayout, and Netgen.

+++
*Not yet available — check back for updates.*
:::

::::

---

## Technical Stack

This workshop uses exclusively **open-source EDA tools**, accessible through a reproducible
Nix-managed environment:

| Tool | Role |
| :--- | :--- |
| **LibreLane** | Unified RTL-to-GDSII flow orchestrator |
| **Yosys** | RTL synthesis and technology mapping |
| **OpenROAD** | Floorplan, placement, CTS, routing, and {term}`STA` |
| **Magic** | Layout editor, {term}`DRC`, and {term}`SPICE` extraction |
| **KLayout** | {term}`GDSII` viewer, {term}`DRC`, and XOR verification |
| **Netgen** | {term}`LVS` netlist comparison |
| **Verilator** | RTL linting |
| **SkyWater 130nm PDK** | Process design kit (`sky130_fd_sc_hd` standard cell library) |

---

## How to Use This Documentation

```{tip}
Each module page is self-contained and includes:

- **Step-by-step terminal commands** in clearly marked `console` blocks.
- **Configuration file snippets** with variable reference tables.
- **Expandable code dropdowns** for longer source files.
- **Report interpretation guides** for analyzing tool output.
- **Comparative tasks** for reinforcing key {term}`PPA` trade-off concepts.

If you are attending a live TA session, follow the module pages in sequence.
If you are working independently, start from **Module 0** to verify your environment
before proceeding.
```

---

```{glossary}
GDSII
  Graphic Database System II. The standard binary file format representing the final IC physical layout, delivered to the foundry for fabrication.

PDN
  Power Distribution Network. The metal conductor network delivering VDD and GND to every standard cell in the design.

SDC
  Synopsys Design Constraints. A Tcl-based format specifying timing and clocking constraints for implementation and static timing analysis.

PnR
  Place and Route. The physical design stage encompassing standard cell placement and signal wire routing.

STA
  Static Timing Analysis. Timing verification performed without simulation, by exhaustively checking all signal paths against constraints.

DRC
  Design Rule Check. Verification that the physical layout conforms to the foundry's manufacturing constraints.

LVS
  Layout vs. Schematic. Verification that the physical layout matches the intended circuit schematic.

SPICE
  Simulation Program with Integrated Circuit Emphasis. Analog circuit simulator used for electrical verification of extracted layouts.

PPA
  Power, Performance, Area. The three primary optimization axes in VLSI design, representing an inherent engineering trade-off.

CTS
  Clock Tree Synthesis. The physical design step that builds a balanced clock distribution network to minimize skew across all sequential elements.
```

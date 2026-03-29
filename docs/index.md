# Silicon Sprint — AUC ASIC Design Workshop

```{admonition} About This Workshop
:class: note

A hands-on journey from **RTL to silicon** — hardening an **AES-128 Accelerator** with the
open-source **LibreLane** toolchain on the **SkyWater 130nm** process node.
```

---

## What You Will Build

An **AES-128 encryption core** wrapped in a **Wishbone bus interface** (`aes_wb_wrapper`),
integrated into the **Caravel SoC** harness and taken all the way to a verified,
manufacturable {term}`GDSII` layout.

| Stage | Tool |
| :--- | :--- |
| RTL Integration & Synthesis | Yosys / Verilator |
| Floorplan & Power Grid | OpenROAD |
| Placement & Clock Tree | OpenROAD |
| Routing | OpenROAD / TritonRoute |
| Physical Signoff ({term}`DRC` · {term}`LVS` · {term}`GDSII`) | Magic / KLayout / Netgen |

---

## Modules


::::{grid} 1 1 2 2
:gutter: 3

:::{grid-item-card} 📦 Module 0 — Environment Setup
:link: MODULE0
:link-type: doc

Nix installation, LibreLane setup, repository cloning, and environment verification.

+++
*Start here before anything else.*
:::

:::{grid-item-card} ⚙️ Module 1 — RTL Integration & ASIC Flow
:link: MODULE1
:link-type: doc

Wishbone wrapper integration, synthesis exploration, floorplan, and PDN generation.

+++
*Requires Module 0.*
:::

:::{grid-item-card} 🔄 Module 2 — Placement & CTS
:link: MODULE2
:link-type: doc

I/O pin placement, global and detailed placement, Clock Tree Synthesis, and post-CTS
timing repair.

+++
*Requires Module 1.*
:::

:::{grid-item-card} 🌐 Module 3 — Routing
:link: MODULE3
:link-type: doc

Global routing, antenna repair, post-GRT design repair, and detailed routing with
TritonRoute.

+++
*Requires Module 2.*
:::

:::{grid-item-card} ✅ Module 4 — Physical Signoff
:link: MODULE4
:link-type: doc

Fill insertion, parasitic extraction, post-{term}`PnR` STA across 9 corners, IR drop
analysis, {term}`DRC`, {term}`LVS`, and final {term}`GDSII` generation.

+++
*Requires Module 3.*
:::

::::

---

## Toolchain

| Tool | Role |
| :--- | :--- |
| **LibreLane** | RTL-to-GDSII flow orchestrator |
| **Yosys** | Synthesis and technology mapping |
| **OpenROAD** | Floorplan, placement, CTS, routing, and {term}`STA` |
| **Magic** | Layout editor, {term}`DRC`, and {term}`SPICE` extraction |
| **KLayout** | {term}`GDSII` viewer, {term}`DRC`, and XOR verification |
| **Netgen** | {term}`LVS` netlist comparison |
| **Verilator** | RTL linting |
| **SkyWater 130nm PDK** | `sky130_fd_sc_hd` standard cell library |

---

```{glossary}
GDSII
  Graphic Database System II. The standard binary layout format delivered to the foundry for fabrication.

PDN
  Power Distribution Network. The metal grid delivering VDD and GND to every standard cell.

SDC
  Synopsys Design Constraints. Tcl-based format specifying timing and clocking constraints.

PnR
  Place and Route. Standard cell placement and signal wire routing.

STA
  Static Timing Analysis. Exhaustive path-by-path timing verification without simulation.

DRC
  Design Rule Check. Verification that the layout conforms to foundry manufacturing constraints.

LVS
  Layout vs. Schematic. Verification that the physical layout matches the logical netlist.

SPICE
  Simulation Program with Integrated Circuit Emphasis. Analog circuit simulator for layout verification.

PPA
  Power, Performance, Area. The three primary VLSI optimisation axes.

CTS
  Clock Tree Synthesis. Building a balanced clock distribution network to minimise skew.
```

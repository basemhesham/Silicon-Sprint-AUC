# Module 6: Hardening Your Design for the OpenFrame Multi-Project Chip

---

## Table of Contents

1. [OpenFrame — The Bare Padframe Platform](#openframe-the-bare-padframe-platform)
2. [The AUC Silicon Sprint Multi-Project Chip](#the-auc-silicon-sprint-multi-project-chip)
3. [Design Rules and Integration Contract](#design-rules-and-integration-contract)
4. [The `project_macro` Slot](#the-project_macro-slot)
5. [Workshop Repository & File Structure](#workshop-repository--file-structure)
6. [Integrating Your Design into `project_macro`](#integrating-your-design-into-project_macro)
7. [Timing Constraints](#timing-constraints)
8. [Hardening Configuration (`config.json`)](#hardening-configuration-configjson)

---

## 1. OpenFrame — The Bare Padframe Platform

**OpenFrame** is an alternative chip harness to Caravel. Where Caravel includes a full
management SoC, a Wishbone bus, and a logic analyser, OpenFrame provides only the
essential harness — a padframe, a power-on-reset circuit, and a 32-bit project ID ROM.

```{figure} ./figures/OpenFrame.png
:align: center

*OpenFrame chip — bare padframe with a ~15 mm² open user area. All 44 GPIO pads are
directly accessible by the user design with no SoC intermediary.*
```

This minimal footprint gives you maximum freedom:

| | Caravel | OpenFrame |
| :--- | :--- | :--- |
| Management SoC | ✅ PicoRV32 + peripherals | ❌ None |
| Wishbone bus | ✅ Required for host access | ❌ Not available |
| GPIO access | Shared with SoC | Full direct control |
| User area | ~10 mm² | ~15 mm² |
| Interface protocol | Wishbone registers | Any — you design it |

```{admonition} I/O Frame Only
:class: note

OpenFrame provides only the pad ring (GPIO and power pads) and the flat power grid.
Everything inside the user area is user-defined. There is no CPU, no bus protocol, and
no firmware — your design is directly responsible for all GPIO configuration and control.
```

Because there is no management SoC, you do not need a Wishbone wrapper around your
design. Your logic connects directly to the GPIO pads through the pin interface of the
`project_macro` boundary.

---

## 2. The AUC Silicon Sprint Multi-Project Chip

The **AUC Silicon Sprint** does not dedicate the entire OpenFrame user area to a single
design. Instead, the chip is partitioned to host **up to 12 independent student projects**
in a single fabrication run, arranged in a **4-row × 3-column grid**.

```{figure} ./figures/floorplan_3x4.svg
:align: center

*OpenFrame Multi-Project floorplan — 4 rows × 3 columns of project slots. Each slot is
connected to the GPIO padframe through dedicated orange mux macros.*
```

A **scan-chain-configurable MUX tree** routes the chip's 38 usable GPIOs to exactly one
selected project at runtime. When a project is activated, its three orange mux macros
(bottom, right, and top) connect it to the physical pads. All other projects remain
electrically isolated.

Each project slot communicates with the outside world through the `project_macro`
boundary ports:

| Edge | Signals | Route to pads |
| :--- | :--- | :--- |
| **Left** | `clk`, `reset_n`, `por_n` | From the green macro (chip-wide clock and reset distribution) |
| **Bottom** | `gpio_bot_in/out[14:0]` + `oeb` + `dm` | Via bottom orange mux → right-side GPIO pads |
| **Right** | `gpio_rt_in/out[8:0]` + `oeb` + `dm` | Via right orange mux → top-side GPIO pads |
| **Top** | `gpio_top_in/out[13:0]` + `oeb` + `dm` | Via top orange mux → left-side GPIO pads |

**Total usable GPIOs per project: 15 + 9 + 14 = 38.**

The orange muxes, green macro, purple routing macros, and scan controller are all
**pre-hardened fixed infrastructure**. You do not touch them. Your responsibility is
to harden your own `project_macro` to the correct footprint and submit the {term}`GDSII`.

For a deeper understanding of the system architecture and the multiproject environment, please refer to the following resource:

* **OpenFrame Multiproject Documentation:** [Caravel OpenFrame MPC Overview](https://github.com/basemhesham/openframe_multiproject/blob/main/Caravel_OF_MPC.md)
---

## 3. Design Rules and Integration Contract

Before writing a single line of RTL, understand the constraints that the multi-project
chip imposes on every participating macro. Violating any of these will prevent your
design from being integrated.

```{admonition} Fixed-Budget Chip Resources
:class: warning

The die area is fixed. Power domains, I/O pads, clock domains, and layer usage must
all be budgeted up front across every participating macro. You share the chip with up to
11 other students — your choices affect everyone.
```

### What You Must Follow

| Constraint | Rule | Reason |
| :--- | :--- | :--- |
| **Die area** | Fixed at `880 × 1031.66 µm`. Do not change `DIE_AREA`. | Every slot is placed at pre-determined coordinates. A different size breaks the assembly. |
| **RTL interface** | Use the exact port list of the `project_macro` template. | This port list is the black box used at the top level. Any change to it breaks connectivity. |
| **DEF template** | Use `fixed_dont_change/project_macro.def` without modification. | Pin locations and power ring geometry are fixed by the top-level integration. |
| **PDN configuration** | Use `PDN_MULTILAYER: false`. Do not enable Metal 5. | Metal 5 is reserved for the top-level power straps. Any Metal 5 geometry inside your macro creates a DRC short that blocks the power delivery to adjacent projects. |
| **Routing layer cap** | Use `RT_MAX_LAYER: "met4"`. | Same reason as above — Metal 5 must remain clear for the wrapper's power straps to pass through. |
| **Power domain** | Use `vccd1` and `vssd1` only. | The slot's power is connected by the top-level wrapper. You declare the nets; the top level provides the connections. |
| **Clock port** | Use port name `clk`. | The green macro drives `clk` by name to every project slot. |
| **Timing constraints** | Use the The Retrieved Constraints part. | These encode the measured electrical delays through openframe. |

```{note}
If you use `PDN_CORE_RING: true` or allow Metal 5 routes, the resulting obstructions
will block the top-level Metal 5 straps from reaching the other projects in the grid.
The error cannot be fixed after integration — it would require re-running your macro.
```

---

## 4. The `project_macro` Slot

Each student's design occupies a single **project slot** with a fixed physical footprint
of **880 × 1031.66 µm**. All 12 slots in the chip are identical in size and pin placement.

We provides a **DEF template** for the slot. LibreLane uses this template
at the floorplan step to stamp the exact boundary, I/O pin locations, and power ring
geometry into your design database — guaranteed to match what the top-level integration
expects.

```{admonition} Use the Template DEF As-Is
:class: important

Do not modify `fixed_dont_change/project_macro.def`. It contains the exact pin positions
and power ring that the surrounding orange and green macros connect to. Any change —
even a single pin shifted by one grid step — will produce a DRC violation or unconnected
net when your macro is placed in the chip.
```

---

## 5. Workshop Repository & File Structure

Clone the workshop repository:

```console
$ git clone https://github.com/basemhesham/openframe_multiproject \
    ~/openframe_multiproject
```

The relevant directory structure is:

```text
~/openframe_multiproject/
├── verilog/
│   └── rtl/
│       └── project_macro.v          ← Template — add your design here
├── openlane/
│   └── project_macro/
│       ├── config.json              ← Hardening configuration (edit this)
│       ├── fixed_dont_change/
│       │   └── project_macro.def   ← Fixed slot DEF template — do NOT edit
│       ├── pnr.sdc                  ← PnR timing constraints
│       └── signoff.sdc              ← Signoff timing constraints
├── gds/                             ← Submit your final GDS here
├── lef/                             ← Submit your final LEF here
└── verilog/gl/                      ← Submit your gate-level netlist here
```

---

## 6. Integrating Your Design into `project_macro`

Open the template file:

```console
$ gedit ~/openframe_multiproject/verilog/rtl/project_macro.v
```

The template declares the complete port list that the chip infrastructure connects to.
**Do not change the module name or any port declaration.** Replace the tie-off logic
inside the `USER LOGIC GOES HERE` section with your own design — either by
instantiating a submodule or by writing your RTL directly.

````{dropdown} project_macro.v — Template
```{literalinclude} ./code/openframe/project_macro.v
:language: verilog
```
````

### GPIO Usage Guidelines

All 38 GPIO ports are available to your design. Each port group has three signal
directions:

- `gpio_*_in` — data arriving from the GPIO pad (always valid, regardless of `oeb`).
- `gpio_*_out` — data your design drives onto the pad when `oeb = 0`.
- `gpio_*_oeb` — output enable bar: `0` = your design drives the pad, `1` = the pad
  is high-impedance (input mode).
- `gpio_*_dm` — drive mode, 3 bits per pad. Set to `3'b110` (strong push-pull) for
  standard digital I/O.

```{admonition} Use the Exact RTL Interface
:class: important

Your instantiated submodule must connect to the `project_macro` ports — do not add,
rename, or remove any port from the template module declaration. The exact port list is
used as the black box interface at the top level.
```

---

## 7. Timing Constraints

You are responsible for authoring two distinct SDC files: `pnr.sdc` (for implementation) and `signoff.sdc` (for final verification). These files must be constructed by integrating two specific sets of data:

### 1. Design Constraints (User-Defined)
These are internal constraints based on your specific implementation goals. You must define:
* **Clock Period:** Set based on your target operating frequency.
* **Uncertainty & Derate:** To account for clock jitter and process variation.
* **Transition Limits:** To ensure signal integrity across your logic gates.

### 2. Retrieved Constraints (Boundary-Defined)
To ensure your macro functions correctly within the larger system, you must incorporate the I/O delays derived from the **OpenFrame** boundary. These represent the real-world electrical delays between the chip pads and your `project_macro` ports.
* **Source:** You can retrieve these fixed boundary constraints from the `openframe_project_wrapper` SDC [here (Lines 37-38)](https://github.com/basemhesham/openframe_multiproject/blob/main/openlane/openframe_project_wrapper/base_user_project_wrapper.sdc#L37C1-L38C1).

---

### Implementation Strategy
* **pnr.sdc:** Write this file with more aggressive targets (tighter constraints). This accounts for the gap between the tool’s early parasitic estimations and the final extracted values. Over-constraining here ensures that potential violations are resolved early in the routing phase.
* **signoff.sdc:** This file should reflect the true timing requirements. It is used during the final timing signoff after **SPEF extraction** to confirm that the design meets all real-world electrical targets.

---

## 8. Hardening Configuration (`config.json`)

Open the configuration file:

```console
$ gedit ~/openframe_multiproject/openlane/project_macro/config.json
```

The configuration consists of two sections. The **user section** at the top is where
you tune synthesis, floorplan, and routing parameters for your specific design. The
**fixed section** at the bottom must never be modified.

### Fixed Section 

```json
    "//": "Fixed configurations for project macro — do NOT edit below this line",
    "DESIGN_NAME": "project_macro",
    "FP_SIZING": "absolute",
    "DIE_AREA": [0, 0, 880, 1031.66],
    "FP_DEF_TEMPLATE": "dir::fixed_dont_change/project_macro.def",
    "VDD_NETS": ["vccd1"],
    "GND_NETS": ["vssd1"],
    "CLOCK_PORT": "clk",
```

| Parameter | Value | Why Fixed |
| :--- | :--- | :--- |
| `DESIGN_NAME` | `project_macro` | Must match the module name in `project_macro.v` and the top-level instantiation. |
| `DIE_AREA` | `[0, 0, 880, 1031.66]` | The slot footprint is fixed for all 12 projects. Any change breaks the top-level placement. |
| `FP_DEF_TEMPLATE` | `project_macro.def` | Encodes the exact pin locations and power ring the surrounding infrastructure connects to. |
| `PDN_MULTILAYER: false` | Metal 4 straps only | The top-level wrapper routes Metal 5 horizontal straps over each slot. Enabling Metal 5 inside your macro that block power delivery to adjacent projects. |
| `RT_MAX_LAYER: "met4"` | No Metal 5 routing | Same reason — Metal 5 must remain clear inside the macro boundary. |
| `VDD_NETS` / `GND_NETS` | `vccd1` / `vssd1` | The top-level power connections to each slot use these net names. Any change breaks power continuity. |
| `CLOCK_PORT` | `clk` | The green macro drives `clk` by this exact name to every project slot. |

```{admonition} Checklist Before Submitting GDS file
:class: important

Before handing your files, verify all of the following:

- ✅ DRC passes with `COUNT: 0`.
- ✅ LVS reports `Circuits match uniquely.`
- ✅ Antenna check shows an empty violation table.
- ✅ `DIE_AREA` in your `config.json` is exactly `[0, 0, 880, 1031.66]`.
- ✅ `PDN_MULTILAYER: false` is set.
- ✅ `RT_MAX_LAYER: "met4"` is set.
- ✅ The module name in your Verilog is `project_macro`.
- ✅ All ports match the template declaration exactly.
```

---

```{glossary}
GPIO
  General Purpose Input/Output. A configurable digital signal pad on the chip boundary, directly accessible by user logic in the OpenFrame architecture.

PDN
  Power Distribution Network. The metal conductor grid delivering VDD and GND to every standard cell in the design.

DRC
  Design Rule Check. Verification that the physical layout conforms to the foundry's manufacturing constraints.

LVS
  Layout vs. Schematic. Verification that the physical layout is electrically equivalent to the design netlist.

GDSII
  Graphic Database System II. The binary layout format submitted to the foundry for fabrication.

STA
  Static Timing Analysis. Exhaustive path-by-path timing verification against declared constraints.

SDC
  Synopsys Design Constraints. Tcl-based timing and clocking constraints used during implementation and signoff.

LEF
  Library Exchange Format. A file describing the physical interface of a macro — boundary, pin locations, and metal blockages.
```

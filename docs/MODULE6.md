# Module 6: OpenFrame & Project Macro Hardening

```{admonition} Prerequisites
:class: important

Modules 1–5 used the **Caravel SoC** target, with the AES accelerator hardened inside a
`user_project_wrapper`. In this module, the same AES core is re-targeted to the
**OpenFrame** platform and integrated into a multi-project chip. You will harden a
`project_macro` that embeds the AES core with a lightweight SPI interface and produces
a {term}`GDSII` ready to be slotted into the shared chip by the instructor.
```

---

## Table of Contents

1. [OpenFrame — The Bare Padframe Platform](#openframe-the-bare-padframe-platform)
2. [OpenFrame Multi-Project Chip (MP-SoC)](#openframe-multi-project-chip-mp-soc)
3. [The `project_macro` Slot](#the-project_macro-slot)
4. [Workshop Repository & Template](#workshop-repository--template)
5. [RTL — AES via SPI Inside `project_macro`](#rtl-aes-via-spi-inside-project_macro)
6. [Timing Constraints](#timing-constraints)
7. [Hardening Configuration](#hardening-configuration)
8. [Running the Flow](#running-the-flow)

---

## 1. OpenFrame — The Bare Padframe Platform

**OpenFrame** is an alternative to Caravel that strips away the management SoC entirely.
It provides only the essential harness — the padframe, a power-on-reset circuit, and a
32-bit project ID ROM — giving you a clean **~15 mm²** user area and **44 GPIOs** to
connect directly to whatever logic you implement.

```{figure} ./figures/OpenFrame.png
:align: center

*OpenFrame chip — bare padframe with 15 mm² open user area and 44 GPIO pads directly
accessible by the user design.*
```

The key difference from Caravel:

| | Caravel | OpenFrame |
| :--- | :--- | :--- |
| Management SoC | ✅ PicoRV32 + peripherals | ❌ None |
| Wishbone bus | ✅ Required for host access | ❌ Not available |
| GPIO access | Shared with SoC | Full direct control |
| User area | ~10 mm² | ~15 mm² |
| Interface protocol | Wishbone registers | Any — you design it |

Because there is no management SoC, you do not need a Wishbone wrapper around your
design. Your logic talks directly to the GPIO pads through the pin interface defined
in the `project_macro` boundary.

---

## 2. OpenFrame Multi-Project Chip (MP-SoC)

The **AUC Silicon Sprint** does not fill the entire OpenFrame user area with a single
design — instead, the chip hosts **up to 12 independent student projects** in a single
fabrication run, arranged in a 4-row × 3-column grid.

```{figure} ./figures/floorplan_3x4.svg
:align: center

*OpenFrame Multi-Project floorplan — 4 rows × 3 columns of project slots, each
connected to the GPIO padframe through shared orange mux macros.*
```

A **scan-chain-configurable MUX tree** routes the chip's 38 usable GPIOs to exactly one
selected project at runtime. When a project is selected, its three orange mux macros
(bottom, right, and top) connect it to the physical GPIO pads. All other projects remain
electrically isolated.

Each project slot communicates through its `project_macro` boundary:

| Edge | Signals | Route |
| :--- | :--- | :--- |
| **Left** | `clk`, `reset_n`, `por_n` | From green macro (clock/reset distribution) |
| **Bottom** | `gpio_bot_in/out[14:0]` + `oeb` + `dm` | Via bottom orange mux → Caravel right pads |
| **Right** | `gpio_rt_in/out[8:0]` + `oeb` + `dm` | Via right orange mux → Caravel top pads |
| **Top** | `gpio_top_in/out[13:0]` + `oeb` + `dm` | Via top orange mux → Caravel left pads |

**Total usable GPIOs per project: 15 + 9 + 14 = 38.**

The orange muxes, green macro, purple routing macros, and scan controller are all
pre-hardened fixed infrastructure. Your only responsibility is to harden your own
`project_macro` to the correct footprint and hand the {term}`GDSII` to the instructor
for integration.

---

## 3. The `project_macro` Slot

Each student's design occupies a single **project slot** — a fixed-size physical
boundary called `project_macro`. All slots are identical in dimension
(**880 × 1031.66 µm**) and must connect to the surrounding infrastructure through a
fixed set of ports on each edge.

The instructor provides a **DEF template** for the slot. LibreLane uses this template
during floorplanning to stamp the correct boundary, I/O pin locations, and power ring
geometry into your design — exactly as the `project_macro.def` template was
used in Module 5 for Caravel.

```{admonition} Why a Fixed Footprint?
:class: note

Because all 12 project slots are placed at pre-determined coordinates inside the
multi-project chip, every `project_macro` must have exactly the same physical boundary
and pin positions. The DEF template enforces this. If your macro has a different size
or pin location, it will not connect to the surrounding orange and green macros when
the chip is assembled.
```

---

## 4. Workshop Repository & Template

Clone the workshop repository, which contains the pre-configured `project_macro`
template including the DEF file, SDC constraints, and configuration skeleton:

```console
$ git clone https://github.com/basemhesham/openframe_multiproject \
    ~/openframe_multiproject
```

Inside `openlane/project_macro/` you will find:

```text
openlane/project_macro/
├── config.json                    ← Hardening configuration (edit this)
├── fixed_dont_change/
│   └── project_macro.def          ← Fixed slot DEF template — do NOT edit
├── pnr.sdc                        ← PnR timing constraints
└── signoff.sdc                    ← Signoff timing constraints
```

The `fixed_dont_change/project_macro.def` file defines the slot boundary and pin
locations and must never be modified. LibreLane reads it at the floorplan step via
`FP_DEF_TEMPLATE` to ensure your macro fits precisely into the multi-project grid.

---

## 5. RTL — AES via SPI Inside `project_macro`

Unlike the Caravel flow in Module 5, this design does **not** use a Wishbone wrapper —
there is no management SoC to drive one. Instead, the AES core is controlled through a
lightweight **4-wire SPI interface** implemented directly inside `project_macro`.

The SPI controller uses only **3 bottom GPIO inputs and 1 bottom GPIO output**, leaving
33 GPIOs available for other uses.

| GPIO | Direction | Signal | Description |
| :--- | :--- | :--- | :--- |
| `gpio_bot_in[0]` | Input | `spi_sclk` | SPI clock from host |
| `gpio_bot_in[1]` | Input | `spi_cs_n` | Chip select, active low |
| `gpio_bot_in[2]` | Input | `spi_mosi` | Serial data in |
| `gpio_bot_out[0]` | Output | `spi_miso` | Serial data out (read results) |

The SPI frame is 42 bits wide — 1 R/nW bit, 8 address bits, and 32 data bits. The host
writes AES configuration registers (key, block, control) by asserting `cs_n` low and
clocking in a write frame. It reads back the encrypted result by sending a read frame to
the result registers (address `0x30`–`0x33`). The AES core signals readiness by setting
the `READY` bit in the status register (address `0x09`), which the host reads through
the same SPI interface.

Copy the provided RTL file into your project:

```console
$ gedit ~/openframe_multiproject/verilog/rtl/project_macro.v
```

````{dropdown} project_macro.v
```{literalinclude} ./code/openframe/project_macro.v
:language: verilog
```
````

---

## 6. Timing Constraints

Two SDC files are provided in the `project_macro` directory.

`pnr.sdc` is applied during all implementation steps (Placement, CTS, Routing). It
uses a strict 0.75 ns maximum transition to drive aggressive violation repair, and
models the clock latency through the green macro clock buffer and the GPIO input delays
through the orange mux macros.

`signoff.sdc` is applied **only** at the final signoff STA stage. It uses the relaxed
1.5 ns library characterisation limit and slightly less pessimistic timing derate,
reflecting a realistic assessment of the manufactured silicon's operating envelope. The
I/O delay values are taken directly from the OpenFrame base SDC, derived from physical
extraction of the actual orange macro and padframe routing.


---

## 7. Hardening Configuration

### Configuration Parameter Notes

#### `PDN_MULTILAYER: false` and `RT_MAX_LAYER: "met4"`

These two parameters work together and are both mandatory — they address the same
Metal 5 constraint from two complementary directions.

The OpenFrame multiproject wrapper uses **Metal 5 horizontal straps** for its top-level
power distribution. If your `project_macro` also places any geometry on Metal 5 — either
PDN straps or signal wires — it will collide with the wrapper's power grid, causing DRC
shorts that cannot be resolved after integration.

- **`PDN_MULTILAYER: false`** restricts the {term}`PDN` generator to vertical straps on
  Metal 4 only. Metal 5 is left completely clear. The wrapper's Metal 5 straps then
  connect down into the macro's Metal 4 straps through vias, forming the complete power
  delivery path.

- **`RT_MAX_LAYER: "met4"`** prevents the router from placing any signal wire on Metal 5.
  Even after Detailed Routing, the Metal 5 layer inside your macro boundary remains free
  for the wrapper's power grid.

```{warning}
Omitting either parameter will result in Metal 5 DRC violations when your `project_macro`
is placed inside the multi-project wrapper during chip assembly. The violations cannot
be fixed post-integration.
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
```

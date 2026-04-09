# Module 5: Caravel User Project Wrapper Integration

```{admonition} Prerequisites
:class: important

Before proceeding, ensure your `aes_wb_wrapper` has completed full physical signoff in
Module 4 and that the `classic_flow_eco` run tag exists and is complete. The
`copy_views.sh` script used later in this module will pull its inputs directly from
that run directory.
```

---

## Table of Contents

1. [What is the User Project Wrapper?](#what-is-the-user-project-wrapper)
2. [Integration Strategies Overview](#integration-strategies-overview)
3. [Strategy 1 — Macro-First Hardening](#strategy-1-macro-first-hardening)
   - [3.1 RTL — Instantiating the AES Macro](#rtl-instantiating-the-aes-macro)
   - [3.2 The DEF Template](#the-def-template)
   - [3.3 Macro Physical Views](#macro-physical-views)
   - [3.4 Macro Registration and Placement](#macro-registration-and-placement)
   - [3.5 Power Connections](#power-connections)
   - [3.6 Disabled Flow Steps](#disabled-flow-steps)
   - [3.7 Full Configuration Reference](#full-configuration-reference)
   - [3.8 Copying Macro Views](#copying-macro-views)
   - [3.9 Flow Execution](#flow-execution)
   - [3.10 Viewing the Layout](#viewing-the-layout)
   - [3.11 Checking the Reports](#checking-the-reports)
   - [3.12 Saving the Views](#saving-the-views)
4. [Strategy 2 — Top-Level Integration](#strategy-2-top-level-integration)
   - [4.1 Timing Constraints](#timing-constraints-top-level)
   - [4.2 Configuration](#configuration-top-level)
   - [4.3 Running the Flow](#running-the-flow-top-level)
   - [4.4 Post-PnR STA Results](#post-pnr-sta-results-top-level)
5. [Strategy 3 — Full-Wrapper Flattening](#strategy-3-full-wrapper-flattening)
   - [5.1 RTL Modification](#rtl-modification)
   - [5.2 Configuration](#configuration-flattening)

---

## 1. What is the User Project Wrapper?

The **User Project Wrapper** (`user_project_wrapper`) is the physical boundary between
your custom design and the **Caravel SoC** harness. Caravel provides the padframe,
the management SoC, and a standardised set of GPIO and Wishbone signals — the
`user_project_wrapper` is the slot where your design plugs in.

```{figure} ./figures/Caravel_SoC.png
:align: center

*Caravel SoC architecture — the User Project Wrapper occupies the central user area and
connects to the management SoC via the Wishbone bus and GPIO interface.*
```

Because Caravel is a fixed physical chip, it imposes strict requirements on the wrapper
that cannot be changed:

- The die area must be exactly **2920 × 3520 µm**.
- All I/O pins must appear at exact coordinate locations with exact metal shapes.
- The power rings must be generated with specific widths, spacings, and offsets to
  align with Caravel's top-level {term}`PDN`.

These constraints are encoded in the `fixed_dont_change/` directory of the project
template and must never be edited.

---

## 2. Integration Strategies Overview

There are three established approaches for placing your design inside the
`user_project_wrapper`. The right choice depends on design size, timing requirements,
and how much control you need over the top-level physical implementation.

::::{grid} 3

:::{grid-item-card} Strategy 1 — Macro-First Hardening
```{figure} ./figures/strategy_macro_first.png
:align: center
```
Harden the user IP as a standalone macro first, then drop it into the wrapper without
adding any top-level standard cells. The wrapper acts as a pass-through. Ideal for
small-to-medium designs — fastest runtime and simplest flow.
:::

:::{grid-item-card} Strategy 2 — Top-Level Integration
```{figure} ./figures/strategy_top_level.png
:align: center
```
Harden the macro first, then integrate it into the wrapper **with** top-level standard
cells enabled. The tool may insert buffers or repair logic at the boundary. A hybrid
approach useful when the macro has boundary violations that require top-level fixing.
:::

:::{grid-item-card} Strategy 3 — Full-Wrapper Flattening
```{figure} ./figures/strategy_flattening.png
:align: center
```
Merge all RTL — AES core, wrapper, and everything else — into one large flattened
design that covers the full ≈ 3mm × 3.6mm area. Maximum performance, but requires the
most PnR time and iteration. Best for designs that need the full wrapper area.
:::

::::

| | Strategy 1 | Strategy 2 | Strategy 3 |
| :--- | :---: | :---: | :---: |
| Macro pre-hardened separately | ✅ | ✅ | ❌ |
| Top-level standard cells | ❌ | ✅ | ✅ |
| CTS / repair at wrapper level | ❌ | ✅ | ✅ |
| Runtime | Fast | Medium | Slow |
| Best for | Small designs | Boundary issues | Full-area designs |

---

## 3. Strategy 1 — Macro-First Hardening

In this strategy, `aes_wb_wrapper` is treated as a pre-hardened black box. The wrapper
only connects its pins to the Caravel interface — no new logic is synthesised or
optimised at the top level, so most flow steps are disabled. This is the approach we
use in this workshop.

---

### 3.1 RTL — Instantiating the AES Macro

The RTL wrapper connects the Caravel Wishbone and GPIO signals to the `aes_wb_wrapper`
macro, instantiated as `mprj`. Open the file for editing:

```console
$ gedit ~/Silicon-Sprint-AUC/verilog/rtl/user_project_wrapper.v
```

````{dropdown} user_project_wrapper.v
```{literalinclude} ./code/user_project_wrapper.v
:language: verilog
:linenos:
```
````

The instance name `mprj` must match exactly in both the Verilog instantiation and the
`MACROS` configuration dictionary.

Create the wrapper configuration file:

```console
$ gedit ~/Silicon-Sprint-AUC/openlane/user_project_wrapper/config.json
```

Paste the following complete configuration:

```json
{
    "VERILOG_FILES": [
        "dir::../../verilog/rtl/defines.v",
        "dir::../../verilog/rtl/user_project_wrapper.v"
    ],
    "PNR_SDC_FILE": "dir::signoff.sdc",

    "SYNTH_ELABORATE_ONLY": true,
    "RUN_POST_GPL_DESIGN_REPAIR": false,
    "RUN_POST_CTS_RESIZER_TIMING": false,
    "DESIGN_REPAIR_BUFFER_INPUT_PORTS": false,
    "PDN_ENABLE_RAILS": false,
    "RUN_ANTENNA_REPAIR": false,
    "RUN_FILL_INSERTION": false,
    "RUN_TAP_ENDCAP_INSERTION": false,
    "RUN_CTS": false,
    "RUN_IRDROP_REPORT": false,

    "MACROS": {
        "aes_wb_wrapper": {
            "gds":  ["dir::../../gds/aes_wb_wrapper.gds"],
            "lef":  ["dir::../../lef/aes_wb_wrapper.lef"],
            "instances": {
                "mprj": {
                    "location": [10, 20],
                    "orientation": "N"
                }
            },
            "nl":   ["dir::../../verilog/gl/aes_wb_wrapper.v"],
            "spef": {
                "min_*": ["dir::../../spef/multicorner/aes_wb_wrapper.min.spef"],
                "nom_*": ["dir::../../spef/multicorner/aes_wb_wrapper.nom.spef"],
                "max_*": ["dir::../../spef/multicorner/aes_wb_wrapper.max.spef"]
            },
            "lib":  {"*": "dir::../../lib/aes_wb_wrapper.lib"}
        }
    },
    "PDN_MACRO_CONNECTIONS": ["mprj vccd2 vssd2 VPWR VGND"],

    "PDN_VOFFSET": 5,
    "PDN_HOFFSET": 5,
    "PDN_VWIDTH": 3.1,
    "PDN_HWIDTH": 3.1,
    "PDN_VSPACING": 15.5,
    "PDN_HSPACING": 15.5,
    "PDN_VPITCH": 180,
    "PDN_HPITCH": 180,
    "QUIT_ON_PDN_VIOLATIONS": false,
    "MAGIC_DRC_USE_GDS": true,
    "MAX_TRANSITION_CONSTRAINT": 1.5,

    "//": "Fixed configurations for Caravel — do NOT edit below this line",
    "DESIGN_NAME": "user_project_wrapper",
    "FP_SIZING": "absolute",
    "DIE_AREA": [0, 0, 2920, 3520],
    "FP_DEF_TEMPLATE": "dir::fixed_dont_change/user_project_wrapper.def",
    "VDD_NETS": ["vccd1", "vccd2", "vdda1", "vdda2"],
    "GND_NETS": ["vssd1", "vssd2", "vssa1", "vssa2"],
    "PDN_CORE_RING": 1,
    "PDN_CORE_RING_VWIDTH": 3.1,
    "PDN_CORE_RING_HWIDTH": 3.1,
    "PDN_CORE_RING_VOFFSET": 12.45,
    "PDN_CORE_RING_HOFFSET": 12.45,
    "PDN_CORE_RING_VSPACING": 1.7,
    "PDN_CORE_RING_HSPACING": 1.7,
    "CLOCK_PORT": "wb_clk_i",
    "SIGNOFF_SDC_FILE": "dir::signoff.sdc",
    "MAGIC_DEF_LABELS": 0,
    "CLOCK_PERIOD": 25,
    "MAGIC_ZEROIZE_ORIGIN": 0
}
```

---

### 3.2 The DEF Template

```json
"FP_DEF_TEMPLATE": "dir::fixed_dont_change/user_project_wrapper.def"
```

During floorplanning, LibreLane reads this pre-built DEF file and stamps its contents
directly into the OpenROAD database. It encodes three things that cannot be derived
from `config.json` parameters alone:

- **Exact pin geometry** — every I/O pin has the precise shape, layer, and coordinate
  that Caravel's management SoC and padframe expect.
- **Fixed power rings** — the outer VDD/GND rings are pre-drawn to connect to
  Caravel's top-level PDN during chip assembly.
- **Fixed core area** — the `2920 × 3520 µm` boundary matches the open user area in
  the fabricated chip exactly.

```{figure} ./figures/DEF_Templet.png
:align: center

*User Project Wrapper DEF template in KLayout — pre-placed I/O pins, power ring, and
die boundary. The open core area is where your macro is placed.*
```

```{warning}
This file must never be modified. Moving even a single pin by one manufacturing grid
step will cause fatal DRC violations during top-level chip assembly.
```

---

### 3.3 Macro Physical Views

LibreLane requires several physical view files to place, route, analyse, and verify the
macro inside the wrapper. The two **essential** views are:

**{term}`LEF` (`.lef`) — Essential for PnR**

The physical interface of the macro — boundary dimensions, pin locations on metal
layers, and routing obstructions. LibreLane uses the LEF to keep routing out of the
macro boundary and prevent shorts against its pins.

**{term}`GDSII` (`.gds`) — Essential for Tape-Out**

The complete physical layout including silicon implant and diffusion layers. Used during
GDS stream-out, DRC, and LVS.

The remaining views are optional but improve analysis quality:

| View | Extension | Role |
| :--- | :--- | :--- |
| Gate-Level Netlist | `.nl.v` | Used during {term}`STA` and as a fallback for linting. |
| Powered Netlist | `.pnl.v` | Same as above with power pins — preferred for LVS. |
| Liberty Model | `.lib` | Cell timing models for OpenSTA path analysis through the macro. |
| Parasitics | `.spef` | Per-corner RC extraction — enables accurate post-layout {term}`STA`. |

---

### 3.4 Macro Registration and Placement

Macros are registered in the `MACROS` dictionary. The `instances` sub-key maps the
RTL instance name to a physical placement:

```json
"instances": {
    "mprj": {
        "location": [10, 20],
        "orientation": "N"
    }
}
```

- **Instance name** — must match exactly as instantiated in `user_project_wrapper.v`.
- **Location** — `[10, 20]` places the macro near the bottom-left corner of the core
  area, minimising wire length to the Wishbone signals that enter the wrapper from
  that edge.
- **Orientation** — `N` (North, no rotation) keeps the macro's Wishbone pins aligned
  with the correct wrapper edge.

---

### 3.5 Power Connections

```json
"PDN_MACRO_CONNECTIONS": ["mprj vccd2 vssd2 VPWR VGND"]
```

| Field | Value | Meaning |
| :--- | :--- | :--- |
| Instance name | `mprj` | Matches the RTL instance name. Accepts regex for multi-instance designs. |
| VDD net | `vccd2` | The secondary digital power domain in Caravel's multi-supply architecture. |
| GND net | `vssd2` | The secondary digital ground. |
| VDD pin | `VPWR` | Physical power pin name on the macro (from its LEF). |
| GND pin | `VGND` | Physical ground pin name on the macro. |

---

### 3.6 Disabled Flow Steps

Because `aes_wb_wrapper` is pre-hardened and timing-closed, most optimisation steps
are disabled at the wrapper level to avoid modifying a physically finalised design.

| Parameter | Why Disabled |
| :--- | :--- |
| `SYNTH_ELABORATE_ONLY: true` | The wrapper contains only a macro instantiation — elaboration-only mode preserves hierarchy without technology mapping. |
| `RUN_CTS: false` | The macro has its own internal clock tree. No new CTS is needed at the wrapper level. |
| `RUN_POST_GPL_DESIGN_REPAIR: false` | Prevents the resizer from attempting to fix violations on an already finalised design. |
| `RUN_POST_CTS_RESIZER_TIMING: false` | No CTS is run, so post-CTS timing optimisation has nothing to act on. |
| `DESIGN_REPAIR_BUFFER_INPUT_PORTS: false` | Prevents buffer insertion at wrapper input ports, preserving direct connections to macro pins. |
| `PDN_ENABLE_RAILS: false` | Metal 1 standard cell rails are only needed where standard cells exist — the wrapper core is occupied by the macro. |
| `RUN_ANTENNA_REPAIR: false` | Antenna repair was already performed during Module 4 hardening. |
| `RUN_TAP_ENDCAP_INSERTION: false` | Tap cells support standard cell rows — not needed when the wrapper contains only a hardened macro. |
| `RUN_FILL_INSERTION: false` | Filler cells close gaps between standard cells. No standard cells means no gaps. |
| `RUN_IRDROP_REPORT: false` | IR drop analysis is performed at the full chip level; skipping it reduces runtime. |

---

### 3.7 Full Configuration Reference

| Variable | Type | Description | Default |
| :--- | :--- | :--- | :--- |
| `SYNTH_ELABORATE_ONLY` | `bool` | Elaborates hierarchy without technology mapping. | `False` |
| `MACROS` | `Dict[str, Macro]?` | Dictionary of macro physical views, instances, and timing models. | `None` |
| `PDN_MACRO_CONNECTIONS` | `List[str]?` | Explicit power connections. Format: `<instance> <vdd_net> <gnd_net> <vdd_pin> <gnd_pin>`. | `None` |
| `DESIGN_NAME` | `str` | Top-level module name. Must be `user_project_wrapper`. | `None` |
| `FP_SIZING` | `'absolute'` \| `'relative'` | `absolute` uses exact die coordinates. | `relative` |
| `DIE_AREA` | `Tuple?` | Fixed die boundary `"x0 y0 x1 y1"` µm. Must be `[0, 0, 2920, 3520]` for Caravel. | `None` |
| `FP_DEF_TEMPLATE` | `Path?` | Pre-built DEF with fixed I/O pins, power ring, and die boundary. | `None` |
| `VDD_NETS` | `List[str]?` | Power net names for PDN generation. | `None` |
| `GND_NETS` | `List[str]?` | Ground net names. | `None` |
| `PDN_CORE_RING` | `bool` | Generates a power ring around the core perimeter. | `False` |
| `PDN_CORE_RING_VWIDTH` | `Decimal` | Width of vertical ring segments (µm). | `None` |
| `PDN_CORE_RING_HWIDTH` | `Decimal` | Width of horizontal ring segments (µm). | `None` |
| `PDN_CORE_RING_VSPACING` | `Decimal` | Spacing between VDD/GND vertical ring straps (µm). | `None` |
| `PDN_CORE_RING_HSPACING` | `Decimal` | Spacing between VDD/GND horizontal ring straps (µm). | `None` |
| `PDN_CORE_RING_VOFFSET` | `Decimal` | Offset of vertical ring from core boundary (µm). | `None` |
| `PDN_CORE_RING_HOFFSET` | `Decimal` | Offset of horizontal ring from core boundary (µm). | `None` |
| `CLOCK_PORT` | `(str \| List[str])?` | Primary clock port. `wb_clk_i` is the Wishbone clock from the management SoC. | `None` |
| `MAGIC_ZEROIZE_ORIGIN` | `bool` | Moves layout origin to (0, 0) in Magic's LEF. Must be `0` for Caravel. | `False` |

---

### 3.8 Copying Macro Views

Before running the wrapper flow, copy all physical view files from the `aes_wb_wrapper`
hardening run into the shared project directories:

```console
$ bash ~/Silicon-Sprint-AUC/openlane/copy_views.sh \
    ~/Silicon-Sprint-AUC \
    aes_wb_wrapper \
    classic_flow_eco
```

The three arguments are: project root directory, macro name, and run tag. The script
copies `final/gds/` → `gds/`, `final/lef/` → `lef/`, `final/nl/` → `verilog/gl/`,
`final/spef/` → `spef/multicorner/`, and `final/lib/` → `lib/`.

```{note}
Verify that all five destination directories are populated before proceeding. A missing
file will cause a file-not-found error at the step that first needs that view.
```

---

### 3.9 Flow Execution

Enter the Nix shell:

```console
$ nix-shell --pure ~/librelane/shell.nix
```

Run the wrapper hardening:

```console
[nix-shell:~]$ librelane \
    ~/Silicon-Sprint-AUC/openlane/user_project_wrapper/config.json \
    --run-tag project_wrapper
```

When the flow completes successfully:

```text
 Antenna
Passed ✅
 LVS
Passed ✅
 DRC
Passed ✅
```

---

### 3.10 Viewing the Layout

```console
[nix-shell:~]$ librelane \
    --last-run \
    --flow openinklayout \
    ~/Silicon-Sprint-AUC/openlane/user_project_wrapper/config.json
```

```{figure} ./figures/user_project_layout.webp
:align: center

*User Project Wrapper layout — the `aes_wb_wrapper` macro at the bottom-left corner,
close to the Wishbone signal pins entering from that edge.*
```

Toggle layer visibility to `prBoundary.boundary`, `met1.drawing`, `met2.drawing`, and
`met3.drawing` to inspect the internal macro routing.

```{figure} ./figures/mprj-gds.webp
:align: center

*AES macro internal view — the absence of long routes confirms that all internal
routing was completed cleanly during Module 4.*
```

---

### 3.11 Checking the Reports

#### Antenna Check (`OpenROAD.CheckAntennas`)

**Location:** `runs/project_wrapper/XX-openroad-checkantennas/`

```text
┏━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━┳━━━━━┳━━━━━┳━━━━━━━┓
┃ Partial/Required ┃ Required ┃ Partial ┃ Net ┃ Pin ┃ Layer ┃
┡━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━╇━━━━━╇━━━━━╇━━━━━━━┩
└──────────────────┴──────────┴─────────┴─────┴─────┴───────┘
```

#### Post-PnR STA (`OpenROAD.STAPostPNR`)

**Location:** `runs/project_wrapper/XX-openroad-stapostpnr/summary.rpt`

```text
┏━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━┓
┃                      ┃ Hold     ┃ Reg to   ┃          ┃          ┃ of which  ┃ Setup    ┃           ┃          ┃           ┃ of which ┃           ┃          ┃
┃                      ┃ Worst    ┃ Reg      ┃          ┃ Hold Vio ┃ reg to    ┃ Worst    ┃ Reg to    ┃ Setup    ┃ Setup Vio ┃ reg to   ┃ Max Cap   ┃ Max Slew ┃
┃ Corner/Group         ┃ Slack    ┃ Paths    ┃ Hold TNS ┃ Count    ┃ reg       ┃ Slack    ┃ Reg Paths ┃ TNS      ┃ Count     ┃ reg      ┃ Violatio… ┃ Violati… ┃
┡━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━┩
│ Overall              │ 0.0047   │ 0.0047   │ 0.0000   │ 0        │ 0         │ 2.1041   │ 2.1041    │ 0.0000   │ 0         │ 0        │ 1         │ 2        │
│ nom_tt_025C_1v80     │ 0.1483   │ 0.1483   │ 0.0000   │ 0        │ 0         │ 7.9981   │ 13.3840   │ 0.0000   │ 0         │ 0        │ 0         │ 0        │
│ nom_ss_100C_1v60     │ 0.5562   │ 0.5562   │ 0.0000   │ 0        │ 0         │ 2.5763   │ 2.5763    │ 0.0000   │ 0         │ 0        │ 0         │ 0        │
│ nom_ff_n40C_1v95     │ 0.0053   │ 0.0053   │ 0.0000   │ 0        │ 0         │ 9.1132   │ 17.4716   │ 0.0000   │ 0         │ 0        │ 0         │ 0        │
│ min_tt_025C_1v80     │ 0.1474   │ 0.1474   │ 0.0000   │ 0        │ 0         │ 8.1437   │ 13.6547   │ 0.0000   │ 0         │ 0        │ 0         │ 0        │
│ min_ss_100C_1v60     │ 0.5545   │ 0.5545   │ 0.0000   │ 0        │ 0         │ 3.0678   │ 3.0678    │ 0.0000   │ 0         │ 0        │ 0         │ 0        │
│ min_ff_n40C_1v95     │ 0.0047   │ 0.0047   │ 0.0000   │ 0        │ 0         │ 9.2076   │ 17.7111   │ 0.0000   │ 0         │ 0        │ 0         │ 0        │
│ max_tt_025C_1v80     │ 0.1491   │ 0.1491   │ 0.0000   │ 0        │ 0         │ 7.8819   │ 13.1149   │ 0.0000   │ 0         │ 0        │ 0         │ 0        │
│ max_ss_100C_1v60     │ 0.5582   │ 0.5582   │ 0.0000   │ 0        │ 0         │ 2.1041   │ 2.1041    │ 0.0000   │ 0         │ 0        │ 1         │ 2        │
│ max_ff_n40C_1v95     │ 0.0059   │ 0.0059   │ 0.0000   │ 0        │ 0         │ 9.0334   │ 17.2358   │ 0.0000   │ 0         │ 0        │ 0         │ 0        │
└──────────────────────┴──────────┴──────────┴──────────┴──────────┴───────────┴──────────┴───────────┴──────────┴───────────┴──────────┴───────────┴──────────┘
```

```{admonition} Interpreting the Results
:class: tip

**Hold and Setup:** zero violations across all 9 corners. The macro's pre-hardened
timing is correctly preserved at the wrapper level.

**Max Slew (2) and Max Cap (1) in `max_ss_100C_1v60`:** inherited from the
`aes_wb_wrapper` interface pins — not resolvable at the wrapper level in this strategy.
They do not affect functional correctness.
```

#### DRC and LVS

**Magic DRC** — `runs/project_wrapper/XX-magic-drc/reports/drc.rpt`:
```text
aes_wb_wrapper
----------------------------------------
[INFO] COUNT: 0
[INFO] Should be divided by 3 or 4
```

**KLayout DRC** — `runs/project_wrapper/XX-klayout-drc/violations.json`:
```json
{ "total": 0 }
```

**LVS** — `runs/project_wrapper/XX-netgen-lvs/reports/lvs.rpt`:
```text
Cell pin lists are equivalent.
Device classes user_project_wrapper and user_project_wrapper are equivalent.
Final result: Circuits match uniquely.
```

---

### 3.12 Saving the Views

```console
$ bash ~/Silicon-Sprint-AUC/openlane/copy_views.sh \
    ~/Silicon-Sprint-AUC \
    user_project_wrapper \
    project_wrapper
```

```{admonition} Congratulations — Strategy 1 Complete!
:class: tip

The `user_project_wrapper.gds` produced by this run is ready for integration into the
Caravel harness.
```

---

## 4. Strategy 2 — Top-Level Integration

In the top-level integration methodology, `aes_wb_wrapper` is still hardened as a
separate macro, but the wrapper is now allowed to place **additional standard cells**
at the top level alongside it. The tool performs full CTS, placement repair, and
buffering on the wrapper-level logic, closing any boundary timing violations that the
macro-first strategy cannot address.

The key differences from Strategy 1 are that all optimisation steps are **enabled**, and
the macro is placed away from the corner (`[100, 100]` instead of `[10, 20]`) to leave
room for the tool to insert routing, well taps, and buffers at the boundary without
creating congestion.

```{warning}
Do not use `"location": [10, 20]` with this strategy. Placing the macro at the extreme
corner leaves no routing headroom for the top-level standard cells, tap cells, and
input port buffers the tool inserts, causing routing overflow.
```

---

### 4.1 Timing Constraints (Top-Level)

Both SDC files are used with Strategy 2 — the same files used in Strategy 1. The PnR
file over-constrains during implementation; the signoff file applies realistic values
for the final timing check.

````{dropdown} signoff.sdc
```{literalinclude} ./code/signoff.sdc
:language: tcl
```
````

````{dropdown} pnr.sdc
```{literalinclude} ./code/pnr.sdc
:language: tcl
```
````

---

### 4.2 Configuration (Top-Level)

The key change from Strategy 1 is that all disabled flags are now set to `true`, and
`SYNTH_ELABORATE_ONLY` is set to `false`:

```json
{
    "QUIT_ON_SYNTH_CHECKS": false,

    "VERILOG_FILES": [
        "dir::../../verilog/rtl/defines.v",
        "dir::../../verilog/rtl/user_project_wrapper.v"
    ],
    "PNR_SDC_FILE": "dir::pnr.sdc",

    "SYNTH_ELABORATE_ONLY": false,
    "RUN_POST_GPL_DESIGN_REPAIR": true,
    "RUN_POST_CTS_RESIZER_TIMING": true,
    "DESIGN_REPAIR_BUFFER_INPUT_PORTS": true,
    "PDN_ENABLE_RAILS": true,
    "RUN_ANTENNA_REPAIR": true,
    "RUN_FILL_INSERTION": true,
    "RUN_TAP_ENDCAP_INSERTION": true,
    "RUN_CTS": true,
    "RUN_IRDROP_REPORT": false,

    "MACROS": {
        "aes_wb_wrapper": {
            "gds":  ["dir::../../gds/aes_wb_wrapper.gds"],
            "lef":  ["dir::../../lef/aes_wb_wrapper.lef"],
            "instances": {
                "mprj": {
                    "location": [100, 100],
                    "orientation": "N"
                }
            },
            "nl":   ["dir::../../verilog/gl/aes_wb_wrapper.v"],
            "spef": {
                "min_*": ["dir::../../spef/multicorner/aes_wb_wrapper.min.spef"],
                "nom_*": ["dir::../../spef/multicorner/aes_wb_wrapper.nom.spef"],
                "max_*": ["dir::../../spef/multicorner/aes_wb_wrapper.max.spef"]
            },
            "lib":  {"*": "dir::../../lib/aes_wb_wrapper.lib"}
        }
    },
    "PDN_MACRO_CONNECTIONS": ["mprj vccd2 vssd2 VPWR VGND"],

    "PDN_VOFFSET": 5,
    "PDN_HOFFSET": 5,
    "PDN_VWIDTH": 3.1,
    "PDN_HWIDTH": 3.1,
    "PDN_VSPACING": 15.5,
    "PDN_HSPACING": 15.5,
    "PDN_VPITCH": 180,
    "PDN_HPITCH": 180,
    "QUIT_ON_PDN_VIOLATIONS": false,
    "MAGIC_DRC_USE_GDS": true,
    "MAX_TRANSITION_CONSTRAINT": 1.5,

    "//": "Fixed configurations for Caravel — do NOT edit below this line",
    "DESIGN_NAME": "user_project_wrapper",
    "FP_SIZING": "absolute",
    "DIE_AREA": [0, 0, 2920, 3520],
    "FP_DEF_TEMPLATE": "dir::fixed_dont_change/user_project_wrapper.def",
    "VDD_NETS": ["vccd1", "vccd2", "vdda1", "vdda2"],
    "GND_NETS": ["vssd1", "vssd2", "vssa1", "vssa2"],
    "PDN_CORE_RING": 1,
    "PDN_CORE_RING_VWIDTH": 3.1,
    "PDN_CORE_RING_HWIDTH": 3.1,
    "PDN_CORE_RING_VOFFSET": 12.45,
    "PDN_CORE_RING_HOFFSET": 12.45,
    "PDN_CORE_RING_VSPACING": 1.7,
    "PDN_CORE_RING_HSPACING": 1.7,
    "CLOCK_PORT": "wb_clk_i",
    "SIGNOFF_SDC_FILE": "dir::signoff.sdc",
    "MAGIC_DEF_LABELS": 0,
    "CLOCK_PERIOD": 25,
    "MAGIC_ZEROIZE_ORIGIN": 0
}
```

The table below summarises the key behavioural difference between the two strategies:

| Parameter | Strategy 1 (Macro-First) | Strategy 2 (Top-Level) | Reason |
| :--- | :---: | :---: | :--- |
| `SYNTH_ELABORATE_ONLY` | `true` | `false` | Strategy 2 synthesises top-level glue logic. |
| `RUN_CTS` | `false` | `true` | A new clock tree is built for the top-level standard cells. |
| `RUN_POST_GPL_DESIGN_REPAIR` | `false` | `true` | The resizer fixes violations on the new top-level cells. |
| `PDN_ENABLE_RAILS` | `false` | `true` | Metal 1 rails are needed for the top-level standard cell rows. |
| `RUN_TAP_ENDCAP_INSERTION` | `false` | `true` | Tap cells bias the N-well of the new standard cell rows. |
| `RUN_FILL_INSERTION` | `false` | `true` | Filler cells close gaps in the standard cell rows. |
| Macro location | `[10, 20]` | `[100, 100]` | Margin required for top-level cells and routing. |

---

### 4.3 Running the Flow (Top-Level)

```console
[nix-shell:~]$ librelane \
    ~/Silicon-Sprint-AUC/openlane/user_project_wrapper/config.json \
    --run-tag top_level
```

```{note}
If the flow crashes during the parasitic extraction (`OpenROAD.RCX`) step, add the
following line to `config.json` and re-run. This forces single-threaded STA — slower
but reliable when multi-thread STA causes memory or scheduling failures:

```json
"STA_THREADS": 1
```
```

---

### 4.4 Post-PnR STA Results (Top-Level)

**Location:** `runs/top_level/XX-openroad-stapostpnr/summary.rpt`

```text
┏━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━┓
┃                      ┃ Hold     ┃ Reg to   ┃          ┃          ┃ of which  ┃ Setup    ┃           ┃          ┃           ┃ of which ┃           ┃          ┃
┃                      ┃ Worst    ┃ Reg      ┃          ┃ Hold Vio ┃ reg to    ┃ Worst    ┃ Reg to    ┃ Setup    ┃ Setup Vio ┃ reg to   ┃ Max Cap   ┃ Max Slew ┃
┃ Corner/Group         ┃ Slack    ┃ Paths    ┃ Hold TNS ┃ Count    ┃ reg       ┃ Slack    ┃ Reg Paths ┃ TNS      ┃ Count     ┃ reg      ┃ Violatio… ┃ Violati… ┃
┡━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━┩
│ Overall              │ 0.0047   │ 0.0047   │ 0.0000   │ 0        │ 0         │ 2.1041   │ 2.1041    │ 0.0000   │ 0         │ 0        │ 1         │ 2        │
│ nom_tt_025C_1v80     │ 0.1483   │ 0.1483   │ 0.0000   │ 0        │ 0         │ 7.9981   │ 13.3840   │ 0.0000   │ 0         │ 0        │ 0         │ 0        │
│ nom_ss_100C_1v60     │ 0.5562   │ 0.5562   │ 0.0000   │ 0        │ 0         │ 2.5763   │ 2.5763    │ 0.0000   │ 0         │ 0        │ 0         │ 0        │
│ nom_ff_n40C_1v95     │ 0.0053   │ 0.0053   │ 0.0000   │ 0        │ 0         │ 9.1132   │ 17.4716   │ 0.0000   │ 0         │ 0        │ 0         │ 0        │
│ min_tt_025C_1v80     │ 0.1474   │ 0.1474   │ 0.0000   │ 0        │ 0         │ 8.1437   │ 13.6547   │ 0.0000   │ 0         │ 0        │ 0         │ 0        │
│ min_ss_100C_1v60     │ 0.5545   │ 0.5545   │ 0.0000   │ 0        │ 0         │ 3.0678   │ 3.0678    │ 0.0000   │ 0         │ 0        │ 0         │ 0        │
│ min_ff_n40C_1v95     │ 0.0047   │ 0.0047   │ 0.0000   │ 0        │ 0         │ 9.2076   │ 17.7111   │ 0.0000   │ 0         │ 0        │ 0         │ 0        │
│ max_tt_025C_1v80     │ 0.1491   │ 0.1491   │ 0.0000   │ 0        │ 0         │ 7.8819   │ 13.1149   │ 0.0000   │ 0         │ 0        │ 0         │ 0        │
│ max_ss_100C_1v60     │ 0.5582   │ 0.5582   │ 0.0000   │ 0        │ 0         │ 2.1041   │ 2.1041    │ 0.0000   │ 0         │ 0        │ 1         │ 2        │
│ max_ff_n40C_1v95     │ 0.0059   │ 0.0059   │ 0.0000   │ 0        │ 0         │ 9.0334   │ 17.2358   │ 0.0000   │ 0         │ 0        │ 0         │ 0        │
└──────────────────────┴──────────┴──────────┴──────────┴──────────┴───────────┴──────────┴───────────┴──────────┴───────────┴──────────┴───────────┴──────────┘
```

To open the final layout:

```console
[nix-shell:~]$ librelane \
    --last-run \
    --flow openinklayout \
    ~/Silicon-Sprint-AUC/openlane/user_project_wrapper/config.json
```

---

## 5. Strategy 3 — Full-Wrapper Flattening

In this strategy, the `user_project_wrapper` is hardened with all AES RTL included
directly — no pre-hardened macro. Yosys synthesises the entire design as one flat
netlist and the router covers the full ≈ 3 mm × 3.6 mm area. This produces the best
possible timing but requires the most PnR time and iteration.

---

### 5.1 RTL Modification

Because this strategy performs full synthesis, Yosys flags undriven top-level output
ports as errors. To prevent approximately 207 synthesis errors, add the following
tie-off assignments to `user_project_wrapper.v`:

```verilog
// Required for Full-Wrapper Flattening — tie off unused top-level outputs
assign io_out      = {`MPRJ_IO_PADS{1'b0}};
assign io_oeb      = {`MPRJ_IO_PADS{1'b0}};
assign la_data_out = 128'b0;
assign user_irq    = 3'b0;
```

```{warning}
These tie-off assignments are **only** for Strategies 2 and 3. Including them in a
Strategy 1 (Macro-First) run will cause Stage 9 checker errors and terminate the flow.
```

---

### 5.2 Configuration (Flattening)

The `MACROS` section is removed entirely. All AES RTL source files are added directly
to `VERILOG_FILES`. All optimisation flags are `true` (which is the LibreLane Classic
flow default — they do not need to be explicitly written in `config.json`).

```json
{
    "VERILOG_FILES": [
        "dir::../../../secworks_aes/src/rtl/*.v",
        "dir::../../verilog/rtl/aes_wb_wrapper.v",
        "dir::../../verilog/rtl/defines.v",
        "dir::../../verilog/rtl/user_project_wrapper.v"
    ],
    "PNR_SDC_FILE": "dir::pnr.sdc",

    "SYNTH_ELABORATE_ONLY": false,
    "RUN_POST_GPL_DESIGN_REPAIR": true,
    "RUN_POST_CTS_RESIZER_TIMING": true,
    "DESIGN_REPAIR_BUFFER_INPUT_PORTS": true,
    "PDN_ENABLE_RAILS": true,
    "RUN_ANTENNA_REPAIR": true,
    "RUN_FILL_INSERTION": true,
    "RUN_TAP_ENDCAP_INSERTION": true,
    "RUN_CTS": true,
    "RUN_IRDROP_REPORT": true,
    "VSRC_LOC_FILES": {
        "vccd1": "dir::vsrc/upw_vccd1_vsrc.loc",
        "vssd1": "dir::vsrc/upw_vssd1_vsrc.loc"
    },

    "PDN_VOFFSET": 5,
    "PDN_HOFFSET": 5,
    "PDN_VWIDTH": 3.1,
    "PDN_HWIDTH": 3.1,
    "PDN_VSPACING": 15.5,
    "PDN_HSPACING": 15.5,
    "PDN_VPITCH": 180,
    "PDN_HPITCH": 180,
    "ERROR_ON_PDN_VIOLATIONS": false,
    "MAGIC_DRC_USE_GDS": true,
    "MAX_TRANSITION_CONSTRAINT": 1.5,
    "DEFAULT_CORNER": "max_tt_025C_1v80",
    "RUN_POST_GRT_DESIGN_REPAIR": true,
    "RUN_POST_GRT_RESIZER_TIMING": true,

    "//": "Fixed configurations for Caravel — do NOT edit below this line",
    "DESIGN_NAME": "user_project_wrapper",
    "FP_SIZING": "absolute",
    "DIE_AREA": [0, 0, 2920, 3520],
    "FP_DEF_TEMPLATE": "dir::fixed_dont_change/user_project_wrapper.def",
    "VDD_NETS": ["vccd1", "vccd2", "vdda1", "vdda2"],
    "GND_NETS": ["vssd1", "vssd2", "vssa1", "vssa2"],
    "PDN_CORE_RING": 1,
    "PDN_CORE_RING_VWIDTH": 3.1,
    "PDN_CORE_RING_HWIDTH": 3.1,
    "PDN_CORE_RING_VOFFSET": 12.45,
    "PDN_CORE_RING_HOFFSET": 12.45,
    "PDN_CORE_RING_VSPACING": 1.7,
    "PDN_CORE_RING_HSPACING": 1.7,
    "CLOCK_PORT": "wb_clk_i",
    "SIGNOFF_SDC_FILE": "dir::signoff.sdc",
    "MAGIC_DEF_LABELS": 0,
    "CLOCK_PERIOD": 25,
    "MAGIC_ZEROIZE_ORIGIN": 0
}
```

```{note}
The `VSRC_LOC_FILES` parameter specifies voltage source locations for IR drop analysis.
This is especially important in the flattening strategy because the full design spans
the entire wrapper area and IR drop hotspots are more likely to occur at points far
from the power ring. The `.loc` files define where the {term}`PDN` voltage sources are
injected for the `OpenROAD.IRDropReport` simulation.
```

---

```{glossary}
PDN
  Power Distribution Network. The network of metal conductors delivering VDD and GND to every cell in the chip.

DRC
  Design Rule Check. Verification that the layout conforms to the foundry's manufacturing constraints.

LVS
  Layout vs. Schematic. Verification that the physical layout is electrically equivalent to the design netlist.

LEF
  Library Exchange Format. A file describing the physical interface of a macro — boundary, pin locations, and blockages.

SPEF
  Standard Parasitic Exchange Format. A text-based map of the resistance and capacitance of every net.

STA
  Static Timing Analysis. Exhaustive path-by-path timing verification against declared constraints.

GDSII
  Graphic Database System II. The standard binary layout format delivered to the foundry for fabrication.

SDC
  Synopsys Design Constraints. Tcl-based timing and clocking constraints.

WNS
  Worst Negative Slack. The largest magnitude of negative slack across all failing timing paths.
```

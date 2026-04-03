# Module 5: User Project Wrapper Hardening

```{admonition} Prerequisites
:class: important

Before proceeding, ensure your `aes_wb_wrapper` has completed full physical signoff in
Module 4 and that the `classic_flow_eco` run tag exists and is complete. The
`copy_views.sh` script used in [Section 4.1](#copying-macro-views) will pull its inputs
directly from that run directory.
```

---

## Table of Contents

1. [What is the User Project Wrapper?](#what-is-the-user-project-wrapper)
2. [RTL — Instantiating the AES Macro](#rtl-instantiating-the-aes-macro)
3. [Hardening Configuration](#hardening-configuration)
   - [3.1 The DEF Template](#the-def-template)
   - [3.2 Macro Physical Views](#macro-physical-views)
   - [3.3 Macro Registration and Placement](#macro-registration-and-placement)
   - [3.4 Power Connections](#power-connections)
   - [3.5 Disabled Flow Steps](#disabled-flow-steps)
   - [3.6 Full Configuration Reference](#full-configuration-reference)
4. [Running the Wrapper Flow](#running-the-wrapper-flow)
   - [4.1 Copying Macro Views](#copying-macro-views)
   - [4.2 Flow Execution](#flow-execution)
5. [Viewing the Layout](#viewing-the-layout)
6. [Checking the Reports](#checking-the-reports)
   - [6.1 Antenna Check](#antenna-check-openroadcheckantennas)
   - [6.2 Post-PnR STA](#post-pnr-sta-openroadstapostpnr)
   - [6.3 DRC — Magic and KLayout](#drc-magic-and-klayout)
   - [6.4 LVS](#lvs-netgenlvs)
7. [Saving the Views](#saving-the-views)

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

## 2. RTL — Instantiating the AES Macro

The RTL wrapper connects the Caravel-provided Wishbone and GPIO signals to the
`aes_wb_wrapper` macro, instantiated as `mprj`. Copy the file into your project:

```console
$ cp user_project_wrapper.v ~/Silicon-Sprint-AUC/verilog/rtl/user_project_wrapper.v
```

````{dropdown} user_project_wrapper.v
```{literalinclude} ./code/user_project_wrapper.v
:language: verilog
:linenos:
```
````

The instance name `mprj` is important — it must match exactly in both the Verilog
instantiation and the `MACROS` configuration dictionary.

---

## 3. Hardening Configuration

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

### 3.1 The DEF Template

```json
"FP_DEF_TEMPLATE": "dir::fixed_dont_change/user_project_wrapper.def"
```

During floorplanning, LibreLane reads this pre-built DEF file and stamps its contents
directly into the OpenROAD database before any macro placement or routing occurs.
It encodes three things that cannot be derived from `config.json` parameters alone:

- **Exact pin geometry** — every I/O pin has the precise shape, layer, and coordinate
  that Caravel's management SoC and padframe expect.
- **Fixed power rings** — the outer VDD/GND rings are pre-drawn to connect to
  Caravel's top-level PDN during chip assembly.
- **Fixed core area** — the `2920 × 3520 µm` boundary matches the open user area
  in the fabricated chip exactly.

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

### 3.2 Macro Physical Views

When a macro is placed inside a wrapper, LibreLane needs several physical view files
to perform placement, routing, timing analysis, and verification. These files are
produced by the macro's hardening run in Module 4.

The two **essential** views are:

**{term}`LEF` (`.lef`) — Essential for PnR**

The physical "interface" of the macro. It describes the macro's boundary dimensions,
pin locations on the metal layers, and any routing obstructions. LibreLane uses the LEF
to ensure routing at the wrapper level does not enter the macro boundary or short
against its pins.

**{term}`GDSII` (`.gds`) — Essential for Tape-Out**

The complete physical layout. Unlike the LEF, it contains not just the metal layers
but also the silicon implant layers, diffusion regions, and all other geometry needed
by the foundry for fabrication. Used during GDS stream-out and DRC/LVS.

The remaining views are optional but improve analysis quality:

| View | Extension | Role |
| :--- | :--- | :--- |
| Gate-Level Netlist | `.nl.v` | Used during {term}`STA` and as a fallback for linting and synthesis. |
| Powered Netlist | `.pnl.v` | Same as above, but with power pins — preferred for LVS. |
| Liberty Model | `.lib` | Provides cell timing models for OpenSTA path analysis through the macro boundary. |
| Parasitics | `.spef` | Per-corner RC extraction — enables accurate post-layout {term}`STA` through the macro. |

```{note}
The `copy_views.sh` script in [Section 4.1](#copying-macro-views) automates copying
all of these files from the macro's `final/` directory to the shared project folders
expected by the `MACROS` paths in `config.json`.
```

---

### 3.3 Macro Registration and Placement

Macros are registered in the `MACROS` dictionary. Each entry maps the macro module name
to its complete set of physical views. The `instances` sub-key maps the RTL instance
name to a physical placement:

```json
"instances": {
    "mprj": {
        "location": [10, 20],
        "orientation": "N"
    }
}
```

- **Instance name** — must match the name as instantiated in `user_project_wrapper.v`
  exactly. LibreLane uses this to correlate the physical placement with the logical
  hierarchy.
- **Location** — coordinates in µm from the core origin `(0, 0)`. We place the macro
  at `[10, 20]` — near the bottom-left corner of the core area — to minimise wire
  length to the Wishbone signals, which enter the wrapper from that edge.
- **Orientation** — `N` (North / no rotation) keeps the macro's Wishbone pins facing
  the correct edge.

---

### 3.4 Power Connections

```json
"PDN_MACRO_CONNECTIONS": ["mprj vccd2 vssd2 VPWR VGND"]
```

This variable explicitly connects the macro's internal power pins to the wrapper's
supply domain. Each entry follows the format:

```text
<instance_name> <vdd_net> <gnd_net> <vdd_pin> <gnd_pin>
```

| Field | Value | Meaning |
| :--- | :--- | :--- |
| Instance name | `mprj` | Must match the RTL instance name. Accepts regex patterns for multi-instance designs. |
| VDD net | `vccd2` | The digital power net in the wrapper to which the macro's supply is connected. |
| GND net | `vssd2` | The digital ground net in the wrapper. |
| VDD pin | `VPWR` | The physical name of the power pin on the macro (as declared in its LEF). |
| GND pin | `VGND` | The physical name of the ground pin on the macro. |

`vccd2` and `vssd2` are the secondary digital power domain in Caravel's multi-supply
architecture, reserved for user project logic.

---

### 3.5 Disabled Flow Steps

Because the `aes_wb_wrapper` is already fully hardened and timing-closed, many standard
optimisation and insertion steps are disabled at the wrapper level. Running them would
either have no effect (no standard cells to optimise) or risk modifying an already
verified design.

| Parameter | Why Disabled |
| :--- | :--- |
| `SYNTH_ELABORATE_ONLY: true` | The wrapper contains only a macro instantiation — there is no combinational logic to synthesise. Elaboration-only mode preserves the hierarchy without technology mapping. |
| `RUN_CTS: false` | The macro has its own internal clock tree from Module 4. No new clock tree is needed at the wrapper level. |
| `RUN_POST_GPL_DESIGN_REPAIR: false` | Prevents the resizer from attempting to fix electrical violations on a design that is already physically finalised. |
| `RUN_POST_CTS_RESIZER_TIMING: false` | No CTS is run, so post-CTS timing optimisation has nothing to act on. |
| `DESIGN_REPAIR_BUFFER_INPUT_PORTS: false` | Prevents the tool from inserting buffers at wrapper input ports, preserving direct connections to the macro pins. |
| `PDN_ENABLE_RAILS: false` | Standard cell power rails (Metal 1) are only needed where standard cells exist. The wrapper core is occupied by the macro. |
| `RUN_ANTENNA_REPAIR: false` | Antenna repair was performed during the macro's standalone hardening in Module 4. Re-running at the wrapper level is redundant if the paths are already protected. |
| `RUN_TAP_ENDCAP_INSERTION: false` | Tap and endcap cells support standard cell rows. A wrapper containing only a hardened macro has no rows to support. |
| `RUN_FILL_INSERTION: false` | Filler cells close gaps between standard cells. With no standard cells in the wrapper core, there are no gaps to fill. |
| `RUN_IRDROP_REPORT: false` | IR drop analysis is performed at the full chip level. Skipping it here reduces runtime. |

---

### 3.6 Full Configuration Reference

| Variable | Type | Description | Default |
| :--- | :--- | :--- | :--- |
| `SYNTH_ELABORATE_ONLY` | `bool` | Elaborates the design without technology mapping — correct for a wrapper that contains only macro instantiations. | `False` |
| `MACROS` | `Dict[str, Macro]?` | Dictionary mapping each macro's name to its physical views, instance placements, and timing models. | `None` |
| `PDN_MACRO_CONNECTIONS` | `List[str]?` | Explicit power connections. Format: `<instance> <vdd_net> <gnd_net> <vdd_pin> <gnd_pin>`. | `None` |
| `DESIGN_NAME` | `str` | Top-level module name. Must be `user_project_wrapper` for Caravel. | `None` |
| `FP_SIZING` | `'absolute'` \| `'relative'` | `absolute` uses exact die coordinates. | `relative` |
| `DIE_AREA` | `Tuple?` | Fixed die boundary `"x0 y0 x1 y1"` µm. Must be `[0, 0, 2920, 3520]` for Caravel. | `None` |
| `FP_DEF_TEMPLATE` | `Path?` | Pre-built DEF with fixed I/O pin shapes, power ring, and die boundary. | `None` |
| `VDD_NETS` | `List[str]?` | Power net names for PDN generation. Caravel uses four supply domains. | `None` |
| `GND_NETS` | `List[str]?` | Ground net names. | `None` |
| `PDN_CORE_RING` | `bool` | Generates a power ring around the core perimeter. | `False` |
| `PDN_CORE_RING_VWIDTH` | `Decimal` | Width of vertical ring segments (µm). | `None` |
| `PDN_CORE_RING_HWIDTH` | `Decimal` | Width of horizontal ring segments (µm). | `None` |
| `PDN_CORE_RING_VSPACING` | `Decimal` | Spacing between VDD/GND vertical ring straps (µm). | `None` |
| `PDN_CORE_RING_HSPACING` | `Decimal` | Spacing between VDD/GND horizontal ring straps (µm). | `None` |
| `PDN_CORE_RING_VOFFSET` | `Decimal` | Offset of vertical ring from core boundary (µm). | `None` |
| `PDN_CORE_RING_HOFFSET` | `Decimal` | Offset of horizontal ring from core boundary (µm). | `None` |
| `CLOCK_PORT` | `(str \| List[str])?` | Primary clock port. `wb_clk_i` is the Wishbone clock from the Caravel management SoC. | `None` |
| `MAGIC_ZEROIZE_ORIGIN` | `bool` | Moves the layout origin to (0, 0) in Magic's LEF output. Must be `0` for Caravel — coordinates are absolute. | `False` |

---

## 4. Running the Wrapper Flow

### 4.1 Copying Macro Views

Before running the wrapper flow, all physical view files from the `aes_wb_wrapper`
hardening run must be copied into the shared project directories that the `MACROS`
paths in `config.json` point to. The `copy_views.sh` script automates this:

```console
$ bash ~/Silicon-Sprint-AUC/openlane/copy_views.sh \
    ~/Silicon-Sprint-AUC \
    aes_wb_wrapper \
    classic_flow_eco
```

The three arguments are, in order: the project root directory, the macro name, and
the run tag of the completed signoff run. The script copies:

- `final/gds/` → `gds/`
- `final/lef/` → `lef/`
- `final/nl/` → `verilog/gl/`
- `final/spef/` → `spef/multicorner/`
- `final/lib/` → `lib/`

```{note}
Verify that all five destination directories are populated before proceeding. If any
file is missing, the wrapper flow will fail with a file-not-found error at the step
that first needs that view.
```

---

### 4.2 Flow Execution

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

## 5. Viewing the Layout

Open the final {term}`GDSII` layout in KLayout:

```console
[nix-shell:~]$ librelane \
    --last-run \
    --flow openinklayout \
    ~/Silicon-Sprint-AUC/openlane/user_project_wrapper/config.json
```

```{figure} ./figures/user_project_layout.webp
:align: center

*User Project Wrapper layout — the `aes_wb_wrapper` macro is placed at the bottom-left
corner, close to the Wishbone signal pins entering from that edge.*
```

To inspect the internal routing of the macro, toggle the layer visibility in KLayout
to show only `prBoundary.boundary`, `met1.drawing`, `met2.drawing`, and `met3.drawing`.

```{figure} ./figures/mprj-gds.webp
:align: center

*AES macro internal view — with only lower metal layers visible, the absence of long
routes confirms that all internal routing was completed cleanly during Module 4.*
```

---

## 6. Checking the Reports

---

### 6.1 Antenna Check (`OpenROAD.CheckAntennas`)

**Location:** `runs/project_wrapper/XX-openroad-checkantennas/`

A clean result shows an empty violation table, confirming no antenna violations were
introduced at the wrapper level:

```text
┏━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━┳━━━━━┳━━━━━┳━━━━━━━┓
┃ Partial/Required ┃ Required ┃ Partial ┃ Net ┃ Pin ┃ Layer ┃
┡━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━╇━━━━━╇━━━━━╇━━━━━━━┩
└──────────────────┴──────────┴─────────┴─────┴─────┴───────┘
```

---

### 6.2 Post-PnR STA (`OpenROAD.STAPostPNR`)

**Location:** `runs/project_wrapper/XX-openroad-stapostpnr/summary.rpt`

```text
┏━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━┓
┃                      ┃ Hold     ┃ Reg to   ┃          ┃          ┃ of which  ┃ Setup    ┃           ┃          ┃           ┃ of which ┃           ┃          ┃
┃                      ┃ Worst    ┃ Reg      ┃          ┃ Hold Vio ┃ reg to    ┃ Worst    ┃ Reg to    ┃ Setup    ┃ Setup Vio ┃ reg to   ┃ Max Cap   ┃ Max Slew ┃
┃ Corner/Group         ┃ Slack    ┃ Paths    ┃ Hold TNS ┃ Count    ┃ reg       ┃ Slack    ┃ Reg Paths ┃ TNS      ┃ Count     ┃ reg      ┃ Violatio… ┃ Violati… ┃
┡━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━┩
│ Overall              │ 0.0068   │ 0.0068   │ 0.0000   │ 0        │ 0         │ 3.7165   │ 4.4084    │ 0.0000   │ 0         │ 0        │ 1         │ 11       │
│ nom_tt_025C_1v80     │ 0.1510   │ 0.1510   │ 0.0000   │ 0        │ 0         │ 8.8029   │ 14.5253   │ 0.0000   │ 0         │ 0        │ 0         │ 0        │
│ nom_ss_100C_1v60     │ 0.5607   │ 0.5607   │ 0.0000   │ 0        │ 0         │ 3.9078   │ 4.9941    │ 0.0000   │ 0         │ 0        │ 0         │ 0        │
│ nom_ff_n40C_1v95     │ 0.0076   │ 0.0076   │ 0.0000   │ 0        │ 0         │ 9.6207   │ 18.0993   │ 0.0000   │ 0         │ 0        │ 0         │ 0        │
│ min_tt_025C_1v80     │ 0.1500   │ 0.1500   │ 0.0000   │ 0        │ 0         │ 8.9049   │ 14.9589   │ 0.0000   │ 0         │ 0        │ 0         │ 0        │
│ min_ss_100C_1v60     │ 0.5589   │ 0.5589   │ 0.0000   │ 0        │ 0         │ 4.1683   │ 5.5905    │ 0.0000   │ 0         │ 0        │ 0         │ 0        │
│ min_ff_n40C_1v95     │ 0.0068   │ 0.0068   │ 0.0000   │ 0        │ 0         │ 9.6906   │ 18.4544   │ 0.0000   │ 0         │ 0        │ 0         │ 0        │
│ max_tt_025C_1v80     │ 0.1522   │ 0.1522   │ 0.0000   │ 0        │ 0         │ 8.7121   │ 14.0229   │ 0.0000   │ 0         │ 0        │ 0         │ 0        │
│ max_ss_100C_1v60     │ 0.5627   │ 0.5627   │ 0.0000   │ 0        │ 0         │ 3.7165   │ 4.4084    │ 0.0000   │ 0         │ 0        │ 1         │ 11       │
│ max_ff_n40C_1v95     │ 0.0086   │ 0.0086   │ 0.0000   │ 0        │ 0         │ 9.5575   │ 17.7586   │ 0.0000   │ 0         │ 0        │ 0         │ 0        │
└──────────────────────┴──────────┴──────────┴──────────┴──────────┴───────────┴──────────┴───────────┴──────────┴───────────┴──────────┴───────────┴──────────┘
```

```{admonition} Interpreting the Results
:class: tip

**Hold violations: none.** All 9 corners show positive Hold {term}`WNS`, confirming
hold timing is clean end-to-end after integration.

**Setup timing: clean.** Zero Setup violation count across all corners. The 40 MHz
target is met at the wrapper level.

**Max Slew (11) and Max Cap (1) in `max_ss_100C_1v60`:** These violations are
inherited from the `aes_wb_wrapper` macro's interface pins. They were present in the
macro's standalone STA and were not fully resolved because they originate on internal
nets that are not accessible for ECO repair at the wrapper level. They do not affect
functional correctness but represent a known limitation of the current implementation.

To inspect the specific violating pins, open:

```text
runs/project_wrapper/XX-openroad-stapostpnr/max_ss_100C_1v60/checks.rpt
```
```

---

### 6.3 DRC — Magic and KLayout

#### Magic DRC

**Location:** `runs/project_wrapper/XX-magic-drc/reports/drc.rpt`

A clean result:

```text
aes_wb_wrapper
----------------------------------------
[INFO] COUNT: 0
[INFO] Should be divided by 3 or 4
```

`COUNT: 0` confirms zero Design Rule violations. The note about dividing by 3 or 4 is
a Magic-internal counting normalisation — a normalised count of 0 is an unambiguous
clean result.

#### KLayout DRC

**Location:** `runs/project_wrapper/XX-klayout-drc/violations.json`

A clean result:

```json
{
  ⋮
  "total": 0
}
```

Both tools independently confirm the layout is manufacturing-ready.

---

### 6.4 LVS (`Netgen.LVS`)

**Location:** `runs/project_wrapper/XX-netgen-lvs/reports/lvs.rpt`

The final section of the report:

```text
Cell pin lists are equivalent.
Device classes user_project_wrapper and user_project_wrapper are equivalent.
Final result: Circuits match uniquely.
```

**"Match"** — the physical connections are logically identical to the netlist.
**"Uniquely"** — Netgen found no topological ambiguity. Every net across the complete
design hierarchy is proven to be connected exactly where the synthesis netlist specifies.

---

## 7. Saving the Views

With the wrapper hardened and verified, copy its physical views into the project's
shared directories for submission or further integration:

```console
$ bash ~/Silicon-Sprint-AUC/openlane/copy_views.sh \
    ~/Silicon-Sprint-AUC \
    user_project_wrapper \
    project_wrapper
```

This copies the wrapper's `final/` outputs — GDS, LEF, gate-level netlist, SPEF, and
Liberty model — to the project-level directories, completing the full RTL-to-{term}`GDSII`
flow for the AES accelerator as a Caravel user project.

```{admonition} Congratulations!
:class: tip

You have successfully hardened an AES-128 accelerator as a Caravel User Project —
from RTL through synthesis, floorplanning, placement, routing, physical signoff, and
wrapper integration. The final `user_project_wrapper.gds` is a tape-out ready GDSII
file.
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
  Library Exchange Format. A file describing the physical interface of a macro — its boundary, pin locations, and metal blockages — used for hierarchical integration.

SPEF
  Standard Parasitic Exchange Format. A text-based map of the resistance and capacitance of every net, produced by RC extraction and consumed by STA.

STA
  Static Timing Analysis. Exhaustive path-by-path timing verification against declared constraints without requiring simulation vectors.

GDSII
  Graphic Database System II. The standard binary layout format delivered to the foundry for fabrication.

SDC
  Synopsys Design Constraints. Tcl-based timing and clocking constraints used during implementation and signoff.

WNS
  Worst Negative Slack. The largest magnitude of negative slack across all failing timing paths.
```

# Module 1: LibreLane Flow & Execution to PDN

```{admonition} Prerequisites
:class: important

Before proceeding, ensure your environment is fully prepared by completing all steps in **Module 0**.
Your repository must be cloned and the Nix-shell verified before starting the ASIC flow.
```

---

## Table of Contents

1. [RTL Integration — The Wishbone Wrapper](#rtl-integration-the-wishbone-wrapper)
   - [1.1 Architectural Overview](#architectural-overview)
   - [1.2 Creating the Verilog Wrapper](#creating-the-verilog-wrapper)
2. [The LibreLane Classic Flow](#the-librelane-classic-flow)
   - [2.1 Flow Step Reference](#flow-step-reference)
3. [Setting Up the Design Environment](#setting-up-the-design-environment)
   - [Step 1 — Create the Design Directory](#step-1-create-the-design-directory)
   - [Step 2 — Define Timing Constraints](#step-2-define-timing-constraints-sdc-files)
   - [Step 3 — Create the Base Configuration File](#step-3-create-the-base-configuration-file)
4. [RTL-to-Power-Grid Configuration Reference](#rtl-to-power-grid-configuration-reference)
   - [4.1 Logic Synthesis Parameters](#logic-synthesis-configuration-reference)
   - [4.2 Floorplan Parameters](#floorplan-configuration-reference)
   - [4.3 Power Distribution Network Parameters](#power-distribution-network-pdn-configuration-reference)
5. [The `librelane` Command Syntax](#the-librelane-command-syntax)
6. [Run 1: Execution to Power Network (Classic Flow)](#run-1-execution-to-power-network-classic-flow)
   - [6.1 Synthesis Exploration](#task-synthesis-exploration)
   - [6.2 Final Configuration Setup](#final-configuration-setup)
   - [6.3 Entering the Nix Shell](#entering-the-nix-shell)
   - [6.4 Flow Execution](#flow-execution)
   - [6.5 Output Directory Structure & Artifacts](#output-directory-structure)
7. [Viewing the Layout](#viewing-the-layout)
   - [7.1 KLayout](#viewing-the-layout-in-klayout)
   - [7.2 OpenROAD GUI](#inspecting-via-openroad-gui)
8. [Checking the Reports](#check-the-reports)
   - [8.1 Syntax and Linting Checks](#syntax-and-linting-checks)
   - [8.2 Timing and Electrical Summary](#timing-and-electrical-summary)
   - [8.3 Detailed Multi-Corner Analysis](#detailed-multi-corner-analysis)
   - [8.4 PDN Integrity](#power-distribution-network-pdn-integrity)

---

## 1. RTL Integration — The Wishbone Wrapper

Before beginning the ASIC flow, we must bridge the gap between the **AES Core** and the
**Caravel SoC**. This is accomplished by encapsulating the design inside a **Wishbone
Wrapper** (`aes_wb_wrapper.v`) — a standardised communication adapter that allows the
Caravel CPU to exchange data with the AES encryption engine using a well-defined bus
protocol.

```{note}
In later modules, we will demonstrate how to integrate this complete unit into the
**User Project Wrapper**. For now, the objective is to ensure the AES logic is
"Wishbone-ready."
```

### Why Do We Need the Wishbone Wrapper?

| Reason | Explanation |
| :--- | :--- |
| **Standardisation** | Adheres to the Wishbone protocol natively understood by the Caravel harness. |
| **Addressability** | Assigns the AES core a specific memory address so the CPU can locate it on the bus. |
| **Control** | Allows the system to independently reset or clock the AES core. |

---

### 1.1 Architectural Overview

Before writing any code, study the block diagram below. It illustrates how the **AES Core**
is encapsulated within the **Wishbone Wrapper**. The wrapper serves as the translation layer,
converting standard Wishbone bus signals — such as `wbs_stb_i` and `wbs_dat_i` — into the
control signals the AES engine requires.

```{figure} ./figures/aes_wb_wrappre.png
:align: center

*Block diagram of* `aes_wb_wrapper`
```

---

### 1.2 Creating the Verilog Wrapper

Follow the steps below to create the interface file that bridges the AES logic with the
Wishbone bus.

#### Step 1 — Initialize the Wrapper File

We use **gedit** (a lightweight graphical text editor) to create the wrapper file. If the
file does not already exist, it will be initialized as an empty document.

```console
$ gedit ~/Silicon-Sprint-AUC/verilog/rtl/aes_wb_wrapper.v
```

#### Step 2 — Add the Verilog Implementation

Once the editor opens, paste the Wishbone wrapper implementation into the file. This module
manages all communication between the Caravel SoC and the AES core. After pasting,
**save the file** and close the editor.

````{dropdown} aes_wb_wrapper.v
```{literalinclude} ./code/aes_wb_wrapper.v
:language: verilog
:linenos:
```
````

---

## 2. The LibreLane Classic Flow

The **LibreLane Classic Flow** is a sequential, automated {term}`RTL`-to-{term}`GDSII`
pipeline built entirely on open-source {term}`EDA` tools. Each phase of ASIC design —
from logic verification through physical signoff — is handled by a specialised tool within
a single unified environment.

```{figure} ./figures/flow.webp
:scale: 60 %
:align: center

*LibreLane RTL-to-GDSII Flow*
```

```{admonition} Key Concept — Deterministic Execution
:class: tip

The Classic flow is deterministic and repeatable. Every run follows the same ordered
sequence of steps, making it the ideal starting point for learning the full ASIC design
process.
```

---

### 2.1 Flow Step Reference

Each step in the flow carries a unique **Step ID** in the format `ToolName.StepName`.
These IDs are consumed directly by the `librelane` command line to start, stop, or skip
individual stages (see [Section 5](#the-librelane-command-syntax)).

| Stage | Step Description | Step ID |
| :--- | :--- | :--- |
| **Logic Verification** | RTL Linting with Verilator | `Verilator.Lint` |
| | Check Timing Constructs | `Checker.LintTimingConstructs` |
| | Check for Lint Errors | `Checker.LintErrors` |
| | Check for Lint Warnings | `Checker.LintWarnings` |
| **Synthesis** | Generate Netlist JSON Header | `Yosys.JsonHeader` |
| | RTL Synthesis and Tech Mapping | `Yosys.Synthesis` |
| | Check for Unmapped Cells | `Checker.YosysUnmappedCells` |
| | Logic Synthesis Checks | `Checker.YosysSynthChecks` |
| | Netlist Assign Statement Check | `Checker.NetlistAssignStatements` |
| **Floorplanning** | Validate {term}`SDC` Constraints | `OpenROAD.CheckSDCFiles` |
| | Validate Macro Instances | `OpenROAD.CheckMacroInstances` |
| | Pre-{term}`PnR` Static Timing Analysis | `OpenROAD.STAPrePNR` |
| | Initial Floorplan Generation | `OpenROAD.Floorplan` |
| | Dump Resistance/Capacitance Values | `OpenROAD.DumpRCValues` |
| | Check Macro Antenna Properties | `Odb.CheckMacroAntennaProperties` |
| | Macro Power Connections | `Odb.SetPowerConnections` |
| | Manual Macro Placement | `Odb.ManualMacroPlacement` |
| | Cut Rows for Macro Sites | `OpenROAD.CutRows` |
| | Tap and Endcap Cell Insertion | `OpenROAD.TapEndcapInsertion` |
| **Power Grid** | Add {term}`PDN` Obstructions | `Odb.AddPDNObstructions` |
| | Power Distribution Network Generation | `OpenROAD.GeneratePDN` |
| | Remove PDN Obstructions | `Odb.RemovePDNObstructions` |
| | Add Routing Obstructions | `Odb.AddRoutingObstructions` |
| **Placement** | Global Placement (Skip IO) | `OpenROAD.GlobalPlacementSkipIO` |
| | IO Pin Placement | `OpenROAD.IOPlacement` |
| | Custom IO Pin Placement | `Odb.CustomIOPlacement` |
| | Apply DEF Template | `Odb.ApplyDEFTemplate` |
| | Global Placement | `OpenROAD.GlobalPlacement` |
| | Write Verilog Header | `Odb.WriteVerilogHeader` |
| | Power Grid Violation Check | `Checker.PowerGridViolations` |
| | Mid-{term}`PnR` Static Timing Analysis (1) | `OpenROAD.STAMidPNR` |
| | Design Repair (Post-GPL) | `OpenROAD.RepairDesignPostGPL` |
| | Manual Global Placement | `Odb.ManualGlobalPlacement` |
| | Detailed Placement | `OpenROAD.DetailedPlacement` |
| **CTS** | Clock Tree Synthesis | `OpenROAD.CTS` |
| | Mid-{term}`PnR` Static Timing Analysis (2) | `OpenROAD.STAMidPNR-1` |
| | Resizer Timing (Post-CTS) | `OpenROAD.ResizerTimingPostCTS` |
| | Mid-{term}`PnR` Static Timing Analysis (3) | `OpenROAD.STAMidPNR-2` |
| **Routing** | Global Routing | `OpenROAD.GlobalRouting` |
| | Initial Antenna Check | `OpenROAD.CheckAntennas` |
| | Design Repair (Post-GRT) | `OpenROAD.RepairDesignPostGRT` |
| | Diodes on Ports | `Odb.DiodesOnPorts` |
| | Heuristic Diode Insertion | `Odb.HeuristicDiodeInsertion` |
| | Antenna Repair | `OpenROAD.RepairAntennas` |
| | Resizer Timing (Post-GRT) | `OpenROAD.ResizerTimingPostGRT` |
| | Mid-{term}`PnR` Static Timing Analysis (4) | `OpenROAD.STAMidPNR-3` |
| | Detailed Routing | `OpenROAD.DetailedRouting` |
| | Remove Routing Obstructions | `Odb.RemoveRoutingObstructions` |
| | Final Antenna Check | `OpenROAD.CheckAntennas-1` |
| | Detailed Routing {term}`DRC` Check | `Checker.TrDRC` |
| | Report Disconnected Pins | `Odb.ReportDisconnectedPins` |
| | Disconnected Pins Check | `Checker.DisconnectedPins` |
| | Report Wire Length | `Odb.ReportWireLength` |
| | Wire Length Check | `Checker.WireLength` |
| **Signoff Prep** | Fill Cell Insertion | `OpenROAD.FillInsertion` |
| | Cell Frequency Tables | `Odb.CellFrequencyTables` |
| | Parasitics Extraction | `OpenROAD.RCX` |
| | Post-PnR {term}`STA` | `OpenROAD.STAPostPNR` |
| | IR Drop Reporting | `OpenROAD.IRDropReport` |
| **Physical Signoff** | {term}`GDSII` Stream Out (Magic) | `Magic.StreamOut` |
| | GDSII Stream Out (KLayout) | `KLayout.StreamOut` |
| | KLayout Render | `KLayout.Render` |
| | Write Macro {term}`LEF` | `Magic.WriteLEF` |
| | Check Design Antenna Properties | `Odb.CheckDesignAntennaProperties` |
| | XOR GDS Comparison | `KLayout.XOR` |
| | XOR Comparison Check | `Checker.XOR` |
| | Physical {term}`DRC` (Magic) | `Magic.DRC` |
| | Physical DRC (KLayout) | `KLayout.DRC` |
| | Magic DRC Check | `Checker.MagicDRC` |
| | KLayout DRC Check | `Checker.KLayoutDRC` |
| | {term}`SPICE` Netlist Extraction | `Magic.SpiceExtraction` |
| | Illegal Overlap Check | `Checker.IllegalOverlap` |
| | Layout vs. Schematic ({term}`LVS`) | `Netgen.LVS` |
| | LVS Comparison Check | `Checker.LVS` |
| | Formal Equivalence Check | `Yosys.EQY` |
| | Setup Violations Check | `Checker.SetupViolations` |
| | Hold Violations Check | `Checker.HoldViolations` |
| | Max Slew Violations Check | `Checker.MaxSlewViolations` |
| | Max Cap Violations Check | `Checker.MaxCapViolations` |
| | Final Manufacturability Report | `Misc.ReportManufacturability` |

---

## 3. Setting Up the Design Environment

This section follows an **Iterative Configuration Strategy**: we begin with the minimum
required settings, execute the flow, analyse the generated reports, and progressively
refine the configuration based on observed results.

### Step 1 — Create the Design Directory

Create the dedicated folder where LibreLane will look for your `config.json`:

```console
$ mkdir -p ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper
```

---

### Step 2 — Define Timing Constraints ({term}`SDC` Files)

To achieve {term}`timing closure` on a complex design like the AES accelerator, it is
strongly recommended to provide design-specific {term}`SDC` files rather than relying on
the tool's auto-generated defaults. This is controlled via the **`PNR_SDC_FILE`** and
**`SIGNOFF_SDC_FILE`** configuration variables.

```{admonition} Key Concept — The Timing Contract
:class: tip

{term}`SDC` files function as a **"timing contract"** between your {term}`RTL` and the
physical implementation tools. They declare the clock frequency, multicycle paths, and
I/O timing requirements that OpenROAD must satisfy during {term}`PnR`.
```

```{note}
**How the two SDC files work together:**

The `pnr.sdc` file is applied throughout the entire implementation flow — including
Placement, CTS, and Routing — to maintain high signal integrity during physical
implementation. The `signoff.sdc` file is only used at the final signoff stage for
the ultimate timing and DRC validation.

This two-file strategy is intentional:

- **Restrictive PnR:** `pnr.sdc` applies a strict **0.75 ns** maximum transition limit.
  This forces the engine to work aggressively during placement and routing, resolving
  the vast majority of slew violations before signoff.

- **Signoff Relaxation:** `signoff.sdc` applies a relaxed **1.5 ns** transition limit,
  consistent with the `sky130_fd_sc_hd` library characterisation boundary. Since the
  tool has already fixed violations against the tighter constraint during {term}`PnR`,
  most slew violations disappear at signoff — producing a clean final timing report.
```

#### PnR Constraint File (`pnr.sdc`)

Applied during all implementation steps (Placement, CTS, Routing). Sets the clock period,
defines a strict 0.75 ns maximum transition, specifies multicycle paths, and establishes
realistic clock latency and I/O delay values based on the Caravel SoC environment.

```console
$ gedit ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/pnr.sdc
```

Paste the following code into the editor and save:

````{dropdown} pnr.sdc
```{literalinclude} ./code/pnr.sdc
:language: tcl
```
````

#### Signoff Constraint File (`signoff.sdc`)

Applied **only** at the final signoff STA stage. Uses a relaxed 1.5 ns maximum transition
limit and slightly less pessimistic timing derate values (±5% vs ±7% in `pnr.sdc`),
reflecting a more realistic assessment of the manufactured silicon's operating envelope.

```console
$ gedit ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/signoff.sdc
```

Paste the following code into the editor and save:

````{dropdown} signoff.sdc
```{literalinclude} ./code/signoff.sdc
:language: tcl
```
````

The key differences between the two files are summarised below:

| Constraint | `pnr.sdc` (Implementation) | `signoff.sdc` (Signoff Only) |
| :--- | :---: | :---: |
| Maximum Transition | **0.75 ns** (strict) | **1.5 ns** (library limit) |
| Timing Derate | **±7%** | **±5%** |
| Clock Uncertainty | **0.12 ns** | **0.10 ns** |
| Clock Latency (max) | **5.70 ns** | **5.57 ns** |

---

### Step 3 — Create the Base Configuration File

The `config.json` file is the **master instruction set** for the LibreLane flow. We begin
with the minimum required settings and will expand it progressively in the steps that follow.

Create and open the file:

```console
$ gedit ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/config.json
```

Paste the following base configuration:

```json
{
    "DESIGN_NAME": "aes_wb_wrapper",
    "PDN_MULTILAYER": false,
    "CLOCK_PORT": "wb_clk_i",
    "CLOCK_PERIOD": 25,
    "VERILOG_FILES": [
        "dir::../../../secworks_aes/src/rtl/*.v",
        "dir::../../verilog/rtl/aes_wb_wrapper.v"
    ],
    "FP_CORE_UTIL": 40,
    "RT_MAX_LAYER": "met4",
    "PNR_SDC_FILE": "dir::pnr.sdc",
    "SIGNOFF_SDC_FILE": "dir::signoff.sdc"
}
```

```{note}
**`FP_CORE_UTIL` is set to 40%** (the default is 50%). This lower utilisation leaves
more routing headroom for the AES core's dense combinational logic, reducing the risk
of routing congestion during placement and routing.
```

#### Configuration Variable Reference

| Variable | Value | Description |
| :--- | :--- | :--- |
| `DESIGN_NAME` | `"aes_wb_wrapper"` | Must match the top-level Verilog module name exactly. |
| `VERILOG_FILES` | *(glob path)* | All {term}`RTL` source files. The `dir::` prefix resolves paths relative to the design directory. The `*.v` glob includes all AES core RTL in a single expression. |
| `CLOCK_PORT` | `"wb_clk_i"` | The RTL port designated as the primary clock input. |
| `CLOCK_PERIOD` | `25` | Clock period in nanoseconds — **25 ns = 40 MHz**. |
| `PDN_MULTILAYER` | `false` | Restricts the PDN to Metal 4 vertical straps only, leaving Metal 5 clear for Caravel top-level integration. See [Section 4.3](#power-distribution-network-pdn-configuration-reference). |
| `FP_CORE_UTIL` | `40` | Core utilisation percentage. Set to 40% (default: 50%) for routing headroom. |
| `RT_MAX_LAYER` | `"met4"` | Restricts all signal routing to Metal 4 and below, leaving Metal 5 clear for the top-level PDN. |

```{warning}
**Minimum Required Variables**

Every LibreLane design configuration **must** include the following four variables at a
minimum. The flow will fail at initialisation if any are absent:

- `DESIGN_NAME`
- `VERILOG_FILES`
- `CLOCK_PERIOD`
- `CLOCK_PORT`
```

Note that `PNR_SDC_FILE` and `SIGNOFF_SDC_FILE` will be added once we have confirmed
the best synthesis strategy in Section 6.

---

## 4. RTL-to-Power-Grid Configuration Reference

This section documents the key `config.json` parameters for synthesis, floorplanning, and
power distribution. These are provided as a reference — **not all are used in this module**.
Values are tuned progressively as the flow matures across modules.

---

### 4.1 Logic Synthesis Configuration Reference

Synthesis maps your RTL to the **SkyWater 130nm (`sky130_fd_sc_hd`)** standard cell library.
The parameters below govern the trade-off between gate count and achievable clock frequency.

| Parameter | Type | Description | Default |
| :--- | :--- | :--- | :--- |
| `SYNTH_STRATEGY` | `str` | Selects the ABC logic synthesis strategy. `AREA 0–3` targets compactness; `DELAY 0–4` targets higher clock frequencies. | `AREA 0` |
| `SYNTH_HIERARCHY_MODE` | `str` | Controls hierarchy handling: `flatten` (merges all modules), `deferred_flatten` (flattens after synthesis), or `keep` (preserves hierarchy). | `flatten` |
| `SYNTH_ABC_BUFFERING` | `bool` | Enables automated cell buffering within ABC to improve signal integrity and timing margins. | `False` |
| `SYNTH_SIZING` | `bool` | Enables ABC cell sizing to optimise gate drive strength. | `False` |
| `SYNTH_SHARE_RESOURCES` | `bool` | Allows Yosys to identify and merge shareable hardware resources (e.g., adders) to reduce total area. | `True` |
| `SYNTH_AUTONAME` | `bool` | Generates human-readable instance names in the netlist. Useful for debugging; may produce very long names. | `False` |
| `SYNTH_ELABORATE_ONLY` | `bool` | Performs {term}`RTL` elaboration only, without technology mapping. Use if the Verilog is already gate-level. | `False` |
| `VERILOG_POWER_DEFINE` | `str` | Specifies the macro used to guard power/ground connections in the RTL. | `USE_POWER_PINS` |
| `ERROR_ON_SYNTH_CHECKS` | `bool` | Quits the flow immediately if synthesis check errors are found — specifically combinational loops or wires with no drivers. Catching these early prevents hard-to-debug downstream failures. | `True` |
| `ERROR_ON_NL_ASSIGN_STATEMENTS` | `bool` | Emits an error (rather than a warning) if assign statements are found in the post-synthesis netlist, which may indicate incomplete technology mapping. | `True` |

---

### 4.2 Floorplan Configuration Reference

These parameters define the physical boundaries of the AES core. Correct floorplan settings
ensure the macro fits within the designated User Project area while preserving adequate
routing resources.

| Parameter | Type | Description | Default |
| :--- | :--- | :--- | :--- |
| `FP_CORE_UTIL` | `Decimal` | Core utilisation percentage. | `50` |
| `FP_ASPECT_RATIO` | `Decimal` | Core aspect ratio (height ÷ width). A value of 1 creates a square floorplan. | `1` |
| `FP_SIZING` | `str` | `'relative'` calculates area from utilisation; `'absolute'` uses fixed user-defined coordinates. | `'relative'` |
| `DIE_AREA` | `Tuple?` | Fixed die boundary as `"x0 y0 x1 y1"`. Required when `FP_SIZING` is `absolute`. | `None` |
| `CORE_AREA` | `Tuple?` | Explicit core area boundary. Must be paired with `DIE_AREA`. | `None` |
| `BOTTOM_MARGIN_MULT` | `Decimal` | Bottom core margin in multiples of site heights. Ignored if `DIE_AREA` / `CORE_AREA` are set. | `4` |
| `TOP_MARGIN_MULT` | `Decimal` | Top core margin in multiples of site heights. | `4` |
| `LEFT_MARGIN_MULT` | `Decimal` | Left core margin in multiples of site widths. | `12` |
| `RIGHT_MARGIN_MULT` | `Decimal` | Right core margin in multiples of site widths. | `12` |

```{admonition} Relative vs. Absolute Floorplan Sizing
:class: note

**Relative Sizing (`"FP_SIZING": "relative"`)** — The default mode. LibreLane calculates
chip area automatically from gate count and `FP_CORE_UTIL`. Use this for initial iterations
to find the smallest feasible footprint.

**Absolute Sizing (`"FP_SIZING": "absolute"`)** — Mandatory for fixed-size projects such
as the **Caravel User Project**. Physical coordinates are explicitly declared via `DIE_AREA`
(e.g., `0 0 2920 3520`), ensuring the AES core fits precisely into the pre-defined silicon
cavity of the SoC.
```

```{figure} ./figures/floorplan.png
:align: center
:scale: 60%

*Floorplan boundary and margin visualisation*
```

---

### 4.3 Power Distribution Network ({term}`PDN`) Configuration Reference

The {term}`PDN` is the grid of metal conductors delivering `VDD` and `GND` to every
standard cell in the design. LibreLane supports two fundamentally different methods
for constructing the PDN of a macro, and the choice between them affects which metal
layers are available for signal routing.

---

#### PDN Method 1 — Hierarchical

In the **Hierarchical method**, power is delivered through stacked metal straps: each
level of the design hierarchy uses a different metal layer for power straps, and the
macro boundary is deliberately kept clear of the topmost used layer so that the
parent-level integration can connect through vias.

```{figure} ./figures/pdn_hierarchical.webp
:align: center

*Hierarchical PDN — each level of hierarchy gives up the topmost metal layer so the
level above can connect through.*
```

The rule is simple: if your macro will be placed inside a top-level wrapper that uses
**met5** for horizontal power straps, your macro must not use met5 — for either PDN
or signal routing.

```{admonition} Critical Parameters for Hierarchical Method
:class: warning

When using the hierarchical method for a macro that will be integrated into the
OpenFrame multiproject wrapper, two parameters **must** be set together:

- **`PDN_MULTILAYER: false`** — Restricts the macro's PDN to vertical straps on
  Metal 4 only. Metal 5 is left completely clear for the top-level wrapper's
  horizontal power straps.

- **`RT_MAX_LAYER: "met4"`** — Prevents the router from placing any signal wire on
  Metal 5. Without this, detailed routing may use met5 for signal wires, creating
  DRC conflicts with the wrapper's power grid.

Omitting either parameter will result in met5 conflicts and fatal {term}`DRC`
violations when the macro is integrated into the top level.
```

::::{grid} 2

:::{grid-item}
```{figure} ./figures/multilayer_true.png
:align: center

**Avoid:** `PDN_MULTILAYER: True` — M4/M5 mesh conflicts with the top-level wrapper straps.
```
:::

:::{grid-item}
```{figure} ./figures/multilayer_false.png
:align: center

**Correct:** `PDN_MULTILAYER: False` — Only vertical M4 straps; Metal 5 is clear.
```
:::

::::

---

#### PDN Method 2 — Ring

In the **Ring method**, a closed power ring is built around the perimeter of the macro
core area. This ring is connected to the top-level integration by abutment — the top
level connects to the ring edges rather than running straps through the macro.

```{figure} ./figures/pdn_ring.webp
:align: center

*Ring PDN — a closed power ring surrounds the core; the full metal layer stack is
available for internal routing.*
```

The key advantage is that the macro can use **all available metal layers for signal
routing** — including met5 — because the power ring does not depend on reserving the
topmost layer for vertical strap continuity. The trade-off is that the ring occupies
additional area around the core perimeter.

```json
"PDN_CORE_RING": true
```

---

#### PDN Control Parameters

| Parameter | Type | Description | Default |
| :--- | :--- | :--- | :--- |
| `PDN_MULTILAYER` | `bool` | Generates both vertical (M4) and horizontal (M5) straps. Set `false` for hierarchical method. | `False` |
| `PDN_CORE_RING` | `bool` | Enables the ring method — builds a power ring around the core perimeter. | `False` |
| `PDN_CORE_RING_VWIDTH` | `Decimal` | Width of vertical ring segments. | `1.6 µm` |
| `PDN_CORE_RING_HWIDTH` | `Decimal` | Width of horizontal ring segments. | `1.6 µm` |
| `PDN_CORE_RING_VSPACING` | `Decimal` | Spacing between the VDD and GND vertical ring straps. | `1.7 µm` |
| `PDN_CORE_RING_HSPACING` | `Decimal` | Spacing between the VDD and GND horizontal ring straps. | `1.7 µm` |
| `PDN_CORE_RING_VOFFSET` | `Decimal` | Offset of the vertical ring from the core boundary. | `6 µm` |
| `PDN_CORE_RING_HOFFSET` | `Decimal` | Offset of the horizontal ring from the core boundary. | `6 µm` |
| `PDN_ENABLE_RAILS` | `bool` | Enables Metal 1 standard cell power rails across every cell row. | `True` |
| `PDN_SKIPTRIM` | `bool` | Prevents removal of metal stubs not connected to macros. | `False` |
| `PDN_HORIZONTAL_HALO` | `Decimal` | Horizontal keep-out distance around macros. | `10 µm` |
| `PDN_VERTICAL_HALO` | `Decimal` | Vertical keep-out distance around macros. | `10 µm` |
| `PDN_CFG` | `Path?` | Custom PDN Tcl configuration file. Uses built-in defaults if not set. | `None` |

#### SkyWater 130nm PDN Layer Defaults

| Design Element | Parameter | Default Value | Description |
| :--- | :--- | :--- | :--- |
| **M1 Rails** | `PDN_RAIL_WIDTH` | **0.48 µm** | Standard cell power rail width. |
| | `PDN_RAIL_OFFSET` | **0** | Starting rail offset. |
| **M4 Vertical Straps** | `PDN_VWIDTH` | **1.6 µm** | Width of vertical power lines. |
| | `PDN_VSPACING` | **1.7 µm** | Spacing between parallel vertical straps. |
| | `PDN_VPITCH` | **153.6 µm** | Centre-to-centre pitch. |
| | `PDN_VOFFSET` | **16.32 µm** | X-axis offset from the left core boundary. |
| **M5 Horizontal Straps** | `PDN_HWIDTH` | **1.6 µm** | Width (active only when `PDN_MULTILAYER: True`). |
| | `PDN_HPITCH` | **153.18 µm** | Y-axis pitch. |

For further reading, refer to the [LibreLane PDN documentation](https://librelane.readthedocs.io/en/stable/usage/pdn.html).

---

## 5. The `librelane` Command Syntax

Before issuing any commands, ensure you are inside the Nix shell environment (see
[Section 6.3](#entering-the-nix-shell)).

```console
[nix-shell:~]$ librelane [OPTIONS] [CONFIG_FILE]...
```

### Sequential Flow Controls

| Option | Description | Example |
| :--- | :--- | :--- |
| `--from <StepID>` | Starts the flow from a specific step. | `--from Checker.LintErrors` |
| `--to <StepID>` | Stops the flow after a specific step completes. | `--to Yosys.Synthesis` |
| `--skip <StepID>` | Bypasses a specific step during execution. | `--skip Checker.LintWarnings` |

### Run Management Options

| Option | Description |
| :--- | :--- |
| `--run-tag <n>` | Assigns a custom name to the run directory. Essential for preserving and comparing different runs. |
| `--last-run` | Automatically targets the most recently created run directory. |
| `--overwrite` | Overwrites the existing run directory if a matching tag is found. |
| `--with-initial-state <FILE>` | Resumes a previous flow using a specific `state_out.json` as the starting checkpoint. |

### Flow Configuration Modes (`--flow` / `-f`)

| Mode | Description |
| :--- | :--- |
| `classic` | Standard sequential flow. Predictable, step-by-step — the recommended starting point for learning. |
| `SynthesisExploration` | Iterates through all available `SYNTH_STRATEGY` options to find the best {term}`PPA` results for your design. |
| `openinklayout` | Opens the current design state in **KLayout** for {term}`GDSII`/{term}`DEF` inspection. |
| `openinopenroad` | Opens the design in the **OpenROAD GUI** for physical analysis. |

---

## 6. Run 1: Execution to Power Network (Classic Flow)

In this run, we execute the **Classic Flow** up to the completion of the {term}`PDN`.
Before doing so, we first identify the best synthesis strategy using the **Synthesis
Exploration** flow.

---

### 6.1 Synthesis Exploration

When hardening a new design, it is essential to first identify the optimal synthesis
strategy. Synthesis strategies are scripts for the **ABC** utility that handle fine-grained
optimisation and technology mapping. LibreLane provides a dedicated exploration flow that
automatically iterates through all available strategies and compares their outcomes.

```{tip}
It is always recommended to run **`SynthesisExploration`** before committing to a full
implementation run. Since `AREA` strategies minimise footprint while `DELAY` strategies
optimise timing, the best choice is design-specific and cannot be reliably predicted
in advance.
```

Ensure you are inside the Nix shell, then run:

```console
[nix-shell:~]$ librelane \
    ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/config.json \
    --flow SynthesisExploration \
    --run-tag synexp
```

The exploration flow tests all nine strategies and prints a ranked summary table. For the
`aes_wb_wrapper`, the results look as follows:

```text
┏━━━━━━━━━━━━━━━━┳━━━━━━━┳━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃ SYNTH_STRATEGY ┃ Gates ┃ Area (µm²)    ┃ Worst R2R Setup Slack (ns) ┃ Worst Setup Slack (ns) ┃ Total -ve Setup Slack (ns) ┃
┡━━━━━━━━━━━━━━━━╇━━━━━━━╇━━━━━━━━━━━━━━━╇━━━━━━━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━━━━━━━━━━━━━━━━━━━┩
│ AREA 0         │ 18539 │ 224092.422400 │ -15.910378                 │ -15.910377465847041    │ -19089.359369544294        │
│ AREA 1         │ 18366 │ 223144.012800 │ 1.487758                   │ 1.4877575148500661     │ 0.0                        │
│ AREA 2         │ 18148 │ 220730.448000 │ 1.312014                   │ 1.3120136459736262     │ 0.0                        │
│ AREA 3         │ 34288 │ 309575.657600 │ 10.604188                  │ 8.695160393369793      │ 0.0                        │
│ DELAY 0        │ 25126 │ 292449.232000 │ -15.024117                 │ -15.024117486468324    │ -2965.166315521618         │
│ DELAY 1        │ 26630 │ 303773.843200 │ -11.669471                 │ -11.66947105309875     │ -5372.319416946378         │
│ DELAY 2        │ 26042 │ 296162.793600 │ -5.635439                  │ -5.63543894167321      │ -937.7127677538822         │
│ DELAY 3        │ 24930 │ 290193.318400 │ -17.302505                 │ -17.30250480754339     │ -3854.8115479629128        │
│ DELAY 4        │ 24181 │ 256073.094400 │ 9.766527                   │ 9.003802402944578      │ 0.0                        │
└────────────────┴───────┴───────────────┴────────────────────────────┴────────────────────────┴────────────────────────────┘

```

```{admonition} Reading the Exploration Results
:class: tip

**`DELAY 4` is the clear winner:** it achieves the **second-best register-to-register
slack** (+9.76 ns) while maintaining a **significantly smaller area** (256,073 µm²)
than `AREA 3` (309,575 µm²) — the only other strategy with comparable internal slack.
This combination of good timing and compact area makes `DELAY 4` the optimal strategy
for the `aes_wb_wrapper`.
```

---

### 6.2 Final Configuration Setup

With `DELAY 4` confirmed as the best strategy, update `config.json` to add the synthesis
strategy and the two SDC constraint files:

```console
$ gedit ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/config.json
```

```json
{
    "DESIGN_NAME": "aes_wb_wrapper",
    "PDN_MULTILAYER": false,
    "CLOCK_PORT": "wb_clk_i",
    "CLOCK_PERIOD": 25,
    "VERILOG_FILES": [
        "dir::../../../secworks_aes/src/rtl/*.v",
        "dir::../../verilog/rtl/aes_wb_wrapper.v"
    ],
    "PNR_SDC_FILE": "dir::pnr.sdc",
    "SIGNOFF_SDC_FILE": "dir::signoff.sdc",
    "FP_CORE_UTIL": 40,
    "RT_MAX_LAYER": "met4",
    "SYNTH_STRATEGY": "DELAY 4"
}
```

```{note}
`DEFAULT_CORNER` is not yet set in this configuration. We will add it after the first run,
once the pre-{term}`PnR` STA report reveals which corner shows the worst electrical
violations. This is covered in [Section 8.2](#timing-and-electrical-summary).
```

---

### 6.3 Entering the Nix Shell

Before running any LibreLane commands, activate the Nix environment to ensure all EDA
tools (Yosys, OpenROAD, Magic, etc.) are loaded at the correct versions.

```console
$ nix-shell --pure ~/librelane/shell.nix
```

Your prompt will change to `[nix-shell:~]$`, confirming the environment is active.

```{tip}
Always verify you are inside the Nix shell before invoking `librelane`. Commands
executed outside the shell may use incompatible system-level tool versions, producing
non-reproducible results.
```

---

### 6.4 Flow Execution

Execute the following command. The `--to` flag halts the flow after
`Odb.AddRoutingObstructions` — the final step of the Power Network phase, which prepares
the design for placement in Module 2.

```console
[nix-shell:~]$ librelane \
    --run-tag classic_flow \
    --to Odb.AddRoutingObstructions \
    ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/config.json
```

---

### 6.5 Output Directory Structure

Upon execution, LibreLane generates a structured run directory inside `runs/`. Each stage
is captured in a numbered subdirectory, providing full traceability of every design
transformation.

```text
runs/
└── classic_flow/
    ├── 01-verilator-lint/
    ├── 02-checker-linttimingconstructs/
    ├── 03-checker-linterrors/
    ├── 04-checker-lintwarnings/
    ├── 05-yosys-jsonheader/
    ├── 06-yosys-synthesis/
    ├── 07-checker-yosysunmappedcells/
    ├── 08-checker-yosyssynthchecks/
    ├── 09-checker-netlistassignstatements/
    ├── 10-openroad-checksdcfiles/
    ├── 11-openroad-checkmacroinstances/
    ├── 12-openroad-staprepnr/
    ├── 13-openroad-floorplan/
    ├── 14-odb-checkmacroantennaproperties/
    ├── 15-odb-setpowerconnections/
    ├── 16-openroad-cutrows/
    ├── 17-openroad-tapendcapinsertion/
    ├── 18-odb-addpdnobstructions/
    ├── 19-openroad-generatepdn/
    ├── 20-odb-removepdnobstructions/
    ├── 21-odb-addroutingobstructions/   ← Run stops here
    ⋮
    ├── final/
    ├── tmp/
    ├── error.log
    ├── info.log
    ├── resolved.json
    └── warning.log
```

```{note}
Always inspect `error.log` first after a failed run to identify the root cause.
If the flow completes but metrics (Slack, Area) are suboptimal, review `warning.log`
for non-fatal issues that may have affected downstream optimisation.
```

#### Step-Level Artifacts

Each numbered subdirectory contains the specific inputs, outputs, and metadata for
that transformation step:

| File | Description |
| :--- | :--- |
| `COMMANDS` | Transcript of the exact shell or Tcl commands executed by this step. |
| `config.json` | The specific subset of variables and constraints applied to this step. |
| `state_in.json` | Metadata describing the incoming layout format and design metrics. |
| `state_out.json` | Updated dictionary reflecting newly generated artifacts and metrics. |
| `*.log` | Raw output logs from the underlying tool engine (Yosys, OpenROAD, etc.). |
| `*.process_stats.json` | Hardware resource utilisation and execution time telemetry. |
| `[design].nl.v` | Structural gate-level netlist (power pins excluded). |
| `[design].pnl.v` | Physical gate-level netlist (power and ground pins included). |
| `[design].odb` | Design state in the native OpenROAD binary database format. |
| `[design].def` | Design state in the industry-standard {term}`DEF` (Design Exchange Format). |
| `[design].sdc` | {term}`SDC` constraints applied for timing and clocking at this step. |

---

## 7. Viewing the Layout

### 7.1 Viewing the Layout in KLayout

KLayout is the standard tool for high-resolution inspection of metal layers and the
final {term}`GDSII`/{term}`DEF` structure.

```console
[nix-shell:~]$ librelane --last-run --flow openinklayout ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/config.json
```

Explore the GUI to verify the automated physical infrastructure of the macro:

- **Tap Cells:** Placed at regular intervals to prevent latch-up by biasing substrate/n-wells.
- **Decap Cells:** Fill row gaps to provide a local charge reservoir and reduce supply noise.
- **Power Straps:** Verify that **Metal 4** vertical straps are present and **Metal 5**
  horizontal straps are *absent* — confirming that `PDN_MULTILAYER: false` was applied.

---

### 7.2 Inspecting via OpenROAD GUI

```console
[nix-shell:~]$ librelane --last-run --flow openinopenroad ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/config.json
```

```{figure} ./figures/OpenROAD.png
:align: center

*OpenROAD GUI — Physical Design Inspection Interface*
```

The interface is organised into three primary panels:

- **Display Control (LHS):** Toggle visibility of design layers — Metal layers, Nets,
  Instances, Blockages. Includes Heatmaps for congestion and power density analysis.
- **Inspector Window (RHS):** Displays properties (coordinates, layer, connectivity) of
  selected design objects and detailed Timing Reports.
- **Main Layout View:** Central canvas for zooming into pin spacing, track alignment, and
  cell placement.

#### Tcl Command Interface

OpenROAD is built on a Tcl-based architecture. Every GUI action can also be executed via
the **Tcl Console** at the bottom of the screen — essential for scripted debugging.

**Area Analysis:**

```tcl
report_design_area
```

```text
Design area 256073 um^2 40% utilization.
```

**Power Analysis:**

```tcl
report_power
```

```text
Group                  Internal  Switching    Leakage      Total
                          Power      Power      Power      Power (Watts)
----------------------------------------------------------------
Sequential             4.94e-03   2.27e-05   3.68e-08   4.97e-03  63.0%
Combinational          1.62e-03   1.30e-03   8.42e-08   2.92e-03  37.0%
Clock                  0.00e+00   0.00e+00   1.91e-09   1.91e-09   0.0%
Macro                  0.00e+00   0.00e+00   0.00e+00   0.00e+00   0.0%
Pad                    0.00e+00   0.00e+00   0.00e+00   0.00e+00   0.0%
----------------------------------------------------------------
Total                  6.56e-03   1.32e-03   1.23e-07   7.89e-03 100.0%
                          83.2%      16.8%       0.0%
```

---

## 8. Check the Reports

After executing the flow, inspecting the generated reports is essential for verifying
design health. These files provide insight into syntax correctness, timing performance,
electrical integrity, and power distribution quality.

---

### 8.1 Syntax and Linting Checks

The first step of the flow performs a strict linting check. Any critical errors detected
at this stage will cause an immediate exit to prevent downstream propagation.

- **Location:** `runs/classic_flow/01-verilator-lint/verilator-lint.log`
- **Action:** Open this log if the flow crashes at startup. Search for `Error` to identify
  syntax mismatches or unsupported Verilog constructs.

---

### 8.2 Timing and Electrical Summary

The **Pre-{term}`PnR` {term}`STA`** report provides the first snapshot of timing health
across all {term}`PVT` corners, based on the synthesised netlist without physical wire
parasitics.

- **Location:** `runs/classic_flow/12-openroad-staprepnr/summary.rpt`

```text
┏━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━┓
┃                      ┃ Hold     ┃ Reg to   ┃          ┃          ┃ of which  ┃ Setup    ┃           ┃          ┃           ┃ of which ┃           ┃          ┃
┃                      ┃ Worst    ┃ Reg      ┃          ┃ Hold Vio ┃ reg to    ┃ Worst    ┃ Reg to    ┃ Setup    ┃ Setup Vio ┃ reg to   ┃ Max Cap   ┃ Max Slew ┃
┃ Corner/Group         ┃ Slack    ┃ Paths    ┃ Hold TNS ┃ Count    ┃ reg       ┃ Slack    ┃ Reg Paths ┃ TNS      ┃ Count     ┃ reg      ┃ Violatio… ┃ Violati… ┃
┡━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━┩
│ Overall              │ -0.7039  │ 0.1242   │ -184.11… │ 1167     │ 0         │ 9.0038   │ 9.7665    │ 0.0000   │ 0         │ 0        │ 36        │ 2377     │
│ nom_tt_025C_1v80     │ -0.6583  │ 0.2630   │ -130.68… │ 389      │ 0         │ 11.3333  │ 17.3576   │ 0.0000   │ 0         │ 0        │ 16        │ 1373     │
│ nom_ss_100C_1v60     │ -0.4039  │ 0.7043   │ -51.3690 │ 389      │ 0         │ 9.0038   │ 9.7665    │ 0.0000   │ 0         │ 0        │ 36        │ 2377     │
│ nom_ff_n40C_1v95     │ -0.7039  │ 0.1242   │ -184.11… │ 389      │ 0         │ 11.2064  │ 20.1298   │ 0.0000   │ 0         │ 0        │ 16        │ 1167     │
└──────────────────────┴──────────┴──────────┴──────────┴──────────┴───────────┴──────────┴───────────┴──────────┴───────────┴──────────┴───────────┴──────────┘
```

```{note}
**Interpreting this report:**

- **Hold violations** are present across all corners. These are **expected and normal
  at the pre-placement stage** — they will be systematically resolved during Clock Tree
  Synthesis ({term}`CTS`) in Module 2.

- **Setup violations** (Setup Vio Count = 0) are absent. This confirms the AES core's
  critical path meets the 40 MHz target clock after applying `DELAY 4` synthesis.

- **Max Slew and Max Cap violations** vary significantly across corners. Notice that
  the `nom_ss_100C_1v60` (Slow-Slow) corner shows the **worst counts** — 36 Max Cap
  and 2,379 Max Slew violations. This is because slower gates and lower voltages
  produce slower signal transitions and higher effective net loads.

- **Corner coverage:** The pre-{term}`PnR` STA analyses **3 corners**. In later
  stages (post-CTS, post-routing, signoff), the tool expands to **9 corners** for
  a more comprehensive {term}`PVT` sweep.
```

**Why we set `DEFAULT_CORNER: "max_ss_100C_1v60"`:**

The Slow-Slow corner (`nom_ss_100C_1v60`) produces the highest number of Max Cap and
Max Slew violations by a significant margin. By adding the following to `config.json`,
we instruct the tool to **optimise and repair against this worst-case corner** first —
ensuring the design is robust before being validated on other corners:

```json
"DEFAULT_CORNER": "max_ss_100C_1v60"
```

Add this line to your `config.json` now. Your complete configuration for Module 2 onward
will be:

```json
{
    "DESIGN_NAME": "aes_wb_wrapper",
    "PDN_MULTILAYER": false,
    "CLOCK_PORT": "wb_clk_i",
    "CLOCK_PERIOD": 25,
    "VERILOG_FILES": [
        "dir::../../../aes/secworks_aes/rtl/*.v",
        "dir::../../verilog/rtl/aes_wb_wrapper.v"
    ],
    "PNR_SDC_FILE": "dir::pnr.sdc",
    "SIGNOFF_SDC_FILE": "dir::signoff.sdc",
    "DEFAULT_CORNER": "max_ss_100C_1v60",
    "FP_CORE_UTIL": 40,
    "RT_MAX_LAYER": "met4",
    "SYNTH_STRATEGY": "DELAY 4"
}
```

---

### 8.3 Detailed Multi-Corner Analysis

For an in-depth timing investigation, navigate to the subdirectories within
`12-openroad-staprepnr/`. Each subdirectory corresponds to a distinct {term}`PVT` corner:

| Corner Directory | Description |
| :--- | :--- |
| `nom_ff_n40C_1v95` | **Fast-Fast** corner — best-case (low temperature, high voltage). |
| `nom_ss_100C_1v60` | **Slow-Slow** corner — worst-case (high temperature, low voltage). |
| `nom_tt_025C_1v80` | **Typical-Typical** corner — nominal operating conditions. |

Each corner directory contains the following critical reports:

| File | Description |
| :--- | :--- |
| `wns.max.rpt` / `wns.min.rpt` | Worst Negative Slack for Setup (Max) and Hold (Min) paths. |
| `tns.max.rpt` / `tns.min.rpt` | Total Negative Slack across all failing paths. |
| `violator_list.rpt` | Categorised list of all nets and pins failing timing constraints. |
| `power.rpt` | Detailed power breakdown: Internal, Switching, and Leakage. |
| `checks.rpt` | Reports on unconstrained pins, multiple clock domains, or missing arrival times. |
| `max.rpt` / `min.rpt` | Path-by-path reports for the worst-case Setup and Hold paths. |
| `skew.max.rpt` | Clock skew analysis across the clock tree. |
| `sta.log` | Raw output log of the OpenROAD {term}`STA` engine for this corner. |
| `aes_wb_wrapper.sdf` | Standard Delay Format file for back-annotation of timing delays. |

---

### 8.4 Power Distribution Network ({term}`PDN`) Integrity

After generating the power grid, verify there are no connectivity issues in the
power/ground straps.

- **VPWR Errors:** `runs/classic_flow/19-openroad-generatepdn/VPWR-grid-errors.rpt`
- **VGND Errors:** `runs/classic_flow/19-openroad-generatepdn/VGND-grid-errors.rpt`

```{warning}
If either of these files contains entries, parts of your power grid are not properly
connected to the main supply rails. This is a critical electrical integrity issue that
**must be resolved before proceeding to Placement and Routing**.
```

---

```{glossary}
RTL
  Register-Transfer Level. An abstraction of a digital circuit describing data flow between registers and the logic operations performed on that data.

GDSII
  Graphic Database System II. The standard binary file format used to represent the final physical layout of an integrated circuit, delivered to the foundry for fabrication.

EDA
  Electronic Design Automation. Software tools used to design, verify, and analyze electronic systems, including ICs and PCBs.

SDC
  Synopsys Design Constraints. An industry-standard Tcl-based format for specifying timing and clocking constraints for digital design implementation and analysis.

PnR
  Place and Route. The physical design stage in which synthesized netlist cells are assigned spatial positions (placement) and interconnected with metal wires (routing).

STA
  Static Timing Analysis. A method of validating circuit timing by checking all signal paths against timing constraints without requiring simulation vectors.

PDN
  Power Distribution Network. The network of metal conductors that delivers supply voltage (VDD) and ground (GND) to every cell in the chip.

PVT
  Process, Voltage, Temperature. The three main sources of variation in semiconductor manufacturing that affect circuit performance and are analyzed through multiple design corners.

DRC
  Design Rule Check. A verification step that ensures the physical layout conforms to the foundry's manufacturing constraints.

DEF
  Design Exchange Format. An ASCII file format describing the physical placement and routing of a chip layout, used for data exchange between EDA tools.

LEF
  Library Exchange Format. A file format describing the physical characteristics of standard cells and macros.

LVS
  Layout vs. Schematic. A physical verification step confirming that the fabricated layout matches the intended circuit schematic.

SPICE
  Simulation Program with Integrated Circuit Emphasis. A general-purpose analog circuit simulator used for electrical verification of layouts.

PPA
  Power, Performance, Area. The three primary optimization metrics in VLSI design, representing a fundamental trade-off space.

WNS
  Worst Negative Slack. The most critical timing violation in a design — the largest magnitude of negative slack across all timing paths.

TNS
  Total Negative Slack. The sum of all negative slack values across failing timing paths.

CTS
  Clock Tree Synthesis. The physical design step that builds a balanced clock distribution network to minimize clock skew across all sequential elements.

timing closure
  The process of iteratively adjusting a design's implementation until all timing constraints are met across all required PVT corners.
```

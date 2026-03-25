# Module 1: RTL Integration & ASIC Flow for the AES Accelerator

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
   - [Step 3 — Create the Configuration File](#step-3-create-the-configuration-file-config-json)
4. [RTL-to-Power-Grid Configuration Reference](#rtl-to-power-grid-configuration-reference)
   - [4.1 Logic Synthesis Parameters](#logic-synthesis-configuration-reference)
   - [4.2 Floorplan Parameters](#floorplan-configuration-reference)
   - [4.3 Power Distribution Network Parameters](#power-distribution-network-pdn-configuration-reference)
5. [The `librelane` Command Syntax](#the-librelane-command-syntax)
6. [Run 1: Execution to Power Network (Classic Flow)](#run-1-execution-to-power-network-classic-flow)
   - [6.1 Configuration Setup](#configuration-setup)
   - [6.2 Entering the Nix Shell](#entering-the-nix-shell)
   - [6.3 Flow Execution](#flow-execution)
   - [6.4 Output Directory Structure & Artifacts](#output-directory-structure)
7. [Viewing the Layout](#viewing-the-layout)
   - [7.1 KLayout](#viewing-the-layout-in-klayout)
   - [7.2 OpenROAD GUI](#inspecting-via-openroad-gui)
8. [Checking the Reports](#check-the-reports)
9. [Task: Comparative Analysis of Flow Results](#task-comparative-analysis-of-flow-results)

---

## 1. RTL Integration — The Wishbone Wrapper

Before beginning the ASIC flow, we must bridge the gap between the **AES Core** and the **Caravel SoC**. This is accomplished by encapsulating the design inside a **Wishbone Wrapper** (`aes_wb_wrapper.v`) — a standardized communication adapter that allows the Caravel CPU to exchange data with the AES encryption engine using a well-defined bus protocol.

```{note}
In later modules, we will demonstrate how to integrate this complete unit into the **User Project Wrapper**.
For now, the objective is to ensure the AES logic is "Wishbone-ready."
```

### Why Do We Need the Wishbone Wrapper?

| Reason | Explanation |
| :--- | :--- |
| **Standardization** | Adheres to the Wishbone protocol natively understood by the Caravel harness. |
| **Addressability** | Assigns the AES core a specific memory address so the CPU can locate it on the bus. |
| **Control** | Allows the system to independently reset or clock the AES core. |

---

### 1.1 Architectural Overview

Before writing any code, study the block diagram below. It illustrates how the **AES Core** is encapsulated within the **Wishbone Wrapper**. The wrapper serves as the translation layer, converting standard Wishbone bus signals — such as `wbs_stb_i` and `wbs_dat_i` — into the control signals the AES engine requires.

```{figure} ./figures/aes_wb_wrappre.png
:align: center

*Block diagram of* `aes_wb_wrapper`
```

---

### 1.2 Creating the Verilog Wrapper

Follow the steps below to create the interface file that bridges the AES logic with the Wishbone bus.

#### Step 1 — Initialize the Wrapper File

We use **gedit** (a lightweight graphical text editor) to create the wrapper file. If the file does not already exist, it will be initialized as an empty document.

Open your terminal and run:

```console
$ gedit ~/Silicon-Sprint-AUC/verilog/rtl/aes_wb_wrapper.v
```

#### Step 2 — Add the Verilog Implementation

Once the editor opens, paste the Wishbone wrapper implementation into the file. This module manages all communication between the Caravel SoC and the AES core.

After pasting, **save the file** and close the editor.

````{dropdown} aes_wb_wrapper.v — Click to expand
```{literalinclude} ./code/aes_wb_wrapper.v
:language: verilog
:linenos:
```
````


```{tip}
 If you prefer to download the verified source file directly into your code directory, use the link below:

{download}`⬇ Download aes_wb_wrapper.v <./code/aes_wb_wrapper.v>`
```

---

## 2. The LibreLane Classic Flow

The **LibreLane Classic Flow** is a sequential, automated {term}`RTL`-to-{term}`GDSII` pipeline built entirely on open-source {term}`EDA` tools. Each phase of ASIC design — from logic verification through physical signoff — is handled by a specialized tool within a single unified environment.

```{figure} ./figures/flow.webp
:scale: 60 %
:align: center

*LibreLane RTL-to-GDSII Flow*
```

```{admonition} Key Concept — Deterministic Execution
:class: tip

The Classic flow is deterministic and repeatable. Every run follows the same ordered sequence of steps,
making it the ideal starting point for learning the full ASIC design process.
```

---

### 2.1 Flow Step Reference

Each step in the flow carries a unique **Step ID** in the format `ToolName.StepName`. These IDs are not merely descriptive labels — they are consumed directly by the `librelane` command line to start, stop, or skip individual stages (see [Section 5](#the-librelane-command-syntax)).

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
| | Cut Rows for Macro Sites | `OpenROAD.CutRows` |
| | Tap and Endcap Cell Insertion | `OpenROAD.TapEndcapInsertion` |
| **Power Grid** | Add {term}`PDN` Obstructions | `Odb.AddPDNObstructions` |
| | Power Distribution Network Generation | `OpenROAD.GeneratePDN` |
| | Macro Power Connections | `Odb.SetPowerConnections` |
| | Remove PDN Obstructions | `Odb.RemovePDNObstructions` |
| **Placement** | IO Pin Placement | `OpenROAD.IOPlacement` |
| | Custom IO Pin Placement | `Odb.CustomIOPlacement` |
| | Global Placement | `OpenROAD.GlobalPlacement` |
| | Design Repair (Post-GPL) | `OpenROAD.RepairDesignPostGPL` |
| | Mid-{term}`PnR` Static Timing Analysis | `OpenROAD.STAMidPNR` |
| | Detailed Placement | `OpenROAD.DetailedPlacement` |
| **CTS** | Clock Tree Synthesis | `OpenROAD.CTS` |
| | Resizer Timing (Post-CTS) | `OpenROAD.ResizerTimingPostCTS` |
| **Routing** | Global Routing | `OpenROAD.GlobalRouting` |
| | Initial Antenna Check | `OpenROAD.CheckAntennas` |
| | Antenna Repair | `OpenROAD.RepairAntennas` |
| | Resizer Timing (Post-GRT) | `OpenROAD.ResizerTimingPostGRT` |
| | Detailed Routing | `OpenROAD.DetailedRouting` |
| | Final Antenna Check | `OpenROAD.CheckAntennas-1` |
| **Signoff Prep** | Fill Cell Insertion | `OpenROAD.FillInsertion` |
| | Parasitics Extraction | `OpenROAD.RCX` |
| | Post-PnR {term}`STA` | `OpenROAD.STAPostPNR` |
| | IR Drop Reporting | `OpenROAD.IRDropReport` |
| **Physical Signoff** | {term}`GDSII` Stream Out (Magic) | `Magic.StreamOut` |
| | GDSII Stream Out (KLayout) | `KLayout.StreamOut` |
| | Write Macro {term}`LEF` | `Magic.WriteLEF` |
| | XOR GDS Comparison | `KLayout.XOR` |
| | Physical {term}`DRC` (Magic) | `Magic.DRC` |
| | Physical DRC (KLayout) | `KLayout.DRC` |
| | {term}`SPICE` Netlist Extraction | `Magic.SpiceExtraction` |
| | Layout vs. Schematic ({term}`LVS`) | `Netgen.LVS` |
| | Final Manufacturability Report | `Misc.ReportManufacturability` |

---

## 3. Setting Up the Design Environment

This section uses an **Iterative Configuration Strategy**: we begin with the minimum required settings, execute the flow, analyze the generated reports, and progressively refine the configuration based on observed results.

### Step 1 — Create the Design Directory

Create the dedicated folder where LibreLane will look for your `config.json`:

```console
$ mkdir -p ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper
```

---

### Step 2 — Define Timing Constraints ({term}`SDC` Files)

To achieve {term}`timing closure` on a complex design like the AES accelerator, it is strongly recommended to provide design-specific {term}`SDC` files rather than relying on the tool's auto-generated defaults. This is controlled via the **`PNR_SDC_FILE`** and **`SIGNOFF_SDC_FILE`** configuration variables.

```{admonition} Key Concept — The Timing Contract
:class: tip

{term}`SDC` files function as a **"timing contract"** between your {term}`RTL` and the physical implementation
tools. They declare the clock frequency, multicycle paths, and I/O timing requirements that OpenROAD
must satisfy during {term}`PnR`.
```

#### PnR Constraint File (`pnr.sdc`)

Used during **Placement and Routing**. Specifies the clock period, identifies multicycle paths, and establishes {term}`DRC`-related rules such as maximum fanout and signal transition time.

```console
$ gedit ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/pnr.sdc
```

Paste the following code into the editor and save:

````{dropdown} 📄 pnr.sdc — Click to expand
```{literalinclude} ./code/pnr.sdc
:language: verilog
```
````

#### Signoff Constraint File (`signoff.sdc`)

Used for **final timing validation (Signoff)**. Applies more pessimistic derating values and detailed I/O delays to ensure the chip remains functional across {term}`PVT` corners (voltage and temperature variation).

```console
$ gedit ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/signoff.sdc
```

Paste the following code into the editor and save:

````{dropdown} 📄 signoff.sdc — Click to expand
```{literalinclude} ./code/signoff.sdc
:language: tcl
```
````

---

### Step 3 — Create the Configuration File (`config.json`)

The `config.json` file is the **master instruction set** for the LibreLane flow. It specifies which source files to compile, the timing target, the active {term}`PVT` corner, and the paths to the {term}`SDC` constraints.

Create and open the file:

```console
$ gedit ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/config.json
```

Paste the following base configuration:

```json
{
    "DESIGN_NAME": "aes_wb_wrapper",
    "VERILOG_FILES": [
        "dir::../../../secworks_aes/src/rtl/aes.v",
        "dir::../../../secworks_aes/src/rtl/aes_core.v",
        "dir::../../../secworks_aes/src/rtl/aes_decipher_block.v",
        "dir::../../../secworks_aes/src/rtl/aes_encipher_block.v",
        "dir::../../../secworks_aes/src/rtl/aes_inv_sbox.v",
        "dir::../../../secworks_aes/src/rtl/aes_key_mem.v",
        "dir::../../../secworks_aes/src/rtl/aes_sbox.v",
        "dir::../../verilog/rtl/aes_wb_wrapper.v"
    ],
    "CLOCK_PORT": "wb_clk_i",
    "CLOCK_PERIOD": 25,
    "PNR_SDC_FILE": "dir::pnr.sdc",
    "SIGNOFF_SDC_FILE": "dir::signoff.sdc",
    "DEFAULT_CORNER": "max_ss_100C_1v60"
}
```

We explicitly set **`DEFAULT_CORNER`** to the Slow-Slow worst-case corner (`100°C, 1.60V`). Optimizing against the slowest gate performance ensures the design remains robust under the most demanding physical operating conditions.

#### Configuration Variable Reference

| Variable | Value | Description |
| :--- | :--- | :--- |
| `DESIGN_NAME` | `"aes_wb_wrapper"` | Must match the top-level Verilog module name exactly. |
| `VERILOG_FILES` | *(list of paths)* | All {term}`RTL` source files. The `dir::` prefix resolves paths relative to the design directory. |
| `CLOCK_PORT` | `"wb_clk_i"` | The RTL port designated as the primary clock input. |
| `CLOCK_PERIOD` | `25` | Clock period in nanoseconds — **25 ns = 40 MHz**. Initial timing target. |
| `PNR_SDC_FILE` | `"dir::pnr.sdc"` | Path to the {term}`SDC` file used during Placement and Routing. |
| `SIGNOFF_SDC_FILE` | `"dir::signoff.sdc"` | Path to the SDC file used for final timing signoff. |
| `DEFAULT_CORNER` | `"max_ss_100C_1v60"` | Primary {term}`PVT` corner for analysis, prioritizing worst-case conditions. |

```{warning}
**Minimum Required Variables**

Every LibreLane design configuration **must** include the following four variables at a minimum.
The flow will fail at initialization if any are absent:

- `DESIGN_NAME`
- `VERILOG_FILES`
- `CLOCK_PERIOD`
- `CLOCK_PORT`
```

---

## 4. RTL-to-Power-Grid Configuration Reference

This section documents the critical `config.json` parameters that govern the transformation of your {term}`RTL` into a placed design with a robust power distribution network. These settings directly impact the area, timing, and electrical integrity of the `aes_wb_wrapper`.

---

### 4.1 Logic Synthesis Configuration Reference

Synthesis maps your RTL to the **SkyWater 130nm (`sky130_fd_sc_hd`)** standard cell library. The parameters below govern the trade-off between gate count and achievable clock frequency.

| Parameter | Type | Description | Default |
| :--- | :--- | :--- | :--- |
| `SYNTH_STRATEGY` | `str` | Selects the ABC logic synthesis strategy. `AREA 0–3` targets compactness; `DELAY 0–4` targets higher clock frequencies. | `AREA 0` |
| `SYNTH_HIERARCHY_MODE` | `str` | Controls hierarchy handling: `flatten` (merges all modules), `deferred_flatten` (flattens after synthesis), or `keep` (preserves hierarchy). | `flatten` |
| `SYNTH_ABC_BUFFERING` | `bool` | Enables automated cell buffering within ABC to improve signal integrity and timing margins. | `True` |
| `SYNTH_SIZING` | `bool` | Enables ABC cell sizing to optimize gate drive strength. | `False` |
| `SYNTH_SHARE_RESOURCES` | `bool` | Allows Yosys to identify and merge shareable hardware resources (e.g., adders) to reduce total area. | `True` |
| `SYNTH_AUTONAME` | `bool` | Generates human-readable instance names in the netlist. Useful for debugging; may produce long names. | `False` |
| `SYNTH_ELABORATE_ONLY` | `bool` | Performs {term}`RTL` elaboration only, without technology mapping. Use if the Verilog is already gate-level. | `False` |
| `VERILOG_POWER_DEFINE` | `str` | Specifies the macro used to guard power/ground connections in the RTL. | `USE_POWER_PINS` |

---

### 4.2 Floorplan Configuration Reference

These parameters define the physical boundaries of the AES core. Within the Caravel SoC context, correct floorplan settings ensure the macro fits within the designated "User Project" area while preserving adequate routing resources.

| Parameter | Type | Description | Default |
| :--- | :--- | :--- | :--- |
| **`FP_CORE_UTIL`** | `Decimal` | Sets the core utilization percentage. Typical values range from 25% to 60%, with 40% often used as a stable starting point. | `50` |
| **`FP_ASPECT_RATIO`** | `Decimal` | Defines the core's aspect ratio (calculated as height / width). A value of 1 creates a square floorplan. | `1` |
| **`FP_SIZING`** | `str` | Determines the sizing mode. `'relative'` calculates area based on utilization, while `'absolute'` uses fixed user-defined dimensions. | `'relative'` |
| **`DIE_AREA`** | `Tuple?` | Specifies a fixed die boundary as a 4-corner rectangle "x0 y0 x1 y1". This is required when `FP_SIZING` is set to absolute. | `None` |
| **`CORE_AREA`** | `Tuple?` | Explicitly sets the core area boundary (die area minus margins). Must be paired with `DIE_AREA`. | `None` |
| **`BOTTOM_MARGIN_MULT`** | `Decimal` | Sets the bottom core margin in multiples of site heights. This is ignored if `DIE_AREA` and `CORE_AREA` are manually defined. | `4` |
| **`TOP_MARGIN_MULT`** | `Decimal` | Sets the top core margin in multiples of site heights. This is ignored if `DIE_AREA` and `CORE_AREA` are manually defined. | `4` |
| **`LEFT_MARGIN_MULT`** | `Decimal` | Sets the left core margin in multiples of site widths. This is ignored if `DIE_AREA` and `CORE_AREA` are manually defined. | `12` |
| **`RIGHT_MARGIN_MULT`** | `Decimal` | Sets the right core margin in multiples of site widths. This is ignored if `DIE_AREA` and `CORE_AREA` are manually defined. | `12` |

```{admonition} Relative vs. Absolute Floorplan Sizing
:class: note

**Relative Sizing (`"FP_SIZING": "relative"`)** — The default mode. LibreLane calculates chip area
automatically based on gate count and the `FP_CORE_UTIL` percentage. Use this for initial iterations
to find the smallest feasible footprint.

**Absolute Sizing (`"FP_SIZING": "absolute"`)** — Mandatory for fixed-size projects such as the
**Caravel User Project**. Physical coordinates are explicitly declared via `DIE_AREA`
(e.g., `0 0 2920 3520`), ensuring the AES core fits precisely into the pre-defined silicon cavity of the SoC.
```

```{figure} ./figures/floorplan.png
:align: center

*Floorplan Boundary and Margin Visualization*
```
---

### 4.3 Power Distribution Network ({term}`PDN`) Configuration Reference

The {term}`PDN` is the grid of metal conductors delivering `VDD` and `GND` to every standard cell in the design. For the `aes_wb_wrapper`, the PDN must be configured specifically to integrate correctly with the Caravel SoC hierarchy.

#### PDN Control Parameters

| Parameter | Type | Description | Default |
| :--- | :--- | :--- | :--- |
| `FP_PDN_SKIPTRIM` | `bool` | Prevents removal of metal stubs not connected to macros. Disabling this reduces top-level routing congestion. | `False` |
| `FP_PDN_CORE_RING` | `bool` | Generates a power ring around the core area. Required for macros using the "ring method" for power integration. | `False` |
| `FP_PDN_ENABLE_RAILS` | `bool` | Enables creation of standard cell power rails (Metal 1) across every cell row. | `True` |
| `FP_PDN_HORIZONTAL_HALO` | `Decimal` | Horizontal keep-out distance around macros where rows are cut to prevent shorts. | `10 µm` |
| `FP_PDN_VERTICAL_HALO` | `Decimal` | Vertical keep-out distance around macros where rows are cut during power grid insertion. | `10 µm` |

#### SkyWater 130nm PDN Layer Defaults

The following values are the **SkyWater 130nm** defaults used by LibreLane when not explicitly overridden. They ensure compliance with the metal stack rules of the `sky130_fd_sc_hd` library.

| Feature / Layer | Parameter | Default Value | Description |
| :--- | :--- | :--- | :--- |
| **Standard Cell Rail (M1)** | `FP_PDN_RAIL_WIDTH` | **0.48 µm** | Width of the M1 power rail inside each cell row. |
| **Standard Cell Rail (M1)** | `FP_PDN_RAIL_OFFSET` | **0** | Offset for the starting rail position. |
| **Vertical Strap (M4)** | `FP_PDN_VWIDTH` | **1.6 µm** | Width of the main vertical power delivery lines. |
| **Vertical Strap (M4)** | `FP_PDN_VSPACING` | **1.7 µm** | Minimum spacing between parallel vertical straps. |
| **Vertical Strap (M4)** | `FP_PDN_VPITCH` | **153.6 µm** | Center-to-center distance between vertical straps. |
| **Vertical Strap (M4)** | `FP_PDN_VOFFSET` | **16.32 µm** | Distance of the first strap from the left core boundary. |
| **Horizontal Strap (M5)** | `FP_PDN_HWIDTH` | **1.6 µm** | Width of horizontal straps (active when `PDN_MULTILAYER` is `True`). |
| **Horizontal Strap (M5)** | `FP_PDN_HPITCH` | **153.18 µm** | Center-to-center distance between horizontal straps. |
| **Core Ring (M4/M5)** | `CORE_RING_VWIDTH` | **1.6 µm** | Width of the vertical portions of the power ring. |
| **Core Ring (M4/M5)** | `CORE_RING_VOFFSET` | **6.0 µm** | Offset of the ring from the core boundary. |

#### Critical Parameter: `PDN_MULTILAYER`

```{warning}
**`PDN_MULTILAYER` must be set to `False` for Caravel integration.**

Setting this parameter incorrectly is one of the most common causes of fatal {term}`DRC` violations
in user project tape-outs.

- **`True` (Avoid):** The tool generates horizontal straps on **Metal 5**. Since the Caravel wrapper
  also uses Metal 5 for its own power distribution, the macro's straps will short against the wrapper's
  power grid, producing DRC errors that are not resolvable post-routing.

- **`False` (Correct):** The PDN is restricted to **Metal 4 (vertical straps only)**, leaving Metal 5
  entirely available for top-level SoC routing. Horizontal connectivity within the macro is handled
  safely by the M1 standard cell rails.
```

The figures below illustrate the visual difference in KLayout:

::::{grid} 2

:::{grid-item}
```{figure} ./figures/multilayer_true.png
:align: center

**Case A — Avoid:** `PDN_MULTILAYER: True`. A conflicting M4/M5 mesh pattern will cause DRC shorts with the Caravel wrapper.
```
:::

:::{grid-item}
```{figure} ./figures/multilayer_false.png
:align: center

**Case B — Correct:** `PDN_MULTILAYER: False`. Only vertical M4 straps are present; Metal 5 is left clear for top-level routing.
```
:::

::::

For further reading, refer to the [LibreLane PDN documentation](https://librelane.readthedocs.io/en/stable/usage/pdn.html).

---

## 5. The `librelane` Command Syntax

Before issuing any commands, ensure you are inside the Nix shell environment (see [Section 6.2](#entering-the-nix-shell)).

```console
[nix-shell:~]$ librelane [OPTIONS] [CONFIG_FILE]...
```

### Sequential Flow Controls

These options allow you to isolate specific stages without executing the complete flow:

| Option | Description | Example |
| :--- | :--- | :--- |
| `--from <StepID>` | Starts the flow from a specific step. | `--from Checker.LintErrors` |
| `--to <StepID>` | Stops the flow after a specific step completes. | `--to Yosys.Synthesis` |
| `--skip <StepID>` | Bypasses a specific step during execution. | `--skip Checker.LintWarnings` |

### Run Management Options

These options govern how LibreLane saves and organizes output in the `runs/` directory:

| Option | Description |
| :--- | :--- |
| `--run-tag <n>` | Assigns a custom name to the run directory. Essential for preserving and comparing different strategy runs. |
| `--last-run` | Automatically targets the most recently created run directory. |
| `--overwrite` | Overwrites the existing run directory if a matching tag is found. |
| `--with-initial-state <FILE>` | Resumes a previous flow using a specific `state_out.json` as the starting checkpoint. |

### Flow Configuration Modes (`--flow` / `-f`)

The `--flow` flag selects the execution engine and methodology for the run:

| Mode | Description |
| :--- | :--- |
| `classic` | Standard sequential flow. Predictable and step-by-step — the recommended starting point for learning. |
| `SynthesisExploration` | Specialized synthesis flow that automatically iterates through all available `SYNTH_STRATEGY` options to find the best {term}`PPA` results. |
| `openinklayout` | Terminates the flow and opens the current design state in **KLayout** for {term}`GDSII`/{term}`DEF` inspection. |
| `openinopenroad` | Terminates the flow and opens the design in the **OpenROAD GUI** for physical analysis. |

```{tip}
It is highly recommended to run **`--flow SynthesisExploration`** first to identify the optimal strategy for your design.

When starting a new design, finding the best synthesis strategy is essential. Since `AREA` strategies minimize footprint and `DELAY` strategies focus on timing, LibreLane provides an exploration flow to test all options and identify the best fit for your specific design.
```

---

## 6. Run 1: Execution to Power Network (Classic Flow)

In this initial run, we execute the **Classic Flow** up to the completion of the {term}`PDN`. This phase transforms the {term}`RTL` netlist into a floorplanned, placed design with a verified power grid — without yet committing to full routing.

### 6.1 Configuration Setup

Update your `config.json` with the parameters below. We select **`SYNTH_STRATEGY: "DELAY 4"`** to minimize logic depth for timing closure on the AES core, and set **`FP_CORE_UTIL: 40`** to leave sufficient routing headroom.

```json
{
    "DESIGN_NAME": "aes_wb_wrapper",
    "VERILOG_FILES": [
        "dir::../../../secworks_aes/src/rtl/aes.v",
        "dir::../../../secworks_aes/src/rtl/aes_core.v",
        "dir::../../../secworks_aes/src/rtl/aes_decipher_block.v",
        "dir::../../../secworks_aes/src/rtl/aes_encipher_block.v",
        "dir::../../../secworks_aes/src/rtl/aes_inv_sbox.v",
        "dir::../../../secworks_aes/src/rtl/aes_key_mem.v",
        "dir::../../../secworks_aes/src/rtl/aes_sbox.v",
        "dir::../../verilog/rtl/aes_wb_wrapper.v"
    ],
    "CLOCK_PORT": "wb_clk_i",
    "CLOCK_PERIOD": 25,
    "PNR_SDC_FILE": "dir::pnr.sdc",
    "SIGNOFF_SDC_FILE": "dir::signoff.sdc",
    "DEFAULT_CORNER": "max_ss_100C_1v60",
    "PDN_MULTILAYER": false,
    "FP_CORE_UTIL": 40,
    "SYNTH_STRATEGY": "DELAY 4"
}
```

---

### 6.2 Entering the Nix Shell

Before running any LibreLane commands, you must activate the Nix environment to ensure all EDA tools (Yosys, OpenROAD, Magic, etc.) are loaded at the correct, reproducible versions.

```console
$ nix-shell --pure ~/librelane/shell.nix
```

Your prompt will change to `[nix-shell:~]$`, confirming the environment is active.

```{tip}
Always verify you are inside the Nix shell before invoking `librelane`.
Commands executed outside the shell may resolve to incompatible system-level tool versions,
producing non-reproducible results.
```

---

### 6.3 Flow Execution

Execute the following command in your terminal. The `--to` flag halts the flow immediately after the `Odb.RemovePDNObstructions` step, which is the final operation of the Power Network phase.

```console
[nix-shell:~]$ librelane \
    --run-tag classic_to_pdn \
    --to Odb.RemovePDNObstructions \
    ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/config.json
```

---

### 6.4 Output Directory Structure

Upon execution, LibreLane generates a structured run directory inside `runs/`. Each stage of the RTL-to-{term}`GDSII` pipeline is captured in a dedicated, numerically prefixed subdirectory, providing precise traceability of every design transformation.

```text
runs/
└── classic_to_pdn/
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
for non-fatal issues that may have affected downstream optimization.
```

#### Step-Level Artifacts

Each numbered subdirectory contains the specific inputs, outputs, and metadata for that transformation step:

| File | Description |
| :--- | :--- |
| `COMMANDS` | Transcript of the exact shell or Tcl commands executed by this step. |
| `config.json` | The specific subset of variables and constraints applied to this step. |
| `state_in.json` | Metadata describing the incoming layout format and design metrics (e.g., input {term}`DEF`). |
| `state_out.json` | Updated dictionary reflecting newly generated artifacts and metrics (e.g., output DEF). |
| `*.log` | Raw output logs from the underlying tool engine (e.g., Yosys or OpenROAD). |
| `*.process_stats.json` | Hardware resource utilization and execution time telemetry. |
| `[design].nl.v` | Structural gate-level netlist (power pins excluded). |
| `[design].pnl.v` | Physical gate-level netlist (power and ground pins included). |
| `[design].odb` | Design state in the native OpenROAD binary database format. |
| `[design].def` | Design state in the industry-standard {term}`DEF` (Design Exchange Format). |
| `[design].sdc` | {term}`SDC` constraints applied for timing and clocking at this step. |

---

## 7. Viewing the Layout

### 7.1 Viewing the Layout in KLayout

KLayout is the standard tool for high-resolution inspection of metal layers and the final {term}`GDSII`/{term}`DEF` structure. Execute the following command to load the results of your most recent run:

```console
[nix-shell:~]$ librelane --last-run --flow openinklayout ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/config.json
```

Explore the GUI to verify the automated physical infrastructure of the macro. Confirm the presence of the following elements:

- **Tap Cells:** Small cells placed at regular intervals to prevent latch-up by biasing the substrate/n-wells.
- **Decap Cells:** Capacitors filling row gaps to provide a local charge reservoir and reduce supply noise.
- **Power Straps:** Verify that **Metal 4** vertical straps are present and **Metal 5** horizontal straps are *absent*.

---

### 7.2 Inspecting via OpenROAD GUI

To visualize placement density and logical connectivity, launch the OpenROAD interface. This tool is particularly valuable for analyzing the floorplan and verifying cell row alignment.

```console
[nix-shell:~]$ librelane --last-run --flow openinopenroad ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/config.json
```

#### OpenROAD GUI Layout

The OpenROAD GUI provides a real-time graphical representation of the physical design, showing how constraints (such as `DIE_AREA` and pin placements) are being physically implemented.

```{figure} ./figures/OpenROAD.png
:align: center

*OpenROAD GUI — Physical Design Inspection Interface*
```

The interface is organized into three primary panels:

- **Display Control (LHS):** Toggle visibility of specific design layers — Metal layers, Nets, Instances, and Blockages. Includes Heatmaps for analyzing routing congestion and power density.
- **Inspector Window (RHS):** Displays properties (coordinates, layer, connectivity) of selected design objects and shows detailed Timing Reports.
- **Main Layout View:** The central canvas for zooming into pin spacing, track alignment, and cell placement.

#### Tcl Command Interface

OpenROAD is built on a Tcl-based architecture. Every GUI action can also be executed via the **Tcl Console** at the bottom of the screen — essential for scripted debugging or direct database queries.

Type `help` in the console to list all available commands. The two most commonly used diagnostic commands are:

**Area Analysis** — Check current utilization and physical dimensions:

```tcl
report_design_area
```

```text
Design area 256073 um^2 40% utilization.
```

**Power Analysis** — View power consumption broken down by logic group:

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

After executing the flow, inspecting the generated reports is essential for verifying the health of the design. These files provide insight into syntax correctness, timing performance, electrical integrity, and power distribution quality.

### 8.1 Syntax and Linting Checks

The first step of the flow performs a strict linting check. Any critical errors detected at this stage will cause an immediate exit to prevent downstream propagation.

- **Location:** `runs/classic_to_pdn/01-verilator-lint/verilator-lint.log`
- **Action:** Open this log if the flow crashes at startup. Search for `Error` to identify syntax mismatches or unsupported Verilog constructs.

---

### 8.2 Timing and Electrical Summary

The **{term}`STA`** pre-placement report provides a snapshot of the design's timing health across all {term}`PVT` corners.

- **Location:** `runs/classic_to_pdn/12-openroad-staprepnr/summary.rpt`

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
Hold violations, Max Capacitance violations, and Max Slew violations are **expected and normal at
the pre-placement stage**. These are systematically resolved during Clock Tree Synthesis ({term}`CTS`)
and the subsequent Routing stages. The absence of **Setup violations** (Setup Vio Count = 0) confirms
the design's critical path meets the target clock period.
```

---

### 8.3 Detailed Multi-Corner Analysis

For an in-depth timing investigation, navigate to the subdirectories within `12-openroad-staprepnr/`. Each subdirectory corresponds to a distinct {term}`PVT` corner:

| Corner Directory | Description |
| :--- | :--- |
| `nom_ff_n40C_1v95` | **Fast-Fast** corner — best-case (low temperature, high voltage). |
| `nom_ss_100C_1v60` | **Slow-Slow** corner — worst-case (high temperature, low voltage). |
| `nom_tt_025C_1v80` | **Typical-Typical** corner — nominal operating conditions. |

Each corner directory contains the following critical reports:

| File | Description |
| :--- | :--- |
| `wns.max.rpt` / `wns.min.rpt` | Worst Negative Slack for Setup (Max) and Hold (Min) paths. |
| `tns.max.rpt` / `tns.min.rpt` | Total Negative Slack — the sum of all negative slack across the design. |
| `violator_list.rpt` | Categorized list of all nets and pins failing timing constraints. |
| `power.rpt` | Detailed power breakdown: Internal, Switching, and Leakage. |
| `checks.rpt` | Reports on unconstrained pins, multiple clock domains, or missing arrival times. |
| `max.rpt` / `min.rpt` | Detailed path-by-path reports for the worst-case Setup and Hold paths. |
| `skew.max.rpt` | Clock skew analysis across the clock tree (critical for synchronous designs). |
| `sta.log` | Raw output log of the OpenROAD {term}`STA` engine for this corner. |
| `aes_wb_wrappre.sdf` | Standard Delay Format file for back-annotation of timing delays. |

---

### 8.4 Power Distribution Network ({term}`PDN`) Integrity

After generating the power grid, you must verify there are no connectivity issues or disconnected segments in the power/ground straps.

- **VPWR Errors:** `runs/classic_to_pdn/21-openroad-generatepdn/VPWR-grid-errors.rpt`
- **VGND Errors:** `runs/classic_to_pdn/21-openroad-generatepdn/VGND-grid-errors.rpt`

```{warning}
If either of these files contains entries, parts of your power grid are not properly connected
to the main supply rails. This is a critical electrical integrity issue that may result in
non-functional silicon and **must be resolved before proceeding to Placement and Routing**.
```

---

### Task: Running Synthesis Exploration

When running a new design, it’s always good to first find the best synthesis strategy. Synthesis strategies are scripts for the **ABC** utility that handle fine-grained optimization and technology mapping.

You can find a list of available strategies under the `SYNTH_STRATEGY` parameter. Generally, `AREA` strategies result in a smaller footprint, while `DELAY` strategies focus on achieving lower timing slack. Since it is difficult to predict which strategy will yield the best results for a specific design, **LibreLane** provides a synthesis exploration flow that iterates through all of them to compare outcomes.

To run that flow, enter the following command:

```console
[nix-shell:~]$librelane ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/config.json --flow SynthesisExploration

```

**Instructions:**
1. Execute the synthesis exploration flow for your `aes_wb_wrapper`.
2. Observe the results for each strategy in the generated reports.
3. Fill out the table below based on your findings.

```text
┏━━━━━━━━━━━━━━━━┳━━━━━━━┳━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃ SYNTH_STRATEGY ┃ Gates ┃ Area (µm²)    ┃ Worst Register-to-Register Setup Slack (ns) ┃ Worst Setup Slack (ns) ┃ Total -ve Setup Slack (ns) ┃
┡━━━━━━━━━━━━━━━━╇━━━━━━━╇━━━━━━━━━━━━━━━╇━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━━━━━━━━━━━━━━━━━━━┩
│ AREA 0         │       │               │                                             │                        │                            │
│ AREA 1         │       │               │                                             │                        │                            │
│ AREA 2         │       │               │                                             │                        │                            │
│ AREA 3         │       │               │                                             │                        │                            │
│ DELAY 0        │       │               │                                             │                        │                            │
│ DELAY 1        │       │               │                                             │                        │                            │
│ DELAY 2        │       │               │                                             │                        │                            │
│ DELAY 3        │       │               │                                             │                        │                            │
│ DELAY 4        │       │               │                                             │                        │                            │
└────────────────┴───────┴───────────────┴─────────────────────────────────────────────┴────────────────────────┴────────────────────────────┘
```


**Final Analysis:**
Based on the data collected above, which synthesis strategy provides the best balance for your design goals?

* **Selected Best Strategy:** \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_
* **Reasoning:** \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_
---

### Run Management — Avoiding Directory Confusion

```{warning}
**Understanding `--run-tag` Behavior**

When re-running a flow with an existing `--run-tag`, be aware of the following behaviors:

- **`--overwrite`:** Completely replaces the contents of the existing run directory.
  Use this to restart a run cleanly while retaining the same tag name.

- **Without `--overwrite`:** If a matching tag exists, the tool will append new steps
  starting from the next available index (e.g., `22-` if the previous run ended at `21-`).
  This produces a cluttered directory structure and makes results difficult to interpret.

- **New Tag (Recommended):** The cleanest approach for comparing configurations is to
  assign a unique `--run-tag` per experiment (e.g., `optimizing_v2`), creating a fully
  isolated and self-contained output directory.
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

GDSII
  Graphic Database System II. Binary format representing the final IC layout submitted to the foundry.

DEF
  Design Exchange Format. An ASCII file format describing the physical placement and routing of a chip layout, used for data exchange between EDA tools.

LEF
  Library Exchange Format. A file format describing the physical characteristics (geometry, pin locations, metal layers) of standard cells and macros.

LVS
  Layout vs. Schematic. A physical verification step confirming that the fabricated layout matches the intended circuit schematic.

SPICE
  Simulation Program with Integrated Circuit Emphasis. A general-purpose analog circuit simulator used for electrical verification of layouts.

PPA
  Power, Performance, Area. The three primary optimization metrics in VLSI design, representing a fundamental trade-off space.

WNS
  Worst Negative Slack. The most critical timing violation in a design — the largest magnitude of negative slack across all timing paths.

TNS
  Total Negative Slack. The sum of all negative slack values across failing timing paths; a measure of the overall timing health of the design.

CTS
  Clock Tree Synthesis. The physical design step that builds a balanced clock distribution network to minimize clock skew across all sequential elements.
```

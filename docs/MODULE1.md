# Module 1: RTL Integration & ASIC Flow for the AES Accelerator

<div align="justify">

> **Prerequisites:** Before proceeding, ensure your environment is fully prepared by completing all steps in **Module 0**. Your repository must be cloned and the Nix-shell verified before starting the ASIC flow.

---

## Table of Contents

1. [RTL Integration — The Wishbone Wrapper](#1-rtl-integration--the-wishbone-wrapper)
   - [1.1 Architectural Overview](#11-architectural-overview)
   - [1.2 Creating the Verilog Wrapper](#12-creating-the-verilog-wrapper)
2. [The LibreLane Classic Flow](#2-the-librelane-classic-flow)
   - [2.1 Flow Step Reference](#21-flow-step-reference)
   - [2.2 Output Directory Structure](#22-output-directory-structure)
3. [Running the ASIC Flow](#3-running-the-asic-flow)
   - [3.1 Setting Up the Design Environment](#31-setting-up-the-design-environment)
   - [3.2 Environment & Command Reference](#32-environment--command-reference)
   - [3.3 Synthesis Strategy & Execution](#33-synthesis-strategy--execution)

---

## 1. RTL Integration — The Wishbone Wrapper

Before we begin the ASIC flow, we must bridge the gap between the **AES Core** and the **Caravel SoC**.

To do this, we wrap the design inside a **Wishbone Wrapper** (`aes_wb_wrapper.v`). Think of this as a standardized communication adapter. The Wishbone bus allows the Caravel CPU to talk to your AES core — sending data to be encrypted and reading the results back — using a well-defined set of signals.

> 📌 **Context:** In later modules, we will show how to integrate this entire unit into the **User Project Wrapper**. For now, our goal is simply to ensure the AES logic is "Wishbone-ready."

### Why do we need the Wishbone Wrapper?

| Reason | Explanation |
| :--- | :--- |
| **Standardization** | Follows the Wishbone protocol that the Caravel harness understands natively. |
| **Addressability** | Assigns the AES core a specific memory address so the CPU can locate it on the bus. |
| **Control** | Allows the system to independently reset or clock the AES core. |

---

### 1.1 Architectural Overview

Before writing any code, study the block diagram below. It shows how the **AES Core** is encapsulated within the **Wishbone Wrapper**. The wrapper acts as the "middleman," translating standard Wishbone bus signals (such as `wbs_stb_i` and `wbs_dat_i`) into control signals that the AES engine understands.

```{figure} ./figures/aes_wb_wrappre.png
:align: center
Block diagram of aes_wb_wrapper
```

---

### 1.2 Creating the Verilog Wrapper

Follow the steps below to create the interface file that bridges the AES logic with the Wishbone bus.

#### Step 1 — Initialize the Wrapper File

We use **gedit** (a simple graphical text editor) to create the wrapper file. If the file does not already exist, it will be created as an empty document.

Open your terminal and run:

```console
$ gedit ~/Silicon-Sprint-AUC/verilog/rtl/aes_wb_wrapper.v
```

#### Step 2 — Add the Verilog Implementation

Once the editor opens, paste the Wishbone wrapper implementation into the file. This code manages all communication between the Caravel SoC and the AES core.

After pasting, **save the file** and close the editor.

````{dropdown} 📄 aes_wb_wrapper.v — Click to expand
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

The **LibreLane Classic Flow** is a sequential, automated RTL-to-GDSII pipeline built on open-source EDA tools. Each phase of ASIC design — from logic verification through physical signoff — is handled by a specialized tool within a single unified environment.

```{figure} ./figures/flow.webp
:align: center
LibreLane RTL-to-GDSII Flow
```

> 💡 **Key Takeaway:** The Classic flow is deterministic and repeatable. Every run follows the same ordered sequence of steps, making it ideal for learning the full ASIC design process.

---

### 2.1 Flow Step Reference

Each step in the flow has a unique **Step ID** in the format `ToolName.StepName`. These IDs are not just labels — they are used directly in the `librelane` command line to start, stop, or skip specific stages (covered in [Section 3.2](#32-environment--command-reference)).

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
| **Floorplanning** | Validate SDC Constraints | `OpenROAD.CheckSDCFiles` |
| | Validate Macro Instances | `OpenROAD.CheckMacroInstances` |
| | Pre-PnR Static Timing Analysis | `OpenROAD.STAPrePNR` |
| | Initial Floorplan Generation | `OpenROAD.Floorplan` |
| | Cut Rows for Macro Sites | `OpenROAD.CutRows` |
| | Tap and Endcap Cell Insertion | `OpenROAD.TapEndcapInsertion` |
| **Power Grid** | Add PDN Obstructions | `Odb.AddPDNObstructions` |
| | Power Distribution Network Generation | `OpenROAD.GeneratePDN` |
| | Macro Power Connections | `Odb.SetPowerConnections` |
| | Remove PDN Obstructions | `Odb.RemovePDNObstructions` |
| **Placement** | IO Pin Placement | `OpenROAD.IOPlacement` |
| | Custom IO Pin Placement | `Odb.CustomIOPlacement` |
| | Global Placement | `OpenROAD.GlobalPlacement` |
| | Design Repair (Post-GPL) | `OpenROAD.RepairDesignPostGPL` |
| | Mid-PnR Static Timing Analysis | `OpenROAD.STAMidPNR` |
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
| | Post-PnR Static Timing Analysis | `OpenROAD.STAPostPNR` |
| | IR Drop Reporting | `OpenROAD.IRDropReport` |
| **Physical Signoff** | GDSII Stream Out (Magic) | `Magic.StreamOut` |
| | GDSII Stream Out (KLayout) | `KLayout.StreamOut` |
| | Write Macro LEF | `Magic.WriteLEF` |
| | XOR GDS Comparison | `KLayout.XOR` |
| | Physical DRC (Magic) | `Magic.DRC` |
| | Physical DRC (KLayout) | `KLayout.DRC` |
| | SPICE Netlist Extraction | `Magic.SpiceExtraction` |
| | Layout vs. Schematic (LVS) | `Netgen.LVS` |
| | Final Manufacturability Report | `Misc.ReportManufacturability` |

---

## 3. Setting Up the Design Environment

### Step 1 — Create the Design Directory

Create the dedicated folder where LibreLane will look for your `config.json`:

```console
$ mkdir -p ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper
```

---

### Step 2 — Define Timing Constraints (SDC Files)

To achieve timing closure on a complex design like the AES accelerator, we strongly recommend providing design-specific SDC files instead of relying on the tool's auto-generated defaults. This is done using the `PNR_SDC_FILE` and `SIGNOFF_SDC_FILE` configuration variables.

> ⏱️ **Key Concept:** Think of SDC files as a **"timing contract"** between your RTL design and the physical implementation tools. They declare the clock frequency, multicycle paths, and I/O timing requirements that OpenROAD must satisfy.

#### PnR Constraint File (`pnr.sdc`)

Used during **Placement and Routing**. Sets the clock period, identifies multicycle paths, and establishes design rules such as maximum fanout and transition time.

```console
$ gedit ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/pnr.sdc
```

Paste the following code into the editor and save:

````{dropdown} 📄 pnr.sdc — Click to expand
```{literalinclude} ./code/pnr.sdc
:language: tcl
```
````

#### Signoff Constraint File (`signoff.sdc`)

Used for **final timing validation (Signoff)**. Applies more pessimistic derating values and detailed I/O delays to ensure the chip remains functional across voltage and temperature corners.

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

The `config.json` file is the **instruction manual** for the LibreLane flow. It tells the EDA tools which source files to read, what the timing target is, and where to find the SDC constraints.

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
    "SIGNOFF_SDC_FILE": "dir::signoff.sdc"
}
```

The mandatory variables are described below:

| Variable | Value | Description |
| :--- | :--- | :--- |
| `DESIGN_NAME` | `"aes_wb_wrapper"` | Must match the top-level Verilog module name exactly. |
| `VERILOG_FILES` | *(list of paths)* | All RTL source files. The `dir::` prefix resolves paths relative to the design directory. |
| `CLOCK_PORT` | `"wb_clk_i"` | The specific port in the RTL designated as the primary clock input. |
| `CLOCK_PERIOD` | `25` | Clock period in nanoseconds — **25 ns = 40 MHz**. This is the initial timing target. |
| `PNR_SDC_FILE` | `"dir::pnr.sdc"` | Points to the SDC file used during Placement and Routing. |
| `SIGNOFF_SDC_FILE` | `"dir::signoff.sdc"` | Points to the SDC file used for final timing signoff. |

> ⚠️ **Warning — Minimum Required Variables:** Every LibreLane design configuration **must** include the following four variables at a minimum, or the flow will fail at initialization:
> - `DESIGN_NAME`
> - `VERILOG_FILES`
> - `CLOCK_PERIOD`
> - `CLOCK_PORT`

---

## 4 RTL-to-Power-Grid Configuration
This section covers the critical parameters required to transform your Verilog RTL into a placed design with a robust power distribution network. These settings in `config.json` directly impact the area, timing, and electrical integrity of the **aes_wb_wrapper**.

### 4.1 Logic Synthesis Configuration Reference
Synthesis maps your RTL to the **SkyWater 130nm (`sky130_fd_sc_hd`)** library. Tuning these helps balance the trade-off between gate count and clock frequency.

| Parameter | Type | Description | Default |
| :--- | :--- | :--- | :--- |
| `SYNTH_STRATEGY` | `str` | Selects the ABC logic synthesis strategy. `AREA 0–3` targets compactness; `DELAY 0–4` targets higher clock frequencies. | `AREA 0` |
| `SYNTH_HIERARCHY_MODE` | `str` | Controls hierarchy handling: `flatten` (merges all modules), `deferred_flatten` (flattens after synthesis), or `keep` (preserves hierarchy). | `flatten` |
| `SYNTH_ABC_BUFFERING` | `bool` | Enables automated cell buffering within ABC to improve signal integrity and timing margins. | `True` |
| `SYNTH_SIZING` | `bool` | Enables ABC cell sizing alongside buffering to optimize gate drive strength. | `False` |
| `SYNTH_SHARE_RESOURCES` | `bool` | Allows Yosys to identify and merge shareable hardware resources (e.g., adders) to reduce total area. | `True` |
| `SYNTH_AUTONAME` | `bool` | Generates more human-readable instance names in the netlist. Useful for debugging, but can produce very long names. | `False` |
| `SYNTH_ELABORATE_ONLY` | `bool` | Performs RTL elaboration only, without technology mapping. Use if your Verilog is already gate-level. | `False` |
| `VERILOG_POWER_DEFINE` | `str` | Specifies the macro used to guard power/ground connections in the RTL. | `USE_POWER_PINS` |

---
### 4.2 Floorplan Configuration Reference

The following parameters define the physical boundaries of your AES core. In the context of the Caravel SoC, these settings ensure the design fits within the assigned "User Project" area while maintaining enough space for routing.

| Parameter | Type | Description | Default / Recommended |
| :--- | :--- | :--- | :--- |
| **FP_CORE_UTIL** | `Decimal` | Sets the standard cell density as a percentage of the core area. Typical values range from 25% to 60%; **50%** is a stable starting point for the AES core. | `50` |
| **FP_SIZING** | `str` | Determines the sizing mode. `relative` calculates area based on utilization, while `absolute` uses fixed dimensions specified by the user. | `relative` |
| **FP_ASPECT_RATIO** | `Decimal` | Defines the ratio of the core's height to its width. A value of **1** results in a square floorplan. | `1` |
| **CORE_AREA** | `Tuple` | Specifies a specific core boundary (die area minus margins) as a 4-corner rectangle. Must be paired with `DIE_AREA`. | `None` |
| **DIE_AREA** | `Tuple` | Explicitly sets the die area coordinates in the format `x0 y0 x1 y1`. Essential for fixed-size projects like the Caravel wrapper. | `None` |

> **Note: Choosing Between Relative and Absolute Sizing**
>
> * **Relative Sizing (`"FP_SIZING": "relative"`)**: The default mode. LibreLane automatically calculates the chip area based on your gate count and the `FP_CORE_UTIL` percentage. Use this for initial iterations to find the smallest possible footprint.
> * **Absolute Sizing (`"FP_SIZING": "absolute"`)**: Mandatory for fixed-size projects like the **Caravel User Project**. You explicitly define the physical coordinates via the `DIE_AREA` variable (e.g., `0 0 2920 3520`). This ensures your AES core fits perfectly into the pre-defined silicon cavity of the SoC.

---
### 4.3 Power Distribution Network (PDN) Configuration Reference

The Power Distribution Network (PDN) is the grid of metal wires that delivers power (`VDD`) and ground (`GND`) to every standard cell. For the `aes_wb_wrapper`, we must configure the PDN specifically to ensure it integrates into the Caravel SoC.

| Parameter | Type | Description | Default |
| :--- | :--- | :--- | :--- |
| **FP_PDN_SKIPTRIM** | `bool` | Prevents removal of metal stubs not connected to macros. Disabling this helps reduce top-level routing congestion. | `False` |
| **FP_PDN_CORE_RING** | `bool` | Generates a power ring around the core area. Required for macros using the "ring method" for power integration. | `False` |
| **FP_PDN_ENABLE_RAILS** | `bool` | Enables the creation of standard cell power rails (Metal 1) across every row. | `True` |
| **FP_PDN_HORIZONTAL_HALO** | `Decimal` | Sets the horizontal keep-out distance (halo) around macros where rows are cut to prevent shorts. | `10 µm` |
| **FP_PDN_VERTICAL_HALO** | `Decimal` | Sets the vertical keep-out distance (halo) around macros where rows are cut during power grid insertion. | `10 µm` |

The following values are the **SkyWater 130nm** defaults used by the tool if they are not explicitly overridden. These values ensure compliance with the metal stack rules for the `sky130_fd_sc_hd` library.

| Feature / Layer | Parameter | Default Value | Description |
| :--- | :--- | :--- | :--- |
| **Standard Cell Rail (M1)** | `FP_PDN_RAIL_WIDTH` | **0.48 µm** | Width of the M1 rail inside each cell row. |
| **Standard Cell Rail (M1)** | `FP_PDN_RAIL_OFFSET` | **0** | Offset for the starting rail. |
| **Vertical Strap (M4)** | `FP_PDN_VWIDTH` | **1.6 µm** | Width of the main vertical power delivery lines. |
| **Vertical Strap (M4)** | `FP_PDN_VSPACING` | **1.7 µm** | Minimum space between parallel vertical straps. |
| **Vertical Strap (M4)** | `FP_PDN_VPITCH` | **153.6 µm** | Distance between the centers of vertical straps. |
| **Vertical Strap (M4)** | `FP_PDN_VOFFSET` | **16.32 µm** | Distance of the first strap from the left core boundary. |
| **Horizontal Strap (M5)** | `FP_PDN_HWIDTH` | **1.6 µm** | Width of horizontal straps (if `PDN_MULTILAYER` is `True`). |
| **Horizontal Strap (M5)** | `FP_PDN_HPITCH` | **153.18 µm** | Distance between centers of horizontal straps. |
| **Core Ring (M4/M5)** | `CORE_RING_VWIDTH` | **1.6 µm** | Width of the vertical portions of the power ring. |
| **Core Ring (M4/M5)** | `CORE_RING_VOFFSET` | **6.0 µm** | Offset of the ring from the core boundary. |

##### ⚠️ Critical Note: `FP_PDN_MULTILAYER`
Setting **`FP_PDN_MULTILAYER`** to **`False`** is vital for Caravel integration.

* **The Risk (`True`):** The tool creates horizontal straps on **Metal 5**. Since the Caravel wrapper also uses Metal 5, your macro will "short" against the wrapper's power grid, causing fatal DRC violations.
* **The Solution (`False`):** This restricts the macro to **Metal 4 (vertical)**, leaving Metal 5 clear for top-level SoC routing.

**Visualizing in KLayout:**
* **Case A (Multilayer: True):** You will see a "mesh" pattern of crossing Vertical (M4) and Horizontal (M5) straps. **Avoid this.**
* **Case B (Multilayer: False):** You will only see Vertical Straps (M4). Horizontal connectivity is safely handled by the M1 rails. **This is the correct setup for the AES wrapper.**


```{figure} ./figures/multilayer_true.png
:align: centre
KLayout DEF View: Conflicting Multilayer PDN (FP_PDN_MULTILAYER: True)
```

```{figure} ./figures/multilayer_false.png
:align: centre
KLayout DEF View: Optimized Vertical-Only PDN (FP_PDN_MULTILAYER: False)
```
You may review [Power Distribution Networks](https://librelane.readthedocs.io/en/stable/usage/pdn.html) for more information.

---
## 5 The `librelane` Command Syntax

```console
[nix-shell:~]$ librelane [OPTIONS] [CONFIG_FILE]...
```

**Sequential Flow Controls** — Isolate specific stages without running the full flow:

| Option | Description | Example |
| :--- | :--- | :--- |
| `--from <StepID>` | Starts the flow from a specific step. | `--from Checker.LintErrors` |
| `--to <StepID>` | Stops the flow after a specific step completes. | `--to Yosys.Synthesis` |
| `--skip <StepID>` | Bypasses a specific step during execution. | `--skip Checker.LintWarnings` |

**Run Management Options** — Control how LibreLane saves and organizes output:

| Option | Description |
| :--- | :--- |
| `--run-tag <name>` | Assigns a custom name to the run directory. Essential for comparing different strategies side by side. |
| `--last-run` | Automatically targets the most recently created run directory. |
| `--overwrite` | Overwrites the existing run directory if a matching tag is found. |
| `--with-initial-state <FILE>` | Resumes a previous flow using a specific `state_out.json` as the starting point. |

---

#### Flow Configuration Modes (`--flow` / `-f`)

The `--flow` flag selects the underlying execution engine and methodology for the run:

| Mode | Description |
| :--- | :--- |
| `classic` | The standard sequential flow. Predictable, step-by-step — ideal for learning and debugging. |
| `optimizing` | An iterative flow that automatically explores multiple synthesis strategies to improve area and timing results. |
| `openinklayout` | Terminates the flow and opens the current design state in **KLayout** for GDS inspection. |
| `openinopenroad` | Terminates the flow and opens the design in the **OpenROAD GUI** for physical analysis. |

> 💡 **Pro Tip:** Use `--flow classic` for your first run to establish a baseline, then switch to `--flow optimizing` to let the tool search for a better result automatically.

---
## 6 Run 1: Execution to Power Network (Classic Flow)
In this initial run, we execute the **Classic Flow** up to the completion of the Power Distribution Network (PDN). This stage transforms the RTL into a placed design with a verified power grid.

### 6.1 Configuration Setup
Modify your `config.json` with the parameters below. We have selected **`DELAY 4`** as the synthesis strategy to optimize logic depth for the AES core and to achieve timing closure, and set **`FP_CORE_UTIL`** to **40%** to ensure sufficient routing resources for timing closure.

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
    "FP_PDN_MULTILAYER" : false,
    "FP_CORE_UTIL": 40,
    "SYNTH_STRATEGY": "DELAY 4"
}
```
---
### 6.2 Entering the Nix Shell
Before running any LibreLane commands, you must enter the Nix environment to ensure all EDA tools (Yosys, OpenROAD, Magic, etc.) are available at the correct versions.

```console
$ nix-shell --pure ~/librelane/shell.nix
```

Your prompt will change to `[nix-shell:~]$`, confirming you are inside the environment.

> ✅ **Pro Tip:** Always verify you are inside the Nix shell before running `librelane`. Commands executed outside the shell may use incompatible system-level tool versions.

---

### 6.3 Flow Execution
Execute the following command in your terminal. We use the `--to` flag to stop the flow immediately after the PDN obstructions are removed, which is the final step of the Power Network phase.

```console
[nix-shell:~]$ librelane \
    --run-tag classic_to_pdn \
    --to Odb.RemovePDNObstructions \
    ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/config.json
```
---

### 6.4 Output Directory Structure

When the flow runs, LibreLane automatically creates a numbered subdirectory for each step inside the `runs/` folder. The numeric prefix reflects the execution order, making it easy to trace your design's journey from RTL to GDS.

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

> 🔍 **Pro Tip:** After any run, check `error.log` first for critical failures, then `warning.log` for non-fatal issues that may affect downstream stages.


---
## 7 Checking the results
We will now utilize GUI tools to inspect the physical layout and verify the power grid, tap cells, and decoupling capacitors (decaps).

### 7.1 Viewing the Layout in KLayout
KLayout is the standard tool for high-resolution inspection of metal layers and the final GDS/DEF structure. Execute the following command in your terminal to load the results of your most recent run:

```console
[nix-shell:~]$ librelane --last-run --flow openinklayout ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/config.json
```
Explore the GUI to verify the automated physical infrastructure of the macro. Confirm the presence of these key elements:

* **Tap Cells:** Small cells placed at regular intervals to prevent "latch-up" by biasing the substrate/n-wells.
* **Decap Cells:** Capacitors filling row gaps to provide a local charge reservoir and reduce power noise.
* **Power Straps:** Ensure **Metal 4** vertical straps are present and **Metal 5** horizontal straps are absent.
* 
---
### 7.1 Inspecting via OpenROAD GUI
To visualize the design with a focus on placement density and logical connectivity, launch the OpenROAD interface. This tool is particularly useful for analyzing the floorplan and verifying the cell rows.

```console
[nix-shell:~]$ librelane --last-run --flow openinopenroad ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/config.json
```
#### OpenROAD GUI
The OpenROAD GUI is a powerful visualization, analysis, and debugging tool with a customizable Tcl interface. It provides a real-time graphical representation of your physical design, allowing you to see exactly how your constraints (like `DIE_AREA` and pin placements) are being implemented.

* **Display Control (LHS):** Use this window to toggle the visibility of specific design elements. You can show/hide individual **Metal Layers**, **Nets**, **Instances**, or **Blockages**. It also features **Heatmaps** for analyzing congestion and power density.
* **Inspector Window (RHS):** When you select a design object (like a pin or a standard cell), the Inspector provides its specific properties, such as coordinates, layer, and connectivity. It also displays detailed **Timing Reports**.
* **Main Layout View:** The central area where you can zoom in to verify pin spacing and track alignment.

```{figure} ./figures/OpenROAD.png
:align: center
OpenROAD GUI
```

#### Tcl Command Interface
OpenROAD is built on a Tcl-based architecture. Every action performed in the GUI can also be executed via commands in the **Tcl Console** located at the bottom of the screen. This is essential for debugging floorplan scripts or querying the design database directly.

Type `help` in the console to see all available commands. Below are examples of how to verify design metrics:

**1. Area Analysis**
To check the current utilization and physical dimensions, run:
`report_design_area`

> **Output Example:**
```text
Design area 256073 um^2 40% utilization.
```
**2. Power Analysis**
To view a breakdown of power consumption across different logic groups, run:
`report_power`

> **Output Example:**
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
## 8 — Task: Comparative Analysis of Flow Results

In this task, you will evaluate the performance of the **Optimizing Flow** against your previous **Classic Flow**. This comparison is critical for understanding the "PPA" (Power, Performance, Area) trade-offs in VLSI design.

### Objectives
1.  **Execute** the optimization run to generate a secondary dataset.
2.  **Preserve** previous results using unique run tags.
3.  **Compare** key metrics: Power consumption, Total Area, and Timing Slack.

---

### Step 1: Execute the Optimizing Flow
Run the following command in your terminal. Ensure you use the specific `--run-tag` below to keep your directories organized.

```console
[nix-shell:~]$ librelane \
    --flow optimizing \
    --run-tag optimizing_to_pdn \
    --to Odb.RemovePDNObstructions \
    ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/config.json
```

### Step 2: Performance Benchmarking
Complete the following table to visualize the impact of the optimizing flow by comparing the relevant metrics from both run directories:

| Design Metric | Classic Flow (Baseline) | Optimizing Flow | % Difference |
| :--- | :--- | :--- | :--- |
| **Total Area (um²)** | | | |
| **Total Power (Watts)** | | | |
| **Worst Negative Slack (WNS)** | | | |
| **Total Negative Slack (TNS)** | | | |

</div>

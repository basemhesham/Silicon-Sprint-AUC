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

#### Step 3 — Download the Source File *(Optional)*

If you prefer to download the verified source file directly into your code directory, use the link below:

{download}`⬇ Download aes_wb_wrapper.v <./code/aes_wb_wrapper.v>`

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

### 2.2 Output Directory Structure

When the flow runs, LibreLane automatically creates a numbered subdirectory for each step inside the `runs/` folder. The numeric prefix reflects the execution order, making it easy to trace your design's journey from RTL to GDS.

```text
runs/
└── test1/
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

## 3. Running the ASIC Flow

In this section, we execute the LibreLane flow for the `aes_wb_wrapper` design. We follow an **Iterative Configuration Strategy**: start with base requirements, run the flow, analyze the reports, and then tune advanced parameters based on actual results.

---

### 3.1 Setting Up the Design Environment

#### Step 1 — Create the Design Directory

Create the dedicated folder where LibreLane will look for your `config.json`:

```console
$ mkdir -p ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper
```

---

#### Step 2 — Define Timing Constraints (SDC Files)

To achieve timing closure on a complex design like the AES accelerator, we strongly recommend providing design-specific SDC files instead of relying on the tool's auto-generated defaults. This is done using the `PNR_SDC_FILE` and `SIGNOFF_SDC_FILE` configuration variables.

> ⏱️ **Key Concept:** Think of SDC files as a **"timing contract"** between your RTL design and the physical implementation tools. They declare the clock frequency, multicycle paths, and I/O timing requirements that OpenROAD must satisfy.

##### PnR Constraint File (`pnr.sdc`)

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

##### Signoff Constraint File (`signoff.sdc`)

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

#### Step 3 — Create the Configuration File (`config.json`)

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

### 3.2 Environment & Command Reference

#### Entering the Nix Shell

Before running any LibreLane commands, you must enter the Nix environment to ensure all EDA tools (Yosys, OpenROAD, Magic, etc.) are available at the correct versions.

```console
$ nix-shell --pure ~/librelane/shell.nix
```

Your prompt will change to `[nix-shell:~]$`, confirming you are inside the environment.

> ✅ **Pro Tip:** Always verify you are inside the Nix shell before running `librelane`. Commands executed outside the shell may use incompatible system-level tool versions.

---

#### The `librelane` Command Syntax

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

### 3.3 Synthesis Strategy & Execution

Synthesis is the stage where your Verilog RTL is mapped into actual logic gates from the **SkyWater 130nm (`sky130_fd_sc_hd`)** standard cell library. The parameters below can be tuned in `config.json` to balance area, power, and timing for the `aes_wb_wrapper`.

#### Synthesis Configuration Parameters

| Parameter | Type | Description | Default |
| :--- | :--- | :--- | :--- |
| `SYNTH_STRATEGY` | `str` | Selects the ABC logic synthesis strategy. `AREA 0–3` targets compactness; `DELAY 0–4` targets higher clock frequencies. **`DELAY 4` is recommended for AES.** | `DELAY 0` |
| `SYNTH_HIERARCHY_MODE` | `str` | Controls hierarchy handling: `flatten` (merges all modules), `deferred_flatten` (flattens after synthesis), or `keep` (preserves hierarchy). | `flatten` |
| `SYNTH_ABC_BUFFERING` | `bool` | Enables automated cell buffering within ABC to improve signal integrity and timing margins. | `True` |
| `SYNTH_SIZING` | `bool` | Enables ABC cell sizing alongside buffering to optimize gate drive strength. | `False` |
| `SYNTH_SHARE_RESOURCES` | `bool` | Allows Yosys to identify and merge shareable hardware resources (e.g., adders) to reduce total area. | `True` |
| `SYNTH_AUTONAME` | `bool` | Generates more human-readable instance names in the netlist. Useful for debugging, but can produce very long names. | `False` |
| `SYNTH_ELABORATE_ONLY` | `bool` | Performs RTL elaboration only, without technology mapping. Use if your Verilog is already gate-level. | `False` |
| `VERILOG_POWER_DEFINE` | `str` | Specifies the macro used to guard power/ground connections in the RTL. | `USE_POWER_PINS` |

---

#### Run 1 — Classic Flow to Pre-PnR STA

Start by running the Classic flow up to the **Pre-PnR Static Timing Analysis** step. This validates your RTL, synthesizes the design, and gives you the first timing report (Slack and Gate Count) without committing to full physical implementation.

```console
[nix-shell:~]$ librelane \
    --flow classic \
    --run-tag classic_to_staprepnr \
    --to OpenROAD.STAPrePNR \
    ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/config.json
```

After the run completes, examine the timing report in:
```
runs/classic_to_staprepnr/12-openroad-staprepnr/reports/
```

Look for **worst negative slack (WNS)** and **total negative slack (TNS)**. A negative value indicates a timing violation that must be resolved before proceeding to physical design.

---

#### Run 2 — Optimizing Flow for Improved Timing

If the first run shows timing violations or you want to explore a better synthesis result, update `SYNTH_STRATEGY` to `DELAY 4` in your `config.json`, then re-run using the `optimizing` flow:

```console
[nix-shell:~]$ librelane \
    --flow optimizing \
    --run-tag optimizing_to_staprepnr \
    --to OpenROAD.STAPrePNR \
    ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/config.json
```

> 🔁 **Key Takeaway — Comparing Runs:** By using distinct `--run-tag` names (`classic_to_staprepnr` vs. `optimizing_to_staprepnr`), both run directories are preserved side by side. You can directly compare the `reports/` folders of each run to determine which configuration yields better timing closure before investing time in full Place-and-Route.

---

*Proceed to **Module 2** once your Pre-PnR STA reports show no timing violations (WNS ≥ 0).*

</div>

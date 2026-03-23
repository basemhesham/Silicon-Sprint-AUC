# Module 1: RTL Integration and AES Wrapper

<div align="justify">

Before proceeding, ensure your environment is fully prepared by following all steps in **Module 0**. Your repository must be cloned and the Nix-shell verified before you can start the ASIC flow.

---

## 1 RTL integration

Before we begin the ASIC flow, we must bridge the gap between our **AES Core** and the **Caravel SoC**. 

To do this, we wrap the design inside a **Wishbone Wrapper** (`aes_wb_wrapper.v`). Think of this as a standard communication interface. The Wishbone bus allows the Caravel CPU to talk to your AES core—sending data to be encrypted and reading the results back—using a simple set of standardized signals.

In later modules, we will explain how to drop this entire unit into the **User Project Wrapper**, but for now, our focus is on ensuring the AES logic is "Wishbone-ready."

### Why do we need the Wishbone Wrapper?
1.  **Standardization**: It follows a specific protocol that the Caravel harness understands.
2.  **Addressability**: It gives the AES core a specific memory address so the CPU can find it.
3.  **Control**: It allows the system to reset or clock the AES core independently.

---

### 1.1 Architectural Overview

Before writing the code, examine the block diagram below. It illustrates how the **AES Core** is encapsulated within the **Wishbone Wrapper**. The wrapper acts as the "middleman," translating standard Wishbone bus signals (like `wbs_stb_i` and `wbs_dat_i`) into control signals that the AES engine can understand.

```{figure} ./figures/aes_wb_wrappre.png
:align: center
Block diagram of aes_wb_wrapper
```

---

### 1.2 Creating the Verilog Wrapper

To start the integration, you need to create the interface file that bridges the AES logic with the Wishbone bus. This step prepares the "socket" that will hold your encryption engine.

#### Step 1: Initialize the Wrapper File
We will use **gedit**, a simple graphical text editor, to create the wrapper file. Running this command will open a window; if the file does not already exist, it will be created as an empty document.

Open your terminal and run:

```console
$ gedit ~/Silicon-Sprint-AUC/verilog/rtl/aes_wb_wrapper.v
```

#### Step 2: Add the Verilog Implementation
Once the editor opens, paste the Wishbone wrapper implementation into the file. This code manage communication between the Caravel SoC and the AES core.

After pasting the code, save the file and close the editor.

````{dropdown} aes_wb_wrapper.v
   ```{literalinclude} ./code/aes_wb_wrapper.v
    :language: verilog
    :linenos:
   ```
````

#### Step 3: Download the Source (Optional)
If you prefer to download the verified source file directly into your code directory for reference, use the link below:
{download}`Download aes_wb_wrapper.v <./code/aes_wb_wrapper.v>`

---

## 2: The LibreLane Classic Flow

The LibreLane Classic flow is a sequential process that automates the RTL-to-GDSII journey using various open-source EDA tools. This structured approach ensures that each phase of the ASIC design—from logic verification to physical implementation—is handled by specialized tools within a unified environment.

```{figure} ./figures/flow.webp
:align: center
LibreLane flow
```

---

### 2.1 Step IDs
Each step in the flow is identified by a unique Step ID. These IDs typically follow a standard `ToolName.StepName` format. These IDs are not just labels; they are used to control the flow, allowing you to start, stop, or skip specific processes during the workshop.

The table below details the steps included in the default flow, organized by design stage:

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
| | Layout vs. Schematic (Netgen) | `Netgen.LVS` |
| | Final Manufacturability Report | `Misc.ReportManufacturability` |

---

### 2.2 Directory Structure and Execution Order
When running the flow, LibreLane automatically manages the data for you. It creates distinct directories for each step within the runs/ folder. To keep the flow organized and easy to follow, LibreLane uses a numeric prefix that indicates the execution order.

```text
test1
├── 01-verilator-lint
├── 02-checker-linttimingconstructs
├── 03-checker-linterrors
├── 04-checker-lintwarnings
├── 05-yosys-jsonheader
├── 06-yosys-synthesis
├── 07-checker-yosysunmappedcells
├── 08-checker-yosyssynthchecks
├── 09-checker-netlistassignstatements
├── 10-openroad-checksdcfiles
├── 11-openroad-checkmacroinstances
├── 12-openroad-staprepnr
├── 13-openroad-floorplan
├── 14-odb-checkmacroantennaproperties
├── 15-odb-setpowerconnections
⋮
├── final/
├── tmp
├── error.log
├── info.log
├── resolved.json
└── warning.log
```

This numbering ensures that even if you have dozens of steps, you can always see the exact chronological path your design took from Verilog to GDS.

---

## 3 Running the Flow
In this section, we will execute the LibreLane flow specifically for Linting and Synthesis of the aes_wb_wrapper. This ensures our RTL is structurally sound and ready to be mapped into logic gates.

### 3.1 Setting Up the Design Environment

In this workshop, we use an **Iterative Configuration Strategy**. Instead of providing a final, "perfect" configuration file immediately, we start with the **Base Requirements**. We will run the flow, analyze the reports, and then tune advanced parameters based on the specific needs of the `aes_wb_wrapper`.

#### Create the Design Directory
First, create the dedicated folder where LibreLane will look for your `config.json`:

```console
$ mkdir -p ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper
```

#### Defining Design-Specific Constraints (SDC)

To achieve timing closure on a complex design like the AES accelerator, it is highly recommended to use design-specific SDC files rather than relying on the tool's default auto-generation. This is handled using the **PNR_SDC_FILE** and **SIGNOFF_SDC_FILE** variables.

These files act as a "timing contract," ensuring your design can communicate reliably with the Caravel SoC at the required frequency.

##### Create the PnR Constraint File
This file is used during the Placement and Routing stages. It focuses on setting the clock, identifying multicycle paths, and establishing design rules (DRC) like maximum fanout and transition.

Enter the following command to create the file:
```console
gedit ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/pnr.sdc
```
**Paste the following code into the editor and save.**
````{dropdown} pnr.sdc
   ```{literalinclude} ./code/pnr.sdc
    :language: sdc
    :linenos:
   ```
````

##### Create the Signoff Constraint File
This file is used for the final timing validation (Signoff). It includes more pessimistic "derate" values and detailed input/output delays. These are essential to ensure the chip remains functional across different voltage and temperature variations once manufactured.

Enter the following command:
```console
gedit ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/signoff.sdc
```
**Paste the following code into the editor and save.**
````{dropdown} signoff.sdc
   ```{literalinclude} ./code/signoff.sdc
    :language: sdc
    :linenos:
   ```
````

#### Create the Configuration File
Designs in LibreLane are controlled by Configuration Files. These files contain specific variables defined by the user to guide how the EDA tools process the design. Think of the configuration file as the "instruction manual" for the flow; without it, the tools won't know which files to read or what the timing constraints are.

Create an empty `config.json` and open it with your text editor:

```console
$ gedit ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/config.json
```

Paste the following base variables. These are the mandatory settings required to initialize the flow and link your Verilog source files.

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
    "CLOCK_PERIOD": 25
}
```

* **`DESIGN_NAME`**: The name of the top-level Verilog module (`aes_wb_wrapper`).
* **`VERILOG_FILES`**: The list of source files. Note the use of `dir::` to resolve paths relative to the design directory.
* **`CLOCK_PERIOD`**: Set to **25ns** (40MHz). This is our initial target for timing closure.
* **`CLOCK_PORT`**: The specific port in the RTL designated as the primary clock.

```{warning}
(required-variables)=
For any design, at a minimum you need to specify the following variables:
* `DESIGN_NAME`
* `VERILOG_FILES`
* `CLOCK_PERIOD`
* `CLOCK_PORT`
```

---
### 3.2 LibreLane Environment and Command Reference
Before running any LibreLane commands, you must enter the Nix environment to ensure all EDA tools (Yosys, OpenROAD, etc.) are available with the correct versions.

Run the following command in your terminal:
```console
$ nix-shell --pure ~/librelane/shell.nix
```

#### The librelane Command Structure
The primary command to trigger the ASIC flow is `librelane`. It follows a standard syntax where you provide options followed by your design configuration file:

```console
[nix-shell:~]$ librelane [OPTIONS] [CONFIG_FILE]...
```

##### Sequential Flow Controls
These options allow you to isolate specific stages (like Synthesis) without running the entire GDSII flow:

| Option | Description | Example |
| :--- | :--- | :--- |
| **--from <StepID>** | Starts the flow from a specific step ID. | `-from Checker.LintErrors` |
| **--to <StepID>** | Stops the flow after a specific step ID completes. | `--to Yosys.Synthesis` |
| **--skip <StepID>** | Instructs the engine to bypass specific steps during execution. | `-skip Checker.LintTiming` |

##### Run Management Options
These options control how LibreLane saves and organizes your data in the runs/ directory:

| Option | Description |
| :--- | :--- |
| **--run-tag <name>** | Assigns a custom name to the run directory. Crucial for comparing different strategies. |
| **--last-run** | Automatically targets the most recently created run directory. |
| **--overwrite** | Overwrites the existing run directory if a matching tag is found. |
| **--with-initial-state <FILE>** | Uses a specific `state_out.json` as the starting point to resume a previous flow. |

#### Flow Configuration Modes
The `--flow` flag (or `-f`) determines the underlying engine and methodology used for the run.

| Mode | Description |
| :--- | :--- |
| **classic** | The standard, sequential flow that follows a predictable, step-by-step path. |
| **optimizing** | An iterative flow that explores multiple synthesis strategies for better area/timing results. |
| **openinklayout** | Terminates the flow and opens the current design state in **KLayout** for GDS inspection. |
| **openinopenroad** | Terminates the flow and opens the design in the **OpenROAD GUI** for physical analysis. |
---
### 3.3 Synthesis Strategy and Execution

Synthesis is the stage where your high-level Verilog code is mapped into actual logic gates from the SkyWater 130nm library. To achieve the best results for the `aes_wb_wrapper`, we focus on specific parameters that balance area and timing.

#### Key Synthesis Configurations
The following table outlines the critical variables you can adjust in your `config.json` to optimize the synthesis results.

| Parameter | Type | Description | Default |
| :--- | :--- | :--- | :--- |
| **SYNTH_HIERARCHY_MODE** | str | Controls how design hierarchy is handled. Options: `flatten` (merges all modules), `deferred_flatten` (flattens after synthesis), or `keep` (preserves hierarchy). | `flatten` |
| **SYNTH_AUTONAME** | bool | When enabled, generates more human-readable instance names in the netlist. Useful for debugging but can result in very long names. | `False` |
| **SYNTH_STRATEGY** | str | Selects the ABC logic synthesis strategy. `AREA` (0-3) focuses on compactness; `DELAY` (0-4) focuses on higher clock frequencies. **DELAY 4** is recommended for AES. | `DELAY 0` |
| **SYNTH_ABC_BUFFERING** | bool | Enables automated cell buffering within the ABC utility to improve signal integrity and timing. | `True` |
| **SYNTH_SIZING** | bool | Enables ABC cell sizing. This can be used alongside buffering to optimize the drive strength of logic gates. | `False` |
| **SYNTH_SHARE_RESOURCES** | bool | Allows Yosys to identify and merge shareable hardware resources (like adders) to reduce total area. | `True` |
| **SYNTH_ELABORATE_ONLY** | bool | Performs RTL elaboration without technology mapping. Use this if your Verilog is already structural/gate-level. | `False` |
| **VERILOG_POWER_DEFINE** | str | Specifies the macro used to guard power/ground connections in the RTL. | `USE_POWER_PINS` |

---

#### Running the Base Synthesis Flow
We will start by running the "Classic" flow. This includes Linting, Synthesis, and initial Static Timing Analysis (STA) before we move into Physical Design (PnR).

Run the following command to execute the flow up to the Pre-PnR STA stage:
```console
[nix-shell:~]$ librelane --run-tag classic_to_staprepnr Silicon-Sprint-AUC/openlane/aes_wb_wrapper/config.json --to OpenROAD.STAPrePNR
```

#### 3. Optimizing the Flow
After reviewing the logs from the first run (specifically looking at the Slack and Gate Count), you may want to try an optimized version. For example, if the first run had timing violations, ensure `SYNTH_STRATEGY` is set to `DELAY 4` in your `config.json` and run:
```console
[nix-shell:~]$ librelane --flow optimizing --run-tag optimize_to_staprepnr Silicon-Sprint-AUC/openlane/aes_wb_wrapper/config.json --to OpenROAD.STAPrePNR
```
By using different `--run-tag` names, you can easily compare the `reports/` folders of both runs to see which configuration yielded the better results.

</div>

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

## 2: The LibreLane Classic Flow

The LibreLane Classic flow is a sequential process that automates the RTL-to-GDSII journey using various open-source EDA tools. This structured approach ensures that each phase of the ASIC design—from logic verification to physical implementation—is handled by specialized tools within a unified environment.

```{figure} ./figures/flow.webp
:align: center
LibreLane flow
```
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

## 3 Running the Flow
In this section, we will execute the LibreLane flow specifically for Linting and Synthesis of the aes_wb_wrapper. This ensures our RTL is structurally sound and ready to be mapped into logic gates.

### 3.1 Design Configuration
Designs in LibreLane are controlled by Configuration Files. These files contain specific variables defined by the user to guide how the EDA tools process the design. Think of the configuration file as the "instruction manual" for the flow; without it, the tools won't know which files to read or what the timing constraints are.

#### 3.1.1 Required Variables
For any design to successfully initialize in the flow, you must specify a set of core variables. Failure to define these will result in an initialization error.

```{warning}
(required-variables)=
For any design, at a minimum you need to specify the following variables:
* `DESIGN_NAME`
* `VERILOG_FILES`
* `CLOCK_PERIOD`
* `CLOCK_PORT`
```

</div>

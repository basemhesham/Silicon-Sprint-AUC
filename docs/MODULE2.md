# Module 2: Placement, CTS & Timing Optimization

```{admonition} Prerequisites
:class: important

Before proceeding, ensure you have completed **Module 1** and that your Classic Flow run
has finished successfully through step `23-odb-addroutingobstructions`. Your `config.json`
and both {term}`SDC` files (`pnr.sdc`, `signoff.sdc`) must be in place before applying
the changes described in this module.
```

---

## Table of Contents

1. [Placement and I/O Configuration](#placement-and-io-configuration)
   - [1.1 I/O Pin Placement Parameters](#io-and-pin-placement-parameters)
   - [1.2 Custom Pin Ordering for the AES Wrapper](#custom-pin-ordering-for-the-aes-wrapper)
   - [1.3 Global and Detailed Placement](#global-and-detailed-placement)
   - [1.4 Placement Configuration Reference](#placement-configuration-reference)
2. [Clock Tree Synthesis (CTS)](#clock-tree-synthesis-cts)
   - [2.1 CTS Configuration Reference](#clock-tree-synthesis-cts-configuration-reference)
   - [2.2 The CTS Build Process](#the-cts-build-process)
   - [2.3 Post-CTS Timing Repair](#post-cts-timing-repair)
   - [2.4 Timing Verification Checkpoints](#timing-verification-checkpoints)
3. [Optimizing Design Repair and Constraints](#optimizing-design-repair-and-constraints)
   - [3.1 Modified Configuration Parameters](#modified-configuration-parameters)
   - [3.2 Final `config.json`](#final-configjson)
4. [Executing the Placement and CTS Run](#executing-the-placement-and-cts-run)
   - [4.1 Flow Execution](#flow-execution)
   - [4.2 Results](#results)

---

## 1. Placement and I/O Configuration

In this section, we define how the `aes_wb_wrapper` interacts with the outside world
and how its standard cells are physically arranged on the chip. Proper {term}`I/O` pin
placement minimises wire length to the Caravel SoC bus, while a well-configured
placement strategy ensures routing resources are not wasted.

```{note}
Pin placement decisions made at this stage have a direct downstream effect on routing
congestion and wire capacitance. Constraining high-fanout signals like `wbs_dat_o`
to the closest physical edge reduces transition time violations before the Resizer
is even invoked.
```

---

### 1.1 I/O and Pin Placement Parameters

The parameters below govern the physical properties and layer assignments of all
{term}`I/O` pins on the `aes_wb_wrapper` macro. These are consumed by the
`OpenROAD.IOPlacement` step.

| Parameter | Type | Description | Default |
| :--- | :--- | :--- | :--- |
| `IO_PIN_ORDER_CFG` | `Path` | Path to a `.cfg` file defining the cardinal edge assignment for each {term}`I/O` pin. | `None` |
| `FP_IO_HLAYER` | `str` | Metal layer for horizontally-aligned pins (East / West edges). | `met3` |
| `FP_IO_VLAYER` | `str` | Metal layer for vertically-aligned pins (North / South edges). | `met2` |
| `FP_IO_MIN_DISTANCE` | `Decimal` | Minimum distance between adjacent pins to prevent {term}`DRC` violations. | `2 × track_pitch` |
| `FP_IO_HLENGTH` | `Decimal` | Length of pins on East or West edges. | PDK Dependent |
| `FP_IO_VLENGTH` | `Decimal` | Length of pins on North or South edges. | PDK Dependent |

---

### 1.2 Custom Pin Ordering for the AES Wrapper

By default, LibreLane distributes pins evenly across all four edges. For the
`aes_wb_wrapper`, we constrain all Wishbone signals to the **South (bottom)** edge —
the closest boundary to the Caravel management SoC bus — to minimise interconnect
length, reduce capacitive load, and simplify top-level integration.

The `IO_PIN_ORDER_CFG` parameter points to a `.cfg` file that maps pin name patterns
(regular expressions) to cardinal edge identifiers (`#N`, `#S`, `#E`, `#W`).

#### Step 1 — Create the Pin Configuration File

```console
$ gedit ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/pin_order.cfg
```

#### Step 2 — Define the South Edge Pin Assignment

Add the following lines and save the file:

```text
#S
wb_.*
wbs_.*
```

```{admonition} How Pattern Matching Works
:class: tip

`wb_.*` matches all pins beginning with `wb_` (e.g., `wb_clk_i`, `wb_rst_i`).
`wbs_.*` matches all Wishbone subordinate interface pins (e.g., `wbs_stb_i`,
`wbs_dat_i[0:31]`, `wbs_dat_o[0:31]`). Any unmatched pin is placed automatically.
```

#### Step 3 — Add to `config.json`

```json
"IO_PIN_ORDER_CFG": "dir::pin_order.cfg"
```

---

### 1.3 Global and Detailed Placement

Placement is a two-stage process that transforms the synthesised netlist into a
physically legal cell arrangement.

**Global Placement** is an iterative process that strategically distributes standard
cells across the chip's surface to minimise total wire length while simultaneously
"inflating" the area of cells in crowded regions to ensure sufficient space for all
future routing interconnects. At this stage, cells may overlap — this is expected and
intentional.

**Detailed Placement** legalises cell positions by aligning them to the manufacturing
grid and site rows, then optimises wire length through cell mirroring and minimal
displacement to create a physically feasible and efficient layout. After this step,
all overlaps are eliminated and the placement is ready for Clock Tree Synthesis.

```{tip}
You can visually compare both stages in the OpenROAD GUI. The Global Placement state
shows overlapping cells optimised for wire length, while the Detailed Placement state
shows the same cells snapped to legal positions. This comparison is one of the most
instructive visualisations in the entire ASIC flow.
```

---

### 1.4 Placement Configuration Reference

These parameters govern both Global Placement and the Design Repair (Resizer)
optimisations that follow it.

| Parameter | Type | Description | Default |
| :--- | :--- | :--- | :--- |
| `PL_TARGET_DENSITY_PCT` | `Decimal?` | The desired placement density of cells. If not specified, the value will be equal to ( `FP_CORE_UTIL` + 5 * `GPL_CELL_PADDING` + 10). | `None` |
| `GPL_CELL_PADDING ` | `int` | Cell padding value (in sites) for global placement. The number will be integer divided by 2 and placed on both sides.. | `0` |
| `PL_WIRE_LENGTH_COEF` | `Decimal` | Global placement initial wirelength coefficient. Decreasing the variable will modify the initial placement of the standard cells to reduce the wirelengths | `0.25` |
| `PL_TIMING_DRIVEN` | `bool` | Specifies whether the placer should use timing-driven placement. | `false` |
| `PL_ROUTABILITY_DRIVEN` | `bool` | Specifies whether the placer should use routability driven placement. | `True` |
| `PL_SKIP_INITIAL_PLACEMENT` | `bool` | Specifies whether the placer should run initial placement or not. | `False` |
| `DESIGN_REPAIR_MAX_WIRE_LENGTH` | `Decimal` | Specifies the maximum wire length cap used by resizer to insert buffers during design repair. If set to 0, no buffers will be inserted. | `0 µm` |
| `DESIGN_REPAIR_MAX_SLEW_PCT` | `Decimal` | Margin above the slew limit within which the Resizer proactively repairs nets. | `20` |
| `DESIGN_REPAIR_MAX_CAP_PCT` | `Decimal` | Margin above the capacitance limit within which the Resizer proactively repairs nets. | `20` |
| `DESIGN_REPAIR_BUFFER_INPUT_PORTS` | `bool` | Inserts buffers on input ports during design repair. | `True` |
| `DESIGN_REPAIR_BUFFER_OUTPUT_PORTS` | `bool` | Inserts buffers on output ports during design repair. | `True` |
| `DESIGN_REPAIR_REMOVE_BUFFERS` | `bool` | Removes synthesis-inserted buffers before repair, giving the Resizer more flexibility. | `False` |
| `RSZ_DONT_TOUCH_LIST` | `List[str]?` | A list of nets and instances as “don’t touch” by design repairs or resizer optimizations. | `None` |

---

## 2. Clock Tree Synthesis (CTS)

Once placement is finalised, the tool must distribute the clock signal to every
sequential element ({term}`flip-flop`) in the design. **Clock Tree Synthesis
({term}`CTS`)** builds a balanced physical network that minimises {term}`clock skew`
across all **2,995 flip-flops** of the AES core, ensuring reliable operation at
**40 MHz (25 ns)**.

Without a balanced clock tree, flip-flops across the layout receive the clock at
different times. This skew directly causes Hold violations on short paths and degrades
Setup margin on long paths.

---

### 2.1 Clock Tree Synthesis (CTS) Configuration Reference

| Parameter | Type | Description | Default |
| :--- | :--- | :--- | :--- |
| `CTS_CLK_BUFFERS` | `List[str]` | Specific clock buffer cells to be used during {term}`CTS`. | `None` |
| `CTS_ROOT_BUFFER` | `str` | Cell inserted at the root of the clock tree — the first buffer driven by the clock source. | `None` |
| `CTS_CLK_MAX_WIRE_LENGTH` | `Decimal` | Maximum allowable clock wire length (µm) to prevent signal degradation on long branches. | `0 µm` |
| `CTS_SINK_CLUSTERING_ENABLE` | `bool` | Enables pre-clustering of sinks to create one level of sub-tree before building the H-tree. Each cluster is driven by a buffer which becomes the end point of the H-tree structure. | `True` |
| `CTS_SINK_CLUSTERING_SIZE` | `int?` | Specifies the maximum number of sinks per cluster. | `none` |
| `CTS_OBSTRUCTION_AWARE` | `bool?` | Prevents clock buffers from being placed on top of blockages or macros. | `None` |
| `RUN_POST_CTS_RESIZER_TIMING` | `bool` | Enables automated timing optimisations after {term}`CTS` to fix residual violations. | `True` |
| `NON_DEFAULT_RULES` | `dict[str, NDR]?` | Specify non-default rules. Can be used to change the width, spacing and vias of a net. | `None` |
| `CTS_APPLY_NDR` | `str` | Level of NDR application to the clock net: `none`, `root_only`, `half`, or `full`. | `half` |
| `RT_CLOCK_MIN_LAYER` | `str` | The name of lowest layer to be used in routing the clock net. | `None` |
| `RT_CLOCK_MAX_LAYER` | `str` | The name of highest layer to be used in routing the clock net. | `None` |
| `PL_RESIZER_HOLD_SLACK_MARGIN` | `Decimal` | Target positive slack guard-band for Hold repair — the tool over-fixes violations to this margin. | `0.1 ns` |
| `PL_RESIZER_SETUP_SLACK_MARGIN` | `Decimal` | Target positive slack guard-band for setup repair — the tool over-fixes violations to this margin. | `0.05 ns` |
| `PL_RESIZER_ALLOW_SETUP_VIOS` | `bool` | Allows the tool to introduce Setup violations to resolve otherwise unresolvable Hold violations. | `False` |

```{note}
All CTS parameters retain their default values for this workshop run. They are
documented here for reference. The key action in this section is understanding
the CTS *process* — not tuning individual parameters.
```

---

### 2.2 The CTS Build Process

The **TritonCTS** engine constructs the physical clock network through a sequence
of automated sub-steps:

| Sub-step | Description |
| :--- | :--- |
| **1. Topology Generation (H-Tree)** | Constructs a geometrically symmetric H-Tree to equalise propagation delays across the chip area. |
| **2. Sink Clustering** | Groups flip-flop clock pins into spatial clusters, each sized to stay within the capacitive load limit of the selected clock buffers. |
| **3. Buffer Insertion** | Inserts clock buffers at the root and every branch point to maintain signal integrity across all 2,995 flip-flops. |
| **4. Dummy Load Insertion** | Adds dummy capacitive loads to lighter branches to equalise their delay against heavier branches. |
| **5. Post-CTS Legalisation** | Runs a Detailed Placement pass to resolve any cell overlaps introduced by clock buffer insertion. |

---

### 2.3 Post-CTS Timing Repair

After the clock tree is physically built, actual propagation delays to every sink are
known for the first time. The OpenROAD Resizer performs a targeted repair pass in
three phases:

**Setup Repair** — Re-checks all data paths using real clock arrival times. Paths that
now violate Setup are repaired by resizing gates or inserting buffers to shorten the
logical depth.

**Hold Repair** — The most intensive phase. The CTS balancing process shortens clock
paths to some flip-flops, causing data to arrive *too early* relative to the faster
clock edge. The Resizer inserts delay buffers (`dlygate`, `clkdlybuf`) to create the
required hold margin.

**Iterative Optimisation** — The Resizer iterates through repair-then-verify cycles
until all violations are closed or the `PL_RESIZER_HOLD_SLACK_MARGIN` target is met.

```{tip}
A significant increase in total cell count after CTS is **normal and expected** — the
Hold repair phase inserts many delay buffers. For a design of this complexity
(~3,000 flip-flops), several hundred additional buffer cells is typical.
```

---

### 2.4 Timing Verification Checkpoints

LibreLane performs two {term}`STA` checks bracketing the CTS step:

| Checkpoint | When It Runs | What to Expect |
| :--- | :--- | :--- |
| **STAMidPNR-1** | *Before* Post-CTS Resizer | Many **Hold violations** — clock tree inserted, data paths not yet adjusted. This is the expected baseline. |
| **STAMidPNR-2** | *After* Post-CTS Resizer | Hold violations **substantially resolved**. Compare {term}`TNS` across both checkpoints to quantify the repair effectiveness. |

```{admonition} Reading the CTS Reports
:class: tip

Do not be alarmed by a high Hold violation count in `STAMidPNR-1` — it is a direct
consequence of a well-built clock tree. Track whether `STAMidPNR-2` brings Hold
{term}`WNS` to zero or positive. If violations persist, consider increasing
`PL_RESIZER_HOLD_SLACK_MARGIN`.
```

---

## 3. Executing the Placement and CTS Run

### 3.2 Final `config.json`

Open your configuration file to add "IO_PIN_ORDER_CFG": "dir::pin_order.cfg":

```console
$ gedit ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/config.json
```

Your complete `config.json` should now read:

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
    "SYNTH_STRATEGY": "DELAY 4",
    "DEFAULT_CORNER": "max_ss_100C_1v60",
    "RUN_POST_GRT_DESIGN_REPAIR": true,
    "PNR_SDC_FILE": "dir::pnr.sdc",
    "SIGNOFF_SDC_FILE": "dir::signoff.sdc",
    "IO_PIN_ORDER_CFG": "dir::pin_order.cfg"
}
```

---

## 4. Executing the Placement and CTS Run

This run **resumes from the Module 1 checkpoint** at step `23-odb-addroutingobstructions`
using `--with-initial-state`. All synthesis, floorplan, and PDN steps are skipped.
All runs in this workshop use the shared `classic_flow` tag to consolidate output
in a single directory.

---

### 4.1 Flow Execution

Ensure you are inside the Nix shell:

```console
$ nix-shell --pure ~/librelane/shell.nix
```

Then execute:

```console
[nix-shell:~]$ librelane \
    --run-tag classic_flow \
    --from OpenROAD.GlobalPlacementSkipIO \
    --to OpenROAD.STAMidPNR-2 \
    ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/config.json \
    --with-initial-state \
    ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/runs/classic_flow/23-odb-addroutingobstructions/state_out.json
```

```{tip}
The `--from OpenROAD.GlobalPlacementSkipIO` flag tells LibreLane to begin execution
at the Global Placement step (after I/O placement), picking up exactly where the
Module 1 PDN run ended. The `--with-initial-state` flag loads the complete design
state — floorplan, PDN, cell placement — from the specified `state_out.json`.
```

The run will execute through the following key steps before stopping at `STAMidPNR-2`:

```text
runs/classic_flow/
    ⋮
    ├── 24-openroad-globalplacementskipio/   ← Global Placement (wire-length optimised)
    ├── 25-openroad-repairdesignpostgpl/     ← Design Repair using GPL parasitics
    ├── 26-openroad-stamidpnr/               ← Mid-PnR STA (post-placement)
    ├── 27-openroad-detailedplacement/       ← Detailed Placement (legalisation)
    ├── 28-openroad-cts/                     ← Clock tree construction
    ├── 29-openroad-stamidpnr-1/             ← STA before Hold repair
    ├── 30-openroad-resizertiminpostcts/     ← Hold and Setup repair
    ├── 31-openroad-stamidpnr-2/             ← STA after Hold repair
    ⋮
```

---

### 4.2 Results

After the run completes, inspect the physical layout and timing data using the
**OpenROAD GUI**. This section walks through layout verification, clock tree
visualisation, heat map analysis, and timing path inspection.

---

#### Viewing the Layout

Launch the OpenROAD GUI for the last completed run:

```console
[nix-shell:~]$ librelane \
    ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/config.json \
    --last-run \
    --flow openinopenroad
```

```{tip}
**Standard cells not visible?** Press `F` to fit the view, or navigate to **Display
Control → Instances** on the left sidebar and enable the **stdCells** checkbox.
Also verify that Wishbone interface pins appear clustered along the **South (bottom)**
edge — confirming that `pin_order.cfg` was applied correctly.
```

The figure below shows the post-{term}`CTS` layout with standard cells placed and
clock tree buffers distributed throughout the core:

```{figure} ./figures/Post_CTS_layout.png
:align: center

*Post-CTS layout of* `aes_wb_wrapper` *— standard cells placed, Wishbone pins constrained to the South edge.*
```

---

#### Tracing the Clock Tree

**Step 1 — Open the Clock Tree Viewer:**
From the top menu bar, select **Windows → Clock Tree Viewer**.

**Step 2 — Render the tree:**
In the **Clock Tree Viewer** panel on the right-hand side, click **Update** in the
top-right corner to render the full hierarchical H-Tree for `aes_wb_wrapper`.

```{tip}
For a cleaner view, disable all metal layers in **Display Control → Layers** on the
left sidebar. This removes routing clutter, leaving only the clock tree structure
visible in the main canvas.
```

```{figure} ./figures/Clock_Tree_Viewer.png
:align: center

*Clock Tree Viewer — synthesised H-Tree topology for* `aes_wb_wrapper`*, with metal layers hidden.*
```

---

#### Using Heat Maps

OpenROAD provides heat map overlays for analysing the spatial distribution of
placement density and power dissipation.

**Placement Density** — From the menu bar, select **Tools → Heat Maps → Placement Density**.

```{figure} ./figures/Placement_Density_heat_map.png
:align: center

*Placement Density heat map — warmer colours indicate higher standard cell density.*
```

**Power Density** — From **Display Control**, expand **Heat Maps** and select
**Power Density**.

```{figure} ./figures/Power_Density_heat_map.png
:align: center

*Power Density heat map — highlights regions of high switching activity in the AES datapath.*
```

---

#### Inspecting Timing Paths

From the menu bar, select **Windows → Timing Report**.

In the **Timing Report** panel:
1. Select the **Hold** tab to check paths where data arrives too quickly.
2. Click **Paths → Update** and enter an integer number of paths to display.
3. **Positive slack** confirms the design is safe and meets the hold constraint.

```{figure} ./figures/Timing_Report_panel.png
:align: center

*Timing Report panel — ranked list of Hold paths after Post-CTS repair.*
```

The tool inserts **delay gates** (`dlygate`) and **clock-delay buffers** (`clkdlybuf`)
as "speed bumps" to slow data propagation and fix Hold violations. Select any path to
view the full **Data Path Details** showing every gate the signal passes through,
with pin name, cumulative time, delay, slew, and load values.

```{figure} ./figures/Worst_Hold_Path.png
:align: center

*Data Path Details — pin-level breakdown of the worst Hold path after CTS repair.*
```

---

#### Inspecting Intermediate Flow Steps

Any intermediate step can be loaded in the GUI using its `state_out.json` and
`--with-initial-state`. To inspect the design **after Global Placement** — before
Detailed Placement resolves cell overlaps:

```console
[nix-shell:~]$ librelane \
    ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/config.json \
    --flow openinopenroad \
    --with-initial-state \
    ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/runs/classic_flow/24-openroad-globalplacementskipio/state_out.json
```

```{note}
At the Global Placement stage, cell positions are optimised for wire length but
**overlaps are not yet resolved** — this is expected. Detailed Placement (the
following step) legalises the layout by aligning cells to site rows and eliminating
all overlaps. Comparing the two states side by side is one of the most instructive
visualisations in the entire ASIC flow.
```

```{figure} ./figures/Global_Placement_state.png
:align: center

*Global Placement state — cell overlaps visible before Detailed Placement legalisation.*
```

---
### **Timing and Design Rule Reports (Post-Placement/CTS)**

After the completion of the `OpenROAD.STAMidPNR-2` step, we analyze several key reports located in `runs/classic_flow/38-openroad-stamidpnr-2/` to verify the health of the design.

#### **1. Design Rule Violations (DRVs)**
The `checks.rpt` file summarizes the electrical health of the netlist. 

```text
===========================================================================
max slew violation count 256
Writing metric design__max_slew_violation__count__corner:max_ss_100C_1v60: 256
max fanout violation count 0
Writing metric design__max_fanout_violation__count__corner:max_ss_100C_1v60: 0
max cap violation count 0
Writing metric design__max_cap_violation__count__corner:max_ss_100C_1v60: 0
============================================================================
```
```{note}
These calculations are currently based on the `max_ss_100C_1v60` corner. While optimizations target this worst-case scenario now, the final Signoff stage will provide results across all corners (PVT variations).
```

#### **2. Clock Skew Analysis**
Clock skew is the difference in arrival times of the clock signal at different registers.

* **Setup Skew (`skew.max.rpt`):
```text
===========================================================================
Clock Skew (Setup)
============================================================================
Writing metric clock__skew__worst_setup__corner:max_ss_100C_1v60: 0.38285464771012606
======================= max_ss_100C_1v60 Corner ===================================

Clock clk
7.593835 source latency _43010_/CLK ^
-5.955407 target latency _43570_/CLK ^
0.120000 clock uncertainty
-1.375574 CRPR
--------------
0.382855 setup skew

```

```{note}
In setup analysis, the worst skew is theoretically a negative influence on timing. While the tool may display a positive magnitude based on its specific calculation rule, it represents the margin consumed between source and target latencies.
```

* **Hold Skew (`skew.min.rpt`):
```text
===========================================================================
Clock Skew (Hold)
============================================================================
Writing metric clock__skew__worst_hold__corner:max_ss_100C_1v60: -3.2176857644646244
======================= max_ss_100C_1v60 Corner ===================================

Clock clk
6.053021 source latency _45282_/CLK ^
-7.601864 target latency _45282_/CLK ^
-0.120000 clock uncertainty
-1.548843 CRPR
--------------
-3.217686 hold skew
```

#### **3. Slack Analysis**
Slack indicates the margin by which a timing constraint is met (positive) or violated (negative).

| Metric | Report File | Value (ns) |
| :--- | :--- | :--- |
| **Worst Slack (Setup)** | `ws.max.rpt` | **0.158** |
| **Worst Slack (Hold)** | `ws.min.rpt` | **0.897** |

```{note}
The current hold slack of **0.897 ns** is measured at the "Slow-Slow" (SS) corner. During signoff in "Fast-Fast" (FF) corners—where cells are much faster—this margin will decrease significantly, often dropping near **0.2 ns**.
```


```{glossary}
I/O
  Input/Output. The physical pins on a macro or chip boundary through which signals enter and leave the design.

DRC
  Design Rule Check. Verification that the physical layout conforms to the foundry's manufacturing constraints.

STA
  Static Timing Analysis. Timing verification performed by exhaustively checking all signal paths against declared constraints without requiring simulation vectors.

CTS
  Clock Tree Synthesis. The physical design step that constructs a balanced clock distribution network to minimise clock skew across all sequential elements.

SDC
  Synopsys Design Constraints. A Tcl-based format specifying timing and clocking constraints for implementation and static timing analysis.

PnR
  Place and Route. The physical design stage encompassing standard cell placement and signal wire routing.

WNS
  Worst Negative Slack. The largest magnitude of negative slack across all failing timing paths.

TNS
  Total Negative Slack. The arithmetic sum of all negative slack values across every failing timing path.

flip-flop
  A bistable sequential logic element that stores one bit of state, clocked by the design's primary clock signal.

clock skew
  The difference in clock arrival time between two sequential elements. Excessive skew causes Hold violations on short paths and degrades Setup margin on long paths.

PPA
  Power, Performance, Area. The three primary optimisation axes in VLSI design.
```

# Module 2: Placement, CTS & Timing Optimization

```{admonition} Prerequisites
:class: important

Before proceeding, ensure you have completed **Module 1** and that your Classic Flow run
(`classic_to_pdn`) has finished successfully. Your `config.json` and both {term}`SDC` files
(`pnr.sdc`, `signoff.sdc`) must be in place before applying the changes described in this module.
```

---

## Table of Contents

1. [Placement and I/O Configuration](#placement-and-io-configuration)
   - [1.1 I/O and Pin Placement Parameters](#io-and-pin-placement-parameters)
   - [1.2 Custom Pin Ordering for the AES Wrapper](#custom-pin-ordering-for-the-aes-wrapper)
2. [Clock Tree Synthesis (CTS)](#clock-tree-synthesis-cts)
   - [2.1 CTS Configuration Reference](#clock-tree-synthesis-cts-configuration-reference)
   - [2.2 The CTS Build Process](#the-cts-build-process-step-35-openroadcts)
   - [2.3 Post-CTS Timing Repair](#post-cts-timing-repair-step-37-openroadresizertiminpostcts)
   - [2.4 Timing Verification Checkpoints](#timing-verification-checkpoints)
3. [Optimizing Design Repair and Constraints](#optimizing-design-repair-and-constraints)
   - [3.1 Modified Configuration Parameters](#modified-configuration-parameters)
   - [3.2 Final `config.json`](#final-configjson)
4. [Executing the CTS Run](#executing-the-cts-run)
   - [4.1 Flow Execution](#flow-execution)
   - [4.2 Results](#results)

---

## 1. Placement and I/O Configuration

In this section, we define how the `aes_wb_wrapper` interacts with the outside world.
Proper placement of {term}`I/O` pins is critical for two reasons: it minimises the
length of the wires connecting the macro to the Caravel SoC bus, and it ensures the
macro integrates seamlessly into the larger **User Project Wrapper** hierarchy without
introducing {term}`DRC` violations at the interface boundary.

```{note}
Pin placement decisions made at this stage have a direct downstream effect on routing
congestion, wire capacitance, and — as a consequence — the Max Slew violations you
observed in the Module 1 {term}`STA` report. Constraining high-fanout signals like
`wbs_dat_o` to the closest physical edge is one of the primary strategies for reducing
transition time violations before the Resizer is even invoked.
```

---

### 1.1 I/O and Pin Placement Parameters

The parameters below govern the physical properties and layer assignments of all
{term}`I/O` pins on the `aes_wb_wrapper` macro. These are set in `config.json` and
consumed by the `OpenROAD.IOPlacement` step of the LibreLane flow.

| Parameter | Type | Description | Default |
| :--- | :--- | :--- | :--- |
| `IO_PIN_ORDER_CFG` | `Path` | Path to a `.cfg` file defining the specific sequence and cardinal edge assignment for each {term}`I/O` pin. | `None` |
| `FP_IO_HLAYER` | `str` | Metal layer used for horizontally-aligned pins (East / West edges). | `met3` |
| `FP_IO_VLAYER` | `str` | Metal layer used for vertically-aligned pins (North / South edges). | `met2` |
| `FP_IO_MIN_DISTANCE` | `Decimal` | Minimum physical distance between two adjacent pins to prevent {term}`DRC` spacing violations. | `2 × track_pitch` |
| `FP_IO_HLENGTH` | `Decimal` | Length (depth into the core) of pins on the East or West edges. | PDK Dependent |
| `FP_IO_VLENGTH` | `Decimal` | Length (depth into the core) of pins on the North or South edges. | PDK Dependent |

```{note}
We will maintain the default values for `FP_IO_HLAYER`, `FP_IO_VLAYER`,
`FP_IO_MIN_DISTANCE`, `FP_IO_HLENGTH`, and `FP_IO_VLENGTH` throughout this workshop.
Advanced pin placement debugging for specific edge cases is covered in Module 6.
The only parameter we configure here is `IO_PIN_ORDER_CFG`.
```

---

### 1.2 Custom Pin Ordering for the AES Wrapper

By default, LibreLane distributes pins evenly across all four edges of the macro.
For the `aes_wb_wrapper`, this default behaviour is sub-optimal: the Wishbone interface
signals must travel to the management SoC's bus, which resides at the **South (bottom)**
boundary of the User Project area.

Constraining all Wishbone pins to the South edge provides the shortest possible wire
path to the bus, producing measurable downstream benefits:

| Benefit | Mechanism |
| :--- | :--- |
| **Reduced wire length** | Shorter physical distance between pin and destination reduces total interconnect length. |
| **Lower capacitive load** | Wire capacitance scales directly with length — shorter wires mean less capacitance on `wbs_dat_o` and related signals. |
| **Fewer Max Slew violations** | Reduced capacitive load directly improves the signal transition time on the Wishbone data bus. |
| **Cleaner SoC integration** | Aligning the macro's bus interface to the expected edge simplifies routing in the top-level User Project Wrapper. |

The `IO_PIN_ORDER_CFG` parameter accepts a plain-text `.cfg` file that maps pin name
patterns (using regular expressions) to cardinal edge identifiers (`#N`, `#S`, `#E`, `#W`).

---

#### Step 1 — Create the Pin Configuration File

Create a new file named `pin_order.cfg` in your design directory:

```console
$ gedit ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/pin_order.cfg
```

---

#### Step 2 — Define the South Edge Pin Assignment

Add the following lines to assign all Wishbone signals to the South edge. The `#S`
directive instructs the placer to group every pin whose name matches the patterns below
along the bottom edge of the macro, in the order they are listed.

```text
#S
wb_.*
wbs_.*
```

Save the file and close the editor.

```{admonition} How the Pattern Matching Works
:class: tip

Each line after a cardinal direction marker (`#S`, `#N`, `#E`, `#W`) is treated as a
**regular expression** matched against the full pin name list.

- `wb_.*` — matches all pins beginning with `wb_`, such as `wb_clk_i` and `wb_rst_i`.
- `wbs_.*` — matches all Wishbone subordinate interface pins, such as `wbs_stb_i`,
  `wbs_dat_i[0:31]`, and `wbs_dat_o[0:31]`.

Any pin not matched by a pattern in the file is placed by the tool using its default
algorithm. This allows you to constrain only the critical interface signals while
leaving internal signals to automatic placement.
```

---

#### Step 3 — Update `config.json`

Open your configuration file and add the pointer to the new pin order file:

```console
$ gedit ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/config.json
```

Add the following key to your existing configuration:

```json
"IO_PIN_ORDER_CFG": "dir::pin_order.cfg"
```

```{warning}
The `dir::` prefix is mandatory. It instructs LibreLane to resolve the path **relative
to the design directory** (the folder containing `config.json`), rather than treating
it as an absolute system path. Omitting `dir::` will cause a file-not-found error at
the `OpenROAD.IOPlacement` step.
```

---

## 2. Clock Tree Synthesis (CTS)

Once the placement of standard cells is finalised, the tool must distribute the clock
signal to every sequential element ({term}`flip-flop`) in the `aes_wb_wrapper`. This
stage — **Clock Tree Synthesis ({term}`CTS`)** — is critical for minimising {term}`clock skew`
and ensuring the design operates reliably at the target frequency of **40 MHz (25 ns)**.

Without a balanced clock tree, different flip-flops across the layout would receive the
clock at slightly different times. This skew directly causes Hold violations on short
paths and degrades the effective Setup margin on long paths.

---

### 2.1 Clock Tree Synthesis (CTS) Configuration Reference

| Parameter | Type | Description | Default |
| :--- | :--- | :--- | :--- |
| `RUN_CTS` | `bool` | Enables the Clock Tree Synthesis step using the `OpenROAD.CTS` engine. | `True` |
| `CTS_CLK_BUFFERS` | `List[str]` | Defines the specific clock buffer cells to be used during {term}`CTS`. Limiting this to specific drive strengths helps balance the tree. | `None` |
| `CTS_ROOT_BUFFER` | `str` | Specifies the cell to be inserted at the root of the clock tree — the first buffer driven directly by the clock source pin. | `None` |
| `CTS_CLK_MAX_WIRE_LENGTH` | `Decimal` | Maximum allowable wire length for clock nets in microns, preventing signal degradation on long clock branches. | `0 µm` |
| `CTS_SINK_CLUSTERING_SIZE` | `int` | Maximum number of sinks (flip-flop clock pins) allowed in a single cluster during tree construction. | `25` |
| `RUN_POST_CTS_RESIZER_TIMING` | `bool` | Enables automated timing optimisations (resizing and buffering) after {term}`CTS` to fix residual violations. | `True` |
| `NON_DEFAULT_RULES` | `Dict` | Defines custom routing rules (width / spacing) to protect critical nets such as the clock from crosstalk and resistive degradation. | `None` |
| `CTS_APPLY_NDR` | `str` | Level of Non-Default Rule application to the clock net. Valid values: `none`, `root_only`, `half`, `full`. | `none` |
| `RT_CLOCK_MIN_LAYER` | `str` | Lowest metal layer permitted for routing the clock net (e.g., `met3`). | `None` |
| `RT_CLOCK_MAX_LAYER` | `str` | Highest metal layer permitted for routing the clock net. | `None` |
| `PL_RESIZER_HOLD_SLACK_MARGIN` | `Decimal` | Instructs the post-CTS resizer to target a positive slack margin beyond zero, providing extra guard-band against Hold violations. | `0.1 ns` |
| `PL_RESIZER_ALLOW_SETUP_VIOS` | `bool` | Permits the tool to introduce Setup violations if necessary to resolve critical Hold violations that cannot otherwise be closed. | `False` |

```{note}
All CTS parameters listed above retain their default values for this workshop run.
They are documented here for reference and to support independent exploration in
later modules. The key action in this section is understanding the CTS *process*,
not tuning its parameters.
```

---

### 2.2 The CTS Build Process (Step 35: `OpenROAD.CTS`)

The **TritonCTS** engine constructs the physical clock distribution network through
a sequence of automated sub-steps. Understanding this process helps interpret the
timing reports generated immediately after.

| Sub-step | Description |
| :--- | :--- |
| **1. Topology Generation (H-Tree)** | The tool constructs a balanced H-Tree structure ensuring the clock path to every flip-flop is as geometrically symmetric as possible, equalising propagation delays across the chip area. |
| **2. Sink Clustering** | Flip-flop clock pins (sinks) are grouped into spatial clusters. Each cluster is sized to remain within the maximum capacitive load the selected clock buffers can drive (`CTS_SINK_CLUSTERING_SIZE`). |
| **3. Buffer Insertion** | Clock buffers are inserted at the root and at every branch point to maintain signal integrity across the **flip-flops** of the AES core. |
| **4. Dummy Load Insertion** | To keep the tree perfectly balanced, dummy capacitive loads are added to lighter branches, equalising their delay against heavier branches. |
| **5. Post-CTS Legalisation** | The newly inserted clock buffers occupy physical space. A Detailed Placement pass is run to resolve any cell overlaps introduced by buffer insertion. |

---

### 2.3 Post-CTS Timing Repair (Step 37: `OpenROAD.ResizerTimingPostCTS`)

After the clock tree is physically built, actual propagation delays to every sink are
known for the first time. The OpenROAD Resizer then performs a targeted repair pass
in three phases:

**Setup Repair** — The tool re-checks all data paths using the real clock arrival times.
Any data path that now violates Setup (because the clock arrived earlier than expected
at the destination register) is repaired by resizing gates to faster cells or inserting
buffers to shorten the logical depth.

**Hold Repair** — This is the most intensive phase. The CTS balancing process tends to
shorten clock paths to certain flip-flops, causing data to arrive *too early* relative
to the (now faster) clock edge. The Resizer inserts delay buffers on affected data paths
to create the required hold margin.

**Iterative Optimisation** — The Resizer works through multiple repair-then-verify
iterations, recalculating {term}`STA` after each buffer insertion until all violations
are closed or the target margins defined by `PL_RESIZER_HOLD_SLACK_MARGIN` are met.

```{tip}
A significant increase in total cell count between the pre-CTS and post-CTS reports is
**normal and expected**. The Hold repair phase in particular inserts a large number of
delay buffers. For a design of the AES core's complexity (~3,000 flip-flops), an
increase of several hundred buffer cells is typical.
```

---

### 2.4 Timing Verification Checkpoints

LibreLane performs two distinct {term}`STA` checks bracketing the CTS step, giving you
a before-and-after view of the clock tree's impact on timing:

| Checkpoint | Flow Step | When It Runs | What to Expect |
| :--- | :--- | :--- | :--- |
| **STAMidPNR-1** | Step 36 | *Before* Post-CTS Resizer | A significant number of **Hold violations** will be present. The clock tree has been inserted but the data paths have not yet been adjusted to match the new clock arrival times. This is the expected baseline for the repair stage. |
| **STAMidPNR-2** | Step 38 | *After* Post-CTS Resizer | Hold violations should be **substantially resolved**. Comparing the {term}`TNS` and violation count between Step 36 and Step 38 directly quantifies the Resizer's repair effectiveness. |

```{admonition} Key Takeaway — Reading the CTS Reports
:class: tip

When reviewing `STAMidPNR-1`, do not be alarmed by the high Hold violation count —
it is a direct and predictable consequence of a well-built clock tree. The metric
to track is whether `STAMidPNR-2` brings the Hold {term}`WNS` to zero or positive.
If Hold violations persist after Step 38, increasing `PL_RESIZER_HOLD_SLACK_MARGIN`
or adjusting `CTS_SINK_CLUSTERING_SIZE` may be required.
```

---

## 3. Optimizing Design Repair and Constraints

To improve the timing health of the `aes_wb_wrapper`, we must align the tool's
constraints with the physical characteristics of the SkyWater 130nm library.
The three parameters introduced in this section reduce unnecessary buffer insertion,
raise the proactive repair effort, and ensure the final {term}`STA` signoff uses a
constraint boundary that is consistent with how the library was characterised.

---

### 3.1 Modified Configuration Parameters

| Parameter | Default | New Value | Impact |
| :--- | :---: | :---: | :--- |
| `MAX_TRANSITION_CONSTRAINT` | `0.75 ns` | **`1.5 ns`** | Aligns the repair target with the `sky130_fd_sc_hd` Liberty file characterisation boundary, eliminating over-buffering on nets that are compliant with the actual library limit. |
| `DESIGN_REPAIR_MAX_SLEW_PCT` | `20%` | **`40%`** | Increases the proactive slew repair margin, instructing the Resizer to fix paths within 30% of the slew limit — catching borderline paths before post-routing parasitics push them into hard violation. |
| `DESIGN_REPAIR_MAX_CAP_PCT` | `20%` | **`40%`** | Increases the proactive capacitance repair margin, reducing the number of Max Cap violations that emerge after actual wire routing adds real parasitic load. |

```{admonition} When Does MAX_TRANSITION_CONSTRAINT Take Effect?
:class: important

`MAX_TRANSITION_CONSTRAINT` is enforced primarily during the **Post-{term}`PnR` Static
Timing Analysis** (`OpenROAD.STAPostPNR`) — not at the pre-placement stage.

As a result, the **Max Slew violation count** visible in the `12-openroad-staprepnr`
report will not change between runs with different `MAX_TRANSITION_CONSTRAINT` values.
The pre-placement report always compares against the internal default (0.75 ns).

The benefit of setting `MAX_TRANSITION_CONSTRAINT: 1.5` is realised at signoff:
the final Post-PnR STA will flag violations only against the 1.5 ns boundary,
producing a cleaner and more physically accurate timing report.

The two percentage-based margins (`DESIGN_REPAIR_MAX_SLEW_PCT` and
`DESIGN_REPAIR_MAX_CAP_PCT`) **do** affect the Placement and Design Repair phases
and will produce a measurable reduction in violations during those stages.
```

---

### 3.2 Final `config.json`

Add the three optimisation parameters to your existing configuration. Your complete
`config.json` should now read:

```console
$ gedit ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/config.json
```

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
    "SYNTH_STRATEGY": "DELAY 4",
    "IO_PIN_ORDER_CFG": "dir::pin_order.cfg",
    "MAX_TRANSITION_CONSTRAINT": 1.5,
    "DESIGN_REPAIR_MAX_SLEW_PCT": 30,
    "DESIGN_REPAIR_MAX_CAP_PCT": 30
}
```

```{warning}
Do **not** set `MAX_TRANSITION_CONSTRAINT` above 1.5 ns. Values beyond the library's
characterised boundary cause the {term}`STA` engine to extrapolate timing data rather
than interpolate from measured table entries. The resulting reports may appear clean
while masking real silicon-level violations.
```

---

## 4. Executing the CTS Run

We will now execute the full flow from RTL through to the Post-CTS Timing Repair stage.
This run incorporates all three configuration changes from Section 3 and includes the
complete CTS pipeline — covering all **2,995 flip-flops** of the AES core.

---

### 4.1 Flow Execution

Ensure you are inside the Nix shell before proceeding:

```console
$ nix-shell --pure ~/librelane/shell.nix
```

Your prompt should read `[nix-shell:~]$`. Then execute:

```console
[nix-shell:~]$ librelane \
    --run-tag classic_to_cts \
    --to OpenROAD.ResizerTimingPostCTS \
    ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/config.json
```

```{tip}
The `--run-tag classic_to_cts` creates a new, isolated run directory alongside the
Module 1 baseline (`classic_to_pdn`). Both directories are preserved under `runs/`,
allowing direct side-by-side comparison of pre-CTS and post-CTS timing reports.
```

The run will execute through the following key steps before stopping:

```text
runs/classic_to_cts/
    ⋮
    ├── 33-openroad-detailedplacement/
    ├── 34-openroad-cts/                         ← Clock tree construction
    ├── 35-openroad-stamidpnr-1/                 ← STA before Hold repair
    ├── 36-openroad-resizertiminpostcts/         ← Hold and Setup repair
    ├── 37-openroad-stamidpnr-2/                 ← STA after Hold repair
    ⋮
```

---

### 4.2 Results

```{admonition} Results — To Be Completed
:class: note

This section will be populated with the timing summary comparison after the run
completes. Navigate to the following reports to gather your data:

- **Pre-CTS STA:** `runs/classic_to_cts/35-openroad-stamidpnr-1/summary.rpt`
- **Post-CTS STA:** `runs/classic_to_cts/37-openroad-stamidpnr-2/summary.rpt`

Record the Hold {term}`WNS`, Hold {term}`TNS`, and violation counts from both
checkpoints to quantify the effect of the Post-CTS Resizer repair pass.
```

---

```{glossary}
I/O
  Input/Output. The physical pins on a macro or chip boundary through which signals enter and leave the design.

DRC
  Design Rule Check. A verification step confirming the physical layout conforms to the foundry's manufacturing constraints, including minimum spacing between adjacent pins.

STA
  Static Timing Analysis. A method of verifying circuit timing by exhaustively checking all signal paths against declared constraints without requiring simulation vectors.

CTS
  Clock Tree Synthesis. The physical design step that constructs a balanced clock distribution network to minimise clock skew across all sequential elements.

SDC
  Synopsys Design Constraints. A Tcl-based format specifying timing and clocking constraints consumed by the synthesis and implementation tools.

PnR
  Place and Route. The physical design stage encompassing standard cell placement and signal wire routing.

WNS
  Worst Negative Slack. The largest magnitude of negative slack across all failing timing paths — the most critical single timing metric.

TNS
  Total Negative Slack. The arithmetic sum of all negative slack values across every failing timing path.

flip-flop
  A bistable sequential logic element that stores one bit of state, clocked by the design's primary clock signal.

clock skew
  The difference in clock arrival time between two sequential elements in a design. Excessive skew causes Hold violations on short paths and degrades Setup margin on long paths.

PPA
  Power, Performance, Area. The three primary optimisation axes in VLSI design, representing an inherent engineering trade-off.
```

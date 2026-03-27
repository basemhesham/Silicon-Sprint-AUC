# Module 3: Routing and Physical Optimization

```{admonition} Prerequisites
:class: important

Before proceeding, ensure your **Module 2** CTS run (`classic_to_cts`) has completed
successfully. This module resumes the flow from the Post-CTS {term}`STA` checkpoint
using `--with-initial-state`, so no design work needs to be repeated.
```

---

## Table of Contents

1. [Global Routing (GRT)](#global-routing-grt)
   - [1.1 What Global Routing Does](#what-global-routing-does)
   - [1.2 GRT Configuration Reference](#grt-configuration-reference)
2. [Antenna Verification](#antenna-verification)
   - [2.1 What is an Antenna Violation?](#what-is-an-antenna-violation)
   - [2.2 Antenna Repair Strategies](#antenna-repair-strategies)
   - [2.3 Antenna Repair Configuration](#antenna-repair-configuration)
3. [Post-GRT Design Repair](#post-grt-design-repair)
4. [Detailed Routing (DRT)](#detailed-routing-drt)
   - [4.1 What Detailed Routing Does](#what-detailed-routing-does)
   - [4.2 DRT Configuration Reference](#drt-configuration-reference)
5. [Mid-PnR STA (Post-Routing)](#mid-pnr-sta-post-routing)
6. [Configuration Summary & Execution](#configuration-summary-and-execution)
   - [6.1 Key Parameters for This Run](#key-parameters-for-this-run)
   - [6.2 Final `config.json`](#final-configjson)
   - [6.3 Flow Execution](#flow-execution)
7. [Inspecting Routing Results](#inspecting-routing-results)
   - [7.1 Routing Congestion in OpenROAD](#routing-congestion-in-openroad)
   - [7.2 Antenna Summary Report](#antenna-summary-report)

---

## 1. Global Routing (GRT)

### 1.1 What Global Routing Does

Global Routing is the first stage of the routing process.  
Given a **detailed placed ODB design**, the router assigns **coarse routing regions**
for each net so they can later be connected with real metal wires.

At this stage, no physical wires are created yet. The router only generates a
high-level routing plan that helps guide the next routing step.

Global routing also allows the tool to compute **more accurate estimates of
wire resistance and capacitance**, which improves the timing analysis results.

---

### 1.2 GRT Configuration Reference

The following parameters govern the behaviour of the Global Router (`OpenROAD.GlobalRouting`).
All values listed are the defaults used in this workshop run unless explicitly overridden
in Section 6.

| Parameter | Type | Description | Default |
| :--- | :--- | :--- | :--- |
| `GRT_ADJUSTMENT` | `Decimal` | Reduction in the routing capacity of the edges between the cells in the global routing graph for all layers. Values range from 0 to 1. 1 = most reduction, 0 = least reduction. | `0.3` |
| `GRT_ALLOW_CONGESTION` | `bool` | If `True`, allows the router to proceed even if congestion overflows remain unresolved. Useful for highly congested designs where zero overflow is unachievable at the global stage. | `False` |
| `GRT_OVERFLOW_ITERS` | `int` | Maximum iterations the global router will attempt to resolve routing overflow before stopping. | `50` |
| `RT_MAX_LAYER` | `str` | The highest metal layer available for signal routing. | met5 |
| `RT_MIN_LAYER` | `str` | The lowest metal layer available for signal routing. | met1 |
| `RUN_POST_GRT_RESIZER_TIMING` | `bool` | Enables resizer timing optimizations after Global Routing (`OpenROAD.ResizerTimingPostGRT`). Uses real RC parasitics from GRT for more accurate repair. **Experimental — may increase run time significantly.** | `False` |
| `RUN_HEURISTIC_DIODE_INSERTION` | `bool` | Enables the `Odb.HeuristicDiodeInsertion` step, which inserts antenna diode cells at design pins before antenna repair step. | `False` |

---

## 2. Antenna Verification

### 2.1 What is an Antenna Violation?

During chip fabrication, wafers pass through a plasma etching process to pattern each
metal layer. As metal is etched, floating conductor segments accumulate a static charge
proportional to their exposed area. If this charge exceeds a threshold, it can tunnel
through the thin gate oxide of connected transistors — permanently damaging them.

```{figure} ./figures/Antenna_Effect.png
:align: center

*Antenna Effect*
```

This is the **Antenna Effect** (formally: *Process Antenna Rule* violation). The ratio
that governs it is:

```text
Antenna Ratio = Total metal area connected to gate / Gate oxide area
```

The SkyWater 130nm {term}`PDK` defines maximum allowable ratios for each metal layer
and via. When a net's accumulated metal area exceeds these limits, the router must
intervene.

```{admonition} Why Does This Appear After Global Routing?
:class: tip

Antenna violations are a function of physical wire length and shape — information that
only becomes available once Global Routing assigns nets to metal layer paths. The check
is performed immediately after GRT using the `OpenROAD.CheckAntennas` step.
```

---

### 2.2 Antenna Repair Strategies

LibreLane provides two complementary repair mechanisms, which can be used individually
or together:

#### Antenna Diode Insertion
Insert specialised diode cells connected to the violating net. The diode provides a
controlled discharge path to the substrate during fabrication, protecting the gate oxide.
This is the **primary repair method** for most violations.

```{figure} ./figures/Solution1_Inserting_Diodes.png
:align: center
:scale: 50%
*Solution 1 Inserting Diodes*
```

#### Metal Jumpering (Layer Hopping)
Break a long continuous metal segment into shorter sections by routing through a higher
metal layer and back down. This resets the accumulated charge at the via, allowing the
net to continue without exceeding the ratio limit.

```{figure} ./figures/Solution2_Layer_Jumping.png
:align: center
:scale: 50%
*Solution2 Layer Jumping*
```

The repair process is **iterative**: after each repair pass, the antenna checker
re-evaluates the design. Iterations continue until all violations are resolved or the
configured iteration limit is reached.

```{tip}
For the `aes_wb_wrapper`, diode insertion is often more effective because the
AES datapath contains several wide bus signals (such as `wbs_dat_o` and key
register buses). These buses can accumulate large metal areas on lower routing
layers, increasing the risk of antenna violations.

Jumper insertion is typically more effective for isolated long nets, but it is
less efficient when many parallel bus wires are involved.
```

---

### 2.3 Antenna Repair Configuration

| Parameter | Type | Description | Default |
| :--- | :--- | :--- | :--- |
| `GRT_ANTENNA_REPAIR_ITERS` | `int` | Maximum repair iterations for global antenna violations. | `3` |
| `GRT_ANTENNA_REPAIR_MARGIN` | `int` | Percentage margin above the PDK limit used to over-fix violations. A value of `15` means the tool fixes nets that are within 15% of the limit — providing guard-band against post-DRT worsening. | `10` |
| `GRT_ANTENNA_REPAIR_JUMPER_ONLY` | `bool` | Restricts repair to metal jumpering only. Cannot be combined with `DIODE_ONLY`. | `False` |
| `GRT_ANTENNA_REPAIR_DIODE_ONLY` | `bool` | Restricts repair to diode insertion only. | `False` |
| `DRT_ANTENNA_REPAIR_ITERS` | `int` | Maximum antenna repair iterations during Detailed Routing. | `0` |
| `DRT_ANTENNA_REPAIR_MARGIN` | `int` | Margin percentage for over-fixing violations during Detailed Routing. | `10` |

---

## 3. Post-GRT Design Repair

After Global Routing assigns wire paths and RC parasitics become physically meaningful
for the first time, LibreLane runs an optional design repair pass
(`OpenROAD.RepairDesignPostGRT`) to address violations that only became apparent after
wire capacitance was known.

This step performs the same type of buffer insertion and gate resizing as the
post-CTS repair from Module 2, but now uses real routing-aware parasitics instead of
statistical estimates. This makes the repairs more targeted and less likely to
introduce regressions.

```{admonition} Why Enable This Step?
:class: tip

At the pre-placement and post-CTS stages, capacitance values are estimated from
statistical wire-length models. After Global Routing, the tool has real path-specific
RC values for every net. Enabling `RUN_POST_GRT_DESIGN_REPAIR` allows the Resizer to
correct violations that were previously invisible — particularly on long, high-fanout
nets in the AES datapath where the actual routed wire length differs significantly
from the statistical estimate.
```

**Key repair parameter:**

| Parameter | Type | Description | Default |
| :--- | :--- | :--- | :--- |
| `RUN_POST_GRT_DESIGN_REPAIR` | `bool` | Enables the `OpenROAD.RepairDesignPostGRT` step. When enabled, the Resizer uses GRT-derived RC parasitics to insert buffers and resize gates. | `False` |
| `GRT_DESIGN_REPAIR_MAX_WIRE_LENGTH` | `Decimal` | Maximum wire length in µm that the post-GRT Resizer will allow before inserting a repeater buffer. Setting this to `800 µm` is a reasonable starting point for the AES core at 40 MHz. | `0` (disabled) |

---

## 4. Detailed Routing (DRT)

### 4.1 What Detailed Routing Does

Detailed Routing is the most computationally intensive step in the entire flow. It
transforms the abstract G-cell routing plan from Global Routing into actual metal wires
and vias that strictly satisfy all SkyWater 130nm {term}`DRC` rules — minimum spacing,
minimum width, via enclosure, and antenna ratios.

The engine used by LibreLane is **TritonRoute**, which operates in multiple passes:

| Pass | Description |
| :--- | :--- |
| **Track assignment** | Assigns each global route to a specific routing track on the target metal layer. |
| **Detailed path search** | Performs local rerouting to resolve shorts, spacing violations, and via conflicts. |
| **Iterative optimisation** | Repeats the search-and-repair cycle for up to `DRT_OPT_ITERS` iterations until all DRC violations are eliminated. |
| **Post-DRT legalisation** | Updates the design database with final wire geometries and newly inserted antenna cells. |

```{note}
A successful Detailed Routing run ends with **0 DRC violations**. If violations remain
after the maximum iteration count, they will appear in the post-DRT DRC report and
must be resolved before the design can proceed to Physical Signoff.
```

---

### 4.2 DRT Configuration Reference

| Parameter | Type | Description | Default |
| :--- | :--- | :--- | :--- |
| `DRT_THREADS` | `int` | Number of CPU threads used by TritonRoute. If unset, defaults to the machine's available thread count. Increase this on multi-core workstations to reduce run time. | `None` |
| `DRT_OPT_ITERS` | `int` | Maximum optimisation iterations TritonRoute will attempt to achieve 0 DRC violations. | `64` |
| `DRT_SAVE_SNAPSHOTS` | `bool` | Saves an `.odb` snapshot of the layout at each routing iteration. Useful for debugging persistent DRC violations but produces large output files. | `False` |
| `DRT_ANTENNA_REPAIR_ITERS` | `int` | Maximum antenna repair iterations during Detailed Routing. | `0` |
| `DRT_SAVE_DRC_REPORT_ITERS` | `int?` | Write a DRC report every N iterations. Defaults to `1` if `DRT_SAVE_SNAPSHOTS` is enabled. | `None` |

---

## 5. Mid-PnR STA (Post-Routing)

After Detailed Routing completes and antenna diodes are inserted, LibreLane performs
a **Mid-PnR Static Timing Analysis** (`OpenROAD.STAMidPNR-3`) using the fully routed
RC parasitics.

This is the first {term}`STA` checkpoint where every wire's resistance and capacitance
is derived from actual physical geometry — not statistical models. Key things to look
for at this stage:

| Metric | What to Expect |
| :--- | :--- |
| **Setup {term}`WNS`** | Should remain zero or positive from the CTS run. Any regression indicates the routing added unexpected delay on a critical path. |
| **Hold {term}`WNS`** | Should remain closed from the post-CTS repair. New hold violations here are uncommon but indicate antenna diode insertion added parasitic load to a tight hold path. |
| **Max Slew / Max Cap** | May be higher than the post-CTS report due to real wire parasitics exceeding statistical estimates. The post-GRT design repair (if enabled) reduces these. |

---

## 6. Configuration Summary and Execution

### 6.1 Key Parameters for This Run

Three parameters are added or modified relative to the Module 2 configuration:

| Parameter | Value | Rationale |
| :--- | :---: | :--- |
| `RT_MAX_LAYER` | `"met4"` | Prevents signal routes from being placed on Metal 5. Since the Caravel User Project Wrapper uses `met5` for its top-level {term}`PDN`, any signal routing on that layer would create {term}`DRC` shorts when the macro is integrated. |
| `GRT_ANTENNA_REPAIR_MARGIN` | `15` | Increases the repair over-fix margin from the default 10% to 15%, proactively protecting nets that are close to the antenna limit from violations introduced during Detailed Routing. |
| `GRT_DESIGN_REPAIR_MAX_WIRE_LENGTH` | `800` | Caps the maximum wire segment length at 800 µm, triggering repeater buffer insertion on long AES datapath wires where routing-aware capacitance exceeds the post-CTS repair estimates. |
| `RUN_POST_GRT_DESIGN_REPAIR` | `true` | Enables the post-GRT design repair step, allowing the Resizer to fix violations using real RC parasitics from Global Routing. |

```{admonition} Why `met4` as the Maximum Routing Layer?
:class: important

The SkyWater 130nm metal stack for the `sky130_fd_sc_hd` library has five signal
routing layers (`met1` through `met5`). In a standalone macro, all five layers are
available. However, when the `aes_wb_wrapper` is integrated into the **Caravel User
Project Wrapper**, the wrapper's {term}`PDN` uses `met5` for horizontal power straps.

Setting `RT_MAX_LAYER: "met4"` ensures that no signal wire from the macro occupies
`met5` tracks, leaving that layer exclusively available for top-level power delivery.
Without this constraint, the Detailed Router may place signal wires on `met5` that
collide with the wrapper's power straps — creating {term}`DRC` violations that are
difficult to resolve post-integration.
```

---

### 6.2 Final `config.json`

Open your configuration file and apply all additions:

```console
$ gedit ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/config.json
```

Your complete `config.json` should now read:

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
    "DESIGN_REPAIR_MAX_SLEW_PCT": 30,
    "DESIGN_REPAIR_MAX_CAP_PCT": 30,
    "RT_MAX_LAYER": "met4",
    "GRT_ANTENNA_REPAIR_MARGIN": 15,
    "GRT_DESIGN_REPAIR_MAX_WIRE_LENGTH": 800,
    "RUN_POST_GRT_DESIGN_REPAIR": true
}
```

---

### 6.3 Flow Execution

This run **resumes from the Module 2 CTS checkpoint** using `--with-initial-state`.
This avoids re-running the entire synthesis, floorplan, and CTS pipeline, saving
significant compute time.

Ensure you are inside the Nix shell:

```console
$ nix-shell --pure ~/librelane/shell.nix
```

Then execute:

```console
[nix-shell:~]$ librelane \
    ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/config.json \
    --run-tag classic_to_drt \
    --to OpenROAD.STAMidPNR-3 \
    --with-initial-state \
    ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/runs/classic_to_cts/38-openroad-stamidpnr-2/state_out.json
```

```{tip}
The `--with-initial-state` flag loads the complete design state (placement, clock tree,
timing data) from the specified `state_out.json`. LibreLane will begin execution from
the first step that follows the state's last completed step — in this case, directly
at Global Routing. No design data is lost between modules.
```

The run will execute through the following key steps before stopping at `STAMidPNR-3`:

```text
runs/classic_to_drt/
    ├── 39-openroad-globalrouting/           ← GRT + congestion resolution
    ├── 40-openroad-checkantennas/           ← Initial antenna violation scan
    ├── 41-openroad-repairantennas/          ← Diode insertion / jumpering
    ├── 42-openroad-resizertiminpostgrt/     ← Post-GRT timing repair (if enabled)
    ├── 43-openroad-detailedrouting/         ← TritonRoute DRT
    ├── 44-openroad-checkantennas-1/         ← Final antenna check post-DRT
    ├── 45-openroad-stamidpnr-3/             ← STA with routed RC parasitics
    ⋮
```

```{warning}
Detailed Routing (`43-openroad-detailedrouting`) is the most time-consuming step in
the entire flow. For the `aes_wb_wrapper`, expect a runtime of **30–90 minutes**
depending on your machine's CPU thread count. Do not interrupt this step — an
incomplete DRT database cannot be resumed and the step must be restarted from the
beginning.
```

---

## 7. Inspecting Routing Results

### 7.1 Routing Congestion in OpenROAD

After the run completes, launch the OpenROAD GUI to inspect the routed layout:

```console
[nix-shell:~]$ librelane \
    ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/config.json \
    --last-run \
    --flow openinopenroad
```

#### Routing Congestion Heat Map

From the menu bar, select **Tools → Heat Maps → Routing Congestion**. You can view
congestion selectively per metal layer by expanding **Heat Maps → Routing Congestion**
in the **Display Control** panel on the left sidebar.

Regions displayed in warm colours (orange / red) are approaching the routing capacity
limit of that layer. For the `aes_wb_wrapper`, moderate congestion on `met1` and `met2`
is expected due to the high logic density of the AES datapath.

```{figure} ./figures/.png
:align: center

*Routing Congestion heat map — per-layer usage after Detailed Routing of* `aes_wb_wrapper`*.*
```

#### Verifying Metal Layer Usage

To confirm that `RT_MAX_LAYER: "met4"` was respected and no signal wires appear on
`met5`, navigate to the **Display Control** panel and disable all layers except `met5`.
The canvas should show only power strap shapes — no signal routing.

```{figure} ./figures/.png
:align: center

*Metal 5 layer view — only PDN straps visible, confirming no signal routes on met5.*
```

---

### 7.2 Antenna Summary Report

After the run, navigate to the antenna check reports:

- **Post-GRT:** `runs/classic_to_drt/40-openroad-checkantennas/antenna.rpt`
- **Post-DRT:** `runs/classic_to_drt/44-openroad-checkantennas-1/antenna.rpt`

The report provides a per-net breakdown of antenna ratios across each metal layer and via.

```text
```

Comparing the post-GRT and post-DRT antenna reports directly shows whether the repair
pass eliminated all violations before Detailed Routing committed them to physical wires.

```{note}
It is normal for the post-DRT antenna report to contain a small number of residual
violations. TritonRoute may introduce new short wire segments during the final DRC
resolution pass that slightly exceed the repair margin. These are typically resolved
during the Physical Signoff stage (Module 4) using Magic's antenna checker.
```

---

```{glossary}
GRT
  Global Routing. The first physical routing stage, which assigns nets to coarse routing regions (G-cells) to estimate congestion and RC parasitics without committing to actual wire shapes.

DRT
  Detailed Routing. The final routing stage, which transforms global routes into DRC-correct metal wires and vias using the TritonRoute engine.

DRC
  Design Rule Check. Verification that physical layout geometries conform to the foundry's manufacturing constraints, including minimum spacing, width, and via enclosure rules.

PDN
  Power Distribution Network. The metal conductor grid delivering supply voltage (VDD) and ground (GND) to every standard cell in the design.

STA
  Static Timing Analysis. Timing verification performed by exhaustively checking all signal paths against declared constraints without requiring simulation vectors.

WNS
  Worst Negative Slack. The largest magnitude of negative slack across all failing timing paths.

TNS
  Total Negative Slack. The arithmetic sum of all negative slack values across every failing timing path.

PnR
  Place and Route. The physical design stage encompassing standard cell placement and signal wire routing.

SDC
  Synopsys Design Constraints. A Tcl-based format specifying timing and clocking constraints for implementation and static timing analysis.
```

# Module 4: Physical Signoff

```{admonition} Prerequisites
:class: important

Before proceeding, ensure your **Module 3** routing run (`classic_flow`) has completed
successfully through step `52-checker-wirelength`. The signoff flow resumes from
this checkpoint using `--with-initial-state`.
```

---

## Table of Contents

1. [Signoff Flow Overview](#signoff-flow-overview)
2. [Signoff Prep](#signoff-prep)
   - [2.1 Fill Cell Insertion](#fill-cell-insertion-openroadfillinsertion)
   - [2.2 Parasitic Extraction (RCX)](#parasitic-extraction-openroadrcx)
   - [2.3 Post-PnR Static Timing Analysis](#post-pnr-static-timing-analysis-openroadstapostpnr)
   - [2.4 IR Drop Analysis](#ir-drop-analysis-openroadirdropreport)
3. [Running the Signoff Prep Flow](#running-the-signoff-prep-flow)
4. [Signoff Prep Results Analysis](#signoff-prep-results-analysis)
   - [4.1 Post-PnR STA Report](#post-pnr-sta-report)
   - [4.2 Power Report](#power-report)
   - [4.3 IR Drop Report](#ir-drop-report)
5. [Resolving Max Slew, Max Cap & Hold Slack Violations](#resolving-max-slew-max-cap--hold-slack-violations)
   - [5.1 Diagnosing the Violations](#diagnosing-the-violations)
   - [5.2 ECO Buffer Insertion — Side Load Isolation](#eco-buffer-insertion--side-load-isolation)
   - [5.3 Running the ECO Flow](#running-the-eco-flow)
   - [5.4 Post-ECO STA Results](#post-eco-sta-results)
   - [5.5 Visual Design Analysis (OpenROAD GUI)](#visual-design-analysis-openroad-gui)
6. [Physical Signoff Steps](#physical-signoff-steps)
   - [6.1 GDSII Generation](#gdsii-generation-magic-and-klayout-stream-out)
   - [6.2 Physical Abstract and Antenna Validation](#physical-abstract-and-antenna-validation)
   - [6.3 XOR Geometric Verification](#xor-geometric-verification-klayoutxor)
   - [6.4 Design Rule Check (DRC)](#design-rule-check-magic-drc--klayout-drc)
   - [6.5 Layout vs. Schematic (LVS)](#layout-vs-schematic-magicspiceextraction--netgenlvs)
7. [Running the Physical Signoff Flow](#running-the-physical-signoff-flow)
8. [Physical Signoff Results](#physical-signoff-results)
   - [8.1 DRC Report](#drc-report)
   - [8.2 LVS Report](#lvs-report)
9. [Final Output Directory](#final-output-directory)

---

## 1. Signoff Flow Overview

The signoff stage transforms a fully routed design into a verified, manufacturable chip.
It is divided into two phases that are executed separately in this module:

- **Signoff Prep** — electrical and timing verification (Fill, RCX, STA, IR Drop).
- **Physical Signoff** — geometric and connectivity verification (GDS, DRC, LVS).

Separating the two phases allows us to analyse the timing reports, resolve any
remaining violations using an ECO (Engineering Change Order), and only then commit
to the final physical checks.

| Phase | Step Description | Step ID |
| :--- | :--- | :--- |
| **Signoff Prep** | Fill Cell Insertion | `OpenROAD.FillInsertion` |
| | Cell Frequency Tables | `Odb.CellFrequencyTables` |
| | Parasitic Extraction | `OpenROAD.RCX` |
| | Post-{term}`PnR` Static Timing Analysis | `OpenROAD.STAPostPNR` |
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
| | Setup / Hold Violations Check | `Checker.SetupViolations` / `Checker.HoldViolations` |
| | Max Slew / Cap Violations Check | `Checker.MaxSlewViolations` / `Checker.MaxCapViolations` |
| | Final Manufacturability Report | `Misc.ReportManufacturability` |

---

## 2. Signoff Prep

### 2.1 Fill Cell Insertion (`OpenROAD.FillInsertion`)

After Detailed Routing completes, the standard cell rows contain physical gaps between
functional cells. The `FillInsertion` step closes every gap by inserting **filler cells**
and **decap cells** across the entire layout.

```{note}
This step marks a critical design boundary. After fill insertion, the design is
**functionally frozen** — all logic, buffers, clock cells, and antenna diodes are
locked in place. Filler cells occupy the remaining silicon area, completing the
physical fabric of the chip.
```

#### What Filler Cells Do

| Role | Why It Matters |
| :--- | :--- |
| **N-well / P-well Continuity** | Standard cells require continuous substrate wells across every row. Gaps break these wells. Filler cells bridge them, ensuring a single uninterrupted implant mask layer. |
| **Power Rail Continuity (VDD/VSS)** | Horizontal Metal 1 power rails must be electrically connected across the entire row. Without fillers these rails float in empty spaces, creating localised IR drop. Fillers act as a conductor bridge for the power grid. |
| **Manufacturing Yield** | Empty spaces create density gradients during CMP, leading to surface defects. Filling all gaps ensures uniform density and maximises the ratio of functional dies per wafer. |

For the `aes_wb_wrapper`, fill insertion produces the following final cell population:

```text
Cell type report:                       Count       Area
  Fill cell                             98361  336197.44
  Tap cell                               9176   11481.01
  Antenna cell                            658    1646.58
  Buffer                                 4273   19159.63
  Clock buffer                            569    7495.94
  Timing Repair Buffer                   2718   23019.58
  Inverter                               3113   11684.96
  Clock inverter                           86    1071.03
  Sequential cell                        2995   78694.22
  Multi-Input combinational cell        13795  150717.05
  Total                                135744  641167.43
```

The figures below show the layout before and after fill insertion:

::::{grid} 2

:::{grid-item}
```{figure} ./figures/Before_Fill_Insertion.png
:align: center

*Before fill insertion — visible gaps between functional cells.*
```
:::

:::{grid-item}
```{figure} ./figures/After_Fill_Insertion.png
:align: center

*After fill insertion — all gaps sealed with filler and decap cells.*
```
:::

::::

---

### 2.2 Parasitic Extraction (`OpenROAD.RCX`)

With the layout physically complete, the **OpenRCX** engine converts routed geometry
into an electrical model. Every wire has real resistance (from its length and
cross-section) and real capacitance (from its proximity to adjacent wires and the
substrate). Parasitic extraction captures these values so the downstream {term}`STA`
uses actual physical delays instead of statistical estimates.

```{figure} ./figures/OpenRCX.png
:align: center

*OpenRCX inputs and outputs — the extraction bridge between physical geometry and electrical models.*
```

#### The Extraction Process

**RC Segment Generation** — Each physical wire is broken into smaller electrical
segments. Resistance is calculated per segment from layer, width, and length.
Via resistance is added at every layer transition. For `aes_wb_wrapper` this yields
**161,601 RC segments** across **27,332 nets**.

**Capacitance Calculation:**

- *Coupling capacitance* — electrical interaction between parallel wires on the same
  layer. The primary mechanism for crosstalk on critical timing paths.
- *Ground capacitance* — capacitance between a wire and the substrate or ground planes.

**Filtering** — Coupling values below **0.1 fF** are merged into ground capacitance,
simplifying the SPEF without meaningful accuracy loss.

#### Output — Three Corner SPEF Files

```text
runs/classic_flow/55-openroad-rcx/
    ├── max/   aes_wb_wrapper.max.spef  ← Worst-case RC — used for Setup analysis
    ├── nom/   aes_wb_wrapper.nom.spef  ← Nominal RC
    └── min/   aes_wb_wrapper.min.spef  ← Best-case RC — used for Hold analysis
```

The **SPEF (Standard Parasitic Exchange Format)** file maps the resistance and
capacitance of every net. It feeds directly into the Post-{term}`PnR` STA engine,
enabling the first silicon-accurate timing analysis.

---

### 2.3 Post-PnR Static Timing Analysis (`OpenROAD.STAPostPNR`)

```{figure} ./figures/OpenSTA.png
:align: center

*Post-PnR STA flow — SPEF parasitics enable physically accurate timing analysis for the first time.*
```

This is the most authoritative timing check in the entire flow. The OpenSTA engine
analyses the completed physical netlist annotated with exact RC parasitics from RCX.

| Analysis Stage | Parasitic Source | Accuracy |
| :--- | :--- | :--- |
| Pre-{term}`PnR` STA (Module 1) | Statistical wire-load models | Low — estimates only |
| Mid-{term}`PnR` STA (Modules 2–3) | Global routing RC estimates | Medium — approximate |
| **Post-{term}`PnR` STA (this step)** | **RCX SPEF — actual wire geometry** | **High — silicon-accurate** |

#### Multi-Corner Analysis

The analysis covers **9 PVT corners** — three process splits (max / nom / min) for
each of three temperature-voltage combinations:

```text
max_ss_100C_1v60    nom_ss_100C_1v60    min_ss_100C_1v60
max_tt_025C_1v80    nom_tt_025C_1v80    min_tt_025C_1v80
max_ff_n40C_1v95    nom_ff_n40C_1v95    min_ff_n40C_1v95
```

```{note}
Earlier STA stages analyse only **3 corners**. Post-{term}`PnR` STA expands to
**9 corners**, providing complete coverage of the {term}`PVT` space for final signoff.
```

Each corner produces a dedicated directory of reports:

```text
runs/classic_flow/56-openroad-stapostpnr/
└── max_ff_n40C_1v95/
    ├── aes_wb_wrapper__max_ff_n40C_1v95.lib   ← Liberty timing model
    ├── aes_wb_wrapper__max_ff_n40C_1v95.sdf   ← Standard Delay Format
    ├── max.rpt / min.rpt                       ← Setup / Hold constrained paths
    ├── wns.max.rpt / wns.min.rpt              ← Worst Negative Setup / Hold Slack
    ├── tns.max.rpt / tns.min.rpt              ← Total Negative Slack
    ├── ws.max.rpt / ws.min.rpt                ← Worst Setup / Hold Slack
    ├── skew.max.rpt / skew.min.rpt            ← Clock skew
    ├── power.rpt                               ← Corner power breakdown
    ├── checks.rpt                              ← Max Cap, Slew, Fanout, unconstrained
    ├── violator_list.rpt                       ← All failing endpoints
    ├── clock.rpt / unpropagated.rpt
    └── sta.log                                 ← Full raw STA engine output
```

---

### 2.4 IR Drop Analysis (`OpenROAD.IRDropReport`)

This step performs a static IR drop analysis on the completed {term}`PDN`.
Every wire in the power and ground network has resistance, causing a voltage drop as
current flows from the supply pads to the standard cells.

The tool evaluates both networks separately:

- **`VPWR`:** Voltage decrease from supply to cells (classical IR drop). Excessive
  drop slows logic and degrades setup margin.
- **`VGND`:** Voltage rise on the ground return path (*ground bounce*). This reduces
  the effective noise margin of every standard cell in the affected region.

Analysis is performed on `max_ss_100C_1v60` — the worst-case combination of
maximum wire resistance and highest current demand.

**Report location:**
```text
runs/classic_flow/57-openroad-irdropreport/irdrop.rpt
```

---

## 3. Running the Signoff Prep Flow

This run executes all Signoff Prep steps and stops after IR Drop Analysis, allowing
us to review the electrical results before committing to the physical signoff steps.

Ensure you are inside the Nix shell:

```console
$ nix-shell --pure ~/librelane/shell.nix
```

Then execute:

```console
[nix-shell:~]$ librelane \
    ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/config.json \
    --run-tag classic_flow \
    --from OpenROAD.FillInsertion \
    --to OpenROAD.IRDropReport \
    --with-initial-state \
    ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/runs/classic_flow/52-checker-wirelength/state_out.json
```

The run will execute through the following steps:

```text
runs/classic_flow/
    ⋮
    ├── 53-openroad-fillinsertion/
    ├── 54-odb-cellfrequencytables/
    ├── 55-openroad-rcx/
    │   ├── max/   aes_wb_wrapper.max.spef
    │   ├── nom/   aes_wb_wrapper.nom.spef
    │   └── min/   aes_wb_wrapper.min.spef
    ├── 56-openroad-stapostpnr/     ← 9-corner STA with SPEF parasitics
    └── 57-openroad-irdropreport/   ← PDN voltage drop analysis
```

---

## 4. Signoff Prep Results Analysis

### 4.1 Post-PnR STA Report

**Location:** `runs/classic_flow/56-openroad-stapostpnr/summary.rpt`

```text
┏━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━┓
┃                      ┃ Hold     ┃ Reg to   ┃          ┃          ┃ of which  ┃ Setup    ┃           ┃          ┃           ┃ of which ┃           ┃          ┃
┃                      ┃ Worst    ┃ Reg      ┃          ┃ Hold Vio ┃ reg to    ┃ Worst    ┃ Reg to    ┃ Setup    ┃ Setup Vio ┃ reg to   ┃ Max Cap   ┃ Max Slew ┃
┃ Corner/Group         ┃ Slack    ┃ Paths    ┃ Hold TNS ┃ Count    ┃ reg       ┃ Slack    ┃ Reg Paths ┃ TNS      ┃ Count     ┃ reg      ┃ Violatio… ┃ Violati… ┃
┡━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━┩
│ Overall              │ 0.1086   │ 0.1086   │ 0.0000   │ 0        │ 0         │ 2.8526   │ 3.3638    │ 0.0000   │ 0         │ 0        │ 5         │ 14       │
│ nom_tt_025C_1v80     │ 0.2519   │ 0.2519   │ 0.0000   │ 0        │ 0         │ 8.6625   │ 14.0341   │ 0.0000   │ 0         │ 0        │ 0         │ 0        │
│ nom_ss_100C_1v60     │ 0.6405   │ 0.6405   │ 0.0000   │ 0        │ 0         │ 3.0600   │ 3.9852    │ 0.0000   │ 0         │ 0        │ 2         │ 2        │
│ nom_ff_n40C_1v95     │ 0.1224   │ 0.1224   │ 0.0000   │ 0        │ 0         │ 9.5746   │ 17.8370   │ 0.0000   │ 0         │ 0        │ 0         │ 0        │
│ min_tt_025C_1v80     │ 0.2631   │ 0.2631   │ 0.0000   │ 0        │ 0         │ 8.7799   │ 14.5271   │ 0.0000   │ 0         │ 0        │ 0         │ 0        │
│ min_ss_100C_1v60     │ 0.6565   │ 0.6565   │ 0.0000   │ 0        │ 0         │ 3.3348   │ 4.6175    │ 0.0000   │ 0         │ 0        │ 1         │ 2        │
│ min_ff_n40C_1v95     │ 0.1306   │ 0.1306   │ 0.0000   │ 0        │ 0         │ 9.6545   │ 18.2251   │ 0.0000   │ 0         │ 0        │ 0         │ 0        │
│ max_tt_025C_1v80     │ 0.2320   │ 0.2320   │ 0.0000   │ 0        │ 0         │ 8.5517   │ 13.5138   │ 0.0000   │ 0         │ 0        │ 0         │ 0        │
│ max_ss_100C_1v60     │ 0.6118   │ 0.6118   │ 0.0000   │ 0        │ 0         │ 2.8526   │ 3.3638    │ 0.0000   │ 0         │ 0        │ 5         │ 14       │
│ max_ff_n40C_1v95     │ 0.1086   │ 0.1086   │ 0.0000   │ 0        │ 0         │ 9.4982   │ 17.4806   │ 0.0000   │ 0         │ 0        │ 0         │ 0        │
└──────────────────────┴──────────┴──────────┴──────────┴──────────┴───────────┴──────────┴───────────┴──────────┴───────────┴──────────┴───────────┴──────────┘
```

```{admonition} Interpreting the Post-PnR STA Results
:class: tip

**Hold violations: fully resolved.** All 9 corners show positive Hold WNS (≥ +0.1086 ns).
The CTS and post-CTS repair passes from Module 2 closed every hold path.

**Setup timing: clean.** Zero Setup violations across all 9 corners. The positive
Setup WNS values confirm the design meets the 40 MHz target under all conditions.

**Max Slew / Max Cap: require attention.** The `max_ss_100C_1v60` corner shows
**14 Max Slew** and **5 Max Cap** violations. These must be resolved before physical
signoff. See [Section 5](#resolving-max-slew-max-cap--hold-slack-violations).

**Hold Slack margin.** The worst Hold {term}`WNS` is only **+0.1086 ns** in the
`max_ff_n40C_1v95` corner. While technically passing, this narrow margin may become
a Hold violation when the macro is integrated into the Caravel top level, as the
wrapper's routing adds additional clock path delays. The ECO step also addresses this.
```

---

### 4.2 Power Report

**Location:** `runs/classic_flow/56-openroad-stapostpnr/max_ff_n40C_1v95/power.rpt`

Worst-case power occurs at `max_ff_n40C_1v95` — fast transistors at low temperature
and high voltage switching at maximum rate:

```text
======================= max_ff_n40C_1v95 Corner ===================================
Group                    Internal    Switching      Leakage        Total
                            Power        Power        Power        Power (Watts)
------------------------------------------------------------------------
Sequential           5.653847e-03 6.869405e-05 6.859135e-08 5.722610e-03  30.8%
Combinational        2.391679e-03 5.279127e-03 2.687200e-07 7.671075e-03  41.3%
Clock                2.375699e-03 2.799051e-03 3.273007e-07 5.175077e-03  27.9%
Macro                0.000000e+00 0.000000e+00 0.000000e+00 0.000000e+00   0.0%
Pad                  0.000000e+00 0.000000e+00 0.000000e+00 0.000000e+00   0.0%
------------------------------------------------------------------------
Total                1.042120e-02 8.146887e-03 6.646642e-07 1.856875e-02 100.0%
                            56.1%        43.9%         0.0%
```

```{note}
**Combinational logic** (41.3%) dominates, driven by switching activity in the AES
datapath — XOR, shift, and S-box substitution operations. The **clock network**
(27.9%) reflects distributing the clock to ~3,000 flip-flops via a balanced H-Tree.
Total power of **~18.6 mW** is well within the Caravel User Project power budget.
```

---

### 4.3 IR Drop Report

**Location:** `runs/classic_flow/57-openroad-irdropreport/irdrop.rpt`

```text
########## IR report #################
Net              : VPWR
Corner           : max_ss_100C_1v60
Supply voltage   : 1.60e+00 V
Average IR drop  : 9.82e-05 V
Worstcase IR drop: 8.13e-04 V
Percentage drop  : 0.05 %
######################################

########## IR report #################
Net              : VGND
Corner           : max_ss_100C_1v60
Supply voltage   : 0.00e+00 V
Average IR drop  : 9.74e-05 V
Worstcase IR drop: 7.47e-04 V
Percentage drop  : 0.05 %
######################################
```

```{admonition} IR Drop — Excellent PDN Health
:class: tip

Worst-case IR drop of **0.05%** on both `VPWR` and `VGND` — well within the industry
signoff requirement of **< 2–5%**. This confirms that the PDN design choices from
Module 1 (`PDN_MULTILAYER: false`, Metal 4 vertical straps) provide stable power
delivery under worst-case conditions. No hotspots or under-powered regions exist
in the core.
```

---

## 5. Resolving Max Slew, Max Cap & Hold Slack Violations

The STA report reveals two categories of issues that must be addressed before physical
signoff can proceed:

1. **Max Slew (14) and Max Cap (5) violations** in the `max_ss_100C_1v60` corner.
2. **Narrow Hold WNS (+0.1086 ns)** in the `max_ff_n40C_1v95` corner — technically
   passing, but at risk of becoming a Hold violation when integrated into Caravel due
   to additional clock path delays introduced by the top-level wrapper routing.

---

### 5.1 Diagnosing the Violations

Open the `checks.rpt` for the worst-case corner:

```text
runs/classic_flow/56-openroad-stapostpnr/max_ss_100C_1v60/checks.rpt
```

The report shows the specific violating pins and the magnitude of each violation:

**Max Slew Violations:**

```text
max slew

Pin                                        Limit        Slew       Slack
------------------------------------------------------------------------
wire709/A                               1.500000    2.140449   -0.640449 (VIOLATED)
_33732_/Y                               1.500000    2.140219   -0.640219 (VIOLATED)
_32081_/Y                               1.496182    1.590252   -0.094070 (VIOLATED)
wire412/A                               1.500000    1.590497   -0.090497 (VIOLATED)
_33024_/X                               1.495224    1.551253   -0.056029 (VIOLATED)
ANTENNA_216/DIODE                       1.500000    1.555177   -0.055177 (VIOLATED)
ANTENNA_214/DIODE                       1.500000    1.555174   -0.055174 (VIOLATED)
ANTENNA_212/DIODE                       1.500000    1.555173   -0.055173 (VIOLATED)
_33025_/A                               1.500000    1.555165   -0.055165 (VIOLATED)
ANTENNA_211/DIODE                       1.500000    1.555138   -0.055138 (VIOLATED)
ANTENNA_213/DIODE                       1.500000    1.555100   -0.055100 (VIOLATED)
ANTENNA_215/DIODE                       1.500000    1.555096   -0.055096 (VIOLATED)
ANTENNA_217/DIODE                       1.500000    1.555091   -0.055091 (VIOLATED)
_30855_/Y                               1.495589    1.496218   -0.000629 (VIOLATED)
```

**Max Cap Violations:**

```text
max capacitance

Pin                                        Limit         Cap       Slack
------------------------------------------------------------------------
_33732_/Y                               0.052195    0.078192   -0.025997 (VIOLATED)
_33024_/X                               0.172129    0.179231   -0.007102 (VIOLATED)
_32081_/Y                               0.065012    0.071731   -0.006719 (VIOLATED)
_30855_/Y                               0.059519    0.062032   -0.002513 (VIOLATED)
fanout2499/X                            0.081492    0.081709   -0.000217 (VIOLATED)
```

```{note}
Notice that `_33732_/Y`, `_33024_/X`, `_32081_/Y`, and `_30855_/Y` appear in **both**
the Max Slew and Max Cap violation lists. This is the expected coupling: an overloaded
output capacitance on the driver directly causes a slow transition on every input it
drives. Fixing the cap violation will simultaneously resolve the corresponding slew
violation on the same net.
```

#### Worst Hold Slack:
In the Post-PnR stage, we analyze the **Fast Corner** (Minimum Delay) to ensure data does not move through the logic too quickly, which would cause a race condition.

To find the most critical hold path, we inspect the timing report generated for the best-case silicon conditions:

* **File:** `runs/classic_flow/56-openroad-stapostpnr/max_ff_n40C_1v95/min.rpt`
* **Analysis:** We locate the first path in the report, which shows the worst slack of **0.108581**.
* **Target Pin:** By tracing the **Arrival Path**, we identify the output of the launch Flip-Flop: **`_45051_/Q`**.

To increase the hold margin, we must intentionally add delay to this specific path. By inserting a buffer immediately after the launch pin, we ensure the data stays stable long enough to meet the hold requirement of the capturing register.

---

### 5.2 ECO Buffer Insertion — Side Load Isolation

The solution is to insert strong driver buffers (`sky130_fd_sc_hd__buf_4`) at the
output of each overloaded gate — an **Engineering Change Order (ECO)** performed
post-routing. This technique is called **Side Load Isolation**:

```{figure} ./figures/Side_Load_Isolation.png
:align: center

*Side Load Isolation — a buf_4 is inserted after the overloaded driver, absorbing the heavy capacitive load so the original gate only drives the small buffer input.*
```

**Why target the driver output pin?**

By inserting a buffer immediately after `_33732_/Y` (for example), the original gate
only needs to charge the tiny input capacitance of the `buf_4`. The `buf_4` then
handles the heavy capacitive load of the long downstream wire (`wire709`). The original
gate's slew improves, the cap violation clears, and `wire709` receives a strongly driven
signal.

#### Step 1 — Add the ECO Flow to `config.json`

LibreLane performs ECO buffer insertion as a substitution step that is injected
just before the final Detailed Routing re-run. Add the `meta` flow substitution block
to your `config.json`:

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
    "IO_PIN_ORDER_CFG": "dir::pin_order.cfg",
    "GRT_ANTENNA_REPAIR_ITERS": 10,
    "GRT_ANTENNA_REPAIR_MARGIN": 15,

    "meta": {
        "flow": "Classic",
        "substituting_steps": {
            "+OpenROAD.DetailedRouting": "Odb.InsertECOBuffers",
            "+Odb.InsertECOBuffers": "OpenROAD.DetailedRouting"
        }
    },

    "INSERT_ECO_BUFFERS": [
        { "target": "wire709/A",       "buffer": "sky130_fd_sc_hd__buf_4" },
        { "target": "_33732_/Y",       "buffer": "sky130_fd_sc_hd__buf_4" },
        { "target": "_32081_/Y",       "buffer": "sky130_fd_sc_hd__buf_4" },
        { "target": "wire412/A",       "buffer": "sky130_fd_sc_hd__buf_4" },
        { "target": "_33024_/X",       "buffer": "sky130_fd_sc_hd__buf_4" },
        { "target": "ANTENNA_216/DIODE", "buffer": "sky130_fd_sc_hd__buf_4" },
        { "target": "ANTENNA_214/DIODE", "buffer": "sky130_fd_sc_hd__buf_4" },
        { "target": "ANTENNA_212/DIODE", "buffer": "sky130_fd_sc_hd__buf_4" },
        { "target": "_33025_/A",       "buffer": "sky130_fd_sc_hd__buf_4" },
        { "target": "ANTENNA_211/DIODE", "buffer": "sky130_fd_sc_hd__buf_4" },
        { "target": "ANTENNA_213/DIODE", "buffer": "sky130_fd_sc_hd__buf_4" },
        { "target": "ANTENNA_215/DIODE", "buffer": "sky130_fd_sc_hd__buf_4" },
        { "target": "ANTENNA_217/DIODE", "buffer": "sky130_fd_sc_hd__buf_4" },
        { "target": "_30855_/Y",       "buffer": "sky130_fd_sc_hd__buf_4" },
        { "target": "fanout2499/X",    "buffer": "sky130_fd_sc_hd__buf_4" },
        { "target": "_45051_/Q",       "buffer": "sky130_fd_sc_hd__buf_4" }
    ]
}
```

---

### 5.3 Running the ECO Flow

The ECO run starts from the state just after Detailed Routing, inserts the ECO buffers,
re-routes the affected nets, and re-runs the Signoff Prep analysis to verify the fix.

```console
[nix-shell:~]$ librelane \
    ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/config.json \
    --run-tag classic_flow_eco \
    --from Odb.InsertECOBuffers \
    --to OpenROAD.IRDropReport \
    --with-initial-state \
    ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/runs/classic_flow/45-openroad-detailedrouting/state_out.json
```

```{note}
This creates a new run directory `classic_flow_eco`, starting from step
`01-odb-insertecobuffers`, followed by `02-openroad-detailedrouting-1` and all
subsequent signoff prep steps. The original `classic_flow` directory is preserved
for comparison.
```

The ECO run directory structure:

```text
runs/classic_flow_eco/
    ├── 01-odb-insertecobuffers/
    ├── 02-openroad-detailedrouting-1/
    ├── 03-openroad-checkantennas-1/
    ├── 04-openroad-repairantennas-1/
    ├── ...
    ├── 10-openroad-fillinsertion/
    ├── 11-openroad-rcx/
    ├── 12-openroad-stapostpnr/
    └── 14-openroad-irdropreport/
```

---

### 5.4 Post-ECO STA Results

**Location:** `runs/classic_flow_eco/13-openroad-stapostpnr/summary.rpt`

```text
┏━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━┓
┃                      ┃ Hold     ┃ Reg to   ┃          ┃          ┃ of which  ┃ Setup    ┃           ┃          ┃           ┃ of which ┃           ┃          ┃
┃                      ┃ Worst    ┃ Reg      ┃          ┃ Hold Vio ┃ reg to    ┃ Worst    ┃ Reg to    ┃ Setup    ┃ Setup Vio ┃ reg to   ┃ Max Cap   ┃ Max Slew ┃
┃ Corner/Group         ┃ Slack    ┃ Paths    ┃ Hold TNS ┃ Count    ┃ reg       ┃ Slack    ┃ Reg Paths ┃ TNS      ┃ Count     ┃ reg      ┃ Violatio… ┃ Violati… ┃
┡━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━┩
│ Overall              │ 0.1309   │ 0.1309   │ 0.0000   │ 0        │ 0         │ 2.8575   │ 3.3804    │ 0.0000   │ 0         │ 0        │ 0         │ 0        │
│ nom_tt_025C_1v80     │ 0.2699   │ 0.2699   │ 0.0000   │ 0        │ 0         │ 8.6689   │ 14.0678   │ 0.0000   │ 0         │ 0        │ 0         │ 0        │
│ nom_ss_100C_1v60     │ 0.6585   │ 0.6585   │ 0.0000   │ 0        │ 0         │ 3.0645   │ 4.0035    │ 0.0000   │ 0         │ 0        │ 0         │ 0        │
│ nom_ff_n40C_1v95     │ 0.1317   │ 0.1317   │ 0.0000   │ 0        │ 0         │ 9.5788   │ 17.8579   │ 0.0000   │ 0         │ 0        │ 0         │ 0        │
│ min_tt_025C_1v80     │ 0.2688   │ 0.2688   │ 0.0000   │ 0        │ 0         │ 8.7852   │ 14.5363   │ 0.0000   │ 0         │ 0        │ 0         │ 0        │
│ min_ss_100C_1v60     │ 0.6565   │ 0.6565   │ 0.0000   │ 0        │ 0         │ 3.3383   │ 4.6340    │ 0.0000   │ 0         │ 0        │ 0         │ 0        │
│ min_ff_n40C_1v95     │ 0.1309   │ 0.1309   │ 0.0000   │ 0        │ 0         │ 9.6581   │ 18.2404   │ 0.0000   │ 0         │ 0        │ 0         │ 0        │
│ max_tt_025C_1v80     │ 0.2711   │ 0.2711   │ 0.0000   │ 0        │ 0         │ 8.5571   │ 13.5450   │ 0.0000   │ 0         │ 0        │ 0         │ 0        │
│ max_ss_100C_1v60     │ 0.6603   │ 0.6603   │ 0.0000   │ 0        │ 0         │ 2.8575   │ 3.3804    │ 0.0000   │ 0         │ 0        │ 0         │ 0        │
│ max_ff_n40C_1v95     │ 0.1326   │ 0.1326   │ 0.0000   │ 0        │ 0         │ 9.5009   │ 17.5000   │ 0.0000   │ 0         │ 0        │ 0         │ 0        │
└──────────────────────┴──────────┴──────────┴──────────┴──────────┴───────────┴──────────┴───────────┴──────────┴───────────┴──────────┴───────────┴──────────┘
```

```{admonition} ECO Results — All Violations Resolved
:class: tip

**Max Slew and Max Cap: fully cleared.** Every violation in the `max_ss_100C_1v60`
corner has been eliminated. The `buf_4` cells absorb the excessive capacitive loads
that previously caused slow transitions on the flagged driver outputs.

**Hold WNS improved.** The worst Hold slack increased from **+0.1086 ns** to
**+0.1309 ns** across all corners — a ~20% improvement that provides better
guard-band against Hold violations when integrating into the Caravel top level.

**Setup timing unchanged.** The ECO buffers added no delay to the critical setup
paths; worst Setup {term}`WNS` remains clean across all 9 corners.

The design is now ready for physical signoff.
```

---

### 5.5 Visual Design Analysis (OpenROAD GUI)

After the ECO run completes, use the OpenROAD GUI to perform a deep-dive into the
physical health of the macro before committing to final physical signoff.

#### Launching the GUI

```console
[nix-shell:~]$ librelane \
    ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/config.json \
    --last-run \
    --flow openinopenroad
```

---

#### IR Drop Heat Map

Navigate to **Heat Maps → IR Drop → Metal 1 → Rebuild Data** in the left-hand panel.

The Metal 1 view shows IR drop specifically on the standard cell power rails — the
most direct measure of whether every cell is receiving adequate voltage. A uniform
colour map confirms no high-resistance hotspots, consistent with the 0.05% drop
measured analytically.

```{figure} ./figures/IR_drop_met1.png.png
:align: center

*IR Drop heat map (Metal 1) — uniform colour confirms no voltage hotspots across the macro.*
```

---

## 6. Physical Signoff Steps

### 6.1 GDSII Generation (Magic and KLayout Stream-Out)

The design must be converted from its OpenROAD representation (DEF/ODB) into
**{term}`GDSII`** — the binary format accepted by semiconductor foundries.
LibreLane performs this using two independent tools to provide a cross-check.

#### `Magic.StreamOut`

Magic performs a technology-aware DEF-to-GDSII conversion using the `.magicrc`
technology file. It loads the PDK standard cell GDS, reads the routed DEF,
reconstructs routing geometry on the correct metal layers, and writes
`aes_wb_wrapper.magic.gds`. Its output is used as the primary signoff-quality GDS
for DRC and LVS.

#### `KLayout.StreamOut`

KLayout merges the macro routing data with the standard cell library GDS, verifies
that every LEF component has a matching GDS geometry, and writes
`aes_wb_wrapper.klayout.gds`.

```{tip}
Both tools run independently by design. Each has different internal interpretations
of layer mapping and macro boundaries. Any disagreement between them will surface
during XOR comparison (Section 6.3) before the design reaches the foundry.
```

---

### 6.2 Physical Abstract and Antenna Validation

#### Abstract Generation (`Magic.WriteLEF`)

Magic creates a **{term}`LEF`** abstract of the `aes_wb_wrapper` — the boundary,
pin locations, metal blockages, and antenna gate area metadata for each input pin.
All internal transistors and routing are stripped away.

This LEF file enables other designers to instantiate the `aes_wb_wrapper` in a
larger SoC without processing the 135,000+ internal cells.

```{figure} ./figures/LEF.png
:align: center

*LEF abstract of* `aes_wb_wrapper` *in KLayout — only boundary, pins, and blockage layers visible.*
```

#### Antenna Metadata Validation (`Odb.CheckDesignAntennaProperties`)

The tool scans the LEF for antenna gate area metadata on every input pin. This is a
**documentation audit**, not a physical DRC — it ensures the LEF "safety manual"
correctly informs future designers how much accumulated charge each pin can tolerate
before gate oxide damage.

---

### 6.3 XOR Geometric Verification (`KLayout.XOR`)

The XOR step performs a layer-by-layer geometric comparison between the two
independently generated GDS files:

1. `aes_wb_wrapper.magic.gds`
2. `aes_wb_wrapper.klayout.gds`

If both tools interpreted the design identically, all polygons overlap exactly and
the XOR produces zero remaining geometry. Any tool disagreement produces a "leftover"
polygon at the discrepancy location.

```text
Total XOR differences: 0
```

---

### 6.4 Design Rule Check (Magic.DRC & KLayout.DRC)

Both Magic and KLayout scan the entire layout to verify that every geometric shape
complies with the SkyWater 130nm foundry rules. Checks include minimum metal width
and spacing, via enclosure, density uniformity, and manufacturing grid alignment.

LibreLane runs both tools because each applies different subsets of the rule deck —
violations at the boundary of one tool's interpretation may be caught by the other.

---

### 6.5 Layout vs. Schematic (`Magic.SpiceExtraction` & `Netgen.LVS`)

**LVS** proves that the physical chip is electrically identical to the logical design.

```{figure} ./figures/LVS.png
:align: center

*LVS flow — SPICE extraction from layout feeds into Netgen comparison against the power-aware netlist.*
```

**Step 1 — SPICE Extraction (`Magic.SpiceExtraction`):** Magic reverse-engineers the
electrical connectivity from the GDSII, producing a `.spice` file — the "as-built"
wiring diagram of the physical design.

**Step 2 — Netlist Comparison (`Netgen.LVS`):** Netgen compares Circuit 1 (extracted
SPICE — the as-built reality) against Circuit 2 (the power-aware `.pnl` netlist — the
as-planned intent). The comparison covers all logical pins, power pins (VPWR/VGND),
and substrate bias pins (VNB/VPB) required by the SkyWater 130nm PDK for latch-up
prevention.

---

## 7. Running the Physical Signoff Flow

With all signoff prep violations resolved via ECO, run the physical signoff steps
starting from the ECO run's final state:

```console
[nix-shell:~]$ librelane \
    ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/config.json \
    --run-tag classic_flow_eco \
    --from Magic.StreamOut \
    --with-initial-state \
    ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/runs/classic_flow_eco/14-openroad-irdropreport/state_out.json
```

When all steps complete, the terminal prints the final signoff summary:

```text
 Antenna
Passed ✅
 LVS
Passed ✅
 DRC
Passed ✅
```

---

## 8. Physical Signoff Results

### 8.1 DRC Report

**Location:** `runs/classic_flow_eco/64-magic-drc/reports/drc.magic.rpt`

```text
aes_wb_wrapper
----------------------------------------
[INFO] COUNT: 0
[INFO] Should be divided by 3 or 4
```

```{admonition} DRC: Clean Pass
:class: tip

**COUNT: 0** confirms zero Design Rule violations. The ECO buffers were placed and
routed without introducing any new geometric conflicts. The `aes_wb_wrapper` layout
is fully compliant with all SkyWater 130nm manufacturing constraints and is ready
for tape-out.

*Note:* The "Should be divided by 3 or 4" message is a Magic-internal counting
normalisation — a normalised count of 0 is an unambiguous clean result.
```

---

### 8.2 LVS Report

**Location:** `runs/classic_flow_eco/70-netgen-lvs/reports/lvs.netgen.rpt`

A representative subcircuit comparison for an AND4 gate:

```text
Subcircuit pins:
Circuit 1: sky130_fd_sc_hd__and4_4         |Circuit 2: sky130_fd_sc_hd__and4_4
-------------------------------------------|-------------------------------------------
A                                          |A
B                                          |B
C                                          |C
D                                          |D
VGND                                       |VGND
VNB                                        |VNB
VPB                                        |VPB
VPWR                                       |VPWR
X                                          |X
```

**Circuit 1** (left) — extracted SPICE netlist from the physical GDSII (as-built).  
**Circuit 2** (right) — power-aware `.pnl` synthesis netlist (as-planned).

Every pin matches identically — logical I/O (A, B, C, D, X), power (VPWR/VGND),
and substrate bias (VNB/VPB). The ECO-inserted `buf_4` cells are present and
correctly wired in both circuits.

```text
Cell pin lists are equivalent.
Device classes aes_wb_wrapper and aes_wb_wrapper are equivalent.
Final result: Circuits match uniquely.
```

```{admonition} LVS: Circuits Match Uniquely
:class: tip

**"Match"** — physical connections are logically identical to the netlist.
**"Uniquely"** — Netgen found no topological symmetry requiring ambiguity resolution.
Every one of the **27,332+ nets** across all **135,744+ instances** is proven to be
connected exactly where the synthesis netlist specifies. No shorts, opens, or
connectivity errors were introduced — including by the ECO buffer insertion and
re-routing.
```

---

## 9. Final Output Directory

When the signoff flow completes, LibreLane consolidates all deliverables into the
`final/` directory:

```text
runs/classic_flow_eco/final/
├── def/           ← Design Exchange Format (ASCII placement + routing)
├── gds/           ← GDSII layout (Magic) — primary fabrication file
├── klayout_gds/   ← GDSII layout (KLayout) — XOR-verified copy
├── lef/           ← LEF abstract for hierarchical SoC integration
├── lib/           ← Liberty timing models (one per PVT corner)
├── nl/            ← Structural gate-level netlist (no power pins)
├── pnl/           ← Power-aware netlist (with VPWR/VGND pins)
├── odb/           ← OpenROAD binary database
├── sdc/           ← Timing constraints applied at signoff
├── sdf/           ← Standard Delay Format (per-corner, for simulation)
├── spef/          ← Parasitic data (max/nom/min SPEF files)
├── spice/         ← Electrical netlist extracted from layout (for LVS)
├── vh/            ← Verilog header — blackbox stub for top-level synthesis
├── mag/ mag_gds/  ← Magic layout and GDS files
├── json_h/        ← JSON header for design metadata
├── metrics.csv    ← Final area, power, wire length, density summary
└── metrics.json   ← Machine-readable version of metrics
```

| Format | Extension | Purpose |
| :--- | :--- | :--- |
| **GDSII** | `.gds` | Fabrication master — submitted to the foundry. |
| **LEF** | `.lef` | Integration abstract for top-level SoC place-and-route. |
| **Liberty** | `.lib` | Timing model for higher-level synthesis tools. |
| **SPEF** | `.spef` | Parasitic data for post-layout simulation. |
| **Verilog Header** | `.vh` | Blackbox port-list stub for top-level synthesis. |
| **Power Netlist** | `.pnl` | Power-aware netlist for LVS and system power simulation. |
| **SDF** | `.sdf` | RC delays back-annotated per gate for timing-accurate simulation. |
| **ODB** | `.odb` | OpenROAD binary database for flow re-entry. |
| **Metrics** | `.csv` / `.json` | Quantitative signoff record — area, power, wire length, density. |

---

```{glossary}
GDSII
  Graphic Database System II. The standard binary layout format delivered to the foundry for fabrication.

DRC
  Design Rule Check. Verification that the layout conforms to foundry manufacturing constraints.

LVS
  Layout vs. Schematic. Verification that the physical layout is electrically equivalent to the design netlist.

SPICE
  Simulation Program with Integrated Circuit Emphasis. The file format produced by Magic extraction for LVS.

LEF
  Library Exchange Format. Physical interface description of a macro — boundary, pins, and blockages.

PDN
  Power Distribution Network. The metal grid delivering VDD and GND to every standard cell.

PnR
  Place and Route. Standard cell placement and signal wire routing.

STA
  Static Timing Analysis. Exhaustive path-by-path timing verification against declared constraints.

PVT
  Process, Voltage, Temperature. The three axes of semiconductor variation, analysed through multiple corners.

WNS
  Worst Negative Slack. The largest magnitude of negative slack across all failing timing paths.

TNS
  Total Negative Slack. The sum of all negative slack values across every failing path.

SDC
  Synopsys Design Constraints. Tcl-based timing and clocking constraints.
```

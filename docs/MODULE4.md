# Module 4: Physical Signoff

```{admonition} Prerequisites
:class: important

Before proceeding, ensure your **Module 3** routing run (`classic_flow`) has completed
successfully through step `52-checker-wirelength`. The signoff flow will resume from
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
3. [Physical Signoff Steps](#physical-signoff-steps)
   - [3.1 GDSII Generation](#gdsii-generation-magic-and-klayout-stream-out)
   - [3.2 Physical Abstract and Antenna Validation](#physical-abstract-and-antenna-validation)
   - [3.3 XOR Geometric Verification](#xor-geometric-verification-klayoutxor)
   - [3.4 Design Rule Check (DRC)](#design-rule-check-magic-drc--klayout-drc)
   - [3.5 Layout vs. Schematic (LVS)](#layout-vs-schematic-magicspiceextraction--netgenlvs)
4. [Running the Signoff Flow](#running-the-signoff-flow)
5. [Signoff Results Analysis](#signoff-results-analysis)
   - [5.1 Post-PnR STA Report](#post-pnr-sta-report)
   - [5.2 Power Report](#power-report)
   - [5.3 IR Drop Report](#ir-drop-report)
   - [5.4 DRC Report](#drc-report)
   - [5.5 LVS Report](#lvs-report)
6. [Final Output Directory](#final-output-directory)
7. [Resolving the Remaining Setup Violations](#resolving-the-remaining-setup-violations)

---

## 1. Signoff Flow Overview

The signoff stage transforms a routed design into a verified, manufacturable chip.
It is divided into two phases: **Signoff Prep** (electrical and timing verification)
and **Physical Signoff** (geometric and connectivity verification).

The table below shows all steps executed in this module, in order:

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
| | Setup Violations Check | `Checker.SetupViolations` |
| | Hold Violations Check | `Checker.HoldViolations` |
| | Max Slew Violations Check | `Checker.MaxSlewViolations` |
| | Max Cap Violations Check | `Checker.MaxCapViolations` |
| | Final Manufacturability Report | `Misc.ReportManufacturability` |

---

## 2. Signoff Prep

### 2.1 Fill Cell Insertion (`OpenROAD.FillInsertion`)

After Detailed Routing completes, the standard cell rows contain physical gaps between
functional cells — empty spaces where no logic, buffer, or clock cell was placed. The
`FillInsertion` step closes these gaps by inserting **filler cells** and **decap cells**
across the entire layout.

```{note}
This step marks a critical boundary in the flow. After fill insertion, the design is
considered **functionally frozen** — all logic, buffers, inverters, clock cells, and
antenna diodes are locked in place. The filler cells occupy the remaining silicon area,
completing the physical fabric of the chip.
```

#### What Filler Cells Do

Despite being non-functional, filler cells serve three essential physical roles:

| Role | Why It Matters |
| :--- | :--- |
| **N-well / P-well Continuity** | Standard cells require continuous substrate wells across every row. Gaps break these wells, creating discontinuities in the implant mask. Filler cells bridge the wells, ensuring a single uninterrupted mask layer across each row. |
| **Power Rail Continuity (VDD/VSS)** | Horizontal Metal 1 power rails must be electrically connected across the entire row. Without fillers, these rails "float" in the empty spaces, creating localised IR drop that degrades switching performance. Fillers act as a physical conductor bridge for the power grid. |
| **Manufacturing Yield** | Empty spaces create density gradients during chemical-mechanical polishing (CMP). Non-uniform density leads to surface defects during etching, reducing the ratio of functional dies per wafer. Filling all gaps ensures uniform density and maximises yield. |

Filler cells are available in a range of widths so that any gap —
regardless of size — can be packed exactly. The tool automatically selects the correct
combination of cell widths to fill every space without overlap.

The figures below show the layout before and after fill insertion in the OpenROAD GUI:

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

With the layout physically complete, the **OpenRCX** engine converts the routed geometry
into an electrical model. Every wire has real resistance (from its length and cross-section)
and real capacitance (from its proximity to adjacent wires and the substrate). Parasitic
extraction captures these values precisely so the downstream {term}`STA` uses actual
physical delays rather than statistical estimates.

```{figure} ./figures/OpenRCX.png
:align: center

*OpenRCX inputs and outputs*
```

#### The Extraction Process

**RC Segment Generation** — The engine breaks each physical wire into a series of smaller
electrical segments. It calculates the resistance of each segment based on its layer,
width, and length, and adds the resistance of every via used to transition between layers.

**Capacitance Calculation** — Two types of capacitance are modelled:

- *Coupling capacitance:* The electrical interaction between parallel wires on the same
  layer. This is the primary mechanism for crosstalk and must be accounted for on all
  critical timing paths.
- *Ground capacitance:* The capacitance between a wire and the substrate or ground
  planes below it.

**Filtering** — A coupling threshold of **0.1 fF** is applied. Any coupling capacitance
below this threshold is "grounded" (merged into the net's total ground capacitance),
simplifying the SPEF without losing accuracy.

#### Output — Three Corner SPEF Files

The extraction is run for three process corners, producing a separate SPEF file for each:

```text
runs/classic_flow/55-openroad-rcx/
    ├── max/
    │   └── aes_wb_wrapper.max.spef
    ├── nom/
    │   └── aes_wb_wrapper.nom.spef
    └── min/
        └── aes_wb_wrapper.min.spef
```

| Corner | SPEF | Purpose |
| :--- | :--- | :--- |
| `max` | `aes_wb_wrapper.max.spef` | Worst-case parasitics — maximum wire resistance and capacitance. Used for Setup analysis. |
| `nom` | `aes_wb_wrapper.nom.spef` | Nominal parasitics — typical operating conditions. |
| `min` | `aes_wb_wrapper.min.spef` | Best-case parasitics — minimum resistance and capacitance. Used for Hold analysis. |

The **SPEF (Standard Parasitic Exchange Format)** file is a text-based map of the
resistance and capacitance of every net in the design. It is consumed directly by the
Post-{term}`PnR` STA engine in the next step, enabling the first truly accurate timing
analysis of the physical design.

---

### 2.3 Post-PnR Static Timing Analysis (`OpenROAD.STAPostPNR`)

```{figure} ./figures/OpenSTA.png
:align: center

*Post-PnR STA flow — SPEF parasitics enable physically accurate timing analysis for the first time.*
```

The **Post-{term}`PnR` STA** step is the most authoritative timing check in the entire
flow. The OpenSTA engine performs a comprehensive analysis of the completed physical
netlist, now annotated with the exact RC parasitics from the RCX step.

This is fundamentally different from all earlier STA checkpoints:

| Analysis Stage | Parasitic Source | Accuracy |
| :--- | :--- | :--- |
| Pre-{term}`PnR` STA (Module 1) | Statistical wire-load models | Low — estimates only |
| Mid-{term}`PnR` STA (Modules 2–3) | Global routing RC estimates | Medium — approximate paths |
| **Post-{term}`PnR` STA (this step)** | **RCX SPEF — actual wire geometry** | **High — silicon-accurate** |

#### Multi-Corner Analysis

To guarantee the chip operates correctly across all possible manufacturing and
environmental conditions, the analysis covers **9 PVT corners**:

```text
max_ss_100C_1v60    nom_ss_100C_1v60    min_ss_100C_1v60
max_tt_025C_1v80    nom_tt_025C_1v80    min_tt_025C_1v80
max_ff_n40C_1v95    nom_ff_n40C_1v95    min_ff_n40C_1v95
```

```{note}
Earlier STA stages (pre-{term}`PnR` and mid-{term}`PnR`) analyse only **3 corners**.
Post-{term}`PnR` STA expands to **9 corners** — three process splits (max / nom / min)
for each of the three temperature-voltage combinations — providing complete coverage
of the {term}`PVT` space.
```

Each corner produces a dedicated directory of reports inside the step folder:

```text
runs/classic_flow/56-openroad-stapostpnr/
└── max_ff_n40C_1v95/
    ├── aes_wb_wrapper__max_ff_n40C_1v95.lib   ← Liberty timing model for this corner
    ├── aes_wb_wrapper__max_ff_n40C_1v95.sdf   ← Standard Delay Format (for simulation)
    ├── max.rpt                                 ← Constrained paths for Setup (max) checks
    ├── min.rpt                                 ← Constrained paths for Hold (min) checks
    ├── wns.max.rpt / wns.min.rpt              ← Worst Negative Setup / Hold Slack
    ├── tns.max.rpt / tns.min.rpt              ← Total Negative Setup / Hold Slack
    ├── ws.max.rpt / ws.min.rpt                ← Worst Setup / Hold Slack 
    ├── skew.max.rpt / skew.min.rpt            ← Clock skew for Setup / Hold
    ├── power.rpt                               ← Corner-specific power breakdown
    ├── checks.rpt                              ← Max Cap, Slew, Fanout, unconstrained paths
    ├── violator_list.rpt                       ← All failing Setup and Hold endpoints
    ├── clock.rpt                               ← Clock domain summary
    ├── sta.log                                 ← Full raw STA engine output
    └── unpropagated.rpt                        ← Nets with unannotated parasitics
```

---

### 2.4 IR Drop Analysis (`OpenROAD.IRDropReport`)

After timing analysis, LibreLane evaluates the integrity of the **Power Distribution
Network ({term}`PDN`)** using a static IR drop analysis. Every wire in the power and
ground network has resistance, which causes a voltage drop as current flows from the
supply pads to the standard cells. If this drop is too large, cells may operate below
their specified voltage, slowing switching and potentially causing functional failures.

#### What the Step Analyses

The tool evaluates both the `VPWR` and `VGND` networks separately:

- **Power net (`VPWR`):** Measures the decrease in voltage from the supply source to
  the cells — the classical IR drop. Excessive drop slows logic and degrades setup margin.

- **Ground net (`VGND`):** Measures the rise in ground voltage due to resistive current
  return paths — known as *ground bounce*. This reduces the effective noise margin of
  every standard cell in the affected region.

The analysis is performed on the `max_ss_100C_1v60` corner — the worst-case
combination of highest resistance (slow process, low voltage) and highest current demand.

#### Output

The report is located at:
```text
runs/classic_flow/57-openroad-irdropreport/irdrop.rpt
```

---

## 3. Physical Signoff Steps

### 3.1 GDSII Generation (Magic and KLayout Stream-Out)

After all electrical verification passes, the design must be converted from its
internal OpenROAD representation (DEF/ODB) into **{term}`GDSII`** — the binary format
accepted by semiconductor foundries for fabrication. LibreLane performs this conversion
using two independent tools, providing a cross-check against conversion errors.

#### `Magic.StreamOut`

Magic performs a technology-aware conversion of the DEF layout into GDSII:

1. Loads the standard cell GDS library files from the SkyWater 130nm PDK.
2. Reads the routed DEF design.
3. Places each cell according to its DEF coordinates.
4. Reconstructs all routing geometries on the correct metal layers.
5. Writes the final `aes_wb_wrapper.magic.gds`.

Magic uses the `.magicrc` technology file to ensure correct layer mapping and
produces geometry that is guaranteed to be DRC-compatible within its rule framework.
Its output is used as the primary signoff-quality GDS for DRC and LVS.

#### `KLayout.StreamOut`

KLayout performs a complementary conversion with an emphasis on efficient merging:

1. Merges the macro's DEF routing data with the standard cell library GDS files.
2. Verifies that every component defined in the LEF has a corresponding physical
   geometry in the GDS — flagging any "missing GDS" entries.
3. Produces the final `aes_wb_wrapper.klayout.gds` — a complete top-level assembly.

```{tip}
Running both Magic and KLayout for GDS generation is a deliberate redundancy strategy.
Each tool has different internal interpretations of layer mapping and macro boundary
handling. If either tool introduces a subtle misinterpretation, the discrepancy will
surface during the XOR comparison in Section 3.3 before the design reaches the foundry.
```

---

### 3.2 Physical Abstract and Antenna Validation

#### Abstract Generation (`Magic.WriteLEF`)

Once the full GDS is generated, Magic creates a **{term}`LEF` (Library Exchange Format)**
abstract of the `aes_wb_wrapper`. This file strips away all internal transistors,
routing, and standard cells — retaining only the essential "outer" features:

- The macro boundary and pin locations.
- The metal layers that block or obstruct external routing.
- The antenna gate area metadata for each input pin.

The LEF abstract enables other designers to use the `aes_wb_wrapper` as a black-box
component in a larger SoC. Their place-and-route tools can connect to the pins and
route around the macro without having to process or understand the 135,000+ internal
cells.

```{figure} ./figures/.png
:align: center

*LEF abstract view of* `aes_wb_wrapper` *in KLayout — only the boundary, pins, and blockage layers are visible.*
```

#### Antenna Metadata Validation (`Odb.CheckDesignAntennaProperties`)

After the LEF is written, the tool scans it to verify that it contains the **antenna
gate area metadata** for every input pin. This metadata documents the size of the
transistor gates connected to each input.

```{note}
This check is a **documentation audit**, not a physical DRC. Its purpose is to ensure
that the LEF "safety manual" correctly informs future designers how much accumulated
charge each input pin can tolerate before the connected gate oxide is at risk of damage.
When another team integrates this macro into a larger chip, their EDA tools will use
this metadata to apply antenna repair rules at the system level — protecting your
transistors from their routing.
```

---

### 3.3 XOR Geometric Verification (`KLayout.XOR`)

With two independently generated GDS files in hand (from Magic and KLayout), the
XOR step performs a geometric **redundancy check** — the most rigorous cross-validation
in the entire flow.

The tool computes a layer-by-layer geometric XOR between:

1. `aes_wb_wrapper.magic.gds` — the Magic-generated layout.
2. `aes_wb_wrapper.klayout.gds` — the KLayout-generated layout.

The logic is simple: if both tools interpreted the design identically, every polygon in
one file overlaps exactly with a polygon in the other. The XOR of two perfectly
overlapping shapes is zero — no remaining geometry. Any disagreement between the tools
produces a "leftover" polygon at the location of the discrepancy.

The target result is:

```text
Total XOR differences: 0
```

This confirms that both Magic and KLayout have produced identical physical representations.

---

### 3.4 Design Rule Check (Magic.DRC & KLayout.DRC)

Before manufacturing, the complete layout must pass a **Design Rule Check ({term}`DRC`)**
— a comprehensive scan that verifies every geometric shape in the design complies with
the SkyWater 130nm foundry's manufacturing rules.

#### What Is Checked

The DRC engine scans tens of thousands of rules covering every layer and interaction in
the design:

- **Minimum width:** Metal wires and vias must meet minimum dimension requirements for
  reliable patterning during lithography.
- **Minimum spacing:** Adjacent polygons must be separated by at least the process
  minimum to prevent electrical shorts during fabrication.
- **Via enclosure:** Vias connecting adjacent metal layers must be enclosed by a minimum
  overlap of the metal shape above and below.
- **Density uniformity:** Metal density on each layer must fall within a defined range
  to ensure the CMP process produces a flat surface.
- **Grid alignment:** All shapes must align to the manufacturing grid — shapes off-grid
  produce yield-killing mask misalignments.

#### Why Two DRC Tools?

LibreLane runs both Magic and KLayout DRC because each tool applies different subsets
of the rule deck with different internal algorithms. Violations that fall within one
tool's interpretation boundary may be caught by the other. Together they provide
complete coverage of the foundry's rule set.

---

### 3.5 Layout vs. Schematic (`Magic.SpiceExtraction` & `Netgen.LVS`)

**LVS (Layout vs. Schematic)** is the final electrical audit of the design. It proves
that the physical chip — as represented by the routed GDSII layout — is electrically
identical to the logical design — as represented by the post-synthesis Verilog netlist.

```{figure} ./figures/.png
:align: center

*LVS flow diagram — SPICE extraction from layout feeds into Netgen comparison against the power-aware netlist.*
```

#### Step 1 — SPICE Extraction (`Magic.SpiceExtraction`)

Magic scans the physical GDSII layout to reverse-engineer the electrical connectivity.
It identifies how every metal wire and via connects the 27,000+ nets and 135,000+ cell
instances, producing a `.spice` file — the "as-built" wiring diagram of the physical
design. Standard cells are treated as black boxes; Magic focuses on the global
interconnect between them.

#### Step 2 — Netlist Comparison (`Netgen.LVS`)

Netgen compares two netlists:

- **Circuit 1 (Layout Netlist):** Extracted from the physical GDSII by Magic — the
  "as-built" reality.
- **Circuit 2 (Schematic Netlist):** The power-aware `.pnl` netlist from synthesis —
  the "as-planned" design intent.

Netgen performs a device-level and net-level topology match. For every gate in the
design, it verifies that every pin is connected to the correct net. The comparison
covers all logical pins (inputs and outputs), power pins (`VPWR`/`VGND`), and
substrate bias pins (`VNB`/`VPB`) — the body connections that prevent latch-up in
the SkyWater 130nm process.

---

## 4. Running the Signoff Flow

This run resumes from the last completed routing step using `--with-initial-state`,
avoiding any repetition of synthesis, placement, or routing. The `--from` flag is not
needed — LibreLane determines the correct starting step automatically from the state file.

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
    --with-initial-state \
    ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/runs/classic_flow/52-checker-wirelength/state_out.json
```

When the flow completes successfully, the terminal will print the final signoff summary:

```text
 Antenna
Passed ✅
 LVS
Passed ✅
 DRC
Passed ✅
```

---

## 5. Signoff Results Analysis

### 5.1 Post-PnR STA Report

**Location:** `runs/classic_flow/56-openroad-stapostpnr/summary.rpt`

```text
┏━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━┓
┃                      ┃ Hold     ┃ Reg to   ┃          ┃          ┃ of which  ┃ Setup    ┃           ┃          ┃           ┃ of which ┃           ┃          ┃
┃                      ┃ Worst    ┃ Reg      ┃          ┃ Hold Vio ┃ reg to    ┃ Worst    ┃ Reg to    ┃ Setup    ┃ Setup Vio ┃ reg to   ┃ Max Cap   ┃ Max Slew ┃
┃ Corner/Group         ┃ Slack    ┃ Paths    ┃ Hold TNS ┃ Count    ┃ reg       ┃ Slack    ┃ Reg Paths ┃ TNS      ┃ Count     ┃ reg      ┃ Violatio… ┃ Violati… ┃
┡━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━┩
│ Overall              │ 0.1470   │ 0.1470   │ 0.0000   │ 0        │ 0         │ -0.1455  │ -0.1455   │ -0.2302  │ 2         │ 2        │ 7         │ 31       │
│ nom_tt_025C_1v80     │ 0.2846   │ 0.2846   │ 0.0000   │ 0        │ 0         │ 8.5010   │ 12.1043   │ 0.0000   │ 0         │ 0        │ 0         │ 0        │
│ nom_ss_100C_1v60     │ 0.6792   │ 0.6792   │ 0.0000   │ 0        │ 0         │ 0.9815   │ 0.9815    │ 0.0000   │ 0         │ 0        │ 2         │ 4        │
│ nom_ff_n40C_1v95     │ 0.1477   │ 0.1477   │ 0.0000   │ 0        │ 0         │ 9.4759   │ 16.5409   │ 0.0000   │ 0         │ 0        │ 0         │ 0        │
│ min_tt_025C_1v80     │ 0.2836   │ 0.2836   │ 0.0000   │ 0        │ 0         │ 8.6093   │ 12.7176   │ 0.0000   │ 0         │ 0        │ 0         │ 0        │
│ min_ss_100C_1v60     │ 0.6771   │ 0.6771   │ 0.0000   │ 0        │ 0         │ 1.4319   │ 2.0856    │ 0.0000   │ 0         │ 0        │ 2         │ 4        │
│ min_ff_n40C_1v95     │ 0.1470   │ 0.1470   │ 0.0000   │ 0        │ 0         │ 9.5472   │ 16.9444   │ 0.0000   │ 0         │ 0        │ 0         │ 0        │
│ max_tt_025C_1v80     │ 0.2848   │ 0.2848   │ 0.0000   │ 0        │ 0         │ 8.4058   │ 11.4998   │ 0.0000   │ 0         │ 0        │ 0         │ 0        │
│ max_ss_100C_1v60     │ 0.6802   │ 0.6802   │ 0.0000   │ 0        │ 0         │ -0.1455  │ -0.1455   │ -0.2302  │ 2         │ 2        │ 7         │ 31       │
│ max_ff_n40C_1v95     │ 0.1479   │ 0.1479   │ 0.0000   │ 0        │ 0         │ 9.4155   │ 16.1424   │ 0.0000   │ 0         │ 0        │ 0         │ 0        │
└──────────────────────┴──────────┴──────────┴──────────┴──────────┴───────────┴──────────┴───────────┴──────────┴───────────┴──────────┴───────────┴──────────┘
```

```{admonition} Interpreting the Post-PnR STA Results
:class: tip

**Hold violations: fully resolved.** All corners show positive Hold WNS (≥ 0.147 ns),
confirming that the CTS and post-CTS repair passes from Module 2 successfully closed
every hold path. This result applies across all 9 corners.

**Setup violations: 2 remain in `max_ss_100C_1v60`.** The Setup WNS of **-0.1455 ns**
with a TNS of **-0.2302 ns** indicates 2 register-to-register paths failing timing by
a small margin at the worst-case corner. All other 8 corners show zero setup violations
with comfortable positive slack.

**Max Slew and Max Cap: reduced significantly.** Compared to the pre-{term}`PnR` STA
(2,379 slew violations), the post-{term}`PnR` count of 31 violations demonstrates the
effectiveness of the `signoff.sdc` 1.5 ns transition limit applied at this stage.

The 2 remaining setup violations in `max_ss_100C_1v60` are addressed in
[Section 7](#resolving-the-remaining-setup-violations).
```

---

### 5.2 Power Report

**Location:** `runs/classic_flow/56-openroad-stapostpnr/max_ff_n40C_1v95/power.rpt`

The worst-case power consumption occurs at the `max_ff_n40C_1v95` corner — fast
transistors at low temperature and high voltage switch at their maximum rate, producing
the highest dynamic power:

```text
======================= max_ff_n40C_1v95 Corner ===================================
Group                    Internal    Switching      Leakage        Total
                            Power        Power        Power        Power (Watts)
------------------------------------------------------------------------
Sequential           5.654275e-03 5.247708e-05 6.859135e-08 5.706821e-03  28.2%
Combinational        3.142535e-03 6.200964e-03 2.692677e-07 9.343768e-03  46.2%
Clock                2.409271e-03 2.762205e-03 3.317228e-07 5.171807e-03  25.6%
Macro                0.000000e+00 0.000000e+00 0.000000e+00 0.000000e+00   0.0%
Pad                  0.000000e+00 0.000000e+00 0.000000e+00 0.000000e+00   0.0%
------------------------------------------------------------------------
Total                1.120604e-02 9.015639e-03 6.697635e-07 2.022235e-02 100.0%
                            55.4%        44.6%         0.0%
```

```{note}
The **combinational logic** (46.2%) dominates total power, driven primarily by
switching activity in the AES datapath — the repeated XOR, shift, and substitution
operations of the cipher. The **clock network** (25.6%) represents a significant
investment from distributing the clock to all 2,995 flip-flops; this is typical for
a design with a balanced H-Tree of this scale. **Leakage power** (0.0%) is negligible
at this corner, as fast transistors have higher leakage than slow ones but the dynamic
component overwhelms it.

Total power of **~20 mW** is well within the Caravel User Project power budget.
```

---

### 5.3 IR Drop Report

**Location:** `runs/classic_flow/57-openroad-irdropreport/irdrop.rpt`

```text
########## IR report #################
Net              : VPWR
Corner           : max_ss_100C_1v60
Total power      : 1.28e-02 W
Supply voltage   : 1.60e+00 V
Worstcase voltage: 1.60e+00 V
Average voltage  : 1.60e+00 V
Average IR drop  : 9.82e-05 V
Worstcase IR drop: 8.13e-04 V
Percentage drop  : 0.05 %
######################################

########## IR report #################
Net              : VGND
Corner           : max_ss_100C_1v60
Total power      : 1.28e-02 W
Supply voltage   : 0.00e+00 V
Worstcase voltage: 7.47e-04 V
Average voltage  : 9.74e-05 V
Average IR drop  : 9.74e-05 V
Worstcase IR drop: 7.47e-04 V
Percentage drop  : 0.05 %
######################################
```

```{admonition} IR Drop Analysis — Excellent PDN Health
:class: tip

The worst-case IR drop is **0.05%** on both `VPWR` and `VGND` — well within the
standard industry signoff requirement of **< 2–5%**. This result confirms that the
PDN configuration from Module 1 (`PDN_MULTILAYER: false`, Metal 4 vertical straps only)
provides adequate power delivery for the AES core under worst-case conditions.

The uniformity of the average and worst-case values (9.82e-05 V vs 8.13e-04 V for VPWR)
reflects the efficiency of the regular strap pitch (153.6 µm) — no localised hot spots
or under-powered regions exist in the core.
```

---

### 5.4 DRC Report

**Location:** `runs/classic_flow/64-magic-drc/reports/drc.magic.rpt`

```text
aes_wb_wrapper
----------------------------------------
[INFO] COUNT: 0
[INFO] Should be divided by 3 or 4
```

```{admonition} DRC: Clean Pass
:class: tip

**COUNT: 0** confirms zero Design Rule violations. The `aes_wb_wrapper` layout is fully
compliant with all SkyWater 130nm manufacturing constraints and is ready for tape-out.

The note *"Should be divided by 3 or 4"* is a Magic-specific diagnostic: the internal
violation counter increments differently for different rule types, and Magic normalises
the count. A normalised count of 0 is an unambiguous clean result.
```

---

### 5.5 LVS Report

**Location:** `runs/classic_flow/70-netgen-lvs/reports/lvs.netgen.rpt`

The LVS report confirms pin-level equivalence for every cell in the design. A representative
subcircuit comparison for an AND4 gate illustrates the verification format:

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

**Circuit 1** (left) is the netlist extracted from the physical GDSII by Magic — the
"as-built" reality of what was actually connected on the silicon floor. **Circuit 2**
(right) is the power-aware `.pnl` netlist from synthesis — the "as-planned" design intent.

Every pin — logical inputs and outputs (A, B, C, D, X), supply pins (VPWR/VGND), and
substrate bias pins (VNB/VPB) — matches identically. VNB and VPB are the N-well and
P-substrate body connections required by the SkyWater 130nm PDK to correctly bias
transistors and prevent latch-up.

The report concludes with the definitive LVS verdict:

```text
Cell pin lists are equivalent.
Device classes aes_wb_wrapper and aes_wb_wrapper are equivalent.
Final result: Circuits match uniquely.
```

```{admonition} LVS: Circuits Match Uniquely
:class: tip

**"Match"** confirms that the physical connections are logically identical to the
netlist. **"Uniquely"** is the critical qualifier — it means Netgen found no
topological symmetry that could allow multiple valid interpretations. Every one of the
**27,332 nets** across the **135,744 instances** was proven to be connected exactly
where the synthesis netlist specifies. There was no ambiguity, no guessing, no open
or short circuits introduced during routing.
```

---

## 6. Final Output Directory

When the signoff flow completes, LibreLane consolidates all deliverables into the
`final/` directory of the run:

```text
runs/classic_flow/final/
├── def/           ← Design Exchange Format (ASCII placement + routing)
├── gds/           ← GDSII layout (Magic) — primary fabrication file
├── klayout_gds/   ← GDSII layout (KLayout) — XOR-verified copy
├── mag/           ← Magic layout database
├── mag_gds/       ← GDS exported via Magic
├── lef/           ← LEF abstract for hierarchical integration
├── lib/           ← Liberty timing models (one per PVT corner)
├── nl/            ← Structural gate-level netlist (no power pins)
├── odb/           ← OpenROAD binary database
├── pnl/           ← Power-aware netlist (with VPWR/VGND pins)
├── sdc/           ← Timing constraints applied at signoff
├── sdf/           ← Standard Delay Format (per-corner, for simulation)
├── spef/          ← Parasitic data (max/nom/min SPEF files)
├── spice/         ← Electrical netlist extracted from layout (for LVS)
├── vh/            ← Verilog header — blackbox stub for top-level integration
├── json_h/        ← JSON header for design metadata
├── metrics.csv    ← Final area, power, wire length, and density summary
└── metrics.json   ← Machine-readable metrics (same data as CSV)
```

Each output format serves a specific role in the handoff to the next integration stage:

| Format | Extension | Purpose |
| :--- | :--- | :--- |
| **GDSII** | `.gds` | The fabrication master — submitted to the foundry. Contains every physical polygon on every layer. |
| **LEF** | `.lef` | The integration abstract — used by top-level SoC tools to place and connect the macro without processing its internals. |
| **Liberty** | `.lib` | The timing model — used by synthesis tools that instantiate this macro in a larger design. |
| **SPEF** | `.spef` | Parasitic data — enables accurate post-layout simulation of any system that includes this macro. |
| **Verilog Header** | `.vh` | The blackbox stub — a module declaration with only the port list, used for top-level synthesis without re-synthesising the macro. |
| **Power Netlist** | `.pnl` | Power-aware netlist — includes explicit VDD/GND pins for LVS and power simulation at the system level. |
| **SDF** | `.sdf` | Standard Delay Format — maps RC delays from the SPEF to specific gate instances for timing-accurate RTL simulation. |
| **ODB** | `.odb` | OpenROAD binary database — preserves the full design state for re-entry into any OpenROAD-based flow. |
| **Metrics** | `.csv` / `.json` | Summary of final area, power, wire length, and routing density — the quantitative signoff record. |

---

## 7. Resolving the Remaining Setup Violations

```{admonition} Section Under Development
:class: note

The Post-{term}`PnR` STA report shows **2 Setup violations** in the
`max_ss_100C_1v60` corner with a {term}`WNS` of **-0.1455 ns** and a
{term}`TNS` of **-0.2302 ns**. Both failing paths are register-to-register
paths — internal datapath violations, not I/O-constrained paths.

This section will document the analysis and resolution of these violations,
including the identification of the failing paths from `violator_list.rpt`
and the specific configuration or SDC changes applied to close timing.
```

---

```{glossary}
GDSII
  Graphic Database System II. The standard binary file format representing the final IC physical layout, submitted to the foundry for fabrication.

DRC
  Design Rule Check. Verification that the physical layout conforms to the foundry's manufacturing constraints.

LVS
  Layout vs. Schematic. Verification that the physical layout is electrically equivalent to the design's logical netlist.

SPICE
  Simulation Program with Integrated Circuit Emphasis. An analog circuit simulator; the file format produced by Magic layout extraction for LVS.

LEF
  Library Exchange Format. A file describing the physical interface of a macro — its boundary, pin locations, and metal blockages — used for hierarchical integration.

PDN
  Power Distribution Network. The metal conductor grid delivering VDD and GND to every standard cell.

PnR
  Place and Route. The physical design stage encompassing standard cell placement and signal wire routing.

STA
  Static Timing Analysis. Timing verification performed by exhaustively checking all signal paths against declared constraints.

PVT
  Process, Voltage, Temperature. The three axes of semiconductor manufacturing variation, analysed through multiple design corners.

WNS
  Worst Negative Slack. The largest magnitude of negative slack across all failing timing paths.

TNS
  Total Negative Slack. The arithmetic sum of all negative slack values across every failing timing path.

SDC
  Synopsys Design Constraints. A Tcl-based format specifying timing and clocking constraints for implementation and signoff.
```

# Module 2: Timing Optimization & Design Repair

```{admonition} Prerequisites
:class: important

Before proceeding, ensure you have completed **Module 1** and that your Classic Flow run
(`classic_to_pdn`) has finished successfully. Your `config.json` and both SDC files
(`pnr.sdc`, `signoff.sdc`) must be in place before applying the changes described in this module.
```

---

## Table of Contents

1. [Addressing Slew and Capacitance Violations](#addressing-slew-and-capacitance-violations)
   - [1.1 Understanding Slew and Capacitance](#understanding-slew-and-capacitance)
   - [1.2 Relaxing the Transition Constraint](#relaxing-the-transition-constraint)
2. [Automated Design Repair Strategies](#automated-design-repair-strategies)
   - [2.1 Adjusting Repair Margins](#adjusting-repair-margins)
   - [2.2 Updated Configuration File](#updated-configuration-file)
3. [Executing the Optimized Run](#executing-the-optimized-run)
   - [3.1 Flow Execution](#flow-execution)
   - [3.2 Output Directory Structure](#output-directory-structure)
4. [Analyzing the Results](#analyzing-the-results)
   - [4.1 Timing Summary Comparison](#timing-summary-comparison)
   - [4.2 Task: Comparative Analysis](#task-comparative-analysis)

---

## 1. Addressing Slew and Capacitance Violations

In Module 1, your {term}`STA` report likely showed a high count of **Max Slew** and
**Max Cap** violations in the pre-placement summary. While these are expected and normal
at the pre-{term}`PnR` stage — because no physical wire parasitics exist yet — they must
be managed systematically during the Placement and Design Repair phases to ensure final
signal integrity and timing closure.

This section explains what these violations mean physically, and introduces the two
configuration knobs used to bring them under control.

---

### 1.1 Understanding Slew and Capacitance

Before tuning the tool, it is important to understand what is being constrained and why
violations occur in the first place.

#### Signal Slew (Transition Time)

**Slew** (also called *transition time*) is the time a signal takes to switch between
logic LOW and logic HIGH — measured between the 10% and 90% voltage thresholds of the
supply rail.

A signal with a **slow slew rate** (long transition time) causes several problems:

| Problem | Explanation |
| :--- | :--- |
| **Increased propagation delay** | A slowly rising signal reaches the switching threshold of downstream gates later, adding delay to every path in the fan-out cone. |
| **Increased short-circuit power** | During the transition window, both PMOS and NMOS transistors in a CMOS gate are momentarily on simultaneously, drawing a short-circuit current from VDD to GND. |
| **Setup and hold violations** | Delayed arrivals at register inputs directly cause Setup violations. Degraded drive strength can also introduce Hold violations in tight paths. |
| **Noise susceptibility** | A slowly changing signal spends more time in the metastable region, making it more susceptible to coupling noise from adjacent nets. |

The {term}`STA` engine flags a **Max Slew violation** when the transition time on any net
exceeds the declared constraint (`MAX_TRANSITION_CONSTRAINT`).

#### Net Capacitance

**Net capacitance** is the total electrical load a driver gate must charge and discharge
on every clock cycle. It is the sum of:

- The **wire capacitance** of the routed interconnect.
- The **input capacitances** of every gate in the fan-out list.

Excessive capacitance manifests identically to a slow slew: the RC time constant of the
driving cell's output resistance and the net's load capacitance directly sets the
transition speed. The {term}`STA` engine flags a **Max Cap violation** when this total
load exceeds the cell's rated drive capability, as specified in the Liberty (`.lib`) file.

```{note}
**Why are there so many violations before Placement?**

At the pre-placement stage, OpenROAD has not yet assigned physical locations to cells or
routed any wires. Capacitance estimates are based on statistical wire-length models
(*virtual routing*), which are pessimistic by design. The violations you observe in the
`12-openroad-staprepnr` report are therefore an **overestimate** — many will disappear
after actual placement and routing assigns shorter, real wire paths to the nets.

The remaining violations that persist after routing are the ones that require active
repair via buffer insertion and gate resizing.
```

---

### 1.2 Relaxing the Transition Constraint

The default LibreLane configuration applies a **strict 0.75 ns** limit on signal
transitions via the `MAX_TRANSITION_CONSTRAINT` variable. This is a conservative
guard-band intended to ensure quality across a wide range of designs.

However, the **SkyWater 130nm Liberty files** characterize the `sky130_fd_sc_hd` cell
library for a transition limit of **1.5 ns**. Enforcing a limit tighter than the
library's own characterization boundary causes the Resizer to perform unnecessary
buffering — inserting extra cells that consume area and power without improving actual
manufacturability.

```{admonition} Key Concept — Library Characterization Boundary
:class: tip

A Liberty (`.lib`) file characterizes each cell's timing and power at a set of defined
input slew and output load table points. Setting `MAX_TRANSITION_CONSTRAINT` beyond the
library's characterized boundary (1.5 ns for `sky130_fd_sc_hd`) forces the tool to
repair transitions that the library tables do not actually model as problematic. This
wastes area and can paradoxically introduce new violations by over-driving nets.
```

#### Action — Update `config.json`

Open your configuration file:

```console
$ gedit ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/config.json
```

Add the following parameter:

```json
"MAX_TRANSITION_CONSTRAINT": 1.5
```

This single change aligns the tool's repair target with the SkyWater library's own
characterized limit, reducing unnecessary buffer insertion and improving {term}`PPA`
outcomes.

---

## 2. Automated Design Repair Strategies

LibreLane uses **OpenROAD's Resizer** engine to fix timing and electrical violations
automatically. The Resizer operates by:

- **Inserting buffers** on nets with excessive capacitance or slow transitions.
- **Upsizing gates** to cells with stronger drive strength.
- **Downsizing gates** on non-critical paths to recover area and reduce power.

For a complex design like the `aes_wb_wrapper`, the default repair effort may not be
aggressive enough to fully eliminate all violations within a single repair pass.

---

### 2.1 Adjusting Repair Margins

The Resizer uses **percentage-based margin parameters** to determine how aggressively it
pursues violations. These margins define a safety buffer *above* the nominal limit:
a repair margin of 20% means the tool will attempt to fix violations that are within
20% of the constraint limit, even if they are not yet strictly violating it.

| Parameter | Default | Purpose |
| :--- | :---: | :--- |
| `DESIGN_REPAIR_MAX_SLEW_PCT` | `20` | Percentage above `MAX_TRANSITION_CONSTRAINT` at which the Resizer proactively repairs nets. |
| `DESIGN_REPAIR_MAX_CAP_PCT` | `20` | Percentage above the cell's rated max capacitance at which the Resizer proactively repairs nets. |

Increasing these values from **20% to 30%** instructs the Resizer to cast a wider net,
catching marginally compliant paths that might degrade to full violations after routing
introduces additional parasitic capacitance.

```{tip}
Think of these margin parameters as a **predictive repair buffer**. The physical routing
step adds real wire capacitance on top of the pre-placement estimates. A repair margin
of 30% ensures that paths which are 25% over the limit post-placement — but not yet
hard violations pre-placement — are repaired proactively rather than discovered as
failures at signoff.
```

---

### 2.2 Updated Configuration File

Apply all three parameters together. Open `config.json` and update it to the following:

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
    "MAX_TRANSITION_CONSTRAINT": 1.5,
    "DESIGN_REPAIR_MAX_SLEW_PCT": 30,
    "DESIGN_REPAIR_MAX_CAP_PCT": 30
}
```

#### New Parameter Summary

| Parameter | Old Value | New Value | Effect |
| :--- | :---: | :---: | :--- |
| `MAX_TRANSITION_CONSTRAINT` | `0.75` ns | **`1.5`** ns | Aligns the repair target with the `sky130_fd_sc_hd` library characterization boundary. Reduces unnecessary buffering. |
| `DESIGN_REPAIR_MAX_SLEW_PCT` | `20`% | **`30`**% | Increases the Resizer's proactive slew repair margin, catching borderline paths before routing worsens them. |
| `DESIGN_REPAIR_MAX_CAP_PCT` | `20`% | **`30`**% | Increases the Resizer's proactive capacitance repair margin, reducing post-routing cap violations. |

```{warning}
**Do not set `MAX_TRANSITION_CONSTRAINT` above 1.5 ns.** Values beyond the library's
characterized boundary produce extrapolated (and therefore unreliable) timing data.
The resulting {term}`STA` reports may show artificially clean results that do not
reflect the silicon's true behaviour.
```

---

## 3. Executing the Optimized Run

With the configuration updated, re-execute the flow. We continue using the Classic flow
and run up to the same `Odb.RemovePDNObstructions` endpoint as in Module 1, but with a
new `--run-tag` to preserve the previous baseline for comparison.

---

### 3.1 Flow Execution

Ensure you are inside the Nix shell before proceeding:

```console
$ nix-shell --pure ~/librelane/shell.nix
```

Your prompt should read `[nix-shell:~]$`. Then execute:

```console
[nix-shell:~]$ librelane \
    --run-tag classic_slew_repaired \
    --to Odb.RemovePDNObstructions \
    ~/Silicon-Sprint-AUC/openlane/aes_wb_wrapper/config.json
```

```{tip}
Using a distinct `--run-tag` (`classic_slew_repaired`) preserves your Module 1 baseline
run (`classic_to_pdn`) untouched. Both directories will coexist under `runs/`, allowing
a direct side-by-side comparison of the reports.
```

---

### 3.2 Output Directory Structure

The new run will produce an identical directory structure under `runs/`, tagged with the
new name:

```text
runs/
├── classic_to_pdn/            ← Module 1 baseline (preserved)
│   ├── 12-openroad-staprepnr/
│   └── ...
└── classic_slew_repaired/     ← Module 2 optimized run
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
Pay particular attention to step `12-openroad-staprepnr/` in the new run. This is the
primary report directory for comparing the Max Slew and Max Cap violation counts
against the Module 1 baseline.
```

---

## 4. Analyzing the Results

### 4.1 Timing Summary Comparison

Navigate to the pre-{term}`PnR` {term}`STA` summary in your new run:

```text
runs/classic_slew_repaired/12-openroad-staprepnr/summary.rpt
```

Focus on the **Max Slew Violations** and **Max Cap Violations** columns. Compare them
directly against your Module 1 baseline:

```text
runs/classic_to_pdn/12-openroad-staprepnr/summary.rpt
```

A well-configured repair run should show a measurable reduction in both violation counts.
The table below shows the columns of interest in the summary report:

| Column | What to Look For |
| :--- | :--- |
| **Max Slew Violations** | Should decrease significantly after relaxing `MAX_TRANSITION_CONSTRAINT` to 1.5 ns. |
| **Max Cap Violations** | Should decrease after increasing `DESIGN_REPAIR_MAX_CAP_PCT` to 30%. |
| **Hold WNS / TNS** | May shift slightly as new buffers alter path timing — verify no new Hold violations were introduced. |
| **Setup WNS / TNS** | Should remain at or better than the Module 1 baseline — new buffers must not degrade the critical path. |

```{admonition} Expected Outcome
:class: tip

After applying these three parameters, a typical `aes_wb_wrapper` run on the
`nom_ss_100C_1v60` worst-case corner should show:

- A **significant reduction** in Max Slew and Max Cap violations.
- **No regression** in Setup {term}`WNS` or {term}`TNS`.
- A **marginal increase** in cell count due to additional buffer insertion — this is
  expected and acceptable.
```

---

### 4.2 Task: Comparative Analysis

Complete the table below using data from the `summary.rpt` files in both run directories.
This exercise reinforces the relationship between configuration parameters and physical
design outcomes.

| Metric | Module 1 Baseline (`classic_to_pdn`) | Module 2 Repaired (`classic_slew_repaired`) | Δ Change |
| :--- | :---: | :---: | :---: |
| **Max Slew Violations** | | | |
| **Max Cap Violations** | | | |
| **Hold {term}`WNS` (ns)** | | | |
| **Hold {term}`TNS` (ns)** | | | |
| **Setup {term}`WNS` (ns)** | | | |
| **Setup {term}`TNS` (ns)** | | | |
| **Total Cell Count** | | | |

```{admonition} Discussion Question
:class: note

After filling in the table, consider the following:

1. Did relaxing `MAX_TRANSITION_CONSTRAINT` from 0.75 ns to 1.5 ns reduce Max Slew
   violations without introducing Setup regressions? What does this tell you about the
   original constraint being overly conservative?

2. The cell count likely increased due to additional buffer insertion. Is this trade-off
   — more cells in exchange for fewer electrical violations — acceptable for a design
   destined for Caravel tape-out? Justify your answer using the {term}`PPA` framework.
```

---

*Proceed to **Module 3** once your `classic_slew_repaired` run shows no increase in
Setup {term}`WNS` relative to the Module 1 baseline and a measurable reduction in both
Max Slew and Max Cap violation counts.*

---

```{glossary}
STA
  Static Timing Analysis. A method of verifying circuit timing by exhaustively checking all signal paths against declared constraints, without requiring simulation vectors.

PnR
  Place and Route. The physical design stage in which synthesized cells are assigned spatial positions and interconnected with metal wires.

PPA
  Power, Performance, Area. The three primary optimization axes in VLSI design, representing an inherent engineering trade-off space.

WNS
  Worst Negative Slack. The largest magnitude of negative slack across all failing timing paths — the single most critical timing violation metric.

TNS
  Total Negative Slack. The arithmetic sum of all negative slack values across every failing timing path; a measure of the overall timing health of the design.
```

# Module 2: Placement, CTS & Timing Optimization

```{admonition} Prerequisites
:class: important

Before proceeding, ensure you have completed **Module 1** and that your Classic Flow run
(`classic_to_pdn`) has finished successfully. Your `config.json` and both SDC files
(`pnr.sdc`, `signoff.sdc`) must be in place before applying the changes described in this module.
```

---

## Table of Contents

1. [Placement and I/O Configuration](#placement-and-io-configuration)
   - [1.1 I/O and Pin Placement Parameters](#io-and-pin-placement-parameters)
   - [1.2 Custom Pin Ordering for the AES Wrapper](#custom-pin-ordering-for-the-aes-wrapper)
2. Clock Tree Synthesis *(coming in the next step)*
3. Addressing Slew and Capacitance Violations *(coming in the next step)*

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
    "IO_PIN_ORDER_CFG": "dir::pin_order.cfg"
}
```

```{warning}
The `dir::` prefix is mandatory. It instructs LibreLane to resolve the path **relative
to the design directory** (the folder containing `config.json`), rather than treating
it as an absolute system path. Omitting `dir::` will cause a file-not-found error at
the `OpenROAD.IOPlacement` step.
```

---

```{glossary}
I/O
  Input/Output. Refers to the physical pins on a macro or chip boundary through which signals enter and leave the design.

DRC
  Design Rule Check. A verification step confirming the physical layout conforms to the foundry's manufacturing constraints, including minimum spacing between adjacent pins.

STA
  Static Timing Analysis. A method of verifying circuit timing by exhaustively checking all signal paths against declared constraints without requiring simulation vectors.
```

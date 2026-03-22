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

</div>

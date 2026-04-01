<div align="center">

<img src="https://github.com/user-attachments/assets/84028fb9-2e26-4733-af28-c6e825395912" alt="Silicon Sprint Logo" height="140" />
---

___
[![Typing SVG](https://readme-typing-svg.demolab.com?font=Inter&size=44&duration=3000&pause=600&color=4C6EF5&center=true&vCenter=true&width=1100&lines=Silicon+Sprint+AUC;LibreLane+Flow+Mastery;AES+Accelerator+Integration)](https://git.io/typing-svg)

# AES-Caravel: Open-Source ASIC Implementation Guide
<p align="center">
    <a href="https://opensource.org/licenses/Apache-2.0"><img src="https://img.shields.io/badge/License-Apache%202.0-blue.svg" alt="License: Apache 2.0"/></a>
    <a href="https://www.python.org"><img src="https://img.shields.io/badge/Python-3.8-3776AB.svg?style=flat&logo=python&logoColor=white" alt="Python 3.8.1 or higher" /></a>
    <a href="https://github.com/psf/black"><img src="https://img.shields.io/badge/code%20style-black-000000.svg" alt="Code Style: black"/></a>
    <a href="https://nixos.org/"><img src="https://img.shields.io/static/v1?logo=nixos&logoColor=white&label=&message=Built%20with%20Nix&color=41439a" alt="Built with Nix"/></a>
</p>
<p align="center">
    <a href="https://github.com/chipfoundry/librelane"><img src="https://img.shields.io/badge/Flow-LibreLane%20v3-FF69B4" alt="LibreLane v3"></a>
    <a href="https://librelane.readthedocs.io/"><img src="https://readthedocs.org/projects/librelane/badge/?version=latest" alt="Documentation Build Status Badge"/></a>
    <a href="https://fossi-chat.org"><img src="https://img.shields.io/badge/Community-FOSSi%20Chat-1bb378?logo=element" alt="Invite to FOSSi Chat"/></a>
</p>
</div>

A comprehensive, modular learning path for mastering the open-source ASIC ecosystem and the **LibreLane** physical implementation flow with progressive complexity levels. This project provides a complete educational resource with hands-on modules, technical clinics, and surgical flow control documentation covering all aspects of hardening an **AES Accelerator** and integrating it into the **Caravel SoC** harness for the free OpenMPW shuttle.

---

## Table of Contents
* [Project Description](#project-description)
* [Caravel SoC](#caravel-soc)
* [LibreLane Framework](#librelane-framework)
* [AES Accelerator Architecture](#aes-accelerator-architecture)
* [Wishbone Communication](#wishbone-communication)
* [Design Implementation](#design-implementation)
* [Design Simulation](#design-simulation)

---

## Project Description
In this project, we build upon the [Caravel User Project](https://github.com/chipfoundry/caravel_user_project) to demonstrate how the SoC template can be used to harden a high-performance **AES (Advanced Encryption Standard) Accelerator** and integrate it within the [Caravel](https://github.com/efabless/caravel) chip. 

While the foundational flow is based on the traditional Caravel tutorial, this implementation leverages the **LibreLane** framework to achieve "surgical" control over the physical design process. This allows us to address complex integration challenges ensuring the cryptographic core is fully compliant with the Sky130 design rules for the OpenMPW shuttle.

---

## Caravel
[Caravel](https://github.com/efabless/caravel) is a template SoC designed for Efabless Open MPW and chipIgnite shuttles, based on the **Sky130 (130nm)** process node from SkyWater Technologies. It acts as a standardized "harness" that surrounds the user’s custom logic, providing all necessary infrastructure for a functional chip.

<p align="center">
  <img width="500" alt="Caravel SoC Structure" src="https://user-images.githubusercontent.com/56173018/182022965-96c2875e-91cf-40fc-8c59-cde0ddeaa16e.png">
</p>

As illustrated above, Caravel consists of a fixed harness frame and two pluggable wrappers:
1. **Management Area:** Contains the RISC-V CPU and system peripherals.
2. **User Project Area:** The sandbox where our **AES Accelerator** is implemented.

Our AES core resides within the `user_project_wrapper` and utilizes the following utilities provided by the management SoC:
* **38 GPIO Ports:** For external data signaling.
* **128 Logic Analyzer Probes:** For real-time hardware debugging.
* **Wishbone Bus Connection:** For high-speed register access between the RISC-V CPU and the AES core.

We utilize the **Wishbone Bus** as the primary communication channel to configure the AES keys and transfer data for encryption/decryption. For more details on the signaling, see the [Wishbone Communication](#wishbone-communication) section.

---

## LibreLane
[LibreLane](https://github.com/chipfoundry/librelane) is an automated RTL-to-GDSII flow based on components including OpenROAD, Yosys, Magic, Netgen, CVC, and KLayout. It performs full ASIC implementation from RTL down to GDSII.

Originally started as version 2.0 of OpenLane, LibreLane is a piece of software for ASIC implementation, initially developed by Efabless Corporation, but it is currently maintained under the stewardship of the [FOSSi Foundation](https://fossi-foundation.org). Rather than being a single fixed flow, LibreLane acts as an infrastructure that allows for multiple implementation strategies, including a "Classic" flow for compatibility with earlier OpenLane versions.

<p align="center">
  <img width="686" alt="LibreLane Architecture" src="https://user-images.githubusercontent.com/56173018/182023837-3ec8d154-8c5a-4d47-a80f-3fa4a9959bbd.png">
</p>

When hardening your design using LibreLane, there are three primary options:

* **Macro-First Hardening:** Harden the user macro(s) initially and incorporate them into the wrapper without top-level standard cells. This method significantly reduces PnR and sign-off time.
* **Full-Wrapper Flattening:** Merge the user macro(s) with the `user_project_wrapper` to cover the entire area. This enhances performance but requires more PnR iterations.
* **Top-Level Integration:** Place the user macro(s) within the wrapper alongside top-level standard cells. This is typically chosen to introduce necessary top-level buffering or glue logic.

---



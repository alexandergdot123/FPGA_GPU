# 24-Core, 32-Thread GPU for Spartan-7 FPGA

## Overview

This project is a 24-core, 32-thread GPU designed for the Spartan-7 FPGA (xcs50-csga324-1). It is optimized for integer matrix multiplication and sprite copying to a frame buffer. The GPU employs a SIMD architecture and is designed to maximize the LUT capacity of the FPGA. This project was developed as part of my ECE 385 final project.

## Features

- **Core Architecture:** 24 cores, 32 threads with a SIMD design.
- **Memory System:**
  - 128-bit wide, 32KB cache.
  - 1KB scratchpad memory.
  - DRAM interface connected to 1Gb DDR3 memory.
  - Preloading of DDR3 using a microSDHC card.
- **ALU Operations:**
  - Logical: AND, OR.
  - Arithmetic: Add/Subtract Immediate (sign-extended), Add/Subtract Registers.
  - Bitwise: Bit shifting (1, 2, 4, 8, 16, or 24 bits).
  - Multiplication: Lower 16-bit multiplication of two registers, and multiplication of sign-extended immediate values.
- **VGA/HDMI Output:** 8-bit color output using a realDigital VGA-to-HDMI IP block.
- **Scalability:** While the current design is limited to 24 cores, it can be expanded to 32 cores easily or beyond on larger FPGAs.
- **Instruction Buffer:** Supports AXI-based instruction delivery to GPU cores.

## Limitations

- Non-unified naming conventions in the project.
- VGA output does not use a double-buffering system.
- DDR3 read operations could be further optimized by preloading FIFO.
- Manual assembly coding required for custom programs.

## Repository Structure

### Inside the IP Core (`alexIP`):

- `alexIP.sv`
  - `gpuAxiTop.sv`
    - `instructionBuffer.sv`
    - `sysClock.sv`
    - `gpuLinker.sv`
      - `gpuCore.sv`
      - `globalMemoryCache.sv`
- `gpuTypes.sv` (library file)

### Outside the IP Core:

- `mb_usb_hdmi_top.xdc`
- `mb_usb_hdmi_top.sv`
- `memoryController.sv`
- `rtl_ddr3_top.sv`
  - `ram_reader.sv`
  - `sdcard_init.sv`
    - `SDCard.vhd`
- `mb_block` instantiation
- `videoController.sv`
  - `vga.sv`
  - VGA-to-HDMI instantiation from realDigital

## Setup and Usage

### Prerequisites

- Xilinx Vivado (for synthesis and implementation).
- Vitis (for programming and testing).
- Spartan-7 FPGA (xcs50-csga324-1).
- MicroSDHC card.

### Steps

1. **Vivado Setup:**
   - Download Vivado and create a MicroBlaze design.
   - Attach the GPU IP (`alexIP`) using AXI.
   - Initialize the following BRAMs within the IP:
     - `gpuLinker.sv`: 256-deep, 32-wide, true dual port, no output registers (scratchpad memory).
     - `gpuCore.sv`: 7-deep, 32-wide, true dual port, no output registers (register file).
     - `globalMemoryCache.sv`:
       - Address Tags: 2048-deep, 16-wide, single port, no output registers.
       - Cache Data: 2048-deep, 32-wide, single port, no output registers.
2. **Testing:**
   - Simulate individual cores, DDR3 interface, cache, instruction buffer, system clock, and scratchpad memory.
   - Use Vitis to program the FPGA and run custom test programs.
   - Preload DDR3 using a microSDHC card.
3. **Programming:**
   - Generate the `.xsa` file in Vivado.
   - Use Vitis to load and test custom assembly programs.

## Verification and Testing

Verification was conducted through simulation of individual components and end-to-end system tests. Custom programs were written to validate matrix multiplication and sprite copying/moving. Simulations ensured the proper functionality of the following:

- GPU cores
- DDR3 interface
- Cache system
- Instruction buffer
- System clock
- Scratchpad memory

## Acknowledgments

- **realDigital IP Block:** Used for VGA-to-HDMI signals.
- **Third-party Files:**
  - `sdcard_init.sv`
  - `vga.sv`
  - `rtl_ddr3_top.sv` (modified by me).

## Contact

If you have questions or need assistance, feel free to reach out:

- Email: [alexanderg.123@outlook.com](mailto\:alexanderg.123@outlook.com)

---

*Note: This project is intended as an academic submission for ECE 385 and does not include an open-source license.*



Note: This project is intended as an academic submission for ECE 385 and does not include an open-source license.

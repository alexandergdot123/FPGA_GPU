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

## Instruction Set

### Arithmetic and Logical Instructions

- **Add/Subtract:**
  - **Opcode:** 0000
  - **Bits:**
    - 28-31: Opcode
    - 25-27: Destination Register
    - 22-24: Source Register 1
    - 21: 1 if Immediate, 0 if Source Register 2
    - 20: 1 for Subtract, 0 for Add
      - **Non-Immediate:**
        - 17-19: Source Register 2
      - **Immediate:**
        - 0-15: Sign-extended immediate value

- **AND/OR:**
  - **Opcode:** 0001
  - **Bits:**
    - 28-31: Opcode
    - 25-27: Destination Register
    - 22-24: Source Register 1
    - 21: AND if 0, OR if 1
    - 20: Immediate if 1, Dual-Source if 0
      - **Dual-Source:**
        - 17-19: Source Register 2
      - **Immediate:**
        - 19: Sign-extend with zeros (0) or ones (1)
        - 0-15: Immediate value

- **Multiply:**
  - **Opcode:** 0010
  - **Bits:**
    - 28-31: Opcode
    - 25-27: Destination Register
    - 22-24: Source Register 1
    - 21: Immediate if 1, Dual-Source if 0
      - **Dual-Source:**
        - 17-19: Source Register 2
      - **Immediate:**
        - 0-15: Sign-extended immediate value

- **Bit-Shifting:**
  - **Opcode:** 0011
  - **Bits:**
    - 28-31: Opcode
    - 25-27: Destination Register
    - 22-24: Source Register 1
    - 21: 0 for right shift, 1 for left shift
    - 18-20: Shift amount (1, 2, 4, 8, 16, or 24 bits)

### Compare Instructions

- **Compare (Immediate):**
  - **Opcode:** 0100
  - **Bits:**
    - 28-31: Opcode
    - 27: Proceed if Positive
    - 26: Proceed if Zero
    - 25: Proceed if Negative
    - 19-24: Lines to skip
    - 16-18: Source Register
    - 0-15: Sign-extended immediate value

- **Compare (Dual Source):**
  - **Opcode:** 0101
  - **Bits:**
    - 28-31: Opcode
    - 27: Proceed if Positive
    - 26: Proceed if Zero
    - 25: Proceed if Negative
    - 19-24: Lines to skip
    - 16-18: Source Register 1
    - 13-15: Source Register 2

### Memory Instructions

- **Load Shared Memory:**
  - **Opcode:** 1000 (Immediate + Register), 1001 (Register + Register)
  - **Bits:**
    - 28-31: Opcode
    - 25-27: Destination Register
    - 22-24: Source Register 1
    - Immediate (0-21) or Source Register 2 (19-21)

- **Load Global Memory:**
  - **Opcode:** 1010 (Immediate + Register), 1011 (Register + Register)
  - **Bits:**
    - 28-31: Opcode
    - 25-27: Destination Register
    - 22-24: Source Register 1
    - Immediate (0-21) or Source Register 2 (19-21)

- **Store Shared Memory:**
  - **Opcode:** 1100 (Immediate + Register), 1101 (Register + Register)
  - **Bits:**
    - 28-31: Opcode
    - 25-27: Register to write from
    - 22-24: Source Register 1
    - Immediate (0-17) or Source Register 2 (19-21)

- **Store Global Memory:**
  - **Opcode:** 1110 (Immediate + Register), 1111 (Register + Register)
  - **Bits:**
    - 28-31: Opcode
    - 25-27: Register to write from
    - 22-24: Source Register 1
    - Immediate (0-17) or Source Register 2 (19-21)
    - 18-21: Byte enable bits

### Reserved Opcodes

- Opcodes 0110 and 0111 are reserved for future use.

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

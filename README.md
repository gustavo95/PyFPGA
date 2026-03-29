# Python Bytecode Execution on FPGA (Proof of Concept)

This repository presents a proof of concept (PoC) for executing Python bytecode directly on FPGA hardware using a custom virtual machine implemented in Verilog.

The goal of this project is to explore an alternative execution model for Python programs, where bytecode is interpreted by a hardware-based stack machine instead of a traditional software interpreter.

---

## Overview

This project implements a simplified Python Virtual Machine (VM) architecture in hardware, capable of executing a subset of CPython bytecode instructions.

The system follows a stack-based execution model and is designed to run on FPGA platforms, demonstrating the feasibility of mapping high-level language execution into hardware.

Key features:

- Execution of Python bytecode (CPython-compatible subset)
- Stack-based virtual machine architecture
- Custom instruction fetch–decode–execute pipeline
- Hardware implementation using Verilog HDL
- Communication interface with host (Python + UART)
- Step-by-step execution mode for debugging

---

## Architecture

The hardware VM is organized as a finite state machine (FSM) implementing the classic execution cycle:

1. **Fetch** – Retrieve instruction from instruction memory
2. **Decode** – Identify opcode and operands
3. **Execute** – Perform operation on stack and internal structures

### Main components:

- **Instruction Memory (FIFO)**  
  Stores incoming bytecode instructions from the host

- **Data Stack**  
  Stack-based operand storage used during execution

- **Name/Variable Storage**  
  Register-based structure for variable storage

- **Execution Engine (FSM)**  
  Controls instruction lifecycle and execution flow

- **Host Interface (UART)**  
  Enables communication between PC and FPGA

---

## Supported Instructions (Subset)

The current implementation supports a subset of CPython bytecode instructions, including:

- `LOAD_CONST`
- `LOAD_NAME`
- `STORE_NAME`
- `BINARY_OP`
- `CALL`
- `POP_TOP`
- `PUSH_NULL`
- `RESUME`
- `PRECALL`

This subset is sufficient to execute simple Python programs involving arithmetic operations and function calls.

---

## Example Execution Flow

A typical execution sequence:

```python
a = 2 + 3
print(a)

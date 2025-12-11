# 8-Bit-CPU-Design

Generic 8-bit CPU implemented in Logisim.
The machine has 3 different instruction formats, and the ALU can perform 4 functions.

## Instruction Formats

| A-type | Opcode |  ds  |   s   | extra  |
| ------ | ------ | ---- | ----- | ------ |
| &nbsp; | 7-4   |  3  |   2  | 1-0   |

| B-type | Opcode |  ds  |   Immediate   |
| ------ | ------ | ---- |  ------------ |
| &nbsp; | 7-4    |  3   |     2-0       |

| C-type | Opcode |  Offset   |
| ------ | ------ | --------- |
| &nbsp; | 7-4    |   3-0     |

## ALU Functions

| Operation | ALU0 | ALU1 |
| --------- | ---- | ---- |
| Add       |   1  |   1  |
| Sub       |   1  |   0  |
| Mult      |   0  |   1  |
| Nand      |   0  |   0  |




## Instruction Definitions
| Instruction Format | Opcode | Operation |
|--------------------|--------|-----------|
| nand               | 0000   | rds=~(rds & rs) |
| add                | 0001   | rds=rds+rs |
| addm               | 0010   | rds=rds+mem[rs] |
| addi               | 0011   | rds=rds+imm |
| sub                | 0100   | rds=rds-rs |
| jmp                | 1111   | PC=PC+offset (offset is sign extended) |

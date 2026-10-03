// ============================================================================
// MODULE: Memory (Single-Port RAM)
// ============================================================================
module memory_module (
    input  logic       clk,
    input  logic [7:0] addr,          // Memory address
    input  logic       write_en,      // Write enable
    input  logic [7:0] data_in,       // Data to write
    output logic [7:0] data_out       // Data read
);
    // Memory storage - exposed for testbench initialization
    logic [7:0] mem [0:255];

    // Initialize memory to 0
    initial begin
        for (int i=0; i<256; i++) mem[i] = 0;
    end

    // Asynchronous read
    assign data_out = mem[addr];

    // Synchronous write
    always @(posedge clk) begin
        #5;
        if (write_en) begin
            mem[addr] <= data_in;
        end
    end
endmodule

// ============================================================================
// MODULE: ALU
// ============================================================================
module alu (
    input  logic [7:0] a,
    input  logic [7:0] b,
    input  logic [1:0] func, // 00: NAND, 01: MULT, 10: SUB, 11: ADD
    output logic [7:0] result,
    output logic       zero // Indicates if result is zero
);
    always_comb begin
        case (func)
            2'b00: result =  ~(a & b);
            2'b01: result = a * b;
            2'b10: result = a - b;
            2'b11: result = a + b;
        endcase
        zero = (result == 0) ? 1 : 0;
    end
    
endmodule


// ============================================================================
// MODULE: Control Unit
// ============================================================================
module control_unit (
    input  logic       clk,
    input  logic       reset,
    input  logic [3:0] opcode,
    input  logic       alu_zero,  // From ALU, for BEQ
    
    // Status
    output logic       halted,
    output logic [7:0] state,
    output logic [1:0] alu_func,

    // Control Signals
    output logic pc_out_b1,
    output logic pc_in,

    output logic ir_out_b1,
    output logic ir_out_b2,
    output logic ir_in_b1,
    
    output logic rds_out_b1,
    output logic rds_out_b2,
    output logic rs_out_b1,
    output logic rs_out_b2,
    output logic rds_in_b1,
    output logic rds_in_b3,
    
    output logic mar_in_b1,
    output logic mdr_out_b1,
    
    output logic offset_enable,
    output logic imm_enable,
    output logic mem_write

);
    logic [7:0] next_state = 0;
    assign pc_out_b1 = ((state == 0) || (state == 7)) ? 1:0;
    assign pc_in = ((state == 0) || (state == 7)) ? 1:0;
    assign ir_out_b1 = 0;
    assign ir_out_b2 = ((state == 7) || (state == 8)) ? 1:0;
    assign ir_in_b1 = (state == 1) ? 1:0;
    assign rds_out_b1 = ((state == 2) || (state == 8) || (state == 10)) ? 1:0;
    assign rds_out_b2 = (state == 4) ? 1:0;
    assign rs_out_b1 = ((state == 3) || (state == 6)) ? 1:0;
    assign rs_out_b2 = ((state == 2) || (state == 10)) ? 1:0;
    assign rds_in_b1 = (state == 5) ? 1:0;
    assign rds_in_b3 = ((state == 2) || (state == 4) || (state == 8)) ? 1:0;
    assign mar_in_b1 = ((state == 0) || (state == 3) || (state == 6)) ? 1:0;
    assign mdr_out_b1 = ((state == 1) || (state == 4) || (state == 5)) ? 1:0;
    assign offset_enable = ((state == 7)) ? 1:0;
    assign imm_enable= ((state == 8)) ? 1:0;
    assign mem_write = ((state == 6)) ? 1:0;
    assign halted = ((state == 9)) ? 1:0;


    always_comb begin

        if (state == 0) begin
            next_state = 1;
        end
        else if (state == 1) begin
            case (opcode)
                4'b0000: next_state = 2; // nand
                4'b0001: next_state = 2; // add
                4'b0010: next_state = 3; // addm
                4'b0011: next_state = 8; // addi
                4'b0100: next_state = 2; // sub
                4'b0101: next_state = 2; // mult
                4'b0110: next_state = 3; // lw
                4'b0111: next_state = 6; // sw
                4'b1000: next_state = 10; // beq
                4'b1001: next_state = 7; // jmp
                4'b1111: next_state = 9; // halt
            endcase
        end else if (state == 3) begin
            case (opcode)
                4'b0010: next_state = 4;
                4'b0110: next_state = 5;
            endcase
        end else if (state == 10) begin
            next_state = (alu_zero)? 7 : 0;
        end else if (state == 9) begin
            next_state = 9;
        end
        else begin
            next_state = 0;
        end

        case (state)
        
            2: begin
                case (opcode)
                    4'b0000: alu_func = 2'b00; // nand
                    4'b0001: alu_func = 2'b11; // add
                    4'b0100: alu_func = 2'b10; // sub
                    4'b0101: alu_func = 2'b01; // mult
                endcase
            end
            4: alu_func = 2'b11;
            7: alu_func = 2'b11;
            8: alu_func = 2'b11;
            10: alu_func = 2'b10;
            default: alu_func = 2'b00;
        endcase
    end

    always @(posedge clk) begin
        #5;
        if (reset) begin
            state <= 0;
        end else begin
            state <= next_state;
        end
    end

endmodule


// ============================================================================
// MODULE: CPU (Datapath Top Level)
// ============================================================================
module cpu (
    input logic clk,
    input logic reset
);

    // -- Storage --
    // Registers kept here so the testbench can access 'dut.registers'
    logic [7:0] registers [0:1];
    logic [7:0] reg_r1;
    logic [7:0] reg_r2;
    logic [7:0] wb_data;

    // -- Architectural Registers --
    logic [7:0] PC = 8'b00000000;
    logic [7:0] IR;
    logic [7:0] MAR;
    logic [7:0] MDR;

    logic [7:0] mem_data_out;
    // -- Bus --
    wire [7:0] bus1;
    wire [7:0] bus2;
    wire [7:0] bus_out;
    wire [7:0] alu_b;
    
    wire [7:0] pc_next;
    logic [7:0] state;

    // -- Control Signals -- 
    logic [1:0] alu_func;
    logic alu_zero;
    logic halted;
    // pc controls
    wire pc_out_b1;
    wire pc_in;
    // ir
    wire ir_out_b1;
    wire ir_out_b2;
    wire ir_in_b1;
    
    // reg write and reg out
    
    wire rds_out_b1;
    wire rds_out_b2;
    wire rs_out_b1;
    wire rs_out_b2;

    wire rds_in_b1;
    wire rds_in_b3;

    // memory
    wire mar_in_b1;
    wire mdr_out_b1;

    // alu b input
    wire offset_enable;
    wire imm_enable;
    wire mem_write;

    // ------------------------------------------------------------------------
    // Instruction Decoding
    // ------------------------------------------------------------------------
    
    logic [3:0] opcode;
    logic ds_idx;
    logic s_idx;
    
    logic [2:0] imm;
    logic [7:0] imm_ext;

    logic signed [3:0] offset;
    logic signed [7:0] signed_offset;
      
    
    assign opcode = IR[7:4];
    assign ds_idx = IR[3];
    assign s_idx  = IR[2];
    assign imm = IR[2:0];
    assign offset = IR[3:0];

    // immediates not sign extended
    assign imm_ext = imm;

    // offset sign extended
    assign signed_offset = {{4{offset[3]}}, offset};

    // ------------------------------------------------------------------------
    // Memory Module Instantiation & Address Multiplexing
    // ------------------------------------------------------------------------

    // Memory module instantiation
    memory_module mem_inst (
        .clk(clk),
        .addr(MAR),
        .write_en(mem_write),
        .data_in(reg_r1),       // Data to write (from rds register)
        .data_out(MDR) // Data read from memory
    );

    // ------------------------------------------------------------------------
    // Register File Access
    // ------------------------------------------------------------------------
    assign reg_r1 = registers[ds_idx]; // Rds
    assign reg_r2 = registers[s_idx];  // Rs


    // ------------------------------------------------------------------------
    // ALU & Datapath Muxes
    // ------------------------------------------------------------------------
    

    alu cpu_alu (
        .a(bus1),
        .b(alu_b),
        .func(alu_func),
        .result(bus_out),
        .zero(alu_zero)
    );

    // ------------------------------------------------------------------------
    // Control Unit Instance
    // ------------------------------------------------------------------------
    control_unit cu (
        .clk(clk),
        .reset(reset),
        .opcode(opcode),
        .alu_zero(alu_zero),
        .halted(halted),
    
        .state(state),
        .alu_func(alu_func),
        .pc_out_b1(pc_out_b1),
        .pc_in(pc_in),
        .ir_out_b1(ir_out_b1),
        .ir_out_b2(ir_out_b2),
        .ir_in_b1(ir_in_b1),

        .rds_out_b1(rds_out_b1),
        .rds_out_b2(rds_out_b2),
        .rs_out_b1(rs_out_b1),
        .rs_out_b2(rs_out_b2),
        .rds_in_b1(rds_in_b1),
        .rds_in_b3(rds_in_b3),
    
        .mar_in_b1(mar_in_b1),
        .mdr_out_b1(mdr_out_b1),
    
        .offset_enable(offset_enable),
        .imm_enable(imm_enable),
        .mem_write(mem_write)
    );
    
    assign bus1 = (pc_out_b1) ? PC:8'bzzzzzzzz;
    assign bus1 = (ir_out_b1) ? IR:8'bzzzzzzzz;
    assign bus1 = (rds_out_b1) ? reg_r1:8'bzzzzzzzz;
    assign bus1 = (rs_out_b1) ? reg_r2:8'bzzzzzzzz;
    assign bus1 = (mdr_out_b1) ? MDR:8'bzzzzzzzz;

    assign bus2 = (ir_out_b2) ? IR:8'bzzzzzzzz;
    assign bus2 = (rds_out_b2) ? reg_r1:8'bzzzzzzzz;
    assign bus2 = (rs_out_b2) ? reg_r2:8'bzzzzzzzz;
    
    assign pc_next = (state == 7) ? bus_out : PC+1;
    assign alu_b = (imm_enable) ? imm_ext : 8'bzzzzzzzz;
    assign alu_b = (offset_enable) ? signed_offset : 8'bzzzzzzzz;
    assign alu_b = (!imm_enable && !offset_enable) ? bus2: 8'bzzzzzzzz;


    always_ff @(posedge clk) begin
        if (pc_in)
            PC <= pc_next;
        if (ir_in_b1)
            IR <= bus1;
        if (mar_in_b1)
            MAR <= bus1;

        if (rds_in_b1)
            registers[ds_idx] <= bus1;
        else if (rds_in_b3)
            registers[ds_idx] <= bus_out;
        
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            registers[0] <= 8'b0;
            registers[1] <= 8'b0;
        end
    end

endmodule
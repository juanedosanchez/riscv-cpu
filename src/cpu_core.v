// Single-cycle RV32I datapath: decode, register file, ALU, branch/jump
// target selection, and load/store alignment. Memories live outside.
module cpu_core (
    input wire         clk,
    input wire         reset,
    input wire [31:0]  pc,
    input wire [31:0]  instruction,
    output wire [31:0] next_pc,

    // Data bus (word-aligned access + byte strobes)
    output wire [31:0] mem_address,
    output wire [31:0] mem_write_data,
    output wire [3:0]  mem_write_strobe,
    input wire  [31:0] mem_read_data,

    output wire [31:0] debug_x3
);

    wire [4:0] rs1;
    wire [4:0] rs2;
    wire [4:0] rd;
    wire [2:0] funct3;

    wire [3:0] alu_operation;
    wire [1:0] alu_src_a;
    wire       use_immediate;
    wire       write_enable;
    wire [1:0] wb_select;
    wire       mem_read;
    wire       mem_write;
    wire       branch;
    wire       jal;
    wire       jalr;

    wire [31:0] data1;
    wire [31:0] data2;

    wire [31:0] immediate;
    wire [31:0] alu_a;
    wire [31:0] alu_b;
    wire [31:0] alu_result;

    reg  [31:0] load_data;
    reg  [31:0] write_back;

    decoder decoder_unit (
        .instruction(instruction),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .funct3(funct3),
        .alu_operation(alu_operation),
        .alu_src_a(alu_src_a),
        .use_immediate(use_immediate),
        .write_enable(write_enable),
        .wb_select(wb_select),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .branch(branch),
        .jal(jal),
        .jalr(jalr)
    );

    imm_gen immediate_generator (
        .instruction(instruction),
        .immediate(immediate)
    );

    regfile register_file (
        .clk(clk),
        .reset(reset),
        .rs1(rs1),
        .rs2(rs2),
        .data1(data1),
        .data2(data2),
        .rd(rd),
        .write_data(write_back),
        .write_enable(write_enable),
        .debug_x3(debug_x3)
    );

    assign alu_a = (alu_src_a == 2'b01) ? pc :
                   (alu_src_a == 2'b10) ? 32'd0 :
                                          data1;

    assign alu_b = use_immediate ? immediate : data2;

    alu alu_unit (
        .a(alu_a),
        .b(alu_b),
        .operation(alu_operation),
        .result(alu_result)
    );

    // Branch condition
    reg branch_taken;

    always @(*) begin
        case (funct3)
            3'b000:  branch_taken = (data1 == data2);                    // BEQ
            3'b001:  branch_taken = (data1 != data2);                    // BNE
            3'b100:  branch_taken = ($signed(data1) <  $signed(data2));  // BLT
            3'b101:  branch_taken = ($signed(data1) >= $signed(data2));  // BGE
            3'b110:  branch_taken = (data1 <  data2);                    // BLTU
            3'b111:  branch_taken = (data1 >= data2);                    // BGEU
            default: branch_taken = 1'b0;
        endcase
    end

    // Next PC
    wire [31:0] pc_plus_4 = pc + 32'd4;
    wire [31:0] pc_target = pc + immediate;

    assign next_pc = jalr                      ? {alu_result[31:1], 1'b0} :
                     (jal || (branch && branch_taken)) ? pc_target :
                                                 pc_plus_4;

    // Stores: replicate the data across lanes, enable only the target bytes
    wire [1:0] byte_offset = alu_result[1:0];

    assign mem_address = alu_result;

    assign mem_write_data = (funct3[1:0] == 2'b00) ? {4{data2[7:0]}}  :  // SB
                            (funct3[1:0] == 2'b01) ? {2{data2[15:0]}} :  // SH
                                                     data2;              // SW

    assign mem_write_strobe = !mem_write              ? 4'b0000 :
                              (funct3[1:0] == 2'b00)  ? (4'b0001 << byte_offset) :
                              (funct3[1:0] == 2'b01)  ? (4'b0011 << {byte_offset[1], 1'b0}) :
                                                        4'b1111;

    // Loads: pick the addressed byte/halfword and extend it
    wire [31:0] shifted = mem_read_data >> {byte_offset, 3'b000};

    always @(*) begin
        case (funct3)
            3'b000:  load_data = {{24{shifted[7]}},  shifted[7:0]};   // LB
            3'b001:  load_data = {{16{shifted[15]}}, shifted[15:0]};  // LH
            3'b100:  load_data = {24'd0, shifted[7:0]};               // LBU
            3'b101:  load_data = {16'd0, shifted[15:0]};              // LHU
            default: load_data = mem_read_data;                       // LW
        endcase
    end

    always @(*) begin
        case (wb_select)
            2'b01:   write_back = load_data;
            2'b10:   write_back = pc_plus_4;
            default: write_back = alu_result;
        endcase
    end

endmodule

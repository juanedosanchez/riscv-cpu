module decoder (
    input wire [31:0] instruction,

    output wire [4:0] rs1,
    output wire [4:0] rs2,
    output wire [4:0] rd,
    output wire [2:0] funct3,

    output reg [3:0] alu_operation,
    output reg [1:0] alu_src_a,      // 00 rs1, 01 pc, 10 zero
    output reg       use_immediate,  // ALU B input: 0 rs2, 1 immediate
    output reg       write_enable,
    output reg [1:0] wb_select,      // 00 ALU, 01 memory, 10 pc + 4
    output reg       mem_read,
    output reg       mem_write,
    output reg       branch,
    output reg       jal,
    output reg       jalr
);

    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_AND  = 4'b0010;
    localparam ALU_OR   = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SLL  = 4'b0101;
    localparam ALU_SRL  = 4'b0110;
    localparam ALU_SRA  = 4'b0111;
    localparam ALU_SLT  = 4'b1000;
    localparam ALU_SLTU = 4'b1001;

    localparam SRC_A_RS1  = 2'b00;
    localparam SRC_A_PC   = 2'b01;
    localparam SRC_A_ZERO = 2'b10;

    localparam WB_ALU = 2'b00;
    localparam WB_MEM = 2'b01;
    localparam WB_PC4 = 2'b10;

    wire [6:0] opcode;
    wire [6:0] funct7;

    assign opcode = instruction[6:0];
    assign rd     = instruction[11:7];
    assign funct3 = instruction[14:12];
    assign rs1    = instruction[19:15];
    assign rs2    = instruction[24:20];
    assign funct7 = instruction[31:25];

    always @(*) begin

        // Default: no-op. Anything not decoded below has no side effects.
        alu_operation = ALU_ADD;
        alu_src_a     = SRC_A_RS1;
        use_immediate = 1'b0;
        write_enable  = 1'b0;
        wb_select     = WB_ALU;
        mem_read      = 1'b0;
        mem_write     = 1'b0;
        branch        = 1'b0;
        jal           = 1'b0;
        jalr          = 1'b0;

        case (opcode)

            // R-type
            7'b0110011: begin
                write_enable = 1'b1;

                case ({funct7, funct3})
                    {7'b0000000, 3'b000}: alu_operation = ALU_ADD;
                    {7'b0100000, 3'b000}: alu_operation = ALU_SUB;
                    {7'b0000000, 3'b001}: alu_operation = ALU_SLL;
                    {7'b0000000, 3'b010}: alu_operation = ALU_SLT;
                    {7'b0000000, 3'b011}: alu_operation = ALU_SLTU;
                    {7'b0000000, 3'b100}: alu_operation = ALU_XOR;
                    {7'b0000000, 3'b101}: alu_operation = ALU_SRL;
                    {7'b0100000, 3'b101}: alu_operation = ALU_SRA;
                    {7'b0000000, 3'b110}: alu_operation = ALU_OR;
                    {7'b0000000, 3'b111}: alu_operation = ALU_AND;
                    default:              write_enable  = 1'b0; // e.g. M extension
                endcase
            end

            // I-type arithmetic
            7'b0010011: begin
                write_enable  = 1'b1;
                use_immediate = 1'b1;

                case (funct3)
                    3'b000: alu_operation = ALU_ADD;   // ADDI
                    3'b010: alu_operation = ALU_SLT;   // SLTI
                    3'b011: alu_operation = ALU_SLTU;  // SLTIU
                    3'b100: alu_operation = ALU_XOR;   // XORI
                    3'b110: alu_operation = ALU_OR;    // ORI
                    3'b111: alu_operation = ALU_AND;   // ANDI

                    3'b001: begin                      // SLLI
                        alu_operation = ALU_SLL;
                        if (funct7 != 7'b0000000)
                            write_enable = 1'b0;
                    end

                    3'b101: begin                      // SRLI / SRAI
                        if (funct7 == 7'b0000000)
                            alu_operation = ALU_SRL;
                        else if (funct7 == 7'b0100000)
                            alu_operation = ALU_SRA;
                        else
                            write_enable = 1'b0;
                    end
                endcase
            end

            // Loads: LB, LH, LW, LBU, LHU
            7'b0000011: begin
                if (funct3 == 3'b000 || funct3 == 3'b001 || funct3 == 3'b010 ||
                    funct3 == 3'b100 || funct3 == 3'b101) begin
                    write_enable  = 1'b1;
                    use_immediate = 1'b1;
                    wb_select     = WB_MEM;
                    mem_read      = 1'b1;
                end
            end

            // Stores: SB, SH, SW
            7'b0100011: begin
                if (funct3 == 3'b000 || funct3 == 3'b001 || funct3 == 3'b010) begin
                    use_immediate = 1'b1;
                    mem_write     = 1'b1;
                end
            end

            // Branches: BEQ, BNE, BLT, BGE, BLTU, BGEU
            7'b1100011: begin
                if (funct3 != 3'b010 && funct3 != 3'b011)
                    branch = 1'b1;
            end

            // JAL
            7'b1101111: begin
                write_enable = 1'b1;
                wb_select    = WB_PC4;
                jal          = 1'b1;
            end

            // JALR
            7'b1100111: begin
                if (funct3 == 3'b000) begin
                    write_enable  = 1'b1;
                    use_immediate = 1'b1;
                    wb_select     = WB_PC4;
                    jalr          = 1'b1;
                end
            end

            // LUI
            7'b0110111: begin
                write_enable  = 1'b1;
                alu_src_a     = SRC_A_ZERO;
                use_immediate = 1'b1;
            end

            // AUIPC
            7'b0010111: begin
                write_enable  = 1'b1;
                alu_src_a     = SRC_A_PC;
                use_immediate = 1'b1;
            end

            // FENCE, ECALL/EBREAK/CSR and unknown opcodes: no-op
            default: begin
            end

        endcase
    end

endmodule

module decoder (
    input wire [31:0] instruction,

    output wire [4:0] rs1,
    output wire [4:0] rs2,
    output wire [4:0] rd,

    output reg [2:0] alu_operation,
    output reg write_enable,
    output reg use_immediate
);

    wire [6:0] opcode;
    wire [2:0] funct3;
    wire [6:0] funct7;

    assign opcode = instruction[6:0];
    assign rd     = instruction[11:7];
    assign funct3 = instruction[14:12];
    assign rs1    = instruction[19:15];
    assign rs2    = instruction[24:20];
    assign funct7 = instruction[31:25];

    always @(*) begin

        alu_operation = 3'b000;
        write_enable  = 1'b0;
        use_immediate = 1'b0;

        case (opcode)

            // R-type
            7'b0110011: begin

                write_enable = 1'b1;

                case (funct3)

                    3'b000: begin
                        if (funct7 == 7'b0000000)
                            alu_operation = 3'b000; // ADD
                        else if (funct7 == 7'b0100000)
                            alu_operation = 3'b001; // SUB
                    end

                    3'b111:
                        alu_operation = 3'b010; // AND

                    3'b110:
                        alu_operation = 3'b011; // OR

                    default:
                        alu_operation = 3'b000;

                endcase
            end

            // ADDI
            7'b0010011: begin
                write_enable  = 1'b1;
                use_immediate = 1'b1;
                alu_operation = 3'b000;
            end

            default: begin
                write_enable  = 1'b0;
            end

        endcase
    end

endmodule
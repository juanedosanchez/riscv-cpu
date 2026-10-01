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

            // R-type: only ADD, SUB, AND, OR are supported.
            // Anything else (unsupported funct3 or funct7) does not write back.
            7'b0110011: begin

                case (funct3)

                    3'b000: begin
                        if (funct7 == 7'b0000000) begin
                            alu_operation = 3'b000; // ADD
                            write_enable  = 1'b1;
                        end
                        else if (funct7 == 7'b0100000) begin
                            alu_operation = 3'b001; // SUB
                            write_enable  = 1'b1;
                        end
                    end

                    3'b111: begin
                        if (funct7 == 7'b0000000) begin
                            alu_operation = 3'b010; // AND
                            write_enable  = 1'b1;
                        end
                    end

                    3'b110: begin
                        if (funct7 == 7'b0000000) begin
                            alu_operation = 3'b011; // OR
                            write_enable  = 1'b1;
                        end
                    end

                    default:
                        write_enable = 1'b0;

                endcase
            end

            // I-type arithmetic: only ADDI, ANDI, ORI are supported.
            // Other funct3 values (SLTI, XORI, shifts, ...) do not write back.
            7'b0010011: begin

                use_immediate = 1'b1;

                case (funct3)

                    3'b000: begin
                        alu_operation = 3'b000; // ADDI
                        write_enable  = 1'b1;
                    end

                    3'b111: begin
                        alu_operation = 3'b010; // ANDI
                        write_enable  = 1'b1;
                    end

                    3'b110: begin
                        alu_operation = 3'b011; // ORI
                        write_enable  = 1'b1;
                    end

                    default:
                        write_enable = 1'b0;

                endcase
            end

            default: begin
                write_enable  = 1'b0;
            end

        endcase
    end

endmodule
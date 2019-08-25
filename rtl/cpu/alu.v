`include "cpu/aludefs.vh"

module alu(
	input I_clk,
	input I_en,
	input I_reset,
	input[31:0] I_dataS1,
	input[31:0] I_dataS2,
	input [4:0] I_aluop,
	output O_busy,
	output[31:0] O_data,
	output reg O_lt,
	output reg O_ltu,
	output reg O_eq);
   
   /*verilator public_module*/ 
	
	reg[31:0] result, sum, myor, myxor, myand;
	reg[32:0] sub; // additional bit for underflow detection
	reg eq, lt, ltu, busy = 0;
	reg[4:0] shiftcnt;

	assign O_data = result;

    // mul
    reg[63:0] muluu;
    reg[63:0] mulss;
    reg[63:0] mulsu;

    reg[63:0] tmp_src1;
    reg[63:0] tmp_src2;
    reg[63:0] tmp_src2u;

    // div
    reg[31:0] div;
    reg[31:0] divu;
    wire signed[31:0] src1_signed;
    wire signed[31:0] src2_signed;
    assign src1_signed = I_dataS1;
    assign src2_signed = I_dataS2;
    reg[31:0] rem;
    reg[31:0] remu;
   
//`define SINGLE_CYCLE_SHIFTER
`ifdef SINGLE_CYCLE_SHIFTER
	wire[31:0] sll, srl, sra;
	wire signed[31:0] I_dataS1_signed;
	assign I_dataS1_signed[31:0] = I_dataS1[31:0];
	assign sll = (I_dataS1 << I_dataS2[4:0]);
	assign srl = (I_dataS1 >> I_dataS2[4:0]);
	assign sra = (I_dataS1_signed >>> I_dataS2[4:0]);
	assign O_busy = 0;
`else
	assign O_busy = busy;
`endif

	always @(*) begin
		sum = I_dataS1 + I_dataS2;
		sub = {1'b0, I_dataS1} - {1'b0, I_dataS2};
		
		myor = I_dataS1 | I_dataS2;
		myxor = I_dataS1 ^ I_dataS2;
		myand = I_dataS1 & I_dataS2;
    end

    always @(*) begin
        // FIXME
        tmp_src1 = { {32{I_dataS1[31]}}, I_dataS1[31:0]};
        tmp_src2 = { {32{I_dataS2[31]}}, I_dataS2[31:0]};
        tmp_src2u = { {32{1'b0}}, I_dataS2[31:0]};

        mulss = tmp_src1 * tmp_src2;
        muluu = I_dataS1 * I_dataS2;
        mulsu = tmp_src1 * tmp_src2u;
    end

    always @(*) begin
        // FIXME
        // TODO: add overflow semantics on MAX_NEG / -1
        if(I_dataS2[31:0] == { 32{1'b0} } ) begin
            div = {32{1'b1}};
            divu = {32{1'b1}};

            rem = I_dataS1;
            remu = I_dataS1;
        end else begin
            div = src1_signed / src2_signed;
            divu = I_dataS1 / I_dataS2;

            rem = src1_signed % src2_signed;
            remu = I_dataS1 % I_dataS2;
        end
    end
	
	always @(*) begin
		// unsigned comparison: simply look at underflow bit
		ltu = sub[32];
		// signed comparison: xor underflow bit with xored sign bit
		lt = (sub[32] ^ myxor[31]);
		
		eq = (sub === 33'b0);
	end
	
	always @(posedge I_clk) begin
		if(I_reset) begin
			busy <= 0;
		end else if(I_en) begin
			case(I_aluop)
				default: result <= sum; // ALUOP_ADD
				`ALUOP_SUB: result <= sub[31:0];		
				`ALUOP_AND: result <= myand;
				`ALUOP_OR:  result <= myor;
				`ALUOP_XOR: result <= myxor;

				`ALUOP_SLT: begin
					result <= 0;
					if(lt) result[0] <= 1;
				end

				`ALUOP_SLTU: begin
					result <= 0;
					if(ltu) result[0] <= 1;
				end

				`ifndef SINGLE_CYCLE_SHIFTER
				// multi-cycle shifting, slow, but compact
				`ALUOP_SLL, `ALUOP_SRL, `ALUOP_SRA: begin
					if(!busy) begin
						busy <= 1;
						result <= I_dataS1;
						shiftcnt <= I_dataS2[4:0];
					end else if(shiftcnt !== 5'b00000) begin
						case(I_aluop)
							`ALUOP_SLL: result <= {result[30:0], 1'b0};
							`ALUOP_SRL: result <= {1'b0, result[31:1]};
							default: result <= {result[31], result[31:1]};
						endcase
						shiftcnt <= shiftcnt - 5'd1;
					end else begin
						busy <= 0;
					end
				end
				`else
				// single-cycle shifting
				`ALUOP_SLL: result <= sll;
				`ALUOP_SRA: result <= sra;
				`ALUOP_SRL: result <= srl;
				`endif
                // FIXME
                // single-cycle multiplication :)
                `ALUOP_MUL: result <= mulss[31:0];
                `ALUOP_MULH: result <= mulss[63:32];
                `ALUOP_MULHSU: result <= mulsu[63:32];
                `ALUOP_MULHU: result <= muluu[63:32];
                // single-cycle division ;)
                `ALUOP_DIV: result <= div;
                `ALUOP_DIVU: result <= divu;
                `ALUOP_REM: result <= rem;
                `ALUOP_REMU: result <= remu;
			endcase

			O_lt <= lt;
			O_ltu <= ltu;
			O_eq <= eq;

		end
	end
		
endmodule

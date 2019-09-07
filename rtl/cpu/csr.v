`include "cpu/csrdefs.vh"
//`include "ram/generic_ram.v"

module csr
#(
   parameter CSR_DATA_WIDTH = 32,
   parameter CSR_ADDR_WIDTH = 12
)
(
   input  wire                        clk_i,
   input  wire                        rst_i,
   input  wire                        csr_en_i,
   input  wire                        csr_we_i,
   input  wire [CSR_ADDR_WIDTH - 1:0] csr_addr_i,
   input  wire [CSR_DATA_WIDTH - 1:0] csr_data_i,
   output wire [CSR_DATA_WIDTH - 1:0] csr_data_o,
   output wire                        csr_busy_o,
   output wire                        csr_exists_o,
   output wire                        csr_ro_o
);
   assign csr_exists_o = 1;
   assign csr_ro_o = 0;
   assign csr_busy_o = busy;
   
   localparam [3:0] M_VENDOR_ID = 0,
                    M_HART_ID   = 1,
                    M_STATUS    = 2,
                    M_ISA       = 3,
                    M_IE        = 4,
                    M_TVEC      = 5,
                    M_COUNTEREN = 6,
                    M_SCRATCH   = 7,
                    M_EPC       = 8,
                    M_CAUSE     = 9,
                    M_TVAL      = 10,
                    M_IP        = 11,
                    M_TAGS      = 12,
                    M_LAST      = 13;


   reg [3:0] csr_index;
   always @(*) begin
      case (stored_addr)
         `MSR_MVENDORID:  csr_index = M_VENDOR_ID;
         `MSR_MHARTID:    csr_index = M_HART_ID;
         `MSR_MSTATUS:    csr_index = M_STATUS;
         `MSR_MISA:       csr_index = M_ISA;
         `MSR_MIE:        csr_index = M_IE;
         `MSR_MTVEC:      csr_index = M_TVEC;
         `MSR_MCOUNTEREN: csr_index = M_COUNTEREN;
         `MSR_MSCRATCH:   csr_index = M_SCRATCH;
         `MSR_MEPC:       csr_index = M_EPC;
         `MSR_MCAUSE:     csr_index = M_CAUSE;
         `MSR_MTVAL:      csr_index = M_TVAL;
         `MSR_MIP:        csr_index = M_IP;
         `MSR_MTAGS:      csr_index = M_TAGS;
         default :        csr_index = M_VENDOR_ID;
      endcase
   end
   
   reg we;
   reg busy;
   reg [CSR_ADDR_WIDTH - 1:0] stored_addr;
   reg [CSR_DATA_WIDTH - 1:0] stored_data;

   wire [CSR_DATA_WIDTH - 1:0] csr_data_out;
   assign csr_data_o = csr_data_out;

   generic_ram
   #(
      .RAM_WORDS_SIZE (13), //mlast
      .RAM_WORDS_WIDTH (CSR_DATA_WIDTH)
   )
   csr0
   (
      .clk_i    (clk_i),
      .we_i     (we),
      .data_i   (stored_data),
      .w_addr_i (csr_index),
      .r_addr_i (csr_index),
      .data_o   (csr_data_out)
   );
  
   
   always @ (posedge clk_i) begin
      if (rst_i) begin
         we <= 0;
         busy <= 0;
      end
      else begin
         if (csr_en_i) begin
            busy <= 1;
            stored_addr <= csr_addr_i;
            stored_data <= csr_data_i;
            we <= csr_we_i;
         end
         if (busy) begin
            busy <= 0;
            we <= 0;
         end
      end
   end


endmodule



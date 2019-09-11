module wb_timer
  #(parameter WB_DATA_WIDTH = 32,
    parameter WB_ADDR_WIDTH = 32,
    parameter WB_SEL_WIDTH  = 4)
   (input wire                        clk_i,
    input wire                        rst_i,
    input wire [WB_ADDR_WIDTH - 1:0]  wb_addr_i,
    input wire [WB_DATA_WIDTH - 1:0]  wb_data_i,
    input wire                        wb_we_i,
    input wire [WB_SEL_WIDTH - 1:0]   wb_sel_i,
    input wire                        wb_stb_i,
    input wire                        wb_cyc_i,
    output wire                       wb_ack_o,
    output wire [WB_DATA_WIDTH - 1:0] wb_data_o,
    output wire                       timer_irq_o);

   /*verilator public_module*/
   localparam DATA_WIDTH = 64;

   reg [DATA_WIDTH - 1:0]             mtime, // current time
                                      mtimecmp, // treshold time
                                      tgt_clk, // clocks to wait
                                      clk_cnt; // i_clk counter

   localparam [7:0] MTIME_LO = 8'h00;
   localparam [7:0] MTIME_HI = 8'h04;
   localparam [7:0] MTIMECMP_LO = 8'h08;
   localparam [7:0] MTIMECMP_HI = 8'h0C;
   localparam [7:0] TGT_CLK_LO = 8'h10;
   localparam [7:0] TGT_CLK_HI = 8'h14;

   ////////////////////////

   // IRQ pin, raised to HIGH if current time exceeds the threshold
   // It can be raised to HIGH only if treshold is not zero
   reg                                irq;
   wire                               irq_enabled;
   assign irq_enabled = |mtimecmp;
   assign timer_irq_o = irq & irq_enabled;

   // ack signal for wishbone delayed by one clock with a reg
   reg                                ack;
   assign wb_ack_o = ack;

   wire                               timer_enabled;
   assign timer_enabled = |tgt_clk;

   wire [7:0]                         addr = wb_addr_i[7:0];

   assign wb_data_o = addr == MTIME_LO ? mtime[31:0] :
                      addr == MTIME_HI ? mtime[63:32] :
                      addr == MTIMECMP_LO ? mtimecmp[31:0] :
                      addr == MTIMECMP_HI ? mtimecmp[63:32] :
                      addr == TGT_CLK_LO ? tgt_clk[31:0] :
                      addr == TGT_CLK_HI ? tgt_clk[63:32] :
                      32'd0;

   always @ (posedge clk_i) begin
      if (rst_i) begin
         mtime <=0;
         mtimecmp <= 0;
         tgt_clk <= 0;
         clk_cnt <= 1;
         ack <=0;
         irq <= 0;
      end
      else begin
         irq <= irq_enabled ? mtime >= mtimecmp : 0;

         if (wb_cyc_i & wb_we_i) begin
            // No increment for MTIME on write to it
            if ((addr == MTIME_LO ) || (addr == MTIME_HI)) begin
               if (addr == MTIME_LO)
                 mtime[31:0] <= wb_data_i;
               if (addr == MTIME_HI)
                 mtime[63:32] <= wb_data_i;

               // Only update, no check
               if (timer_enabled)
                 clk_cnt <= clk_cnt + 1;
            end
            else begin
               case (addr)
                 MTIMECMP_LO: mtimecmp[31:0] <= wb_data_i;
                 MTIMECMP_HI: mtimecmp[63:32] <= wb_data_i;
                 TGT_CLK_LO: tgt_clk[31:0] <= wb_data_i;
                 TGT_CLK_HI: tgt_clk[63:32] <= wb_data_i;
                 default:;
               endcase // case (addr)

               if (timer_enabled) begin
                  if (clk_cnt >= tgt_clk) begin
                     clk_cnt <= 1;
                     mtime <= mtime + 1;
                  end
                  else begin
                     clk_cnt <= clk_cnt + 1;
                  end
               end
            end // else: !if((addr == MTIME_LO ) || (addr == MTIME_HI))

            ack <= wb_cyc_i;
         end // if (wb_cyc_i & wb_we_i)
         else begin
            if (timer_enabled) begin
               if (clk_cnt >= tgt_clk) begin
                  clk_cnt <= 1;
                  mtime <= mtime + 1;
               end
               else begin
                  mtime <= mtime;
                  clk_cnt <= clk_cnt + 1;
               end
            end
            ack <= 0;
         end // else: !if(wb_cyc_i & wb_we_i)
      end // else: !if(rst_i)
   end // always @ (posedge clk_i)
endmodule // wb_timer

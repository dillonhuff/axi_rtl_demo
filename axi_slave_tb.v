`define POSEDGE #1 clk = 0; #1 clk = 1; #1 clk = 0; #1

module test();

   parameter ADDRESS_WIDTH = 8;
   parameter DATA_WIDTH = 32;

   reg clk;
   reg rst;

   // Read address channel
   reg [ADDRESS_WIDTH - 1 : 0] araddr;
   reg [7:0]                   arlen;
   reg [2:0]                   arsize;
   reg [1:0]                   arburst;
   reg                        arvalid;
   wire                        arready;

   // Read data channel
   wire [DATA_WIDTH - 1 : 0]   rdata;
   wire [1:0]                  rresp;
   wire                       rlast; 
   wire                       rvalid;
   reg                        rready;
   
   
   initial begin
      #1 clk = 0;
      #1 rst = 0;

      #10 rst = 1;

      #10 arvalid = 1;
      arlen = 5;
      arsize = 2;
      arburst = 1;
      araddr = 7;

      #30 arvalid = 0;
      rready = 1;
      
      #1 $display("Done.");
      
      #100 $finish();
   end

   always #5 clk = ~clk;

   always @(posedge clk) begin
      if (arready && arvalid) begin
         $display("Starting read burst");
      end else begin
         $display("arready = %d, arrvalid = %d", arready, arvalid);
      end
   end

   axi_slave_ram dut(.aclk(clk),
                     .aresetn(rst),

                     .araddr(araddr),
                     .arsize(arsize),
                     .arlen(arlen),
                     .arburst(arburst),
                     .arvalid(arvalid),
                     .arready(arready),

                     .rdata(rdata),
                     .rlast(rlast),
                     .rresp(rresp),
                     .rready(rready),
                     .rvalid(rvalid));

endmodule

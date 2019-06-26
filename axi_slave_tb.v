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
   reg                         arvalid;
   reg                        arready;

   // Read data channel
   reg [DATA_WIDTH - 1 : 0]   rdata;
   reg [1:0]                  rresp;
   reg                        rlast; 
   reg                        rvalid;
   reg                         rready;
   
   
   initial begin
      #1 clk = 0;
      #1 rst = 0;
      
   end

   axi_slave_ram dut(.aclk(clk),
                     .aresetn(rst),

                     .araddr(araddr),
                     .arsize(arsize),
                     .arlen(arlen),
                     .arburst(arburst),
                     .arvalid(arvalid),
                     .arready(arread));

endmodule

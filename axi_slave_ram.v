module axi_slave_ram(
                     // Global signals
                     input                         aclk,
                     input                         aresetn,

                     // Write address channel
                     input [ADDRESS_WIDTH - 1 : 0] awaddr,
                     input [7:0]                   awlen,
                     input [2:0]                   awsize,
                     input [1:0]                   awburst,
                     input                         awvalid,
                     output                        awready,

                     // Write data channel
                     input [DATA_WIDTH - 1 : 0]    wdata,
                     input [STROBE_WIDTH - 1 : 0]  wstrb,
                     input                         wlast,
                     input                         wvalid,
                     output                        wready,

                     // Write response channel
                     output [1:0]                  bresp,
                     output                        bvalid,
                     input                         bready,

                     // Read address channel
                     input [ADDRESS_WIDTH - 1 : 0] araddr,
                     input [7:0]                   arlen,
                     input [2:0]                   arsize,
                     input [1:0]                   arburst,
                     input                         arvalid,
                     output                        arready,

                     // Read data channel
                     output [DATA_WIDTH - 1 : 0]   rdata,
                     output [1:0]                  rresp,
                     output                        rlast, 
                     output                        rvalid,
                     input                         rready
                     );

   parameter DATA_WIDTH = 32;
   parameter STROBE_WIDTH = DATA_WIDTH / 8;
   parameter ADDRESS_WIDTH = 8;
   parameter BYTES_PER_WORD = STROBE_WIDTH;

   // Start with slave reads, take in read burst, and then
   // emit read data?

   // What is the size of the underlying memory?
   // 2**(address width) bytes, so
   // 2**(address width) / bytes_per_word

   //reg [DATA_WIDTH - 1 : 0]                        ram [(2**(ADDRESS_WIDTH)) / BYTES_PER_WORD - 1: 0];

   reg [7:0]                                       ram[2**ADDRESS_WIDTH];
   
   // Read state is?
   // Idle (waiting for burst)
   // Servicing burst

   localparam READ_CONTROLLER_WAITING = 0;
   localparam READ_CONTROLLER_ACTIVE = 1;   

   reg                                             read_state;

   reg [ADDRESS_WIDTH - 1 : 0]                        read_burst_base_addr;
   reg [8:0]                                          read_bursts_remaining;
   reg [2:0]                                          read_burst_size;
   reg [1:0]                                          read_burst_type;

   // Maybe right structure: Have next registers and current registers to
   // store values for the next transaction while waiting on the first one?

   // If we are in the wait state we cannot transition to active until
   // read is ready

   // If we are in the active state we cannot transition to a new state
   // until the rready signal is high
   always @(posedge aclk) begin
      if (!aresetn) begin
         read_state <= READ_CONTROLLER_WAITING;
         //rvalid <= 0;
      end else begin

         $display("read bursts remaining = %d", read_bursts_remaining);
         
         // Starting a burst
         if (arvalid && arready) begin
            read_state <= READ_CONTROLLER_ACTIVE;
            read_bursts_remaining <= {1'b0, arlen} + 8'd1; // # of bursts is len + 1 in AXI
            read_burst_base_addr <= araddr;
            read_burst_type <= arburst;
            read_burst_size <= arsize;
         end else if (rvalid && rready) begin
            read_bursts_remaining <= read_bursts_remaining - 1;
            // calculate next address
            // update address register

            if (read_bursts_remaining == 1) begin
               read_state <= READ_CONTROLLER_WAITING;
            end
         end
      end
   end // always @ (posedge aclk)

   assign arready = read_state == READ_CONTROLLER_WAITING;

endmodule

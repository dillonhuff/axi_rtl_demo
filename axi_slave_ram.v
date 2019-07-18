module axi_slave_ram(
                     // Global signals
                     input                           aclk,
                     input                           aresetn,

                     // Write address channel
                     input [ADDRESS_WIDTH - 1 : 0]   awaddr,
                     input [7:0]                     awlen,
                     input [2:0]                     awsize,
                     input [1:0]                     awburst,
                     input                           awvalid,
                     output                          awready,

                     // Write data channel
                     input [DATA_WIDTH - 1 : 0]      wdata,
                     input [STROBE_WIDTH - 1 : 0]    wstrb,
                     input                           wlast,
                     input                           wvalid,
                     output                          wready,

                     // Write response channel
                     output [1:0]                    bresp,
                     output                          bvalid,
                     input                           bready,

                     // Read address channel
                     input [ADDRESS_WIDTH - 1 : 0]   araddr,
                     input [7:0]                     arlen,
                     input [2:0]                     arsize,
                     input [1:0]                     arburst,
                     input                           arvalid,
                     output                          arready,

                     // Read data channel
                     output [DATA_WIDTH - 1 : 0] rdata,
                     output [1:0]                    rresp,
                     output                          rlast,
                     output                          rvalid,
                     input                           rready
                     );

   parameter DATA_WIDTH = 32;
   parameter STROBE_WIDTH = DATA_WIDTH / 8;
   parameter ADDRESS_WIDTH = 8;
   parameter BYTES_PER_WORD = STROBE_WIDTH;
   parameter DATA_BUS_BYTES = DATA_WIDTH / 8;
   
   reg [7:0]                                       ram[2**ADDRESS_WIDTH];
   
   // Read state is?
   // Idle (waiting for burst)
   // Servicing burst

   localparam READ_CONTROLLER_IDLE = 0;
   localparam READ_CONTROLLER_LOADING = 1;
   localparam READ_CONTROLLER_ACTIVE = 2;

   localparam BURST_TYPE_INCR = 1;

   reg [31:0]                                             read_state;

   reg [ADDRESS_WIDTH - 1 : 0]                     read_burst_base_addr;
   reg [8:0]                                       read_bursts_remaining;
   reg [2:0]                                       read_burst_size;
   reg [1:0]                                       read_burst_type;

   // Current read address
   reg [ADDRESS_WIDTH - 1 : 0]                     read_addr;
   
   // Next address calculation
   reg [8:0]                                       read_transfer_number;
   reg [ADDRESS_WIDTH - 1 : 0]                     aligned_addr_read;
   reg [ADDRESS_WIDTH - 1 : 0]                     next_read_addr;
   reg [ADDRESS_WIDTH - 1 : 0]                     number_bytes_read;

   reg [ADDRESS_WIDTH - 1 : 0]                     lower_byte_lane_read;
   reg [ADDRESS_WIDTH - 1 : 0]                     upper_byte_lane_read;

   reg [DATA_WIDTH - 1 : 0]                        read_value_reg;

   integer                                         i;

   initial begin
      for (i = 0; i < 2**ADDRESS_WIDTH; i = i + 1) begin
         ram[i] = i % 256;
      end
   end
   
   always @(*) begin
      if (read_burst_type == BURST_TYPE_INCR) begin
         // Use read_transfer number (not read_transfer_number - 1)
         // because we are at the Nth read, but we are computing the
         // (N + 1)th read address
         next_read_addr = aligned_addr_read + (read_transfer_number)*number_bytes_read;
      end else begin
         $display("Unsupported burst type %d", read_burst_type);
      end

      if (read_transfer_number == 1) begin
         lower_byte_lane_read = read_addr - (read_addr / DATA_BUS_BYTES)*DATA_BUS_BYTES;
         upper_byte_lane_read = aligned_addr_read + (number_bytes_read - 1) - (read_addr / DATA_BUS_BYTES)*DATA_BUS_BYTES;
      end else begin
         lower_byte_lane_read = read_addr - (read_addr / DATA_BUS_BYTES)*DATA_BUS_BYTES;
         upper_byte_lane_read = lower_byte_lane_read + (number_bytes_read - 1);
      end
   end // always @ (*)

   // Maybe right structure: Have next registers and current registers to
   // store values for the next transaction while waiting on the first one?

   // If we are in the wait state we cannot transition to active until
   // read is ready

   // If we are in the active state we cannot transition to a new state
   // until the rready signal is high

   // Maybe I should have "next read" registers for the address of the read
   // that will be serviced next time rvalid is high?
   always @(posedge aclk) begin

      $display("read state = %d", read_state);
      $display("upper_byte_lane = %d", upper_byte_lane_read);      
      
      if (!aresetn) begin
         read_state <= READ_CONTROLLER_IDLE;

         //rvalid <= 0;
      end else begin

         //$display("read bursts remaining = %d", read_bursts_remaining);
         //$display("Number bytes read = %d", number_bytes_read);
         //$display("Aligned addr      = %d", aligned_addr_read);            

         // Starting a burst
         if (arvalid && arready) begin

            read_state <= READ_CONTROLLER_LOADING;
            
            read_bursts_remaining <= {1'b0, arlen} + 8'd1; // # of bursts is len + 1 in AXI
            read_burst_base_addr <= araddr;
            read_burst_type <= arburst;
            read_burst_size <= arsize;

            read_transfer_number <= 1;

            // Calculated from burst parameters
            read_addr <= araddr;
            number_bytes_read <= 2**arsize;
            aligned_addr_read <= (araddr / 2**arsize) * 2**arsize;

            // Should this condition be rvalid and rready
         end else if ((read_state == READ_CONTROLLER_ACTIVE) && (rvalid && rready)) begin

            //$display("%d th read addr   = %d, (aligned %d), lanes: %d to %d, data = %b", read_transfer_number, read_addr, aligned_addr_read, lower_byte_lane_read, upper_byte_lane_read, rdata);
            
            read_transfer_number <= read_transfer_number + 1;
            read_bursts_remaining <= read_bursts_remaining - 1;
            read_addr <= next_read_addr;

            // calculate next address
            // update address register

            if (read_bursts_remaining == 1) begin
               read_state <= READ_CONTROLLER_IDLE;
            end else begin
               read_state <= READ_CONTROLLER_LOADING;
            end

            // I would like for reads from RAM to be done in
            // exactly one place but I do not know how to
            // do that

         end else if (read_state == READ_CONTROLLER_LOADING) begin // if (READ_CONTROLLER_ACTIVE && (rvalid && rready))

            $display("setting read controller active");
            
            read_state <= READ_CONTROLLER_ACTIVE;

            for (i = 0; i < DATA_BUS_BYTES; i = i + 1) begin
               if (lower_byte_lane_read <= i && i <= upper_byte_lane_read) begin
                  read_value_reg[i*8 +: 8] <= ram[read_addr + i - lower_byte_lane_read];
               end else begin
                  read_value_reg[i*8 +: 8] <= 0;
               end
            end
         end
      end
   end // always @ (posedge aclk)

   always @(posedge aclk) begin
      $display("read addr = %d", read_addr);
      
   //    $display("read_state = %d", read_state);
   end

   assign rdata = read_value_reg;
   
   assign arready = read_state == READ_CONTROLLER_IDLE;
   assign rvalid = read_state == READ_CONTROLLER_ACTIVE;

   // Idea: Allow state machines with wait statements?
   // lambdas are anonymous functions, for, if, etc
   // are anonymous control flow

endmodule

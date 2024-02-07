module clock_divisor #(
parameter TIMER_BITS	= 32)(
    input	logic	clk, rst, enable,
	 input	logic [TIMER_BITS-1:0]	prescaler,
    output	logic [TIMER_BITS-1:0] 	cnt,
	 output  logic strobe
    );

	 logic [TIMER_BITS-1:0]cnt_prescaler;
always @ (posedge(clk), posedge(rst))
begin
		if (rst) begin
		cnt_prescaler = 1'd0;
		strobe = 1'd0;
		end

		else if (enable)	
		begin
				if(cnt_prescaler == prescaler)	
				begin
					cnt_prescaler = 1'd0;
					strobe = 1'd1;
				end
					else
				begin
					cnt_prescaler = cnt_prescaler + 1'd1;
					strobe = 1'd0;
				end
		end
end
always @ (posedge(clk))
	begin	
	if (rst)		cnt = 1'd0;
	if (strobe) cnt = cnt + 1'd1;
	end

endmodule

module clock_divisor_zero #(
parameter 	TIMER_BITS	= 32)(
				
   input		clk, rst, enable,
	input		logic [TIMER_BITS-1:0]	prescaler,		// Значение предделителя
   output	logic [TIMER_BITS-1:0] 	cnt,	
	output	logic strobe
   );

	logic [TIMER_BITS-1:0]cnt_prescaler;
always @ (posedge(clk), posedge(rst))
begin
	if (rst) 
	begin
		cnt_prescaler = 1'd0;
		strobe = 1'd0;
	end
	else	if (enable)	
				if (prescaler ==	1)	strobe = 1'd1;
				else if(cnt_prescaler == prescaler)	
				begin
					cnt_prescaler = 1'd0;
					strobe = 1'd1;
				end	else	begin
					cnt_prescaler = cnt_prescaler + 1'd1;
					strobe = 1'd0;
				end
			else strobe = 1'd0;
end
			
always @ (posedge(clk))
	begin	
	if (rst)	cnt = 1'd0;
	if (strobe) cnt = cnt + 1'd1;
	end

endmodule


module delay_n_cycles #(parameter N = 32)(
  input wire [31:0] data_in,
  input wire clk,
  output reg [31:0] data_out
);

  reg [N-1:0][31:0] shift_reg;

always @(posedge clk) begin
  shift_reg <= (shift_reg << 32) | data_in;
  data_out <= shift_reg[N-1];
end
endmodule
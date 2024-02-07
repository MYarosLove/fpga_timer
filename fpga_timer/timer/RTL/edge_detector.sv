module edge_detector (

	input clk_i,								// Тактирование 
	input rst_i,								// Сброс
	input async_sig,							// Внешний асинхронный клок
	input edge_mode,							// Строб по фронту или срезу
	
	output reg rise_o,						// Факт детектирования фронта
	output reg fall_o,						// Факт детектированя среза
	
	output reg active_strobe_o				// Строб показывающий наличие изменений
	);

  reg [1:3] resync;

  always @(posedge clk_i)
  begin
    // detect rising and falling edges.
    rise_o <= resync[2] & !resync[3];
    fall_o <= resync[3] & !resync[2];
    // update history shifter.
    resync <= {async_sig , resync[1:2]};
  end
assign active_strobe_o = edge_mode	?	fall_o	:	rise_o;	// входной импульс выбирается в зависимости от режима

endmodule

module edge_detector_classic (

	input clk_i,								// Тактирование 
	input rst_i,								// Сброс
	input async_sig,						// Внешний асинхронный клок
	input edge_mode,							// Строб по фронту или срезу
	
	output reg pos_edge,						// Факт детектирования фронта
	output reg neg_edge,						// Факт детектированя среза
	
	output logic in_pulse				// Строб показывающий наличие изменений
);

	reg [3:0] clk_ext_past;
	reg         clk_ps_past;
//Input edge detector
always @(posedge clk_i)
	if (rst_i)	
		clk_ext_past = 4'b0;
	else	
		clk_ext_past = clk_ext_past << 1|async_sig;
  
assign pos_edge = ( (&(~clk_ext_past[3:2])) & (&clk_ext_past[1:0]) );
assign neg_edge = ( (&(~clk_ext_past[1:0])) & (&clk_ext_past[3:2]) );

assign in_pulse = edge_mode	?	neg_edge	:	pos_edge;
endmodule



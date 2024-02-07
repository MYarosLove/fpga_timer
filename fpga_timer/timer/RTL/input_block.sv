// Может работать в режиме асинхронного таймера

module async_block #(
	parameter	COUNTER_SIZE  = 32,
					PRESCALER_BIT = 32)
(
	input		clk_ext,								// Внешнее тактирование
				clk_i,								// Тактирование
				rst,									// Сброс
	input		[PRESCALER_BIT-1:0]	prescaler_val,  // Предделитель
	input 	edge_mode,							// Фронт / срез

	output	clk_pulse,							// Строб
	output 	logic [PRESCALER_BIT-1:0]	ps_counter_out
);


initial 
begin
	pos_edge			=	1'd0;
	neg_edge			=	1'd0;
	in_pulse			=	1'd0;
	clk_ps			=	1'd0;
	clk_ps_past		=	1'd0;
end

	reg 		[7:0] clk_ext_past;				// 8 битный регистр используемый для детектора фронтов или среза
	wire     pos_edge;							// Фронт (переход 0 -> 1)
	wire     neg_edge;							// Срез (переход 1 -> 0)

	reg   	[PRESCALER_BIT-1:0] ps_counter;					// Счетчик предделителя
	wire     in_pulse;							// 
	wire     clk_ps;								// Текущий импульс
	reg      clk_ps_past;						// Прошлый импульс

	logic 	stb;									// Строб для основного таймера

edge_detector 
	edge_detector (
		.clk_i(clk_i),								// Тактирование 
		.rst_i(rst),								// Сброс
		.async_sig(clk_ext),						// Внешний асинхронный клок
		.edge_mode(edge_mode),							// Строб по фронту или срезу
		.rise_o(pos_edge),						// Факт детектирования фронта
		.fall_o(neg_edge),						// Факт детектированя среза
		.active_strobe_o(in_pulse )			
);


clock_divisor_zero #(.TIMER_BITS(32)) 
	divisor(
			.clk			(clk_i),
			.rst			(rst),
			.enable 		(in_pulse),
			.prescaler	(prescaler_val),
			.cnt			(ps_counter_out),
			.strobe		(clk_ps)
);

	
	// Текущий импульс приводится к положительному фронту
	assign  clk_pulse = ~clk_ps_past & clk_ps;
  
       
endmodule

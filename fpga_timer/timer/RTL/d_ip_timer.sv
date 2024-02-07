// Code your design here

module d_ip_timer #(
	parameter COUNTER_SIZE	=	32,
	parameter PRESCALER_BIT	=	32)
(
	input  clk,										// Тактирование
	input  rst_b,									// Сброс
	input  [5:0] addr,							// Адресс регистров
	input  wr_en,									// 1 - пишем в регистр 0 - читаем из регистра
	input  mod_en,									// Сигнал выбора модуля. Активный уровень - 1
	input  timer_in,								// Внешний синхросигнал или внешние тактовые импульсы
	input  [COUNTER_SIZE-1:0] wdata,			// Данные записываемые в регистр
	
	output logic [COUNTER_SIZE-1:0] rdata,			// Значение считанное из регистра
	output logic [COUNTER_SIZE-1:0] sync_cnt,
	output logic [COUNTER_SIZE-1:0] aync_cnt,
	output timer_out,								// Выход ШИМ
	output trigger,
	output overflow_int,							// Флаг прерывания по переполнению
			comp_1_match_int,						// Флаг прерывания по совпадению канала 0
			comp_0_match_int						// Флаг прерывания по сопвадению канала 1
			
);

	localparam CNTR_ADDR	=	6'h04;  
	localparam NUM_COMP	=	2;

	wire                     overflow_trg_en;
	wire                     out_match_1_trg_en;
	wire                     out_match_0_trg_en;
	wire                     overflow_int_en;
	wire                     out_match_1_int_en;
	wire                     out_match_0_int_en;
	wire                     clock_select;
	wire                     count_mode;
	wire                     start;
	wire [COUNTER_SIZE-1:0]  counter_value;
	wire                     counter_overflow;

	wire [COUNTER_SIZE-1:0]  match_1_value;
	wire [COUNTER_SIZE-1:0]  match_0_value;

	wire [COUNTER_SIZE-1:0]  count_min;
	wire [COUNTER_SIZE-1:0]  count_max;
	wire [COUNTER_SIZE-1:0]  count_init;

	wire overflow_status_flag;
	wire cnt_match_0_status_flag;
	wire cnt_match_1_status_flag;
	wire cnt_match_0_status_flag_set;
	wire cnt_match_1_status_flag_set;


	reg start_1;
	wire start_rise;
	  

	wire up_count;										// Счет в верх
	wire down_count;									// Счет в низ
	wire free_mode;									
	wire clk_pulse;									// Провод с клоком
	wire pwm_mode;										// Режим ШИМ
	wire edge_mode;									// Фронт \ срез
	wire inv;
	wire trigger_int;
	wire enable_operation;							// Разрешение работы

	assign sync_cnt	=	sync_counter_value;// Синхронные счетчик
	
	wire [PRESCALER_BIT-1:0] async_prescaler;			// Предделитель
	wire [PRESCALER_BIT-1:0] sync_prescaler;			// Предделитель
	
	//decode
	assign  ext_clock_select = clock_select;

	//edge detector
	always @ (posedge clk) begin
	 start_1 <= start;
	end  
	assign start_rise = start & ~start_1;

	// Разрешение работы - 
	assign enable_operation = clk_pulse & ext_clock_select & start	| ~ext_clock_select & start;

	timer_registers #(.COUNTER_SIZE(COUNTER_SIZE), .PRESCALER_BIT(PRESCALER_BIT))timer_registers(
	.clk (clk),
	.rst (~rst_b),
	.module_en (mod_en),
	.wr (wr_en),
	.wdata (wdata),
	.addr (addr),
	.overflow_int_en(overflow_int_en),
	.out_match_1_int_en(out_match_1_int_en),
	.out_match_0_int_en(out_match_0_int_en),  
	.overflow_trg_en(overflow_trg_en),
	.out_match_1_trg_en(out_match_1_trg_en),
	.out_match_0_trg_en(out_match_0_trg_en),
	.clock_select(clock_select),
	.count_mode(count_mode),
	.force_free (free_mode),
	.count_init(count_init),
	.count_min(count_min),
	.count_max(count_max),
	.match_1_value(match_1_value),
	.match_0_value(match_0_value),
	.overflow_status_flag(overflow_status_flag),
	.cnt_match_0_status_flag(cnt_match_0_status_flag),
	.cnt_match_1_status_flag(cnt_match_1_status_flag),
	.overflow(counter_overflow),
	.match_0(cnt_match_0_status_flag_set),
	.match_1(cnt_match_1_status_flag_set),     
	.start(start),
	.inv(inv),
	//.sync_prescaler(prescaler),
	.pwm_mode(pwm_mode),
	.edge_mode(edge_mode),
	.cnt_init_wr(cnt_init_wr),
	.rdata (rdata)
	);

	// Таймер - счетчик
	timer_counter #(.COUNTER_SIZE (COUNTER_SIZE))                                            
	timer_counter(                               
	 .clk_i				(clk),											// Тактирование
	 .en_i				(enable_operation),							// Разрешение работы
	 .rst_i				(~rst_b),										// Сброс
	 .cnt_mode 			( ~count_mode ), 								// Режим счета 
	 .free 				(free_mode),	 
	 .init_cnt			(cnt_init_wr),
	 .min 				(count_min),									// Максимальное значение
	 .max 				(count_max),									// Минимальное значение
	 .init_val			(count_init),
	 .clock_divisor 	(sync_prescaler),
	 .sync_cnt_value	(sync_counter_value),						// Значение таймера
	 .overflow_set		(counter_overflow)				// Переполнение таймера (флаг)                     
	);

	// Прерывание по переполнению - разрешено прерывание и установлен флаг прерывания (аппаратно)
	assign overflow_int = overflow_int_en && overflow_status_flag;

	async_block #(.PRESCALER_BIT(PRESCALER_BIT), .COUNTER_SIZE(COUNTER_SIZE)) async_block (

	.clk_i			(clk),					// Системный клок
	.clk_ext			(timer_in),				// Внешний клок (может быть сиситемным)
	.rst				(~rst_b),				
	.edge_mode		(edge_mode),  
	.clk_pulse		(clk_pulse),
	.prescaler_val	(async_prescaler)
		
	);

	output_block  #(.NUM_COMP (NUM_COMP), .COUNTER_SIZE(COUNTER_SIZE))    
	output_block (
	.clk           (	clk),
	.rst           (	~rst_b),
	.counter_value (	counter_value),
	.pwm_mode      (	pwm_mode),
	.timer_out     (	timer_out),
	.match_value   ({ match_1_value,
							match_0_value  }),
	.match         ({ cnt_match_1_status_flag_set,
							cnt_match_0_status_flag_set}),
	.flag          ({ cnt_match_1_status_flag,
							cnt_match_0_status_flag}),
	.intr_en       ({ out_match_1_int_en,
							out_match_0_int_en }),
	.trg_en        ({ out_match_1_trg_en,
							out_match_0_trg_en   }),
	.intr          ({ comp_1_match_int,
							comp_0_match_int   }),
	.inv           (	inv),
	.en            (	enable_operation),
	.trigger       (	trigger_int)
	);

	assign trigger = trigger_int | (counter_overflow & overflow_trg_en);

	endmodule

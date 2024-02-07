module timer_top  #(
	parameter NUM_COMP		=	2,
	parameter COUNTER_SIZE	=	32,
	parameter PRESCALER_BIT	=	32)
(
   input   logic clk_i, 
   input   logic rst_i, 
   //input   logic module_en, 
   //input   logic wr,
   inout   logic timer_in,                         // Внешний сигнал

   input   reg [7:0] CTRL_REG,                    // Регистр управления режимом работы и прерываниям
	input	  reg [7:0] CTRL_INTR,                   // Регистр управления прерываниями 
   input   reg [7:0] CTRL_PWM,                    // Регистр управления выходным сигналом (ШИМ)
    
   input   reg [PRESCALER_BIT-1:0]	DIVISOR_SYNC_VAL,
   input   reg [PRESCALER_BIT-1:0]	DIVISOR_ASYNC_VAL,
   input   reg [COUNTER_SIZE-1:0]	CNT_INIT_START_VAL,
   input   reg [COUNTER_SIZE-1:0]	CNT_INIT_MIN,
   input   reg [COUNTER_SIZE-1:0]	CNT_INIT_MAX,
    
   input   logic [COUNTER_SIZE-1:0] CNT_MATCH_CH_0,
   input   logic [COUNTER_SIZE-1:0] CNT_MATCH_CH_1,


   output  logic [7:0]              STATUS,
	output  logic [7:0] 					INTERRUPT_FLAG,
   output  logic [COUNTER_SIZE-1:0] CNT_VAL_SYNC,
   output  logic [COUNTER_SIZE-1:0] CNT_VAL_ASYNC,
	
	output logic	PWM_OUT_GPIO
);

	
   // CTRL_REG
	// Регистр управления таймером-счетчиком
   localparam CTRL_START_BIT =   0;
	localparam CTRL_FREE_BIT    = 1;
   localparam CTRL_CNT_MODE_BIT= 2;
   localparam CTRL_CLK_SEL_BIT = 3;
	localparam CTRL_CNT_INIT_BIT = 4;
	localparam CTRL_EDGE_BIT	= 5;
	localparam CTRL_TRIGGER_OUT_BIT_EN	=	6;
	
	
   // CTRL_INTR
	// Регистр управления прерываниями
   localparam CTRL_INTR_OVF_EN_BIT		= 0;
   localparam CTRL_INTR_MO_BIT			= 1;
   localparam CTRL_INTR_M1_BIT			= 2;

	// CTRL_PWM
	// Регистр управления выходным каскадом
	localparam PWM_MODE_BIT =   0;
   localparam PWM_INV_BIT  =   1;
   localparam PWM_OVF_TRG  =   2;
   localparam PWM_M0_TRG   =   3;
   localparam PWM_M1_TRG   =   4;
	localparam PWM_TRG_OUT  =   5;
	
	// INTERRUPT_FLAG
	// Регистр статуса прерываний
	localparam 	OVF_TIM_INTR_FLAG			=	0;
	localparam	COMP_MATCH0_INTR_FLAG	=	1;
	localparam	COMP_MATCH1_INTR_FLAG	=	2;
	
	// STATUS
	// Регистр статуса (флаги статуса)
	localparam 	STATUS_OVF_TIM_F			=	0;
	localparam	STATUS_COMP_0_MATCH_F	=	1;
	localparam	STATUS_COMP_1_MATCH_F	=	2;
	localparam	STATUS_TRG_STATUS			=	3;
	

	logic [7:0] localCTRL_REG;
	
	
    // Таймер - счетчик
	timer_counter #(.PRESCALER_BIT(PRESCALER_BIT), .COUNTER_SIZE(COUNTER_SIZE))                                            
	timer_counter(                               
	 .clk_i				(clk_i),										// Тактирование
	 .en_i				(enable_operation),						// Разрешение работы / настройка таймера
	 .rst_i				(~rst_i),									// Сброс
	 .cnt_mode 			( ~CTRL_REG[CTRL_CNT_MODE_BIT] ),	// Режим счета 
	 .free 				(CTRL_REG	[CTRL_FREE_BIT]), 
	 .init_cnt			(CTRL_REG[CTRL_CNT_INIT_BIT]),											// Механизм инициализации таймера пока не реализован.
	 .min 				(CNT_INIT_MIN),							// Максимальное значение
	 .max 				(CNT_INIT_MAX),							// Минимальное значение
	 .init_val			(CNT_INIT_START_VAL),
	 .clock_divisor 	(DIVISOR_SYNC_VAL),
	 .sync_cnt_value	(CNT_VAL_SYNC),							// Значение таймера
	 .overflow_set		(overflow_status_flag)					// Переполнение таймера (флаг)                   
	);

	logic enable_operation;
	logic clk_pulse;
	
	// Прерывание по переполнению - разрешено прерывание и установлен флаг прерывания (аппаратно)
	
	assign overflow_int = CTRL_INTR[CTRL_INTR_OVF_EN_BIT] && overflow_status_flag;
	
   assign trigger = trigger_out_stat | (overflow_status_flag & CTRL_REG[CTRL_TRIGGER_OUT_BIT_EN]);
	
	assign enable_operation = (clk_pulse & CTRL_REG[CTRL_CLK_SEL_BIT] & CTRL_REG[CTRL_START_BIT])	| (~CTRL_REG[CTRL_CLK_SEL_BIT] & CTRL_REG[CTRL_START_BIT]);

	
	// Выставляем прерывание
	always_ff @ (posedge clk_i or negedge rst_i)
	begin
			INTERRUPT_FLAG[OVF_TIM_INTR_FLAG]	=	overflow_int;
	end
	// Выставляем флаг статуса
	always_ff @ (posedge clk_i or negedge rst_i)
	begin
			STATUS[STATUS_OVF_TIM_F]	<=	overflow_status_flag;
			STATUS[STATUS_TRG_STATUS]	<=	trigger_out_stat | (overflow_status_flag & CTRL_REG[CTRL_TRIGGER_OUT_BIT_EN]);
	end
	
	
	async_block #(.PRESCALER_BIT(PRESCALER_BIT), .COUNTER_SIZE(COUNTER_SIZE)) 
	async_block (
	.clk_i				(clk_i),		                         // Системный клок
	.clk_ext				(timer_in),		                      // Внешний клок (может быть сиситемным)
	.rst					(rst_i),				
	.edge_mode			(CTRL_REG[CTRL_EDGE_BIT]),
	.clk_pulse			(clk_pulse),
	.prescaler_val		(DIVISOR_ASYNC_VAL),
   .ps_counter_out 	(CNT_VAL_ASYNC)
	);
	
   logic first, second;
   logic trigger_out_stat;
	
    // Блок ШИМ
   PWM_block  #(.NUM_COMP (NUM_COMP), .COUNTER_SIZE(COUNTER_SIZE))    
	output_block (
	.clk           (clk_i),        // Тактирование
	.rst           (~rst_i),       // Сброс   
   .match_value   ({	CNT_MATCH_CH_1,                //
							CNT_MATCH_CH_0  }),    
	.counter_value (	CNT_VAL_SYNC),     
    
	.pwm_mode      (	CTRL_PWM[PWM_MODE_BIT]),           // Режим работы ШИМ
	.intr_en       ({ CTRL_INTR[CTRL_INTR_M1_BIT],
							CTRL_INTR[CTRL_INTR_MO_BIT] }),
							
	.trg_en        ({ CTRL_PWM[PWM_M1_TRG],
							CTRL_PWM[PWM_M0_TRG]   }),

	.inv           (CTRL_PWM[PWM_INV_BIT]),
	.en            (enable_operation),
	// Выходы
   .trigger       (trigger_out_stat),
   .timer_out     (PWM_OUT_GPIO), 
	
	.intr          ({ INTERRUPT_FLAG[COMP_MATCH1_INTR_FLAG],
							INTERRUPT_FLAG[COMP_MATCH0_INTR_FLAG]   }),					
 								
   .match         ({STATUS[STATUS_COMP_1_MATCH_F], 
							STATUS[STATUS_COMP_0_MATCH_F]})
	);

	
	
	
endmodule : timer_top
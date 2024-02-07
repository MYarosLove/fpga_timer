// Синхронный таймер
// Модуль выдает значени с синхронного таймера-счетчика
// флаг переполнения

module timer_counter	#( parameter COUNTER_SIZE  = 32, PRESCALER_BIT	=	32)(
				input clk_i,						// Тактирование 
				en_i,									// Разрешение работы
				rst_i,									// Сброс
				cnt_mode,							// Режим счета
				free,
				init_cnt,							// Инициализация счетчика
				
	input	logic [COUNTER_SIZE-1:0]  min,		// Минимум
	input logic	[COUNTER_SIZE-1:0]  max,		// Максимум
	input logic	[COUNTER_SIZE-1:0]  init_val,  	// Значение инициализации    
	input logic	[PRESCALER_BIT-1:0]	clock_divisor,			// Предделитель для синхронного таймера
	output	logic	[COUNTER_SIZE-1:0]  sync_cnt_value,
	output 	reg overflow_set					// Флаг переполнения
);


initial 
begin
start_load = 1'd1;								// Начальная загрузка разрешена

end

wire up,down;										// Направление счета
wire overflow_up_set;							// Флаг переполнения при счете вверх
wire overflow_down_set;							// Флаг переполнения при счете в низ
wire overflow_set_local;

logic clk_strobe;
logic overflow_dwn_set;
logic overflow_status_flag;
logic overflow_int;
logic trigger;
logic clk_pulse;
logic timer_out;

assign up   = (cnt_mode	==	1);					// Режим - счет вверх
assign down = (cnt_mode	==	0);					// режим - счет вниз


clock_divisor_zero #(.TIMER_BITS(32)) 
				divisor(
				.clk			(clk_i),
				.rst			(rst_i),
				.enable 		(1),
				.prescaler	(clock_divisor),
				.strobe		(clk_strobe)
);

/*
always @(posedge clk_strobe or posedge rst_i)
begin
  if (rst_i)
      sync_cnt_value = 0;								// Сброс
  else if (init_cnt)
      sync_cnt_value = init_val;						// Инициализация счетчика некоторым значением
  else	begin
    if (en_i) begin										// Если есть разрешающий сигнал счета (enable)
       if ((up|free) & ~down )	
		 begin												// Счет вверех с автоматической загрузкой минимального значения (при free = 0)
          if (~free)	begin
            if (sync_cnt_value < max)	sync_cnt_value = sync_cnt_value + 1;	// Не досчитали до конца. Счет в нормальном режиме
              	else if (sync_cnt_value >= max)	sync_cnt_value = min;			// АНалог переполнения. Начинаем счет с начального (минимального значения)
							end
          else	sync_cnt_value = sync_cnt_value + 1;									// Счет в режиме free тупо до COUNTER_SIZE
       end
       else if ( (down|free) & ~up )														// Счет на уменьшение
       begin
          if (~free)	begin
            if (sync_cnt_value > min)			sync_cnt_value = sync_cnt_value - 1;		// Счет
            else if (sync_cnt_value <= min)	sync_cnt_value = max;				// Достигли минимума. Начинаем заново
          end
          else	sync_cnt_value = sync_cnt_value - 1;
       end
       else	sync_cnt_value = sync_cnt_value;
    end
  end      
end
*/

logic start_load;

always @(posedge clk_strobe or posedge rst_i)
begin
  if (rst_i)
  begin
      sync_cnt_value = 1'd0;								// Сброс
		start_load 		= 1'd1;
  end
  else  if (init_cnt & start_load)
  begin
      sync_cnt_value = init_val;						// Инициализация счетчика некоторым значением
      start_load = 1'd0;                    // Снимаем флаг начальной автозагрузки
  end
        else	begin if (en_i) begin										// Если есть разрешающий сигнал счета (enable)
          if ((up|free) & ~down )	
		      begin												// Счет вверех с автоматической загрузкой минимального значения (при free = 0)
            if (~free)    
            begin
              if (sync_cnt_value < max)	    sync_cnt_value = sync_cnt_value + 1;	// Не досчитали до конца. Счет в нормальном режиме
                	else if (sync_cnt_value >= max) 
                  if (init_cnt)  sync_cnt_value = init_val;
                  else           sync_cnt_value = min;
            end
          else	sync_cnt_value = sync_cnt_value + 1;									// Счет в режиме free тупо до COUNTER_SIZE
       end
       else if ( (down|free) & ~up )														// Счет на уменьшение
       begin
          if (~free)	
          begin
            if (sync_cnt_value > min)			sync_cnt_value = sync_cnt_value - 1;		// Счет
            else if (sync_cnt_value <= min)
              if (init_cnt)  sync_cnt_value = init_val;
              else           sync_cnt_value = max;       // Достигли минимума. Начинаем заново
          end
          else	sync_cnt_value = sync_cnt_value - 1;
       end
       else	sync_cnt_value = sync_cnt_value;
    end
  end      
end

// as max/min value reached and enabled 
// next cycle count restarts
// overflow set

assign overflow_up_set  = (sync_cnt_value == {COUNTER_SIZE{1'b1}}) & en_i;		// Переполнение по режиму "счет" -(2^32)-1
assign overflow_dwn_set = (sync_cnt_value == {COUNTER_SIZE{1'b0}}) & en_i;		// Переполнение по режиму декремент	- 0

assign overflow_set_local =  cnt_mode	?	overflow_up_set	:	overflow_dwn_set;		// Флаг переполнения

always_ff @ (posedge clk_i or posedge rst_i)
begin
	overflow_set =	overflow_set_local;
end

endmodule

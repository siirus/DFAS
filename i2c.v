`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// This module receives bytes from I2c bus, then sends it to EXTMEM
// I2C START indicates beginning of session
//	First byte contains 7 bit of I2C device's address on bus and 1 bit of R/W
// Second byte has 2 parts:
// 	[msb;lsb-1] - address of memory cell in EXTMEM,
//		[lsb]       - type of EXTMEM (mask or pattern)
// Third byte is address of cell that should be used as mask/pattern
// Fourth to seventh bytes contain "payload"
// Everything after this should be but is not yet ignored
// I2C STOP signal indicates end of session
// For each parameter (mask or pattern) separate session of following type should be established
// {START} - {DEV_SIG,R/W} - {SWITCH_TO} - {ADDR,DEST} - {BYTE} - {BYTE} - {BYTE} - {BYTE} - {STOP} 
//////////////////////////////////////////////////////////////////////////////////
module I2C_SRO(SDA, SCL, EXTMEM, READ);
	inout wire SDA;
   input wire SCL;
	output wire READ;
   output wire [0:7] EXTMEM;
	parameter dev_sig = 7'b0101110;
	reg [0:7] h_buf, outmem = 0;
	reg [0:3] bitcount = 0;
	reg [0:2] msgcount = 0;
	reg [0:2] state = 3'b100;
	reg [0:1] ack = 0;
	reg ack_flag = 0;
	reg SDA_low = 0;
	reg read = 0;
	reg CH_ST=0;
	reg [0:1]srt = 0;

task SET_STATE;
	input [0:2] next_state;
	case(next_state)
		2'b10: state = 3'b100; //STOP  = 100
		2'b01: state = 3'b010; //START = 010
		2'b00: state = 3'b001; //MATCH = 001
	endcase;
endtask;

always @(negedge SCL)
	if(ack_flag)
		begin
			ack[0]=0;
			SDA_low = 1;
			ack[0]=1;
		end
	else
		SDA_low = 0;
		
always @(ack[0] or ack[1])
if((ack[0]) || (ack[1]))
		ack_flag = ~ ack_flag;

always@(posedge SCL)
begin
	if(state ^ 3'b100)// NOT STOP
		begin
			if(bitcount ^ 4'b1000)
				begin
					bitcount <= bitcount +1;
					h_buf[bitcount] = (SDA)? 1'b1 : 1'b0;
					if(bitcount == 4'b111) 
						begin
							msgcount = msgcount + 1;
							ack[1]=0;
							begin
								if(state == 3'b010)          //STATE==START
									begin
									if(h_buf[0:6]^dev_sig)          //to STOP;
										begin    //SET_STATE(2'b10);
											CH_ST = 0;
											srt = 2'b10;
											CH_ST = 1;
										end
									else	             //to MATCH;
										begin    //SET_STATE(2'b00);
											CH_ST = 0;
											srt = 2'b00;
											CH_ST = 1;
										end
									end
								else if(state==3'b001)       //STATE==MATCH
									begin
										outmem=h_buf;
										get_it;
										get_it;
									end
		
								if(msgcount == 3'b111) //to stop
									begin      //SET_STATE(2'b10);
										CH_ST = 0;
										srt = 2'b10;
										CH_ST = 1;
									end
							end
							ack[1]=1;//ACK;
						end
				end
			else bitcount <= 4'b0; 
		end
	else msgcount = 3'b0;
end
	
always @(SDA or CH_ST)
begin
	if(SCL)
		if(~SDA) 
			SET_STATE(2'b01);//start
		else 
			SET_STATE(2'b10);//stop
	if(CH_ST)
			SET_STATE(srt);
end
			

task get_it;
	read = ~read;
endtask;

assign READ   = read;	
assign EXTMEM = outmem;
assign SDA = (SDA_low) ? 1'b0 : 1'bz ;
endmodule

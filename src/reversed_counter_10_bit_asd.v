/*
 * This file was generated by the scsynth tool, and is availablefor use under
 * the MIT license. More information can be found at
 * https://github.com/arminalaghi/scsynth/
 */
module reversed_counter_10_bit_asd(//10 bit counter
	output [9:0] out,
	input enable, //When on, new state every clock cycle
	input restart, //Restart the LFSR at its seed state

	input reset,
	input clk
);
	reg [9:0] value;
	always @(posedge clk or posedge reset) begin
		if (reset) value <= 0;
		else if (restart) value <= 0;
		else if (enable) value = value + 1;
	end
	genvar i;
	generate
		for (i=0; i<10; i=i+1) assign out[i] = value[9-i];
	endgenerate
endmodule

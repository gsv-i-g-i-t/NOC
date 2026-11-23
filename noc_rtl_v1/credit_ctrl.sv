

module credit_ctrl
  import noc_pkg::*;
#(
  parameter int BUF_DEPTH = noc_pkg::BUF_DEPTH
) (
  input  logic clk,
  input  logic rst_n,

  input  logic                consume_valid [NUM_PORTS],
  input  logic [VC_ID_W-1:0]  consume_vc    [NUM_PORTS],

  input  logic                credit_in_valid [NUM_PORTS],
  input  logic [VC_ID_W-1:0]  credit_in_vc    [NUM_PORTS],

  output logic credit_avail [NUM_PORTS][VC_PER_VN]
);

  localparam int CNT_W = $clog2(BUF_DEPTH + 1);

  logic [CNT_W-1:0] cnt_q [NUM_PORTS][VC_PER_VN];

  always_comb begin
    for (int p = 0; p < NUM_PORTS; p++)
      for (int v = 0; v < VC_PER_VN; v++)
        credit_avail[p][v] = (cnt_q[p][v] != '0);
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int p = 0; p < NUM_PORTS; p++)
        for (int v = 0; v < VC_PER_VN; v++)
          cnt_q[p][v] <= CNT_W'(BUF_DEPTH);
    end else begin
      for (int p = 0; p < NUM_PORTS; p++) begin
        for (int v = 0; v < VC_PER_VN; v++) begin
          automatic logic do_inc, do_dec;
          do_inc = credit_in_valid[p] && (credit_in_vc[p] == VC_ID_W'(v));
          do_dec = consume_valid[p]   && (consume_vc[p]   == VC_ID_W'(v));
          unique case ({do_inc, do_dec})
            2'b10:   cnt_q[p][v] <= cnt_q[p][v] + 1'b1;
            2'b01:   cnt_q[p][v] <= cnt_q[p][v] - 1'b1;
            default: ;
          endcase
        end
      end
    end
  end

endmodule : credit_ctrl

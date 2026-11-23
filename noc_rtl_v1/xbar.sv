

module xbar
  import noc_pkg::*;
(
  input  flit_t              head_flit    [NUM_PORTS][VC_PER_VN],
  input  logic [VC_ID_W-1:0] alloc_out_vc [NUM_PORTS][VC_PER_VN],

  input  logic               xbar_valid       [NUM_PORTS],
  input  port_e               xbar_sel_in_port [NUM_PORTS],
  input  logic [VC_ID_W-1:0]  xbar_sel_in_vc   [NUM_PORTS],

  output logic  out_valid [NUM_PORTS],
  output flit_t out_flit  [NUM_PORTS]
);

  always_comb begin
    for (int op = 0; op < NUM_PORTS; op++) begin
      automatic int ip, v;
      ip = int'(xbar_sel_in_port[op]);
      v  = int'(xbar_sel_in_vc[op]);

      out_valid[op]         = xbar_valid[op];
      out_flit[op]          = head_flit[ip][v];
      out_flit[op].vc_id    = alloc_out_vc[ip][v];
    end
  end

endmodule : xbar



module sw_allocator
  import noc_pkg::*;
(
  input  logic  clk,
  input  logic  rst_n,

  input  logic  want_sa          [NUM_PORTS][VC_PER_VN],
  input  port_e granted_out_port [NUM_PORTS][VC_PER_VN],

  output logic  sa_grant [NUM_PORTS][VC_PER_VN],

  output logic               xbar_valid       [NUM_PORTS],
  output port_e              xbar_sel_in_port [NUM_PORTS],
  output logic [VC_ID_W-1:0] xbar_sel_in_vc   [NUM_PORTS]
);

  localparam int IPTR_W = (VC_PER_VN > 1) ? $clog2(VC_PER_VN) : 1;
  localparam int OPTR_W = $clog2(NUM_PORTS);

  logic [IPTR_W-1:0] rr_i_ptr_q [NUM_PORTS];
  logic [OPTR_W-1:0] rr_o_ptr_q [NUM_PORTS];

  logic              sai_valid [NUM_PORTS];
  logic [IPTR_W-1:0] sai_vc    [NUM_PORTS];
  port_e             sai_port  [NUM_PORTS];

  logic [VC_PER_VN-1:0] sai_req    [NUM_PORTS];
  logic [VC_PER_VN-1:0] sai_onehot [NUM_PORTS];

  for (genvar ip = 0; ip < NUM_PORTS; ip++) begin : g_sai
    rr_arbiter #(.N(VC_PER_VN)) u_sai_rr (
      .req   (sai_req[ip]),
      .ptr   (rr_i_ptr_q[ip]),
      .grant (sai_onehot[ip])
    );
  end

  logic [NUM_PORTS-1:0] sao_req    [NUM_PORTS];
  logic [NUM_PORTS-1:0] sao_onehot [NUM_PORTS];

  for (genvar op = 0; op < NUM_PORTS; op++) begin : g_sao
    rr_arbiter #(.N(NUM_PORTS)) u_sao_rr (
      .req   (sao_req[op]),
      .ptr   (rr_o_ptr_q[op]),
      .grant (sao_onehot[op])
    );
  end

  always_comb
    for (int ip = 0; ip < NUM_PORTS; ip++)
      for (int v = 0; v < VC_PER_VN; v++)
        sai_req[ip][v] = want_sa[ip][v];

  always_comb
    for (int ip = 0; ip < NUM_PORTS; ip++) begin
      sai_valid[ip] = |sai_req[ip];
      sai_vc[ip]    = '0;
      sai_port[ip]  = PORT_L;
      for (int v = 0; v < VC_PER_VN; v++) begin
        if (sai_onehot[ip][v]) begin
          sai_vc[ip]   = IPTR_W'(v);
          sai_port[ip] = granted_out_port[ip][v];
        end
      end
    end

  always_comb
    for (int op = 0; op < NUM_PORTS; op++)
      for (int ip = 0; ip < NUM_PORTS; ip++)
        sao_req[op][ip] = sai_valid[ip] && (sai_port[ip] == port_e'(op));

  always_comb begin
    for (int ip = 0; ip < NUM_PORTS; ip++)
      for (int v = 0; v < VC_PER_VN; v++)
        sa_grant[ip][v] = 1'b0;

    for (int op = 0; op < NUM_PORTS; op++) begin
      xbar_valid[op]       = 1'b0;
      xbar_sel_in_port[op] = port_e'(op);
      xbar_sel_in_vc[op]   = '0;
      for (int ip = 0; ip < NUM_PORTS; ip++) begin
        if (sao_onehot[op][ip]) begin
          xbar_valid[op]                  = 1'b1;
          xbar_sel_in_port[op]            = port_e'(ip);
          xbar_sel_in_vc[op]              = VC_ID_W'(sai_vc[ip]);
          sa_grant[ip][int'(sai_vc[ip])]  = 1'b1;
        end
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int ip = 0; ip < NUM_PORTS; ip++) begin
        rr_i_ptr_q[ip] <= '0;
        rr_o_ptr_q[ip] <= '0;
      end
    end else begin
      for (int ip = 0; ip < NUM_PORTS; ip++)
        if (sai_valid[ip] && sa_grant[ip][int'(sai_vc[ip])])
          rr_i_ptr_q[ip] <= IPTR_W'((int'(sai_vc[ip]) + 1) % VC_PER_VN);

      for (int op = 0; op < NUM_PORTS; op++)
        if (xbar_valid[op])
          rr_o_ptr_q[op] <= OPTR_W'((int'(xbar_sel_in_port[op]) + 1) % NUM_PORTS);
    end
  end

endmodule : sw_allocator



module vc_allocator
  import noc_pkg::*;
#(
  parameter int REQ_COUNT = NUM_PORTS * VC_PER_VN
) (
  input  logic     clk,
  input  logic     rst_n,

  input  logic     want_va     [REQ_COUNT],
  input  port_e    routed_port [REQ_COUNT],

  output logic                va_grant    [REQ_COUNT],
  output logic [VC_ID_W-1:0]  va_grant_vc [REQ_COUNT],

  input  logic                release_valid [NUM_PORTS],
  input  logic [VC_ID_W-1:0]  release_vc    [NUM_PORTS]
);

  localparam int RPTR_W = (REQ_COUNT > 1) ? $clog2(REQ_COUNT) : 1;

  logic              busy_q   [NUM_PORTS][VC_PER_VN];
  logic [RPTR_W-1:0] rr_ptr_q [NUM_PORTS];

  logic [REQ_COUNT-1:0] req_bits    [NUM_PORTS];
  logic [REQ_COUNT-1:0] win0_onehot [NUM_PORTS];
  logic [REQ_COUNT-1:0] win1_onehot [NUM_PORTS];

  for (genvar op = 0; op < NUM_PORTS; op++) begin : g_op
    rr_arbiter #(.N(REQ_COUNT)) u_rr0 (
      .req   (req_bits[op]),
      .ptr   (rr_ptr_q[op]),
      .grant (win0_onehot[op])
    );
    rr_arbiter #(.N(REQ_COUNT)) u_rr1 (
      .req   (req_bits[op] & ~win0_onehot[op]),
      .ptr   (rr_ptr_q[op]),
      .grant (win1_onehot[op])
    );
  end

  always_comb begin
    for (int op = 0; op < NUM_PORTS; op++)
      for (int i = 0; i < REQ_COUNT; i++)
        req_bits[op][i] = want_va[i] && (routed_port[i] == port_e'(op));

    for (int i = 0; i < REQ_COUNT; i++) begin
      va_grant[i]    = 1'b0;
      va_grant_vc[i] = '0;
    end

    for (int op = 0; op < NUM_PORTS; op++) begin
      automatic int free_vc [VC_PER_VN];
      automatic int nfree;
      nfree = 0;
      for (int v = 0; v < VC_PER_VN; v++) begin
        if (!busy_q[op][v]) begin
          free_vc[nfree] = v;
          nfree++;
        end
      end

      if (nfree >= 1 && (win0_onehot[op] != '0)) begin
        for (int i = 0; i < REQ_COUNT; i++) begin
          if (win0_onehot[op][i]) begin
            va_grant[i]    = 1'b1;
            va_grant_vc[i] = VC_ID_W'(free_vc[0]);
          end
        end
      end

      if (nfree >= 2 && (win1_onehot[op] != '0)) begin
        for (int i = 0; i < REQ_COUNT; i++) begin
          if (win1_onehot[op][i]) begin
            va_grant[i]    = 1'b1;
            va_grant_vc[i] = VC_ID_W'(free_vc[1]);
          end
        end
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int op = 0; op < NUM_PORTS; op++) begin
        rr_ptr_q[op] <= '0;
        for (int v = 0; v < VC_PER_VN; v++) busy_q[op][v] <= 1'b0;
      end
    end else begin
      for (int op = 0; op < NUM_PORTS; op++) begin

        for (int v = 0; v < VC_PER_VN; v++) begin
          automatic logic set_bit, clr_bit;
          set_bit = 1'b0;
          clr_bit = release_valid[op] && (release_vc[op] == VC_ID_W'(v));
          for (int i = 0; i < REQ_COUNT; i++) begin
            if (va_grant[i] && (routed_port[i] == port_e'(op)) && (va_grant_vc[i] == VC_ID_W'(v)))
              set_bit = 1'b1;
          end
          if (set_bit)      busy_q[op][v] <= 1'b1;
          else if (clr_bit) busy_q[op][v] <= 1'b0;
        end

        begin
          automatic logic [REQ_COUNT-1:0] winner;
          automatic logic [RPTR_W-1:0]    widx;
          winner = (win1_onehot[op] != '0) ? win1_onehot[op] : win0_onehot[op];
          widx   = '0;
          for (int i = 0; i < REQ_COUNT; i++)
            if (winner[i]) widx = widx | RPTR_W'(i);
          if (winner != '0)
            rr_ptr_q[op] <= RPTR_W'((int'(widx) + 1) % REQ_COUNT);
        end
      end
    end
  end

endmodule : vc_allocator

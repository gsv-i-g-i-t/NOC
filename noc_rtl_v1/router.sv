

module router
  import noc_pkg::*;
#(
  parameter int BUF_DEPTH = noc_pkg::BUF_DEPTH
) (
  input  logic          clk,
  input  logic          rst_n,
  input  coord_t         my_coord,

  input  link_fwd_t     link_in         [NUM_VN][NUM_PORTS],

  output link_credit_t  link_credit_out [NUM_VN][NUM_PORTS],

  output link_fwd_t     link_out        [NUM_VN][NUM_PORTS],

  input  link_credit_t  link_credit_in  [NUM_VN][NUM_PORTS]
);

  localparam int REQ_COUNT = NUM_PORTS * VC_PER_VN;

  genvar gvn, gp, gv;
  generate
    for (gvn = 0; gvn < NUM_VN; gvn++) begin : g_vn

      logic               ivu_have_head        [NUM_PORTS][VC_PER_VN];
      flit_t              ivu_head_flit        [NUM_PORTS][VC_PER_VN];
      logic               ivu_want_va          [NUM_PORTS][VC_PER_VN];
      port_e              ivu_routed_port      [NUM_PORTS][VC_PER_VN];
      logic               ivu_want_sa          [NUM_PORTS][VC_PER_VN];
      logic [VC_ID_W-1:0] ivu_alloc_out_vc     [NUM_PORTS][VC_PER_VN];
      logic               ivu_credit_ret_valid [NUM_PORTS][VC_PER_VN];
      logic [VC_ID_W-1:0] ivu_credit_ret_vc    [NUM_PORTS][VC_PER_VN];

      logic               va_want_flat     [REQ_COUNT];
      port_e              va_port_flat     [REQ_COUNT];
      logic               va_grant_flat    [REQ_COUNT];
      logic [VC_ID_W-1:0] va_grant_vc_flat [REQ_COUNT];

      logic               sa_want_gated [NUM_PORTS][VC_PER_VN];
      logic               sa_grant      [NUM_PORTS][VC_PER_VN];

      logic               xbar_valid       [NUM_PORTS];
      port_e              xbar_sel_in_port [NUM_PORTS];
      logic [VC_ID_W-1:0] xbar_sel_in_vc   [NUM_PORTS];
      logic               xbar_out_valid   [NUM_PORTS];
      flit_t              xbar_out_flit    [NUM_PORTS];

      logic               cc_consume_valid   [NUM_PORTS];
      logic [VC_ID_W-1:0] cc_consume_vc      [NUM_PORTS];
      logic               cc_credit_in_valid [NUM_PORTS];
      logic [VC_ID_W-1:0] cc_credit_in_vc    [NUM_PORTS];
      logic               cc_credit_avail    [NUM_PORTS][VC_PER_VN];

      logic               va_release_valid [NUM_PORTS];
      logic [VC_ID_W-1:0] va_release_vc    [NUM_PORTS];

      for (gp = 0; gp < NUM_PORTS; gp++) begin : g_port
        for (gv = 0; gv < VC_PER_VN; gv++) begin : g_vc
          localparam int FLAT_IDX = gp * VC_PER_VN + gv;

          input_vc_unit #(
            .VC_IDX    (gv),
            .BUF_DEPTH (BUF_DEPTH)
          ) u_ivu (
            .clk        (clk),
            .rst_n      (rst_n),
            .my_coord   (my_coord),
            .push_en    (link_in[gvn][gp].valid && (link_in[gvn][gp].flit.vc_id == VC_ID_W'(gv))),
            .push_flit  (link_in[gvn][gp].flit),
            .have_head  (ivu_have_head[gp][gv]),
            .head_flit  (ivu_head_flit[gp][gv]),
            .want_va    (ivu_want_va[gp][gv]),
            .routed_port(ivu_routed_port[gp][gv]),
            .want_sa    (ivu_want_sa[gp][gv]),
            .va_grant    (va_grant_flat[FLAT_IDX]),
            .va_grant_vc (va_grant_vc_flat[FLAT_IDX]),
            .sa_grant    (sa_grant[gp][gv]),
            .alloc_out_vc(ivu_alloc_out_vc[gp][gv]),
            .credit_ret_valid(ivu_credit_ret_valid[gp][gv]),
            .credit_ret_vc   (ivu_credit_ret_vc[gp][gv])
          );

          assign va_want_flat[FLAT_IDX] = ivu_want_va[gp][gv];
          assign va_port_flat[FLAT_IDX] = ivu_routed_port[gp][gv];

          assign sa_want_gated[gp][gv] = ivu_want_sa[gp][gv] &&
              cc_credit_avail[int'(ivu_routed_port[gp][gv])][ivu_alloc_out_vc[gp][gv]];
        end
      end

      vc_allocator #(.REQ_COUNT(REQ_COUNT)) u_va (
        .clk           (clk),
        .rst_n         (rst_n),
        .want_va       (va_want_flat),
        .routed_port   (va_port_flat),
        .va_grant      (va_grant_flat),
        .va_grant_vc   (va_grant_vc_flat),
        .release_valid (va_release_valid),
        .release_vc    (va_release_vc)
      );

      sw_allocator u_sa (
        .clk              (clk),
        .rst_n            (rst_n),
        .want_sa          (sa_want_gated),
        .granted_out_port (ivu_routed_port),
        .sa_grant         (sa_grant),
        .xbar_valid       (xbar_valid),
        .xbar_sel_in_port (xbar_sel_in_port),
        .xbar_sel_in_vc   (xbar_sel_in_vc)
      );

      xbar u_xbar (
        .head_flit       (ivu_head_flit),
        .alloc_out_vc    (ivu_alloc_out_vc),
        .xbar_valid      (xbar_valid),
        .xbar_sel_in_port(xbar_sel_in_port),
        .xbar_sel_in_vc  (xbar_sel_in_vc),
        .out_valid       (xbar_out_valid),
        .out_flit        (xbar_out_flit)
      );

      credit_ctrl #(.BUF_DEPTH(BUF_DEPTH)) u_cc (
        .clk             (clk),
        .rst_n           (rst_n),
        .consume_valid   (cc_consume_valid),
        .consume_vc      (cc_consume_vc),
        .credit_in_valid (cc_credit_in_valid),
        .credit_in_vc    (cc_credit_in_vc),
        .credit_avail    (cc_credit_avail)
      );

      for (gp = 0; gp < NUM_PORTS; gp++) begin : g_outport
        assign cc_consume_valid[gp]   = xbar_out_valid[gp];
        assign cc_consume_vc[gp]      = xbar_out_flit[gp].vc_id;
        assign cc_credit_in_valid[gp] = link_credit_in[gvn][gp].valid;
        assign cc_credit_in_vc[gp]    = link_credit_in[gvn][gp].vc_id;

        assign va_release_valid[gp] = xbar_out_valid[gp] &&
            ((xbar_out_flit[gp].ftype == FLIT_TAIL) || (xbar_out_flit[gp].ftype == FLIT_HEADTAIL));
        assign va_release_vc[gp] = xbar_out_flit[gp].vc_id;

        assign link_out[gvn][gp].valid = xbar_out_valid[gp];
        assign link_out[gvn][gp].flit  = xbar_out_flit[gp];

        assign link_credit_out[gvn][gp].valid =
            ivu_credit_ret_valid[gp][0] | ivu_credit_ret_valid[gp][1];
        assign link_credit_out[gvn][gp].vc_id =
            ivu_credit_ret_valid[gp][0] ? VC_ID_W'(0) : VC_ID_W'(1);
      end

    end
  endgenerate

endmodule : router

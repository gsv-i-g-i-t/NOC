

module input_vc_unit
  import noc_pkg::*;
#(
  parameter int VC_IDX    = 0,
  parameter int BUF_DEPTH = noc_pkg::BUF_DEPTH
) (
  input  logic     clk,
  input  logic     rst_n,
  input  coord_t   my_coord,

  input  logic     push_en,
  input  flit_t    push_flit,

  output logic     have_head,
  output flit_t    head_flit,
  output logic     want_va,
  output port_e    routed_port,
  output logic     want_sa,

  input  logic                va_grant,
  input  logic [VC_ID_W-1:0]  va_grant_vc,
  input  logic                sa_grant,

  output logic [VC_ID_W-1:0]  alloc_out_vc,

  output logic                credit_ret_valid,
  output logic [VC_ID_W-1:0]  credit_ret_vc
);

  localparam int PTR_W = (BUF_DEPTH > 1) ? $clog2(BUF_DEPTH) : 1;
  localparam int CNT_W = $clog2(BUF_DEPTH + 1);

  flit_t                mem [BUF_DEPTH];
  logic [PTR_W-1:0]      wr_ptr_q, rd_ptr_q;
  logic [CNT_W-1:0]      count_q;

  logic buf_empty;
  assign buf_empty = (count_q == '0);
  assign have_head = ~buf_empty;
  assign head_flit  = mem[rd_ptr_q];

  typedef enum logic { S_ALLOC, S_ACTIVE } state_e;
  state_e              state_q;
  logic [VC_ID_W-1:0]  alloc_out_vc_q;

  port_e rc_port;
  route_compute u_rc (
    .my_coord   (my_coord),
    .dest_coord ('{x: head_flit.dest_x, y: head_flit.dest_y}),
    .out_port   (rc_port)
  );

  assign want_va     = have_head && (state_q == S_ALLOC);
  assign routed_port = rc_port;
  assign want_sa      = have_head && (state_q == S_ACTIVE);
  assign alloc_out_vc  = alloc_out_vc_q;

  logic pop_en;
  assign pop_en = sa_grant;

  assign credit_ret_vc = VC_ID_W'(VC_IDX);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_ptr_q         <= '0;
      rd_ptr_q         <= '0;
      count_q          <= '0;
      state_q          <= S_ALLOC;
      alloc_out_vc_q   <= '0;
      credit_ret_valid <= 1'b0;
    end else begin
      credit_ret_valid <= 1'b0;

      if (push_en) begin
        mem[wr_ptr_q] <= push_flit;
        wr_ptr_q      <= wr_ptr_q + 1'b1;
      end

      if (pop_en) begin
        rd_ptr_q         <= rd_ptr_q + 1'b1;
        credit_ret_valid <= 1'b1;
      end

      unique case ({push_en, pop_en})
        2'b10:   count_q <= count_q + 1'b1;
        2'b01:   count_q <= count_q - 1'b1;
        default: ;
      endcase

      unique case (state_q)
        S_ALLOC: begin
          if (want_va && va_grant) begin
            alloc_out_vc_q <= va_grant_vc;
            state_q        <= S_ACTIVE;
          end
        end
        S_ACTIVE: begin
          if (pop_en && (head_flit.ftype == FLIT_TAIL || head_flit.ftype == FLIT_HEADTAIL)) begin
            state_q <= S_ALLOC;
          end
        end
        default: state_q <= S_ALLOC;
      endcase
    end
  end

endmodule : input_vc_unit

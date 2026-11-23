

module rr_arbiter #(
  parameter int N     = 4,
  parameter int PTR_W = (N > 1) ? $clog2(N) : 1
) (
  input  logic [N-1:0]     req,
  input  logic [PTR_W-1:0] ptr,
  output logic [N-1:0]     grant
);

  logic [N-1:0] mask;
  logic [N-1:0] masked_req;
  logic [N-1:0] masked_grant;
  logic [N-1:0] unmasked_grant;

  assign mask = N'(-1) << ptr;

  assign masked_req = req & mask;

  assign masked_grant   = masked_req & (-masked_req);
  assign unmasked_grant = req        & (-req);

  assign grant = (masked_req != '0) ? masked_grant : unmasked_grant;

endmodule : rr_arbiter


package noc_pkg;

  localparam int MESH_X = 4;
  localparam int MESH_Y = 4;
  localparam int X_BITS = $clog2(MESH_X);
  localparam int Y_BITS = $clog2(MESH_Y);

  typedef struct packed {
    logic [X_BITS-1:0] x;
    logic [Y_BITS-1:0] y;
  } coord_t;

  localparam int NUM_PORTS = 5;
  typedef enum logic [2:0] {
    PORT_N = 3'd0,
    PORT_S = 3'd1,
    PORT_E = 3'd2,
    PORT_W = 3'd3,
    PORT_L = 3'd4
  } port_e;

  localparam int NUM_VN = 2;
  typedef enum logic {
    VN_REQ = 1'b0,
    VN_RSP = 1'b1
  } vn_e;

  localparam int VC_PER_VN = 2;
  localparam int VC_ID_W   = (VC_PER_VN > 1) ? $clog2(VC_PER_VN) : 1;
  localparam int BUF_DEPTH = 8;

  localparam int FLIT_PAYLOAD_W = 128;

  typedef enum logic [1:0] {
    FLIT_HEADTAIL = 2'd0,
    FLIT_HEAD     = 2'd1,
    FLIT_BODY     = 2'd2,
    FLIT_TAIL     = 2'd3
  } flit_type_e;

  typedef struct packed {
    flit_type_e            ftype;
    logic [X_BITS-1:0]      dest_x;
    logic [Y_BITS-1:0]      dest_y;
    logic [VC_ID_W-1:0]     vc_id;
    logic [FLIT_PAYLOAD_W-1:0] payload;
  } flit_t;

  typedef struct packed {
    logic  valid;
    flit_t flit;
  } link_fwd_t;

  typedef struct packed {
    logic               valid;
    logic [VC_ID_W-1:0] vc_id;
  } link_credit_t;

endpackage : noc_pkg

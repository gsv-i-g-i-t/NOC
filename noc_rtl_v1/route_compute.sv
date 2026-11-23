

module route_compute
  import noc_pkg::*;
(
  input  coord_t my_coord,
  input  coord_t dest_coord,
  output port_e  out_port
);

  always_comb begin
    if (dest_coord.x != my_coord.x)
      out_port = (dest_coord.x > my_coord.x) ? PORT_E : PORT_W;
    else if (dest_coord.y != my_coord.y)
      out_port = (dest_coord.y > my_coord.y) ? PORT_S : PORT_N;
    else
      out_port = PORT_L;
  end

endmodule : route_compute


`timescale 1ns / 10ps
`default_nettype none

module dumbrv_core (
  input         clk,
  input         rst_n,
  // instruction SPI
  output        spi_inst_mosi,
  input         spi_inst_miso,
  output        spi_inst_cs,
  output        spi_inst_sck,
  // data SPI
  output        spi_data_mosi,
  input         spi_data_miso,
  output        spi_data_cs,
  output        spi_data_sck,
  // gpio
  input  [ 7:0] gpio_i,
  output [ 7:0] gpio_o
  );

  // global resteer mechanism
  wire        resteer_en;
  wire [15:1] resteer_addr;

  // fetch to execute instruction pipe
  wire [ 1:0] f2e_size;
  wire [31:0] f2e_inst;
  wire [15:1] f2e_addr;
  wire        f2e_use;
  wire        f2e_use_half;

  // execute submit work to lsu
  wire        e2m_valid;
  wire [ 3:0] e2m_opcode;
  wire [31:0] e2m_addr;
  wire [31:0] e2m_data;
  wire [ 3:0] e2m_dreg;
  wire        e2m_accept;

  // lsu write back to registers in execute
  wire [ 3:0] m2e_dreg;
  wire [31:0] m2e_data;
  wire        m2e_done;
  wire [ 3:0] m2e_pending_dreg;

  // lsu read instruction memory
  wire        m2f_en;
  wire [15:0] m2f_addr;
  wire [ 2:0] m2f_size;
  wire [31:0] m2f_data;
  wire        m2f_done;

  wire        m2g_en;
  wire        m2g_wr;
  wire [15:0] m2g_addr;
  wire [ 2:0] m2g_size;
  wire [31:0] m2g_rd_data;
  wire [31:0] m2g_wr_data;
  wire        m2g_done;

  dumbrv_fetch fetch (
    .clk             ( clk                ),
    .rst_n           ( rst_n              ),
    // instruction SPI
    .spi_inst_mosi   ( spi_inst_mosi      ),
    .spi_inst_miso   ( spi_inst_miso      ),
    .spi_inst_cs     ( spi_inst_cs        ),
    .spi_inst_sck    ( spi_inst_sck       ),
    // read instruction memory to LSU
    .rd_en_i         ( m2f_en             ),
    .rd_addr_i       ( m2f_addr           ),
    .rd_size_i       ( m2f_size           ),
    .rd_data_o       ( m2f_data           ),
    .rd_done_o       ( m2f_done           ),
    // resteer control
    .resteer_en_i    ( resteer_en         ),
    .resteer_addr_i  ( resteer_addr       ),
    // instruction output
    .inst_size_o     ( f2e_size           ),
    .inst_o          ( f2e_inst           ),
    .inst_addr_o     ( f2e_addr           ),
    .inst_use_i      ( f2e_use            ),
    .inst_use_half_i ( f2e_use_half       )
  );

  dumbrv_work work (
    .clk             ( clk                ),
    .rst_n           ( rst_n              ),
    // inst input
    .inst_size_i     ( f2e_size           ),
    .inst_i          ( f2e_inst           ),
    .inst_addr_i     ( f2e_addr           ),
    .inst_use_o      ( f2e_use            ),
    .inst_use_half_o ( f2e_use_half       ),
    // resteer control
    .resteer_en_o    ( resteer_en         ),
    .resteer_addr_o  ( resteer_addr       ),
    // work submission to LSU
    .lsu_valid_o     ( e2m_valid          ),
    .lsu_opcode_o    ( e2m_opcode         ),
    .lsu_addr_o      ( e2m_addr           ),
    .lsu_data_o      ( e2m_data           ),
    .lsu_dreg_o      ( e2m_dreg           ),
    .lsu_accept_i    ( e2m_accept         ),
    // write back from LSU
    .lsu_wb_dreg_i   ( m2e_dreg           ),
    .lsu_wb_data_i   ( m2e_data           ),
    .lsu_wb_done_o   ( m2e_done           ),
    .lsu_load_dreg   ( m2e_pending_dreg   )
  );

  dumbrv_lsu lsu (
    .clk             ( clk                ),
    .rst_n           ( rst_n              ),
    // data SPI
    .spi_data_mosi   ( spi_data_mosi      ),
    .spi_data_miso   ( spi_data_miso      ),
    .spi_data_cs     ( spi_data_cs        ),
    .spi_data_sck    ( spi_data_sck       ),
    // work from execute
    .valid_i         ( e2m_valid          ),
    .opcode_i        ( e2m_opcode         ),
    .addr_i          ( e2m_addr           ),
    .data_i          ( e2m_data           ),
    .dreg_i          ( e2m_dreg           ),
    .accept_o        ( e2m_accept         ),
    // write back
    .wb_dreg_o       ( m2e_dreg           ),
    .wb_data_o       ( m2e_data           ),
    .wb_done_i       ( m2e_done           ),
    .pending_dreg    ( m2e_pending_dreg   ),
    // instruction memory read
    .imem_en_o       ( m2f_en             ),
    .imem_addr_o     ( m2f_addr           ),
    .imem_size_o     ( m2f_size           ),
    .imem_data_i     ( m2f_data           ),
    .imem_done_i     ( m2f_done           ),
    // stray memory operations
    .stray_en_o      ( m2g_en             ),
    .stray_wr_o      ( m2g_wr             ),
    .stray_addr_o    ( m2g_addr           ),
    .stray_size_o    ( m2g_size           ),
    .stray_data_o    ( m2g_rd_data        ),
    .stray_data_i    ( m2g_wr_data        ),
    .stray_done_i    ( m2g_done           )
  );

  dumbrv_gpio gpio (
    .clk             ( clk                ),
    .rst_n           ( rst_n              ),
    // stray memory requests
    .stray_en_i      ( m2g_en             ),
    .stray_wr_i      ( m2g_wr             ),
    .stray_addr_i    ( m2g_addr           ),
    .stray_size_i    ( m2g_size           ),
    .stray_data_i    ( m2g_rd_data        ),
    .stray_data_o    ( m2g_wr_data        ),
    .stray_done_o    ( m2g_done           ),
    // gpio
    .gpio_i          ( gpio_i             ),
    .gpio_o          ( gpio_o             )
  );

endmodule

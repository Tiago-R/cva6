// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Author: Michael Schaffner <schaffner@iis.ee.ethz.ch>, ETH Zurich
// Date: 19.03.2017
// Description: Ariane Top-level wrapper to break out SV structs to logic vectors.


module ariane_verilog_wrap
    import ariane_pkg::*;
#(
  parameter int unsigned               RASDepth              = 2,
  parameter int unsigned               BTBEntries            = 32,
  parameter int unsigned               BHTEntries            = 128,
  // debug module base address
  parameter logic [63:0]               DmBaseAddress         = 64'h0,
  // swap endianess in l15 adapter
  parameter bit                        SwapEndianess         = 1,
  // PMA configuration
  // idempotent region
  parameter int unsigned               NrNonIdempotentRules  =  1,
  parameter logic [config_pkg::NrMaxRules*64-1:0]  NonIdempotentAddrBase = 64'h00C0000000,
  parameter logic [config_pkg::NrMaxRules*64-1:0]  NonIdempotentLength   = 64'hFFFFFFFFFF,
  // executable regions
  parameter int unsigned               NrExecuteRegionRules  =  0,
  parameter logic [config_pkg::NrMaxRules*64-1:0]  ExecuteRegionAddrBase = '0,
  parameter logic [config_pkg::NrMaxRules*64-1:0]  ExecuteRegionLength   = '0,
  // cacheable regions
  parameter int unsigned               NrCachedRegionRules   =  0,
  parameter logic [config_pkg::NrMaxRules*64-1:0]  CachedRegionAddrBase  = '0,
  parameter logic [config_pkg::NrMaxRules*64-1:0]  CachedRegionLength    = '0,
  // PMP
  parameter int unsigned               NrPMPEntries          =  8
) (
  input                       clk_i,
  input                       reset_l,      // this is an openpiton-specific name, do not change (hier. paths in TB use this)
  output                      spc_grst_l,   // this is an openpiton-specific name, do not change (hier. paths in TB use this)
  // Core ID, Cluster ID and boot address are considered more or less static
  input  [riscv::VLEN-1:0]               boot_addr_i,  // reset boot address
  input  [riscv::XLEN-1:0]               hart_id_i,    // hart id in a multicore environment (reflected in a CSR)
  // Interrupt inputs
  input  [1:0]                irq_i,        // level sensitive IR lines, mip & sip (async)
  input                       ipi_i,        // inter-processor interrupts (async)
  // Timer facilities
  input                       time_irq_i,   // timer interrupt in (async)
  input                       debug_req_i,  // debug request (async)

  // L15 (memory side)
  output [$size(l15_req_t)-1:0]  l15_req_o,
  input  [$size(l15_rtrn_t)-1:0] l15_rtrn_i
 );

  localparam type l15_req_t = struct packed {
    logic l15_val;  // valid signal, asserted with request
    logic l15_req_ack;  // ack for response
    wt_cache_pkg::l15_reqtypes_t l15_rqtype;  // see below for encoding
    logic l15_nc;  // non-cacheable bit
    logic [2:0]                        l15_size;                  // transaction size: 000=Byte 001=2Byte; 010=4Byte; 011=8Byte; 111=Cache line (16/32Byte)
    logic [CVA6Cfg.MEM_TID_WIDTH-1:0] l15_threadid;  // currently 0 or 1
    logic l15_prefetch;  // unused in openpiton
    logic l15_invalidate_cacheline;  // unused by Ariane as L1 has no ECC at the moment
    logic l15_blockstore;  // unused in openpiton
    logic l15_blockinitstore;  // unused in openpiton
    logic [CVA6Cfg.DCACHE_SET_ASSOC_WIDTH-1:0] l15_l1rplway;  // way to replace
    logic [39:0] l15_address;  // physical address
    logic [63:0] l15_data;  // word to write
    logic [63:0] l15_data_next_entry;  // unused in Ariane (only used for CAS atomic requests)
    logic [wt_cache_pkg::L15_TLB_CSM_WIDTH-1:0] l15_csm_data;  // unused in Ariane
    logic [3:0] l15_amo_op;  // atomic operation type
  };
  localparam type l15_rtrn_t = struct packed {
    logic l15_ack;  // ack for request struct
    logic l15_header_ack;  // ack for request struct
    logic l15_val;  // valid signal for return struct
    wt_l15_adapter::l15_rtrntypes_t l15_returntype;  // see below for encoding
    logic l15_l2miss;  // unused in Ariane
    logic [1:0] l15_error;  // unused in openpiton
    logic l15_noncacheable;  // non-cacheable bit
    logic l15_atomic;  // asserted in load return and store ack packets of atomic tx
    logic [CVA6Cfg.MEM_TID_WIDTH-1:0] l15_threadid;  // used as transaction ID
    logic l15_prefetch;  // unused in openpiton
    logic l15_f4b;  // 4byte instruction fill from I/O space (nc).
    logic [63:0] l15_data_0;  // used for both caches
    logic [63:0] l15_data_1;  // used for both caches
    logic [63:0] l15_data_2;  // currently only used for I$
    logic [63:0] l15_data_3;  // currently only used for I$
    logic l15_inval_icache_all_way;  // invalidate all ways
    logic l15_inval_dcache_all_way;  // unused in openpiton
    logic [15:4] l15_inval_address_15_4;  // invalidate selected cacheline
    logic l15_cross_invalidate;  // unused in openpiton
    logic [CVA6Cfg.DCACHE_SET_ASSOC_WIDTH-1:0] l15_cross_invalidate_way;  // unused in openpiton
    logic l15_inval_dcache_inval;  // invalidate selected cacheline and way
    logic l15_inval_icache_inval;  // unused in openpiton
    logic [CVA6Cfg.DCACHE_SET_ASSOC_WIDTH-1:0] l15_inval_way;  // way to invalidate
    logic l15_blockinitstore;  // unused in openpiton
  };

// assign bitvector to packed struct and vice versa
  // L15 (memory side)
  l15_req_t  l15_req;
  l15_rtrn_t l15_rtrn;

  assign l15_req_o = l15_req;
  assign l15_rtrn  = l15_rtrn_i;


  /////////////////////////////
  // Core wakeup mechanism
  /////////////////////////////

  // // this is a workaround since interrupts are not fully supported yet.
  // // the logic below catches the initial wake up interrupt that enables the cores.
  // logic wake_up_d, wake_up_q;
  // logic rst_n;

  // assign wake_up_d = wake_up_q || ((l15_rtrn.l15_returntype == wt_cache_pkg::L15_INT_RET) && l15_rtrn.l15_val);

  // always_ff @(posedge clk_i or negedge reset_l) begin : p_regs
  //   if(~reset_l) begin
  //     wake_up_q <= 0;
  //   end else begin
  //     wake_up_q <= wake_up_d;
  //   end
  // end

  // // reset gate this
  // assign rst_n = wake_up_q & reset_l;

  // this is a workaround,
  // we basically wait for 32k cycles such that the SRAMs in openpiton can initialize
  // 128KB..8K cycles
  // 256KB..16K cycles
  // etc, so this should be enough for 512k per tile

  logic [15:0] wake_up_cnt_d, wake_up_cnt_q;
  logic rst_n;

  assign wake_up_cnt_d = (wake_up_cnt_q[$high(wake_up_cnt_q)]) ? wake_up_cnt_q : wake_up_cnt_q + 1;

  always_ff @(posedge clk_i or negedge reset_l) begin : p_regs
    if(~reset_l) begin
      wake_up_cnt_q <= 0;
    end else begin
      wake_up_cnt_q <= wake_up_cnt_d;
    end
  end

  // reset gate this
  assign rst_n = wake_up_cnt_q[$high(wake_up_cnt_q)] & reset_l;


  /////////////////////////////
  // synchronizers
  /////////////////////////////

  logic [1:0] irq;
  logic ipi, time_irq, debug_req;

  // reset synchronization
  synchronizer i_sync (
    .clk         ( clk_i      ),
    .presyncdata ( rst_n      ),
    .syncdata    ( spc_grst_l )
  );

  // interrupts
  for (genvar k=0; k<$size(irq_i); k++) begin
    synchronizer i_irq_sync (
      .clk         ( clk_i      ),
      .presyncdata ( irq_i[k]   ),
      .syncdata    ( irq[k]     )
    );
  end

  synchronizer i_ipi_sync (
    .clk         ( clk_i      ),
    .presyncdata ( ipi_i      ),
    .syncdata    ( ipi        )
  );

  synchronizer i_timer_sync (
    .clk         ( clk_i      ),
    .presyncdata ( time_irq_i ),
    .syncdata    ( time_irq   )
  );

  synchronizer i_debug_sync (
    .clk         ( clk_i       ),
    .presyncdata ( debug_req_i ),
    .syncdata    ( debug_req   )
  );

  /////////////////////////////
  // ariane instance
  /////////////////////////////

  function automatic config_pkg::cva6_cfg_t build_openpiton_config(config_pkg::cva6_user_cfg_t CVA6UserCfg);
    config_pkg::cva6_user_cfg_t cfg = CVA6UserCfg;
    cfg.RASDepth = RASDepth;
    cfg.BTBEntries = BTBEntries;
    cfg.BHTEntries = BHTEntries;
    // idempotent region
    cfg.NrNonIdempotentRules = NrNonIdempotentRules;
    cfg.NonIdempotentAddrBas = NonIdempotentAddrBase;
    cfg.NonIdempotentLength = NonIdempotentLength;
    cfg.NrExecuteRegionRules = NrExecuteRegionRules;
    cfg.ExecuteRegionAddrBas = ExecuteRegionAddrBase;
    cfg.ExecuteRegionLength = ExecuteRegionLength;
    // cached region
    cfg.NrCachedRegionRules = NrCachedRegionRules;
    cfg.CachedRegionAddrBase = CachedRegionAddrBase;
    cfg.CachedRegionLength = CachedRegionLength;
    // cache config
    cfg.AxiCompliant = 1'b0;
    cfg.SwapEndianess = SwapEndianess;
    // debug
    cfg.DmBaseAddress = DmBaseAddress;
    cfg.NrPMPEntries = NrPMPEntries;
    return cfg;
  endfunction

  localparam config_pkg::cva6_user_cfg_t CVA6UserCfg = build_openpiton_config(cva6_config_pkg::cva6_cfg);
  localparam config_pkg::cva6_cfg_t CVA6Cfg = build_config_pkg::build_config(CVA6UserCfg);

  ariane #(
    .CVA6Cfg ( CVA6Cfg ),
    .noc_req_t  ( l15_req_t ),
    .noc_resp_t ( l15_rtrn_t )
  ) ariane (
    .clk_i       ( clk_i      ),
    .rst_ni      ( spc_grst_l ),
    .boot_addr_i              ,// constant
    .hart_id_i                ,// constant
    .irq_i       ( irq        ),
    .ipi_i       ( ipi        ),
    .time_irq_i  ( time_irq   ),
    .debug_req_i ( debug_req  ),
    .noc_req_o   ( l15_req    ),
    .noc_resp_i  ( l15_rtrn   )
  );

endmodule // ariane_verilog_wrap

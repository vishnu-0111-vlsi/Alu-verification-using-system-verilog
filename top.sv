// Code your testbench here
// or browse Examples
`timescale 1ns/1ns
`define num 20
`define WIDTH 8
`define cmd_WIDTH 4

//-------------------------------------

interface alu_if(input logic clk,input logic rst);
  logic [`WIDTH - 1 : 0]opa;
  logic [`WIDTH - 1 : 0]opb;
  logic [`cmd_WIDTH - 1 : 0]cmd;
  logic [1:0]input_valid;
  logic mode;
  logic ce;
  logic cin;
  logic [`WIDTH : 0]res;
  logic err;
  logic cout;
  logic oflow;
  logic g;
  logic e;
  logic l;

  clocking Drv_cb @(posedge clk);
    default input #0 output #0;

    output opa;
    output opb;
    output cmd;
    output input_valid;
    output mode;
    output ce;
    output cin;
    input rst;

  endclocking

  clocking Mon_cb @(posedge clk);
    default input #0 output #0;
     input opa;
    input opb;
          input mode;
          input cmd;
    input res;
    input err;
    input oflow;
    input cout;
    input g;
    input e;
    input l;
    input rst;

  endclocking

  clocking Ref_cb @(posedge clk);
    default input #0 output #0;

    input opa;
    input opb;
    input cmd;
    input input_valid;
    input mode;
    input ce;
    input cin;
    input rst;

  endclocking

  modport drv_mod(clocking Drv_cb);
    modport mon_mod(clocking Mon_cb);
      modport ref_mod(clocking Ref_cb);
  modport dut(input opa,
    input opb,
    input cmd,
    input input_valid,
    input mode,
    input ce,
    input cin,
    output res,
    output err,
    output oflow,
    output cout,
    output g,
    output e,
    output l);


//ASSeRTIONS

  property prop1;
    @(posedge clk)
    input_valid == 2'b11 |-> !$isunknown(opa) && !$isunknown(opb);
  endproperty
    assert property (prop1)
    else $error("opa/opb unknown when input_valid == 2'b11");

  property prop2;
    @(posedge clk)
    ce |-> !$isunknown(cmd) && !$isunknown(opa) && !$isunknown(opb) && !$isunknown(input_valid) && !$isunknown(mode);
  endproperty
    assert property (prop2)
    else $error("cmd or operands unknown when ce is high");

  property prop3;
    @(posedge clk)
    (cmd!=='x)-> (cmd < (2**`cmd_WIDTH));
  endproperty
    assert property (prop3)
    else $error("cmd out of range!");

  property prop4;
    @(posedge clk)
    (mode==1 ) |-> (cmd inside {0,1,2,3,4,5,6,7,8,9,10});
  endproperty
    assert property (prop4)
    else $error("Invalid cmd used in mode=1");

  property prop5;
    @(posedge clk)
    (mode==0 ) |-> (cmd inside {0,1,2,3,4,5,6,7,8,9,10,11,12,13});
  endproperty
    assert property (prop5)
    else $error("Invalid cmd used in mode=0");

  property prop6;
    @(posedge clk)
    rst |-> (res==0 && err==0 && cout==0 && oflow==0 && g==0 && e==0 && l==0);
  endproperty
    assert property (prop6)
    else $error("Outputs not cleared on rst");

      sequence seq1;
        ce ==1 && ((mode ==1) && cmd inside{0,1,2,3,4,5,6,7,8}) || mode == 0;
      endsequence

  property prop7;
    @(posedge clk) seq1 |=> res;
  endproperty
     assert property (prop7)
       else $error("No result after 1 clk cycle");

       sequence seq2;
         ce == 1 && (mode == 1 && cmd inside {9,10});
       endsequence

       property prop8;
         @(posedge clk) seq2 ##3 res;
       endproperty
       assert property (prop8);
         $warning("no resut for multiplication after 2 clk cycle ");

endinterface

//---------------------------------------------------------------------------------------
class transaction;

  rand bit [`WIDTH - 1 : 0]opa;
  rand bit [`WIDTH - 1 : 0]opb;
  rand bit [`cmd_WIDTH - 1 : 0]cmd;
  rand bit [1:0]input_valid;
  rand bit ce;
  randc bit mode;
  rand bit cin;
  bit [`WIDTH : 0]res;
  bit err;
  bit cout;
  bit oflow;
  bit g;
  bit e;
  bit l;

  constraint a1{ce dist{0:=10,1:=90};}
  //constraint a2{input_valid dist{[1:3]:=70 , 0:=30};}
  constraint a3{input_valid == 2'b11; ce == 1; }
  constraint set {cmd ==9 ;mode ==1; opa inside{[0:5]};opb inside {[0:5]};}
  virtual function transaction copy();
    copy = new;
    copy.opa = opa;
    copy.opb = opb;
    copy.cmd = cmd;
    copy.input_valid = input_valid;
    copy.ce = ce;
    copy.mode = mode;
    copy.cin = cin;
    copy.res = res;
    copy.cout = cout;
    copy.oflow = oflow;
    copy.g = g;
    copy.e = e;
    copy.l = l;
    return copy;
  endfunction
endclass
  //-----------------------------------------------------------------------------------------

class generator;

  transaction gen_tr;

  mailbox #(transaction) mb_gd;

  function new(mailbox #(transaction) mb_gd);
    this.mb_gd = mb_gd;
    gen_tr = new();
  endfunction

  task start();
    begin
      for(int i = 0 ; i < `num ; i++)
        begin
          gen_tr.randomize();
          mb_gd.put(gen_tr.copy());
          $display("[%t]the Randomized values in generator are : opa:%d , opb:%d , cmd:%d , input_valid:%d , ce:%d, mode:%d ",$time, gen_tr.opa,gen_tr.opb,gen_tr.cmd,gen_tr.input_valid,gen_tr.ce,gen_tr.mode);
        end
    end
  endtask
endclass
//-------------------------------------------------------------------------------------------------
  class driver;

  virtual alu_if.drv_mod drv_intf;
  transaction drv_tr;
  mailbox #(transaction) mb_gd;
  mailbox #(transaction) mb_dr;

  function new(mailbox #(transaction) mb_gd,
               mailbox #(transaction) mb_dr,
               virtual alu_if.drv_mod drv_intf);
    this.mb_gd = mb_gd;
    this.mb_dr = mb_dr;
    this.drv_intf = drv_intf;
  endfunction

  covergroup driver_cover;
Input_Valid : coverpoint drv_tr.input_valid { bins vld[4] = {2'b00, 2'b01, 2'b10, 2'b11}; }
Command     : coverpoint drv_tr.cmd {
  bins cmd_first[]  = {[0 : (2**(`cmd_WIDTH/2))-1]};
  //bins cmd_second[] = {(2**(`cmd_WIDTH/2)) : (2**`cmd_WIDTH)-1]};
}
OperandA    : coverpoint drv_tr.opa {
  bins zero      = {0};
  bins small_opa = {[1 : (2**(`WIDTH/2))-1]};
  bins large_opa = {[2**(`WIDTH/2) : (2**`WIDTH)-1]};
}
OperandB    : coverpoint drv_tr.opb {
  bins zero      = {0};
  bins small_opb = {[1 : (2**(`WIDTH/2))-1]};
  bins large_opb = {[2**(`WIDTH/2) : (2**`WIDTH)-1]};
}
//clk    : coverpoint drv_tr.ce  { bins Clock_en[] = {[1'b0, 1'b1]}; }
//carry_in : coverpoint drv_tr.cin { bins Carry_in[] = {[1'b0, 1'b1]}; }
AxB      : cross OperandA, OperandB;
cmdxinp  : cross command, Input_Valid;

  endgroup

  task start();
    //driver_cover = new();
    repeat(3)@(drv_intf.Drv_cb);
    $display("driver started - %t",$time);
    for (int i = 0; i < `num; i++) begin
      mb_gd.get(drv_tr);
      //driver_cover.sample();

      if (drv_intf.Drv_cb.rst == 0 && drv_tr.ce == 1) begin

        if ( (drv_tr.mode == 1 && drv_tr.input_valid == 2'b11 ) || (drv_tr.mode == 0 && drv_tr.input_valid == 2'b11)) begin


          drv_intf.Drv_cb.opa      <= drv_tr.opa;
          drv_intf.Drv_cb.opb      <= drv_tr.opb;
          drv_intf.Drv_cb.cmd      <= drv_tr.cmd;
          drv_intf.Drv_cb.input_valid <= drv_tr.input_valid;
          drv_intf.Drv_cb.mode     <= drv_tr.mode;
          drv_intf.Drv_cb.ce       <= drv_tr.ce;
          drv_intf.Drv_cb.cin      <= drv_tr.cin;


            if ((drv_tr.mode == 1 && drv_tr.cmd == 9) || (drv_tr.mode == 1 && drv_tr.cmd == 10))
              repeat(3) @(drv_intf.Drv_cb);
            else
              repeat(2)@(drv_intf.Drv_cb);

          mb_dr.put(drv_tr.copy());
          $display("[%t]Driver sent for single operand(valid cmd): opa=%d ,opb=%d ,cmd=%d ,input_valid=%d, mode=%d", $time,drv_tr.opa, drv_tr.opb, drv_tr.cmd, drv_tr.input_valid, drv_tr.mode);

        end


         else if ( (drv_tr.mode == 1 && drv_tr.cmd inside {4,5,6,7}) ||
             (drv_tr.mode == 0 && drv_tr.cmd inside {6,7,8,9,10,11}) ) begin


          drv_intf.Drv_cb.opa      <= drv_tr.opa;
          drv_intf.Drv_cb.opb      <= drv_tr.opb;
          drv_intf.Drv_cb.cmd      <= drv_tr.cmd;
          drv_intf.Drv_cb.input_valid <= drv_tr.input_valid;
          drv_intf.Drv_cb.mode     <= drv_tr.mode;
          drv_intf.Drv_cb.ce       <= drv_tr.ce;
          drv_intf.Drv_cb.cin      <= drv_tr.cin;

              repeat(2)@(drv_intf.Drv_cb);

          mb_dr.put(drv_tr.copy());
          $display("[%t]Driver sent for single operand(valid cmd): opa=%d ,opb=%d ,cmd=%d ,input_valid=%d, mode=%d", $time,drv_tr.opa, drv_tr.opb, drv_tr.cmd, drv_tr.input_valid, drv_tr.mode);

        end
        else begin
          if (drv_tr.input_valid == 2'b10 || drv_tr.input_valid == 2'b01) begin
            bit found = 0;
            drv_tr.cmd.rand_mode(0);
            drv_tr.mode.rand_mode(0);
            drv_tr.ce.rand_mode(0);

            drv_intf.Drv_cb.opa      <= drv_tr.opa;
            drv_intf.Drv_cb.opb      <= drv_tr.opb;
            drv_intf.Drv_cb.cmd      <= drv_tr.cmd;
            drv_intf.Drv_cb.input_valid <= drv_tr.input_valid;
            drv_intf.Drv_cb.mode     <= drv_tr.mode;
            drv_intf.Drv_cb.ce       <= drv_tr.ce;
            drv_intf.Drv_cb.cin      <= drv_tr.cin;


            for (int j = 0; j < 15; j++) begin
              @(drv_intf.Drv_cb);
              drv_tr.randomize();
              if (drv_tr.input_valid == 2'b11) begin
                drv_intf.Drv_cb.opa      <= drv_tr.opa;
            drv_intf.Drv_cb.opb      <= drv_tr.opb;
            drv_intf.Drv_cb.input_valid <= drv_tr.input_valid;
            drv_intf.Drv_cb.cin      <= drv_tr.cin;
                mb_dr.put(drv_tr);
                found = 1;
                break;
              end
            end

            drv_tr.cmd.rand_mode(1);
            drv_tr.mode.rand_mode(1);
            drv_tr.ce.rand_mode(1);


            if (!found) begin
              $error("input_valid did not become 2'b11 in 16 clks for invalid cmd %0d mode %0d",
                      drv_tr.cmd, drv_tr.mode);
            end

            drv_intf.Drv_cb.opa      <= drv_tr.opa;
            drv_intf.Drv_cb.opb      <= drv_tr.opb;
            drv_intf.Drv_cb.cmd      <= drv_tr.cmd;
            drv_intf.Drv_cb.input_valid <= drv_tr.input_valid;
            drv_intf.Drv_cb.mode     <= drv_tr.mode;
            drv_intf.Drv_cb.ce       <= drv_tr.ce;
            drv_intf.Drv_cb.cin      <= drv_tr.cin;

            if ((drv_tr.mode == 1 && drv_tr.cmd == 9) || (drv_tr.mode == 1 && drv_tr.cmd == 10))
              repeat(3) @(drv_intf.Drv_cb);
            else
              repeat(2)@(drv_intf.Drv_cb);

            mb_dr.put(drv_tr.copy());
            $display("[%t]Driver sent for double operand(after waiting for input_valid): opa=%d opb=%d cmd=%d input_valid=%d",$time,
                      drv_tr.opa, drv_tr.opb, drv_tr.cmd, drv_tr.input_valid);

          end
        end
      end
    end
  endtask
endclass
//----------------------------------------------------------------------------------------------------------------------------

 class Monitor;
         transaction mon_tr;

  virtual alu_if.mon_mod mon_intf;

  mailbox #(transaction) mb_ms;

  function new(mailbox #(transaction) mb_ms, virtual alu_if.mon_mod mon_intf);
    begin
    this.mb_ms = mb_ms;
    this.mon_intf = mon_intf;
   // monitor_cover = new(); // instantiate covergroup
    end
  endfunction

  task start();
          int start=1;
          repeat(4)@(mon_intf.Mon_cb);
                  for(int i = 0 ; i < `num ; i++) begin
                          mon_tr = new();

                          repeat(1)@(mon_intf.Mon_cb);
      mon_tr.mode = mon_intf.Mon_cb.mode;
          mon_tr.cmd = mon_intf.Mon_cb.cmd;
      mon_tr.res   = mon_intf.Mon_cb.res;
      mon_tr.err   = mon_intf.Mon_cb.err;
      mon_tr.cout  = mon_intf.Mon_cb.cout;
      mon_tr.oflow = mon_intf.Mon_cb.oflow;
      mon_tr.g     = mon_intf.Mon_cb.g;
      mon_tr.e     = mon_intf.Mon_cb.e;
      mon_tr.l     = mon_intf.Mon_cb.l;


      $display("[%t]Monitor TO Scoreboard: res=%0d, err=%d, cout=%d, oflow=%d, g=%d, e=%d, l=%d ",$time,
                  mon_tr.res, mon_tr.err, mon_tr.cout, mon_tr.oflow, mon_tr.g, mon_tr.e, mon_tr.l);
         if(start==1  && ((mon_tr.mode == 1 && mon_tr.cmd == 9) || (mon_tr.mode == 1 && mon_tr.cmd == 10)))
          begin
                  repeat(1)@(mon_intf.Mon_cb);
                  start=0;
                  mb_ms.put(mon_tr);
          end
          else
          begin
                 // repeat(1)@(mon_intf.Mon_cb);
                  mb_ms.put(mon_tr);
                  start=0;
          end



          //mb_ms.put(mon_tr);

          if((mon_tr.mode == 1 && mon_tr.cmd == 9) || (mon_tr.mode == 1 && mon_tr.cmd == 10))
          begin
                  repeat(2)@(mon_intf.Mon_cb);
          end
          else
          begin
                  repeat(1)@(mon_intf.Mon_cb);
          end

                  end
  endtask

endclass

 //--------------------------------------------------------------------------------------------------------------------
 class reference_model;

  virtual alu_if.ref_mod ref_intf;
  transaction ref_tr;

  mailbox #(transaction) mb_dr;
  mailbox #(transaction) mb_rs;

  localparam rot_bits = $clog2(`WIDTH);
  logic [rot_bits-1:0] rot_val;

  function new(mailbox #(transaction) mb_dr, mailbox #(transaction) mb_rs, virtual alu_if.ref_mod ref_intf);
    this.mb_dr = mb_dr;
    this.mb_rs = mb_rs;
    this.ref_intf = ref_intf;
  endfunction

  task start();
    bit found;
    bit [3:0] count;

    for(int i = 0; i < `num; i++) begin
      mb_dr.get(ref_tr);

      $display("[%t] data from driver :  opa=%d ,opb=%d ,cmd=%d ,input_valid=%d, mode=%d", $time,ref_tr.opa, ref_tr.opb, ref_tr.cmd, ref_tr.input_valid, ref_tr.mode);
      found = 0;
      count = 0;

      if (ref_intf.Ref_cb.rst == 1 || ref_tr.ce == 0) begin
        ref_tr.res = 0;
        ref_tr.err = 0;
        ref_tr.cout = 0;
        ref_tr.oflow = 0;
        ref_tr.g = 0;
        ref_tr.e = 0;
        ref_tr.l = 0;
      end
      else if (ref_intf.Ref_cb.rst == 0 && ref_tr.ce == 1) begin

        if ( (ref_tr.mode == 1 && !(ref_tr.cmd inside {0,1,2,3,4,5,6,7,8,9,10})) ||
             (ref_tr.mode == 0 && !(ref_tr.cmd inside {0,1,2,3,4,5,6,7,8,9,10,11,12,13})) ) begin
          ref_tr.err = 1;
        end

        if( (ref_tr.mode == 1 && (ref_tr.cmd inside {0,1,2,3,4,8,9,10})) ||
           (ref_tr.mode == 0 && (ref_tr.cmd inside {0,1,2,3,4,5,12,13})) ) begin

          if (ref_tr.input_valid == 2'b10 || ref_tr.input_valid == 2'b01) begin
            repeat(16) begin
              mb_dr.get(ref_tr);
              if (ref_tr.input_valid == 2'b11) begin
                found = 1;
                break;
              end
            end
          end

            if (!found) begin
              ref_tr.err = 1;
            end
          end


    if (ref_tr.mode == 1) begin
      case (ref_tr.cmd)

                0: if (ref_tr.input_valid == 2'b11 || found) begin
                  ref_tr.res = ref_tr.opa + ref_tr.opb;
                  ref_tr.cout = ref_tr.res[`WIDTH] ? 1 : 0 ;
                end
                1: if (ref_tr.input_valid == 2'b11 || found) begin
                  ref_tr.res = ref_tr.opa - ref_tr.opb;
                  ref_tr.oflow = (ref_tr.opa < ref_tr.opb) ? 1 : 0;
                end
                2: if (ref_tr.input_valid == 2'b11 || found) begin
                  ref_tr.res = ref_tr.opa + ref_tr.opb + ref_tr.cin;
                  ref_tr.cout = ref_tr.res[`WIDTH] ? 1 : 0 ;
                end
                3: if (ref_tr.input_valid == 2'b11 || found) begin
                  ref_tr.res = ref_tr.opa - ref_tr.opb - ref_tr.cin;
                  ref_tr.oflow = (ref_tr.opa < ref_tr.opb) ? 1 : 0;
                end
                 4: if(ref_tr.input_valid == 2'b01 || ref_tr.input_valid == 2'b11) begin
                  ref_tr.res = ref_tr.opa + 1;
                end
                   else begin
                     ref_tr.err = 1;
                   end
                5: if(ref_tr.input_valid == 2'b01 || ref_tr.input_valid == 2'b11) begin
                  ref_tr.res = ref_tr.opa - 1;
                end
                  else begin
                    ref_tr.err = 1;
                  end
                6: if(ref_tr.input_valid == 2'b10 || ref_tr.input_valid == 2'b11) begin
                  ref_tr.res = ref_tr.opb + 1;
                end
                  else begin
                    ref_tr.err = 1;
                  end
                7: if(ref_tr.input_valid == 2'b10 || ref_tr.input_valid == 2'b11) begin
                  ref_tr.res = ref_tr.opb - 1;
                end
                  else begin
                    ref_tr.err = 1;
                  end
                8: if (ref_tr.input_valid == 2'b11 || found) begin
                  if(ref_tr.opa > ref_tr.opb) ref_tr.g = 1;
                  else if (ref_tr.opa == ref_tr.opb) ref_tr.e = 1;
                  else ref_tr.l = 1;
                end
                9: if (ref_tr.input_valid == 2'b11 || found) begin
                  ref_tr.res = (ref_tr.opa+1) * (ref_tr.opb+1);
                end
                10: if (ref_tr.input_valid == 2'b11 || found) begin
                  ref_tr.res = (ref_tr.opa<<1) * ref_tr.opb;
                end
                default: ref_tr.err = 1;
              endcase
            end

            else if (ref_tr.mode == 0) begin
              case (ref_tr.cmd)
                0: if (ref_tr.input_valid == 2'b11 || found) begin
                  ref_tr.res = {1'b0, ref_tr.opa & ref_tr.opb};
                end
                1: if (ref_tr.input_valid == 2'b11 || found) begin
                  ref_tr.res = {1'b0, ~(ref_tr.opa & ref_tr.opb)};
                end
                2: if (ref_tr.input_valid == 2'b11 || found) begin
                  ref_tr.res = {1'b0, ref_tr.opa | ref_tr.opb};
                end
                3: if (ref_tr.input_valid == 2'b11 || found) begin
                  ref_tr.res = {1'b0, ~(ref_tr.opa | ref_tr.opb)};
                end
                4: if (ref_tr.input_valid == 2'b11 || found) begin
                  ref_tr.res = {1'b0, ref_tr.opa ^ ref_tr.opb};
                end
                5: if (ref_tr.input_valid == 2'b11 || found) begin
                  ref_tr.res = {1'b0, ~(ref_tr.opa ^ ref_tr.opb)};
                end
                6: if(ref_tr.input_valid == 2'b01 || ref_tr.input_valid == 2'b11) begin
                  ref_tr.res = {1'b0, ~ref_tr.opa};
                end
                else begin
                  ref_tr.err = 1;
                end
                7: if(ref_tr.input_valid == 2'b10 || ref_tr.input_valid == 2'b11) begin
                  ref_tr.res = {1'b0, ~ref_tr.opb};
                end
                else begin
                  ref_tr.err = 1;
                end
                8: if(ref_tr.input_valid == 2'b01 || ref_tr.input_valid == 2'b11) begin
                  ref_tr.res = {1'b0, ref_tr.opa>>1};
                end
                else begin
                  ref_tr.err = 1;
                end
                9: if(ref_tr.input_valid == 2'b01 || ref_tr.input_valid == 2'b11) begin
                  ref_tr.res = {1'b0, ref_tr.opa << 1};
                end
                else begin
                  ref_tr.err = 1;
                end
                10:if(ref_tr.input_valid == 2'b10 || ref_tr.input_valid == 2'b11) begin
                  ref_tr.res = {1'b0,ref_tr.opb >> 1};
                end
                else begin
                  ref_tr.err = 1;
                end
                11: if(ref_tr.input_valid == 2'b10 || ref_tr.input_valid == 2'b11) begin
                  ref_tr.res = {1'b0, ref_tr.opb >>1};
                end
                else begin
                  ref_tr.err = 1;
                end
                12: if (ref_tr.input_valid == 2'b11 || found) begin
                  if (ref_tr.opb >= `WIDTH)
                    ref_tr.err = 1;
                  else
                    rot_val= ref_tr.opb[rot_bits-1 :0];
                  ref_tr.res = {1'b0, (ref_tr.opa << rot_val) | (ref_tr.opa >> (`WIDTH - rot_val))};
                end
                13: if (ref_tr.input_valid == 2'b11 || found) begin
                  if (ref_tr.opb >= `WIDTH)
                    ref_tr.err = 1;
                  else
                    rot_val= ref_tr.opb[rot_bits-1 : 0];
                  ref_tr.res = {1'b0, (ref_tr.opa >> rot_val) | (ref_tr.opa << (`WIDTH - rot_val))};
                end
                default : ref_tr.err = 1;
              endcase
            end
          end

      mb_rs.put(ref_tr.copy());
      $display("[%t]data out from reference model cmd=%d mode=%d res=%d err=%d cout=%d oflow=%d g=%d e=%d l=%d", $time,ref_tr.cmd, ref_tr.mode, ref_tr.res, ref_tr.err, ref_tr.cout, ref_tr.oflow, ref_tr.g, ref_tr.e, ref_tr.l);

        end
  endtask
endclass
    //----------------------------------------------------------------------------------------------------------------------------------------------------------------

 class scoreboard;

  transaction ref_tr, mon_tr;
  mailbox #(transaction) mb_rs;
  mailbox #(transaction) mb_ms;

  function new(mailbox #(transaction) mb_rs, mailbox #(transaction) mb_ms);
    this.mb_rs = mb_rs;
    this.mb_ms = mb_ms;
  endfunction

  task start();
    for(int i = 0; i < `num; i++) begin
      fork
        begin
          mb_ms.get(mon_tr);
        end
        begin
          mb_rs.get(ref_tr);
        end
      join
      $display("[%t]------------Data From Reference Model--------- : Result: %d, err: %d, cout: %d, oflow: %d, g: %d, e: %d, l: %d",$time,ref_tr.res, ref_tr.err, ref_tr.cout, ref_tr.oflow, ref_tr.g, ref_tr.e, ref_tr.l);
           $display("[%t]-------------data from monitor model---------- : result: %d, err: %d, cout: %d, oflow: %d, g: %d, e: %d, l: %d",$time,mon_tr.res, mon_tr.err, mon_tr.cout, mon_tr.oflow, mon_tr.g, mon_tr.e, mon_tr.l);

      if (ref_tr.res === mon_tr.res)
        $display("%t : res matches ", $time);
      else
        $error("%t : res mismatch  (ReF=%d, MON=%d)", $time, ref_tr.res, mon_tr.res);

      if (ref_tr.err === mon_tr.err)
        $display("%t : err matches ", $time);
      else
        $error("%t : err mismatch (ReF=%d, MON=%d)", $time, ref_tr.err, mon_tr.err);

      if (ref_tr.cout === mon_tr.cout)
        $display("%t : cout matches ", $time);
      else
        $error("%t : cout mismatch (ReF=%d, MON=%d)", $time, ref_tr.cout, mon_tr.cout);

      if (ref_tr.oflow === mon_tr.oflow)
        $display("%t : oflow matches ", $time);
      else
        $error("%t : oflow mismatch (ReF=%d, MON=%d)", $time, ref_tr.oflow, mon_tr.oflow);

      if (ref_tr.g === mon_tr.g)
        $display("%t : g matches ", $time);
      else
        $error("%t : g mismatch (ReF=%d, MON=%d)", $time, ref_tr.g, mon_tr.g);

      if (ref_tr.e === mon_tr.e)
        $display("%t : e matches ", $time);
      else
        $error("%t : e mismatch (ReF=%d, MON=%d)", $time, ref_tr.e, mon_tr.e);

      if (ref_tr.l === mon_tr.l)
        $display("%t : l matches ", $time);
      else
        $error("%t : l mismatch (ReF=%d, MON=%d)", $time, ref_tr.l, mon_tr.l);

      $display("-------------------------------------------------------------");
    end
  endtask
endclass
//-----------------------------------------------------------------------------------------------------------------------------------------------------

  class environment;

  virtual alu_if drv_intf;
  virtual alu_if mon_intf;
  virtual alu_if ref_intf;

  mailbox #(transaction) mb_gd;
  mailbox #(transaction) mb_dr;
  mailbox #(transaction) mb_ms;
  mailbox #(transaction) mb_rs;

  generator gen;
  driver drv;
  Monitor mon;
  reference_model ref_mod;
  scoreboard scb;

  function new(  virtual alu_if drv_intf,virtual alu_if mon_intf,virtual alu_if ref_intf);
    begin
      this.drv_intf = drv_intf;
      this.mon_intf = mon_intf;
      this.ref_intf = ref_intf;
    end
  endfunction

  task build();
    begin
    mb_gd = new();
    mb_dr = new();
    mb_ms = new();
    mb_rs = new();

    gen = new(mb_gd);
    drv = new(mb_gd,mb_dr,drv_intf);
    mon = new(mb_ms,mon_intf);
    ref_mod = new(mb_dr,mb_rs,ref_intf);
    scb = new(mb_rs,mb_ms);
    end
  endtask

  task start();
    fork
    gen.start();
    drv.start();
    mon.start();
    ref_mod.start();
    scb.start();
    join
  endtask

endclass
  //----------------------------------------------------------------------------------------------------------------------------------------------------
 class testbench;

  virtual alu_if drv_intf;
  virtual alu_if mon_intf;
  virtual alu_if ref_intf;

  environment env;

  function new(virtual alu_if drv_intf,virtual alu_if mon_intf,virtual alu_if ref_intf);
    begin
      this.drv_intf = drv_intf;
      this.mon_intf = mon_intf;
      this.ref_intf = ref_intf;
    end
  endfunction

  task run;
    begin
      env = new( drv_intf, mon_intf, ref_intf);
      env.build();
      env.start();
    end
  endtask

endclass
  //--------------------------------------------------------------------------------------------------------------------------------------------------
 module top1;
  logic clk;
  logic rst;

   initial
     begin
       clk = 0;
       forever #5 clk = ~clk;
     end


  initial
    begin
      rst = 0;
      @(posedge clk)
      rst = 0;
    end


  alu_if intf(clk, rst);

  ALU_DESIGN DUT(.INP_VALID(intf.input_valid), .OPA(intf.opa), .OPB(intf.opb), .CIN(intf.cin), .CMD(intf.cmd), .COUT(intf.cout), .OFLOW(intf.oflow), .RES(intf.res), .G(intf.g), .E(intf.e), .L(intf.l), .CLK(clk), .ERR(intf.err), .CE(intf.ce), .MODE(intf.mode), .RST(intf.rst));

   testbench test = new(intf.drv_mod, intf.mon_mod, intf.ref_mod);

  initial
    begin
      test.run();
      $finish();
    end
endmodule

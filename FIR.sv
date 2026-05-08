// Simon Nagel
// FIR Filter control module
//
//                                      --> RAM (coeff) x50
//  ADC ->   /-----\        /-----\        |
//           | TOP |  <->   | FIR |   -->  MAC x50
//  DAC <-   \-----/        \-----/        |
//                                      --> RAM (data) x50
//

module FIR(
  input  logic              adc_clk,    // Takt
  input  logic              adc_rstn,   // aktiver-low Reset
  input  logic signed [13:0] new_data,  // 14-Bit Eingang
  (* keep = "true" *)
  output logic signed [47:0] sample_out,// 48-Bit FIR-Ausgang

  sys_bus_if.s         bus              // sys_bus Interface
);

  // -------------------------------------------------------
  // interne Signale
  // -------------------------------------------------------
  parameter int NTAPS = 50;

  logic                   acc_done;
  (* keep = "true" *)
  logic signed [47:0]     mac_acc[NTAPS];
  logic signed [47:0]     sum;
  logic                   init_done;
  logic [8:0]             counter;
  logic [8:0]             ram_new;
  logic [8:0]             ram_old;
  typedef enum logic [2:0] { STATE_RUN, STATE_RESET, STATE_PAUSE } state_t;
  state_t                 state;
  logic signed [47:0]     mac_acc_hold[NTAPS];

  // Daten-RAM
  logic [$clog2(512)-1:0] wr_addr;
  logic [$clog2(512)-1:0] rd_addr;
  logic signed [13:0]     sample_i[NTAPS];
  logic signed [13:0]     sample_o[NTAPS];
  logic                   write_en;

  // Koeffizienten-RAM
  logic                   write_en_coeff[NTAPS];
  logic [$clog2(512)-1:0] wr_addr_coeff;
  logic [$clog2(512)-1:0] rd_addr_coeff;           // EINZIGE Leseadresse für alle coeff-RAMs
  logic signed [13:0]     coeff_i[NTAPS];
  logic signed [13:0]     coeff_o[NTAPS];
  logic signed [31:0]     coeff_read_value;        // 32 Bit, sign-erweitert
  logic signed [31:0]     coeff_read_reg;          // LATCH für Bus-Read
  logic [8:0] idx_reg_p1;
  assign idx_reg_p1 = idx_reg + 9'd1;  // modulo 512, weil 9 Bit
  
  // sys_bus Signale
  logic [8:0]             tap_reg;   // 0..49
  logic [8:0]             idx_reg;   // 0..511
  logic [13:0]            data_reg;  // zu schreibender Koeff
  logic                   we_reg;    // Write-Impuls
  logic [19:0]            local_addr;
  assign local_addr = bus.addr[19:0];

  // -------------------------------------------------------
  // generate: NTAPS Instanzen von Daten-RAM + Koeff-RAM + MAC
  // -------------------------------------------------------
  genvar i;
  generate
    for (i = 0; i < NTAPS; i++) begin : FIR_TAP

      // Daten-RAM
      blk_mem_gen_0 ram_data_inst (
        // Port A: Schreiben
        .clka  (adc_clk),
        .wea   (write_en),
        .addra (wr_addr),
        .dina  (sample_i[i]),
        .ena   (1'b1),
        // Port B: Lesen
        .clkb  (adc_clk),
        .addrb (rd_addr),
        .doutb (sample_o[i]),
        .enb   (1'b1)
      );

      // Koeffizienten-RAM
      blk_mem_gen_1 ram_coeff_inst (
        // Port A: Schreiben (Bus)
        .clka  (adc_clk),
        .wea   (write_en_coeff[i]),
        .addra (wr_addr_coeff),
        .dina  (coeff_i[i]),
        // Port B: Lesen (FIR + Bus-Read)
        .clkb  (adc_clk),
        .addrb (rd_addr_coeff),
        .doutb (coeff_o[i])
      );

      // MAC
      MAC imac (
        .clk      (adc_clk),
        .mac_reset(acc_done),
        .A        (sample_o[i]),
        .B        (coeff_o[i]),
        .result   (mac_acc[i])
      );
    end
  endgenerate

  // =======================================================
  // BLOCK 1: FSM + INIT + DATENPFAD
  // =======================================================
  always_ff @(posedge adc_clk or negedge adc_rstn) begin
    if (!adc_rstn) begin
      init_done     <= 1'b0;
      counter       <= 9'd0;
      state         <= STATE_RUN;

      wr_addr       <= 9'd0;
      rd_addr       <= 9'd0;
      write_en      <= 1'b0;

      ram_new       <= 9'd0;
      ram_old       <= 9'd511;
      sum           <= 48'sd0;
      sample_out    <= 48'sd0;
      acc_done      <= 1'b0;

      sample_i      <= '{default:14'sd0};
      mac_acc_hold  <= '{default:48'sd0};

    end else begin

      if (!init_done) begin
        // --- INIT PHASE: Daten-RAM mit Testwerten füllen ---
        wr_addr  <= counter;
        sample_i <= '{default:(14'd1 + counter[1:0])};
        write_en <= 1'b1;

        if (counter == 9'd511) begin
          init_done <= 1'b1;
          counter   <= 9'd0;
          acc_done  <= 1'b1;
        end else begin
          counter   <= counter + 9'd1;
        end
      end else begin
        case (state)
          //--------------------------------------------------
          // STATE_RUN
          //--------------------------------------------------
          STATE_RUN: begin
            write_en <= 1'b0;
            rd_addr  <= counter + ram_new;

            // 0 ? Start neue Berechnung
            if (counter == 9'd0) begin
              acc_done <= 1'b1;
              sum      <= '0;
              counter  <= counter + 9'd1;

              // MAC Wertekopie
              for (int j = 0; j < NTAPS; j++) begin
                mac_acc_hold[j] <= mac_acc[j];
              end

            end else if (counter >= 9'd1 && counter <= 9'd50) begin
              acc_done <= 1'b0;
              sum      <= sum + mac_acc_hold[counter - 1];
              counter  <= counter + 9'd1;

            end else if (counter == 9'd51) begin
              acc_done   <= 1'b0;
              sample_out <= sum;
              counter    <= counter + 9'd1;

            // Ringende bei 511
            end else if (counter == 9'd511) begin
              acc_done <= 1'b0;
              counter  <= 9'd0;
              state    <= STATE_RESET;

            end else begin
              acc_done <= 1'b0;
              counter  <= counter + 9'd1;
            end
          end

          //--------------------------------------------------
          // STATE_RESET
          //--------------------------------------------------
          STATE_RESET: begin
            acc_done <= 1'b0;
            write_en <= 1'b1;
            wr_addr  <= ram_old;
            ram_new  <= ram_old;
            state    <= STATE_PAUSE;
          end

          //--------------------------------------------------
          // STATE_PAUSE
          //--------------------------------------------------
          STATE_PAUSE: begin
            write_en <= 1'b1;
            acc_done <= 1'b0;
            wr_addr  <= ram_old;

            // neuen ADC-Wert in Ring 0 schreiben
            sample_i[0] <= new_data;

            // übrige Ringe übernehmen Wert aus dem vorherigen
            for (int j = NTAPS-1; j > 0; j--) begin
              sample_i[j] <= sample_o[j-1];
            end

            // Rückwärtslauf des Ringpuffers (511 -> ... -> 0 -> 511)
            if (ram_old == 9'd0)
              ram_old <= 9'd511;
            else
              ram_old <= ram_old - 9'd1;

            state <= STATE_RUN;
          end

          default: state <= STATE_RUN;
        endcase
      end
    end
  end

  // =======================================================
  // BLOCK 1b: Koeffizienten-Leseadresse (nur FIR)
  // =======================================================
  always_ff @(posedge adc_clk or negedge adc_rstn) begin
    if (!adc_rstn) begin
      rd_addr_coeff <= 9'd0;
    end else begin
      rd_addr_coeff <= counter;
    end
  end

  // =======================================================
  // BLOCK 1c: Latch für Koeffizientenwert
  // =======================================================
  always_ff @(posedge adc_clk or negedge adc_rstn) begin
    if (!adc_rstn) begin
      coeff_read_reg <= 32'sd0;
    end else begin
      // Wenn der FIR bei der gewünschten Adresse ist, Wert einfangen
      if (rd_addr_coeff == idx_reg_p1) begin
        // 14 Bit -> 32 Bit sign-erweitern
        coeff_read_reg <= {{18{coeff_o[tap_reg][13]}}, coeff_o[tap_reg]};
      end
      // sonst Wert beibehalten
    end
  end



  // =======================================================
  // BLOCK 2: SYS-BUS REGISTER
  // =======================================================
  always_ff @(posedge adc_clk or negedge adc_rstn) begin
    if (!adc_rstn) begin
      bus.rdata <= 32'h0;
      bus.ack   <= 1'b0;
      bus.err   <= 1'b0;

      tap_reg   <= 9'd0;
      idx_reg   <= 9'd0;
      data_reg  <= 14'sd0;
      we_reg    <= 1'b0;

    end else begin
      // Standard ACK
      bus.ack <= bus.wen | bus.ren;
      bus.err <= 1'b0;

      // RESET jedes Taktes:
      we_reg <= 1'b0;

      // WRITE REGISTER
      if (bus.wen) begin
        case (local_addr)
          20'h00000: tap_reg  <= bus.wdata[8:0];   // TAP
          20'h00004: idx_reg  <= bus.wdata[8:0];   // ADDR
          20'h00008: data_reg <= bus.wdata[13:0];  // VALUE
          20'h0000C: we_reg   <= bus.wdata[0];     // EIN-Takt-Impuls
        endcase
      end

      // READ REGISTER
      if (bus.ren) begin
        case (local_addr)
          20'h00000: bus.rdata <= {{23{1'b0}}, tap_reg};      // TAP zurück
          20'h00004: bus.rdata <= {{23{1'b0}}, idx_reg};      // ADDR zurück
          20'h00008: bus.rdata <= coeff_read_reg;           // KOEFF-WERT
          default:   bus.rdata <= 32'hDEADBEEF;
        endcase
      end
    end
  end


  // =======================================================
  // BLOCK 3: KOEFFIZIENTEN-WRITE
  // =======================================================
  always_ff @(posedge adc_clk or negedge adc_rstn) begin
    if (!adc_rstn) begin
      wr_addr_coeff <= 9'd0;

      for (int k = 0; k < NTAPS; k++) begin
        write_en_coeff[k] <= 1'b0;
        coeff_i[k]        <= 14'sd0;
      end

    end else if (!init_done) begin
      // ---------- INIT PHASE ----------
      wr_addr_coeff <= counter;

      if (counter == 9'd0) begin
        // Tap 0 bekommt 4096, alle anderen 0
        write_en_coeff[0] <= 1'b1;
        coeff_i[0]        <= 14'sd4096;

        for (int k = 1; k < NTAPS; k++) begin
          write_en_coeff[k] <= 1'b1;
          coeff_i[k]        <= 14'sd0;
        end
      end else begin
        // Für counter > 0 ? ALLE Taps auf Adresse counter = 0
        for (int k = 0; k < NTAPS; k++) begin
          write_en_coeff[k] <= 1'b1;
          coeff_i[k]        <= 14'sd0;
        end
      end

    end else begin
      // ---------- NORMAL BETRIEB ----------
      wr_addr_coeff <= wr_addr_coeff;

      // Default: nichts schreiben
      for (int k = 0; k < NTAPS; k++)
        write_en_coeff[k] <= 1'b0;

      // Bus-Write EIN Takt
      if (we_reg) begin
        wr_addr_coeff           <= idx_reg;      // Adresse
        write_en_coeff[tap_reg] <= 1'b1;         // nur gewählter TAP
        coeff_i[tap_reg]        <= data_reg;     // Wert
      end
    end
  end

endmodule
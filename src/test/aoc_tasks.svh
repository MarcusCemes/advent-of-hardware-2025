`ifndef AOC_TASKS_SVH
`define AOC_TASKS_SVH

//==============================================================================
// AoC Reusable Test Tasks (Wire-based)
//
// Include this file in your test module AFTER declaring:
//   - logic clk                      : clock signal
//   - logic rst                      : reset signal (active high = running)
//   - logic [BYTES-1:0][7:0] i_data    : input data buffer
//   - logic [IDX_BITS-1:0] i_available : bytes available in buffer
//   - logic [IDX_BITS-1:0] o_consumed  : bytes consumed by DUT
//   - logic o_finished                 : DUT finished signal
//   - logic [63:0] o_answer            : answer from DUT
//   - longint cycle_count              : cycle counter (written by aoc_run_test)
//
// The tasks access these signals directly by name.
//==============================================================================

// File handle for streaming (module-level so tasks can share)
int aoc_fd;

//------------------------------------------------------------------------------
// aoc_init: Initialize signals and perform reset sequence
//------------------------------------------------------------------------------
task aoc_init();
    int i;

    // Initialize data signals
    i_available = 0;
    i_eof = 0;
    for (i = 0; i < $size(i_data); i++) begin
        i_data[i] = 8'h00;
    end

    // Reset sequence: rst=0 (reset), wait, rst=1 (running)
    rst = 0;
    @(posedge clk);
    @(posedge clk);
    rst = 1;
    @(negedge clk);  // Wait for signals to settle before returning

    $display("[AoC] Reset complete, starting test");
endtask

//------------------------------------------------------------------------------
// aoc_run_test: Stream file to DUT, return when finished or timeout
//
// Reads incrementally from file as bytes are consumed.
// Buffer is shifted on positive clock edge based on o_consumed.
//------------------------------------------------------------------------------
task aoc_run_test(
    input string filename,
    input longint timeout_cycles,
    output longint cycles_taken
);
    int bytes_in_buffer;
    int consumed_int;
    int i;
    int read_result;
    logic [7:0] read_byte;

    // Open file
    aoc_fd = $fopen(filename, "rb");
    if (aoc_fd == 0) begin
        $error("[AoC] Failed to open file: %s", filename);
        cycles_taken = 0;
        return;
    end
    $display("[AoC] Opened file: %s", filename);

    // Initialize buffer state
    bytes_in_buffer = 0;

    // Initial fill of buffer
    while (bytes_in_buffer < $size(i_data) && !$feof(aoc_fd)) begin
        read_result = $fread(read_byte, aoc_fd);
        if (read_result > 0) begin
            i_data[bytes_in_buffer] = read_byte;
            bytes_in_buffer++;
        end
    end
    i_available = bytes_in_buffer[$bits(i_available)-1:0];

    // Main streaming loop
    cycles_taken = 0;

    while (!o_finished && cycles_taken < timeout_cycles) begin
        // Sample o_consumed at negedge (stable combinational outputs)
        @(negedge clk);
        consumed_int = int'(o_consumed);

        // Wait for posedge (state transitions occur here)
        @(posedge clk);
        cycles_taken++;

        // Shift out consumed bytes and refill from file
        // Clamp consumed to bytes_in_buffer (DUT may request more than available)
        if (consumed_int > bytes_in_buffer)
            consumed_int = bytes_in_buffer;

        if (consumed_int > 0) begin
            for (i = 0; i < $size(i_data); i++) begin
                if (i + consumed_int < $size(i_data))
                    i_data[i] = i_data[i + consumed_int];
                else
                    i_data[i] = 8'h00;
            end
            bytes_in_buffer = bytes_in_buffer - consumed_int;

            while (bytes_in_buffer < $size(i_data) && !$feof(aoc_fd)) begin
                read_result = $fread(read_byte, aoc_fd);
                if (read_result > 0) begin
                    i_data[bytes_in_buffer] = read_byte;
                    bytes_in_buffer++;
                end
            end

            i_available = bytes_in_buffer[$bits(i_available)-1:0];
        end

        // Update EOF flag - buffer empty and file exhausted
        i_eof = (i_available == 0) && $feof(aoc_fd);
    end

    $fclose(aoc_fd);

    if (cycles_taken >= timeout_cycles) begin
        $error("[AoC] Timeout after %0d cycles", timeout_cycles);
    end else begin
        $display("[AoC] Finished after %0d cycles", cycles_taken);
    end
endtask

//------------------------------------------------------------------------------
// aoc_verify: Check answer and report results
//------------------------------------------------------------------------------
task aoc_verify(
    input longint expected,
    input longint cycles_taken
);
    $display("[AoC] Answer: %0d", o_answer);
    $display("[AoC] Cycles: %0d (%.3f μs at 1 GHz)", cycles_taken, cycles_taken / 1000.0);

    if (expected != 0) begin
        if (o_answer == expected)
            $display("[AoC] PASS: Answer matches expected");
        else
            $error("[AoC] FAIL: Expected %0d, got %0d", expected, o_answer);
    end else begin
        $display("[AoC] (No expected value provided, skipping verification)");
    end
endtask

`endif // AOC_TASKS_SVH

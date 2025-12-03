`ifndef AOC_TASKS_SVH
`define AOC_TASKS_SVH

//==============================================================================
// AoC Reusable Test Tasks
//
// Include this file in your test module to get access to common test tasks.
// Usage: `include "aoc_tasks.svh"
//
// These tasks assume the following signals exist in the test module:
//   - clk       : logic (clock)
//   - i_data    : logic [7:0] (input data to DUT)
//   - i_valid   : logic (input valid signal)
//   - o_busy    : logic (backpressure from DUT)
//   - o_valid   : logic (output valid from DUT)
//   - o_answer  : logic [63:0] (answer from DUT)
//==============================================================================

// Stream a file byte-by-byte to the DUT
task automatic aoc_stream_file(input string filename);
    int fd;
    int char_in;

    fd = $fopen(filename, "rb");
    if (fd == 0) begin
        $error("[AoC] Failed to open input file: %s", filename);
        return;
    end

    $display("[AoC] Streaming file: %s", filename);

    @(negedge clk);
    i_valid = 1;

    while (!$feof(fd)) begin
        char_in = $fgetc(fd);
        if (char_in != -1) begin
            i_data = 8'(char_in);
            @(negedge clk);
            while (o_busy == 1) @(negedge clk);
        end
    end

    // Send final newline to flush any pending data
    i_data = 8'h0A;
    @(negedge clk);
    i_valid = 0;

    $fclose(fd);
    $display("[AoC] File streaming complete");
endtask

// Wait for DUT to produce a valid result with timeout
task automatic aoc_wait_for_result(input int timeout_cycles = 1000000);
    int cycle_count = 0;
    while (!o_valid && cycle_count < timeout_cycles) begin
        @(negedge clk);
        cycle_count++;
    end
    if (cycle_count >= timeout_cycles)
        $error("[AoC] Timeout waiting for result after %0d cycles", timeout_cycles);
    else
        $display("[AoC] Solution complete after %0d cycles", cycle_count);
endtask

// Initialize signals to default state
task automatic aoc_init();
    rst = 0;
    i_valid = 0;
    i_data = 0;
endtask

// Perform standard reset sequence
task automatic aoc_reset();
    rst = 0;
    #20;
    rst = 1;
    #10;
endtask

// Run a complete test: init, reset, stream file, wait for result, display answer
task automatic aoc_run_test(input string filename);
    aoc_init();
    aoc_reset();
    aoc_stream_file(filename);
    aoc_wait_for_result();
    #100;
    $display("[AoC] Final Answer: %0d", o_answer);
endtask

// Check answer against expected value
task automatic aoc_check_answer(input longint expected);
    if (o_answer == expected)
        $display("[AoC] PASS: Answer %0d matches expected", o_answer);
    else
        $error("[AoC] FAIL: Expected %0d, got %0d", expected, o_answer);
endtask

`endif // AOC_TASKS_SVH

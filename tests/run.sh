#!/usr/bin/env bash
# SagePocket test runner.
#
#   tests/run.sh          full suite (unit + host smoke + compile checks)
#   tests/run.sh host     host smoke test only
#
# Exit 0 on success, 1 on any failure.

set -u
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
SAGE="${SAGE:-sage}"
BUILD_DIR="build"
BOARD="waveshare_rp2350_lcd_1_47"
SDK="${SDK:-$ROOT/.deps/pico-sdk}"
SCRATCH="$(mktemp -d /tmp/sagepocket-test.XXXXXX)"
trap 'rm -rf "$SCRATCH"' EXIT

failures=0
passes=0

check() { # name, status
    if [ "$2" -eq 0 ]; then
        passes=$((passes + 1))
        echo "PASS: $1"
    else
        failures=$((failures + 1))
        echo "FAIL: $1"
    fi
}

# --- host smoke test: run the pico C with host stubs -----------------------

host_smoke() {
    echo "== host smoke test (SageBoot bring-up logic) =="
    local c="$SCRATCH/sageboot.c"
    if ! "$SAGE" --emit-pico-c boot/sageboot.sage -o "$c" 2>"$SCRATCH/emit.err"; then
        check "emit sageboot C" 1
        return
    fi
    check "emit sageboot C" 0

    # Build stub harness: real host libc headers + fake pico API.
    python3 - "$c" << 'PYEOF'
import sys
path = sys.argv[1]
src = open(path).read()
old = '''#include <stdint.h>
#include "pico/stdlib.h"
#include "hardware/adc.h"
#include "hardware/clocks.h"
#include "hardware/pio.h"
#include "hardware/spi.h"'''
new = '''#include <stdint.h>
#include <math.h>
#include <setjmp.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <dlfcn.h>
#include <stdatomic.h>
#include <semaphore.h>
#include <time.h>
#include <unistd.h>
#include <pthread.h>
#include "stubs.h"'''
assert old in src, "pico include block not found"
open(path, "w").write(src.replace(old, new))
PYEOF

    cat > "$SCRATCH/stubs.h" << 'STUBH'
void stdio_init_all(void);
void sleep_ms(unsigned int);
STUBH

    cat > "$SCRATCH/stubs.c" << 'STUBC'
#include "stubs.h"
void stdio_init_all(void) { }
void sleep_ms(unsigned int ms) { (void)ms; }
STUBC

    cat > "$SCRATCH/stub_hw.h" << 'STUBHW'
#pragma once
#include <string.h>
typedef unsigned int uint;
#define clk_sys 0
static int gpio_put(unsigned int p, int v) { (void)p; (void)v; return 0; }
static int gpio_get(unsigned int p) { (void)p; return 0; }
static void gpio_init(unsigned int p) { (void)p; }
static void gpio_set_dir(unsigned int p, int d) { (void)p; (void)d; }
static void gpio_set_pulls(unsigned int p, int u, int d) { (void)p; (void)u; (void)d; }
static unsigned int clock_get_hz(int c) { (void)c; return 150000000u; }
static unsigned int to_ms_since_boot(unsigned int t) { (void)t; return 0; }
static unsigned int get_absolute_time(void) { return 0; }
static void sleep_us(unsigned int us) { (void)us; }
typedef struct { int dummy; } uart_inst_t;
static uart_inst_t uart0;
static void uart_init(uart_inst_t* u, unsigned int b) { (void)u; (void)b; }
static void uart_putc_raw(uart_inst_t* u, char c) { (void)u; (void)c; }
static int uart_is_readable(uart_inst_t* u) { (void)u; return -1; }
static int uart_getc(uart_inst_t* u) { (void)u; return -1; }
static void gpio_set_function(unsigned int p, int f) { (void)p; (void)f; }
#define GPIO_FUNC_UART 2
static void adc_init(void) {}
static void adc_gpio_init(unsigned int p) { (void)p; }
static void adc_select_input(unsigned int i) { (void)i; }
static unsigned int adc_read(void) { return 0; }
static void adc_set_temp_sensor_enabled(int e) { (void)e; }
typedef struct { const unsigned short* instructions; unsigned char length; signed char origin; unsigned char pio_version; unsigned char used_gpio_ranges; } pio_program_t;
typedef struct { int pio_version; } pio_hw_t;
static pio_hw_t pio0;
static unsigned int pio_claim_unused_sm(pio_hw_t* p, int h) { (void)p; (void)h; return 0; }
static unsigned int pio_add_program(pio_hw_t* p, const pio_program_t* prog) { (void)p; (void)prog; return 0; }
static void pio_gpio_init(pio_hw_t* p, unsigned int g) { (void)p; (void)g; }
static void pio_sm_set_consecutive_pindirs(pio_hw_t* p, unsigned int sm, unsigned int pin, unsigned int n, int out) { (void)p;(void)sm;(void)pin;(void)n;(void)out; }
typedef struct { int dummy; } pio_sm_config;
static pio_sm_config pio_get_default_sm_config(void) { pio_sm_config c; memset(&c,0,sizeof(c)); return c; }
static void sm_config_set_sideset(pio_sm_config* c, int bits, int opt, int pindirs) { (void)c;(void)bits;(void)opt;(void)pindirs; }
static void sm_config_set_wrap(pio_sm_config* c, int t, int w) { (void)c;(void)t;(void)w; }
static void sm_config_set_out_shift(pio_sm_config* c, int right, int autopull, int thresh) { (void)c;(void)right;(void)autopull;(void)thresh; }
static void sm_config_set_fifo_join(pio_sm_config* c, int j) { (void)c;(void)j; }
static void pio_sm_init(pio_hw_t* p, unsigned int sm, unsigned int off, const pio_sm_config* c) { (void)p;(void)sm;(void)off;(void)c; }
static void pio_sm_set_enabled(pio_hw_t* p, unsigned int sm, int e) { (void)p;(void)sm;(void)e; }
static void pio_sm_put_blocking(pio_hw_t* p, unsigned int sm, unsigned int v) { (void)p;(void)sm;(void)v; }
#define PIO_FIFO_JOIN_TX 2
#define pio_x 1
STUBHW

    if ! gcc -std=c11 -O0 -w "$c" "$SCRATCH/stubs.c" -o "$SCRATCH/sageboot-host" -lm -lpthread -ldl 2>"$SCRATCH/gcc.err"; then
        check "compile host harness" 1
        return
    fi
    check "compile host harness" 0

    local out
    out="$(timeout 3 stdbuf -o0 "$SCRATCH/sageboot-host" 2>&1)"
    if [ $? -ne 124 ]; then
        check "sageboot host run stays in main loop" 1
    else
        check "sageboot host run stays in main loop" 0
    fi

    for expect in "SageBoot" "Arch:" "Clock:" "UART0: PASS" "RGB LED: PASS" "LCD: ST7789V3 init FAIL" "SD: NOT AVAILABLE" "SageBoot Phase 4 bring-up complete" "Boot menu:" "Boot: no SAGEOS.KRN on storage, staying in boot console"; do
        if echo "$out" | grep -qF "$expect"; then
            check "sageboot output contains '$expect'" 0
        else
            check "sageboot output contains '$expect'" 1
        fi
    done
}

# --- kernel smoke: SageOS scheduler demo runs on host stubs -----------------

kernel_smoke() {
    echo "== kernel smoke test (SageOS scheduler demo) =="
    local c="$SCRATCH/kdemo.c"
    if ! "$SAGE" --emit-pico-c kernel/demo.sage -o "$c" 2>"$SCRATCH/kdemo.err"; then
        check "emit kernel demo C" 1
        return
    fi
    check "emit kernel demo C" 0

    python3 - "$c" << 'PYEOF'
import sys
path = sys.argv[1]
src = open(path).read()
old = '''#include <stdint.h>
#include "pico/stdlib.h"
#include "hardware/adc.h"
#include "hardware/clocks.h"
#include "hardware/pio.h"
#include "hardware/spi.h"'''
new = '''#include <stdint.h>
#include <math.h>
#include <setjmp.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <dlfcn.h>
#include <stdatomic.h>
#include <semaphore.h>
#include <time.h>
#include <unistd.h>
#include <pthread.h>
#include "stub_hw.h"
#include "stubs.h"'''
assert old in src, "pico include block not found"
open(path, "w").write(src.replace(old, new))
PYEOF

    if ! gcc -std=c11 -O0 -w "$c" "$SCRATCH/stubs.c" -o "$SCRATCH/kdemo-host" -lm -lpthread -ldl 2>"$SCRATCH/kdemo-gcc.err"; then
        check "compile kernel demo host" 1
        return
    fi
    check "compile kernel demo host" 0

    local out
    out="$(timeout 20 "$SCRATCH/kdemo-host" 2>&1)"
    for expect in "alpha: tick 100" "demo: alpha=100 beta=20 delivered=20" "demo: done"; do
        if echo "$out" | grep -qF "$expect"; then
            check "kdemo output contains '$expect'" 0
        else
            check "kdemo output contains '$expect'" 1
        fi
    done
}

# --- unit tests: pure-Sage files run in the interpreter --------------------

unit_tests() {
    echo "== unit tests (interpreter) =="
    local f out
    for f in tests/unit/*.sage; do
        [ -e "$f" ] || continue
        if out="$("$SAGE" "$f" 2>&1)"; then
            local expect
            for expect in $(sed -n 's/^# *expect: *//p' "$f"); do
                if echo "$out" | grep -qF "$expect"; then
                    check "unit $(basename "$f") '$expect'" 0
                else
                    check "unit $(basename "$f") '$expect'" 1
                fi
            done
            check "unit $(basename "$f") runs" 0
        else
            check "unit $(basename "$f") runs" 1
        fi
    done
}

# --- sagefs smoke: SageFS demo runs in the interpreter ----------------------

sagefs_smoke() {
    echo "== sagefs smoke test (VFS + FAT32 over RAM disk) =="
    local out
    if out="$("$SAGE" sagefs/demo.sage 2>&1)"; then
        check "sagefs demo runs" 0
    else
        check "sagefs demo runs" 1
        return
    fi
    for expect in "mounted 2 volumes" "hello read back: hello sagefs" \
                  "big file read back 1000 bytes ok" "nested read ok" \
                  "subdir listing ok" "rmdir verified" "fd seek ok" \
                  "demo done"; do
        if echo "$out" | grep -qF "$expect"; then
            check "sagefs demo '$expect'" 0
        else
            check "sagefs demo '$expect'" 1
        fi
    done
}

# --- compile checks: every Sage file must build for the target board --------

compile_checks() {
    echo "== pico compile checks (ARM) =="
    local f dir name
    for f in boot/sageboot.sage kernel/hal.sage kernel/kernel.sage kernel/demo.sage drivers/lcd/st7789v3.sage drivers/sd/sd_spi.sage drivers/fs/fat32.sage; do
        name="$(basename "$f" .sage)"
        if "$SAGE" --compile-pico "$f" -o "$SCRATCH/$name" \
                --name "$name" --board "$BOARD" --chip rp2350-arm \
                --sdk "$SDK" --board-dir boards >/dev/null 2>"$SCRATCH/$name.err"; then
            check "compile $f (ARM)" 0
        else
            check "compile $f (ARM)" 1
        fi
    done
}

# --- runner ------------------------------------------------------------------

if [ "${1:-}" = "host" ]; then
    host_smoke
else
    host_smoke
    kernel_smoke
    sagefs_smoke
    unit_tests
    compile_checks
fi

echo
echo "tests: $passes passed, $failures failed"
[ "$failures" -eq 0 ]

# Towers of Hanoi — CPE 487 Final Project

---
## Description

This project implements a playable **Towers of Hanoi** game on an FPGA using **VHDL** and renders the game on a **VGA monitor** (800×600 @ ~60 Hz). The player moves an on-screen selector arrow between three rods and uses a button to **pick up** and **drop** disks while obeying the classic Hanoi rule (you can’t place a larger disk on a smaller disk).

What’s implemented in the provided source:

* **3 rods** drawn on VGA
* **4 disks** (different widths + colors)
* **Arrow selector** to choose a rod (left / middle / right)
* **Pick / drop** interaction using one button
* **Move counter** (4-digit BCD) drawn on-screen (top-right)
* Automatic **reset after a win** (all disks on the right rod)

---
### Objective

Move all 4 disks from the **left rod** to the **right rod**:

* Move only **one disk at a time**
* You can only move the **top** disk from a rod
* You may **not** place a larger disk on top of a smaller disk
<br> <br>
	![](https://github.com/Dennis3204/vhdl-tower-of-hanoi/blob/main/img/tower.jpg)
---
### Controls

* **BTNL**: Move selector arrow to the **left** rod
* **BTNR**: Move selector arrow to the **right** rod
* **BTN0**: Action button

  * If no disk is selected: **pick up** the top disk from the selected rod
  * If a disk is selected: **drop** it onto the selected rod (only if valid)


---
## Required Hardware

* A Xilinx FPGA board with:

  * **100 MHz system clock input**
  * **VGA output** (RGB + HSYNC + VSYNC)
  * **Push buttons** mapped to `btnl`, `btnr`, `btn0`

Also needed:

* **VGA monitor + VGA cable** (or adapter)

---
## Files in This Repo

```text
towers.vhd               -- top-level: wires clocking + VGA + arrow/game module
arrow.vhd                -- main game: rods + disks + logic + on-screen counter
counter.vhd              -- draws the move counter digits on VGA (counter_display)
vga_sync.vhd             -- VGA timing generator (800x600 @ 60Hz style timings)
clk_wiz_0.vhd             \
clk_wiz_0_clk_wiz.vhd      -- Vivado clock wizard IP wrapper (pixel clock)
```


---
## Images / Diagrams

#### Module Diagram (logical)

```text
                +-------------------+
clk_in (100MHz) |      towers       |
btnl/btnr/btn0  |                   |
                |  +-------------+  |
                |  | clk_wiz_0   |--> pxl_clk (~40MHz)
                |  +-------------+  |
                |         |         |
                |  +-------------+  |      +------------------+
                |  |   arrow     |--|RGB-->|    vga_sync       |--> VGA RGB/HS/VS
                |  | (game+gfx)  |  |      | (timing+blanking) |
                |  +-------------+  |<-----| pixel_row/col     |
                +-------------------+
```

---
## Steps to Run (Vivado)

1. Create a **new Vivado project** for your board (pick the correct FPGA part).
2. Add these source files:

   * `towers.vhd`
   * `arrow.vhd`
   * `counter.vhd`
   * `vga_sync.vhd`
   * `clk_wiz_0.vhd`
   * `clk_wiz_0_clk_wiz.vhd`
3. Add constraints file:

   * `towers.xdc`
4. Run:

   * **Synthesis**
   * **Implementation**
   * **Generate Bitstream**
5. Open **Hardware Manager** → Program device.
6. Connect VGA display and play.

---
## Gameplay Notes (How the VHDL Implements Hanoi)

### Rod positions (hardcoded)

In `arrow.vhd`, rods are centered at:

* Left: `x = 200`
* Middle: `x = 400`
* Right: `x = 600`

### Disk model

* 4 disks indexed `0..3`
* Widths: `(30, 40, 50, 60)` pixels
* Height: `20` pixels
* Each disk has:

  * `rod` (0/1/2)
  * `stack_pos` (0..3)

### Pick / drop logic

* Game state updates on `rising_edge(v_sync)` (frame tick)
* BTN0 rising edge triggers:

  * **Pick**: selects the top disk on the current rod
  * **Drop**: checks size rule, updates rod + stack position, increments move counter

### Win condition

When all disks are on rod 2 (right rod), the game:

* resets disk positions back to the left rod
* waits until the next BTN0 press to clear the move counter

---
## Inputs and Outputs
---
## `towers.vhd`

This is the project’s top-level module. It connects the clock wizard, VGA timing module, and the game/rendering module, and it handles the left/right button logic that selects which rod the arrow points to.

### Inputs

* `clk_in` — system clock (expected 100 MHz)
* `btnl`, `btnr` — move the arrow selector between rods
* `btn0` — pick/drop disk action

### Outputs

* `VGA_red[3:0]`, `VGA_green[3:0]`, `VGA_blue[3:0]` — VGA color outputs
* `VGA_hsync`, `VGA_vsync` — VGA sync outputs
* `SEG7_anode[7:0]`, `SEG7_seg[6:0]` — declared, **not driven** in the current file set (see “Limitations”)

### What it does

* Instantiates `clk_wiz_0` to generate the pixel clock used by `vga_sync`
* Tracks the current rod index (0/1/2) using BTNL/BTNR rising edges
* Snaps `arrowpos` to rod centers (200/400/600)
* Instantiates:

  * `arrow` (game logic + pixel coloring)
  * `vga_sync` (timing + pixel coordinates)

---

## `arrow.vhd`

This is the core of the game. This file holds all Towers of Hanoi rules/state and also draws the entire scene (rods, arrow, disks) plus the move counter overlay.
### Inputs

* `v_sync` — used as the “game tick” (updates once per frame)
* `pixel_row[10:0]`, `pixel_col[10:0]` — current pixel coordinates from `vga_sync`
* `arrow_x[10:0]` — selector x-position (from `towers.vhd`)
* `btn0` — pick/drop action

### Outputs

* `red`, `green`, `blue` — **1-bit** “is this pixel on?” signals (later expanded to 4-bit in `towers.vhd`)
* `counter[15:0]` — move counter (BCD, 4 digits)

### What it does

* Draws:

  * rods + bases
  * arrow (inverted triangle)
  * disks (colored)
  * counter digits (via `counter_display`)
* Holds all game state:

  * disk positions
  * selected disk
  * move counter + reset behavior


---
## `counter.vhd`

This is a VGA overlay renderer for the move counter. It turns the 4-digit BCD move count into on-screen digits by asserting counter_on for pixels that belong to the counter glyphs.
### Inputs

* `pixel_row[10:0]`, `pixel_col[10:0]` — pixel coordinates
* `count_value[15:0]` — 4-digit **BCD** move counter

### Outputs

* `counter_on` — asserted when current pixel is part of the counter glyphs

### What it does

* Renders a 4-digit 7-segment-style counter near the top-right (start position is set by constants in the file)


---
## `vga_sync.vhd`

This is the VGA timing generator. This module creates HSYNC/VSYNC pulses and exposes pixel coordinates so other modules can draw per-pixel graphics.
### Inputs

* `pixel_clk` — pixel clock (from `clk_wiz_0`)
* `red_in[3:0]`, `green_in[3:0]`, `blue_in[3:0]` — intended RGB inputs

### Outputs

* `red_out[3:0]`, `green_out[3:0]`, `blue_out[3:0]`
* `hsync`, `vsync`
* `pixel_row[10:0]`, `pixel_col[10:0]`

### What it does

* Generates VGA sync pulses and “video_on” blanking
* Exposes pixel coordinates to drive per-pixel drawing logic
* Uses timing constants consistent with an 800×600-style mode

---
## `clk_wiz_0.vhd` / `clk_wiz_0_clk_wiz.vhd`

This is the Vivado Clock Wizard wrapper module. It’s the interface-level file Vivado generates so your design can consume a stable pixel clock.
### Inputs

* `clk_in1` — 100 MHz board clock

### Outputs

* `clk_out1` — pixel clock (generated by MMCM)

### What it does

* Vivado Clock Wizard IP wrapper to derive the VGA pixel clock needed by `vga_sync`

<br><br>
---

## Contributions

* `clk_in1` — 100 MHz board clock

### Dennis Ren:

* 

### Dritan Xhelilaj:

* 

<br><br>

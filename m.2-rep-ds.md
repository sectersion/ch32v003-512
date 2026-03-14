# M.2 Main Receptacle Datasheet

**Project:** STASIS 512-core CH32V003 Compute Cluster  
**Connector type:** M.2 Key A/E, 75-pin  
**Instance count:** 4 (J_COL0 – J_COL3) on stasis_backplane.kicad_sch  
**Revision:** 0.1  

---

## Overview

The M.2 Key A/E receptacle is the primary interface between the STASIS backplane and each column board. Each column board plugs into one receptacle as a removable card. The connector carries SPI communication from the host MCU, 3.3V power for the column controller, system control signals, and ground.

Power for the bulk of the column board (slot routers, module boards, LED chain) is supplied independently via a USB-C connector on the column board itself. The M.2 connector does not carry 5V.

---

## Electrical characteristics

| Parameter | Value |
|---|---|
| Interface voltage | 3.3V logic |
| Max 3.3V current (per connector) | ~150mA (column controller only) |
| SPI clock max | 36MHz (CH32V307 SPI1 limit) |
| Signal standard | LVCMOS 3.3V |
| ESD protection | Recommended on SPI lines, 15kV HBM minimum |

---

## Pin definitions

Key A/E uses a 75-pin connector. Pins are numbered per the M.2 specification. Only pins relevant to this design are assigned; all others are No Connect.

### Power and ground

| Pin(s) | Net | Description |
|---|---|---|
| 2, 4, 32, 50, 68 | GND | Ground. All connected to backplane GND pour. |
| 3, 5 | 3V3_MAIN | 3.3V supply from backplane. Powers CH32V307 column controller only. ~150mA max. |
| 7, 9 | NC | 5V pins. No connect — column board supplies its own power via USB-C. |

### SPI bus

All four column receptacles share CLK, MOSI, and MISO. CS is individual per column.

| Pin | Net | Direction | Description |
|---|---|---|---|
| 22 | SPI_H_CLK | Backplane → Column | SPI1 clock from host CH32V307 (PA5). Shared across all 4 receptacles. |
| 24 | SPI_H_MOSI | Backplane → Column | SPI1 master out from host MCU (PA7). Shared across all 4 receptacles. |
| 26 | SPI_H_MISO | Column → Backplane | SPI1 master in to host MCU (PA6). Wired-OR across all 4 receptacles — only the selected column drives this line. Add 100kΩ pull-down on backplane side. |
| 28 | SPI_CS_COL0 | Backplane → Column | Individual chip select for J_COL0. Driven by host MCU PA4. Active low. |
| 28 | SPI_CS_COL1 | Backplane → Column | Individual chip select for J_COL1. Driven by host MCU PA3. Active low. |
| 28 | SPI_CS_COL2 | Backplane → Column | Individual chip select for J_COL2. Driven by host MCU PA2. Active low. |
| 28 | SPI_CS_COL3 | Backplane → Column | Individual chip select for J_COL3. Driven by host MCU PA1. Active low. |

> Note: CS pins use the same M.2 pin number in the table above for brevity. Each receptacle J_COL0–J_COL3 has its own physical connector and its own CS net.

### Control signals

| Pin | Net | Direction | Description |
|---|---|---|---|
| 34 | SYS_NRST | Backplane → Column | Active-low system reset. Shared across all 4 receptacles. Driven by host MCU PC0. 100nF cap to GND and 10kΩ pull-up on backplane side. |
| 36 | SYS_FAULT | Bidirectional | Open-drain fault indicator. Any board on the system can assert this low to signal a fault condition. Shared globally. 10kΩ pull-up to 3V3_MAIN on backplane. |

### Reserved and no connect

| Pin(s) | Assignment | Notes |
|---|---|---|
| 6, 8, 10 | NC | 5V pins. No connect. Add NC flag in KiCad. |
| 38, 40 | RESERVED | DNP 0Ω pads for future use. Do not connect. |
| All others | NC | Add No Connect flags in KiCad schematic to suppress ERC warnings. |

---

## Typical operation

### Startup sequence

1. Backplane ATX PSU asserts 3V3_MAIN. All column controller CH32V307s power up via the M.2 connector.
2. Host MCU CH32V307 completes boot. SYS_NRST releases high.
3. Host MCU asserts SPI_CS_COLx low and begins polling each column controller over SPI.
4. Column controllers respond with status: whether USB-C power is present, how many slots are populated, fault states.
5. If USB-C is connected on a column board, the column controller reports downstream power good. Host MCU can then begin scheduling compute tasks to that column.

### SPI transaction model

The host MCU is SPI master. Each column controller is SPI slave, selected by its individual CS line. Only one column is selected at a time. The host cycles through columns in round-robin or priority order depending on workload.

MISO is wired-OR across all four receptacles on the backplane. The non-selected columns must hold MISO high-impedance (CS high = SPI slave output disabled on CH32V307). A 100kΩ pull-down on the backplane MISO line ensures the net is defined when no column is selected.

### Fault handling

SYS_FAULT is open-drain and shared across every board in the system via a global label. Any board — backplane, column, or future expansion — can assert SYS_FAULT low to indicate an unrecoverable error such as overcurrent, thermal shutdown, or communication failure. The host MCU monitors SYS_FAULT on PC1 and halts all SPI transactions when asserted, then polls each column controller individually to identify the faulting board.

### Hot-swap / removal

Column boards are designed to be removable while the backplane is powered. Safe removal procedure:

1. Host MCU detects STATUS pin deassert (or user initiates soft eject via software).
2. Host MCU stops all SPI traffic to that column's CS line.
3. Column controller asserts PWR_EN low on all 8 AP2141 switches, cutting power to module boards.
4. Column controller reports power-down complete to host MCU.
5. Column board can now be physically removed.

Do not remove a column board without following this sequence — hot-pulling under load may cause inrush damage to the AP2141 switches on the module slots.

---

## KiCad schematic notes

- Place one receptacle symbol per column: J_COL0 through J_COL3.
- All GND pins must connect to a GND power symbol — do not leave any floating.
- Add PWR_FLAG on the 3V3_MAIN net at each receptacle to suppress ERC power pin warnings.
- SPI_CS_COLx nets must be unique per receptacle. All other SPI and control nets are shared.
- SYS_FAULT must use a Global Label, not a Net Label, so it connects across all schematic sheets.
- Add No Connect flags on all unused pins before running ERC. Expect zero errors on this sheet when complete.

---

## Related sheets and projects

| Sheet / Project | Relationship |
|---|---|
| `host.kicad_sch` | Source of SPI_H_* and SPI_CS_COL* nets |
| `backplane_psu.kicad_sch` | Source of 3V3_MAIN and 5V_ATX |
| `stasis_column` (separate project) | Plugs into this receptacle — edge fingers are the mating connector |
| `backplane_leds.kicad_sch` | Consumes SYS_FAULT and PWR_GOOD globals |

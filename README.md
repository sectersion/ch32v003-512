# STASIS — 512-Core CH32V003 RISC-V Compute Cluster

> A massively parallel, modular RISC-V compute cluster built from 512 CH32V003 microcontrollers, designed for neural network inference, extremely slow graphics rendering, and embarrassingly parallel workloads.

![Status](https://img.shields.io/badge/status-in%20development-orange)
![Cores](https://img.shields.io/badge/cores-512-blue)
![MCUs](https://img.shields.io/badge/total%20MCUs-549-blueviolet)
![LEDs](https://img.shields.io/badge/LEDs-829-yellow)
![License](https://img.shields.io/badge/license-MIT-green)

---

## Overview

CH32V003512 is a custom compute cluster built entirely from WCH CH32V003 RISC-V microcontrollers. 512 worker cores are organized across 32 hot-swappable modules, connected via a hierarchical SPI fabric to a host MCU that interfaces with a PC over USB. The system is designed for parallel workloads including neural network inference, raytracing, cellular automata, and any embarrassingly parallel computation.

I created this project inspired by [bitluni's lab](https://bitluni.net/) take on a ch32v003 cluster. The architecture was inspired by my prior knowledge of chip design. My goal is to emulate tiny distributed computing in an easy to understand way.

This project was built for [Hack Club Stasis](https://stasis.hackclub.com).

---

## Architecture

```
PC (USB/Serial)
└── Host MCU — CH32V307 (USB-HS)
    └── SPI Bus
        ├── Column Controller 0 — CH32V307
        │   ├── PSU (5V → 3.3V, ~5A)
        │   └── Slot Router ×8 — CH32V203
        │       └── 16× CH32V003 Worker Cores (via SPI ring)
        ├── Column Controller 1 — CH32V307
        ├── Column Controller 2 — CH32V307
        └── Column Controller 3 — CH32V307
```

### MCU Roles

| Role | MCU | Count | Notes |
|---|---|---|---|
| Worker Core | CH32V003J4M6 (QFN-20) | 512 | 3×3mm, 48MHz, 2KB RAM |
| Slot Router | CH32V203C8T6 (QFN-48) | 32 | Dual SPI + DMA, manages 16 workers |
| Column Controller | CH32V307VCT6 | 4 | FPU, manages 8 slot routers + PSU |
| Host MCU | CH32V307VCT6 | 1 | USB-HS to PC, top-level scheduler |
| **Total** | | **549** | |

---

## Hardware

### System Boards

| Board | Qty | Description |
|---|---|---|
| **Module Board** | 32 | 16× CH32V003 workers, M.2 Key B edge connector, 20 LEDs |
| **Backplane** | 1 | 4 removable columns using M.2 Key B, host MCU, system status LEDs, ATX power input |
| **Column Board** | 4 | 8× M.2 slots, CH32V307 column controller, CH32V203 slot routers, PSU |
| **Programmer Board** | 1 | Programs one module at a time via SWD, separate project |

NOTE: May need 2 seperate programmer boards for columns and compute modules, because they don't follow the same pin layout.

### Module Board

- **Size**: M.2 2260 (22×60mm), 4-layer PCB
- **Workers**: 16× CH32V003J4M6 in QFN-20 (3×3mm each)
- **Interface**: M.2 Key B, 0.5mm pin pitch
- **LEDs**: 16× green per-worker activity + 4× status (power, SPI, reset, ready)
- **Topology**: SPI daisy-chain ring, slot router as master

### Backplane

- **Columns**: 4× removable column boards via M.2 Key A/E connector
- **Power**: ATX PSU input, per-column regulation
- **Host MCU**: CH32V307 with USB-HS
- **LEDs**: Per-slot status (128), per-column status (20), system status bank (20)
- **Hot-swap**: Per-slot AP2141 load switch, soft-eject protocol

### M.2 Module Pinout (Key B, 75 pins)

| Signal | Pins | Notes |
|---|---|---|
| GND | 11 | Distributed |
| 3.3V | 9 | ~4.5A capacity |
| SPI (CLK, MOSI, MISO, CS) | 4 | Slot router ↔ module ring master |
| NRST_ALL | 1 | Global worker reset |
| STATUS | 1 | Module insertion detect |
| SLOT_ID[0:4] | 5 | 5-bit address strapping (32 slots) |
| PWR_EN | 1 | Hot-swap load switch enable |
| PWR_GOOD | 1 | Power good feedback |
| RESERVED | 2 | Future expansion |

> SWD is handled entirely on the backplane by the CH32V203 slot router.  
> No SWD signals cross the M.2 connector during normal operation.

---

## LED Map

| Location | Count | Colors | Purpose |
|---|---|---|---|
| Per worker (×512) | 512 | Green | Computation activity |
| Per module status (×32) | 128 | R/B/Y/W | Power, SPI, reset, ready |
| Backplane per-slot (×32) | 128 | G/B/R/Y | Slot power, traffic, fault, programming |
| Backplane per-column (×4) | 20 | G/R/B/Y/W | PSU, controller, busy, idle |
| Backplane system status | 20 | Various | USB, SPI bus, power rails, fault |
| Programmer board | 21 | Various | Programming status per worker |
| **Total** | **829** | | |

---

## Software / SDK

A custom SDK is being developed targeting all tiers of the hierarchy:
It will be a combination of a custom compiler, communications package and flasher, and will have a 80-120 instruction set for programming the workers. The compiler will generate the code into arduino .INO files, the flasher will autonomously flash the worker and column modules. The communications package is in charge of talking to the main MCU using Serial via USB. It is a very heavy SDK for a very heavy board. The board will probably weight like 5 pounds.


### Workload Model

Jobs are tiled into small packets (<512 bytes) to fit within router SRAM constraints. The host PC dispatches job tiles down the hierarchy:

```
PC -> Host MCU -> Column Controller -> Slot Router -> Worker Core
                                                  |
PC <- Host MCU <- Column Controller <- Slot Router <- Result
```

---

## BOM Summary

| Category | Approx. Cost |
|---|---|
| Worker MCUs (512× CH32V003) | ~$61 |
| Slot routers (32× CH32V203) | ~$16 |
| Column controllers + host (5× CH32V307) | ~$12.50 |
| PCBs (JLC, 4-layer) | TBD |
| PCBA assembly | TBD |
| M.2 connectors (×32 module + ×4 column) | TBD |
| Passives, LEDs, power components | TBD |
| 5-port USB-C power brick | ~$30 |
| **Estimated Total** | **$500–1500** |

---

## Project Status

- [x] System architecture defined
- [x] MCU selection finalized
- [x] M.2 pinout spec complete
- [x] LED strategy defined
- [x] KiCad schematic — top level hierarchy
- [x] KiCad schematic — module board
- [ x KiCad schematic — backplane
- [WIP] KiCad schematic — column board
- [ ] KiCad schematic — programmer board
- [ ] PCB layout — module board
- [ ] PCB layout — backplane
- [ ] PCB layout — column board
- [ ] Bring-up and testing
- [ ] SDK — worker firmware
- [ ] SDK — router/controller firmware
- [ ] SDK — PC interface
- [ ] Compute kernels

---

## Tools & Fabrication

- **EDA**: KiCad 9
- **PCB Fab**: JLCPCB (4-layer and 2-layer, PCBA)
- **Programming**: Custom programmer board (separate project)
- **Languages**: C (firmware), Python / C++ / Rust (host SDK)

---

## Inspiration

Heavily inspired by bitluni's CH32V003 cluster. STASIS scales the concept to 512 cores with a structured hierarchical fabric, hot-swap modules, custom tooling, and a full SDK.

---

## License

MIT License — see [LICENSE](LICENSE) for details.

---

## Author

Built for Hack Club Stasis.  
If you're reading this and you've also built something unhinged out of cheap RISC-V chips, let's talk.

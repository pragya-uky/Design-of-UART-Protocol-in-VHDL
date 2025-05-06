# Design-of-UART-Protocol-in-VHDL#
Implementation of a Universal Asynchronous Receiver-Transmitter (UART) using VHDL. The design includes modules for transmitting and receiving serial data, a baud rate generator, and a top-level module for integration.

## Features:
- 32 bit control and status registers.
- 8 bit transmission without parity bit

## Communication Module Registers

| Register Name          | Bits (Bit Range)         | Description                                              |
|------------------------|--------------------------|----------------------------------------------------------|
| **Transmitter**        |                          |                                                          |
| TX_BAUD_DIVISOR_SEL    | 3 - 0                    | Baud divisor select                                      |
| TX_CONTROL             | 8: fifo tx_wr_en         | FIFO transmit write enable                               |
|                        | 4: reset_tx              | Reset transmitter                                        |
|                        | 0: TX_ENABLE             | Enable transmitter                                      |
| TX_STATUS              | 8: tx_fifo_full          | Transmitter FIFO full status                             |
|                        | 4: tx_fifo_almost_full   | Transmitter FIFO almost full status                      |
|                        | 0: tx_ongoing            | Transmitter ongoing status                               |
| **Receiver**           |                          |                                                          |
| RX_BAUD_DIVISOR_SEL    | 3 - 0                    | Baud divisor select                                      |
| RX_CONTROL             | 8: fifo rx_rd_en         | FIFO receive read enable                                 |
|                        | 4: reset_rx              | Reset receiver                                           |
|                        | 0: RX_ENABLE is TX_READY | Enable receiver (when transmitter is ready)              |
| RX_STATUS              | 12: rx_fifo_almost_full  | Receiver FIFO almost full status                          |
|                        | 8: rx_fifo_empty         | Receiver FIFO empty status                               |
|                        | 4: rx_fifo_almost_empty  | Receiver FIFO almost empty status                        |
|                        | 0: rx_error              | Receiver error status                                    |

## Baud Rate Selection

Use `BAUD_DIVISOR_SEL` to select the baud rate using the following key:

| Hex Value (BAUD_DIVISOR_SEL) | Baud Rate  |
|------------------------------|------------|
| `x"1"`                       | 2400       |
| `x"2"`                       | 4800       |
| `x"3"`                       | 9600       |
| `x"4"`                       | 14400      |
| `x"5"`                       | 19200      |
| `x"6"`                       | 28800      |
| `x"7"`                       | 38400      |
| `x"8"`                       | 57600      |
| `x"9"`                       | 76800      |
| `x"a"`                       | 115200     |
| `x"b"`                       | 230400     |
| `x"c"`                       | 460800     |
| `x"d"`                       | 921600     |
| `others`                     | 115200 (default) |

#rem_scan

## Open Source Scan Controller for SEMs

- PCB: https://github.com/stdlogicvector/rem_scan_pcb
- GUI: https://github.com/stdlogicvector/rem_scan_gui

The scan controller features two 16bit DACs to steer the electron beam of an SEM and two 16bit ADCs to acquire the image signal from up to two detectors.

It can be controlled via USB. The FTDI chip provides a virtual comport, a fast FIFO connection and a JTAG port for flashing the gateware.
Currently, only the serial port is supported in the gateware and the GUI.

Additionally, a VGA monitor can be connected for a live view of the image.
On PCBv1, only the internal blockram is used. This limits the resolution to 100x75 pixels. The image is upscaled to 800x600.

PCBv2 has external RAM and allows a native resolution of 800x600.

## Commands

The FPGA is controlled with a 921600bps 8N1 serial connection with hardware flow control.

All commands and replies are encapsulated in { }.

If a command does not return data, the reply is just an ACK which is represented by an ! .

If a command is not recognized, a ? will be sent, which represents a NACK.

The following commands are available:

  - {S}: Scan an image. This command is special in that it is followed by image data instead of an ACK or {} reply.
  - {L}: Activate live preview.
  - {X}: Abort scan/live mode.
  - {Rhh}: Read register 0xhh. Reply contains contents of register {Rhhhh}.
  - {Whhdddd}: Write register 0xhh with 0xdddd.


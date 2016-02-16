*******************************************************
*
* DWWrite
*    Send a packet to the DriveWire server.
*    Serial data format:  1-8-N-1
*    4/12/2009 by Darren Atkinson
*
* Entry:
*    X  = starting address of data to send
*    Y  = number of bytes to send
*
* Exit:
*    X  = address of last byte sent + 1
*    Y  = 0
*    All others preserved
*


DWWrite_bkr
	  pshs      d,cc              ; preserve registers
txByte
          lda       ,x+
          sta       $FF42
          leay      -1,y                ; decrement byte counter
          bne       txByte              ; loop if more to send

          puls      cc,d,pc           ; restore registers and return


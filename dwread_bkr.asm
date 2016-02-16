*******************************************************
*
* DWRead
*    Receive a response from the DriveWire server.
*    Times out if serial port goes idle for more than 1.4 (0.7) seconds.
*    Serial data format:  1-8-N-1
*    4/12/2009 by Darren Atkinson
*
* Entry:
*    X  = starting address where data is to be stored
*    Y  = number of bytes expected
*
* Exit:
*    CC = carry set on framing error, Z set if all bytes received
*    X  = starting address of data received
*    Y  = checksum
*    U is preserved.  All accumulators are clobbered
*

* NOTE: There is no timeout currently on here...
DWRead_bkr
	  clra                          ; clear Carry (no framing error)
          deca                          ; clear Z flag, A = timeout msb ($ff)
          tfr       cc,b
          pshs      u,x,dp,b,a          ; preserve registers, push timeout msb
          leau   ,x
          ldx    #$0000
loop@     ldb    $FF41
          bitb   #$02
          beq    loop@
          ldb    $FF42
          stb    ,u+
          abx
          leay   ,-y
          bne    loop@
          tfr    x,y
          ldb    #0
          lda    #3
          leas      1,s                 ; remove timeout msb from stack
          inca                          ; A = status to be returned in C and Z
          ora       ,s                  ; place status information into the..
          sta       ,s                  ; ..C and Z bits of the preserved CC
          leay      ,x                  ; return checksum in Y
          puls      cc,dp,x,u,pc        ; restore registers and return



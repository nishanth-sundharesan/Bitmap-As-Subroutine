*-----------------------------------------------------------
* Title      : Bitmap as Subroutine
* Written by : Nishanth Sundharesan
* Date       : 23-Sept-2016
* Description: This program displays a chunk or the whole of a 256 color .bmp image on the screen by calling a subroutine.
*-----------------------------------------------------------
*----------------------------------------------------                  
*Parameters sent to the subroutine(All are in pixels)
*----------------------------------------------------
BITMAP_CHUNK_HEIGHT         EQU     480                     ;Change this EQU to vary the height of the image to be displayed
BITMAP_CHUNK_WIDTH          EQU     640                     ;Change this EQU to vary the width of the image to be displayed
BITMAP_CHUNK_TOPLEFT_X      EQU     0                   
BITMAP_CHUNK_TOPLEFT_Y      EQU     0                   
SCREEN_LOCATION_TOPLEFT_X   EQU     0                       ;Change this EQU to vary the X position of the image to be displayed on the screen
SCREEN_LOCATION_TOPLEFT_Y   EQU     0                       ;Change this EQU to vary the Y position of the image to be displayed on the screen
*----------------------------------------------------
*Parameters used in the subroutine
*----------------------------------------------------
PARAM_BITMAP_CHUNK_HEIGHT           EQU     24
PARAM_BITMAP_CHUNK_WIDTH            EQU     20
PARAM_BITMAP_CHUNK_TOPLEFT_X        EQU     16
PARAM_BITMAP_CHUNK_TOPLEFT_Y        EQU     12
PARAM_SCREEN_LOCATION_TOPLEFT_X     EQU     8
PARAM_SCREEN_LOCATION_TOPLEFT_Y     EQU     4
*----------------------------------------------------
*Constant values
*----------------------------------------------------
FILE_OFFSET_TO_PIXELARRAY_BYTES   EQU     10
SCREEN_WIDTH                      EQU     1000
SCREEN_HEIGHT                     EQU     800
*----------------------------------------------------
*Trap codes
*----------------------------------------------------
CLEAR_SCREEN_TRAP_CODE    EQU     11
PEN_COLOR_TRAP_CODE       EQU     80
DRAW_PIXEL_TRAP_CODE      EQU     82
SCREEN_SIZE_TRAP_CODE     EQU     33
*----------------------------------------------------

*Program starts here
START:  ORG    $1000
        *Clear the screen
        move.b  #CLEAR_SCREEN_TRAP_CODE,d0      
        move.l  #$FF00,d1                                   ;#$FF00 is to clear the whole screen
        TRAP    #15
        
        *Set the screen size
        move.l  #SCREEN_SIZE_TRAP_CODE,d0
        move.w  #SCREEN_WIDTH,d1                            ;Higher significant word should contain the width and the lower significant word should contain the height
        swap    d1
        move.w  #SCREEN_HEIGHT,d1
        TRAP    #15
        
        *Let's point the address register to the pixel array in the bmp image
        lea     ImageData,a0                                ;Load the image address to a0
        move.l  a0,a1
        adda    #FILE_OFFSET_TO_PIXELARRAY_BYTES,a0         ;Add the static file offset to reach the pixel array       
        move.l  (a0)+,d7                                    ;Move the offset address of the pixel array and increment the address register
        jsr     LittleToBigEndianLong                       ;Call the subroutine to convert the offset from Little Endian format to Big Endian format
        add.l   d7,a1                                       ;Add the offset to the current address. a1 now holds the address to the pixel array
                
        *a0 now points to the address where DIB's header size is placed
        move.l  a0,a2
        move.l  (a0)+,d7                                    ;Move the DIB's header size and increment the address register
        jsr     LittleToBigEndianLong                       ;Call the subroutine to convert the size from Little Endian format to Big Endian format
                                                            ;d7 now holds the size of the DIB header                                   
        add.l   d7,a2                                       ;Add the DIB header size to the current offset.
                                                            ;a2 will now hold the address to the color table
                
        *a0 now points to the image's width
        move.l  (a0)+,d7                                    ;Move the width of the image and increment the address register
        jsr     LittleToBigEndianLong                       ;Call the subroutine to convert the image width from Little Endian format to Big Endian format
        move.l  d7,d5                                       ;d5 now holds the width of the image
        
        *a0 now points to the image's height
        move.l  (a0),d7                                     ;Move the height of the image
        jsr     LittleToBigEndianLong                       ;Call the subroutine to convert the image height from Little Endian format to Big Endian format
        move.l  d7,d3                                       ;d3 now holds the height of the image
                                               
        *The pixel array stores the pixels in a table format with the dimensions of image width and height
        *Each row will be the size of the width in the multiples of 4.
        *Additional padding with 00 is added to make up the multiple of 4
        move.l  d5,d4                                       ;Move the image width to the data register
        divu.w  #$04,d4                                     ;Divide the image width by 4. Lower word = Quotient, Higher word = Remainder
        lsr.l   #$8,d4                                      ;Shift right by 2 bytes, to get only the remainder in the entire register
        lsr.l   #$8,d4                                      ;d4 will now hold the remainder

        *Calculate the padding that needs to be added using the remainder
        cmpi.w   #0,d4                                      ;Check if the width is a multiple of 4
        beq      DONTSUBTRACT                               ;Or else Subtract the remainder with 4 which will be used to increment the pixel array/add as padding
        move.l   d4,d6
        move.l   #4,d4                               
        sub.l    d6,d4                                      ;d4 will now hold the additional padding needed
        
        clr.l    d6
        
DONTSUBTRACT:        
        *Push the arguments onto the stack
        move.l  #BITMAP_CHUNK_HEIGHT,-(sp)
        move.l  #BITMAP_CHUNK_WIDTH,-(sp)        
        move.l  #BITMAP_CHUNK_TOPLEFT_X,-(sp)
        move.l  #BITMAP_CHUNK_TOPLEFT_Y,-(sp)
        move.l  #SCREEN_LOCATION_TOPLEFT_X,-(sp)
        move.l  #SCREEN_LOCATION_TOPLEFT_Y,-(sp)
        
        *Call the subroutine to display the chunk of the 256 color .bmp image                
        jsr DisplayChunkOfBMPImage                

        SIMHALT                                             ;Halt the simulator

*This subroutine converts a long from Little Endian format to Big Endian format(68000). It uses d7 register. 
LittleToBigEndianLong
        ror.w   #$8,d7                                      ;Rotate the word by 8 bits(less significant 16 bits)
        swap    d7                                          ;Swap higer word to lower word
        ror.w   #$8,d7                                      ;Rotate the word by 8 bits(less significant 16 bits)
        rts                                                 ;Return from subroutine

*This subroutine displays the chunk of the 256 color bitmap image.
DisplayChunkOfBMPImage
        move.l  PARAM_SCREEN_LOCATION_TOPLEFT_X(sp),d1              ;X screen coordinate now points to the bottom left corner of the chunk image
        move.l  PARAM_SCREEN_LOCATION_TOPLEFT_Y(sp),d2          
        add.l   PARAM_BITMAP_CHUNK_HEIGHT(sp),d2                    ;Y screen coordinate now points to the bottom left corner of the chunk image
                        
        *Let's move the address of the pixel array to the bottom left corner of the chunk image        
        *Moving the Y offset
        move.l  #0,d6                                               ;Use data register as a loop counter
        move.l  d3,d7                                               ;Move the height of the image
        sub.l   PARAM_BITMAP_CHUNK_TOPLEFT_Y(sp),d7                 ;Subtract the chunk's Y offset
        sub.l   PARAM_BITMAP_CHUNK_HEIGHT(sp),d7                    ;Subtract the chunk height
         
        cmp.l   d7,d6                                               ;If the height of the chunk image is greater than or equal to the image, then don't loop
        bge     DONTLOOP 
         
        *We will now get the number of times to increment the Y offset
LOOPBACK:
        add.l   d5,a1                                               ;Add the width of the image to the address of the pixel arrray
        add.l   d4,a1                                               ;Add the padding to make it a multiple of 4
        addi.l  #1,d6                                               ;Increment the loop counter
        cmp.l   d7,d6                                               ;Check if the loop counter has reached the Y offset, if not then loop back
        bne     LOOPBACK

DONTLOOP:       
        *Moving the X offset        
        add.l  PARAM_BITMAP_CHUNK_TOPLEFT_X(sp),a1                  ;For moving the X offset just add the chunk image's X position
        
        *Clear the registers. We will use them for holding temporary data
        clr.l   d6
        clr.l   d7
  
        *Calculating the width of the chunk to be drawn with respect to screen co-ordinates
        lea     WidthFromScreen,a3                                        
        move.l  PARAM_SCREEN_LOCATION_TOPLEFT_X(sp),(a3)            ;Move the Screen's X co-ordinate
        move.l  PARAM_BITMAP_CHUNK_WIDTH(sp),d6                     ;Move the chunk image's width
        add.l   d6,(a3)                                             ;Add both of them. a3 will now point to the width of the image to be drawn from the 0th position of screen
                                                                    
        
        *Calculating the remaining width of the image that has be incremented after drawing each row of pixels
        lea     RemainingWidthOfBMP,a4
        move.l  d5,(a4)                                             ;Move the width of the image
        sub.l   d6,(a4)                                             ;d6 already holds the width of the chunk image, subtract it
        move.l  PARAM_BITMAP_CHUNK_TOPLEFT_X(sp),d6                 
        sub.l   d6,(a4)                                             ;Subtract the chunk's X offset. a4 will now point to the remaining width of the image
    
        *Drawing of the pixels starts here
DRAWEACHROW:
        move.l  PARAM_SCREEN_LOCATION_TOPLEFT_X(sp),d7              ;d7 will contain the X corordinate of the screen             
          
DRAWEACHPIXEL:
        clr.l   d6
        
        move.b  (a1)+,d6                                    ;Load the offset address of the color table and increment the address register
        lsl.l   #$02,d6                                     ;Multiply the offset address by 4 because each color on color table is 4 bytes long
        move.l  (a2,d6),d1                                  ;Load the color of the pixel to data register. The color has to be in d1 register
        lsr.l   #$8,d1                                      ;Shift out the least significant byte because this byte is added for padding
                                                            ;Set the pen color. We now have the color of the pixel in BGR format
                                                            
        move.l  #PEN_COLOR_TRAP_CODE, d0                    ;Set the proper trap code to set the pen color
        trap    #15                                         ;Pen color is now set
        
        
        *Draw the pixel on the X,Y co-ordinate
        move.l  d7,d1                                       ;X co-ordinate should be kept in d1 register
                                                            ;Y co-ordinate should be kept in d2 register
        move.l  #DRAW_PIXEL_TRAP_CODE,d0                    ;Set the proper trap code to draw the pixel using the set pen color
        trap    #15
        
       *Increment the X co-ordinate
        addi    #1,d7

        cmp.l   (a3),d7                                     ;Check if the chunk width has been reached, if not continue drawing with the same row
        bne     DRAWEACHPIXEL
                
        *Increment the pixel array by the remaining width of the image
        add.l   (a4),a1
        
        *Increment the pixel array by adding the padding(each row should be a multiple of 4)
        add.l   d4,a1
        *Pixel array is now pointing to the beginning of the new row of the image
        
        *Add the X offset to draw pixels in the new row
        add.l  PARAM_BITMAP_CHUNK_TOPLEFT_X(sp),a1
        
        *Decrement the Y co-ordinate
        subi.l  #1,d2

        cmp.l   PARAM_SCREEN_LOCATION_TOPLEFT_Y(sp),d2      ;Check if the Y co-ordinate has reached the top most row of the image, if not draw another row.
        bne     DRAWEACHROW
                
        rts

ImageData               INCBIN   "WolfStartScreen.bmp"
WidthFromScreen         ds.l    1    
RemainingWidthOfBMP     ds.l    1
    END    START





















*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~

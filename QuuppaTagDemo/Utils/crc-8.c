//
//  crc-8.c
//  QuuppaTagDemo
//
//  Created by Quuppa on 25/02/15.
//  Copyright (c) 2015 Quuppa. All rights reserved.
//

#include "crc-8.h"
#include <inttypes.h>

#define CRC8POLY 0x97

#define WIDTH  8
#define TOPBIT (1 << (WIDTH - 1))

// used only internally here...
uint u8CRC(uint message, uint remainder) {
    // Bring the next byte into the remainder.
    remainder ^= message;
    
    // Perform modulo-2 division, a bit at a time.
    for (uint bit = 8; bit > 0; --bit){
        // Try to divide the current data bit.
        if (remainder & TOPBIT){
            remainder = (remainder << 1) ^ CRC8POLY;
        } else {
            remainder = (remainder << 1);
        }
    }
    
    // The final remainder is the CRC result.
    return (remainder);
}

uint8_t crc8(uint8_t *data, uint16_t size) {
    unsigned char u8Temp = 0;
    int i;
    for(i=0; i<size; i++)  {
        u8Temp = u8CRC(data[i], u8Temp);
    }
    return u8Temp;
}

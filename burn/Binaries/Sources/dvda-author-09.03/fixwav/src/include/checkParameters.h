#ifndef CHECKPARAMETERS_H_INCLUDED
#define CHECKPARAMETERS_H_INCLUDED
#include "fixwav_manager.h"

int user_control(WaveData *info, WaveHeader *header);
int auto_control(WaveData *info, WaveHeader *header);
void regular_test(WaveHeader *head, int* regular);
#endif // CHECKPARAMETERS_H_INCLUDED

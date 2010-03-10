#ifndef REPAIR_H_INCLUDED
#define REPAIR_H_INCLUDED

#include "fixwav_manager.h"

int launch_repair(FILE* outfile, WaveData *info, WaveHeader *header);
int write_header(uint8_t *newheader, FILE* outfile, WaveData *info);
int copy_fixwav_files(WaveData *info, FILE* infile, FILE* outfile);

#endif
// REPAIR_H_INCLUDED



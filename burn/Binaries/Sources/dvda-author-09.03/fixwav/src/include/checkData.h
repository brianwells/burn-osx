#ifndef CHECKDATA_H_INCLUDED
#define CHECKDATA_H_INCLUDED

int check_evenness(FILE* outfile, WaveData* info, WaveHeader *header);
int check_sample_count(FILE* outfile, WaveData *info, WaveHeader *header);
int readjust_sizes(FILE* outfile, WaveData *info, WaveHeader *header);
int prune(FILE* infile, FILE* outfile, WaveData *info, WaveHeader *header);

#endif // CHECKDATA_H_INCLUDED

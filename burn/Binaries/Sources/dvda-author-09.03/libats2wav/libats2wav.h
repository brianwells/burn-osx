#ifndef LIBATS2WAV_H
#define LIBATS2WAV_H



int ats2wav(const char* filename, const char* outdir);


typedef struct
{
    FILE* fpout;
    const char* filename;
    int samplerate;
    int channels;
    int bitspersample;
    int ntracks;
    int started;
    uint64_t last_sector;
    uint64_t first_sector;
    uint64_t numsamples;
    uint64_t numbytes;
    uint64_t byteswritten;
    uint64_t pts_length;
    
} _fileinfo_t;

#define BUFFER_SIZE 3*2048

#endif

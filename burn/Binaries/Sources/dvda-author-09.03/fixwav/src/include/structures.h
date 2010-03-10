#ifndef STRUCTURES_H_INCLUDED
#define STRUCTURES_H_INCLUDED

#include <inttypes.h>



typedef struct
  {
    char *filename;
    int type;
    int bitspersample;
    int sampleunitsize;
    int channels;
    uint32_t samplerate;
    uint64_t numsamples;
    uint64_t numbytes; // theoretical file size
    uint64_t file_size; // file size on disc
    uint64_t bytesperframe;
    uint64_t bytespersecond;


  } fileinfo_t;



typedef struct
  {
    _Bool silence;
    _Bool logfile;
    _Bool end_pause;
    _Bool debugging;
    _Bool fixwav_virtual_enable;
    _Bool fixwav_automatic; /* automatic behaviour */
    _Bool fixwav_prepend; /* do not prepend a header */
    _Bool fixwav_in_place; /* do not correct in place */
    _Bool fixwav_interactive; /* not interactive */
    _Bool fixwav_padding; /* padding */
    _Bool fixwav_prune; /* prune */
    _Bool fixwav_autorename;
    char* fixwav_suffix; /* output suffix for corrected files */
    char* fixwav_parameters;
    char* fixwav_output_dir;
    uint16_t fixwav_channels;
    uint16_t fixwav_bit_p_spl;
    uint32_t fixwav_sample_fq;
    FILE *journal;

  } globalData ;



#endif // STRUCTURES_H_INCLUDED

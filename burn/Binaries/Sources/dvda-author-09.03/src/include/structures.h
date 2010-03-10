#ifndef STRUCTURES_H_INCLUDED
#define STRUCTURES_H_INCLUDED

#if HAVE_CONFIG_H && !defined __CB__
#include <config.h>
#endif

#include "stream_decoder.h"
#include "inttypes.h"

typedef struct
{
    int bitspersample;
    int channels;
    uint32_t samplerate;
} audioformat_t;


typedef struct
{
    FILE* fp;
    FLAC__StreamDecoder* flac;
    // Used for FLAC decoding:
    uint8_t buf[1024*256];
    int n;
    int bytesread;
    int eos;
} audio_input_t;

typedef struct
{
    char *filename;
    int type;
    int bitspersample;
    //conflict on sampleunitsize type
    //int sampleunitsize;
    uint64_t sampleunitsize;
    int channels;
    int audio_format; // Pointer to the audio format record

    // L&T Fedkamp addition
    int joingap;
    int single_track;
    int contin_track;
    int cga;
    int join;
    int byteorder_testmode;
    int newtitle;
    int headerlength;
    int padd;
    // L&T Fedkamp addition

    uint32_t samplerate;
    uint32_t first_sector;
    uint32_t last_sector;

    // L&T Feldkamp addition (multichannel)
    uint32_t lpcm_payload;
    uint32_t firstpackdecrement;
    uint32_t SCRquantity;
    uint32_t firstpack_audiopesheaderquantity;
    uint32_t midpack_audiopesheaderquantity;
    uint32_t firstpack_lpcm_headerquantity;
    uint32_t midpack_lpcm_headerquantity;
    uint32_t firstpack_pes_padding;
    uint32_t midpack_pes_padding;
    // L&T Feldkamp addition (multichannel)

    uint64_t numsamples;
    uint64_t numbytes; // theoretical file size
    uint64_t file_size; // file size on disc
    uint64_t bytesperframe;
    uint64_t bytespersecond;
    uint64_t first_PTS;
    uint64_t PTS_length;

    // L&T Feldkamp addition (multichannel)
    uint64_t title_numbytes;
    uint64_t rmdr;
    uint64_t offset;
    // L&T Feldkamp addition (multichannel)


    audio_input_t* audio;  // Used whilst decoding.
} fileinfo_t;


typedef struct
{
    int access_rights;
    int ngroups;
    int n_g_groups;
    int nvideolinking_groups;
    int maximum_VTSI_rank;
    int Udo;
    int *VTSI_rank;
    int *ntracks;
    fileinfo_t **files;

}command_t;




typedef struct
{
    int ngroups;
    int *ntracks;
} parse_t;

typedef struct
{
    char  *settingsfile;
    char  *logfile;
    char  *indir;
    char  *outdir;
    char  *linkdir;
} defaults ;

typedef struct
{
    _Bool silence;
    _Bool logfile;
    _Bool videozone;
    _Bool videolinking;
    _Bool end_pause;
    _Bool debugging;
    _Bool padding;
#ifndef WITHOUT_SOX
    _Bool sox_enable;
#endif
#ifndef WITHOUT_FIXWAV
    _Bool fixwav_enable;
    _Bool fixwav_virtual_enable;
    _Bool fixwav_automatic; /* automatic behaviour */
    _Bool fixwav_prepend; /* do not prepend a header */
    _Bool fixwav_in_place; /* do not correct in place */
    _Bool fixwav_interactive; /* not interactive */
    _Bool fixwav_padding; /* padding */
    _Bool fixwav_prune; /* prune */
    char* fixwav_suffix; /* output suffix for corrected files */
    char* fixwav_parameters;
#endif
    FILE *journal;
    defaults settings;

} globalData ;



typedef struct
{
    int nlines;
    char **commandline;
} lexer_t;


#endif // STRUCTURES_H_INCLUDED

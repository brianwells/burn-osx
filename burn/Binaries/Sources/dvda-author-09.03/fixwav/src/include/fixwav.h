#ifndef FIXWAV_H
#define FIXWAV_H


#include <assert.h>
#include <stdint.h>


#define TRUE 1
#define FALSE 0
#define YES 1
#define NO  0

#define FIXBUF_LEN 256
#define BAD_HEADER  1
#define BAD_DATA    2
#define GOOD_HEADER 0
#define FAIL        10
#define COPY_SUCCESS 100
#define NO_PRUNE    4
#define PRUNED      5

/* real size of header in bytes */
#define HEADER_SIZE 44
#define HEX_COLUMNS 16
#define FW_VERSION "Version 0.1.3\n\n"\
                    "Copyright pigiron 2007, Fabrice Nicol 2008 (revised version) \n<fabnicol@users.sourceforge.net>.\nReleased under GPLv3. This software comes under NO GUARANTEE.\nPlease backup your files before running this utility.\n\n"

/* Definitions for Microsoft WAVE format */

#define RIFF		0x46464952
#define WAVE		0x45564157
#define FMT     0x20746d66
#define DATA    0x61746164
#define PCM_CODE	1
#define WAVE_MONO	1
#define WAVE_STEREO	2


typedef struct {
	_Bool silence;
	_Bool logfile;
	FILE* journal;
} globals_fixwav;

#endif

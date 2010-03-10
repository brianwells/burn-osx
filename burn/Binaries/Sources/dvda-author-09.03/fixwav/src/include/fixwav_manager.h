#ifndef MANAGER_H
#define MANAGER_H

#include <sys/stat.h>
#include <sys/types.h>

#define _READ_2_bytes  p[1]<<8 | p[0];\
        p+=2;	

#define LITTLE_ENDIAN_WRITE_2_bytes(Y, X)  Y[0]=X & 0xFF ;\
                                           Y[1]=(X & 0xFF00) >> 8;
											

#define _LITTLE_ENDIAN_WRITE_2_bytes(Y, X) LITTLE_ENDIAN_WRITE_2_bytes(Y, X)\
                                           Y+=2;

#define LITTLE_ENDIAN_WRITE_4_bytes(Y, X)  Y[0]= X & 0xFF ;\
                                           Y[1]= (X & 0xFF00) >> 8;\
                                           Y[2]= (X & 0xFF0000) >> 16;\
                                           Y[3]= X >>24;
									
#define _LITTLE_ENDIAN_WRITE_4_bytes(Y, X) LITTLE_ENDIAN_WRITE_4_bytes(Y, X)\
                                           Y+=4;
        

typedef struct {
	/* pointers */
	char* infile;
	char* outfile;

	/* global behavior booleans are set to zero by default, being global */
	_Bool automatic;  /* whether automatic processing mode is selected */
	_Bool prepend;  /* whether new header is prepended to raw data or overwrites old header */
	_Bool in_place; /* whether old file is overwritten */
	_Bool interactive; /* whether interactive dialogs will be used (not the case if -b, -s, -c are set)*/
	/* global diagnosis values */
	_Bool padding; /* whether files should be end-padded */
	_Bool prune; /* whether files ending with 00 should be pruned */ 
	_Bool virtual;
	int repair;
	/* header substructure */

} WaveData;

typedef struct {

	uint16_t	sc_format;	/* should be 1 for PCM-code */
	uint16_t	channels;	/* 1 Mono, 2 Stereo */
	uint16_t	byte_p_spl;	/* samplesize*/
	uint16_t	bit_p_spl;	/* 8, 12, 16, or 24 bit */

	uint32_t	chunk_id;	/* 'RIFF' */
	uint32_t	chunk_size;	/* filelen */
	uint32_t	chunk_format;	/* 'WAVE' */

	uint32_t	sub_chunk;	/* 'fmt ' */
	uint32_t	sc_size;	/* length of sub_chunk = 16 */
	uint32_t	sample_fq;	/* frequence of sample */
	uint32_t	byte_p_sec;     /* bytes per second */

	uint32_t	data_chunk;	/* 'data' */
	uint32_t	data_size;	/* samplecount */

} WaveHeader;


/* Function declarations */


WaveHeader    *fixwav(WaveData *info, WaveHeader *header);
int repair_wav(struct stat *file_stat, WaveData *info, WaveHeader *header );
void print_fixwav_help();


#endif

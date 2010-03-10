/* ==========================================================================
*
*   checkParameters.c
*   user_control function was originally designed by Pigiron, 2007.
*   auto_control and regular_test functions: Copyright Fabrice Nicol, 2008.
*
*   Description: processes core audio parameters in two alternative modes.
*        uses simple heuristics to automate header patching, or enters
*        user's core audio parameters (bit rate, sample rate, channels)
* ========================================================================== */

#include    <stdio.h>
#include    <stdlib.h>
#include    <locale.h>
#include    <stdint.h>
#include    <inttypes.h>
#include    <math.h>
#include    "fixwav_auxiliary.h"
#include    "checkParameters.h"
#include    "fixwav.h"
#include    "fixwav_manager.h"
#include    "c_utils.h"

extern globals_fixwav globals_f;

int user_control(WaveData *info, WaveHeader *header)
{

    char buf[FIXBUF_LEN];
    int repair=GOOD_HEADER;
    unsigned int bps;

    /* The Subchunk1 Number of Channels */

    if (info->interactive)
    {
    	foutput_f( "\n%s\n", "[INT]  Is the file recorded in " );

        switch ( header->channels )
        {
        case 1:
            foutput_f( "%s", "Mono? [y/n] " );
            break;
        case 2:
            foutput_f( "%s", "Stereo?  [y/n] " );
            break;

        default:
            foutput_f( "%d channels?  [y/n] ", header->channels );

        }

        if ( !isok() )
        {
            foutput_f( "%s", "[INT]  Enter number of channels... 1=Mono, 2=Stereo, etc: " );
            fflush(stdout);
            get_input(buf);
            header->channels = (uint16_t) atoi(buf);
            repair = BAD_HEADER;
        }

        /* The Sample Rate is the number of samples per second */
        foutput_f( "[INT]  Is the number of samples per second = %"PRIu32"?  [y/n] ", header->sample_fq );

        if ( !isok() )
        {
            foutput_f( "%s", "[INT]  Enter number of samples per second in kHz (e.g. 44.1) : " );
            fflush(stdout);
            get_input(buf);
            header->sample_fq = (uint32_t) floor(1000*atof(buf));
            repair = BAD_HEADER;
        }

        /* The number of bits per sample */
        foutput_f( "[INT]  Is the number of bits per sample = %d?  [y/n] ", header->bit_p_spl );

        if ( !isok() )
        {
            foutput_f( "%s", "[INT]  Enter number of bits per sample:  " );
            fflush(stdout);
            get_input(buf);
            header->bit_p_spl = (uint16_t) atoi(buf);
            repair = BAD_HEADER;
        }

    }

    /* The bytes per second = SampleRate * NumChannels * BitsPerSample/8 */
    bps = header->sample_fq * header->channels * (header->bit_p_spl / 8);
    
    // forcing interactive mode if null audio
    if (bps == 0) 
    {
    	info->interactive=TRUE;
    	return (info->repair=user_control(info, header));
    }
    
    if ( header->byte_p_sec == bps )
    {
    	// Patch again version 0.1.1: -Saple Rate ...offset 24  + Bytes per second ...offset 28
        foutput_f("%s\n",  "[MSG]  Found correct Subchunk1 Bytes per Second at offset 28\n" );
    }
    else
    {
        foutput_f("%s\n",  "[MSG]  Subchunk1 Bytes per Second at offset 28 is incorrect\n[INF]  ... repairing\n" );
        header->byte_p_sec = bps;
        repair = BAD_HEADER;
    }

    /* The number of bytes per sample = NumChannels * BitsPerSample/8 */
    if ( header->byte_p_spl == header->channels * (header->bit_p_spl / 8) )
    {
        foutput_f("%s\n",  "[MSG]  Found correct Subchunk1 Bytes Per Sample at offset 32\n" );
    }
    else
    {
        foutput_f("%s\n",  "[MSG]  Subchunk1 Bytes Per Sample at offset 32 is incorrect\n[INF]  ... repairing\n" );
        header->byte_p_spl = header->channels * (header->bit_p_spl / 8);
        repair = BAD_HEADER;
    }

    return (info->repair=repair);
}

int auto_control(WaveData *info, WaveHeader *header)
{
/* This implementation of the algoritm restricts it to the 44.1 kHz and 48 kHz families although this is not
out of logical necessity */


int regular[6]={0};

/* initializing */

foutput_f("\n%s\n", "[INF]  Checking header--automatic mode...");

regular_test(header, regular);

_Bool regular_bit_p_spl =regular[1];
_Bool regular_sample_fq =regular[2];
_Bool regular_byte_p_spl=regular[3];
_Bool regular_byte_p_sec=regular[4];
_Bool regular_channels=regular[5];

/* Checking whether there is anything to be done at all */

if (   (header->byte_p_sec == (header->sample_fq*header->bit_p_spl*header->channels)/8)
	&& (header->byte_p_spl == (header->channels*header->bit_p_spl)/8)
	&& (regular[0] == 5)
   )
   {
   	foutput_f("\n%s\n", "[MSG]  Core parameters need not be repaired");
	return(info->repair = GOOD_HEADER);
   }
/* Always repairing from now on except when bailing out */

info->repair=BAD_HEADER;

/* Set of assumptions (R) + (3), see comment below */
if (regular[0] < 3)
   goto bailing_out;


if (regular_channels)
{
  /* channel number considered a parameter, variables between curly brackets */

	// {N, S} case

	if ((regular_bit_p_spl) && (regular_sample_fq ))
	{
		header->byte_p_sec = (header->sample_fq*header->bit_p_spl*header->channels)/8;
		header->byte_p_spl = (header->channels*header->bit_p_spl)/8;
		regular_test(header, regular);
		if (regular[0] == 5)  return (info->repair);
	}

	// {N, B}
	if ((regular_byte_p_spl) && (regular_sample_fq ))
	{
		header->bit_p_spl  = (header->channels)? (header->byte_p_spl *8)/ header->channels: 0;
		header->byte_p_sec = (header->sample_fq*header->bit_p_spl*header->channels)/8;
		regular_test(header, regular);
		if (regular[0] == 5)  return (info->repair);
	}

	// {S, F}

	if ((regular_byte_p_sec) && (regular_bit_p_spl ))
	{
		header->byte_p_spl  = (header->bit_p_spl * header->channels)/8;
		header->sample_fq   = (header->bit_p_spl*header->channels)? (header->byte_p_sec*8)/(header->bit_p_spl*header->channels):0 ;
		regular_test(header, regular);
		if (regular[0] == 5) return (info->repair);
	}

	// {S, B}
	if ((regular_byte_p_sec) && (regular_sample_fq ))
	{
		header->byte_p_spl  = (header->bit_p_spl * header->channels)/8;
		header->bit_p_spl   =  (header->channels*header->sample_fq)? (8*header->byte_p_sec)/(header->channels*header->sample_fq):0 ;
		regular_test(header, regular);
		if (regular[0] == 5) return (info->repair);
	}

	// {F, B}
	if ((regular_byte_p_sec) && (regular_byte_p_spl ))
	{
		header->bit_p_spl   = (header->byte_p_spl*8 )/ header->channels;
		header->sample_fq   = (header->bit_p_spl*header->channels)?(header->byte_p_sec*8)/(header->bit_p_spl*header->channels) :0;
		regular_test(header, regular);
		if (regular[0] == 5) return (info->repair);
	}

}
/* Now consider cases in which number of channels is corrupt */

// {N,C}

if ((regular_byte_p_spl) && (regular_bit_p_spl) && (regular_sample_fq))
	{
		header->channels   = (header->byte_p_spl*8) / header->bit_p_spl;
		header->byte_p_sec = (header->sample_fq*header->bit_p_spl*header->channels)/8;
		regular_test(header, regular);
		if (regular[0] == 5)  return (info->repair);
	}

// {S, C}

if ((regular_byte_p_sec) && (regular_bit_p_spl) && (regular_sample_fq))
	{
		header->byte_p_spl = (header->sample_fq)? header->byte_p_sec/header->sample_fq : 0;
		header->channels   = (header->byte_p_spl*8 )/ header->bit_p_spl;
		regular_test(header, regular);
		if (regular[0] == 5)  return (info->repair);
	}

/* Special non-linear (hyperbolic) cases: XY= constant, yet a single solution under the set of assumtions */

// {F, C}

if ((regular_byte_p_sec) && (regular_bit_p_spl) && (regular_byte_p_spl))
	{
		header->sample_fq = (header->byte_p_spl)? header->byte_p_sec/header->byte_p_spl:0;
		header->channels  = (header->byte_p_spl*8)/ header->bit_p_spl;

		regular_test(header, regular);
		if (regular[0] == 5)  return (info->repair);
	}

/* Uniqueness of solution requires (R) */

// Now strengthening the notion of regular variable
if (header->channels % 3 == 0)
	goto bailing_out;

// {C, B}
// The theorem below proves unicity of the {C, B} solution: it suffices to loop on C and break once found one.
if ((regular_byte_p_sec) && (regular_byte_p_spl) && (regular_sample_fq))
{
		// Satisfying constaint on constants ?
		if (header->byte_p_sec != header->sample_fq * header->byte_p_spl) goto bailing_out;

		for (header->channels=1; header->channels < 6 ; header->channels++)
		{
			if (header->channels == 3) continue;
			header->bit_p_spl   = (header->channels)? (header->byte_p_spl*8) / header->channels:0;
			regular_test(header, regular);
			if (regular[0] == 5) return (info->repair);
		}
}

/* Now we are left with the unfortunate {N, F} case...or non-regular solutions: bailing out */

		goto bailing_out;

bailing_out:

foutput_f("\n%s\n", "[WAR]  Sorry, automatic mode cannot be used:\n       not enough information left in header");
foutput_f("%s\n", "[INF]  Reverting to interactive simple mode.");
info->interactive=TRUE;
info->repair=user_control(info, header);

return (info->repair);

}

void regular_test(WaveHeader *head, int* regular)
{
 int i, j, k, l;

if (head ==NULL) fprintf(stderr, "NULL!");
_Bool regular_channels=(head->channels >= 1)*(head->channels < 6);
_Bool regular_bit_p_spl=(head->bit_p_spl == 16 ) + (head->bit_p_spl == 24);
_Bool regular_sample_fq;
if (head->sample_fq)
   regular_sample_fq=(head->sample_fq % 44100 == 0) + (head->sample_fq % 48000 == 0);
else
   regular_sample_fq=0;
   
/* bit rates other than 16, 24 and 3 channels are not considered */

_Bool regular_byte_p_spl=(head->byte_p_spl == 2*16/8)+(head->byte_p_spl == 2*24/8)
						+(head->byte_p_spl == 3*16/8)+(head->byte_p_spl == 3*24/8)
						+(head->byte_p_spl == 4*16/8)+(head->byte_p_spl == 4*24/8)
						+(head->byte_p_spl == 5*16/8)+(head->byte_p_spl == 5*24/8)
						+(head->byte_p_spl == 16/8)+(head->byte_p_spl == 24/8);

_Bool regular_byte_p_sec=0;


for (i=1; i < 6; i++)
	for (j=0; j < 3; j++)
		for (k=0; k < 3; k++)
			for (l=16; l < 32; l+=8)
			{
				if ( (j+k) && (j*k == 0) )
				if ( head->byte_p_sec == (uint32_t) (i* ((j* 44100) + (k* 48000)) * l /8 ))
				{
					regular_byte_p_sec=1;
					break;
				}
			}


regular[0]=regular_bit_p_spl + regular_sample_fq + regular_byte_p_spl + regular_byte_p_sec + regular_channels;
regular[1]=regular_bit_p_spl;
regular[2]=regular_sample_fq ;
regular[3]=regular_byte_p_spl;
regular[4]=regular_byte_p_sec;
regular[5]=regular_channels;

return;

}


/*************************************************************************************************
*	About automatic mode
*	--------------------
*
*		A set of well-formed audio characteristics (R) is first defined (implementations
*		may be restrictive for practical purposes as above), variables in (R) will
*		henceforth be called regular variables.
*
*		The algorithm is based on the two equations on regular variables,
*
*			(1) N - F C B/8 = 0
*			(2) S -   C B/8   = 0
*
*			where N is the number of bytes per second
*			      S    the number of bytes per sample (all channels)
*			      C    the number of channels
*			      B    the number of bits per sample channel
*			      F    sampling frequency in Hz
*
*		Assumptions on header state are:
*
*	     (3) three out of the five above variables are assumed to be correct, and considered as parameters.
*
*
*	Mathematical discussion
*   -----------------------
*
*		Let D={N,S, C, B, F}. The above system of equations (1) and (2) form a linear system with two
*		unknown variables if the pair of variables is among this list:
*		{N,S}, {N,C}, {N, B}, {S, F}, {S, C}, {S, B}, as the determinant is not null.
*		In these cases, there is a single solution to the linear system.
*
*		However, the determinant is either null, or the system is not linear, for the following pairs of
*		unknown variables:
*		{N, F}, {F, C}, {F, B}, {C, B}, out of the 10 possible pairs.
*		In these cases yet, S is always known and, following (3), considered as a parameter.
*		As there must be a solution, the problem thus boild down to proving unicity under the set of assumptions.
*		From (2) it can be shown that, for a pair of solutions {(N, S, C, B, F), (N', S, C', B', F')}:
*
*			(4) B/B' = k, where k =C'/C
*
*		The {F, C} and {F, B} cases are straightforward and the solution is unique. Hower for {C, B} the set
*		of three constants {F, N, S} is linked by the equation F = N S, hence (2) is hyperbolic.
*		For this case we now add the following assumptions on variables, which define a stricter set (R'):
*		(R)	- number of channels is strictly positive and not a multiple of 3,
*			- bit rate is either 16 or 24.
*		Variables satisfying (R') in this case will be called regular variables equally.
*
*		Now, B/B' = 1 or 3/2, hence if C' > C, 2 | C.
*		Therefore C = 2 or 4, barring 6 (from (R)), and C' = 3 or 6, contradicting (R). Ab absurdo, C' = C
*		and B' = B out of (2). Out of the five cases at hand, N is a known correct parameter except in the
*		four cases, hence N' = N, whence F' = F out of (1).
*
*		There remains the {N, F} case, which should be
*		very rare, and added to the set of header assumptions as below:
*
*			(3') (header assumptions, revised): Three parameters are known to be correct, other than {S, C, B}.
*
*		In the {S, C, B} case, the algorithm will bail out.
*
*	Algorithm
*   ---------
*
*		The algorithm first tests whether all five C variables read from the file header are within the bounds
*		of (R), the set of regular values for this mode. If there are fewer than two such variables out of five,
*		fixwav reverts to manual mode.
*		Then setting the channel number, two regular variables are selected other than {S, B}.
*		If this is not possible,  fixwav bails out.
*		The other two variables are calculated out of (1) and (2), then tested to be within the bounds of (R).
*		Should the test fail, fixwav looks for other possible combinations of known parameters.
*		The above theorem ensures that there is	just one solution: the first regular values are the only ones
*		under the set of assumptions.
*		In the {C, B} case, the linear constraint on constants is checked and the stricter conditions (R') are
*		enforced, bailing out if they are not satisfied. Then the one remaining equation is
*		solved by looping on the number of channels C: the above theorem ensures that the first regular pair
*		is the only one solution.
*		When all options have failed, fixwav bails out to manual mode, otherwise it returns BAD_header->
*		info values are modified as global variables.
*
*	Important note
*	--------------
*
*		The algorithm assumes that if the constants are regular, then they are correct values.
*		Should this assumption be erroneous, wrong corrections can be made that satisfy all mathematical constraints.
*		User checking is therefore advised when option -a is used (please refrain from using silent mode -q
*		in conjunction with -a).
*		Example of "wrong" correction: C = 1, S = 3, B = 24, F = 96kHz, instead of C = 2, S = 6, B = 24, F = 48 kHz.
*
*		<added by Fabrice Nicol,  May 2008 >
*
******************************************************************************************************************/












































































































































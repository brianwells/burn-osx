/*
    $Id: image_nrg.c,v 1.8 2005/06/09 00:53:23 rocky Exp $

    Copyright (C) 2001, 2003, 2004, 2005 Herbert Valerio Riedel <hvr@gnu.org>

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

/*! This code implements low-level access functions for Nero's native
   CD-image format residing inside a disk file (*.nrg).
*/

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <cdio/cdio.h>
#include <cdio/bytesex.h>
#include <cdio/iso9660.h>

/* Public headers */
#include <libvcd/sector.h>
#include <libvcd/logging.h>

/* Private headers */
#include "vcd_assert.h"
#include "image_sink.h"
#include "stream_stdio.h"
#include "util.h"

static const char _rcsid[] = "$Id: image_nrg.c,v 1.8 2005/06/09 00:53:23 rocky Exp $";

/* structures used */

/* this ugly image format is typical for lazy win32 programmers... at
   least structure were set big endian, so at reverse
   engineering wasn't such a big headache... */

PRAGMA_BEGIN_PACKED
typedef struct {
  uint32_t start      GNUC_PACKED;
  uint32_t length     GNUC_PACKED;
  uint32_t type       GNUC_PACKED; /* only 0x3 seen so far... 
                                      -> MIXED_MODE2 2336 blocksize */
  uint32_t start_lsn  GNUC_PACKED; /* does not include any pre-gaps! */
  uint32_t _unknown   GNUC_PACKED; /* wtf is this for? -- always zero... */
} _etnf_array_t;

/* finally they realized that 32bit offsets are a bit outdated for IA64 *eg* */
typedef struct {
  uint64_t start      GNUC_PACKED;
  uint64_t length     GNUC_PACKED;
  uint32_t type       GNUC_PACKED;
  uint32_t start_lsn  GNUC_PACKED;
  uint64_t _unknown   GNUC_PACKED; /* wtf is this for? -- always zero... */
} _etn2_array_t;

typedef struct {
  uint8_t  _unknown1  GNUC_PACKED; /* 0x41 == 'A' */
  uint8_t  track      GNUC_PACKED; /* binary or BCD?? */
  uint8_t  index      GNUC_PACKED; /* makes 0->1 transitions */
  uint8_t  _unknown2  GNUC_PACKED; /* ?? */
  uint32_t lsn        GNUC_PACKED; 
} _cuex_array_t;

typedef struct {
  uint32_t id                    GNUC_PACKED;
  uint32_t len                   GNUC_PACKED;
  char data[EMPTY_ARRAY_SIZE]    GNUC_PACKED;
} _chunk_t;

PRAGMA_END_PACKED

/* to be converted into BE */
#define CUEX_ID  0x43554558
#define CUES_ID  0x43554553
#define DAOX_ID  0x44414f58
#define DAOI_ID  0x44414f49
#define END1_ID  0x454e4421
#define ETN2_ID  0x45544e32
#define ETNF_ID  0x45544e46
#define NER5_ID  0x4e455235
#define NERO_ID  0x4e45524f
#define SINF_ID  0x53494e46

/****************************************************************************
 * writer
 */

typedef struct {
  VcdDataSink *nrg_snk;
  char *nrg_fname;

  CdioList_t *vcd_cue_list;
  int tracks;
  uint32_t cue_end_lsn;

  bool init;
} _img_nrg_snk_t;

static void
_sink_init (_img_nrg_snk_t *_obj)
{
  if (_obj->init)
    return;

  if (!(_obj->nrg_snk = vcd_data_sink_new_stdio (_obj->nrg_fname)))
    vcd_error ("init failed");

  _obj->init = true;  
}


static void
_sink_free (void *user_data)
{
  _img_nrg_snk_t *_obj = user_data;

  free (_obj->nrg_fname);
  vcd_data_sink_destroy (_obj->nrg_snk);

  free (_obj);
}

static int
_set_cuesheet (void *user_data, const CdioList_t *vcd_cue_list)
{
  _img_nrg_snk_t *_obj = user_data;
  CdioListNode_t *node;
  int num;

  _sink_init (_obj);

  _obj->vcd_cue_list = _cdio_list_new ();

  num = 0;
  _CDIO_LIST_FOREACH (node, (CdioList_t *) vcd_cue_list)
    {
      const vcd_cue_t *_cue = _cdio_list_node_data (node);
      vcd_cue_t *_cue2 = calloc(1, sizeof (vcd_cue_t));
      *_cue2 = *_cue;
      _cdio_list_append (_obj->vcd_cue_list, _cue2);
  
      if (_cue->type == VCD_CUE_TRACK_START)
	num++;

      if (_cue->type == VCD_CUE_END)
	_obj->cue_end_lsn = _cue->lsn;
    }

  _obj->tracks = num;

  vcd_assert (CDIO_CD_MIN_TRACK_NO >= 1 && num <= CDIO_CD_MAX_TRACKS);

  return 0;
}

static uint32_t
_map (_img_nrg_snk_t *_obj, uint32_t lsn)
{
  CdioListNode_t *node;
  uint32_t result = lsn;
  vcd_cue_t *_cue = NULL, *_last = NULL;

  vcd_assert (_obj->cue_end_lsn > lsn);

  _CDIO_LIST_FOREACH (node, _obj->vcd_cue_list)
    {
      _cue = _cdio_list_node_data (node);
      
      if (lsn < _cue->lsn)
	break;

      switch (_cue->type)
	{
	case VCD_CUE_TRACK_START:
	  result -= _cue->lsn;
	  break;
	case VCD_CUE_PREGAP_START:
	  result += _cue->lsn;
	  break;
	default:
	  break;
	}

      _last = _cue;
    }
  
  vcd_assert (node != NULL);

  switch (_last->type)
    {
    case VCD_CUE_TRACK_START:
      return result;
      break;

    case VCD_CUE_PREGAP_START:
      return -1;
      break;
    
    default:
    case VCD_CUE_END:
      vcd_assert_not_reached ();
      break;
    }

  return -1;
}

static int
_write_tail (_img_nrg_snk_t *_obj, uint32_t offset)
{
  CdioListNode_t *node;
  int _size;
  _chunk_t _chunk;

  vcd_data_sink_seek (_obj->nrg_snk, offset);

  _size = _obj->tracks * sizeof (_etnf_array_t);
  _chunk.id = UINT32_TO_BE (ETNF_ID);
  _chunk.len = uint32_to_be (_size);

  vcd_data_sink_write (_obj->nrg_snk, &_chunk, sizeof (_chunk_t), 1);

  _CDIO_LIST_FOREACH (node, _obj->vcd_cue_list)
    {
      vcd_cue_t *_cue = _cdio_list_node_data (node);
      
      if (_cue->type == VCD_CUE_TRACK_START)
	{
	  vcd_cue_t *_cue2 = 
	    _cdio_list_node_data (_cdio_list_node_next (node));

	  _etnf_array_t _etnf = { 0, };

	  _etnf.type = UINT32_TO_BE (0x3);
	  _etnf.start_lsn = uint32_to_be (_map (_obj, _cue->lsn));
	  _etnf.start = uint32_to_be (_map (_obj, _cue->lsn) * M2RAW_SECTOR_SIZE);
	  
	  _etnf.length = uint32_to_be ((_cue2->lsn - _cue->lsn) * M2RAW_SECTOR_SIZE);

	  vcd_data_sink_write (_obj->nrg_snk, &_etnf, sizeof (_etnf_array_t), 1);
	}
	
    }
  
  {
    uint32_t tracks = uint32_to_be (_obj->tracks);

    _chunk.id = UINT32_TO_BE (SINF_ID);
    _chunk.len = UINT32_TO_BE (sizeof (uint32_t));
    vcd_data_sink_write (_obj->nrg_snk, &_chunk, sizeof (_chunk_t), 1);

    vcd_data_sink_write (_obj->nrg_snk, &tracks, sizeof (uint32_t), 1);
  }

  _chunk.id = UINT32_TO_BE (END1_ID);
  _chunk.len = UINT32_TO_BE (0);
  vcd_data_sink_write (_obj->nrg_snk, &_chunk, sizeof (_chunk_t), 1);

  _chunk.id = UINT32_TO_BE (NERO_ID);
  _chunk.len = uint32_to_be (offset);
  vcd_data_sink_write (_obj->nrg_snk, &_chunk, sizeof (_chunk_t), 1);

  return 0;
}
 
static int
_vcd_image_nrg_write (void *user_data, const void *data, lsn_t lsn)
{
  const char *buf = data;
  _img_nrg_snk_t *_obj = user_data;
  uint32_t _lsn = _map (_obj, lsn);

  _sink_init (_obj);

  if (_lsn == -1)
    {
      /* vcd_debug ("ignoring %d", lsn); */
      return 0;
    }

  vcd_data_sink_seek(_obj->nrg_snk, _lsn * M2RAW_SECTOR_SIZE);
  vcd_data_sink_write(_obj->nrg_snk, buf + 12 + 4, M2RAW_SECTOR_SIZE, 1);

  if (_obj->cue_end_lsn - 1 == lsn)
    {
      vcd_debug ("ENDLSN reached! (%lu == %lu)", 
		 (long unsigned int) lsn, (long unsigned int) _lsn);
      return _write_tail (_obj, (_lsn + 1) * M2RAW_SECTOR_SIZE);
    }

  return 0;
}

static int
_sink_set_arg (void *user_data, const char key[], const char value[])
{
  _img_nrg_snk_t *_obj = user_data;

  if (!strcmp (key, "nrg"))
    {
      free (_obj->nrg_fname);

      if (!value)
	return -2;

      _obj->nrg_fname = strdup (value);
    }
  else
    return -1;

  return 0;
}

VcdImageSink_t *
vcd_image_sink_new_nrg (void)
{
  _img_nrg_snk_t *_data;

  vcd_image_sink_funcs _funcs = {
    .set_cuesheet = _set_cuesheet,
    .write        = _vcd_image_nrg_write,
    .free         = _sink_free,
    .set_arg      = _sink_set_arg
  };

  _data = calloc(1, sizeof (_img_nrg_snk_t));
  _data->nrg_fname = strdup ("videocd.nrg");

  vcd_warn ("opening TAO NRG image for writing; TAO (S)VCD are NOT 100%% compliant!");

  return vcd_image_sink_new (_data, &_funcs);
}


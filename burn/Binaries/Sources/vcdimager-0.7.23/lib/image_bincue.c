/*
    $Id: image_bincue.c,v 1.8 2005/06/09 00:53:23 rocky Exp $

    Copyright (C) 2001, 2004 Herbert Valerio Riedel <hvr@gnu.org>

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

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif


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

static const char _rcsid[] = "$Id: image_bincue.c,v 1.8 2005/06/09 00:53:23 rocky Exp $";

/* reader */

#define DEFAULT_VCD_DEVICE "videocd.bin"

/****************************************************************************
 * writer
 */

typedef struct {
  bool sector_2336_flag;
  VcdDataSink *bin_snk;
  VcdDataSink *cue_snk;
  char *bin_fname;
  char *cue_fname;

  bool init;
} _img_bincue_snk_t;

static void
_sink_init (_img_bincue_snk_t *_obj)
{
  if (_obj->init)
    return;

  if (!(_obj->bin_snk = vcd_data_sink_new_stdio (_obj->bin_fname)))
    vcd_error ("init failed");

  if (!(_obj->cue_snk = vcd_data_sink_new_stdio (_obj->cue_fname)))
    vcd_error ("init failed");

  _obj->init = true;  
}

static void
_sink_free (void *user_data)
{
  _img_bincue_snk_t *_obj = user_data;

  vcd_data_sink_destroy (_obj->bin_snk);
  vcd_data_sink_destroy (_obj->cue_snk);
  free (_obj->bin_fname);
  free (_obj->cue_fname);
  free (_obj);
}

static int
_set_cuesheet (void *user_data, const CdioList *vcd_cue_list)
{
  _img_bincue_snk_t *_obj = user_data;
  CdioListNode_t *node;
  int track_no, index_no;
  const vcd_cue_t *_last_cue = 0;
  
  _sink_init (_obj);

  vcd_data_sink_printf (_obj->cue_snk, "FILE \"%s\" BINARY\r\n",
			_obj->bin_fname);

  track_no = 0;
  index_no = 0;
  _CDIO_LIST_FOREACH (node, (CdioList *) vcd_cue_list)
    {
      const vcd_cue_t *_cue = _cdio_list_node_data (node);
      char *psz_msf;
      
      msf_t _msf = { 0, 0, 0 };
      
      switch (_cue->type)
	{
	case VCD_CUE_TRACK_START:
	  track_no++;
	  index_no = 0;

	  vcd_data_sink_printf (_obj->cue_snk, 
				"  TRACK %2.2d MODE2/%d\r\n"
				"    FLAGS DCP\r\n",
				track_no, (_obj->sector_2336_flag ? 2336 : 2352));

	  if (_last_cue && _last_cue->type == VCD_CUE_PREGAP_START)
	    {
	      cdio_lba_to_msf (_last_cue->lsn, &_msf);
	      psz_msf = cdio_msf_to_str(&_msf);

	      vcd_data_sink_printf (_obj->cue_snk, 
				    "    INDEX %2.2d %s\r\n", 
				    index_no, psz_msf);
	      free(psz_msf);
	    }

	  index_no++;

	  cdio_lba_to_msf (_cue->lsn, &_msf);
	  psz_msf = cdio_msf_to_str(&_msf);

	  vcd_data_sink_printf (_obj->cue_snk, 
				"    INDEX %2.2d %s\r\n",
				index_no, psz_msf);
	  free(psz_msf);
	  break;

	case VCD_CUE_PREGAP_START:
	  /* handled in next iteration */
	  break;

	case VCD_CUE_SUBINDEX:
	  vcd_assert (_last_cue != 0);

	  index_no++;
	  vcd_assert (index_no <= CDIO_CD_MAX_TRACKS);

	  cdio_lba_to_msf (_cue->lsn, &_msf);
	  psz_msf = cdio_msf_to_str(&_msf);

	  vcd_data_sink_printf (_obj->cue_snk, 
				"    INDEX %2.2d %s\r\n",
				index_no, psz_msf);
	  free(psz_msf);
	  break;
	  
	case VCD_CUE_END:
	  vcd_data_sink_close (_obj->cue_snk);
	  return 0;
	  break;

	case VCD_CUE_LEADIN:
	  break;
	}

      _last_cue = _cue;
    }

  vcd_assert_not_reached ();

  return -1;
}
 
static int
_vcd_image_bincue_write (void *user_data, const void *data, lsn_t lsn)
{
  const char *buf = data;
  _img_bincue_snk_t *_obj = user_data;
  long offset = lsn;

  _sink_init (_obj);

  offset *= _obj->sector_2336_flag ? M2RAW_SECTOR_SIZE : CDIO_CD_FRAMESIZE_RAW;

  vcd_data_sink_seek(_obj->bin_snk, offset);
  
  if (_obj->sector_2336_flag)
    vcd_data_sink_write(_obj->bin_snk, buf + 12 + 4, M2RAW_SECTOR_SIZE, 1);
  else
    vcd_data_sink_write(_obj->bin_snk, buf, CDIO_CD_FRAMESIZE_RAW, 1);

  return 0;
}

static int
_sink_set_arg (void *user_data, const char key[], const char value[])
{
  _img_bincue_snk_t *_obj = user_data;

  if (!strcmp (key, "bin"))
    {
      free (_obj->bin_fname);

      if (!value)
	return -2;

      _obj->bin_fname = strdup (value);
    }
  else if (!strcmp (key, "cue"))
    {
      free (_obj->cue_fname);

      if (!value)
	return -2;

      _obj->cue_fname = strdup (value);
    }
  else if (!strcmp (key, "sector"))
    {
      if (!strcmp (value, "2336"))
	_obj->sector_2336_flag = true;
      else if (!strcmp (value, "2352"))
	_obj->sector_2336_flag = false;
      else
	return -2;
    }
  else
    return -1;

  return 0;
}

VcdImageSink_t *
vcd_image_sink_new_bincue (void)
{
  _img_bincue_snk_t *_data;

  vcd_image_sink_funcs _funcs = {
    .set_cuesheet = _set_cuesheet,
    .write        = _vcd_image_bincue_write,
    .free         = _sink_free,
    .set_arg      = _sink_set_arg
  };

  _data = calloc(1, sizeof (_img_bincue_snk_t));

  _data->bin_fname = strdup ("videocd.bin");
  _data->cue_fname = strdup ("videocd.cue");

  return vcd_image_sink_new (_data, &_funcs);
}


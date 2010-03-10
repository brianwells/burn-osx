/*
    $Id: image.c,v 1.6 2005/06/09 00:53:23 rocky Exp $

    Copyright (C) 2001 Herbert Valerio Riedel <hvr@gnu.org>
                  2002, 2005 Rocky Bernstein <rocky@panix.com>

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

#include <cdio/cdio.h>

/* Public headers */
#include <libvcd/sector.h>
#include <cdio/iso9660.h>

/* Private headers */
#include "vcd_assert.h"
#include "image_sink.h"
#include "util.h"

static const char _rcsid[] = "$Id: image.c,v 1.6 2005/06/09 00:53:23 rocky Exp $";

/*
 * VcdImageSink routines next.
 */

struct _VcdImageSink {
  void *user_data;
  vcd_image_sink_funcs op;
};

VcdImageSink_t *
vcd_image_sink_new (void *p_user_data, const vcd_image_sink_funcs *funcs)
{
  VcdImageSink_t *new_obj;

  new_obj = calloc(1, sizeof (VcdImageSink_t));

  new_obj->user_data = p_user_data;
  new_obj->op = *funcs;

  return new_obj;
}

void
vcd_image_sink_destroy (VcdImageSink_t *p_obj)
{
  vcd_assert (p_obj != NULL);
  
  p_obj->op.free (p_obj->user_data);
  free (p_obj);
}

int
vcd_image_sink_set_cuesheet (VcdImageSink_t *p_obj, 
                             const CdioList_t *vcd_cue_list)
{
  vcd_assert (p_obj != NULL);

  return p_obj->op.set_cuesheet (p_obj->user_data, vcd_cue_list);
}

int
vcd_image_sink_write (VcdImageSink_t *p_obj, void *p_buf, lsn_t lsn)
{
  vcd_assert (p_obj != NULL);

  return p_obj->op.write (p_obj->user_data, p_buf, lsn);
}

/*!
  Set the arg "key" with "value" in the target device.
*/

int
vcd_image_sink_set_arg (VcdImageSink_t *obj, const char key[],
			const char value[])
{
  vcd_assert (obj != NULL);
  vcd_assert (obj->op.set_arg != NULL);
  vcd_assert (key != NULL);

  return obj->op.set_arg (obj->user_data, key, value);
}


/* 
 * Local variables:
 *  c-file-style: "gnu"
 *  tab-width: 8
 *  indent-tabs-mode: nil
 * End:
 */

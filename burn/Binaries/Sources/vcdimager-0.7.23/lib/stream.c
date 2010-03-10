/*
    $Id: stream.c,v 1.5 2005/06/07 23:29:23 rocky Exp $

    Copyright (C) 2000, 2005 Herbert Valerio Riedel <hvr@gnu.org>

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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

#include <cdio/cdio.h>

/* #define STREAM_DEBUG  */

/* Public headers */

#include <libvcd/logging.h>

/* Private headers */
#include "vcd_assert.h"
#include "stream.h"
#include "util.h"

static const char _rcsid[] = "$Id: stream.c,v 1.5 2005/06/07 23:29:23 rocky Exp $";

/* 
 * DataSource implementations
 */

struct _VcdDataSink {
  void* user_data;
  vcd_data_sink_io_functions op;
  int is_open;
  long position;
};

static void
_vcd_data_sink_open_if_necessary(VcdDataSink *obj)
{
  vcd_assert (obj != NULL);

  if (!obj->is_open) {
    if (obj->op.open(obj->user_data))
      vcd_error("could not opening output stream...");
    else {
      obj->is_open = 1;
      obj->position = 0;
    }
  }
}

VcdDataSink* 
vcd_data_sink_new(void *user_data, const vcd_data_sink_io_functions *funcs)
{
  VcdDataSink *new_obj;

  new_obj = calloc(1, sizeof(VcdDataSink));

  new_obj->user_data = user_data;
  memcpy(&(new_obj->op), funcs, sizeof(vcd_data_sink_io_functions));

  return new_obj;
}

long
vcd_data_sink_seek(VcdDataSink* obj, long offset)
{
  vcd_assert (obj != NULL);

  _vcd_data_sink_open_if_necessary(obj);

  if (obj->position != offset) {
    vcd_warn("had to reposition DataSink from %ld to %ld!", obj->position, offset);
    obj->position = offset;
    return obj->op.seek(obj->user_data, offset);
  }

  return 0;
}

long
vcd_data_sink_write(VcdDataSink* obj, const void *ptr, long size, long nmemb)
{
  long written;

  vcd_assert (obj != NULL);
  
  _vcd_data_sink_open_if_necessary(obj);

  written = obj->op.write(obj->user_data, ptr, size*nmemb);
  obj->position += written;

  return written;
}

long
vcd_data_sink_printf (VcdDataSink *obj, const char format[], ...)
{
  char buf[4096] = { 0, };
  long retval;
  int len;

  va_list args;
  va_start (args, format);

  len = vsnprintf (buf, sizeof(buf), format, args);

  if (len < 0 || len > (sizeof (buf) - 1))
    vcd_error ("vsnprintf() returned %d", len);
  
  retval = vcd_data_sink_write (obj, buf, 1, len);

  va_end (args);

  return retval;
}

void
vcd_data_sink_close(VcdDataSink* obj)
{
  vcd_assert (obj != NULL);

  if (obj->is_open) {
    obj->op.close(obj->user_data);
    obj->is_open = 0;
    obj->position = 0;
  }
}

void
vcd_data_sink_destroy(VcdDataSink* obj)
{
  vcd_assert (obj != NULL);

  vcd_data_sink_close(obj);

  obj->op.free(obj->user_data);
}

/* 
 * DataSource implementations
 */

struct _VcdDataSource {
  void* user_data;
  vcd_data_source_io_functions op;
  int is_open;
  long position;
};

static void
_vcd_data_source_open_if_necessary(VcdDataSource_t *obj)
{
  vcd_assert (obj != NULL);

  if (!obj->is_open) {
    if (obj->op.open(obj->user_data))
      vcd_error ("could not opening input stream...");
    else {
#ifdef STREAM_DEBUG
      vcd_debug ("opened source...");
#endif
      obj->is_open = 1;
      obj->position = 0;
    }
  }
}

long
vcd_data_source_seek(VcdDataSource_t* p_obj, long offset)
{
  vcd_assert (p_obj != NULL);

  _vcd_data_source_open_if_necessary(p_obj);

  if (p_obj->position != offset) {
#ifdef STREAM_DEBUG
    vcd_warn("had to reposition DataSource from %ld to %ld!", p_obj->position, 
             offset);
#endif
    p_obj->position = offset;
    return p_obj->op.seek(p_obj->user_data, offset);
  }

  return 0;
}

VcdDataSource_t *
vcd_data_source_new(void *p_user_data, 
                    const vcd_data_source_io_functions *funcs)
{
  VcdDataSource_t *new_obj;

  new_obj = calloc(1, sizeof (VcdDataSource_t));

  new_obj->user_data = p_user_data;
  memcpy(&(new_obj->op), funcs, sizeof(vcd_data_source_io_functions));

  return new_obj;
}

/** 
    read size*nmemb bytes from obj into ptr 
*/
long
vcd_data_source_read(VcdDataSource_t* obj, void *ptr, long size, long nmemb)
{
  long read_bytes;

  vcd_assert (obj != NULL);

  _vcd_data_source_open_if_necessary(obj);

  read_bytes = obj->op.read(obj->user_data, ptr, size*nmemb);
  obj->position += read_bytes;

  return read_bytes;
}

long
vcd_data_source_stat(VcdDataSource_t *p_obj)
{
  vcd_assert (p_obj != NULL);

  _vcd_data_source_open_if_necessary(p_obj);

  return p_obj->op.stat(p_obj->user_data);
}

void
vcd_data_source_close(VcdDataSource_t *p_obj)
{
  vcd_assert (p_obj != NULL);

  if (p_obj->is_open) {
#ifdef STREAM_DEBUG
    vcd_debug ("closed source...");
#endif
    p_obj->op.close(p_obj->user_data);
    p_obj->is_open = 0;
    p_obj->position = 0;
  }
}

void
vcd_data_source_destroy(VcdDataSource_t *p_obj)
{
  vcd_assert (p_obj != NULL);

  vcd_data_source_close(p_obj);

  p_obj->op.free(p_obj->user_data);
}


/* 
 * Local variables:
 *  c-file-style: "gnu"
 *  tab-width: 8
 *  indent-tabs-mode: nil
 * End:
 */

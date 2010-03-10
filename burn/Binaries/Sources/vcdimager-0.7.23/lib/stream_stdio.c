/*
    $Id: stream_stdio.c,v 1.4 2005/06/07 23:29:23 rocky Exp $

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
#include <unistd.h> 
#include <sys/stat.h>
#include <errno.h>

#include <cdio/cdio.h>

#include <libvcd/logging.h>

/* Private headers */
#include "stream_stdio.h"
#include "util.h"

static const char _rcsid[] = "$Id: stream_stdio.c,v 1.4 2005/06/07 23:29:23 rocky Exp $";

#define VCD_STREAM_STDIO_BUFSIZE (128*1024)

typedef struct {
  char *pathname;
  FILE *fd;
  char *fd_buf;
  off_t st_size; /* used only for source */
} _UserData;

static int
_stdio_open_source (void *user_data) 
{
  _UserData *const ud = user_data;
  
  if ((ud->fd = fopen (ud->pathname, "rb")))
    {
      ud->fd_buf = calloc(1, VCD_STREAM_STDIO_BUFSIZE);
      setvbuf (ud->fd, ud->fd_buf, _IOFBF, VCD_STREAM_STDIO_BUFSIZE);
    }

  return (ud->fd == NULL);
}

static int
_stdio_open_sink (void *user_data) 
{
  _UserData *const ud = user_data;

  if ((ud->fd = fopen (ud->pathname, "wb")))
    {
      ud->fd_buf = calloc(1, VCD_STREAM_STDIO_BUFSIZE);
      setvbuf (ud->fd, ud->fd_buf, _IOFBF, VCD_STREAM_STDIO_BUFSIZE);
    }
  
  return (ud->fd == NULL);
}

static int
_stdio_close(void *user_data)
{
  _UserData *const ud = user_data;

  if (fclose (ud->fd))
    vcd_error ("fclose (): %s", strerror (errno));
 
  ud->fd = NULL;

  free (ud->fd_buf);
  ud->fd_buf = NULL;

  return 0;
}

static void
_stdio_free(void *user_data)
{
  _UserData *const ud = user_data;

  if (ud->pathname)
    free(ud->pathname);

  if (ud->fd) /* should be NULL anyway... */
    _stdio_close(user_data); 

  free(ud);
}

static long
_stdio_seek(void *user_data, long offset)
{
  _UserData *const ud = user_data;

  if (fseek (ud->fd, offset, SEEK_SET))
    vcd_error ("fseek (): %s", strerror (errno));

  return offset;
}

static long
_stdio_stat(void *user_data)
{
  const _UserData *const ud = user_data;

  return ud->st_size;
}

static long
_stdio_read(void *user_data, void *buf, long count)
{
  _UserData *const ud = user_data;
  long read;

  read = fread(buf, 1, count, ud->fd);

  if (read != count)
    { /* fixme -- ferror/feof */
      if (feof (ud->fd))
        {
          vcd_debug ("fread (): EOF encountered");
          clearerr (ud->fd);
        }
      else if (ferror (ud->fd))
        {
          vcd_error ("fread (): %s", strerror (errno));
          clearerr (ud->fd);
        }
      else
        vcd_debug ("fread (): short read and no EOF?!?");
    }

  return read;
}

static long
_stdio_write(void *user_data, const void *buf, long count)
{
  _UserData *const ud = user_data;
  long written;

  written = fwrite(buf, 1, count, ud->fd);
  
  if (written != count)
    vcd_error ("fwrite (): %s", strerror (errno));

  return written;
}

VcdDataSource_t *
vcd_data_source_new_stdio(const char pathname[])
{
  VcdDataSource_t *new_obj = NULL;
  vcd_data_source_io_functions funcs = { 0, };
  _UserData *ud = NULL;
  struct stat statbuf;
  
  if (stat (pathname, &statbuf) == -1) 
    {
      vcd_error ("could not stat() file `%s': %s", pathname, strerror (errno));
      return NULL;
    }

  ud = calloc(1, sizeof (_UserData));

  ud->pathname = strdup(pathname);
  ud->st_size = statbuf.st_size; /* let's hope it doesn't change... */

  funcs.open = _stdio_open_source;
  funcs.seek = _stdio_seek;
  funcs.stat = _stdio_stat;
  funcs.read = _stdio_read;
  funcs.close = _stdio_close;
  funcs.free = _stdio_free;

  new_obj = vcd_data_source_new(ud, &funcs);

  return new_obj;
}


VcdDataSink*
vcd_data_sink_new_stdio(const char pathname[])
{
  VcdDataSink *new_obj = NULL;
  vcd_data_sink_io_functions funcs;
  _UserData *ud = NULL;
  struct stat statbuf;

  if (stat (pathname, &statbuf) != -1) 
    vcd_warn ("file `%s' exist already, will get overwritten!", pathname);

  ud = calloc(1, sizeof (_UserData));

  memset (&funcs, 0, sizeof (funcs));

  ud->pathname = strdup (pathname);

  funcs.open = _stdio_open_sink;
  funcs.seek = _stdio_seek;
  funcs.write = _stdio_write;
  funcs.close = _stdio_close;
  funcs.free = _stdio_free;

  new_obj = vcd_data_sink_new (ud, &funcs);

  return new_obj;
}


/* 
 * Local variables:
 *  c-file-style: "gnu"
 *  tab-width: 8
 *  indent-tabs-mode: nil
 * End:
 */

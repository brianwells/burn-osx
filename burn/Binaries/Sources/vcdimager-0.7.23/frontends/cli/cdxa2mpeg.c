/* -*- c -*- 
   $Id: cdxa2mpeg.c,v 1.10 2005/02/02 00:37:37 rocky Exp $

   Copyright (C) 2001, 2004, 2005 Herbert Valerio Riedel <hvr@gnu.org>

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

/* quick'n'dirty RIFF CD-XA 2 MPEG converter */

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#if defined ( WIN32 )
#define ftruncate chsize
#endif

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <errno.h>
#include <unistd.h>
#include <cdio/sector.h>
#include <cdio/bytesex.h>

#include <popt.h>

/* Private includes */
#include "vcd_assert.h"
#include "util.h"
#include "vcd.h"

static struct {
  int quiet_flag;
  int verbose_flag;

  vcd_log_handler_t default_vcd_log_handler;
} gl = { 0, }; /* global */

static void
_vcd_log_handler (vcd_log_level_t level, const char message[])
{
  if (level == VCD_LOG_DEBUG && !gl.verbose_flag)
    return;

  if (level == VCD_LOG_INFO && gl.quiet_flag)
    return;

  gl.default_vcd_log_handler (level, message);
}


typedef struct {
  FILE *fd;
  FILE *fd_out;
  uint32_t size;
  uint32_t lsize;
} riff_context;

static int next_id (riff_context *ctxt);

static uint32_t
read_le_u32 (riff_context *ctxt)
{
  uint32_t tmp;

  if (fread (&tmp, sizeof (uint32_t), 1, ctxt->fd) != 1)
    {
      if (ferror (ctxt->fd))
        vcd_error ("fread (): %s", strerror (errno));

      if (feof (ctxt->fd))
        vcd_warn ("premature end of file encountered");

      fclose (ctxt->fd);
      if (ctxt->fd_out)
        fclose (ctxt->fd_out);
      exit (EXIT_FAILURE);
    }

  return uint32_from_le (tmp);
}

static int
handler_RIFF (riff_context *ctxt)
{
  const uint32_t size = read_le_u32 (ctxt);

  vcd_info ("RIFF data[%u]", (unsigned int) size);

  ctxt->lsize = ctxt->size = size;

  return next_id (ctxt);
}

static int
handler_CDXA (riff_context *ctxt)
{
  vcd_info ("CD-XA RIFF detected");

  next_id (ctxt); /* fmt */
  next_id (ctxt); /* data */

  return 0;
}

static int
handler_data (riff_context *ctxt)
{
  const uint32_t size = read_le_u32 (ctxt);
  uint32_t sectors;

  if (size % CDIO_CD_FRAMESIZE_RAW)
    vcd_warn ("size not a multiple of %u bytes!!", CDIO_CD_FRAMESIZE_RAW);
  sectors = size / CDIO_CD_FRAMESIZE_RAW;

  vcd_info ("CD-XA data[%u] (%u sectors)", (unsigned int) size, 
            (unsigned int) sectors);

  if (ctxt->fd_out)
    {
      long first_nzero = -1, last_nzero = -1, s;
      struct {
	uint8_t sync[CDIO_CD_SYNC_SIZE];
	uint8_t header[CDIO_CD_HEADER_SIZE];
	uint8_t subheader[CDIO_CD_SUBHEADER_SIZE];
	uint8_t data[M2F2_SECTOR_SIZE];
	uint8_t edc[CDIO_CD_EDC_SIZE];
      } GNUC_PACKED sbuf;

      vcd_assert (sizeof (sbuf) == CDIO_CD_FRAMESIZE_RAW);

      vcd_info ("...converting...");

      for (s = 0; s < sectors; s++)
	{
	  int r = fread (&sbuf, CDIO_CD_FRAMESIZE_RAW, 1, ctxt->fd);
	  bool empty = true;

	  {
	    int i;
	    for (i = 0; (i < M2F2_SECTOR_SIZE) && !sbuf.data[i]; i++);
	    empty = i == M2F2_SECTOR_SIZE;
	  }

	  if (!r)
	    {
	      if (ferror (ctxt->fd))
		vcd_error ("fread (): %s", strerror (errno));

	      if (feof (ctxt->fd))
		vcd_warn ("premature end of file encountered after %ld sectors", s);

	      fclose (ctxt->fd);
	      fclose (ctxt->fd_out);
	      exit (EXIT_FAILURE);
	    }

	  if (empty)
	    {
	      if (first_nzero == -1)
		continue;
	    }
	  else
	    {
	      last_nzero = s;

	      if (first_nzero == -1)
		first_nzero = s;
	    }

	  fwrite (&sbuf.data, M2F2_SECTOR_SIZE, 1, ctxt->fd_out);
	}

      fflush (ctxt->fd_out);

      {
	const long allsecs = (last_nzero - first_nzero + 1);
	ftruncate (fileno (ctxt->fd_out), allsecs * M2F2_SECTOR_SIZE);

	vcd_info ("...stripped %ld leading and %ld trailing empty sectors...",
		first_nzero, (sectors - last_nzero - 1));
	vcd_info ("...extraction done (%ld sectors extracted to file)!", allsecs);
      }
    }
  else
    vcd_warn ("no extraction done, since no output file was given");

  return 0;
}

static int
handler_fmt (riff_context *ctxt)
{
  uint8_t buf[1024] = { 0, };
  const uint32_t size = read_le_u32 (ctxt);
  int i;

  vcd_assert (size < sizeof (buf));
  if (fread (buf, 1, (size % 2) ? size + 1 : size, ctxt->fd) != ((size % 2) ? size + 1 : size))
    {
      if (ferror (ctxt->fd))
        vcd_error ("fread (): %s", strerror (errno));

      if (feof (ctxt->fd))
        vcd_warn ("premature end of file encountered");

      fclose (ctxt->fd);
      if (ctxt->fd_out)
        fclose (ctxt->fd_out);
      exit (EXIT_FAILURE);
    }

  {
    char *strbuf = calloc(1, 1 + size * 6);
    strbuf[0] = '\0';

    for (i = 0; i < size; i++)
      {
        char _buf[7] = { 0, };
        snprintf (_buf, sizeof (_buf) - 1, "%.2x ", buf[i]);
        strcat (strbuf, _buf);
      }

    vcd_info ("CD-XA fmt[%u] = 0x%s", (unsigned int) size, strbuf);

    free (strbuf);
  }

  return 0;
}

static int
handle (riff_context *ctxt, char id[4])
{
  struct {
    char id[4];
    int (*handler) (riff_context *);
  } handlers[] = {
    { "RIFF", handler_RIFF},
    { "CDXA", handler_CDXA},
    { "fmt ", handler_fmt},
    { "data", handler_data},
    { "", 0}
  }, *p = handlers;

  for (; p->id[0]; p++)
    if (!strncmp (p->id, id, 4))
      return p->handler (ctxt);

  vcd_warn ("unknown chunk id [%.4s] encountered", id);

  return -1;
}

static int
next_id (riff_context *ctxt)
{
  char id[4] = { 0, };

  if (fread (id, 1, 4, ctxt->fd) != 4)
    {
      if (ferror (ctxt->fd))
        vcd_error ("fread (): %s", strerror (errno));

      if (feof (ctxt->fd))
        vcd_warn ("premature end of file encountered");

      fclose (ctxt->fd);
      if (ctxt->fd_out)
        fclose (ctxt->fd_out);
      exit (EXIT_FAILURE);
    }

  return handle (ctxt, id);
}

int
main (int argc, const char *argv[])
{
  FILE *in = NULL, *out = NULL;
  riff_context ctxt = { 0, };

  gl.default_vcd_log_handler = vcd_log_set_handler (_vcd_log_handler);

  {
    struct poptOption optionsTable[] =
      {
        {"verbose", 'v', POPT_ARG_NONE, &gl.verbose_flag, 0, "be verbose"},
        {"quiet", 'q', POPT_ARG_NONE, &gl.quiet_flag, 0, "show only critical messages"},
        {"version", 'V', POPT_ARG_NONE, NULL, 1, "display version and copyright information and exit"},

        POPT_AUTOHELP
        {NULL, 0, 0, NULL, 0}
      };

    int opt;

    const char **args = NULL;

    poptContext optCon = poptGetContext ("vcdimager", argc, argv, optionsTable, 0);
    poptSetOtherOptionHelp (optCon, "[OPTION...] <input-cdxa-file> [<output-mpeg-file>]");

    if (poptReadDefaultConfig (optCon, 0))
      fprintf (stderr, "warning, reading popt configuration failed\n");

    while ((opt = poptGetNextOpt (optCon)) != -1)
      switch (opt)
        {
        case 1:
          fprintf (stdout, vcd_version_string (true), "cdxa2mpeg");
          fflush (stdout);
          poptFreeContext(optCon);
          exit (EXIT_SUCCESS);
          break;
        default:
          vcd_error ("error while parsing command line - try --help");
          break;
        }

    if (gl.verbose_flag && gl.quiet_flag)
      vcd_error ("I can't be both, quiet and verbose... either one or another ;-)");

    if ((args = poptGetArgs (optCon)) == NULL)
      vcd_error ("need at least an input argument -- try --help");

    vcd_assert (args[0] != 0);

    if (args[1] && args[2])
      vcd_error ("too many arguments -- try --help");

    in = fopen (args[0], "rb");
    if (!in)
      {
        vcd_error ("fopen (`%s'): %s", args[0], strerror (errno));
        poptFreeContext(optCon);
        exit (EXIT_FAILURE);
      }

    if (args[1]) {
      if ( strcmp(args[0], args[1]) == 0 ) 
        {
          vcd_error ("input and output can't refer to the same file");
          poptFreeContext(optCon);
          exit (EXIT_FAILURE);
        }
           
      out = fopen (args[1], "wb");
      if (!out)
        {
          vcd_error ("fopen (`%s'): %s", args[1], strerror (errno));
          poptFreeContext(optCon);
          exit (EXIT_FAILURE);
	}
    }

    poptFreeContext(optCon);
  }

  ctxt.fd = in;
  ctxt.fd_out = out;

  next_id (&ctxt);

  if (in)
    fclose (in);

  if (out)
    fclose (out);

  return 0;
}

/*
  Local Variables:
  c-file-style: "gnu"
  tab-width: 8
  indent-tabs-mode: nil
  End:
*/

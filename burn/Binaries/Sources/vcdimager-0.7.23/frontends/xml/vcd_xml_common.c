/*
    $Id: vcd_xml_common.c,v 1.12 2005/02/09 08:50:31 rocky Exp $

    Copyright (C) 2001 Herbert Valerio Riedel <hvr@gnu.org>

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

/* Private includes */
#include "vcd_assert.h"
#include "vcd.h"
#include <libxml/parser.h>


#include "vcd_xml_common.h"

static const char _rcsid[] = "$Id: vcd_xml_common.c,v 1.12 2005/02/09 08:50:31 rocky Exp $";

bool vcd_xml_gui_mode = false;

const char *vcd_xml_progname = "UNSET";
const char *vcd_xml_filename_charset = "UTF-8";

vcd_log_level_t vcd_xml_verbosity = VCD_LOG_INFO;

bool vcd_xml_show_progress = false;

bool vcd_xml_check_mode = false;

static vcd_log_handler_t __default_vcd_log_handler = 0;

static void 
_vcd_xml_log_handler (vcd_log_level_t level, const char message[])
{

  if (level < vcd_xml_verbosity)
    return;

  if (vcd_xml_gui_mode)
    {
      const char *_level_str = "unknown";

      switch (level)
	{
	case VCD_LOG_DEBUG:
	  _level_str = "debug";
	  break;
	case VCD_LOG_WARN:
	  _level_str = "warning";
	  break;
	case VCD_LOG_INFO:
	  _level_str = "information";
	  break;
	case VCD_LOG_ASSERT:
	  _level_str = "assertion";
	  break;
	case VCD_LOG_ERROR:
	  _level_str = "error";
	  break;
	}

      fprintf (stdout, "<log level=\"%s\">%s</log>\n", _level_str, message);
      fflush (stdout);
    }
  else
    __default_vcd_log_handler (level, message);

  if (level == VCD_LOG_ERROR
      || level == VCD_LOG_ASSERT)
    exit (EXIT_FAILURE);
}

void
vcd_xml_log_init (void)
{
  vcd_assert (__default_vcd_log_handler == 0);
  __default_vcd_log_handler = vcd_log_set_handler (_vcd_xml_log_handler);
}

int 
vcd_xml_scan_progress_cb (const vcd_mpeg_prog_info_t *info, void *user_data)
{
  const bool _last = info->current_pos == info->length;

  if (!vcd_xml_show_progress)
    return 0;

  if (vcd_xml_gui_mode)
    fprintf (stdout, "<progress operation=\"scan\" id=\"%s\" position=\"%ld\" size=\"%ld\" />\n",
	     (char *) user_data, info->current_pos, info->length);
  else
    {
      fprintf (stdout, "#scan[%s]: %ld/%ld (%2.0f%%)          \r",
	       (char *) user_data, info->current_pos, info->length,
	       (double) info->current_pos / info->length * 100);

      if (_last)
	{
	  fflush (stdout);

	  fprintf (stdout, "                                                                            \r");
	}
    }

  fflush (stdout);

  return 0;
}

int
vcd_xml_read_progress_cb (const _read_progress_t *info, void *user_data)
{
  const bool _last = info->done == info->total;

  if (!vcd_xml_show_progress)
    return 0;
  
  if (vcd_xml_gui_mode)
    fprintf (stdout, "<progress operation=\"extract\" id=\"%s\" position=\"%ld\" size=\"%ld\" />\n",
	     (char *) user_data, info->done, info->total);
  else
    {
      fprintf (stdout, "#extract[%s]: %ld/%ld (%2.0f%%)          \r",
	       (char *) user_data, info->done, info->total,
	       (double) info->done / info->total * 100);
      
      if (_last)
	{
	  fflush (stdout);

	  fprintf (stdout, "                                                                            \r");
	}
    }

  fflush (stdout);

  return 0;
}

int
vcd_xml_write_progress_cb (const progress_info_t *info, void *user_data)
{
  const bool _last = info->sectors_written == info->total_sectors;

  if (!vcd_xml_show_progress)
    return 0;

  if (vcd_xml_gui_mode)
    fprintf (stdout, "<progress operation=\"write\" position=\"%ld\" size=\"%ld\" />\n",
	     info->sectors_written, info->total_sectors);
  else
    {
      fprintf (stdout, "#write[%d/%d]: %ld/%ld (%2.0f%%)          \r",
	       info->in_track, info->total_tracks, info->sectors_written,
	       info->total_sectors,
	       (double) info->sectors_written / info->total_sectors * 100);
      
      if (_last)
	{
	  fflush (stdout);

	  fprintf (stdout, "                                                                            \r");
	}
    }

  fflush (stdout);

  return 0;
}

void vcd_xml_print_version (void)
{
  if (vcd_xml_gui_mode)
    {
      char buf[] = VERSION;
      char *major, *minor, *micro;

      major = buf;
      minor = strchr (major, '.');

      vcd_assert (minor != NULL);

      *minor++ = '\0';

      micro = strchr (minor, '.');

      vcd_assert (micro != NULL);

      *micro++ = '\0';

      fprintf (stdout,
	       "<version program=\"%s\""
	       " major=\"%s\" minor=\"%s\" micro=\"%s\""
	       " platform=\"%s\" />\n",
	       vcd_xml_progname,
	       major, minor, micro,
	       HOST_ARCH);
    }
  else
    fprintf (stdout, vcd_version_string (true), vcd_xml_progname);

}

static char *
_convert (const char in[], const char encoding[], bool from)
{
  unsigned char *out;
  int ret, size, out_size, temp;
  xmlCharEncodingHandlerPtr handler = 0;

  if (!in)
    return 0;

  if (!(handler = xmlFindCharEncodingHandler (encoding))) {
    vcd_error ("could not find charset conversion handler for '%s'", encoding);
    return 0;
  }

  size = (int) strlen (in) + 1;
  out_size = size * 2 - 1;
  out = malloc ((size_t) out_size);

  vcd_assert (out != 0);

  temp = size - 1;
  if (from) {
    if (NULL != handler->output)  
      ret = handler->output (out, &out_size, (const unsigned char *) in, &temp);
    else
      return strdup(in);
  } else {
    if (NULL != handler->input)  
      ret = handler->input (out, &out_size, (const unsigned char *) in, &temp);
    else
      return strdup(in);
  }

  if (ret < 0 || (temp - size + 1))
    {
      free (out);
      vcd_error ("charset conversion failed for encoding '%s'", encoding);
      return 0;
    }

  out = realloc (out, out_size + 1);
  out[out_size] = 0;

  return (char *) out;
}


unsigned char *
vcd_xml_filename_to_utf8 (const char fname[])
{
  return (unsigned char *) _convert (fname, vcd_xml_filename_charset, false);
}

char *
vcd_xml_utf8_to_filename (const unsigned char fname[])
{
  return _convert ((const char *) fname, vcd_xml_filename_charset, true);
  fflush (stdout);
}

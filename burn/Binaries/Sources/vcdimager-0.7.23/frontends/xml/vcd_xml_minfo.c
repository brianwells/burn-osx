/*
    $Id: vcd_xml_minfo.c,v 1.12 2005/05/08 03:48:55 rocky Exp $

    Copyright (C) 2001, 2005 Herbert Valerio Riedel <hvr@gnu.org>

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
#include <stdio.h>
#include <string.h>
#include <stdarg.h>
#include <errno.h>

#include <popt.h>

/* Private headers */
#include "mpeg_stream.h"
#include "stream_stdio.h"
#include "util.h"
#include "vcd.h"

#include "vcd_xml_common.h"

static const char _rcsid[] = "$Id: vcd_xml_minfo.c,v 1.12 2005/05/08 03:48:55 rocky Exp $";


enum {
  OP_NONE = 0,
  OP_VERSION = 1 << 1
};

static int _TAG_LEVEL = 0;
static char *_TAG_STACK[16];

static FILE *_TAG_FD = 0;

static void
_TAG_INDENT (void)
{
  int _i;

  for (_i = 0; _i < _TAG_LEVEL; _i++) 
    fputs ("  ", _TAG_FD);  
}

static void
_TAG_OPEN (const char tag[], const char fmt[], ...)
{
  va_list args;
  va_start (args, fmt);

  _TAG_STACK[_TAG_LEVEL] = strdup (tag);

  _TAG_INDENT();
  if (fmt)
    {
      char buf[1024] = { 0, };

      vsnprintf (buf, sizeof (buf), fmt, args);

      fprintf (_TAG_FD, "<%s %s>", tag, buf);
    }
  else
    fprintf (_TAG_FD, "<%s>", tag);

  fputs ("\n", _TAG_FD);

  _TAG_LEVEL++;

  va_end (args);
}

static void
_TAG_CLOSE (void)
{
  _TAG_LEVEL--;

  _TAG_INDENT();
  fprintf (_TAG_FD, "</%s>\n", _TAG_STACK[_TAG_LEVEL]);

  free (_TAG_STACK[_TAG_LEVEL]);
}

static void
_TAG_COMMENT (const char fmt[]) 
{
  _TAG_INDENT ();
  fprintf (_TAG_FD, " <!-- %s -->\n", fmt);
}

static void
_TAG_PRINT (const char tag[], const char fmt[], ...) 
{
  va_list args;
  va_start (args, fmt);

  _TAG_INDENT ();

  if (fmt)
    {
      char buf[1024] = { 0, };

      vsnprintf (buf, sizeof (buf), fmt, args);

      fprintf (_TAG_FD, "<%s>%s</%s>", tag, buf, tag);
    }
  else
    fprintf (_TAG_FD, "<%s />", tag);

  fputs ("\n", _TAG_FD);

  va_end (args);
}

#define _TAG_PRINT2(tag, tp, val) \
 { _TAG_INDENT (); fprintf (_TAG_FD, "<" tag ">" tp "</" tag ">\n", val); }

int
main (int argc, const char *argv[])
{
  char *_mpeg_fname = NULL;
  int _generic_info = 0;
  int _relaxed_aps = 0;
  int _dump_aps = 0;

  int _quiet_flag = 0;
  int _verbose_flag = 0;
  int _progress_flag = 0;
  int _gui_flag = 0;

  char *_output_file = 0;

  vcd_xml_progname = "vcdxminfo";

  vcd_xml_log_init ();

  /* command line processing */
  {
    int opt = 0;

    struct poptOption optionsTable[] = {
      {"generic-info", 'i', POPT_ARG_NONE, &_generic_info, OP_NONE,
       "show generic information"},

      {"dump-aps", 'a', POPT_ARG_NONE, &_dump_aps, OP_NONE,
       "dump APS data"},

      {"relaxed-aps", '\0', POPT_ARG_NONE, &_relaxed_aps, OP_NONE,
       "relax APS constraints"},

      {"output-file", 'o', POPT_ARG_STRING, &_output_file, OP_NONE,
       "file for XML output", "FILE"},

      {"progress", 'p', POPT_ARG_NONE, &_progress_flag, 0,  
       "show progress"}, 
      
      {"verbose", 'v', POPT_ARG_NONE, &_verbose_flag, OP_NONE, 
       "be verbose"},
    
      {"quiet", 'q', POPT_ARG_NONE, &_quiet_flag, OP_NONE, 
       "show only critical messages"},

      {"gui", '\0', POPT_ARG_NONE, &_gui_flag, 0, "enable GUI mode"},

      {"version", 'V', POPT_ARG_NONE, NULL, OP_VERSION,
       "display version and copyright information and exit"},

      POPT_AUTOHELP

      {NULL, 0, 0, NULL, 0}
    };

    poptContext optCon = poptGetContext (NULL, argc, argv, optionsTable, 0);

    /* end of local declarations */

    while ((opt = poptGetNextOpt (optCon)) != -1)
      switch (opt)
        {
        case OP_VERSION:
          vcd_xml_gui_mode = _gui_flag;
          vcd_xml_print_version ();
          exit (EXIT_SUCCESS);
          break;

        default:
          fprintf (stderr, "error while parsing command line - try --help\n");
          exit (EXIT_FAILURE);
          break;
        }

    {
      const char **args = NULL;
      int n;

      if ((args = poptGetArgs (optCon)) == NULL)
        vcd_error ("mpeg input file argument missing -- try --help");

      for (n = 0; args[n]; n++);

      if (n != 1)
        vcd_error ("only one xml input file argument allowed -- try --help");

      _mpeg_fname = strdup (args[0]);
    }

    poptFreeContext (optCon);
  } /* command line processing */

  if (_quiet_flag)
    vcd_xml_verbosity = VCD_LOG_WARN;
  else if (_verbose_flag)
    vcd_xml_verbosity = VCD_LOG_DEBUG;
  else
    vcd_xml_verbosity = VCD_LOG_INFO;

  if (_gui_flag)
    vcd_xml_gui_mode = true;

  if (_progress_flag)
    vcd_xml_show_progress = true;

  {
    VcdMpegSource_t *src;
    CdioListNode_t *n;

    vcd_debug ("trying to open mpeg stream...");

    src = vcd_mpeg_source_new (vcd_data_source_new_stdio (_mpeg_fname));

    vcd_mpeg_source_scan (src, _relaxed_aps ? false : true, false,
                          vcd_xml_show_progress ? vcd_xml_scan_progress_cb : NULL, _mpeg_fname);

    vcd_debug ("stream scan completed");

    fflush (stdout);

    if (_output_file && strcmp (_output_file, "-"))
      {
        if (!(_TAG_FD = fopen (_output_file, "w")))
          vcd_error ("fopen (): %s", strerror (errno));
      }
    else
      {
        _TAG_FD = stdout;
        _output_file = 0;
      }

    _TAG_OPEN ("mpeg-info", "src=\"%s\"", _mpeg_fname);

    if (_generic_info)
      { 
        const struct vcd_mpeg_stream_info *_info = vcd_mpeg_source_get_info (src);
        int i;

        _TAG_OPEN ("mpeg-properties", 0);

        _TAG_PRINT ("version", "%d", _info->version);

        _TAG_PRINT ("playing-time", "%f", _info->playing_time);
        _TAG_PRINT ("pts-offset", "%f", _info->min_pts);
        _TAG_PRINT ("packets", "%d", _info->packets);

        _TAG_PRINT ("bit-rate", "%d", (int) _info->muxrate);

        for (i = 0; i < 3; i++)
          {
            const struct vcd_mpeg_stream_vid_info *_vinfo = &_info->shdr[i];

            if (!_vinfo->seen)
              continue;

            _TAG_OPEN ("video-stream", "index=\"%d\"", i);

            {
              const char *_str[] = {
                "motion video stream",
                "still picture stream",
                "secondary still picture stream"
              };

              _TAG_COMMENT (_str[i]);
            }

            _TAG_PRINT ("horizontal-size", "%d", _vinfo->hsize);
            _TAG_PRINT ("vertical-size", "%d", _vinfo->vsize);
            _TAG_PRINT ("frame-rate", "%f", _vinfo->frate);
            
            _TAG_PRINT ("bit-rate", "%d", _vinfo->bitrate);

            if (_dump_aps && _vinfo->aps_list)
              {
                _TAG_OPEN ("aps-list", 0);
                if (_relaxed_aps)
                  _TAG_COMMENT ("relaxed aps");

                _CDIO_LIST_FOREACH (n, _vinfo->aps_list)
                  {
                    struct aps_data *_data = _cdio_list_node_data (n);
                    
                    _TAG_INDENT ();
                    fprintf (_TAG_FD, "<aps packet-no=\"%u\">%f</aps>\n",
                             (unsigned int) _data->packet_no, 
                             _data->timestamp);
                  }

                _TAG_CLOSE ();
              }

            _TAG_CLOSE ();
          }

        for (i = 0; i < 3; i++)
          {
            const struct vcd_mpeg_stream_aud_info *_ainfo = &_info->ahdr[i];

            if (!_ainfo->seen)
              continue;

            _TAG_OPEN ("audio-stream", "index=\"%d\"", i);

            {
              const char *_str[] = {
                "base audio stream",
                "secondary audio stream",
                "extended MC5.1 audio stream"
              };

              _TAG_COMMENT (_str[i]);
            }
            
            _TAG_PRINT ("layer", "%d", _ainfo->layer);
            _TAG_PRINT ("sampling-frequency", "%d", _ainfo->sampfreq);
            _TAG_PRINT ("bit-rate", "%d", _ainfo->bitrate);

            {
              const char *_mode_str[] = {
                "invalid",
                "stereo",
                "joint_stereo",
                "dual_channel",
                "single_channel",
                "invalid"
              };
              _TAG_PRINT ("mode", "%s", _mode_str[_ainfo->mode]);
            }

            _TAG_CLOSE ();
          }

        for (i = 0; i < 4; i++)
          {
            if (!_info->ogt[i])
              continue;

            _TAG_OPEN ("ogt-stream", "index=\"%d\"", i);
            _TAG_CLOSE ();
          }


        /* fprintf (stdout, " v: %d a: %d\n", _info->video_type, _info->audio_type); */

        _TAG_CLOSE ();
      }

    _TAG_CLOSE ();

    if (_output_file)
      fclose (_TAG_FD);
    else
      fflush (_TAG_FD);

    vcd_mpeg_source_destroy (src, true);
  }

  free (_mpeg_fname);

  return EXIT_SUCCESS;
}

/* 
 * Local variables:
 *  c-file-style: "gnu"
 *  tab-width: 8
 *  indent-tabs-mode: nil
 * End:
 */

/*
    $Id: vcdimager.c,v 1.48 2005/06/09 00:53:23 rocky Exp $

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

/* Private includes */
#include "vcd.h"
#include "vcd_assert.h"
#include "image_sink.h"
#include "stream_stdio.h"
#include "util.h"

/* Public includes */
#include <cdio/bytesex.h>
#include <libvcd/logging.h>
#include <libvcd/sector.h>

#include <stdio.h>
#ifdef HAVE_STDLIB_H
#include <stdlib.h>
#endif
#ifdef HAVE_STRING_H
#include <string.h>
#endif
#include <time.h>

#include <popt.h>

static const char _rcsid[] = "$Id: vcdimager.c,v 1.48 2005/06/09 00:53:23 rocky Exp $";

/* defaults */
#define DEFAULT_CUE_FILE       "videocd.cue"
#define DEFAULT_BIN_FILE       "videocd.bin"
#define DEFAULT_VOLUME_ID      "VIDEOCD"
#define DEFAULT_APPLICATION_ID ""
#define DEFAULT_ALBUM_ID       ""
#define DEFAULT_TYPE           "vcd2"

/* global stuff kept as a singleton makes for less typing effort :-) 
 */

struct add_files_t {
  char *fname;
  char *iso_fname;
  int raw_flag;
};

static struct {
  const char *type;
  const char *image_fname;
  const char *cue_fname;
  const char *create_timestr;
  char **track_fnames;

  CdioList_t *add_files;

  const char *volume_label;
  const char *application_id;
  const char *album_id;

  int volume_number;
  int volume_count;

  int sector_2336_flag;
  int broken_svcd_mode_flag;
  int update_scan_offsets;

  int verbose_flag;
  int quiet_flag;
  int check_flag;

  vcd_log_handler_t default_vcd_log_handler;
} gl = { 0, };                             /* global */


static void
gl_add_file (char *fname, char *iso_fname, int raw_flag)
{
  struct add_files_t *tmp = calloc(1, sizeof (struct add_files_t));

  _cdio_list_append (gl.add_files, tmp);

  tmp->fname = fname;
  tmp->iso_fname = iso_fname;
  tmp->raw_flag = raw_flag;
}

static void
gl_add_dir (char *iso_fname)
{
  gl_add_file (NULL, iso_fname, false);
}


/****************************************************************************/

static VcdObj_t *gl_vcd_obj = NULL;

static void 
_vcd_log_handler (vcd_log_level_t level, const char message[])
{
  if (level == VCD_LOG_DEBUG && !gl.verbose_flag)
    return;

  if (level == VCD_LOG_INFO && gl.quiet_flag)
    return;
  
  gl.default_vcd_log_handler (level, message);
}

static int
_parse_file_arg (const char *arg, char **fname1, char **fname2)
{
  int rc = 0;
  char *tmp, *arg_cpy = strdup (arg);

  *fname1 = *fname2 = NULL;

  tmp = strtok(arg_cpy, ",");
  if (tmp)
    *fname1 = strdup (tmp);
  else
    rc = -1;
  
  tmp = strtok(NULL, ",");
  if (tmp)
    *fname2 = strdup (tmp);
  else
    rc = -1;
  
  tmp = strtok(NULL, ",");
  if (tmp)
    rc = -1;

  free (tmp);

  if(rc)
    {
      free (*fname1);
      free (*fname2);

      *fname1 = *fname2 = NULL;
    }

  return rc;
}

int
main (int argc, const char *argv[])
{
  int n = 0;
  vcd_type_t type_id;
  CdioListNode_t *node;
  time_t create_time;

  /* g_set_prgname (argv[0]); */

  gl.cue_fname = DEFAULT_CUE_FILE;
  gl.create_timestr = NULL;
  gl.image_fname = DEFAULT_BIN_FILE;
  gl.track_fnames = NULL;

  gl.type = DEFAULT_TYPE;

  gl.volume_label = DEFAULT_VOLUME_ID;
  gl.application_id = DEFAULT_APPLICATION_ID;
  gl.album_id = DEFAULT_ALBUM_ID;
  
  gl.volume_count = 1;
  gl.volume_number = 1;

  gl.default_vcd_log_handler = vcd_log_set_handler (_vcd_log_handler);

  gl.add_files = _cdio_list_new ();

  {
    const char **args = NULL;
    int opt = 0;

    enum {
      CL_VERSION = 1,
      CL_ADD_DIR,
      CL_ADD_FILE,
      CL_ADD_FILE_RAW
    };

    struct poptOption optionsTable[] = 
      {
        {"type", 't', POPT_ARG_STRING, &gl.type, 0,
         "select VideoCD type ('vcd11', 'vcd2', 'svcd' or 'hqvcd')"
         " (default: '" DEFAULT_TYPE "')", "TYPE"},

        {"cue-file", 'c', POPT_ARG_STRING, &gl.cue_fname, 0,
         "specify cue file for output (default: '" DEFAULT_CUE_FILE "')",
         "FILE"},
      
        {"bin-file", 'b', POPT_ARG_STRING, &gl.image_fname, 0,
         "specify bin file for output (default: '" DEFAULT_BIN_FILE "')",
         "FILE"},

        {"iso-volume-label", 'l', POPT_ARG_STRING, &gl.volume_label, 0,
         "specify ISO volume label for video cd (default: '" DEFAULT_VOLUME_ID
         "')", "LABEL"},

        {"iso-application-id", '\0', POPT_ARG_STRING, &gl.application_id, 0,
         "specify ISO application id for video cd (default: '" 
         DEFAULT_APPLICATION_ID "')", "LABEL"},

        {"info-album-id", '\0', POPT_ARG_STRING, &gl.album_id, 0,
         "specify album id for video cd set (default: '" DEFAULT_ALBUM_ID
         "')", "LABEL"},

        {"volume-count", '\0', POPT_ARG_INT, &gl.volume_count, 0,
         "specify number of volumes in album set", "NUMBER"},

        {"volume-number", '\0', POPT_ARG_INT, &gl.volume_number, 0,
         "specify album set sequence number (< volume-count)", "NUMBER"},

        {"broken-svcd-mode", '\0', POPT_ARG_NONE, &gl.broken_svcd_mode_flag, 0,
         "enable non-compliant compatibility mode for broken devices"},

        {"update-scan-offsets", '\0', POPT_ARG_NONE, &gl.update_scan_offsets, 0,
         "update scan data offsets in video mpeg2 stream"},
        
        {"sector-2336", '\0', POPT_ARG_NONE, &gl.sector_2336_flag, 0,
         "use 2336 byte sectors for output"},

        {"add-dir", '\0', POPT_ARG_STRING, NULL, CL_ADD_DIR, 
         "add empty dir to ISO fs", "ISO_DIRNAME"},

        {"add-file", '\0', POPT_ARG_STRING, NULL, CL_ADD_FILE, 
         "add single file to ISO fs", "FILE,ISO_FILENAME"},

        {"add-file-2336", '\0', POPT_ARG_STRING, NULL, CL_ADD_FILE_RAW, 
         "add file containing full 2336 byte sectors to ISO fs",
         "FILE,ISO_FILENAME"},

        {"create-time", 'T', POPT_ARG_STRING, &gl.create_timestr, 0,
         "specify creation date on files in CD image (default: current date)"},
      
        {"progress", 'p', POPT_ARG_NONE | POPT_ARGFLAG_DOC_HIDDEN,
         NULL, 0, "show progress"},

        {"check", '\0', POPT_ARG_NONE | POPT_ARGFLAG_DOC_HIDDEN, 
         &gl.check_flag, 0, "enabled check mode"},

        {"verbose", 'v', POPT_ARG_NONE, &gl.verbose_flag, 0, "be verbose"},

        {"quiet", 'q', POPT_ARG_NONE, &gl.quiet_flag, 0, 
         "show only critical messages"},

        {"version", 'V', POPT_ARG_NONE, NULL, CL_VERSION,
         "display version and copyright information and exit"},

        POPT_AUTOHELP 

        {NULL, 0, 0, NULL, 0}
      };
    
    poptContext optCon = poptGetContext ("vcdimager", argc, argv, optionsTable, 0);
    poptSetOtherOptionHelp (optCon, "[OPTION...] <mpeg-tracks...>");

    if (poptReadDefaultConfig (optCon, 0)) 
      fprintf (stderr, "warning, reading popt configuration failed\n"); 

    while ((opt = poptGetNextOpt (optCon)) != -1)
      switch (opt)
        {
        case CL_VERSION:
          fprintf (stdout, vcd_version_string (true), "vcdimager");
          fflush (stdout);
          poptFreeContext(optCon);
          exit (EXIT_SUCCESS);
          break;

        case CL_ADD_DIR:
          {
            const char *arg = poptGetOptArg (optCon);

            vcd_assert (arg != NULL);
            gl_add_dir (strdup (arg));
          }
          break;
          
        case CL_ADD_FILE:
        case CL_ADD_FILE_RAW:
          {
            const char *arg = poptGetOptArg (optCon);
            char *fname1 = NULL, *fname2 = NULL;

            vcd_assert (arg != NULL);

            if(!_parse_file_arg (arg, &fname1, &fname2)) 
              gl_add_file (fname1, fname2, (opt == CL_ADD_FILE_RAW));
            else
              {
                fprintf (stderr, "file parsing of `%s' failed\n", arg);
                poptFreeContext(optCon);
                exit (EXIT_FAILURE);
              }
          }
          break;

        default:
          vcd_error ("error while parsing command line - try --help");
          break;
        }

    if (gl.verbose_flag && gl.quiet_flag)
      vcd_error ("I can't be both, quiet and verbose... either one or another ;-)");
    
    if ((args = poptGetArgs (optCon)) == NULL)
      vcd_error ("error: need at least one data track as argument "
                 "-- try --help");

    for (n = 0; args[n]; n++);

    if (n > CDIO_CD_MAX_TRACKS - 1)
      vcd_error ("error: maximal number of supported mpeg tracks (%d) reached",
                 CDIO_CD_MAX_TRACKS - 1);

    gl.track_fnames = calloc(1, sizeof (char *) * (n + 1));

    for (n = 0; args[n]; n++)
      gl.track_fnames[n] = strdup (args[n]);

    {
      struct {
        const char *str;
        vcd_type_t id;
      } type_str[] = 
        {
          { "vcd10", VCD_TYPE_VCD },
          { "vcd11", VCD_TYPE_VCD11 },
          { "vcd2", VCD_TYPE_VCD2 },
          { "vcd20", VCD_TYPE_VCD2 },
          { "svcd", VCD_TYPE_SVCD },
          { "hqvcd", VCD_TYPE_HQVCD },
          { NULL, }
        };
      
      int i = 0;

      while (type_str[i].str) 
        if (strcasecmp(gl.type, type_str[i].str))
          i++;
        else
          break;

      if (!type_str[i].str)
        vcd_error ("invalid type given");
        
      type_id = type_str[i].id;
    }

    poptFreeContext (optCon);
  }

  /* done with argument processing */

  if (!strcmp (gl.image_fname, gl.cue_fname))
    vcd_warn ("bin and cue file seem to be the same"
              " -- cue file may get overwritten by bin file!");

  gl_vcd_obj = vcd_obj_new (type_id);

  if (gl.check_flag)
    vcd_obj_set_param_str (gl_vcd_obj, VCD_PARM_PREPARER_ID, "GNU VCDIMAGER CHECK MODE");

  vcd_obj_set_param_str (gl_vcd_obj, VCD_PARM_VOLUME_ID, gl.volume_label);
  vcd_obj_set_param_str (gl_vcd_obj, VCD_PARM_APPLICATION_ID, 
                         gl.application_id);
  vcd_obj_set_param_str (gl_vcd_obj, VCD_PARM_ALBUM_ID, gl.album_id);

  vcd_obj_set_param_uint (gl_vcd_obj, VCD_PARM_VOLUME_COUNT, gl.volume_count);
  vcd_obj_set_param_uint (gl_vcd_obj, VCD_PARM_VOLUME_NUMBER, 
                          gl.volume_number);

  if (type_id == VCD_TYPE_SVCD)
    {
      vcd_obj_set_param_bool (gl_vcd_obj, VCD_PARM_SVCD_VCD3_MPEGAV,
                              gl.broken_svcd_mode_flag);
      vcd_obj_set_param_bool (gl_vcd_obj, VCD_PARM_SVCD_VCD3_ENTRYSVD,
                              gl.broken_svcd_mode_flag);

      vcd_obj_set_param_bool (gl_vcd_obj, VCD_PARM_UPDATE_SCAN_OFFSETS, 
                              gl.update_scan_offsets);
    }

  create_time = time(NULL);
  if (gl.create_timestr != NULL) {
    if (!strcmp (gl.create_timestr, "TESTING")) 
      create_time = 269236800L;
    else {
#ifdef HAVE_STRPTIME
      struct tm tm;
      
      if (NULL == strptime(gl.create_timestr, "%Y-%m-%d %H:%M:%S", &tm)) {
        vcd_warn("Trouble converting date string %s using strptime.", 
                 gl.create_timestr);
        vcd_warn("String should match %%Y-%%m-%%d %%H:%%M:%%S");
      } else {
        create_time = mktime(&tm);
      }
#else 
      create_time = 269236800L;
#endif
    }
  }

  _CDIO_LIST_FOREACH (node, gl.add_files)
  {
    struct add_files_t *p = _cdio_list_node_data (node);

    if (p->fname)
      {
        fprintf (stdout, "debug: adding [%s] as [%s] (raw=%d)\n", 
                 p->fname, p->iso_fname, p->raw_flag);
        
        if (vcd_obj_add_file(gl_vcd_obj, p->iso_fname,
                             vcd_data_source_new_stdio (p->fname),
                             p->raw_flag))
          {
            fprintf (stderr, 
                     "error while adding file `%s' as `%s' to (S)VCD\n",
                     p->fname, p->iso_fname);
            exit (EXIT_FAILURE);
          }
      }
    else
      {
        fprintf (stdout, "debug: adding empty dir [%s]\n", p->iso_fname);

        if (vcd_obj_add_dir(gl_vcd_obj, p->iso_fname))
          {
            fprintf (stderr, 
                     "error while adding dir `%s' to (S)VCD\n", p->iso_fname);
            exit (EXIT_FAILURE);
          }
      }
  } /* _CDIO_LIST_FOREACH */

  for (n = 0; gl.track_fnames[n] != NULL; n++)
    {
      VcdDataSource_t *data_source;
      
      data_source = vcd_data_source_new_stdio (gl.track_fnames[n]);

      vcd_assert (data_source != NULL);

      vcd_obj_append_sequence_play_item (gl_vcd_obj,
                                         vcd_mpeg_source_new (data_source),
                                         NULL, NULL);
    }


  {
    unsigned sectors;
    VcdImageSink_t *p_image_sink;

    p_image_sink = vcd_image_sink_new_bincue ();

    vcd_image_sink_set_arg (p_image_sink, "bin", gl.image_fname);
    vcd_image_sink_set_arg (p_image_sink, "cue", gl.cue_fname);
    vcd_image_sink_set_arg (p_image_sink, "sector", 
                            gl.sector_2336_flag ? "2336" : "2352");
    
    if (!p_image_sink)
      {
        vcd_error ("failed to create image object");
        exit (EXIT_FAILURE);
      }

    sectors = vcd_obj_begin_output (gl_vcd_obj);

    vcd_obj_write_image (gl_vcd_obj, p_image_sink, NULL, NULL, &create_time);

    vcd_obj_end_output (gl_vcd_obj);

    {
      unsigned _bytes = sectors * 
        (gl.sector_2336_flag ? M2RAW_SECTOR_SIZE : CDIO_CD_FRAMESIZE_RAW);
      char *_msfstr = cdio_lba_to_msf_str (sectors);

      fprintf (stdout, 
               "finished ok, image created with %d sectors [%s] (%d bytes)\n",
               sectors, _msfstr, _bytes);
      
      free (_msfstr);
    }
  }

  return EXIT_SUCCESS;
}


/* 
 * Local variables:
 *  c-file-style: "gnu"
 *  tab-width: 8
 *  indent-tabs-mode: nil
 * End:
 */

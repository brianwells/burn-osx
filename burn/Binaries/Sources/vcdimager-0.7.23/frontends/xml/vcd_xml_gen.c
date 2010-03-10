/*
    $Id: vcd_xml_gen.c,v 1.27 2005/05/07 19:53:21 rocky Exp $

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

#include <sys/types.h>

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <popt.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifdef HAVE_SYS_MMAN_H
#include <sys/mman.h>
#endif
#include <sys/stat.h>
#include <unistd.h>

#include <libvcd/sector.h>

/* Private headers */
#include "data_structures.h"
#include "pbc.h"
#include "util.h"
#include "vcd.h"

#include "vcd_xml_dtd.h"
#include "vcd_xml_dump.h"
#include "vcdxml.h"
#include "vcd_xml_common.h"

static const char _rcsid[] = "$Id: vcd_xml_gen.c,v 1.27 2005/05/07 19:53:21 rocky Exp $";

/* defaults */
#define DEFAULT_SYSTEM_ID      "CD-RTOS CD-BRIDGE"
#define DEFAULT_VOLUME_ID      "VIDEOCD"
#define DEFAULT_APPLICATION_ID ""
#define DEFAULT_ALBUM_ID       ""
#define DEFAULT_TYPE           "vcd2"
#define DEFAULT_XML_FNAME      "videocd.xml"

static int _verbose_flag = 0;
static int _quiet_flag = 0;

/****************************************************************************/

static vcd_type_t
_parse_type_arg (const char arg[])
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
      { NULL, VCD_TYPE_INVALID }
    };
      
  int i = 0;

  while (type_str[i].str) 
    if (strcasecmp(arg, type_str[i].str))
      i++;
    else
      break;

  if (!type_str[i].str)
    fprintf (stderr, "invalid type given\n");
        
  return type_str[i].id;
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

static void
_add_dir (vcdxml_t *obj, const char pathname[])
{
  vcd_assert (pathname != NULL);

  {
    struct filesystem_t *_file = calloc(1, sizeof (struct filesystem_t));
    
    _file->name = strdup (pathname);
    _file->file_src = NULL;
    _file->file_raw = false;

    _cdio_list_append (obj->filesystem, _file);
  }
}

static void
_add_dirtree (vcdxml_t *obj, const char pathname[], 
          const char iso_pathname[])
{
  DIR *dir = NULL;
  struct dirent *dentry = NULL;

  vcd_assert (pathname != NULL);
  vcd_assert (iso_pathname != NULL);

  dir = opendir (pathname);

  if (!dir)
    {
      perror ("--add-dirtree: opendir()");
      exit (EXIT_FAILURE);
    }

  while ((dentry = readdir (dir)))
    {
      char buf[1024] = { 0, };
      char iso_name[1024] = { 0, };
      struct stat st;

      if (!strcmp (dentry->d_name, "."))
        continue;

      if (!strcmp (dentry->d_name, ".."))
        continue;

      strcat (buf, pathname);
      strcat (buf, "/");
      strcat (buf, dentry->d_name);

      strcat (iso_name, dentry->d_name);

      if (stat (buf, &st))
        perror ("stat()");

      if (S_ISDIR(st.st_mode))
        {
          strcat (iso_name, "/");
          _add_dirtree (obj, buf, iso_name);
        }
      else if (S_ISREG(st.st_mode))
        {
          struct filesystem_t *_file = calloc(1, sizeof (struct filesystem_t));

          _file->name = strdup (iso_name);
          _file->file_src = strdup (buf);
          _file->file_raw = false;

          _cdio_list_append (obj->filesystem, _file);
        }
      else
        fprintf (stdout, "ignoring %s\n", buf);
    }

  closedir (dir);
}

static const char *
_lid_str (int n)
{
  static char buf[16];

  snprintf (buf, sizeof (buf), "lid-%3.3d", n);

  return buf;
}

static const char *
_sequence_str (int n)
{
  static char buf[16];

  snprintf (buf, sizeof (buf), "sequence-%2.2d", n);

  return buf;
}

int
main (int argc, const char *argv[])
{
  vcdxml_t obj;
  int n;
  
  char *xml_fname = strdup (DEFAULT_XML_FNAME);
  char *type_str = strdup (DEFAULT_TYPE);
  int broken_svcd_mode_flag = 0;
  int update_scan_offsets_flag = 0;
  int nopbc_flag = 0;

  vcd_xml_progname = "vcdxgen";

  vcd_xml_init (&obj);

  vcd_xml_log_init ();

  obj.pvd.system_id = strdup (DEFAULT_SYSTEM_ID);
  obj.pvd.volume_id = strdup (DEFAULT_VOLUME_ID);
  obj.pvd.application_id = strdup (DEFAULT_APPLICATION_ID);
  obj.info.album_id = strdup (DEFAULT_ALBUM_ID);
  
  obj.info.volume_count = 1;
  obj.info.volume_number = 1;

  {
    const char **args = NULL;
    int opt = 0;

    enum {
      CL_VERSION = 1,
      CL_ADD_DIR,
      CL_ADD_DIRTREE,
      CL_ADD_FILE,
      CL_ADD_FILE_RAW
    };

    struct poptOption optionsTable[] = 
      {
        {"output-file", 'o', POPT_ARG_STRING, &xml_fname, 0,
         "specify xml file for output (default: '" DEFAULT_XML_FNAME "')",
         "FILE"},

        {"type", 't', POPT_ARG_STRING, &type_str, 0,
         "select VideoCD type ('vcd11', 'vcd2', 'svcd' or 'hqvcd')"
         " (default: '" DEFAULT_TYPE "')", "TYPE"},

        {"iso-volume-label", 'l', POPT_ARG_STRING, &obj.pvd.volume_id, 0,
         "specify ISO volume label for video cd (default: '" DEFAULT_VOLUME_ID
         "')", "LABEL"},

        {"iso-application-id", '\0', POPT_ARG_STRING, &obj.pvd.application_id, 0,
         "specify ISO application id for video cd (default: '" DEFAULT_APPLICATION_ID
         "')", "LABEL"},

        {"info-album-id", '\0', POPT_ARG_STRING, &obj.info.album_id, 0,
         "specify album id for video cd set (default: '" DEFAULT_ALBUM_ID
         "')", "LABEL"},

        {"volume-count", '\0', POPT_ARG_INT, &obj.info.volume_count, 0,
         "specify number of volumes in album set", "NUMBER"},

        {"volume-number", '\0', POPT_ARG_INT, &obj.info.volume_number, 0,
         "specify album set sequence number (< volume-count)", "NUMBER"},

        {"broken-svcd-mode", '\0', POPT_ARG_NONE, &broken_svcd_mode_flag, 0,
         "enable non-compliant compatibility mode for broken devices"},

        {"update-scan-offsets", '\0', POPT_ARG_NONE, &update_scan_offsets_flag, 0,
         "update scan data offsets in video mpeg2 stream"},

        {"nopbc", '\0', POPT_ARG_NONE, &nopbc_flag, 0, "don't create PBC"},
        
        {"add-dirtree", '\0', POPT_ARG_STRING, NULL, CL_ADD_DIRTREE,
         "add directory contents recursively to ISO fs root", "DIR"},

        {"add-dir", '\0', POPT_ARG_STRING, NULL, CL_ADD_DIR, 
         "add empty dir to ISO fs", "ISO_DIRNAME"},

        {"add-file", '\0', POPT_ARG_STRING, NULL, CL_ADD_FILE, 
         "add single file to ISO fs", "FILE,ISO_FILENAME"},

        {"add-file-2336", '\0', POPT_ARG_STRING, NULL, CL_ADD_FILE_RAW, 
         "add file containing full 2336 byte sectors to ISO fs",
         "FILE,ISO_FILENAME"},

        { "filename-encoding", '\0', POPT_ARG_STRING, &vcd_xml_filename_charset, 0,
          "use given charset encoding for filenames instead of UTF8" },

        {"verbose", 'v', POPT_ARG_NONE, &_verbose_flag, 0, "be verbose"},

        {"quiet", 'q', POPT_ARG_NONE, &_quiet_flag, 0, "show only critical messages"},

        {"version", 'V', POPT_ARG_NONE, NULL, CL_VERSION,
         "display version and copyright information and exit"},

        POPT_AUTOHELP 

        {NULL, 0, 0, NULL, 0}
      };
    
    poptContext optCon = poptGetContext ("vcdimager", argc, argv, optionsTable, 0);
    poptSetOtherOptionHelp (optCon, "mpeg-track1 [mpeg-track2...]");

    if (poptReadDefaultConfig (optCon, 0)) 
      fprintf (stderr, "warning, reading popt configuration failed\n"); 

    while ((opt = poptGetNextOpt (optCon)) != -1)
      switch (opt)
        {
        case CL_VERSION:
          /* vcd_xml_gui_mode = gl.gui_flag; */
          vcd_xml_print_version ();
          exit (EXIT_SUCCESS);
          break;

        case CL_ADD_DIRTREE:
          {
            const char *arg = poptGetOptArg (optCon);

            vcd_assert (arg != NULL);
            
            _add_dirtree (&obj, arg, "");
          }
          break;

        case CL_ADD_DIR:
          {
            const char *arg = poptGetOptArg (optCon);

            vcd_assert (arg != NULL);
            
            _add_dir (&obj, arg);
          }
          break;

        case CL_ADD_FILE:
        case CL_ADD_FILE_RAW:
          {
            const char *arg = poptGetOptArg (optCon);
            char *fname1 = NULL, *fname2 = NULL;

            vcd_assert (arg != NULL);

            if(!_parse_file_arg (arg, &fname1, &fname2)) 
              {
                struct filesystem_t *_file = calloc(1, sizeof (struct filesystem_t));

                _file->name = strdup (fname2);
                _file->file_src = strdup (fname1);
                _file->file_raw = (opt == CL_ADD_FILE_RAW);

                _cdio_list_append (obj.filesystem, _file);
              }
            else
              {
                fprintf (stderr, "file parsing of `%s' failed\n", arg);
                exit (EXIT_FAILURE);
              }
          }
          break;

        default:
          fprintf (stderr, "error while parsing command line - try --help\n");
          exit (EXIT_FAILURE);
          break;
        }

    if (_verbose_flag && _quiet_flag)
      fprintf (stderr, "I can't be both, quiet and verbose... either one or another ;-)");
    
    if ((args = poptGetArgs (optCon)) == NULL)
      {
        fprintf (stderr, "error: need at least one data track as argument "
                 "-- try --help\n");
        exit (EXIT_FAILURE);
      }

    for (n = 0; args[n]; n++)
      {
        struct sequence_t *_seq = calloc(1, sizeof (struct sequence_t));

        _seq->entry_point_list = _cdio_list_new ();
        _seq->autopause_list = _cdio_list_new ();
        _seq->src = strdup (args[n]);
        _seq->id = strdup (_sequence_str (n));

        _cdio_list_append (obj.sequence_list, _seq);
      }

    if (_cdio_list_length (obj.sequence_list) > CDIO_CD_MAX_TRACKS - 1)
      {
        fprintf (stderr, "error: maximal number of supported mpeg tracks (%d) reached",
                 CDIO_CD_MAX_TRACKS - 1);
        exit (EXIT_FAILURE);
      }
                        
    if ((obj.vcd_type = _parse_type_arg (type_str)) == VCD_TYPE_INVALID)
      exit (EXIT_FAILURE);

    poptFreeContext (optCon);
  }

  if (_quiet_flag)
    vcd_xml_verbosity = VCD_LOG_WARN;
  else if (_verbose_flag)
    vcd_xml_verbosity = VCD_LOG_DEBUG;
  else
    vcd_xml_verbosity = VCD_LOG_INFO;

  /* done with argument processing */

  if (obj.vcd_type == VCD_TYPE_VCD11
      || obj.vcd_type == VCD_TYPE_VCD)
    nopbc_flag = true;

  if (!nopbc_flag) 
    {
      pbc_t *_pbc;
      CdioListNode_t *node;

      int n = 0;
      _CDIO_LIST_FOREACH (node, obj.sequence_list)
        {
          struct sequence_t *_sequence = _cdio_list_node_data (node);

          _pbc = vcd_pbc_new (PBC_PLAYLIST);

          _pbc->id = strdup (_lid_str (n));

          if (n)
            _pbc->prev_id = strdup (_lid_str (n - 1));

          if (_cdio_list_node_next (node))
            _pbc->next_id = strdup (_lid_str (n + 1));
          else
            _pbc->next_id = strdup ("lid-end");

          _pbc->retn_id = strdup ("lid-end");

          _pbc->wait_time = 5;

          _cdio_list_append (_pbc->item_id_list, strdup (_sequence->id));
          
          _cdio_list_append (obj.pbc_list, _pbc);

          n++;
        }

      /* create end list */

      _pbc = vcd_pbc_new (PBC_END);
      _pbc->id = strdup ("lid-end");
      _pbc->rejected = true;

      _cdio_list_append (obj.pbc_list, _pbc);
    }

  if ((obj.vcd_type == VCD_TYPE_SVCD 
       || obj.vcd_type == VCD_TYPE_HQVCD)
      && update_scan_offsets_flag)
    {
      struct option_t *_opt = calloc(1, sizeof (struct option_t));
      
      _opt->name = strdup (OPT_UPDATE_SCAN_OFFSETS);
      _opt->value = strdup ("true");

      _cdio_list_append (obj.option_list, _opt);
    }

  if (obj.vcd_type == VCD_TYPE_SVCD 
      && broken_svcd_mode_flag)
    {
      struct option_t *_opt = calloc(1, sizeof (struct option_t));
      
      _opt->name = strdup (OPT_SVCD_VCD3_MPEGAV);
      _opt->value = strdup ("true");

      _cdio_list_append (obj.option_list, _opt);

      _opt = calloc(1, sizeof (struct option_t));
      
      _opt->name = strdup (OPT_SVCD_VCD3_ENTRYSVD);
      _opt->value = strdup ("true");

      _cdio_list_append (obj.option_list, _opt);
    }

  vcd_xml_dump (&obj, xml_fname);

  fprintf (stdout, "(Super) VideoCD xml description created successfully as `%s'\n",
           xml_fname);

  return EXIT_SUCCESS;
}


/* 
 * Local variables:
 *  c-file-style: "gnu"
 *  tab-width: 8
 *  indent-tabs-mode: nil
 * End:
 */

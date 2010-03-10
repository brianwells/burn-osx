/*
    $Id: vcd_xml_build.c,v 1.27 2005/06/09 00:53:23 rocky Exp $

    Copyright (C) 2001, 2003, 2005 Herbert Valerio Riedel <hvr@gnu.org>

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
#include <errno.h>

#include <popt.h>

#include <libxml/parserInternals.h>
#include <libxml/parser.h>
#include <libxml/valid.h>
#include <libxml/xmlmemory.h>
#include <libxml/xmlerror.h>

#include <libvcd/logging.h>
#include <libvcd/types.h>

/* Private headers */
#include "image_sink.h"
#include "stream_stdio.h"
#include "util.h"

#include "vcdxml.h"
#include "vcd_xml_parse.h"
#include "vcd_xml_master.h"
#include "vcd_xml_dtd.h"
#include "vcd_xml_common.h"

static const char _rcsid[] = "$Id: vcd_xml_build.c,v 1.27 2005/06/09 00:53:23 rocky Exp $";

static void
_init_xml (void)
{
  static bool _init_done = false;

  vcd_assert (!_init_done);
  _init_done = true;

  xmlKeepBlanksDefaultValue = false;
  xmlIndentTreeOutput = true; 

  vcd_xml_dtd_init ();
}

#if 0
static void
_dummy_error (void *ctx, const char *msg, ...)
{
  fputs (msg, stdout);
}
#endif

static xmlDocPtr
_xmlParseFile(const char *filename)
{
  xmlDocPtr ret = NULL;
  xmlParserCtxtPtr ctxt = NULL;
  char *directory = NULL;

  /* assert (_init_done == true); */

  ctxt = xmlCreateFileParserCtxt (filename);
  
  if (!ctxt)
    return NULL;

  /* ctxt->keepBlanks = false; */
  ctxt->pedantic = true; 
  ctxt->validate = true;

  if (ctxt->sax)
    {
      ctxt->sax->error = ctxt->sax->fatalError = xmlParserError;
      ctxt->sax->warning = xmlParserWarning;
    }

  ctxt->vctxt.error = xmlParserValidityError;
  ctxt->vctxt.warning = xmlParserValidityWarning;

  ctxt->vctxt.nodeMax = 0;

  if (!ctxt->directory 
      && (directory = xmlParserGetDirectory(filename)))
    ctxt->directory = (char *) xmlStrdup((xmlChar *) directory);
  
  xmlParseDocument(ctxt);

  if (ctxt->wellFormed && ctxt->valid)
    ret = ctxt->myDoc;
  else
    {
      xmlFreeDoc (ctxt->myDoc);
      ctxt->myDoc = NULL;
    }

  xmlFreeParserCtxt(ctxt);
    
  return(ret);
}

#define DEFAULT_CUE_FILE       "videocd.cue"
#define DEFAULT_BIN_FILE       "videocd.bin"
#define DEFAULT_IMG_TYPE       "bincue"

static struct {
  enum {
    IMG_TYPE_BINCUE = 0,
    IMG_TYPE_CDRDAO,
    IMG_TYPE_NRG
  } img_type;

  CdioList_t *img_options;

  char *xml_fname;
  char *file_prefix;
  char *create_timestr;

  int verbose_flag;
  int check_flag;
  int quiet_flag;
  int progress_flag;
  int gui_flag;
} gl;

struct key_val_t {
  char *key;
  char *val;
};

static void
_set_img_opt (const char key[], const char val[])
{
  struct key_val_t *_cons;

  if (!key || !val)
    vcd_error ("invalid image option");

  _cons = calloc(1, sizeof (struct key_val_t));
  _cons->key = strdup (key);
  _cons->val = strdup (val);

  _cdio_list_append (gl.img_options, _cons);
}


static int
_do_cl (int argc, const char *argv[])
{
  const char **args = NULL;
  int n, opt = 0;
  enum { 
    CL_VERSION = 1,
    CL_IMG_TYPE,
    CL_IMG_OPT,
    CL_BIN_FILE,
    CL_CUE_FILE,
    CL_CDRDAO_FILE,
    CL_NRG_FILE,
    CL_2336_FLAG,
    CL_DUMP_DTD
  };
  poptContext optCon = NULL;
  struct poptOption optionsTable[] = 
    {
      {"image-type", 'i', POPT_ARG_STRING, NULL, CL_IMG_TYPE,
       "specify image type for output (default: '" DEFAULT_IMG_TYPE "')",
       "TYPE"},

      {"image-option", 'o', POPT_ARG_STRING, NULL, CL_IMG_OPT,
       "specify image option", "KEY=VALUE"},

      {"cue-file", 'c', POPT_ARG_STRING, NULL, CL_CUE_FILE,
       "specify cue file for output (default: '" DEFAULT_CUE_FILE "')",
       "FILE"},
      
      {"bin-file", 'b', POPT_ARG_STRING, NULL, CL_BIN_FILE,
       "specify bin file for output (default: '" DEFAULT_BIN_FILE "')",
       "FILE"},

      {"cdrdao-file", '\0', POPT_ARG_STRING, NULL, CL_CDRDAO_FILE,
       "specify cdrdao-style image filename base", "FILE"},

      {"nrg-file", '\0', POPT_ARG_STRING | POPT_ARGFLAG_DOC_HIDDEN,
       NULL, CL_NRG_FILE, "specify nrg-style image filename", "FILE"},

      {"sector-2336", '\0', POPT_ARG_NONE, NULL, CL_2336_FLAG,
       "use 2336 byte sectors for output"},

      {"create-time", 'T', POPT_ARG_STRING, &gl.create_timestr, 0,
       "specify creation date on files in CD image (default: current date)"},

      {"progress", 'p', POPT_ARG_NONE, &gl.progress_flag, 0,  
       "show progress"}, 

      {"dump-dtd", '\0', POPT_ARG_NONE, NULL, CL_DUMP_DTD,
       "dump internal DTD to stdout"},

      {"check", '\0', POPT_ARG_NONE | POPT_ARGFLAG_DOC_HIDDEN, 
       &gl.check_flag, 0, "enable check mode (undocumented)"},

      {"file-prefix", '\0', POPT_ARG_STRING | POPT_ARGFLAG_DOC_HIDDEN,
       &gl.file_prefix, 0, "add prefix string to all filenames (undocumented)"}, 

      { "filename-encoding", '\0', POPT_ARG_STRING, &vcd_xml_filename_charset, 0,
        "use given charset encoding for filenames instead of UTF8" },

      {"verbose", 'v', POPT_ARG_NONE, &gl.verbose_flag, 0, 
       "be verbose"},
	
      {"quiet", 'q', POPT_ARG_NONE, &gl.quiet_flag, 0, 
       "show only critical messages"},

      {"gui", '\0', POPT_ARG_NONE, &gl.gui_flag, 0, "enable GUI mode"},

      {"version", 'V', POPT_ARG_NONE, NULL, CL_VERSION,
       "display version and copyright information and exit"},

      POPT_AUTOHELP 

      {NULL, 0, 0, NULL, 0}
    };

  optCon = poptGetContext ("vcdimager", argc, argv, optionsTable, 0);
  poptSetOtherOptionHelp (optCon, "[OPTION...] <xml-control-file>");

  if (poptReadDefaultConfig (optCon, 0)) 
    fprintf (stderr, "warning, reading popt configuration failed\n"); 

  while ((opt = poptGetNextOpt (optCon)) != -1)
    switch (opt)
      {
	const char *opt_arg;

      case CL_DUMP_DTD:
	fputs (videocd_dtd, stdout);
	fflush (stdout);
	exit (EXIT_SUCCESS);
	break;

      case CL_VERSION:
	vcd_xml_gui_mode = gl.gui_flag;
	vcd_xml_print_version ();
	exit (EXIT_SUCCESS);
	break;

      case CL_CDRDAO_FILE:
	opt_arg = poptGetOptArg (optCon);
	gl.img_type = IMG_TYPE_CDRDAO;

	_set_img_opt ("img_base", opt_arg);

	{
	  char buf[1024] = { 0, };
	  strncpy (buf, opt_arg, sizeof (buf));
	  strncat (buf, ".toc", sizeof (buf));

	  _set_img_opt ("toc", buf);
	}
	break;

      case CL_NRG_FILE:
	gl.img_type = IMG_TYPE_NRG;
	_set_img_opt ("nrg", poptGetOptArg (optCon));
	break;

      case CL_BIN_FILE:
	gl.img_type = IMG_TYPE_BINCUE;
	_set_img_opt ("bin", poptGetOptArg (optCon));
	break;

      case CL_CUE_FILE:
	gl.img_type = IMG_TYPE_BINCUE;
	_set_img_opt ("cue", poptGetOptArg (optCon));
	break;

      case CL_2336_FLAG:
	_set_img_opt ("sector", "2336");
	break;

      case CL_IMG_TYPE:
	opt_arg = poptGetOptArg (optCon);
	  
	if (!strcmp (opt_arg, "bincue"))
	  gl.img_type = IMG_TYPE_BINCUE;
	else if (!strcmp (opt_arg, "cdrdao"))
	  gl.img_type = IMG_TYPE_CDRDAO;
	else if (!strcmp (opt_arg, "nrg"))
	  gl.img_type = IMG_TYPE_NRG;
	else
	  vcd_error ("unknown image type '%s'", opt_arg);
	break;

      case CL_IMG_OPT:
	{
	  char buf[1024] = { 0, }, *buf2;
	  opt_arg = poptGetOptArg (optCon);
	 
	  strncpy (buf, opt_arg, sizeof (buf));
	  
	  if ((buf2 = strchr (buf, '=')))
	    {
	      *buf2 = '\0';
	      buf2++;
	    }

	  _set_img_opt (buf, buf2);
	}
	break;

      default:
	vcd_error ("error while parsing command line - try --help");
	break;
      }

  if (gl.verbose_flag && gl.quiet_flag)
    vcd_error ("I can't be both, quiet and verbose... either one or another ;-)");
    
  if ((args = poptGetArgs (optCon)) == NULL)
    vcd_error ("xml input file argument missing -- try --help");

  for (n = 0; args[n]; n++);

  if (n != 1)
    vcd_error ("only one xml input file argument allowed -- try --help");

  gl.xml_fname = strdup (args[0]);

  poptFreeContext (optCon);

  return 0;
}

static VcdImageSink_t *
_create_sink (void)
{
  VcdImageSink_t *image_sink = NULL;
  CdioListNode_t *node;

  switch (gl.img_type)
    {
    case IMG_TYPE_BINCUE:
      image_sink = vcd_image_sink_new_bincue ();
      break;

    case IMG_TYPE_CDRDAO:
      image_sink = vcd_image_sink_new_cdrdao ();
      break;

    case IMG_TYPE_NRG:
      image_sink = vcd_image_sink_new_nrg ();
      break;
    }

  if (!image_sink)
    return image_sink;

  _CDIO_LIST_FOREACH (node, gl.img_options)
    {
      struct key_val_t *_cons = _cdio_list_node_data (node);
      
      if (vcd_image_sink_set_arg (image_sink, _cons->key, _cons->val))
	vcd_error ("error while setting image option '%s' (key='%s')", 
		   _cons->key, _cons->val);
    }
  
  return image_sink;
}

int 
main (int argc, const char *argv[])
{
  time_t create_time;
  xmlDocPtr vcd_doc;

  memset(&gl, 0, sizeof(gl));
  
  vcd_xml_progname = "vcdxbuild";

  _init_xml ();

  vcd_xml_log_init ();

  gl.img_options = _cdio_list_new ();
  gl.create_timestr = NULL;

  if (_do_cl (argc, argv))
    goto err_exit;

  if (gl.quiet_flag)
    vcd_xml_verbosity = VCD_LOG_WARN;
  else if (gl.verbose_flag)
    vcd_xml_verbosity = VCD_LOG_DEBUG;
  else
    vcd_xml_verbosity = VCD_LOG_INFO;

  if (gl.gui_flag)
    vcd_xml_gui_mode = true;

  if (gl.progress_flag)
    vcd_xml_show_progress = true;

  if (gl.check_flag)
    vcd_xml_check_mode = true;

  errno = 0;
  if (!(vcd_doc = _xmlParseFile (gl.xml_fname)))
    {
      if (errno)
	vcd_warn ("error while parsing file `%s': %s",
		   gl.xml_fname, strerror (errno));
      else
	vcd_warn ("parsing file `%s' failed", gl.xml_fname);
      goto err_exit;
    }

  if (vcd_xml_dtd_loaded < 1)
    {
      vcd_error ("doctype declaration missing in `%s'", gl.xml_fname);
      goto err_exit;
    }

  {
    xmlNodePtr root;
    xmlNsPtr ns;
    vcdxml_t vcdxml;
    VcdImageSink_t *image_sink;

    vcd_xml_init (&vcdxml);
    
    if (!(root = xmlDocGetRootElement (vcd_doc)))
      vcd_error ("XML document seems to be empty (no root node found)");

    if (!(ns = xmlSearchNsByHref (vcd_doc, root, (const xmlChar *) VIDEOCD_DTD_XMLNS)))
      vcd_error ("Namespace not found in document");
    
    if (vcd_xml_parse (&vcdxml, vcd_doc, root, ns))
      vcd_error ("parsing tree failed");

    if (!(image_sink = _create_sink (/* gl */)))
      {
        vcd_error ("failed to create image object");
        goto err_exit;
      }

    vcdxml.file_prefix = gl.file_prefix;
    
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
  
    if (vcd_xml_master (&vcdxml, image_sink, &create_time)) {
      vcd_warn ("building videocd failed");
      goto err_exit;
    }
    
    
    vcd_xml_destroy(&vcdxml);
  } 

  xmlFreeDoc (vcd_doc);
  free(gl.xml_fname);
  _cdio_list_free (gl.img_options, true);
  return EXIT_SUCCESS;
 err_exit: 
  free(gl.xml_fname);
  _cdio_list_free (gl.img_options, true);
  return EXIT_FAILURE;
}

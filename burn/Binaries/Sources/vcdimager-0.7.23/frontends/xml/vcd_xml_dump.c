/*
    $Id: vcd_xml_dump.c,v 1.29 2005/07/07 07:03:12 rocky Exp $

    Copyright (C) 2001 Herbert Valerio Riedel <hvr@gnu.org>
    Copyright (C) 2005 Rocky Bernstein <rocky@panix.com>

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

#include <libxml/tree.h>
#include <libxml/parser.h>
#include <libxml/parserInternals.h>
#include <libxml/xmlmemory.h>
#include <libxml/uri.h>

#define FOR_EACH(iter, parent) for(iter = parent->xmlChildrenNode; iter != NULL; iter = iter->next)

#include "vcd_xml_dump.h"
#include "vcd_xml_dtd.h"
#include "vcd_xml_common.h"

static const char _rcsid[] = "$Id: vcd_xml_dump.c,v 1.29 2005/07/07 07:03:12 rocky Exp $";

static xmlNodePtr 
_get_node (xmlDocPtr doc, xmlNodePtr cur, xmlNsPtr ns, 
	   const char nodename[], bool folder)
{
  xmlNodePtr n = NULL;
  const xmlChar *_node_id = folder ?(const xmlChar *) "folder" :(const xmlChar *) "file";

  FOR_EACH (n, cur)
    {
      xmlChar *tmp = NULL;

      if (xmlStrcmp (n->name, _node_id))
	continue;

      vcd_assert (!xmlStrcmp (n->children->name, (const xmlChar *) "name"));
      
      tmp = xmlNodeListGetString (doc, n->children->children, 1);
      
      if (!xmlStrcmp (tmp, (const xmlChar *) nodename))
	break;
    }
  
  if (!n)
    {
      n = xmlNewNode (ns, _node_id);
      xmlNewChild (n, ns, (const xmlChar *) "name", (const xmlChar *) nodename);

      if (!folder || !cur->xmlChildrenNode) /* file or first entry */
	xmlAddChild (cur, n);
      else /* folder */
	{
	  if (!xmlStrcmp (cur->children->name, (const xmlChar *) "name"))
	    xmlAddNextSibling (cur->xmlChildrenNode, n);
	  else
	    {
	      vcd_assert (!xmlStrcmp (cur->name, (const xmlChar *) "filesystem"));
	      xmlAddPrevSibling (cur->xmlChildrenNode, n); /* special case for <filesystem> */
	    }
	}
    }

  return n;
}

static xmlNodePtr 
_get_node_pathname (xmlDocPtr doc, xmlNodePtr cur, xmlNsPtr ns, const char pathname[], bool folder)
{
  char *_dir, *c;
  xmlNodePtr retval = NULL;

  vcd_assert (pathname != NULL);

  if (pathname[0] == '/')
    return _get_node_pathname (doc, cur, ns, pathname + 1, folder);

  if (pathname[0] == '\0')
    return retval;

  _dir = _vcd_strdup_upper (pathname);
  c = strchr (_dir, '/');

  if (c)
    { /* subdir... */
      xmlNodePtr n;

      *c++ = '\0';

      n = _get_node (doc, cur, ns, _dir, true);

      retval = _get_node_pathname (doc, n, ns, c, folder);
    }
  else /* leaf */
    retval = _get_node (doc, cur, ns, _dir, folder);

  free (_dir);

  return retval;
}

static void
_ref_area_helper (xmlNodePtr cur, xmlNsPtr ns, const char tag_id[], const char pbc_id[], const pbc_area_t *_area)
{
  xmlNodePtr node;

  if (!pbc_id)
    return;
  
  node = xmlNewChild (cur, ns, (const xmlChar *) tag_id, NULL);
  
  xmlSetProp (node, (const xmlChar *) "ref", (const xmlChar *) pbc_id);

  if (_area)
    {
      char buf[16];

      snprintf (buf, sizeof (buf), "%d", _area->x1);
      xmlSetProp (node, (const xmlChar *) "x1", (const xmlChar *) buf);

      snprintf (buf, sizeof (buf), "%d", _area->y1);
      xmlSetProp (node, (const xmlChar *) "y1", (const xmlChar *) buf);

      snprintf (buf, sizeof (buf), "%d", _area->x2);
      xmlSetProp (node, (const xmlChar *) "x2", (const xmlChar *) buf);

      snprintf (buf, sizeof (buf), "%d", _area->y2);
      xmlSetProp (node, (const xmlChar *) "y2", (const xmlChar *) buf);
    }
}

static void
_make_xml (vcdxml_t *obj, const char xml_fname[])
{
  xmlDtdPtr dtd;
  xmlDocPtr doc;
  xmlNodePtr vcd_node, section;
  xmlNsPtr ns = NULL;
  char buf[1024];
  CdioListNode_t *node;

  xmlKeepBlanksDefault(0);

  doc = xmlNewDoc ((const xmlChar *) "1.0");
  
  dtd = xmlNewDtd (doc, (const xmlChar *) "videocd", 
		   (const xmlChar *) VIDEOCD_DTD_PUBID, 
		   (const xmlChar *) VIDEOCD_DTD_SYSID);
  xmlAddChild ((xmlNodePtr) doc, (xmlNodePtr) dtd);

  if (obj->comment)
    xmlAddChild ((xmlNodePtr) doc, xmlNewComment ((const xmlChar *) obj->comment));

  vcd_node = xmlNewDocNode (doc, ns, (const xmlChar *) "videocd", NULL);
  xmlAddChild ((xmlNodePtr) doc, vcd_node);

  ns = xmlNewNs (vcd_node, (const xmlChar *) VIDEOCD_DTD_XMLNS, NULL);
  xmlSetNs (vcd_node, ns);

  switch (obj->vcd_type) 
    {
    case VCD_TYPE_VCD:
      xmlSetProp (vcd_node, (const xmlChar *) "class", (const xmlChar *) "vcd");
      xmlSetProp (vcd_node, (const xmlChar *) "version", (const xmlChar *) "1.0");
      break;

    case VCD_TYPE_VCD11:
      xmlSetProp (vcd_node, (const xmlChar *) "class", (const xmlChar *) "vcd");
      xmlSetProp (vcd_node, (const xmlChar *) "version", (const xmlChar *) "1.1");
      break;

    case VCD_TYPE_VCD2:
      xmlSetProp (vcd_node, (const xmlChar *) "class", (const xmlChar *) "vcd");
      xmlSetProp (vcd_node, (const xmlChar *) "version", (const xmlChar *) "2.0");
      break;

    case VCD_TYPE_SVCD:
      xmlSetProp (vcd_node, (const xmlChar *) "class", (const xmlChar *) "svcd");
      xmlSetProp (vcd_node, (const xmlChar *) "version", (const xmlChar *) "1.0");
      break;

    case VCD_TYPE_HQVCD:
      xmlSetProp (vcd_node, (const xmlChar *) "class", (const xmlChar *) "hqvcd");
      xmlSetProp (vcd_node, (const xmlChar *) "version", (const xmlChar *) "1.0");
      break;

    default:
      vcd_assert_not_reached ();
      break;
    }

  /* options */

  _CDIO_LIST_FOREACH (node, obj->option_list)
    {
      struct option_t *_option = _cdio_list_node_data (node);
      
      section = xmlNewChild (vcd_node, ns, (const xmlChar *) "option", NULL);
      xmlSetProp (section, (const xmlChar *) "name", (const xmlChar *) _option->name);
      xmlSetProp (section, (const xmlChar *) "value", (const xmlChar *) _option->value);
    }

  /* INFO */

  section = xmlNewChild (vcd_node, ns, (const xmlChar *) "info", NULL);

  xmlNewChild (section, ns, (const xmlChar *) "album-id", (const xmlChar *) obj->info.album_id);
  
  snprintf (buf, sizeof (buf), "%d", obj->info.volume_count);
  xmlNewChild (section, ns, (const xmlChar *) "volume-count", (const xmlChar *) buf);

  snprintf (buf, sizeof (buf), "%d", obj->info.volume_number);
  xmlNewChild (section, ns, (const xmlChar *) "volume-number", (const xmlChar *) buf);

  if (obj->info.use_sequence2)
    xmlNewChild (section, ns, (const xmlChar *) "next-volume-use-sequence2", NULL);

  if (obj->info.use_lid2)
    xmlNewChild (section, ns, (const xmlChar *) "next-volume-use-lid2", NULL);

  snprintf (buf, sizeof (buf), "%d", obj->info.restriction);
  xmlNewChild (section, ns, (const xmlChar *) "restriction", (const xmlChar *) buf);

  /* PVD */

  section = xmlNewChild (vcd_node, ns, (const xmlChar *) "pvd", NULL);

  xmlNewChild (section, ns, (const xmlChar *) "volume-id", (const xmlChar *) obj->pvd.volume_id);
  xmlNewChild (section, ns, (const xmlChar *) "system-id", (const xmlChar *) obj->pvd.system_id);
  xmlNewChild (section, ns, (const xmlChar *) "application-id", (const xmlChar *) obj->pvd.application_id);
  xmlNewChild (section, ns, (const xmlChar *) "preparer-id", (const xmlChar *) obj->pvd.preparer_id);
  xmlNewChild (section, ns, (const xmlChar *) "publisher-id", (const xmlChar *) obj->pvd.publisher_id);

  /* filesystem */

  if (_cdio_list_length (obj->filesystem))
    {
      section = xmlNewChild (vcd_node, ns, (const xmlChar *) "filesystem", NULL);

      _CDIO_LIST_FOREACH (node, obj->filesystem)
	{
	  struct filesystem_t *p = _cdio_list_node_data (node);
	  
	  if (p->file_src)
	    { /* file */
	      unsigned char *psz_fname_utf8 = vcd_xml_filename_to_utf8 (p->file_src);
	      xmlNodePtr filenode = _get_node_pathname (doc, section, ns, p->name, false);

	      xmlSetProp (filenode, (const xmlChar *) "src", psz_fname_utf8);
	      free(psz_fname_utf8);

	      if (p->file_raw)
		xmlSetProp (filenode, (const xmlChar *) "format", (const xmlChar *) "mixed");
	    }
	  else /* folder */
	    _get_node_pathname (doc, section, ns, p->name, true);
	}
    }

  /* segments */

  if (_cdio_list_length (obj->segment_list))
    {
      section = xmlNewChild (vcd_node, ns, (const xmlChar *) "segment-items", NULL);

      _CDIO_LIST_FOREACH (node, obj->segment_list)
	{
	  struct segment_t *_segment =  _cdio_list_node_data (node);
	  xmlNodePtr seg_node;
	  CdioListNode_t *node2;
	  
	  seg_node = xmlNewChild (section, ns, (const xmlChar *) "segment-item", NULL);
	  xmlSetProp (seg_node, (const xmlChar *) "src", vcd_xml_filename_to_utf8 (_segment->src));
	  xmlSetProp (seg_node, (const xmlChar *) "id", (const xmlChar *) _segment->id);

	  _CDIO_LIST_FOREACH (node2, _segment->autopause_list)
	    {
	      double *_ap_ts = _cdio_list_node_data (node2);
	      char buf[80];

	      snprintf (buf, sizeof (buf), "%f", *_ap_ts);
	      xmlNewChild (seg_node, ns, (const xmlChar *) "auto-pause", (const xmlChar *) buf);
	    }
	}
    }

  /* sequences */
    
  section = xmlNewChild (vcd_node, ns, (const xmlChar *) "sequence-items", NULL);

  _CDIO_LIST_FOREACH (node, obj->sequence_list)
    {
      struct sequence_t *p_sequence =  _cdio_list_node_data (node);
      xmlNodePtr seq_node;
      CdioListNode_t *node2;
      unsigned char *psz_xml_fname_utf8 = 
	vcd_xml_filename_to_utf8 (p_sequence->src);

      seq_node = xmlNewChild (section, ns, (const xmlChar *) "sequence-item", 
			      NULL);
      xmlSetProp (seq_node, (const xmlChar *) "src", psz_xml_fname_utf8);
      free(psz_xml_fname_utf8);
      
      xmlSetProp (seq_node, (const xmlChar *) "id", 
		  (const xmlChar *) p_sequence->id);

      if (p_sequence->default_entry_id)
	{
	  xmlNodePtr ent_node;

	  ent_node = xmlNewChild (seq_node, ns, 
				  (const xmlChar *) "default-entry", NULL);
	  xmlSetProp (ent_node, (const xmlChar *) "id", 
		      (const xmlChar *) p_sequence->default_entry_id);
	}

      _CDIO_LIST_FOREACH (node2, p_sequence->entry_point_list)
	{
	  struct entry_point_t *p_entry = _cdio_list_node_data (node2);
	  xmlNodePtr ent_node;
	  char buf[80];

	  snprintf (buf, sizeof (buf), "%f", p_entry->timestamp);
	  ent_node = xmlNewChild (seq_node, ns, (const xmlChar *) "entry", 
				  (const xmlChar *) buf);
	  xmlSetProp (ent_node, (const xmlChar *) "id", 
		      (const xmlChar *) p_entry->id);
	}

      _CDIO_LIST_FOREACH (node2, p_sequence->autopause_list)
	{
	  double *_ap_ts = _cdio_list_node_data (node2);
	  char buf[80];

	  snprintf (buf, sizeof (buf), "%f", *_ap_ts);
	  xmlNewChild (seq_node, ns, (const xmlChar *) "auto-pause", 
		       (const xmlChar *) buf);
	}
    }

  /* PBC */

  if (_cdio_list_length (obj->pbc_list))
    {
      section = xmlNewChild (vcd_node, ns, (const xmlChar *) "pbc", NULL);

      _CDIO_LIST_FOREACH (node, obj->pbc_list)
	{
	  pbc_t *_pbc = _cdio_list_node_data (node);
	  xmlNodePtr pl = NULL;
	  
	  switch (_pbc->type)
	    {
	      char buf[80];
	      CdioListNode_t *node2;

	    case PBC_PLAYLIST:
	      pl = xmlNewChild (section, ns, (const xmlChar *) "playlist", NULL);

	      _ref_area_helper (pl, ns, "prev", _pbc->prev_id, _pbc->prev_area);
	      _ref_area_helper (pl, ns, "next", _pbc->next_id, _pbc->next_area);
	      _ref_area_helper (pl, ns, "return", _pbc->retn_id, _pbc->return_area);

	      if (_pbc->playing_time)
		{
		  snprintf (buf, sizeof (buf), "%f", _pbc->playing_time);
		  xmlNewChild (pl, ns, (const xmlChar *) "playtime", (const xmlChar *) buf);
		}

	      snprintf (buf, sizeof (buf), "%d", _pbc->wait_time);
	      xmlNewChild (pl, ns, (const xmlChar *) "wait", (const xmlChar *) buf);

	      snprintf (buf, sizeof (buf), "%d", _pbc->auto_pause_time);
	      xmlNewChild (pl, ns, (const xmlChar *) "autowait", (const xmlChar *) buf);

	      _CDIO_LIST_FOREACH (node2, _pbc->item_id_list)
		{
		  const char *_id = _cdio_list_node_data (node2);
		  
		  if (_id)
		    xmlSetProp (xmlNewChild (pl, ns, (const xmlChar *) "play-item", NULL), 
				(const xmlChar *) "ref", (const xmlChar *) _id);
		  else
		    xmlNewChild (pl, ns, (const xmlChar *) "play-item", NULL);
		}

	      break;

	    case PBC_SELECTION:
	      pl = xmlNewChild (section, ns, (const xmlChar *) "selection", NULL);

	      snprintf (buf, sizeof (buf), "%d", _pbc->bsn);
	      xmlNewChild (pl, ns, (const xmlChar *) "bsn", (const xmlChar *) buf);

	      _ref_area_helper (pl, ns, "prev", _pbc->prev_id, _pbc->prev_area);
	      _ref_area_helper (pl, ns, "next", _pbc->next_id, _pbc->next_area);
	      _ref_area_helper (pl, ns, "return", _pbc->retn_id, _pbc->return_area);
	      switch (_pbc->selection_type)
		{
		case _SEL_NORMAL:
		  _ref_area_helper (pl, ns, "default",
				    _pbc->default_id, _pbc->default_area);
		  break;

		case _SEL_MULTI_DEF:
		  xmlSetProp (xmlNewChild (pl, ns, (const xmlChar *) "multi-default", NULL), 
			      (const xmlChar *) "numeric", (const xmlChar *) "enabled");
		  break;

		case _SEL_MULTI_DEF_NO_NUM:
		  xmlSetProp (xmlNewChild (pl, ns, (const xmlChar *) "multi-default", NULL), 
			      (const xmlChar *) "numeric", (const xmlChar *) "disabled");
		  break;
		}

	      if (_pbc->timeout_id)
		xmlSetProp (xmlNewChild (pl, ns, (const xmlChar *) "timeout", NULL), 
			    (const xmlChar *) "ref", (const xmlChar *) _pbc->timeout_id);

	      snprintf (buf, sizeof (buf), "%d", _pbc->timeout_time);
	      xmlNewChild (pl, ns, (const xmlChar *) "wait", (const xmlChar *) buf);

	      snprintf (buf, sizeof (buf), "%d", _pbc->loop_count);
	      xmlSetProp (xmlNewChild (pl, ns, (const xmlChar *) "loop", (const xmlChar *) buf),
			  (const xmlChar *) "jump-timing", 
			  (_pbc->jump_delayed ? (const xmlChar *) "delayed" : (const xmlChar *) "immediate"));

	      if (_pbc->item_id)
		xmlSetProp (xmlNewChild (pl, ns, 
					 (const xmlChar *) "play-item", NULL), 
			    (const xmlChar *) "ref", 
			    (const xmlChar *) _pbc->item_id);

	      {
		CdioListNode_t *node3 = 
		  _cdio_list_begin (_pbc->select_area_list);

		_CDIO_LIST_FOREACH (node2, _pbc->select_id_list)
		  {
		    char *_id = _cdio_list_node_data (node2);
		    pbc_area_t *_area = node3 ? _cdio_list_node_data (node3) : NULL;

		    if (_id)
		      _ref_area_helper (pl, ns, "select", _id, _area);
		    else
		      xmlNewChild (pl, ns, (const xmlChar *) "select", NULL);

		    if (_cdio_list_length (_pbc->select_area_list))
		      node3 = _cdio_list_node_next (node3);
		  }
	      }
	      break;
	      
	    case PBC_END:
	      pl = xmlNewChild (section, ns, (const xmlChar *) "endlist", NULL);

	      if (_pbc->next_disc)
		{
		  snprintf (buf, sizeof (buf), "%d", _pbc->next_disc);
		  xmlNewChild (pl, ns, (const xmlChar *) "next-volume", (const xmlChar *) buf);
		}

	      if (_pbc->image_id)
		xmlSetProp (xmlNewChild (pl, ns, (const xmlChar *) "play-item", NULL),
			    (const xmlChar *) "ref", (const xmlChar *) _pbc->image_id);
	      break;

	    default:
	      vcd_assert_not_reached ();
	    }
	  
	  xmlSetProp (pl, (const xmlChar *) "id", (const xmlChar *) _pbc->id);
	  if (_pbc->rejected)
	    xmlSetProp (pl, (const xmlChar *) "rejected", (const xmlChar *) "true");
	}
    }

  xmlSaveFormatFile (xml_fname, doc, true);

  xmlFreeDoc (doc);
}

int
vcd_xml_dump (vcdxml_t *obj, const char xml_fname[])
{
  _make_xml (obj, xml_fname);
  
  return 0;
}

/* 
   Print command line used as a XML comment. Start is either 0 or 
   1. The program might be invoked either from a binary or a libtool
   wrapper script to invoke the module.
*/
char *
vcd_xml_dump_cl_comment (int argc, const char *argv[], int start)
{
  int idx;
  char *retval;
  size_t len = 0;

  switch(start) {
  case 0:
    retval = strdup (" command line used: ");
    break;
  case 1:
    retval = strdup (" command arguments used: ");
    break;
  default:
    fprintf (stderr, "internal error: expecting start=0 or start=1\n"); 
    retval = strdup (" command line used: ");
    start=0;
  }
  

  len = strlen (retval);

  for (idx = start; idx < argc; idx++)
    {
      len += strlen (argv[idx]) + 1;
      
      retval = realloc (retval, len + 1);

      strcat (retval, argv[idx]);
      strcat (retval, " ");
    }

  /* scramble hyphen's */
  for (idx = 0; retval[idx]; idx++)
    if (!strncmp (retval + idx, "--", 2))
      retval[idx + 1] = '=';

  return retval;
}


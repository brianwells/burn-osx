/*
    $Id: vcd_xml_parse.c,v 1.37 2005/06/25 23:35:17 rocky Exp $

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

#include "vcd_xml_parse.h"
#include "vcd_xml_common.h"

#include <stdlib.h>
#include <string.h>

#include <libxml/xmlmemory.h>
#include <libxml/parser.h>

#include <libvcd/logging.h>

/* Private headers */
#include "util.h"
#include "vcd_xml_parse.h"

static const char _rcsid[] = "$Id: vcd_xml_parse.c,v 1.37 2005/06/25 23:35:17 rocky Exp $";

/*
 * shortcut templates...
 */

#define FOR_EACH(iter, parent) for(iter = parent->xmlChildrenNode; iter != NULL; iter = iter->next)

typedef struct {
  xmlChar *name; /* node name */
} handlers_t;

#define GET_ELEM_(id, doc, node, ns) \
 if ((!xmlStrcmp (node->name, (const xmlChar *) id)) && (node->ns == ns)) 

#define GET_ELEM_STR(str, id, doc, node, ns) \
 if ((!xmlStrcmp (node->name, (const xmlChar *) id)) && (node->ns == ns)) \
   (str) = (char *) xmlNodeListGetString (doc, node->xmlChildrenNode, 1)

#define GET_ELEM_LONG(val, id, doc, node, ns) \
 if ((!xmlStrcmp (node->name, (const xmlChar *) id)) && (node->ns == ns)) \
   val = _get_elem_long (id, doc, node, ns)

#define GET_ELEM_DOUBLE(val, id, doc, node, ns) \
 if ((!xmlStrcmp (node->name, (const xmlChar *) id)) && (node->ns == ns)) \
   val = _get_elem_double (id, doc, node, ns)

#define GET_PROP_STR(str, id, doc, node, ns) \
 if (xmlHasProp ((node), (const xmlChar *) (id))) \
   (str) = (char *) xmlGetProp ((node), (const xmlChar *) (id))

#define GET_ELSE else

static long
_get_elem_long (const char id[], xmlDocPtr doc, xmlNodePtr node, xmlNsPtr ns)
{
  long retval = 0;
  char *_tmp = NULL;
  char *endptr;
  
  GET_ELEM_STR (_tmp, id, doc, node, ns);

  if (!_tmp)
    {
      vcd_warn ("XML: empty content where integer value was expected,"
		" assuming 0");
      return retval;
    }

  retval = strtol (_tmp, &endptr, 10);

  if (*endptr)
    vcd_error ("XML: error while converting string '%s' to an integer.", _tmp);

  return retval;
}

static double
_get_elem_double (const char id[], xmlDocPtr doc, xmlNodePtr node, xmlNsPtr ns)
{
  double retval = 0;
  char *_tmp = NULL;
  char *endptr;
  
  GET_ELEM_STR (_tmp, id, doc, node, ns);

  if (!_tmp)
    {
      vcd_warn ("XML: empty content where floating point value was expected,"
		" assuming 0.0");
      return retval;
    }

  retval = strtod (_tmp, &endptr);

  if (*endptr)
    vcd_error ("XML: error while converting string '%s' to floating point.", 
	       _tmp);

  return retval;
}


/*
 * options 
 */

static bool
_parse_option (vcdxml_t *obj, xmlDocPtr doc, xmlNodePtr node, xmlNsPtr ns)
{
  if (!xmlStrcmp (node->name, (const xmlChar *) "option")) 
    {
      struct option_t *_option = calloc(1, sizeof (struct option_t));
	  
      GET_PROP_STR (_option->name, "name", doc, node, ns);
      GET_PROP_STR (_option->value, "value", doc, node, ns);

      _cdio_list_append (obj->option_list, _option);
    }
  else
    vcd_assert_not_reached ();

  return false;
}

/*
 * info block
 */

static bool
_parse_info (vcdxml_t *obj, xmlDocPtr doc, xmlNodePtr node, xmlNsPtr ns)
{
  xmlNodePtr cur;

  FOR_EACH (cur, node)
    {
      if (cur->ns != ns)
	continue;

      GET_ELEM_STR (obj->info.album_id, "album-id", doc, cur, ns);
      GET_ELSE GET_ELEM_LONG (obj->info.volume_count, "volume-count", doc, cur, ns);
      GET_ELSE GET_ELEM_LONG (obj->info.volume_number, "volume-number", doc, cur, ns);
      GET_ELSE GET_ELEM_LONG (obj->info.restriction, "restriction", doc, cur, ns);
      GET_ELSE GET_ELEM_DOUBLE (obj->info.time_offset, "time-offset", doc, cur, ns);
      GET_ELSE GET_ELEM_ ("next-volume-use-sequence2", doc, cur, ns)
	obj->info.use_sequence2 = true;
      GET_ELSE GET_ELEM_ ("next-volume-use-lid2", doc, cur, ns)
	obj->info.use_lid2 = true;
      GET_ELSE vcd_assert_not_reached ();
    }

  return false;
}

/*
 * iso9660 pvd block
 */

static bool
_parse_pvd (vcdxml_t *obj, xmlDocPtr doc, xmlNodePtr node, xmlNsPtr ns)
{
  xmlNodePtr cur;

  FOR_EACH (cur, node)
    {
      if (cur->ns != ns)
	continue;

      GET_ELEM_STR (obj->pvd.volume_id, "volume-id", doc, cur, ns);
      GET_ELSE GET_ELEM_STR (obj->pvd.system_id, "system-id", doc, cur, ns);
      GET_ELSE GET_ELEM_STR (obj->pvd.application_id, "application-id", doc, cur, ns);
      GET_ELSE GET_ELEM_STR (obj->pvd.preparer_id, "preparer-id", doc, cur, ns);
      GET_ELSE GET_ELEM_STR (obj->pvd.publisher_id, "publisher-id", doc, cur, ns);
      GET_ELSE vcd_assert_not_reached ();
    }

  return false;
}

/*
 * segment items block 
 */

static bool
_parse_mpeg_segment (vcdxml_t *obj, xmlDocPtr doc, xmlNodePtr node, xmlNsPtr ns)
{
  struct segment_t *segment;
  xmlNodePtr cur;

  segment = calloc(1, sizeof (struct segment_t));

  _cdio_list_append (obj->segment_list, segment);

  GET_PROP_STR (segment->id, "id", doc, node, ns);
  segment->src = vcd_xml_utf8_to_filename ((unsigned char *)segment->src); // memleak
  GET_PROP_STR (segment->src, "src", doc, node, ns);
  segment->src = vcd_xml_utf8_to_filename ((unsigned char *)segment->src); // memleak

  segment->autopause_list = _cdio_list_new ();

  FOR_EACH (cur, node)
    {
      if (cur->ns != ns)
	continue;

      if (!xmlStrcmp (cur->name, (const xmlChar *) "auto-pause"))
	{
	  double *_ap_ts = calloc(1, sizeof (double));
	  *_ap_ts = 0;
	  
	  GET_ELEM_DOUBLE (*_ap_ts, "auto-pause", doc, cur, ns);

	  _cdio_list_append (segment->autopause_list, _ap_ts);
	}
      else
	vcd_assert_not_reached ();
    }

  return false;
}

static bool
_parse_segments (vcdxml_t *obj, xmlDocPtr doc, xmlNodePtr node, xmlNsPtr ns)
{
  xmlNodePtr cur;

  FOR_EACH (cur, node)
    {
      bool rc = false;

      if (cur->ns != ns)
	continue;

      if (!xmlStrcmp (cur->name, (const xmlChar *) "segment-item")) 
	rc = _parse_mpeg_segment (obj, doc, cur, ns);
      else
	vcd_assert_not_reached ();

      if (rc)
	return rc;
    }

  return false;
}

/*
 * PBC block 
 */

static void
_parse_common_pbcattrs (pbc_t *pbc, xmlDocPtr doc, xmlNodePtr node, 
			xmlNsPtr ns)
{
  char *_tmp = NULL;

  vcd_assert (pbc != NULL);

  GET_PROP_STR (pbc->id, "id", doc, node, ns);

  GET_PROP_STR (_tmp, "rejected", doc, node, ns);

  pbc->rejected = (_tmp && !strcmp (_tmp, "true"));
}

static long
_get_prop_long (const char _prop_name[], xmlDocPtr doc, xmlNodePtr node, 
		xmlNsPtr ns)
{
  if (xmlHasProp (node, (const xmlChar *) _prop_name)) 
    {
      char *str = (char *) xmlGetProp (node, (const xmlChar *) _prop_name);
      long retval = 0;
      char *endptr;

      if (!str)
	return retval;

      retval = strtol (str, &endptr, 10);

      if (*endptr)
	vcd_error ("XML: error while converting string '%s' to an integer.", 
		   str);

      return retval;
    }
  
  return 0;
}

static void
_get_area_props (pbc_area_t **pp_area,
		 xmlDocPtr doc, xmlNodePtr node, xmlNsPtr ns)
{
  const uint32_t x1 = _get_prop_long ("x1", doc, node, ns);
  const uint32_t y1 = _get_prop_long ("y1", doc, node, ns);
  const uint32_t x2 = _get_prop_long ("x2", doc, node, ns);
  const uint32_t y2 = _get_prop_long ("y2", doc, node, ns);

  if (x1 > 255) 
    vcd_warn ("XML: value of x1 (%u) is greater than 255", (unsigned int) x1);

  if (x2 > 255) 
    vcd_error ("XML: value of x2 (%u) is greater than 255", (unsigned int) x2);

  if (y1 > 255) 
    vcd_error ("XML: value of y1 (%u) is greater than 255", (unsigned int) y1);

  if (y2 > 255) 
    vcd_error ("XML: value of y2 (%u) is greater than 255", (unsigned int) y2);

  *pp_area = vcd_pbc_area_new ( x1, y1, x2, y2);
}

static bool
_parse_pbc_selection (vcdxml_t *p_obj, xmlDocPtr doc, xmlNodePtr node, 
		      xmlNsPtr ns)
{
  xmlNodePtr cur;
  pbc_t *p_pbc;

  p_pbc = vcd_pbc_new (PBC_SELECTION);
  p_pbc->bsn = 1;
  p_pbc->loop_count = 1;

  _parse_common_pbcattrs (p_pbc, doc, node, ns);

  FOR_EACH (cur, node)
    {
      if (cur->ns != ns) 
	continue; 
      
      if (!xmlStrcmp (cur->name, (const xmlChar *) "prev"))
	{ 
	  GET_PROP_STR (p_pbc->prev_id, (const xmlChar *) "ref", doc, cur, ns);
	  _get_area_props (&p_pbc->prev_area, doc, cur, ns);
	}
      else if (!xmlStrcmp (cur->name, (const xmlChar *) "next"))
	{ 
	  GET_PROP_STR (p_pbc->next_id, "ref", doc, cur, ns); 
	  _get_area_props (&p_pbc->next_area, doc, cur, ns);
	}
      else if (!xmlStrcmp (cur->name, (const xmlChar *) "return"))
	{
	  GET_PROP_STR (p_pbc->retn_id, "ref", doc, cur, ns); 
	  _get_area_props (&p_pbc->return_area, doc, cur, ns);
	}
      else if (!xmlStrcmp (cur->name, (const xmlChar *) "timeout"))
	{ 
	  GET_PROP_STR (p_pbc->timeout_id, "ref", doc, cur, ns); 
	}
      else if (!xmlStrcmp (cur->name, (const xmlChar *) "multi-default"))
	{
	  char *_numeric = NULL;

	  p_pbc->selection_type = _SEL_MULTI_DEF;

	  GET_PROP_STR (_numeric, "numeric", doc, cur, ns); 
	  if (_numeric && !strcmp (_numeric, "disabled"))
	    p_pbc->selection_type = _SEL_MULTI_DEF_NO_NUM;
	}
      else if (!xmlStrcmp (cur->name, (const xmlChar *) "default"))
	{ 
	  p_pbc->selection_type = _SEL_NORMAL;
	  GET_PROP_STR (p_pbc->default_id, "ref", doc, cur, ns); 
	}
      else if (!xmlStrcmp (cur->name, (const xmlChar *) "bsn"))
	{ p_pbc->bsn = _get_elem_long ("bsn", doc, cur, ns); }
      else if (!xmlStrcmp (cur->name, (const xmlChar *) "loop"))
	{ 
	  char *_tmp = NULL;
	  
	  p_pbc->loop_count = _get_elem_long ("loop", doc, cur, ns); 

	  GET_PROP_STR (_tmp, "jump-timing", doc, cur, ns);
	  
	  if (_tmp && !strcmp (_tmp, "delayed"))
	    p_pbc->jump_delayed = true;
	}
      else if (!xmlStrcmp (cur->name, (const xmlChar *) "wait"))
	{ p_pbc->timeout_time = _get_elem_long ("wait", doc, cur, ns); }
      else if (!xmlStrcmp (cur->name, (const xmlChar *) "play-item"))
	{ GET_PROP_STR (p_pbc->item_id, "ref", doc, cur, ns); }
      else if (!xmlStrcmp (cur->name, (const xmlChar *) "select"))
	{
	  char *_select_ref = NULL;

	  GET_PROP_STR (_select_ref, "ref", doc, cur, ns); 

	  _cdio_list_append (p_pbc->select_id_list, _select_ref);

	  {
	    pbc_area_t *_area = NULL;

	    _get_area_props (&_area, doc, cur, ns);
	    _cdio_list_append (p_pbc->select_area_list, _area);
	  }
	  
	}
      else
	vcd_assert_not_reached ();
    }

  _cdio_list_append (p_obj->pbc_list, p_pbc);

  return false;
}

static bool
_parse_pbc_playlist (vcdxml_t *p_obj, xmlDocPtr doc, xmlNodePtr node, 
		     xmlNsPtr ns)
{
  xmlNodePtr cur;
  pbc_t *_pbc;

  _pbc = vcd_pbc_new (PBC_PLAYLIST);

  _parse_common_pbcattrs (_pbc, doc, node, ns);

  FOR_EACH (cur, node)
    {
      if (cur->ns != ns) 
	continue; 
      
      if (!xmlStrcmp (cur->name, (const xmlChar *) "prev"))
	{ GET_PROP_STR (_pbc->prev_id, "ref", doc, cur, ns); }
      else if (!xmlStrcmp (cur->name, (const xmlChar *) "next"))
	{ GET_PROP_STR (_pbc->next_id, "ref", doc, cur, ns); }
      else if (!xmlStrcmp (cur->name, (const xmlChar *) "return"))
	{ GET_PROP_STR (_pbc->retn_id, "ref", doc, cur, ns); }
      else if (!xmlStrcmp (cur->name, (const xmlChar *) "wait"))
	{ _pbc->wait_time = _get_elem_long ("wait", doc, cur, ns); }
      else if (!xmlStrcmp (cur->name, (const xmlChar *) "autowait"))
	{ _pbc->auto_pause_time = _get_elem_long ("autowait", doc, cur, ns); }
      else if (!xmlStrcmp (cur->name, (const xmlChar *) "playtime"))
	{ _pbc->playing_time = _get_elem_double ("playtime", doc, cur, ns); }
      else if (!xmlStrcmp (cur->name, (const xmlChar *) "play-item"))
	{
	  char *_item_ref = NULL;

	  GET_PROP_STR (_item_ref, "ref", doc, cur, ns); 

	  _cdio_list_append (_pbc->item_id_list, _item_ref);
	}
      else
	vcd_assert_not_reached ();
    }

  _cdio_list_append (p_obj->pbc_list, _pbc);

  return false;
}

static bool
_parse_pbc_endlist (vcdxml_t *p_obj, xmlDocPtr doc, xmlNodePtr node, 
		    xmlNsPtr ns)
{
  xmlNodePtr cur;
  pbc_t *_pbc;

  _pbc = vcd_pbc_new (PBC_END);

  _parse_common_pbcattrs (_pbc, doc, node, ns);

  FOR_EACH (cur, node)
    {
      if (cur->ns != ns) 
	continue; 

      if (!xmlStrcmp (cur->name, (const xmlChar *) "next-volume"))
	{ _pbc->next_disc = _get_elem_long ("next-volume", doc, cur, ns); }
      else if (!xmlStrcmp (cur->name, (const xmlChar *) "play-item"))
	{ GET_PROP_STR (_pbc->image_id, "ref", doc, cur, ns); }
      else
	vcd_assert_not_reached ();
    }

  _cdio_list_append (p_obj->pbc_list, _pbc);

  return false;
}

static bool
_parse_pbc (vcdxml_t *p_obj, xmlDocPtr doc, xmlNodePtr node, xmlNsPtr ns)
{
  xmlNodePtr cur;

  FOR_EACH (cur, node)
    {
      bool rc = true;

      if (cur->ns != ns) 
	continue; 

      if (!xmlStrcmp (cur->name, (const xmlChar *) "selection")) 
	rc = _parse_pbc_selection (p_obj, doc, cur, ns);
      else if (!xmlStrcmp (cur->name, (const xmlChar *) "playlist")) 
	rc = _parse_pbc_playlist (p_obj, doc, cur, ns);
      else if (!xmlStrcmp (cur->name, (const xmlChar *) "endlist")) 
	rc = _parse_pbc_endlist (p_obj, doc, cur, ns);
      else 
	vcd_assert_not_reached ();

      if (rc)
	return rc;
    }

  return false;
}

/*
 * sequence items block
 */

static bool
_parse_mpeg_sequence (vcdxml_t *p_obj, xmlDocPtr doc, xmlNodePtr node, 
		      xmlNsPtr ns)
{
  struct sequence_t *sequence;
  xmlNodePtr cur;

  sequence = calloc(1, sizeof (struct sequence_t));

  _cdio_list_append (p_obj->sequence_list, sequence);

  GET_PROP_STR (sequence->id, "id", doc, node, ns);
  sequence->src = vcd_xml_utf8_to_filename ((unsigned char *)sequence->src); // memleak
  GET_PROP_STR (sequence->src, "src", doc, node, ns);
  sequence->src = vcd_xml_utf8_to_filename ((unsigned char *)sequence->src); // memleak

  sequence->entry_point_list = _cdio_list_new ();
  sequence->autopause_list = _cdio_list_new ();

  FOR_EACH (cur, node)
    {
      if (cur->ns != ns)
	continue;

      if (!xmlStrcmp (cur->name, (const xmlChar *) "default-entry"))
	{
	  GET_PROP_STR (sequence->default_entry_id, "id", doc, cur, ns);
	}
      else if (!xmlStrcmp (cur->name, (const xmlChar *) "entry"))
	{
	  struct entry_point_t *entry = calloc(1, sizeof (struct entry_point_t));
	  
	  GET_PROP_STR (entry->id, "id", doc, cur, ns);
	  GET_ELEM_DOUBLE (entry->timestamp, "entry", doc, cur, ns);

	  _cdio_list_append (sequence->entry_point_list, entry);
	}
      else if (!xmlStrcmp (cur->name, (const xmlChar *) "auto-pause"))
	{
	  double *_ap_ts = calloc(1, sizeof (double));
	  *_ap_ts = 0;
	  
	  GET_ELEM_DOUBLE (*_ap_ts, "auto-pause", doc, cur, ns);

	  _cdio_list_append (sequence->autopause_list, _ap_ts);
	}
      else
	vcd_assert_not_reached ();
    }

  return false;
}

static bool
_parse_sequences (vcdxml_t *p_obj, xmlDocPtr doc, xmlNodePtr node, xmlNsPtr ns)
{
  xmlNodePtr cur;

  FOR_EACH (cur, node)
    {
      bool rc = false;

      if (cur->ns != ns)
	continue;


      if (!xmlStrcmp (cur->name, (const xmlChar *) "sequence-item")) 
	rc = _parse_mpeg_sequence (p_obj, doc, cur, ns);
      else
	vcd_assert_not_reached ();

      if (rc)
	return rc;
    }

  return false;
}

/*
 * filesystem block 
 */

static bool
_parse_file (vcdxml_t *p_obj, const char path[], xmlDocPtr doc, 
	     xmlNodePtr node, xmlNsPtr ns)
{
  xmlNodePtr cur;
  char *_name = NULL;
  char *_src = NULL;
  char *_format = NULL;

  vcd_assert (path != NULL);

  GET_PROP_STR (_src, "src", doc, node, ns);
  _src = vcd_xml_utf8_to_filename ((unsigned char *) _src); // memleak
  vcd_assert (_src != NULL);
  _src = vcd_xml_utf8_to_filename ((unsigned char *) _src); // memleak

  GET_PROP_STR (_format, "format", doc, node, ns);

  FOR_EACH (cur, node)
    {
      if (cur->ns != ns)
	continue;


      GET_ELEM_STR (_name, "name", doc, cur, ns);
      GET_ELSE vcd_assert_not_reached ();
    }

  if (!_name)
    return true;

  {
    struct filesystem_t *_data;
    char *_tmp;

    _tmp = malloc (strlen (path) + strlen (_name) + 1);
    
    strcpy (_tmp, path);
    strcat (_tmp, _name);
	    
    _data = malloc (sizeof (struct filesystem_t));
    _data->name = _tmp;
    _data->file_src = strdup (_src);
    _data->file_raw = (_format && !strcmp (_format, "mixed"));

    _cdio_list_append (p_obj->filesystem, _data);
  }

  return false;
}

static bool
_parse_folder (vcdxml_t *p_obj, const char path[], xmlDocPtr doc, 
	       xmlNodePtr node, xmlNsPtr ns)
{
  xmlNodePtr cur;
  char *new_path = NULL;

  vcd_assert (path != NULL);

  FOR_EACH (cur, node)
    {
      bool rc = true;

      if (cur->ns != ns) 
	continue; 

      if (!xmlStrcmp (cur->name, (const xmlChar *) "name")) 
	{
	  xmlChar *_tmp;

	  vcd_assert (new_path == NULL);

	  _tmp = xmlNodeListGetString (doc, cur->xmlChildrenNode, 1);

	  vcd_assert (_tmp != NULL);

	  new_path = malloc (strlen (path) + xmlStrlen (_tmp) + 1 + 1);
	  strcpy (new_path, path);
	  strcat (new_path, (const char *) _tmp);

	  {
	    struct filesystem_t *_data;
	    
	    _data = malloc (sizeof (struct filesystem_t));
	    _data->name = strdup (new_path);
	    _data->file_src = NULL;

	    _cdio_list_append (p_obj->filesystem, _data);
	  }
	  

	  strcat (new_path, "/");
	  
	  rc = false;
	  
	  /* fixme, free _tmp?? */
	}
      else if (!xmlStrcmp (cur->name, (const xmlChar *) "folder")) 
	rc = _parse_folder (p_obj, new_path, doc, cur, ns);
      else if (!xmlStrcmp (cur->name, (const xmlChar *) "file"))
	rc = _parse_file (p_obj, new_path, doc, cur, ns);
      else 
	vcd_assert_not_reached ();
      
      if (new_path == NULL)
	rc = true;

      if (rc) {
	free(new_path);
	return rc;
      }
      
    }

  free(new_path);
  return false;
}

static bool
_parse_filesystem (vcdxml_t *p_obj, xmlDocPtr doc, xmlNodePtr node, 
		   xmlNsPtr ns)
{
  xmlNodePtr cur;

  FOR_EACH (cur, node)
    {
      bool rc = true;

      if (cur->ns != ns) 
	continue; 

      if (!xmlStrcmp (cur->name, (const xmlChar *) "folder")) 
	rc = _parse_folder (p_obj, "", doc, cur, ns);
      else if (!xmlStrcmp (cur->name, (const xmlChar *) "file"))
	rc = _parse_file (p_obj, "", doc, cur, ns);
      else 
	vcd_assert_not_reached ();

      if (rc)
	return rc;
    }

  return false;
}

/*
 * top videocd block
 */

static vcd_type_t
_type_id_by_str (const char class[], const char version[])
{
  struct {
    const char *class;
    const char *version;
    vcd_type_t id;
  } type_str[] = {
    { "vcd", "1.0", VCD_TYPE_VCD },
    { "vcd", "1.1", VCD_TYPE_VCD11 },
    { "vcd", "2.0", VCD_TYPE_VCD2 },
    { "svcd", "1.0", VCD_TYPE_SVCD },
    { "hqvcd", "1.0", VCD_TYPE_HQVCD },
    { NULL, NULL, VCD_TYPE_INVALID }
  };
      
  int i = 0;

  while (type_str[i].class) 
    if (strcasecmp(class, type_str[i].class)
	|| strcasecmp(version, type_str[i].version))
      i++;
    else
      break;

  return type_str[i].id;
}

static bool
_parse_videocd (vcdxml_t *p_obj, xmlDocPtr doc, xmlNodePtr node, xmlNsPtr ns)
{
  xmlNodePtr cur;
  char *_class = NULL;
  char *_version = NULL;

  vcd_assert (p_obj != NULL);

  GET_PROP_STR (_class, "class", doc, node, ns);
  GET_PROP_STR (_version, "version", doc, node, ns);

  p_obj->vcd_type = _type_id_by_str (_class, _version);
  if (p_obj->vcd_type == VCD_TYPE_INVALID)
    return true;

  FOR_EACH (cur, node)
    {
      bool rc = false;
      
      if (cur->ns != ns)
	continue;

      if (!xmlStrcmp (cur->name, (const xmlChar *) "meta")) 
	{ /* NOOP */ }
      else if (!xmlStrcmp (cur->name, (const xmlChar *) "option")) 
	rc = _parse_option (p_obj, doc, cur, ns);
      else if (!xmlStrcmp (cur->name, (const xmlChar *) "info")) 
	rc = _parse_info (p_obj, doc, cur, ns);
      else if (!xmlStrcmp (cur->name, (const xmlChar *) "pvd")) 
	rc = _parse_pvd (p_obj, doc, cur, ns);
      else if (!xmlStrcmp (cur->name, (const xmlChar *) "pbc")) 
	rc = _parse_pbc (p_obj, doc, cur, ns);
      else if (!xmlStrcmp (cur->name, (const xmlChar *) "segment-items")) 
	rc = _parse_segments (p_obj, doc, cur, ns);
      else if (!xmlStrcmp (cur->name, (const xmlChar *) "filesystem")) 
	rc = _parse_filesystem (p_obj, doc, cur, ns);
      else if (!xmlStrcmp (cur->name, (const xmlChar *) "sequence-items")) 
	rc = _parse_sequences (p_obj, doc, cur, ns);
      else vcd_warn ("XML: unexpected element: %s", cur->name);

      if (rc)
	return rc;
    }

  return false;
}

/*
 * exported entry function
 */

bool
vcd_xml_parse (vcdxml_t *p_obj, xmlDocPtr doc, xmlNodePtr node, xmlNsPtr ns)
{
  vcd_assert (p_obj != NULL);
  vcd_assert (node != NULL);
  vcd_assert (doc != NULL);

  if (xmlStrcmp (node->name, (const xmlChar *) "videocd") || (node->ns != ns))
    {
      vcd_warn ("XML: root element not videocd...");
      return true;
    }

  return _parse_videocd (p_obj, doc, node, ns);
}


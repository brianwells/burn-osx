/*
    $Id: directory.c,v 1.5 2005/02/09 10:00:59 rocky Exp $

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

#include <stdlib.h>
#include <string.h>

/* Public headers */
#include <cdio/bytesex.h>
#include <cdio/iso9660.h>
#include <libvcd/logging.h>

/* Private headers */
#include "vcd_assert.h"
#include "directory.h"
#include "util.h"

static const char _rcsid[] = "$Id: directory.c,v 1.5 2005/02/09 10:00:59 rocky Exp $";

/* CD-ROM XA */

/* tree data structure */

typedef struct 
{
  bool is_dir;
  char *name;
  uint16_t version;
  uint16_t xa_attributes;
  uint8_t xa_filenum;
  uint32_t extent;
  uint32_t size;
  unsigned pt_id;
} data_t;

typedef VcdTreeNode_t VcdDirNode_t;

#define EXTENT(anode) (DATAP(anode)->extent)
#define SIZE(anode)   (DATAP(anode)->size)
#define PT_ID(anode)  (DATAP(anode)->pt_id)

#define DATAP(anode) ((data_t*) _vcd_tree_node_data (anode))

/* important date to celebrate (for me at least =)
   -- until user customization is implemented... */
static const time_t _vcd_time = 269222400L;
                                       
/* implementation */

static void
traverse_get_dirsizes(VcdDirNode_t *node, void *data)
{
  data_t *d = DATAP(node);
  unsigned *sum = data;

  if (d->is_dir)
    {
      vcd_assert (d->size % ISO_BLOCKSIZE == 0);

      *sum += (d->size / ISO_BLOCKSIZE);
    }
}

static unsigned
get_dirsizes (VcdDirNode_t * dirnode)
{
  unsigned result = 0;

  _vcd_tree_node_traverse (dirnode, traverse_get_dirsizes, &result);

  return result;
}

static void
traverse_update_dirextents (VcdDirNode_t *dirnode, void *data)
{
  data_t *d = DATAP(dirnode);

  if (d->is_dir) 
    {
      VcdDirNode_t *child;
      unsigned dirextent = d->extent;
      
      vcd_assert (d->size % ISO_BLOCKSIZE == 0);
      
      dirextent += d->size / ISO_BLOCKSIZE;
      
      _VCD_CHILD_FOREACH (child, dirnode)
        {
          data_t *d = DATAP(child);
          
          vcd_assert (d != NULL);
          
          if (d->is_dir) 
            {
              d->extent = dirextent;
              dirextent += get_dirsizes (child);
            }
        }
    }
}

static void 
update_dirextents (VcdDirectory_t *dir, uint32_t extent)
{
  data_t *dirdata = DATAP(_vcd_tree_root (dir));
  
  dirdata->extent = extent;
  _vcd_tree_node_traverse (_vcd_tree_root (dir),
                           traverse_update_dirextents, NULL);
}

static void
traverse_update_sizes(VcdDirNode_t *node, void *data)
{
  data_t *dirdata = DATAP(node);

  if (dirdata->is_dir)
    {
      VcdDirNode_t *child;
      unsigned offset = 0;
      
      offset += iso9660_dir_calc_record_size (1, sizeof(iso9660_xa_t)); /* '.' */
      offset += iso9660_dir_calc_record_size (1, sizeof(iso9660_xa_t)); /* '..' */
      
      _VCD_CHILD_FOREACH (child, node)
        {
          data_t *d = DATAP(child);
          unsigned reclen;
          char *pathname = (d->is_dir 
                            ? strdup (d->name)
                            : iso9660_pathname_isofy (d->name, d->version));
          
          vcd_assert (d != NULL);
          
          reclen = iso9660_dir_calc_record_size (strlen (pathname), 
                                                 sizeof (iso9660_xa_t));

          free (pathname);
          
          offset = _vcd_ofs_add (offset, reclen, ISO_BLOCKSIZE);
        }

      vcd_assert (offset > 0);

      dirdata->size = _vcd_ceil2block (offset, ISO_BLOCKSIZE);
    }
}

static void 
update_sizes (VcdDirectory_t *dir)
{
  _vcd_tree_node_traverse (_vcd_tree_root(dir), traverse_update_sizes, NULL);
}


/* exported stuff: */

VcdDirectory_t *
_vcd_directory_new (void)
{
  data_t *data;
  VcdDirectory_t *dir = NULL;

  vcd_assert (sizeof(iso9660_xa_t) == 14);

  data = calloc(1, sizeof (data_t));
  dir = _vcd_tree_new (data);

  data->is_dir = true;
  data->name = _vcd_memdup("\0", 2);
  data->xa_attributes = XA_FORM1_DIR;
  data->xa_filenum = 0x00;

  return dir;
}

static void
traverse_vcd_directory_done (VcdDirNode_t *node, void *data)
{
  data_t *dirdata = DATAP (node);

  free (dirdata->name);
}

void
_vcd_directory_destroy (VcdDirectory_t *dir)
{
  vcd_assert (dir != NULL);

  _vcd_tree_node_traverse (_vcd_tree_root (dir),
                           traverse_vcd_directory_done, NULL);

  _vcd_tree_destroy (dir, true);
}

static VcdDirNode_t * 
lookup_child (VcdDirNode_t *node, const char name[])
{
  VcdDirNode_t *child;

  _VCD_CHILD_FOREACH (child, node)
    {
      data_t *d = DATAP(child);
      
      if (!strcmp (d->name, name))
        return child;
    }
  
  return child; /* NULL */
}

static int
_iso_dir_cmp (VcdDirNode_t *node1, VcdDirNode_t *node2)
{
  data_t *d1 = DATAP(node1);
  data_t *d2 = DATAP(node2);
  int result = 0;

  result = strcmp (d1->name, d2->name);

  return result;
}

int
_vcd_directory_mkdir (VcdDirectory_t *dir, const char pathname[])
{
  char **splitpath;
  unsigned level, n;
  VcdDirNode_t *pdir = _vcd_tree_root (dir);

  vcd_assert (dir != NULL);
  vcd_assert (pathname != NULL);

  splitpath = _vcd_strsplit (pathname, '/');

  level = _vcd_strlenv (splitpath);

  for (n = 0; n < level-1; n++) 
    if (!(pdir = lookup_child(pdir, splitpath[n]))) 
      {
        vcd_error("mkdir: parent dir `%s' (level=%d) for `%s' missing!",
                  splitpath[n], n, pathname);
        vcd_assert_not_reached ();
      }

  if (lookup_child (pdir, splitpath[level-1])) 
    {
      vcd_error ("mkdir: `%s' already exists", pathname);
      vcd_assert_not_reached ();
    }

  {
    data_t *data = calloc(1, sizeof (data_t));

    _vcd_tree_node_append_child (pdir, data);

    data->is_dir = true;
    data->name = strdup(splitpath[level-1]);
    data->xa_attributes = XA_FORM1_DIR;
    data->xa_filenum = 0x00;
    /* .. */
  }

  _vcd_tree_node_sort_children (pdir, _iso_dir_cmp);
  
  _vcd_strfreev (splitpath);

  return 0;
}

int
_vcd_directory_mkfile (VcdDirectory_t *dir, const char pathname[], 
                       uint32_t start, uint32_t size,
                       bool form2_flag, uint8_t filenum)
{
  char **splitpath;
  unsigned level, n;
  const int file_version = 1;

  VcdDirNode_t *pdir = NULL;

  vcd_assert (dir != NULL);
  vcd_assert (pathname != NULL);

  splitpath = _vcd_strsplit (pathname, '/');

  level = _vcd_strlenv (splitpath);

  while (!pdir)
    {
      pdir = _vcd_tree_root (dir);
      
      for (n = 0; n < level-1; n++) 
        if (!(pdir = lookup_child (pdir, splitpath[n]))) 
          {
            char *newdir = _vcd_strjoin (splitpath, n+1, "/");

            vcd_info ("autocreating directory `%s' for file `%s'",
                      newdir, pathname);
            
            _vcd_directory_mkdir (dir, newdir);
            
            free (newdir);
        
            vcd_assert (pdir == NULL);

            break;
          }
        else if (!DATAP(pdir)->is_dir)
          {
            char *newdir = _vcd_strjoin (splitpath, n+1, "/");

            vcd_error ("mkfile: `%s' not a directory", newdir);

            free (newdir);

            return -1;
          }

    }

  if (lookup_child (pdir, splitpath[level-1])) 
    {
      vcd_error ("mkfile: `%s' already exists", pathname);
      return -1;
    }
  
  {
    data_t *data = calloc(1, sizeof (data_t));

    _vcd_tree_node_append_child (pdir, data);

    data->is_dir = false;
    data->name = strdup (splitpath[level-1]);
    data->version = file_version;
    data->xa_attributes = form2_flag ? XA_FORM2_FILE : XA_FORM1_FILE;
    data->xa_filenum = filenum;
    data->size = size;
    data->extent = start;
    /* .. */
  }

  _vcd_tree_node_sort_children (pdir, _iso_dir_cmp);

  _vcd_strfreev (splitpath);

  return 0;
}

uint32_t
_vcd_directory_get_size (VcdDirectory_t *dir)
{
  vcd_assert (dir != NULL);

  update_sizes (dir);
  return get_dirsizes (_vcd_tree_root (dir));
}

static void
traverse_vcd_directory_dump_entries (VcdDirNode_t *node, void *data)
{
  data_t *d = DATAP(node);
  iso9660_xa_t xa_su;

  uint32_t root_extent = EXTENT(_vcd_tree_node_root (node));

  uint32_t parent_extent = 
    (!_vcd_tree_node_is_root (node))
    ? EXTENT(_vcd_tree_node_parent (node))
    : EXTENT(node);

  uint32_t parent_size = 
    (!_vcd_tree_node_is_root (node))
    ? SIZE(_vcd_tree_node_parent (node))
    : SIZE(node);

  void *dirbufp = (char*) data + ISO_BLOCKSIZE * (parent_extent - root_extent);

  iso9660_xa_init (&xa_su, 0, 0, d->xa_attributes, d->xa_filenum);

  if (!_vcd_tree_node_is_root (node))
    {
      char *pathname = (d->is_dir 
                        ? strdup (d->name)
                        : iso9660_pathname_isofy (d->name, d->version));

      iso9660_dir_add_entry_su (dirbufp, pathname, d->extent, d->size, 
                                d->is_dir ? ISO_DIRECTORY : ISO_FILE,
                                &xa_su, sizeof (xa_su),
                                &_vcd_time);

      free (pathname);
    }

  /* if this is a directory, create the new directory node */
  if (d->is_dir) 
    {
      dirbufp = (char*)data + ISO_BLOCKSIZE * (d->extent - root_extent);

      iso9660_dir_init_new_su (dirbufp, 
                               d->extent, d->size, &xa_su, sizeof (xa_su),
                               parent_extent, parent_size, &xa_su, 
                               sizeof (xa_su), &_vcd_time);
    }
}

void
_vcd_directory_dump_entries (VcdDirectory_t *dir, void *buf, uint32_t extent)
{
  vcd_assert (dir != NULL);

  update_sizes (dir); /* better call it one time more than one less */
  update_dirextents (dir, extent);

  _vcd_tree_node_traverse (_vcd_tree_root (dir), 
                           traverse_vcd_directory_dump_entries, buf); 
}

typedef struct 
{
  void *ptl;
  void *ptm;
} _vcd_directory_dump_pathtables_t;

static void
_dump_pathtables_helper (_vcd_directory_dump_pathtables_t *args,
                         data_t *d, uint16_t parent_id)
{
  uint16_t id_l, id_m;

  vcd_assert (args != NULL);
  vcd_assert (d != NULL);

  vcd_assert (d->is_dir);

  id_l = iso9660_pathtable_l_add_entry (args->ptl, d->name, d->extent, 
                                        parent_id);
  
  id_m = iso9660_pathtable_m_add_entry (args->ptm, d->name, d->extent, 
                                        parent_id);

  vcd_assert (id_l == id_m);

  d->pt_id = id_m;
}

static void
traverse_vcd_directory_dump_pathtables (VcdDirNode_t *node, void *data)
{
  _vcd_directory_dump_pathtables_t *args = data;

  if (DATAP (node)->is_dir)
    {
      VcdDirNode_t *parent = _vcd_tree_node_parent (node);
      uint16_t parent_id = parent ? PT_ID (parent) : 1;

      _dump_pathtables_helper (args, DATAP (node), parent_id);
    }
}

void
_vcd_directory_dump_pathtables (VcdDirectory_t *dir, void *ptl, void *ptm)
{
  _vcd_directory_dump_pathtables_t args;

  vcd_assert (dir != NULL);

  iso9660_pathtable_init (ptl);
  iso9660_pathtable_init (ptm);

  args.ptl = ptl;
  args.ptm = ptm;

  _vcd_tree_node_traverse_bf (_vcd_tree_root (dir),
                              traverse_vcd_directory_dump_pathtables, &args); 
}


/* 
 * Local variables:
 *  c-file-style: "gnu"
 *  tab-width: 8
 *  indent-tabs-mode: nil
 * End:
 */

/*
    $Id: data_structures.c,v 1.5 2005/02/09 10:00:59 rocky Exp $

    Copyright (C) 2000 Herbert Valerio Riedel <hvr@gnu.org>
    Copyright (C) 2004, 2005 Rocky Bernstein <rocky@panix.com>

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

#include <cdio/cdio.h>

/* Public headers */
#include <libvcd/types.h>

/* Private headers */
#include "vcd_assert.h"
#include "data_structures.h"
#include "util.h"

static const char _rcsid[] = "$Id: data_structures.c,v 1.5 2005/02/09 10:00:59 rocky Exp $";

struct _CdioList
{
  unsigned length;

  CdioListNode_t *begin;
  CdioListNode_t *end;
};

struct _CdioListNode
{
  CdioList_t *list;

  CdioListNode_t *next;

  void *data;
};

/* impl */

static bool
_bubble_sort_iteration (CdioList_t *p_list, _cdio_list_cmp_func cmp_func)
{
  CdioListNode_t **pp_node;
  bool changed = false;
  
  for (pp_node = &(p_list->begin);
       (*pp_node) != NULL && (*pp_node)->next != NULL;
       pp_node = &((*pp_node)->next))
    {
      CdioListNode_t *p_node = *pp_node;
      
      if (cmp_func (p_node->data, p_node->next->data) <= 0)
        continue; /* n <= n->next */
      
      /* exch n n->next */
      *pp_node = p_node->next;
      p_node->next = p_node->next->next;
      (*pp_node)->next = p_node;
      
      changed = true;

      if (p_node->next == NULL)
        p_list->end = p_node;
    }

  return changed;
}

void _vcd_list_sort (CdioList_t *list, _cdio_list_cmp_func cmp_func)
{
  /* fixme -- this is bubble sort -- worst sorting algo... */

  vcd_assert (list != NULL);
  vcd_assert (cmp_func != 0);
  
  while (_bubble_sort_iteration (list, cmp_func));
}

/* node ops */

CdioListNode_t *
_vcd_list_at (CdioList_t *list, int idx)
{
  CdioListNode_t *node = _cdio_list_begin (list);

  if (idx < 0)
    return _vcd_list_at (list, _cdio_list_length (list) + idx);

  vcd_assert (idx >= 0);

  while (node && idx)
    {
      node = _cdio_list_node_next (node);
      idx--;
    }

  return node;
}

/*
 * n-way tree based on list -- somewhat inefficent 
 */

struct _VcdTree
{
  VcdTreeNode_t *root;
};

struct _VcdTreeNode
{
  void *data;

  CdioListNode_t *listnode;
  VcdTree_t *tree;
  VcdTreeNode_t *parent;
  CdioList_t *children;
};

VcdTree_t *
_vcd_tree_new (void *root_data)
{
  VcdTree_t *new_tree;

  new_tree = calloc(1, sizeof (VcdTree_t));

  new_tree->root = calloc(1, sizeof (VcdTreeNode_t));

  new_tree->root->data = root_data;
  new_tree->root->tree = new_tree;
  new_tree->root->parent = NULL;
  new_tree->root->children = NULL;
  new_tree->root->listnode = NULL;
  
  return new_tree;
}

void
_vcd_tree_destroy (VcdTree_t *tree, bool free_data)
{
  _vcd_tree_node_destroy (tree->root, free_data);
  
  free (tree->root);
  free (tree);
}

void
_vcd_tree_node_destroy (VcdTreeNode_t *p_node, bool free_data)
{
  VcdTreeNode_t *p_child, *nxt_child;
  
  vcd_assert (p_node != NULL);

  p_child = _vcd_tree_node_first_child (p_node);
  while(p_child) {
    nxt_child = _vcd_tree_node_next_sibling (p_child);
    _vcd_tree_node_destroy (p_child, free_data);
    p_child = nxt_child;
  }

  if (p_node->children)
    {
      vcd_assert (_cdio_list_length (p_node->children) == 0);
      _cdio_list_free (p_node->children, true);
      p_node->children = NULL;
    }

  if (free_data)
    free (_vcd_tree_node_set_data (p_node, NULL));

  if (p_node->parent)
    _cdio_list_node_free (p_node->listnode, true);
  else
    _vcd_tree_node_set_data (p_node, NULL);
}

VcdTreeNode_t *
_vcd_tree_root (VcdTree_t *p_tree)
{
  return p_tree->root;
}

void *
_vcd_tree_node_data (VcdTreeNode_t *p_node)
{
  return p_node->data;
}

void *
_vcd_tree_node_set_data (VcdTreeNode_t *p_node, void *p_new_data)
{
  void *p_old_data = p_node->data;

  p_node->data = p_new_data;

  return p_old_data;
}

VcdTreeNode_t *
_vcd_tree_node_append_child (VcdTreeNode_t *p_node, void *cdata)
{
  VcdTreeNode_t *p_nnode;

  vcd_assert (p_node != NULL);

  if (!p_node->children)
    p_node->children = _cdio_list_new ();

  p_nnode = calloc(1, sizeof (VcdTreeNode_t));

  _cdio_list_append (p_node->children, p_nnode);

  p_nnode->data = cdata;
  p_nnode->parent = p_node;
  p_nnode->tree = p_node->tree;
  p_nnode->listnode = _cdio_list_end (p_node->children);

  return p_nnode;
}

VcdTreeNode_t *
_vcd_tree_node_first_child (VcdTreeNode_t *p_node)
{
  vcd_assert (p_node != NULL);

  if (!p_node->children)
    return NULL;

  return _cdio_list_node_data (_cdio_list_begin (p_node->children));
}

VcdTreeNode_t *
_vcd_tree_node_next_sibling (VcdTreeNode_t *p_node)
{
  vcd_assert (p_node != NULL);

  return _cdio_list_node_data (_cdio_list_node_next (p_node->listnode));
}

void
_vcd_tree_node_sort_children (VcdTreeNode_t *p_node, 
                              _vcd_tree_node_cmp_func cmp_func)
{
  vcd_assert (p_node != NULL);

  if (p_node->children)
    _vcd_list_sort (p_node->children, (_cdio_list_cmp_func) cmp_func);
}

void
_vcd_tree_node_traverse (VcdTreeNode_t *p_node, 
                         _vcd_tree_node_traversal_func trav_func,
                         void *p_user_data) /* pre-order */
{
  VcdTreeNode_t *p_child;

  vcd_assert (p_node != NULL);

  trav_func (p_node, p_user_data);

  _VCD_CHILD_FOREACH (p_child, p_node)
    {
      _vcd_tree_node_traverse (p_child, trav_func, p_user_data);
    }
}

void
_vcd_tree_node_traverse_bf (VcdTreeNode_t *p_node, 
                            _vcd_tree_node_traversal_func trav_func,
                            void *p_user_data) /* breath-first */
{
  CdioList_t *queue;

  vcd_assert (p_node != NULL);

  queue = _cdio_list_new ();

  _cdio_list_prepend (queue, p_node);

  while (_cdio_list_length (queue))
    {
      CdioListNode_t *lastnode = _cdio_list_end (queue);
      VcdTreeNode_t  *treenode = _cdio_list_node_data (lastnode);
      VcdTreeNode_t  *childnode;

      _cdio_list_node_free (lastnode, false);

      trav_func (treenode, p_user_data);
      
      _VCD_CHILD_FOREACH (childnode, treenode)
        {
          _cdio_list_prepend (queue, childnode);
        }
    }

  _cdio_list_free (queue, false);
}

VcdTreeNode_t *_vcd_tree_node_parent (VcdTreeNode_t *p_node)
{
  return p_node->parent;
}

VcdTreeNode_t *_vcd_tree_node_root (VcdTreeNode_t *p_node)
{
  return p_node->tree->root;
}

bool _vcd_tree_node_is_root (VcdTreeNode_t *p_node)
{
  return (p_node->parent == NULL);
}

/* eof */


/* 
 * Local variables:
 *  c-file-style: "gnu"
 *  tab-width: 8
 *  indent-tabs-mode: nil
 * End:
 */


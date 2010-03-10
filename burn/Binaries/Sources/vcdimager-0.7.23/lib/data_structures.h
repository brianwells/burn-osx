/*
    $Id: data_structures.h,v 1.5 2005/02/09 10:00:59 rocky Exp $

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

#ifndef __VCD_DATA_STRUCTURES_H__
#define __VCD_DATA_STRUCTURES_H__

#include <cdio/ds.h>
#include <libvcd/types.h>

/* node ops */

CdioListNode_t *_vcd_list_at (CdioList_t *list, int idx);

void _vcd_list_sort (CdioList_t *p_list, _cdio_list_cmp_func cmp_func);

/* n-way tree */

typedef struct _VcdTree VcdTree_t;
typedef struct _VcdTreeNode VcdTreeNode_t;

#define _VCD_CHILD_FOREACH(child, parent) \
 for (child = _vcd_tree_node_first_child (parent); child; child = _vcd_tree_node_next_sibling (child))

typedef int (*_vcd_tree_node_cmp_func) (VcdTreeNode_t *p_node1, 
                                        VcdTreeNode_t *p_node2);

typedef void (*_vcd_tree_node_traversal_func) (VcdTreeNode_t *p_node, 
                                               void *p_user_data);

VcdTree_t *_vcd_tree_new (void *p_root_data);

void _vcd_tree_destroy (VcdTree_t *tree, bool free_data);

VcdTreeNode_t *_vcd_tree_root (VcdTree_t *p_tree);

void _vcd_tree_node_sort_children (VcdTreeNode_t *node,
                                   _vcd_tree_node_cmp_func cmp_func);

void *_vcd_tree_node_data (VcdTreeNode_t *p_node);

void _vcd_tree_node_destroy (VcdTreeNode_t *p_node, bool free_data);

void *_vcd_tree_node_set_data (VcdTreeNode_t *p_node, void *p_new_data);

VcdTreeNode_t *_vcd_tree_node_append_child (VcdTreeNode_t *p_node, 
                                            void *p_cdata);

VcdTreeNode_t *_vcd_tree_node_first_child (VcdTreeNode_t *p_node);

VcdTreeNode_t *_vcd_tree_node_next_sibling (VcdTreeNode_t *p_node);

VcdTreeNode_t *_vcd_tree_node_parent (VcdTreeNode_t *p_node);

VcdTreeNode_t *_vcd_tree_node_root (VcdTreeNode_t *p_node);

bool _vcd_tree_node_is_root (VcdTreeNode_t *p_node);

void _vcd_tree_node_traverse (VcdTreeNode_t *p_node, 
                              _vcd_tree_node_traversal_func trav_func,
                              void *user_data);

void
_vcd_tree_node_traverse_bf (VcdTreeNode_t *p_node, 
                            _vcd_tree_node_traversal_func trav_func,
                            void *p_user_data);
     
#endif /* __VCD_DATA_STRUCTURES_H__ */

/* 
 * Local variables:
 *  c-file-style: "gnu"
 *  tab-width: 8
 *  indent-tabs-mode: nil
 * End:
 */


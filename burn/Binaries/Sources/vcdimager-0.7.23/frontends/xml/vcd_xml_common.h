/*
    $Id: vcd_xml_common.h,v 1.7 2003/11/10 11:57:48 rocky Exp $

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

#ifndef __VCD_XML_COMMON_H__
#define __VCD_XML_COMMON_H__

#include <libvcd/logging.h>

extern bool vcd_xml_gui_mode;

extern bool vcd_xml_show_progress;

extern bool vcd_xml_check_mode;

extern vcd_log_level_t vcd_xml_verbosity;

extern const char *vcd_xml_progname;


void vcd_xml_log_init (void);

int vcd_xml_scan_progress_cb (const vcd_mpeg_prog_info_t *info, void *user_data);

int vcd_xml_write_progress_cb (const progress_info_t *info, void *user_data);

typedef struct {
  long done;
  long total;
} _read_progress_t;

int vcd_xml_read_progress_cb (const _read_progress_t *info, void *user_data);

void vcd_xml_print_version (void);

extern const char *vcd_xml_filename_charset;

unsigned char *vcd_xml_filename_to_utf8 (const char fname[]);
char *vcd_xml_utf8_to_filename (const unsigned char fname[]);

#endif /* __VCD_XML_COMMON_H__ */

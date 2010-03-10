/*
    $Id: stream.h,v 1.4 2005/06/07 23:29:23 rocky Exp $

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


#ifndef __VCD_STREAM_H__
#define __VCD_STREAM_H__

#include <libvcd/types.h>

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

/* typedef'ed IO functions prototypes */

typedef int(*vcd_data_open_t)(void *p_user_data);

typedef long(*vcd_data_read_t)(void *p_user_data, void *buf, long count);

typedef long(*vcd_data_write_t)(void *p_user_data, const void *buf,
                                  long count);

typedef long(*vcd_data_seek_t)(void *p_user_data, long offset);

typedef long(*vcd_data_stat_t)(void *p_user_data);

typedef int(*vcd_data_close_t)(void *p_user_data);

typedef void(*vcd_data_free_t)(void *p_user_data);


/* abstract data sink */

typedef struct _VcdDataSink VcdDataSink;

typedef struct {
  vcd_data_open_t open;
  vcd_data_seek_t seek;
  vcd_data_write_t write;
  vcd_data_close_t close;
  vcd_data_free_t free;
} vcd_data_sink_io_functions;

VcdDataSink* 
vcd_data_sink_new(void *p_user_data, const vcd_data_sink_io_functions *funcs);

long
vcd_data_sink_write(VcdDataSink* p_obj, const void *ptr, long size, 
                    long nmemb);

long
vcd_data_sink_printf (VcdDataSink *obj, const char format[], ...) GNUC_PRINTF(2, 3);

long
vcd_data_sink_seek(VcdDataSink* p_obj, long offset);

void
vcd_data_sink_destroy(VcdDataSink* p_obj);

void
vcd_data_sink_close(VcdDataSink* p_obj);

/* abstract data source */

typedef struct _VcdDataSource VcdDataSource_t;

typedef struct {
  vcd_data_open_t open;
  vcd_data_seek_t seek; 
  vcd_data_stat_t stat; 
  vcd_data_read_t read;
  vcd_data_close_t close;
  vcd_data_free_t free;
} vcd_data_source_io_functions;

VcdDataSource_t *
vcd_data_source_new(void *p_user_data, 
                    const vcd_data_source_io_functions *funcs);

/** 
    read size*nmemb bytes from obj into ptr 
*/
long
vcd_data_source_read(VcdDataSource_t *p_obj, /*out*/ void *ptr, long int size, 
                     long int nmemb);

long
vcd_data_source_seek(VcdDataSource_t *p_obj, long int offset);

long
vcd_data_source_stat(VcdDataSource_t *p_obj);

void
vcd_data_source_destroy(VcdDataSource_t *p_obj);

void
vcd_data_source_close(VcdDataSource_t *p_obj);

#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /* __VCD_STREAM_H__ */


/* 
 * Local variables:
 *  c-file-style: "gnu"
 *  tab-width: 8
 *  indent-tabs-mode: nil
 * End:
 */

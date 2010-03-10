/*
    $Id: stream_stdio.h,v 1.3 2005/06/07 23:29:23 rocky Exp $

    Copyright (C) 2000 Herbert Valerio Riedel <hvr@gnu.org>

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


#ifndef __VCD_STREAM_STDIO_H__
#define __VCD_STREAM_STDIO_H__

/* Private headers */
#include "stream.h"

VcdDataSink*
vcd_data_sink_new_stdio(const char pathname[]);

VcdDataSource_t *
vcd_data_source_new_stdio(const char pathname[]);

#endif /* __VCD_STREAM_STDIO_H__ */


/* 
 * Local variables:
 *  c-file-style: "gnu"
 *  tab-width: 8
 *  indent-tabs-mode: nil
 * End:
 */

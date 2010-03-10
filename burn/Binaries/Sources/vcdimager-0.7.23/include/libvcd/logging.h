/*
    $Id: logging.h,v 1.3 2004/05/05 01:52:31 rocky Exp $

    Copyright (C) 2000 Herbert Valerio Riedel <hvr@gnu.org>
    Copyright (C) 2003 Rocky Bernstein <rocky@panix.com>

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

#ifndef __VCD_LOGGING_H__
#define __VCD_LOGGING_H__

#include <libvcd/types.h>

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

/**
 * The different log levels supported.
 */
typedef enum {
  VCD_LOG_DEBUG = 1, /**< Debug-level messages - helps debug what's up. */
  VCD_LOG_INFO,      /**< Informational - indicates perhaps something of 
                           interest. */
  VCD_LOG_WARN,      /**< Warning conditions - something that looks funny. */
  VCD_LOG_ERROR,     /**< Error conditions - may terminate program.  */
  VCD_LOG_ASSERT     /**< Critical conditions - may abort program. */
} vcd_log_level_t;

/**
 * The place to save the preference concerning how much verbosity 
 * is desired. This is used by the internal default log handler, but
 * it could be use by applications which provide their own log handler.
 */
extern vcd_log_level_t vcd_loglevel_default;

/**
 * This type defines the signature of a log handler.  For every
 * message being logged, the handler will receive the log level and
 * the message string.
 *
 * @see vcd_log_set_handler
 * @see vcd_log_level_t
 *
 * @param level   The log level.
 * @param message The log message.
 */
typedef void (*vcd_log_handler_t) (vcd_log_level_t level, 
                                   const char message[]);

/**
 * Set a custom log handler for libcdio.  The return value is the log
 * handler being replaced.  If the provided parameter is NULL, then
 * the handler will be reset to the default handler.
 *
 * @see vcd_log_handler_t
 *
 * @param new_handler The new log handler.
 * @return The previous log handler.
 */
vcd_log_handler_t
vcd_log_set_handler (vcd_log_handler_t new_handler);

/**
 * Handle an message with the given log level
 *
 * @see vcd_debug
 * @see vcd_info
 * @see vcd_warn
 * @see vcd_error

 * @param level   The log level.
 * @param format  printf-style format string
 * @param ...     remaining arguments needed by format string
 */
void
vcd_log (vcd_log_level_t level, const char format[], ...) GNUC_PRINTF(2, 3);
    
/**
 * Handle a debugging message.
 *
 * @see vcd_log for a more generic routine
 */
void
vcd_debug (const char format[], ...) GNUC_PRINTF(1,2);

/**
 * Handle an informative message.
 *
 * @see vcd_log for a more generic routine
 */
void
vcd_info (const char format[], ...) GNUC_PRINTF(1,2);

/**
 * Handle a warning message.
 *
 * @see vcd_log for a more generic routine
 */
void
vcd_warn (const char format[], ...) GNUC_PRINTF(1,2);

/**
 * Handle an error message.
 *
 * @see vcd_log for a more generic routine. Execution is terminated.
 */
void
vcd_error (const char format[], ...) GNUC_PRINTF(1,2);

#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /* __VCD_LOGGING_H__ */


/* 
 * Local variables:
 *  c-file-style: "gnu"
 *  tab-width: 8
 *  indent-tabs-mode: nil
 * End:
 */

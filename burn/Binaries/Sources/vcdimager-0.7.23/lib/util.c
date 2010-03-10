/*
    $Id: util.c,v 1.4 2005/02/02 00:37:37 rocky Exp $

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

#include <ctype.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <cdio/bytesex.h>

/* Private includes */
#include "vcd_assert.h"
#include "util.h"

static const char _rcsid[] = "$Id: util.c,v 1.4 2005/02/02 00:37:37 rocky Exp $";

size_t
_vcd_strlenv(char **str_array)
{
  size_t n = 0;

  vcd_assert (str_array != NULL);

  while(str_array[n])
    n++;

  return n;
}

void
_vcd_strfreev(char **strv)
{
  int n;
  
  vcd_assert (strv != NULL);

  for(n = 0; strv[n]; n++)
    free(strv[n]);

  free(strv);
}

char *
_vcd_strjoin (char *strv[], unsigned count, const char delim[])
{
  size_t len;
  char *new_str;
  unsigned n;

  vcd_assert (strv != NULL);
  vcd_assert (delim != NULL);

  len = (count-1) * strlen (delim);

  for (n = 0;n < count;n++)
    len += strlen (strv[n]);

  len++;

  new_str = calloc(1, len);
  new_str[0] = '\0';

  for (n = 0;n < count;n++)
    {
      if (n)
        strcat (new_str, delim);
      strcat (new_str, strv[n]);
    }
  
  return new_str;
}

char **
_vcd_strsplit(const char str[], char delim) /* fixme -- non-reentrant */
{
  int n;
  char **strv = NULL;
  char *_str, *p;
  char _delim[2] = { 0, 0 };

  vcd_assert (str != NULL);

  _str = strdup(str);
  _delim[0] = delim;

  vcd_assert (_str != NULL);

  n = 1;
  p = _str;
  while(*p) 
    if (*(p++) == delim)
      n++;

  strv = calloc(1, sizeof (char *) * (n+1));
  
  n = 0;
  while((p = strtok(n ? NULL : _str, _delim)) != NULL) 
    strv[n++] = strdup(p);

  free(_str);

  return strv;
}

void *
_vcd_memdup (const void *mem, size_t count)
{
  void *new_mem = NULL;

  if (mem)
    {
      new_mem = malloc(count);
      memcpy (new_mem, mem, count);
    }
  
  return new_mem;
}

char *
_vcd_strdup_upper (const char str[])
{
  char *new_str = NULL;

  if (str)
    {
      char *p;

      p = new_str = strdup (str);

      while (*p)
        {
          *p = toupper (*p);
          p++;
        }
    }

  return new_str;
}


/* 
 * Local variables:
 *  c-file-style: "gnu"
 *  tab-width: 8
 *  indent-tabs-mode: nil
 * End:
 */

/* memory allocation routines with error checking.
   Copyright 1989, 90, 91, 92, 93, 94 Free Software Foundation, Inc.

This file is part of the libiberty library.
Libiberty is free software; you can redistribute it and/or
modify it under the terms of the GNU Library General Public
License as published by the Free Software Foundation; either
version 2 of the License, or (at your option) any later version.

Libiberty is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Library General Public License for more details.

You should have received a copy of the GNU Library General Public
License along with libiberty; see the file COPYING.LIB.  If
not, write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
Boston, MA 02111-1307, USA.  */

#include "ansidecl.h"
#include "libiberty.h"

#include <stdio.h>

#ifdef __STDC__
#include <stddef.h>
#else
#define size_t unsigned long
#define ptrdiff_t long
#endif


/* For systems with larger pointers than ints, these must be declared.  */
PTR malloc PARAMS ((size_t));


/* The program name if set.  */
static const char *name = "";

#ifdef HAVE_SBRK
/* The initial sbrk, set when the program name is set. Not used for win32
   ports other than cygwin32.  */
static char *first_break = NULL;
#endif /* HAVE_SBRK */


void (*_xexit_cleanup) PARAMS ((void));

void
xexit (int code)
{
  if (_xexit_cleanup != NULL)
    (*_xexit_cleanup) ();
  exit (code);
}


PTR
xmalloc (size_t size)
{
  PTR newmem;

  if (size == 0)
    size = 1;
  newmem = malloc (size);
  if (!newmem)
    {
#ifdef HAVE_SBRK
      extern char **environ;
      size_t allocated;

      if (first_break != NULL)
	allocated = (char *) sbrk (0) - first_break;
      else
	allocated = (char *) sbrk (0) - (char *) &environ;
      fprintf (stderr,
	       "\n%s%sCan not allocate %lu bytes after allocating %lu bytes\n",
	       name, *name ? ": " : "",
	       (unsigned long) size, (unsigned long) allocated);
#else /* HAVE_SBRK */
      fprintf (stderr,
	       "\n%s%sCan not allocate %lu bytes\n",
	       name, *name ? ": " : "", (unsigned long) size);
#endif /* HAVE_SBRK */
      xexit (1);
    }
  return (newmem);
}

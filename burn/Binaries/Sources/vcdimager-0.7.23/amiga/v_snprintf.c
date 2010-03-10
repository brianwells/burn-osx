#include <stdio.h>
#include <stdarg.h>
#include <string.h>

int
vsnprintf (char *str, size_t n, const char *fmt, va_list ap)
{
  int ret;
  char buffer[4096] = { 0, };

  if ((int) n < 1)
    return (EOF);

  ret = vsprintf (buffer, fmt, ap);

  if (ret >= n)
    {
      memcpy (str, buffer, n);
      str[n - 1] = '\0';
    }
  else
    {
      memcpy (str, buffer, ret);
      str[ret] = '\0';
    }

  if (ret>=n)
    ret = -1;

  return (ret);
}

int
snprintf (char *s, size_t size, const char *format, ...)
{
  int retval;
  va_list args;

  va_start (args, format);
  retval = vsnprintf (s, size, format, args);
  va_end (args);

  return retval;
}

/* EOF */

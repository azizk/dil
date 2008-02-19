/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.Time;

import tango.stdc.time : time_t, time, ctime;
import tango.stdc.string : strlen;

struct Time
{
static:
  char[] toString()
  {
    time_t time_val;
    .time(&time_val);
    char* str = ctime(&time_val); // ctime returns a pointer to a static array.
    char[] timeStr = str[0 .. strlen(str)-1]; // -1 removes trailing '\n'.
    return timeStr.dup;
  }

  char[] time(char[] timeStr)
  {
    return timeStr[11..19];
  }

  char[] month_day(char[] timeStr)
  {
    return timeStr[4..10];
  }

  char[] year(char[] timeStr)
  {
    return timeStr[20..24];
  }
}

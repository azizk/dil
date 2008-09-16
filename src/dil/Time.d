/// Author: Aziz Köksal
/// License: GPL3
module dil.Time;

import tango.stdc.time : time_t, time, ctime;
import tango.stdc.string : strlen;

/// Some convenience functions for dealing with C's time functions.
struct Time
{
static:
  /// Returns the current date as a string.
  char[] toString()
  {
    time_t time_val;
    .time(&time_val);
    char* str = ctime(&time_val); // ctime returns a pointer to a static array.
    char[] timeStr = str[0 .. strlen(str)-1]; // -1 removes trailing '\n'.
    return timeStr.dup;
  }

  /// Returns the time of timeStr: hh:mm:ss
  char[] time(char[] timeStr)
  {
    return timeStr[11..19];
  }

  /// Returns the month and day of timeStr: Mmm dd
  char[] month_day(char[] timeStr)
  {
    return timeStr[4..10];
  }

  /// Returns the year of timeStr: yyyy
  char[] year(char[] timeStr)
  {
    return timeStr[20..24];
  }
}

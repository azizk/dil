/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity high)
module dil.Time;

import dil.String;
import common;

import tango.stdc.time : time_t, time, ctime;

/// Some convenience functions for dealing with C's time functions.
struct Time
{
static:
  /// Returns the current date as a string.
  char[] now()
  {
    time_t time_val;
    tango.stdc.time.time(&time_val);
    // ctime returns a pointer to a static array.
    char* timeStr = ctime(&time_val);
    return String(timeStr, '\n').array;
  }

  /// Returns the time of timeStr: hh:mm:ss
  cstring time(cstring timeStr)
  {
    return timeStr[11..19];
  }

  /// Returns the month and day of timeStr: Mmm dd
  cstring month_day(cstring timeStr)
  {
    return timeStr[4..10];
  }

  /// Returns the year of timeStr: yyyy
  cstring year(cstring timeStr)
  {
    return timeStr[20..24];
  }
}

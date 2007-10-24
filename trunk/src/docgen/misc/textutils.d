/**
 * Author: Aziz Köksal & Jari-Matti Mäkelä
 * License: GPL3
 */
module docgen.misc.textutils;

// copied from Generate.d
char[] xml_escape(char[] text)
{
  char[] result;
  result.length = text.length;
  foreach(c; text)
    switch(c)
    {
      case '<': result ~= "&lt;";  break;
      case '>': result ~= "&gt;";  break;
      case '&': result ~= "&amp;"; break;
      default:  result ~= c;
    }
  return result;
}

char[] plainTextHeading(char[] s) {
  char[] line;
  line.length = 80;
  line[] = "=";

  return s ~ \n ~ line[0..s.length].dup ~ \n ~ \n;
}

char[] plainTextHorizLine(int l = 80) {
  char[] line;
  line.length = 80;
  line[] = "-";
  
  return line[0..l].dup ~ \n;
}

/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity very high)
module dil.HtmlEntities;

import dil.lexer.Funcs : toString;
import common;

/// A named HTML entity.
struct Entity
{
  char[] name;
  dchar value;
}

/// The table of named HTML entities.
static const Entity[] namedEntities = [
  {"Aacute", '\u00C1'},
  {"aacute", '\u00E1'},
  {"Acirc", '\u00C2'},
  {"acirc", '\u00E2'},
  {"acute", '\u00B4'},
  {"AElig", '\u00C6'},
  {"aelig", '\u00E6'},
  {"Agrave", '\u00C0'},
  {"agrave", '\u00E0'},
  {"alefsym", '\u2135'},
  {"Alpha", '\u0391'},
  {"alpha", '\u03B1'},
  {"amp", '\u0026'},
  {"and", '\u2227'},
  {"ang", '\u2220'},
  {"Aring", '\u00C5'},
  {"aring", '\u00E5'},
  {"asymp", '\u2248'},
  {"Atilde", '\u00C3'},
  {"atilde", '\u00E3'},
  {"Auml", '\u00C4'},
  {"auml", '\u00E4'},
  {"bdquo", '\u201E'},
  {"Beta", '\u0392'},
  {"beta", '\u03B2'},
  {"brvbar", '\u00A6'},
  {"bull", '\u2022'},
  {"cap", '\u2229'},
  {"Ccedil", '\u00C7'},
  {"ccedil", '\u00E7'},
  {"cedil", '\u00B8'},
  {"cent", '\u00A2'},
  {"Chi", '\u03A7'},
  {"chi", '\u03C7'},
  {"circ", '\u02C6'},
  {"clubs", '\u2663'},
  {"cong", '\u2245'},
  {"copy", '\u00A9'},
  {"crarr", '\u21B5'},
  {"cup", '\u222A'},
  {"curren", '\u00A4'},
  {"Dagger", '\u2021'},
  {"dagger", '\u2020'},
  {"dArr", '\u21D3'},
  {"darr", '\u2193'},
  {"deg", '\u00B0'},
  {"Delta", '\u0394'},
  {"delta", '\u03B4'},
  {"diams", '\u2666'},
  {"divide", '\u00F7'},
  {"Eacute", '\u00C9'},
  {"eacute", '\u00E9'},
  {"Ecirc", '\u00CA'},
  {"ecirc", '\u00EA'},
  {"Egrave", '\u00C8'},
  {"egrave", '\u00E8'},
  {"empty", '\u2205'},
  {"emsp", '\u2003'},
  {"ensp", '\u2002'},
  {"Epsilon", '\u0395'},
  {"epsilon", '\u03B5'},
  {"equiv", '\u2261'},
  {"Eta", '\u0397'},
  {"eta", '\u03B7'},
  {"ETH", '\u00D0'},
  {"eth", '\u00F0'},
  {"Euml", '\u00CB'},
  {"euml", '\u00EB'},
  {"euro", '\u20AC'},
  {"exist", '\u2203'},
  {"fnof", '\u0192'},
  {"forall", '\u2200'},
  {"frac12", '\u00BD'},
  {"frac14", '\u00BC'},
  {"frac34", '\u00BE'},
  {"frasl", '\u2044'},
  {"Gamma", '\u0393'},
  {"gamma", '\u03B3'},
  {"ge", '\u2265'},
  {"gt", '\u003E'},
  {"hArr", '\u21D4'},
  {"harr", '\u2194'},
  {"hearts", '\u2665'},
  {"hellip", '\u2026'},
  {"Iacute", '\u00CD'},
  {"iacute", '\u00ED'},
  {"Icirc", '\u00CE'},
  {"icirc", '\u00EE'},
  {"iexcl", '\u00A1'},
  {"Igrave", '\u00CC'},
  {"igrave", '\u00EC'},
  {"image", '\u2111'},
  {"infin", '\u221E'},
  {"int", '\u222B'},
  {"Iota", '\u0399'},
  {"iota", '\u03B9'},
  {"iquest", '\u00BF'},
  {"isin", '\u2208'},
  {"Iuml", '\u00CF'},
  {"iuml", '\u00EF'},
  {"Kappa", '\u039A'},
  {"kappa", '\u03BA'},
  {"Lambda", '\u039B'},
  {"lambda", '\u03BB'},
  {"lang", '\u2329'},
  {"laquo", '\u00AB'},
  {"lArr", '\u21D0'},
  {"larr", '\u2190'},
  {"lceil", '\u2308'},
  {"ldquo", '\u201C'},
  {"le", '\u2264'},
  {"lfloor", '\u230A'},
  {"lowast", '\u2217'},
  {"loz", '\u25CA'},
  {"lrm", '\u200E'},
  {"lsaquo", '\u2039'},
  {"lsquo", '\u2018'},
  {"lt", '\u003C'},
  {"macr", '\u00AF'},
  {"mdash", '\u2014'},
  {"micro", '\u00B5'},
  {"middot", '\u00B7'},
  {"minus", '\u2212'},
  {"Mu", '\u039C'},
  {"mu", '\u03BC'},
  {"nabla", '\u2207'},
  {"nbsp", '\u00A0'},
  {"ndash", '\u2013'},
  {"ne", '\u2260'},
  {"ni", '\u220B'},
  {"not", '\u00AC'},
  {"notin", '\u2209'},
  {"nsub", '\u2284'},
  {"Ntilde", '\u00D1'},
  {"ntilde", '\u00F1'},
  {"Nu", '\u039D'},
  {"nu", '\u03BD'},
  {"Oacute", '\u00D3'},
  {"oacute", '\u00F3'},
  {"Ocirc", '\u00D4'},
  {"ocirc", '\u00F4'},
  {"OElig", '\u0152'},
  {"oelig", '\u0153'},
  {"Ograve", '\u00D2'},
  {"ograve", '\u00F2'},
  {"oline", '\u203E'},
  {"Omega", '\u03A9'},
  {"omega", '\u03C9'},
  {"Omicron", '\u039F'},
  {"omicron", '\u03BF'},
  {"oplus", '\u2295'},
  {"or", '\u2228'},
  {"ordf", '\u00AA'},
  {"ordm", '\u00BA'},
  {"Oslash", '\u00D8'},
  {"oslash", '\u00F8'},
  {"Otilde", '\u00D5'},
  {"otilde", '\u00F5'},
  {"otimes", '\u2297'},
  {"Ouml", '\u00D6'},
  {"ouml", '\u00F6'},
  {"para", '\u00B6'},
  {"part", '\u2202'},
  {"permil", '\u2030'},
  {"perp", '\u22A5'},
  {"Phi", '\u03A6'},
  {"phi", '\u03C6'},
  {"Pi", '\u03A0'},
  {"pi", '\u03C0'},
  {"piv", '\u03D6'},
  {"plusmn", '\u00B1'},
  {"pound", '\u00A3'},
  {"Prime", '\u2033'},
  {"prime", '\u2032'},
  {"prod", '\u220F'},
  {"prop", '\u221D'},
  {"Psi", '\u03A8'},
  {"psi", '\u03C8'},
  {"quot", '\u0022'},
  {"radic", '\u221A'},
  {"rang", '\u232A'},
  {"raquo", '\u00BB'},
  {"rArr", '\u21D2'},
  {"rarr", '\u2192'},
  {"rceil", '\u2309'},
  {"rdquo", '\u201D'},
  {"real", '\u211C'},
  {"reg", '\u00AE'},
  {"rfloor", '\u230B'},
  {"Rho", '\u03A1'},
  {"rho", '\u03C1'},
  {"rlm", '\u200F'},
  {"rsaquo", '\u203A'},
  {"rsquo", '\u2019'},
  {"sbquo", '\u201A'},
  {"Scaron", '\u0160'},
  {"scaron", '\u0161'},
  {"sdot", '\u22C5'},
  {"sect", '\u00A7'},
  {"shy", '\u00AD'},
  {"Sigma", '\u03A3'},
  {"sigma", '\u03C3'},
  {"sigmaf", '\u03C2'},
  {"sim", '\u223C'},
  {"spades", '\u2660'},
  {"sub", '\u2282'},
  {"sube", '\u2286'},
  {"sum", '\u2211'},
  {"sup", '\u2283'},
  {"sup1", '\u00B9'},
  {"sup2", '\u00B2'},
  {"sup3", '\u00B3'},
  {"supe", '\u2287'},
  {"szlig", '\u00DF'},
  {"Tau", '\u03A4'},
  {"tau", '\u03C4'},
  {"there4", '\u2234'},
  {"Theta", '\u0398'},
  {"theta", '\u03B8'},
  {"thetasym", '\u03D1'},
  {"thinsp", '\u2009'},
  {"THORN", '\u00DE'},
  {"thorn", '\u00FE'},
  {"tilde", '\u02DC'},
  {"times", '\u00D7'},
  {"trade", '\u2122'},
  {"Uacute", '\u00DA'},
  {"uacute", '\u00FA'},
  {"uArr", '\u21D1'},
  {"uarr", '\u2191'},
  {"Ucirc", '\u00DB'},
  {"ucirc", '\u00FB'},
  {"Ugrave", '\u00D9'},
  {"ugrave", '\u00F9'},
  {"uml", '\u00A8'},
  {"upsih", '\u03D2'},
  {"Upsilon", '\u03A5'},
  {"upsilon", '\u03C5'},
  {"Uuml", '\u00DC'},
  {"uuml", '\u00FC'},
  {"weierp", '\u2118'},
  {"Xi", '\u039E'},
  {"xi", '\u03BE'},
  {"Yacute", '\u00DD'},
  {"yacute", '\u00FD'},
  {"yen", '\u00A5'},
  {"Yuml", '\u0178'},
  {"yuml", '\u00FF'},
  {"Zeta", '\u0396'},
  {"zeta", '\u03B6'},
  {"zwj", '\u200D'},
  {"zwnj", '\u200C'}
];

uint stringToHash(char[] str)
{
  uint hash;
  foreach(c; str)
    hash = hash * 11 + c;
  return hash;
}

char[] generateHashAndValueArrays()
{
  uint[] hashes; // String hashes.
  dchar[] values; // Unicode codepoints.
  // Build arrays:
  foreach (entity; namedEntities)
  {
    auto hash = stringToHash(entity.name);
    auto value = entity.value;
    assert(hash != 0);
    // Find insertion place.
    uint i;
    for (; i < hashes.length; ++i)
    {
      assert(hash != hashes[i], "bad hash function: conflicting hashes");
      if (hash < hashes[i])
        break;
    }
    // Insert hash and value into tables.
    if (i == hashes.length)
    {
      hashes ~= hash;
      values ~= value;
    }
    else
    {
      hashes = hashes[0..i] ~ hash ~ hashes[i..$]; // Insert before index.
      values = values[0..i] ~ value ~ values[i..$]; // Insert before index.
    }
    assert(hashes[i] == hash && values[i] == value);
  }
  // Build source text:
  char[] hashesText = "private static const uint[] hashes = [",
         valuesText = "private static const dchar[] values = [";
  foreach (i, hash; hashes)
  {
    hashesText ~= toString(hash) ~ ",";
    valuesText ~= toString(values[i]) ~ ",";
  }
  hashesText ~= "];";
  valuesText ~= "];";
  return hashesText ~"\n"~ valuesText;
}

version(DDoc)
{
  /// Table of hash values of the entities' names.
  private static const uint[] hashes;
  /// Table of Unicode codepoints.
  private static const dchar[] values;
}
else
  mixin(generateHashAndValueArrays);
// pragma(msg, generateHashAndValueArrays());

/// Converts a named HTML entity into its equivalent Unicode codepoint.
/// Returns: the entity's value or 0xFFFF if it doesn't exist.
dchar entity2Unicode(char[] entity)
{
  auto hash = stringToHash(entity);
  // Binary search:
  size_t lower = void, index = void, upper = void;
  lower = 0;
  upper = hashes.length -1;
  while (lower <= upper)
  {
    index = (lower + upper) / 2;
    if (hash < hashes[index])
      upper = index - 1;
    else if (hash > hashes[index])
      lower = index + 1;
    else
      return values[index]; // Return the Unicode codepoint.
  }
  return 0xFFFF; // Return error value.
}

unittest
{
  Stdout("Testing entity2Unicode().").newline;
  alias entity2Unicode f;
  foreach (entity; namedEntities)
    assert(f(entity.name) == entity.value,
      Format("'&{};' == \\u{:X4}, not \\u{:X4}",
             entity.name, entity.value, cast(uint)f(entity.name))
    );
}

/++
  Author: Aziz Köksal
  License: GPL3
+/
module dil.Settings;
import dil.Messages;
import dil.Parser, dil.SyntaxTree, dil.Declarations, dil.Expressions;
import std.metastrings;

version(D2)
{
  const VERSION_MAJOR = 2;
  const VERSION_MINOR = 0;
}
else
{
  const VERSION_MAJOR = 1;
  const VERSION_MINOR = 0;
}

template Pad(char[] str, uint amount)
{
  static if (str.length >= amount)
    const char[] Pad = str;
  else
    const char[] Pad = "0" ~ Pad!(str, amount-1);
}

template Pad(int num, uint amount)
{
  const char[] Pad = Pad!(ToString!(num), amount);
}

const string VERSION = Format!("%s.%s", VERSION_MAJOR, Pad!(VERSION_MINOR, 3));

const COMPILED_WITH = __VENDOR__;
const COMPILED_VERSION = Format!("%s.%s", __VERSION__/1000, Pad!(__VERSION__%1000, 3));
const COMPILED_DATE = __TIMESTAMP__;

const usageGenerate = "generate (gen)";

struct GlobalSettings
{
static:
  string language; /// Language of messages catalogue to load.
  string[] messages; /// Table of localized compiler messages.
  void load()
  {
    auto fileName = "config.d"[];
    auto sourceText = cast(char[]) std.file.read(fileName);
    auto parser = new Parser(sourceText, fileName);
    parser.start();
    auto root = parser.parseModule();

    if (parser.errors.length || parser.lx.errors.length)
    {
      throw new Exception("There are errors in " ~ fileName ~ ".");
    }

    foreach (decl; root.children)
    {
      auto v = Cast!(VariableDeclaration)(decl);
      if (v && v.idents[0].srcText == "language")
      {
        auto e = v.values[0];
        if (!e)
          throw new Exception("language variable has no value set.");
        auto val = Cast!(StringLiteralsExpression)(e);
        if (val)
        {
          GlobalSettings.language = val.getString();
          break;
        }
      }
    }

    // Load messages
    if (GlobalSettings.language.length)
    {
      fileName = "lang_" ~ GlobalSettings.language ~ ".d";
      sourceText = cast(char[]) std.file.read(fileName);
      parser = new Parser(sourceText, fileName);
      parser.start();
      root = parser.parseModule();

      if (parser.errors.length || parser.lx.errors.length)
      {
        throw new Exception("There are errors in "~fileName~".");
      }

      char[][] messages;
      foreach (decl; root.children)
      {
        auto v = Cast!(VariableDeclaration)(decl);
        if (v && v.idents[0].srcText == "messages")
        {
          auto e = v.values[0];
          if (!e)
            throw new Exception("messages variable in "~fileName~" has no value set.");
          if (auto array = Cast!(ArrayInitializer)(e))
          {
            foreach (value; array.values)
            {
              if (auto str = Cast!(StringLiteralsExpression)(value))
                messages ~= str.getString();
            }
          }
          else
            throw new Exception("messages variable is set to "~e.classinfo.name~" instead of an ArrayInitializer.");
        }
      }
      if (messages.length != MID.max+1)
        throw new Exception(std.string.format("messages table in %s must exactly have %d entries, but %s were found.", fileName, MID.max+1, messages.length));
      GlobalSettings.messages = messages;
    }
  }

}

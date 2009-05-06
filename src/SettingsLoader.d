/// Author: Aziz Köksal
/// License: GPL3
/// $(Maturity average)
module SettingsLoader;

import dil.ast.Node,
       dil.ast.Declarations,
       dil.ast.Expressions;
import dil.semantic.Module,
       dil.semantic.Pass1,
       dil.semantic.Symbol,
       dil.semantic.Symbols;
import dil.Messages;
import dil.Diagnostics;
import dil.Compilation;
import dil.Unicode;
import Settings;
import common;

import tango.io.FilePath;
import tango.sys.Environment;
import tango.util.PathUtil : normalize;

/// Loads settings from a D module file.
abstract class SettingsLoader
{
  Diagnostics diag; /// Collects error messages.
  Module mod; /// Current module.

  /// Constructs a SettingsLoader object.
  this(Diagnostics diag)
  {
    this.diag = diag;
  }

  /// Creates an error report.
  /// Params:
  ///   token = where the error occurred.
  ///   formatMsg = error message.
  void error(Token* token, char[] formatMsg, ...)
  {
    auto location = token.getErrorLocation();
    auto msg = Format(_arguments, _argptr, formatMsg);
    diag ~= new SemanticError(location, msg);
  }

  T getValue(T)(char[] name)
  {
    auto var = mod.lookup(name);
    if (!var) // Returning T.init instead of null, because dmd gives an error.
      return error(mod.firstToken, "variable '{}' is not defined", name), T.init;
    auto t = var.node.begin;
    if (!var.isVariable)
      return error(t, "'{}' is not a variable declaration", name), T.init;
    auto value = var.to!(Variable).value;
    if (!value)
      return error(t, "'{}' variable has no value set", name), T.init;
    T val = value.Is!(T); // Try casting to T.
    if (!val)
      error(value.begin, "the value of '{}' must be of type {}", name, T.stringof);
    return val;
  }

  T castTo(T)(Node n)
  {
    if (auto result = n.Is!(T))
      return result;
    char[] type = T.stringof;
    (is(T == StringExpression) && (type = "char[]").ptr) ||
    (is(T == ArrayInitExpression) && (type = "[]").ptr) ||
    (is(T == IntExpression) && (type = "int"));
    error(n.begin, "expression is not of type {}", type);
    return null;
  }

  void load()
  {}
}

/// Loads the configuration file of dil.
class ConfigLoader : SettingsLoader
{
  static string configFileName = "dilconf.d"; /// Name of the configuration file.
  string executablePath; /// Absolute path to dil's executable.
  string executableDir; /// Absolute path to the directory of dil's executable.
  string dataDir; /// Absolute path to dil's data directory.
  string homePath; /// Path to the home directory.

  /// Constructs a ConfigLoader object.
  this(Diagnostics diag)
  {
    super(diag);
    this.homePath = Environment.get("HOME");
    this.executablePath = GetExecutableFilePath();
    this.executableDir = (new FilePath(this.executablePath)).path();
    Environment.set("BINDIR", this.executableDir);
  }

  static ConfigLoader opCall(Diagnostics diag)
  {
    return new ConfigLoader(diag);
  }

  /// Expands environment variables such as ${HOME} in a string.
  static string expandVariables(string val)
  {
    char[] makeString(char* begin, char* end)
    {
      assert(begin && end && begin <= end);
      return begin[0 .. end - begin];
    }

    char[] result;
    char* p = val.ptr, end = p + val.length;
    char* pieceBegin = p; // Points to the piece of the string after a variable.

    while (p+3 < end)
    {
      if (p[0] == '$' && p[1] == '{')
      {
        auto variableBegin = p;
        while (p < end && *p != '}')
          p++;
        if (p == end)
          break; // Don't expand unterminated variables.
        result ~= makeString(pieceBegin, variableBegin);
        variableBegin += 2; // Skip ${
        // Get the environment variable and append it to the result.
        result ~= Environment.get(makeString(variableBegin, p));
        pieceBegin = p + 1; // Point to character after '}'.
      }
      p++;
    }
    if (pieceBegin < end)
      result ~= makeString(pieceBegin, end);
    return result;
  }

  /// Loads the configuration file.
  void load()
  {
    // Search for the configuration file.
    auto filePath = findConfigurationFilePath();
    if (filePath is null)
    {
      diag ~= new Error(new Location("",0),
        "the configuration file "~configFileName~" could not be found.");
      return;
    }
    // Load the file as a D module.
    mod = new Module(filePath, diag);
    mod.parse();

    if (mod.hasErrors)
      return;

    auto context = new CompilationContext;
    auto pass1 = new SemanticPass1(mod, context);
    pass1.run();

    // Initialize the dataDir member.
    if (auto val = getValue!(StringExpression)("DATADIR"))
      this.dataDir = val.getString();
    this.dataDir = normalize(expandVariables(this.dataDir));
    GlobalSettings.dataDir = this.dataDir;
    Environment.set("DATADIR", this.dataDir);

    if (auto array = getValue!(ArrayInitExpression)("VERSION_IDS"))
      foreach (value; array.values)
        if (auto val = castTo!(StringExpression)(value))
          GlobalSettings.versionIds ~= expandVariables(val.getString());
    if (auto val = getValue!(StringExpression)("LANG_FILE"))
      GlobalSettings.langFile = normalize(expandVariables(val.getString()));
    if (auto array = getValue!(ArrayInitExpression)("IMPORT_PATHS"))
      foreach (value; array.values)
        if (auto val = castTo!(StringExpression)(value))
          GlobalSettings.importPaths ~=
            normalize(expandVariables(val.getString()));
    if (auto array = getValue!(ArrayInitExpression)("DDOC_FILES"))
      foreach (value; array.values)
        if (auto val = castTo!(StringExpression)(value))
          GlobalSettings.ddocFilePaths ~=
            normalize(expandVariables(val.getString()));
    if (auto val = getValue!(StringExpression)("XML_MAP"))
      GlobalSettings.xmlMapFile = normalize(expandVariables(val.getString()));
    if (auto val = getValue!(StringExpression)("HTML_MAP"))
      GlobalSettings.htmlMapFile = normalize(expandVariables(val.getString()));
    if (auto val = getValue!(StringExpression)("LEXER_ERROR"))
      GlobalSettings.lexerErrorFormat = expandVariables(val.getString());
    if (auto val = getValue!(StringExpression)("PARSER_ERROR"))
      GlobalSettings.parserErrorFormat = expandVariables(val.getString());
    if (auto val = getValue!(StringExpression)("SEMANTIC_ERROR"))
      GlobalSettings.semanticErrorFormat = expandVariables(val.getString());
    if (auto val = getValue!(IntExpression)("TAB_WIDTH"))
    {
      GlobalSettings.tabWidth = cast(uint)val.number;
      Location.TAB_WIDTH = cast(uint)val.number;
    }


    // Load language file.
    // TODO: create a separate class for this?
    filePath = expandVariables(GlobalSettings.langFile);
    mod = new Module(filePath, diag);
    mod.parse();

    if (mod.hasErrors)
      return;

    pass1 = new SemanticPass1(mod, context);
    pass1.run();

    if (auto array = getValue!(ArrayInitExpression)("messages"))
    {
      char[][] messages;
      foreach (value; array.values)
        if (auto val = castTo!(StringExpression)(value))
          messages ~= val.getString();
      if (messages.length != MID.max+1)
        error(mod.firstToken,
              "messages table in {} must exactly have {} entries, but not {}.",
              filePath, MID.max+1, messages.length);
      GlobalSettings.messages = messages;
      dil.Messages.SetMessages(messages);
    }
    if (auto val = getValue!(StringExpression)("lang_code"))
      GlobalSettings.langCode = val.getString();
  }

  /// Searches for the configuration file of dil.
  /// Returns: the filePath or null if the file couldn't be found.
  string findConfigurationFilePath()
  {
    // 1. Look in environment variable DILCONF.
    auto filePath = new FilePath(Environment.get("DILCONF"));
    if (filePath.exists())
      return filePath.toString();
    // 2. Look in the current working directory.
    filePath.set(this.configFileName);
    if (filePath.exists())
      return filePath.toString();
    // 3. Look in the directory set by HOME.
    filePath.set(this.homePath);
    filePath.append(this.configFileName);
    if (filePath.exists())
      return filePath.toString();
    // 4. Look in the binary's directory.
    filePath.set(this.executableDir);
    filePath.append(this.configFileName);
    if (filePath.exists())
      return filePath.toString();
    return null;
  }
}

/// Loads an associative array from a D module file.
class TagMapLoader : SettingsLoader
{
  /// Constructs a TagMapLoader object.
  this(Diagnostics diag)
  {
    super(diag);
  }

  static TagMapLoader opCall(Diagnostics diag)
  {
    return new TagMapLoader(diag);
  }

  string[string] load(string filePath)
  {
    mod = new Module(filePath, diag);
    mod.parse();
    if (mod.hasErrors)
      return null;

    auto context = new CompilationContext;
    auto pass1 = new SemanticPass1(mod, context);
    pass1.run();

    string[string] map;
    if (auto array = getValue!(ArrayInitExpression)("map"))
      foreach (i, value; array.values)
      {
        auto key = array.keys[i];
        if (auto valExp = castTo!(StringExpression)(value))
          if (!key)
            error(value.begin, "expected key : value");
          else if (auto keyExp = castTo!(StringExpression)(key))
            map[keyExp.getString()] = valExp.getString();
      }
    return map;
  }
}

/// Resolves the path to a file from the executable's dir path
/// if it is relative.
/// Returns: filePath if it is absolute or execPath + filePath.
string resolvePath(string execPath, string filePath)
{
  scope path = new FilePath(filePath);
  if (path.isAbsolute())
    return filePath;
  path.set(execPath).append(filePath);
  return path.toString();
}

extern(Windows) uint GetModuleFileNameW(void*, wchar*, uint);
extern(C) size_t readlink(char* path, char* buf, size_t bufsize);

/// Returns the fully qualified path to this executable.
char[] GetExecutableFilePath()
{
  version(Windows)
  {
  wchar[] buffer = new wchar[256];
  uint count;

  while (1)
  {
    count = GetModuleFileNameW(null, buffer.ptr, buffer.length);
    if (count == 0)
      return null;
    if (buffer.length != count && buffer[count] == 0)
      break;
    // Increase size of buffer
    buffer.length = buffer.length * 2;
  }
  assert(buffer[count] == 0);
  // Reduce buffer to the actual length of the string (excluding '\0'.)
  buffer.length = count;
  return toUTF8(buffer);
  } // version(Windows)
  else version(linux)
  {
  char[] buffer = new char[256];
  size_t count;

  while (1)
  {
    // This won't work on very old Linux systems.
    count = readlink("/proc/self/exe".ptr, buffer.ptr, buffer.length);
    if (count == -1)
      return null;
    if (count < buffer.length)
      break;
    buffer.length = buffer.length * 2;
  }
  buffer.length = count;
  return buffer;
  } // version(linux)
  else
  {
  static assert(0,
    "GetExecutableFilePath() is not implemented on this platform.");
  return "";
  }
}

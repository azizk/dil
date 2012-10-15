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
import dil.lexer.Funcs,
       dil.lexer.Identifier;
import dil.i18n.Messages,
       dil.i18n.ResourceBundle;
import dil.Diagnostics,
       dil.Compilation,
       dil.Unicode,
       dil.String;
import util.Path;
import Settings,
       common;

import tango.sys.Environment;
import tango.io.Path : normalize;

/// Loads settings from a D module file.
abstract class SettingsLoader
{
  Diagnostics diag; /// Collects error messages.
  Module mod; /// Current module.
  CompilationContext cc; /// The context.

  /// Constructs a SettingsLoader object.
  this(CompilationContext cc, Diagnostics diag)
  {
    this.cc = cc;
    this.diag = diag;
  }

  /// Creates an error report.
  /// Params:
  ///   token = Where the error occurred.
  ///   formatMsg = Error message.
  void error(Token* token, cstring formatMsg, ...)
  {
    auto location = token.getErrorLocation(mod.filePath);
    auto msg = Format(_arguments, _argptr, formatMsg);
    diag ~= new SemanticError(location, msg);
  }

  T getValue(T)(cstring name, bool isOptional = false)
  {
    auto var = mod.lookup(hashOf(name));
    T value;
    if (!var && isOptional)
    {}
    else if (!var)
      error(mod.firstToken, "variable ‘{}’ is not defined", name);
    else if (!var.isVariable)
      error(var.node.begin, "‘{}’ is not a variable declaration", name);
    else if (auto e = var.to!(VariableSymbol).value)
    {
      if ((value = e.Is!(T)) is null) // Try casting to T.
        error(e.begin,
          "the value of ‘{}’ must be of type ‘{}’", name, T.stringof);
    }
    else
      error(var.node.begin, "‘{}’ variable has no value set", name);
    return value;
  }

  T castTo(T)(Node n)
  {
    if (auto result = n.Is!(T))
      return result;
    auto type = T.stringof;
    if (is(T == StringExpr))
      type = "char[]";
    else if (is(T == ArrayInitExpr))
      type = "[]";
    else if(is(T == IntExpr))
      type = "int";
    error(n.begin, "expression is not of type ‘{}’", type);
    return null;
  }

  void load()
  {}
}

/// Loads the configuration file of DIL.
class ConfigLoader : SettingsLoader
{
  /// Name of the configuration file.
  static cstring configFileName = "dilconf.d";
  cstring executablePath; /// Absolute path to DIL's executable.
  cstring executableDir; /// Absolute path to the directory of DIL's executable.
  cstring dataDir; /// Absolute path to DIL's data directory.
  cstring homePath; /// Path to the home directory.
  cstring dilconfPath; /// Path to dilconf.d to be used.

  ResourceBundle resourceBundle; /// A bundle for compiler messages.

  /// Constructs a ConfigLoader object.
  this(CompilationContext cc, Diagnostics diag, cstring arg0)
  {
    super(cc, diag);
    this.homePath = Environment.get("HOME");
    this.executablePath = GetExecutableFilePath(arg0);
    this.executableDir = Path(this.executablePath).path();
    Environment.set("BINDIR", this.executableDir);
  }

  static ConfigLoader opCall(CompilationContext cc, Diagnostics diag,
    cstring arg0)
  {
    return new ConfigLoader(cc, diag, arg0);
  }

  /// Expands environment variables such as ${HOME} in a string.
  static cstring expandVariables(cstring str)
  {
    char[] result;
    const s = String(str);
    cchar* p = s.ptr, end = s.end;
    auto pieceBegin = p; // Points past the closing brace '}' of a variable.

    while (p+3 < end)
    {
      auto variableBegin = String(p, end).findp(String("${"));
      if (!variableBegin)
        break;
      auto variableEnd = String(variableBegin + 2, end).findp('}');
      if (!variableEnd)
        break; // Don't expand unterminated variables.
      result ~= slice(pieceBegin, variableBegin); // Copy previous string.
      // Get the environment variable and append it to the result.
      result ~= Environment.get(slice(variableBegin + 2, variableEnd));
      pieceBegin = p = variableEnd + 1; // Point to character after '}'.
    }
    if (pieceBegin is s.ptr)
      return str; // Return unchanged string.
    if (pieceBegin < end) // Copy end piece.
      result ~= slice(pieceBegin, end);
    return result;
  }

  /// Loads the configuration file.
  void load()
  {
    // Search for the configuration file.
    dilconfPath = findConfigurationFilePath();
    if (dilconfPath is null)
    {
      diag ~= new GeneralError(new Location("",0),
        "the configuration file ‘"~configFileName~"’ could not be found.");
      return;
    }
    // Load the file as a D module.
    mod = new Module(dilconfPath, cc);
    mod.parse();

    if (mod.hasErrors)
      return;

    auto pass1 = new SemanticPass1(mod, cc);
    pass1.run();

    // Initialize the dataDir member.
    if (auto val = getValue!(StringExpr)("DATADIR"))
      this.dataDir = val.getString();
    this.dataDir = normalize(expandVariables(this.dataDir));
    GlobalSettings.dataDir = this.dataDir;
    Environment.set("DATADIR", this.dataDir);

    if (auto val = getValue!(StringExpr)("KANDILDIR"))
    {
      auto kandilDir = normalize(expandVariables(val.getString()));
      GlobalSettings.kandilDir = kandilDir;
      Environment.set("KANDILDIR", kandilDir);
    }

    if (auto array = getValue!(ArrayInitExpr)("VERSION_IDS"))
      foreach (value; array.values)
        if (auto val = castTo!(StringExpr)(value))
          GlobalSettings.versionIds ~= expandVariables(val.getString());
    if (auto val = getValue!(StringExpr)("LANG_FILE"))
      GlobalSettings.langFile = normalize(expandVariables(val.getString()));
    if (auto array = getValue!(ArrayInitExpr)("IMPORT_PATHS"))
      foreach (value; array.values)
        if (auto val = castTo!(StringExpr)(value))
          GlobalSettings.importPaths ~=
            normalize(expandVariables(val.getString()));
    if (auto array = getValue!(ArrayInitExpr)("DDOC_FILES"))
      foreach (value; array.values)
        if (auto val = castTo!(StringExpr)(value))
          GlobalSettings.ddocFilePaths ~=
            normalize(expandVariables(val.getString()));
    if (auto val = getValue!(StringExpr)("XML_MAP"))
      GlobalSettings.xmlMapFile = normalize(expandVariables(val.getString()));
    if (auto val = getValue!(StringExpr)("HTML_MAP"))
      GlobalSettings.htmlMapFile = normalize(expandVariables(val.getString()));
    if (auto val = getValue!(StringExpr)("LEXER_ERROR"))
      GlobalSettings.lexerErrorFormat = expandVariables(val.getString());
    if (auto val = getValue!(StringExpr)("PARSER_ERROR"))
      GlobalSettings.parserErrorFormat = expandVariables(val.getString());
    if (auto val = getValue!(StringExpr)("SEMANTIC_ERROR"))
      GlobalSettings.semanticErrorFormat = expandVariables(val.getString());
    if (auto val = getValue!(IntExpr)("TAB_WIDTH"))
    {
      GlobalSettings.tabWidth = cast(uint)val.number;
      Location.TAB_WIDTH = cast(uint)val.number;
    }

    auto langFile = expandVariables(GlobalSettings.langFile);
    resourceBundle = loadResource(langFile);
  }

  /// Loads a language file and returns a ResouceBundle object.
  ResourceBundle loadResource(cstring langFile)
  {
    if (!Path(langFile).exists)
    {
      diag ~= new GeneralError(new Location("", 0),
        "the language file ‘"~langFile~"’ does not exist.");
      goto Lerr;
    }

    // 1. Load language file.
    mod = new Module(langFile, cc);
    mod.parse();

    if (mod.hasErrors)
      goto Lerr;

    auto pass1 = new SemanticPass1(mod, cc);
    pass1.run();

    // 2. Extract the values of the variables.
    cstring[] messages = new cstring[MID.max + 1];
    if (auto array = getValue!(ArrayInitExpr)("messages"))
    {
      foreach (i, value; array.values)
        if (i >= messages.length)
          break; // More messages given than allowed.
        else if (value.Is!(NullExpr))
        {} // messages[i] = null;
        else if (auto val = castTo!(StringExpr)(value))
          messages[i] = val.getString();
      //if (messages.length != MID.max+1)
        //error(mod.firstToken,
          //"messages table in {} must exactly have {} entries, but not {}.",
          //langFile, MID.max+1, messages.length);
    }
    cstring langCode;
    if (auto val = getValue!(StringExpr)("lang_code"))
      langCode = val.getString();
    cstring parentLangFile;
    if (auto val = getValue!(StringExpr)("inherit", true))
      parentLangFile = expandVariables(val.getString());

    // 3. Load the parent bundle if one is specified.
    auto parentRB = parentLangFile ? loadResource(parentLangFile) : null;

    // 4. Return a new bundle.
    auto rb =  new ResourceBundle(messages, parentRB);
    rb.langCode = langCode;

    return rb;
  Lerr:
    return new ResourceBundle();
  }

  /// Searches for the configuration file of DIL.
  /// Returns: the filePath or null if the file couldn't be found.
  cstring findConfigurationFilePath()
  {
    auto path = Path();
    bool exists(cstring s)
    {
      return path.set(s).exists;
    }
        // 1. Look in environment variable DILCONF.
    if (exists(Environment.get("DILCONF")) ||
        // 2. Look in the current working directory.
        exists(configFileName) ||
        // 3. Look in the directory set by HOME.
        exists(homePath~"/"~configFileName) ||
        // 4. Look in the binary's directory.
        exists(executableDir~"/"~configFileName) ||
        // 5. Look in /etc/.
        exists("/etc/"~configFileName))
      return normalize(path.toString());
    else
      return null;
  }
}

/// Loads an associative array from a D module file.
class TagMapLoader : SettingsLoader
{
  /// Constructs a TagMapLoader object.
  this(CompilationContext cc, Diagnostics diag)
  {
    super(cc, diag);
  }

  static TagMapLoader opCall(CompilationContext cc, Diagnostics diag)
  {
    return new TagMapLoader(cc, diag);
  }

  cstring[hash_t] load(cstring filePath)
  {
    mod = new Module(filePath, cc);
    mod.parse();
    if (mod.hasErrors)
      return null;

    auto pass1 = new SemanticPass1(mod, cc);
    pass1.run();

    cstring[hash_t] map;
    if (auto array = getValue!(ArrayInitExpr)("map"))
      foreach (i, value; array.values)
      {
        auto key = array.keys[i];
        if (auto valExp = castTo!(StringExpr)(value))
          if (!key)
            error(value.begin, "expected key : value");
          else if (auto keyExp = castTo!(StringExpr)(key))
            map[hashOf(keyExp.getString())] = valExp.getString();
      }
    return map;
  }
}

/// Resolves the path to a file from the executable's dir path
/// if it is relative.
/// Returns: filePath if it is absolute or execPath + filePath.
cstring resolvePath(cstring execPath, cstring filePath)
{
  scope path = Path(filePath);
  if (path.isAbsolute())
    return filePath;
  path.set(execPath).append(filePath);
  return path.toString();
}

extern(Windows) uint GetModuleFileNameW(void*, wchar*, uint);
extern(C) size_t readlink(char* path, char* buf, size_t bufsize);
extern(C) char* realpath(char* base, char* dest);
extern(C) int _NSGetExecutablePath(char* buf, uint* bufsize);

/// Returns the fully qualified path to this executable,
/// or arg0 on failure or when a platform is unsupported.
/// Params:
///   arg0 = This is argv[0] from main(cstring[] argv).
cstring GetExecutableFilePath(cstring arg0)
{
  version(Windows)
  {
  wchar[] buffer = new wchar[256];
  size_t count;

  while (1)
  {
    count = GetModuleFileNameW(null, buffer.ptr, buffer.length);
    if (count == 0)
      return arg0;
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
  { // This won't work on very old Linux systems.
    count = readlink("/proc/self/exe".dup.ptr, buffer.ptr, buffer.length);
    if (count == -1)
      return arg0;
    if (count < buffer.length)
      break;
    buffer.length = buffer.length * 2;
  }
  buffer.length = count;
  return buffer;
  } // version(linux)

  else version(darwin)
  {
  // First, get the executable path.
  uint size = 256;
  char[] path = new char[size];
  while (_NSGetExecutablePath(path.ptr, &size) == -1)
    path = new char[size];

  // Then, convert it to the »real path«, resolving symlinks, etc.
  char[] buffer = new char[1024];  // 1024 = PATH_MAX on Mac OS X 10.5
  if (!realpath(path.ptr, buffer.ptr))
    return arg0;
  return String(buffer.ptr, 0).array;
  } // version(darwin)

  else
  {
  pragma(msg, "Warning: GetExecutableFilePath() is not implemented on this platform.");
  return arg0;
  }
}

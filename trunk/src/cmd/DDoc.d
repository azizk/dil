/++
  Author: Aziz Köksal
  License: GPL3
+/
module cmd.DDoc;

import dil.doc.Parser;
import dil.doc.Macro;
import dil.doc.Doc;
import dil.ast.DefaultVisitor;
import dil.semantic.Module;
import dil.semantic.Pass1;
import dil.semantic.Symbol;
import dil.semantic.Symbols;
import dil.Information;
import dil.File;
import common;

import tango.stdc.time : time_t, time, ctime;
import tango.stdc.string : strlen;

void execute(string[] filePaths, string destDir, string[] macroPaths,
             bool incUndoc, InfoManager infoMan)
{
  // Parse macro files.
  MacroTable mtable;
  MacroParser mparser;
  foreach (macroPath; macroPaths)
  {
    auto macros = mparser.parse(loadFile(macroPath));
    mtable = new MacroTable(mtable);
    mtable.insert(macros);
  }

//   foreach (k, v; mtable.table)
//     Stdout(k)("=")(v.text);

  Module[] modules;
  foreach (filePath; filePaths)
  {
    auto mod = new Module(filePath, infoMan);
    modules ~= mod;
    // Parse the file.
    mod.parse();
    if (mod.hasErrors)
      continue;

    // Start semantic analysis.
    auto pass1 = new SemanticPass1(mod);
    pass1.start();
  }

  foreach (mod; modules)
    generateDocumentation(mod, mtable);
}

void generateDocumentation(Module mod, MacroTable mtable)
{
  // Create a macro environment for this module.
  mtable = new MacroTable(mtable);
  // Define runtime macros.
  mtable.insert(new Macro("TITLE", mod.getFQN()));
  mtable.insert(new Macro("DOCFILENAME", mod.getFQN()));

  time_t time_val;
  time(&time_val);
  char* str = ctime(&time_val);
  char[] time_str = str[0 .. strlen(str)];
  mtable.insert(new Macro("DATETIME", time_str.dup));
  mtable.insert(new Macro("YEAR", time_str[20..24].dup));

  if (mod.moduleDecl)
  {
    auto ddocComment = getDDocComment(mod.moduleDecl);
    if (auto copyright = ddocComment.getCopyright())
      mtable.insert(new Macro("COPYRIGHT", copyright.text));
  }

  auto docEmitter = new DDocEmitter();
  docEmitter.emit(mod);

  mtable.insert(new Macro("BODY", docEmitter.text));
  expandMacros(mtable, "$(DDOC)");
}

class DDocEmitter : DefaultVisitor
{
  char[] text;

  char[] emit(Module mod)
  {
    return text;
  }
}

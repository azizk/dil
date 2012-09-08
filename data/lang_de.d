/++
  Author: Aziz Köksal
  License: GPL3
+/

string lang_code = "de";

string[] messages = [
  // Lexer messages:
  "illegales Zeichen gefunden: '{0}'",
//   "ungültiges Unicodezeichen.",
  "ungültige UTF-8-Sequenz: '{0}'",
  // ''
  "ungeschlossenes Zeichenliteral",
  "leeres Zeichenliteral.",
  // #line
  "erwartete 'line' nach '#'.",
  "Ganzzahl nach #line erwartet.",
//   `erwartete Dateispezifikation (z.B. "pfad\zur\datei".)`,
  "ungeschlossene Dateispezifikation (filespec)",
  "ein Special Token muss mit einem Zeilenumbruch abgeschlossen werden.",
  // ""
  "ungeschlossene Zeichenkette",
  // x""
  "Nicht-Hexzeichen '{0}' in Hexzeichenkette gefunden.",
  "ungerade Anzahl von Hexziffern in Hexzeichenkette.",
  "ungeschlossene Hexzeichenkette",
  // /* */ /+ +/
  "ungeschlossener Blockkommentar (/* */)",
  "ungeschlossener verschachtelter Kommentar (/+ +/)",
  // `` r""
  "ungeschlossene rohe Zeichenkette.",
  "ungeschlossene Backquote-Zeichenkette.",
  // \x \u \U
  "undefinierte Escapesequenz '{0}' gefunden.",
  "ungültige Unicode-Escapesequenz '{0}' gefunden.",
  "unzureichende Anzahl von Hexziffern in Escapesequenz: '{0}'",
  // \&[a-zA-Z][a-zA-Z0-9]+;
  "undefinierte HTML-Entität ‚{0}‘",
  "ungeschlossene HTML-Entität ‚{0}‘",
  "HTML-Entitäten müssen mit einem Buchstaben beginnen.",
  // integer overflows
  "Dezimalzahl überläuft im Vorzeichenbit.",
  "Überlauf in Dezimalzahl.",
  "Überlauf in Hexadezimalzahl.",
  "Überlauf in Binärzahl.",
  "Überlauf in Oktalzahl.",
  "Überlauf in Fließkommazahl.",
  "die Ziffern 8 und 9 sind in Oktalzahlen unzulässig.",
  "Oktalzahlen sind seit D2 nicht mehr erlaubt",
  "ungültige Hexzahl; mindestens eine Hexziffer erforderlich.",
  "ungültige Binärzahl; mindestens eine Binärziffer erforderlich.",
  "der Exponent einer hexadezimalen Fließkommazahl ist erforderlich.",
  "Hexadezimal-Exponenten müssen mit einer Dezimalziffer anfangen.",
  "Exponenten müssen mit einer Dezimalziffer anfangen.",
  "die Moduldatei konnte nicht gelesen werden",
  "die Moduldatei existiert nicht",
  "die Oktalzahl ist größer als 0xFF: ‘{}’",
  "der Dateiname ‘{}’ kann nicht als Modulname benutzt werden; es ist ein ungültiger oder reservierter D-Bezeichner",
  "das Trennzeichen darf kein Leerzeichen sein",
  "erwartete ein Trennzeichen oder einen Bezeichner nach ‘q\"’",
  "erwartete eine neue Zeile nach dem Trennbezeichner ‘{}’",
  "ungeschlossene abgegrenzte Zeichenkette",
  "erwartete ‘\"’ nach dem Trenner ‘{}’",
  "ungeschlossene Tokenzeichenkette",

  // Parser messages:
  "erwartete ‚{0}‘, fand aber ‚{1}‘",
  "‚{0}‘ ist redundant",
  "Template-Tupel-Parameter dürfen nur am Ende auftreten",
  "der ‚in’-Vertrag der Funktion wurde bereits geparst",
  "der ‚out’-Vertrag der Funktion wurde bereits geparst",
  "es wurde kein Anbindungstyp angegeben",
  "unbekannter Anbindungstyp ‚{0}‘ (gültig sind: ‚C‘, ‚C++‘, ‚D‘, ‚Windows‘, ‚Pascal‘, ‚System‘)",
  "erwartete eine oder mehrere Basisklassen, nicht ‚{0}‘",
  "Basisklassen sind in Vorwärtsdeklarationen nicht erlaubt",

  "ungültige UTF-8-Sequenz in Zeichenkette: ‚{}‘",
  "eine Moduldeklaration ist nur als allererste Deklaration in einer Datei erlaubt",
  "die Postfix-Zeichen in den Zeichenketten passen nicht zusammen",
  "der Bezeichner ‚{}‘ ist in einem Typ nicht erlaubt",
  "erwartete Bezeichner nach ‚(Typ).‘, nicht ‚{}‘",
  "erwartete Modulbezeichner, nicht ‚{}‘",
  "ungültige Deklaration gefunden: „{}“",
  "erwartete ‚system‘ oder ‚safe‘, nicht ‚{}‘",
  "erwartete Funktionsnamen, nicht ‚{}‘",
  "erwartete Variablenname, nicht ‚{}‘",
  "erwartete Funktionskörper, nicht ‚{}‘",
  "redundanter Anbindungstyp: ‚{}‘",
  "redundantes Zugriffsattribut: ‚{}‘",
  "erwartete einen Pragma-Bezeichner, nicht ‚{}‘",
  "erwartete einen Alias-Modulnamen, nicht ‚{}‘",
  "erwartete einen Aliasnamen, nicht ‚{}‘",
  "erwartete einen Bezeichner, nicht ‚{}‘",
  "erwartete ein Enummitglied, nicht ‚{}‘",
  "erwartete einen Enumkörper, nicht ‚{}‘",
  "erwartete einen Klassennamen, nicht ‚{}‘",
  "erwartete einen Klassenkörper, nicht ‚{}‘",
  "erwartete einen Interfacenamen, nicht ‚{}‘",
  "erwartete einen Interfacekörper, nicht ‚{}‘",
  "erwartete einen Structkörper, nicht ‚{}‘",
  "erwartete einen Unionkörper, nicht ‚{}‘",
  "erwartete Unittest-Körper, nicht ‚{}‘",
  "erwartete einen Templatenamen, nicht ‚{}‘",
  "erwartete einen Bezeichner, nicht ‚{}‘",
  "ungültige Anweisung gefunden: „{}“",
  "erwartete nicht ‚;‘, verwende ‚{{ }‘ stattdessen",
  "erwartete ‚exit‘, ‚success‘ oder ‚failure‘, nicht ‚{}‘",
  "‚{}‘ ist kein gültiger Scopebezeichner (gültig sind: ‚exit‘, ‚success‘, ‚failure‘)",
  "erwartete ‚C‘, ‚C++‘, ‚D‘, ‚Windows‘, ‚Pascal‘ oder ‚System‘, aber nicht ‚{}‘",
  "erwartete einen Bezeichner nach ‚@‘",
  "unbekanntes Attribut: ‚@{}‘",
  "erwartete eine Ganzzahl nach align, nicht ‚{}‘",
  "ungültige Asm-Anweisung gefunden: „{}“",
  "ungültiger binärer Operator ‘{}’ in Asm-Anweisung",
  "erwartete einen Bezeichner für die Deklaration, nicht ‚{}‘",
  "erwartete einen oder mehrere Templateparameter, nicht ‚)‘",
  "erwartete einen Typ oder einen Ausdruck, nicht ‚)‘",
  "erwartete einen Namen für den Alias-Templateparameter, nicht ‚{}‘",
  "erwartete einen Namen für den ‚this‘-Templateparameter, nicht ‚{}‘",
  "erwartete einen Bezeichner oder eine Ganzzahl, nicht ‚{}‘",
  "der ‚try‘-Anweisung fehlt eine ‚catch‘- oder ‚finally‘-Anweisung",
  "erwartete schließende Klammer ‚{}‘ (‚{}‘ @{},{}), nicht ‚{}‘",
  "Initialisierer sind für ‚alias‘-Deklarationen nicht erlaubt",
  "erwartete eine Variablendeklaration in alias, nicht ‚{}‘",
  "erwartete eine Variablendeklaration in typedef, nicht ‚{}‘",
  "nur ein Ausdruck ist für den Start einer Case-Range-Anweisung erlaubt",
  "erwartete einen Standardwert für den Parameter ‚{}‘",
  "variadischer Parameter darf nicht ‚ref‘ oder ‚out‘ sein",
  "weitere Parameter nach einem variadischen Parameter sind nicht erlaubt",
  "Vergleichsoperatoren können nicht verkettet werden, w.z.B. a == b == c",

  // Semantic analysis:
  "das Modul ‚{}‘ konnte nicht gefunden werden",
  "das Modul steht im Konflikt mit dem Modul ‚{}‘",
  "das Modul steht im Konflikt mit dem Paket ‚{}‘",
  "das Paket ‚{0}‘ steht im Konflikt mit dem Modul ‚{0}‘",
  "das Modul sollte im Paket ‚{}‘ sein",
  "undefinierter Bezeichner ‚{}‘",
  "die Deklaration ‚{}‘ ist in Konflikt mit der Deklaration @{}",
  "die Variable ‚{}‘ ist in Konflikt mit der Deklaration @{}",
  "ein Interface darf keine Mitgliedsvariablen haben",
  "das Mixin-Argument muss zu einem String evaluieren",
  "debug={} muss auf der Modulebene stehen",
  "version={} muss auf der Modulebene stehen",

  "ungültige UTF-16-Sequenz \\u{:X4}\\u{:X4}",
  "fehlendes niedriges Surrogatzeichen in UTF-16-Sequenz \\u{:X4}\\uXXXX",
  "fehlendes hohes Surrogatzeichen in UTF-16-Sequenz \\uXXXX\\u{:X4}",
  "ungültiges Template-Argument ‘{}’",

  // Converter:
  "ungültiges UTF-16-Zeichen: '\\u{:X4}'",
  "ungültiges UTF-32-Zeichen: '\\U{:X8}'",
  "die Bytelänge einer UTF-16-Quelldatei muss durch 2 teilbar sein",
  "die Bytelänge einer UTF-32-Quelldatei muss durch 4 teilbar sein",

  // DDoc messages:
  "das Ddoc-Makro ‚{}‘ ist nicht definiert",
  "das Ddoc-Makro ‚{}‘ hat keine schließende Klammer ‚)‘",
  "undokumentiertes Symbol",
  "leerer Kommentar",
  "fehlender ‚Params:‘-Teil",
  "undokumentierter Parameter ‘{}’",

  // Help messages:
  "Unbekannter Befehl: ‚{}‘",

  // UsageError
  "Benutzungsfehler:\n  {}",

  // MissingOptionArgument
  "fehlendes Argument für Option ‚{}‘",

  // HelpMain
  `DIL v{0}
Copyright (c) 2007-2012, Aziz Köksal. Lizenziert unter der GPL3.

Befehle:
{1}
Gib 'dil help <Befehl>' ein, um mehr Hilfe zu einem bestimmten Befehl
zu erhalten.

Kompiliert mit {2} v{3} am {4}.`,

  // HelpCompile
  `Kompiliert D-Quelldateien.
Benutzung:
  dil c[ompile] datei.d [datei2.d, ...] [Optionen]

  Dieser Befehl parst die Quelldateien und führt nur wenig
  semantische Analysen durch.
  Fehlermeldungen werden in die Standardfehlerausgabe geschrieben.

Optionen:
  -d               : akzeptiere veralteten Quelltext
  -debug           : inkludiere „debug“-Code
  -debug=LEVEL     : inkludiere „debug(l)“-Code, wo „l <= LEVEL“ gilt
  -debug=IDENT     : inkludiere „debug(IDENT)"-Code
  -version=LEVEL   : inkludiere „version(l)“-Code, wo „l >= LEVEL“ gilt
  -version=IDENT   : inkludiere „version(IDENT)“-Code
  -I=PFAD          : füge PFAD zu der Liste von Importpfaden hinzu
  -J=PATH          : füge PFAD zu der Liste von Stringimport-Pfaden
  -release         : kompiliere eine Release-Version
  -unittest        : kompiliere Unittests
  -m32             : erzeuge 32bit-Code
  -m64             : erzeuge 64bit-Code
  -of=DATEI        : Ausgabe des binären Codes in DATEI

  -v               : detaillierte Ausgabe

Beispiel:
  dil c src/main.d -I=src/`,

  // HelpPytree
  `Exportiert einen D-Syntaxbaum zu einer Python-Quelldatei.
Benutzung:
  dil py[tree] Ziel datei.d [datei2.d, ...] [Optionen]

Optionen:
  --tokens         : schreibe nur eine Liste von Tokens (noch nicht möglich)
  --fmt            : der Formatstring für die Zieldateinamen
                     Default: d_{{0}.py
                     {{0} = vollqualifizierter Modulname (z.B. dil_PyTreeEmitter)
                     {{1} = Paketname (z.B. dil, dil_ast, dil_lexer etc.)
                     {{2} = Modulname (z.B. PyTreeEmitter)
  -v               : detaillierte Ausgabe

Beispiel:
  dil py pyfiles/ src/dil/translator/PyTreeEmitter.d`,

  // HelpDdoc
  `Generiert Dokumentation aus Ddoc-Kommentaren in D-Quelldateien.
Benutzung:
  dil d[doc] Ziel datei.d [datei2.d, ...] [Optionen]

  ‚Ziel‘ ist der Ordner, in dem die Dokumentationsdateien geschrieben werden.
  Dateien mit der Erweiterung ‚.ddoc‘ werden als Makrodateien erkannt.

Optionen:
  --kandil         : benutze Kandil als Interface
  --report         : schreibe einen Problembericht nach Ziel/report.txt
  -rx=REGEXP       : exkludiere Module vom Problembericht wenn ihr Name
                     mit REGEXP übereinstimmt (kann mehrmals verwendet werden)
  --xml            : schreibe XML statt HTML-Dokumente
  --raw            : keine Makroexpansion in der Ausgabe (für Debugging)
  -hl              : schreibe syntaxhervorgehobene Dateien nach Ziel/htmlsrc
  -i               : inkludiere undokumentierte Symbole
  --inc-private    : inkludiere private Symbole
  -v               : detaillierte Ausgabe
  -m=PFAD          : schreibe eine Liste der bearbeiteten Module nach PFAD
  -version=IDENT   : siehe "dil help compile" für mehr Details

Beispiele:
  dil d doc/ src/main.d data/macros_dil.ddoc -i -m=doc/modules.txt
  dil d tangodoc/ -v -version=Windows -version=Tango \
        --kandil tangosrc/file_1.d tangosrc/file_n.d`,

  // HelpHighlight
  `Markiert eine D-Quelldatei mit XML- oder HTML-Elementen.
Benutzung:
  dil hl datei.d [Ziel] [Optionen]

  Die Datei wird nach Stdout ausgegeben, wenn ‚Ziel‘ nicht angegeben ist.

Optionen:
  --syntax         : generiere Elemente für den Syntaxbaum
  --html           : benutze das HTML-Format (Default)
  --xml            : benutze das XML-Format
  --lines          : gib Zeilennummern aus

Beispiele:
  dil hl src/main.d --syntax > main.html
  dil hl --xml src/main.d main.xml`,

  // HelpImportgraph
  `Parst ein Modul und bildet einen Abhängigkeitsgraph.
Benutzung:
  dil i[mport]graph datei.d Format [Optionen]

  Der Ordner von datei.d wird implizit zu der Liste von Importpfaden
  hinzugefügt.

Format:
  --dot            : generiere ein „dot“-Dokument (Default)
    Optionen zu --dot:
  --gbp            : Gruppiere Module nach Paketnamen
  --gbf            : Gruppiere Module nach vollen Paketnamen
  --hle            : markiere zyklische Kanten im Graph
  --hlv            : markiere Module in zyklischer Relation
  -si=STIL         : der Stil der Kanten von statischen Imports
  -pi=STIL         : der Stil der Kanten von publiken Imports
      STIL         : „dashed“, „dotted“, „solid“, „invis“ or „bold“

  --paths          : gib die Dateipfade der Module im Graph aus
  --list           : gib die Namen der Module im Graph aus
    Optionen gemein zu --paths und --list:
  -l=N             : gib N Levels aus
  -m               : benutze ‚*‘ um zyklische Module zu markieren

Optionen:
  -I=PFAD          : füge PFAD zu der Liste von Importpfaden hinzu
  -x=REGEXP        : exkludiere Module deren Name mit REGEXP übereinstimmen
  -i               : inkludiere unauffindbare Module

Beispiele:
  dil igraph src/main.d --list
  dil igraph src/main.d | dot -Tpng > main.png`,

  // HelpTokenize
  `Gibt die Tokens einer D-Quelldatei aus.
Benutzung:
  dil tok[enize] datei.d [Optionen]

Optionen:
  -               : lies den Text von STDIN aus
  -s=SEPARATOR    : gib zwischen den Tokens SEPARATOR aus, statt '\n'
  -i              : ignoriere Leerzeichen-Tokens (z.B. Kommentare, etc.)
  -ws             : gib die vorangehenden Leerzeichen eines Tokens aus

Beispiele:
  echo 'module xyz; void func(){{}' | dil tok -
  dil tok src/main.d | grep ^[0-9]`,

  // HelpDlexed
  `Schreibt die Anfangs- u. Endwerte aller Tokens in einem binären Format.
Benutzung:
  dil dlx datei.d [Optionen]

Optionen:
  -               : lies den Text von STDIN aus
  -o=FILE         : Ausgabe zu FILE statt STDOUT

Beispiele:
  echo 'module xyz; void func(){{}' | dil dlx - > test.dlx
  dil dlx src/main.d -o src/main.dlx`,

  // HelpSerialize
  `Serialisiert den gesamten Syntaxbaum eines Moduls im Binärformat.
Benutzung:
  dil sz datei.d [Options]

Optionen:
  -               : lies den Text von STDIN aus
  -o=FILE         : Ausgabe zu FILE statt STDOUT

Beispiele:
  echo 'module xyz; void func(){{}' | dil sz - > test.dpt
  dil sz src/main.d -o src/main.dpt`,

  // HelpStatistics
  "Zeigt Statistiken für D-Quelldateien an.
Benutzung:
  dil stat[istic]s datei.d [datei2.d, ...] [Optionen]

Optionen:
  --toktable      : gib die Zahl aller Tokenarten in einer Tabelle aus
  --asttable      : gib die Zahl aller Nodearten in einer Tabelle aus

Beispiel:
  dil stats src/main.d src/dil/Unicode.d",

  // HelpTranslate
  `Übersetzt eine D-Quelldatei in eine andere Sprache.
Benutzung:
  dil trans[late] Sprache datei.d

  Unterstützte Sprachen:
    *) Keine

Beispiel:
  dil trans X src/main.d`,

  // HelpSettings
  "Gibt den Wert einer Einstellungsvariable aus.
Benutzung:
  dil set[tings] [name, name2...]

  Die Namen müssen mit den Einstellungsnamen in dilconf.d übereinstimmen.

Beispiel:
  dil set import_paths datadir",

  // HelpHelp
  "Gibt Hilfestellung zu einem Befehl.
Benutzung:
  dil help Befehl

Beispiele:
  dil help compile
  dil ? hl",
];

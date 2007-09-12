/++
  Author: Jari-Matti Mäkelä <jmjm@iki.fi>
  License: GPL3
+/

string lang_code = "fi";

string[] messages = [
  // Lexer messages:
  "virheellinen Unicode-merkki.",
  "virheellinen UTF-8-merkkijono.",
  // ''
  "päättämätön merkkiliteraali.",
  "tyhjä merkkiliteraali.",
  // #line
  "odotettiin rivinumeroa '#':n jälkeen.",
  "odotettiin kokonaislukua #line:n jälkeen",
  `odotettiin tiedostomäärittelyn merkkijonoa (esim. "polku\tiedostoon")`,
  "päättämätön tiedostomäärittely.",
  "odotettiin päättävää rivinvaihtoa erikoismerkin jälkeen.",
  // ""
  "päättämätön merkkijonoliteraali.",
  // x""
  "ei-heksamerkki '{1}' löytyi heksajonossa.",
  "pariton määrä heksanumeroita heksajonossa.",
  "päättämätön heksajono.",
  // /* */ /+ +/
  "päättämätön lohkokommentti (/* */).",
  "päättämätön sisäkkäinen kommentti (/+ +/).",
  // `` r""
  "päättämätön raakamerkkijono.",
  "päättämätön gravisaksenttimerkkijono.",
  // \x \u \U
  "löydettiin määrittelemätön escape-sekvenssi.", // TODO: Insert '{1}'
  "riittämätön määrä heksanumeroita escape-sekvenssissä.",
  // \&[a-zA-Z][a-zA-Z0-9]+;
  "määrittelemätön HTML-entiteetti '{1}'",
  "päättämätön HTML-entiteetti.",
  "HTML-entiteettien tulee alkaa kirjaimella.",
  // integer overflows
  "desimaaliluku ylivuotaa etumerkin.",
  "desimaaliluvun ylivuoto.",
  "heksadesimaaliluvun ylivuoto.",
  "binääriluvun ylivuoto.",
  "oktaaliluvun ylivuoto.",
  "liukuluvun ylivuoto.",
  "numerot 8 ja 9 eivät ole sallittuja oktaaliluvuissa.",
  "virheellinen heksaluku; odotettiin vähintään yhtä heksanumeroa.",
  "virheellinen binääriluku; odotettiin vähintään yhtä binäärinumeroa.",
  "heksadesimaalisen liukuluvun eksponentti vaaditaan.",
  "heksadesimaalisen liukuluvun eksponentista puuttui numeroita.", // TODO: update
  "eksponenttien tulee alkaa numerolla.",

  // Parser messages
  "odotettiin '{1}':a, mutta löydettiin '{2}'.",
  "'{1}' on redundantti.",
  "tupla voi esiintyä ainoastaan mallin viimeisenä parametrina.",
  "funktion alkuehto jäsennettiin jo.",
  "funktion loppuehto jäsennettiin jo.",
  "linkitystyyppiä ei määritelty.",
  "tunnistamaton linkitystyyppi '{1}'; sallittuja tyyppejä ovat C, C++, D, Windows, Pascal ja System.",

  // Help messages:
  `dil v{1}
Copyright (c) 2007, Aziz Köksal. GPL3-lisensöity.

Alikomennot:
{2}
Lisäohjeita tietystä alitoiminnosta saa kirjoittamalla 'dil help <toiminto>'.

Käännetty {3}:n versiolla {4} {5}.`,

  `Luo XML- tai HTML-dokumentti D-lähdekoodista.

Käyttö:
  dil gen tiedosto.d [Valinnat]

Valinnat:
  --syntax         : luo elementtejä syntaksipuun mukaisesti
  --xml            : käytä XML-muotoa (oletus)
  --html           : käytä HTML-muotoa

Esimerkki:
  dil gen Parser.d --html --syntax > Parser.html`,

  ``,
];
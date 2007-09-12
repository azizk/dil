/++
  Author: Aziz Köksal
  License: GPL3
+/

string lang_code = "tr";

string[] messages = [
  // Lexer messages:
  "geçersiz Unikod karakteri.",
  "geçersiz UTF-8 serisi.",
  // ''
  "kapanmamış karakter sabiti.",
  "boş karakter sabiti.",
  // #line
  "'#' karakter'den sonra 'line' beklendi.",
  "'#line''den sonra rakam beklendi.",
  `filespec dizgisi beklendi (e.g. "yol\dosya".)`,
  "kapanmamış filespec dizgisi.",
  "özel belirtici'den (special token) sonra yeni bir satır beklendi.",
  // ""
  "kapanmamış çift tırnak dizgisi.",
  // x""
  "heks sayı olmayan karakter '{1}' heks dizgisi içinde bulundu.",
  "heks dizginin içindeki sayılar çifter çifter olmalıdır.",
  "kapanmamış heks dizgisi.",
  // /* */ /+ +/
  "kapanmamış blok açıklaması (/* */).",
  "kapanmamış iç içe koyulabilen açıklaması (/+ +/).",
  // `` r""
  "kapanmamış çiğ dizgisi.",
  "kapanmamış ters tırnak dizgisi.",
  // \x \u \U
  "tanımlanmamış çıkış serisi '{1}' bulundu.",
  "heksadesimal çıkış serisi sayıları yeterli değil.",
  // \&[a-zA-Z][a-zA-Z0-9]+;
  "tanımlanmamış HTML varlık '{1}'",
  "kapanmamış HTML varlık.",
  "HTML varlık bir harf ile başlamalı.",
  // integer overflows
  "desimal rakamın bit işareti taşdı.",
  "desimal rakam taşması.",
  "heksadesimal rakam taşması.",
  "binari rakam taşması.",
  "oktal rakam taşması.",
  "float rakam taşması.",
  "8 ve 9 sayılar oktal rakamlar'da geçersizdir.",
  "geçersiz heks rakam; minimum bir heks sayı gereklidir.",
  "geçersiz binari rakam; minimum bir binari sayı gereklidir.",
  "bir heksadesimal float rakamın üsü gereklidir.",
  "heksadesimal float rakamın üsün'de desimal sayılar eksik.",
  "üsler desimal sayı ile başlamalı.",

  // Parser messages
  "'{1}' beklendi, ama '{2}' bulundu.",
  "'{1}' lüzumsuz.",
  "şablon tuple parametre son sırada olmalı.",
  "fonksiyonun 'in' kontratı daha önceden ayrıştırılmış.",
  "fonksiyonun 'out' kontratı daha önceden ayrıştırılmış.",
  "bağlantı tüp (linkage type) belirtilmedi.",
  "bilinmeyen bağlantı tüpü (linkage type) '{1}'; geçerli olanlar C, C++, D, Windows, Pascal ve System.",

  // Help messages:
  `dil v{1}
Copyright (c) 2007, Aziz Köksal. Lisans GPL3.

Komutlar:
{2}
Belirli komut'a yardım edinmek için 'dil help <komut>' yazınız.

Bu yazılım {3} v{4} ile {5} tarihinde derletilmiş.`,

  `Bir D kaynak kodundan XML veya HTML dosyası oluştur.
Kullanım:
  dil gen dosya.d [Seçenekler]

Seçenekler:
  --syntax         : söz dizimi için etiketler yazdır
  --xml            : XML biçimi kullan (varsayılır)
  --html           : HTML biçimi kullan

Örnek:
  dil gen Parser.d --html --syntax > Parser.html`,

  ``,
];
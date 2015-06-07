" File: xml_completion.vim
" Language: XML
" Author: David Tardon <d.tardon at tiscali.cz>
" Created: 06.07.2004 15:32
" Modified: 13.01.2006 16:06
" RCS Revision: $Revision: 1.18 $
" Abstract: Context sensitive completion for XML based on namespaces or
" DocType. Completes element names, attribute names, attribute values
" (if defined as enumeration), closing tag names and XML declarations.
"
" Note: All following comments are written in czech. Translation to
" english is on TODO list.
"
" Description:
" Tento skript poskytuje kontextove doplnovani v XML souborech (to jest
" nabizi k doplneni jen takove vyrazy, ktere maji na dane pozici
" kurzoru vyznam). Moznosti doplnovani jsou nasledujici:
" * otviraci tag
"   + jmeno elementu
"   + jmeno atributu (nabizi jen dosud nepouzita jmena)
"   + hodnota atributu (vcetne uvozovek, pokud nejsou zapsany)
" * zaviraci tag
"   + jmeno elementu vcetne ">", pokud neni zapsana
" * XML deklarace
"   + jmeno "atributu" (version, standalone, encoding)
"   + hodnota "atributu"
" * procesni instrukce
"   + klicova slova cile PI (napr. funkce PHP, ASP, ...)
"   - dosud neimplementovano
"
" Interface:
" Var: g:xmlCompletionDir  umisteni adresare s definicemi
"      doplnovani.
" Var: g:xmlTemporaryDict  umisteni "pracovniho" slovniku
"      pro doplnovani.
" Var: g:xmlResolveFull  urcuje, zda se budou pri hledani definice
"      jmenneho prostoru prohledavat vsechny rodicovske elementy.
"      * "no" - prohledavaji se jen atributy aktualniho elementu
"      a korenoveho elementu
"      * "yes" - prohledavaji se vsechny elementy az ke korenu (pokud
"        neni odpovidajici definice nalezena drive).
"        V rozsahlejsich souborech temer nepouzitelne.
" Var: g:xmlSubelements  urcuje, zda se doplnovani elementu omezi na
"      podelementy soucasneho elementu (neni-li korenovy).
"      * "no" - pouziji se vsechny elementy (vychozi).
"      * "yes" - pouziji se jen podelementy.
" Function: XmlAddNamespaceDef(uri, file)
" Function: XmlAddDoctypePublicDef(public, file)
" Function: XmlAddDoctypeSystemDef(system, file)
" Function: XmlAddPITargetDef(target, file)


if exists("xml_completion_loaded")
  finish
endif

" Definition:
" * Default NS je aplikovan na vsechny elementy, kde je deklarovan 
"   a ktere zaroven nemaji zadny prefix, a na jejich potomky.
" * Default NS lze nastavit na "", coz znamena prazdny NS.
" * Default NS neni aplikovan na jmena atributu.
" * Nekvalifikovane atributy jsou definovany jmenem a NS elementu.
"   (Namespaces in XML, A.2-A.3)


" ################################################################
" #                          RE Patterns                         #
" ################################################################

" Vzory pro jednotlive lexemy XML
" TODO: doplnit k vzorkum odkazy na umisteni v norme
" Bily znak
let s:patS = "[\\ \\t\\r\\n]"
let s:patNameChar = "[a-zA-Z0-9\\._:-]"
let s:patName = "[a-zA-Z_]" . s:patNameChar . "*"
let s:patNCNameChar = "[a-zA-Z0-9\\._-]"
let s:patNCName = "[a-zA-Z_]" . s:patNCNameChar . "*"
" let s:patNCNmtoken = s:patNCNameChar . "\\+"
let s:patQName = "\\%(" . s:patNCName . ":\\)\\?" . s:patNCName
let s:patEq = s:patS . "*=" . s:patS . "*"
let s:patEntityRef = "&" . s:patName . ";"
let s:patCharRef = "&\\#[0-9]\\+;\\|&\\#x[0-9a-fA-F]\\+;"
let s:patReference = s:patEntityRef . "\\|" . s:patCharRef

" Element
let s:patAttValue = "\\%(\"\\%(\\_[^<&\"]\\|" . s:patReference . "\\)*\""
      \ . "\\|" . "'\\%(\\_[^<&']\\|" . s:patReference . "\\)*'\\)"
let s:patDefaultAttName = "xmlns"
let s:patPrefixedAttName = "xmlns:" . s:patNCName
let s:patNSAttName = "\\%(" . s:patPrefixedAttName . "\\|" 
      \ . s:patDefaultAttName . "\\)"
let s:patAttribute = "\\%(" . s:patNSAttName . s:patEq . s:patAttValue 
      \ . "\\|" . s:patQName . s:patEq . s:patAttValue . "\\)"
let s:patSTag = "<" . s:patQName . "\\%(" . s:patS . "\\+" .
      \ s:patAttribute . "\\)*" . s:patS . "*>"
let s:patETag = "<\\/\\(" . s:patQName . "\\)" . s:patS . "*>"
let s:patEmptyElemTag = "<" . s:patQName . "\\%(" . s:patS . "\\+"
      \ . s:patAttribute . "\\)*" . s:patS . "*\\/>"
let s:patSTagFull = "<\\(" . s:patQName . "\\)\\(\\%("
      \ . s:patS . "\\+" .
      \ s:patAttribute . "\\)*\\)" . s:patS . "*\\(\\/\\?\\)>"

" DOCTYPE
let s:patSystemLiteral = "\\(\"[^\"]\\{-}\"\\|'[^']\\{-}'\\)"
let s:patPubidChar = 
      \ "[\\ \\r\\na-zA-Z0-9\\'()+,\\.\\/:=?;!\\*\\#@\\$_%-]"
" Bez "'"
let s:patPubidChar2 = "[\\ \\r\\na-zA-Z0-9()+,\\.\\/:=?;!\\*\\#@\\$_%-]"
let s:patPubidLiteral = "\\(\"" . s:patPubidChar . "*\"\\|'"
      \ . s:patPubidChar2 . "*'\\)"
" Mezi verejnym a systemovym identifikatorem povolime vice mezer
" (napr. zalomeni radku a odsazeni)
let s:patExternalID = "\\%(SYSTEM" . s:patS . s:patSystemLiteral
      \ . "\\|PUBLIC" . s:patS . s:patPubidLiteral
      \ . s:patS . "\\+" . s:patSystemLiteral . "\\)"
" Po jmene korenoveho elementu povolime vice mezer
let s:patdoctypedecl = "<!DOCTYPE" . s:patS . s:patQName
      \ . s:patS . "\\+" . s:patExternalID . s:patS . "\\?>"

" CDATA
let s:patCDStart = "<!\\[CDATA\\["
let s:patCDEnd = "\\]\\]>"
let s:patCData = "\\_.\\{-}\\%(\\]\\]>\\)\\@="  " !
let s:patCDSect = s:patCDStart . s:patCData . s:patCDEnd

" Comment
let s:patComment = "<!--\\_.\\{-}-->" 

" Processing instruction
" V originale nesmi byt jako jmeno /xml/i
let s:patPITarget = s:patName
let s:patPI = "<?" . s:patPITarget . "\\%(" . s:patS 
      \ . ".\\{-}\\%(?>\\)\\@=\\)?>"


" Seznam prevodu NS na odpovidajici definicni soubory
let s:nslist = ListNew()

" Seznam prevodu verejnych identifikatoru DOCTYPE na odpovidajici
" definicni soubory
let s:dtpublist = ListNew()

" Seznam prevodu systemovych identifikatoru DOCTYPE na odpovidajici
" definicni soubory
let s:dtsyslist = ListNew()

" Seznam prevodu cilu PI na odpovidajici definicni soubory
let s:pilist = ListNew()

" Soubor obsahujici doplnovani pro XML deklaraci
let s:xmlDeclFile = "xmldecl-1.0"

" Urcuje, zda se budou pri hledani definice jmenneho prostoru 
" prohledavat vsechny rodicovske elementy.
" "no" - Prohledavaji se jen atributy aktualniho elementu a korenoveho
"        elementu
" "yes" - Prohledavaji se vsechny elementy az ke korenu (pokud neni
"         odpovidajici definice nalezena drive).
"         V rozsahlejsich souborech nepouzitelne.
let g:xmlResolveFull = "no"

" Nastavuje omezeni doplnovani jmen elementu na subelementy nadrazeneho.
let g:xmlSubelements = "no"

setlocal iskeyword+=-
setlocal iskeyword+=.

" Adresar pro definicni soubory
let g:xmlCompletionDir = "/home/ja/.vim/ftplugin/xml/completions"

" Docasny slovnik
let g:xmlTemporaryDict = "/home/ja/.vim/ftplugin/xml/.xmldict"
let &dict = g:xmlTemporaryDict


" ################################################################
" #                   Completion Related Variables               #
" ################################################################

" Parametry tykajici se doplnovani otviraciho tagu
" Jmeno elementu, ktereho se tyka doplnovani
let s:stagElementName = ""
" Jmeno atributu, jehoz hodnotu doplnujeme
let s:stagAttributeName = ""
" Seznam definic jmennych prostoru v aktualnim elementu
let s:stagNamespaceList = ListNew()
" Co se doplnuje v oteviracim tagu. Moznosti:
" * "ename"
" * "aname"
" * "avalue"
let s:stagComplType = ""
" Retezec, ktery je doplnovan
let s:stagComplValue = ""
" Urcuje, zda aktualni element je prazdny
let s:stagEmptyElement = 0
" Slovnik vsech plne zadanych atributu doplnovaneho otviraciho tagu
" s vyjimkou definic NS.
let s:stagAttributeDict = ListNew()
" Pokud doplnujeme hodnotu atributu, urcuje pritomnost uvozovek kolem
" hodnoty. Moznosti:
" * "none"  nejsou uvozovky, je treba doplnit
" * "start"  jen pocatecni uvozovka, zaviraci je treba doplnit
" * "both"  obe uvozovky
let s:attrValueQuoting = ""
" Typ uvozovek uzavirajicich hodnotu atributu. Urcuje se podle pocatecni
" uvozovky, pri "none" je vzdy nastaven na "\""
let s:attrValueQuoteType = "\""

let s:doctypePublic = ""
let s:doctypeSystem = ""

" Parametry tykajici se doplnovani zaviraciho tagu
" Obsahuje jmeno prislusneho elementu. Urceno pro vyuziti pri parsovani
" nedoplnovanych tagu.
let s:etagElementName = ""
" Obsahuje doplnovanou hodnotu. Urceno pro vyuziti pri parsovani
" doplnovaneho tagu.
let s:etagComplValue = ""
" Urcuje, zda tag obsahuje zaviraci zavorku. 1 = ano, 0 = ne.
let s:etagHasEndBracket = 0

" Parametry potrebne pri beznem prochazeni dokumentu
let s:stagTempElementName = ""
let s:stagTempEmptyElement = ""
let s:stagTempNamespaceList = ListNew()

" Parametry pro doplnovani XML deklarace
let s:xmldeclAttributeName = ""
let s:xmldeclComplType = ""
let s:xmldeclComplValue = ""
" let s:xmldeclAttributeDict = ListNew()

" Parametry pro doplnovani procesnich instrukci
let s:piTarget = ""


" ################################################################
" #                   Common completion functions                #
" ################################################################

" Zpracuje uzel na pozici kurzoru.
" Return: typ uzlu:
" * "stag" - kurzor se nachazi uvnitr oteviraciho tagu
" * "etag" - kurzor se nachazi uvnitr zaviraciho tagu
" * "comment" - kurzor se nachazi uvnitr komentare
" * "pi" - kurzor se nachazi uvnitr PI
" * "cdata" - kurzor se nachazi uvnitr sekce CDATA
" * "doctype" - kurzor se nachazi uvnitr sekce DOCTYPE
" * "xmldecl" - kurzor se nachazi v XML deklaraci (PI s cilem xml)
" * "text" - kurzor se nachazi v textu
function! XmlParseCurrent()
  let lnum = line(".")
  let cnum = col(".") - 1 " Pozice
  if !search("<", "bW")
    return "text"
  endif
  let type = XmlNodeType()  " Rozhodnuti o typu uzlu
  if type == "stag"
    let result = XmlParseCurrentSTag(lnum, cnum)
  elseif type == "etag"
    let result = XmlParseCurrentETag(lnum, cnum)
  elseif type == "pi"
    let result = XmlParseCurrentPI(lnum, cnum)
  elseif type == "doctype"  " Hudba budoucnosti
    let result = XmlParseCurrentDoctype(lnum, cnum)
  elseif type == "comment" || type == "cdata"
    let result = type
  elseif type == "xmldecl"
    let result = XmlParseCurrentXmlDecl(lnum, cnum)
  else
    echohl WarningMsg
    echo "Divny uzel: " . str
    echohl None
  endif
  call cursor(lnum, cnum + 1) " Vrat se zpet
  return result
endfunction


" Vychozi bod pro doplnovani. V zavislosti na pozici kurzoru vybira,
" co se bude doplnovat. Vraci prikaz provadejici doplnovani.
" Return: doplnovaci prikaz
" * "\<C-X>\<C-K>" - doplnuje se ze slovniku
" * "\<C-N>" - doplnuje se z textu
" * "" - nedoplnuje se nic
function! XmlComplete()
  let type = XmlParseCurrent()
  if type =~ "text\\|comment\\|cdata\\|doctype"
    return "\<C-N>"
  elseif type == "stag" " Otviraci tag
    return XmlCompleteSTag()
  elseif type == "etag"
    return XmlCompleteETag()
  elseif type == "pi"
    return XmlCompletePI()
  elseif type == "xmldecl"
    return XmlCompleteXmlDecl()
  else  " Chyba
    echoerr "Chybne urceni pozice kurzoru: " . type
  endif
  return "\<C-N>"
endfunction " XmlComplete()


" Typ uzlu, na jehoz otviraci zavorce stoji kurzor.
" Return: typ uzlu:
" * "stag" - oteviraci tag
" * "etag" - zaviraci tag
" * "comment" - komentar
" * "pi" - PI
" * "cdata" - sekce CDATA
" * "doctype" - sekce DOCTYPE
" * "xmldecl" - XML deklarace (PI s cilem xml) 
" * "" - chyba
function! XmlNodeType()
  let test = strpart(getline("."), col(".") - 1, 9)
  " 9 je delka retezce "<!DOCTYPE"; nejdelsi retezec, ktery je testovan
  if match(test, "<" . s:patNCNameChar) == 0 || 
        \ match(test, "<" . s:patS) == 0 || match(test, "<$") == 0
    " Samostatna "<" (nasledovana mezerou nebo koncem radku) znamena
    " otviraci tag.
    return "stag"
  elseif match(test, "<\\/.*") == 0
    return "etag"
  elseif match(test, "<!--.*") == 0
    return "comment"
  elseif match(test, "<?\\cxml\\s.*") == 0
    return "xmldecl"
  elseif match(test, "<?.*") == 0
    return "pi"
  elseif match(test, "<![CDATA[") == 0
    return "cdata"
  elseif match(test, "<!DOCTYPE") == 0
    return "doctype"
  else
    echoerr "XmlNodeType: chybny typ uzlu"
  endif
  return ""
endfunction " XmlNodeType()


" Najde nejblizsi predchazejici otviraci nebo zaviraci tag elementu.
" Preskakuje obsah komentaru a sekci CDATA.
" Return: string  "stag" | "etag" | "none"
function! XmlPrecedingTag()
  if !search("<" . s:patNCNameChar . "\\|<\\/\\|]]>\\|-->", "bW")
    return "none"
  endif
  let str = strpart(getline("."), col(".") - 1, 3)
  while str == "]]>" || str == "-->"
    if str == "]]>"
      if !search(s:patCDStart, "bW")
        echoerr "Nelze najit zacatek sekce CDATA koncici na pozici " .
              \ XmlPrintPos(".")
        return "none"
      endif
    elseif str == "-->"
      if !search(s:patComment, "bW")
        echoerr "Nelze najit zacatek komentare koncici na pozici " .
              \ XmlPrintPos(".")
        return "none"
      endif
    endif
    if !search("<" . s:patNCNameChar . "\\|<\\/\\|]]>\\|-->", "bW")
      return "none"
    endif
    let str = strpart(getline("."), col(".") - 1, 3)
  endwhile
  return XmlNodeType()
endfunction " XmlPrecedingTag()


" Najde nejblizsi nasledujici otviraci nebo zaviraci tag elementu.
" Preskakuje obsah komentaru a sekci CDATA.
" Return: string  "stag" | "etag" | "none"
function! XmlFollowingTag()
  if !search("<", "W")
    return "none"
  endif
  let type = XmlNodeType()
  while !(type == "stag" || type == "etag")
    if type == "cdata"
      if !search("]]>", "W")
        echoerr "Nelze najit konec sekce CDATA zacinajici na pozici " .
              \ XmlPrintPos(".")
      endif
    elseif type == "comment"
      if !search("-->", "W")
        echoerr "Nelze najit konec komentare zacinajici na pozici " .
              \ XmlPrintPos(".")
      endif
    endif
    if !search("<", "W")
      return "none"
    endif
    let type = XmlNodeType()
  endwhile
  return type
endfunction " XmlFollowingTag()


" Najde rodicovsky element aktualniho elementu.
" Return: string  "stag" | "none"
function! XmlParent()
  " Note: Hleda prvni neuzavreny otviraci tag
  let type = XmlNodeType()
  if type == "stag"
    let type = XmlPrecedingTag()
  endif
  while 1
    if type == "none"
      return type
    elseif type == "etag"
      call XmlParseETag()
      let type = XmlStartTag()
      if type == "none"
        return type
      endif
    elseif type == "stag"
      call XmlParseSTag()
      if s:stagTempEmptyElement == 0
        return "stag"
      endif
    endif
    let type = XmlPrecedingTag()
  endwhile
endfunction " XmlParent()


" Najde otviraci element k aktualnimu zaviracimu.
" Return: string "stag" | "none"
function! XmlStartTag()
  " Note: Hleda otviraci tag se stejnym jmenem. Pritom je treba davat
  "  pozor na vnorene stejnojmenne elementy (i prazdne).
  let include = 0
  let firstloop = 1
  " call XmlParseETag()	" Warning: Nelze pri doplnovani koncoveho tagu
  " (tam je treba pouzit XmlParseCurrentETag) -> je treba volat predem
  while include > 0 || firstloop
    let firstloop = 0
    if !search("<\\/\\?" . s:etagElementName . "\\|]]>\\|-->", "bW")
      return "none"
    endif
    let str = strpart(getline("."), col(".") - 1, 3)
  " while str == "]]>" || str == "-->"
    if str == "]]>"
      if !search(s:patCDStart, "bW")
        echoerr "Nelze najit zacatek sekce CDATA koncici na pozici " .
              \ XmlPrintPos(".")
        return "none"
      endif
    elseif str == "-->"
      if !search(s:patComment, "bW")
        echoerr "Nelze najit zacatek komentare koncici na pozici " .
              \ XmlPrintPos(".")
        return "none"
      endif
    elseif str =~ "^<\\/"
      let include = include + 1
    else
      call XmlParseSTag()
      if !s:stagTempEmptyElement
        let include = include - 1 "Jsme venku z jedne urovne uzavreni
      endif
    endif
  endwhile
  return "stag"
endfunction


" Najde zaviraci element k aktualnimu otviracimu.
" Return: string "stag" | "etag" | "none"
  " TODO: prepsat
function! XmlEndTag()
  " Note: Hleda zaviraci tag se stejnym jmenem. Pritom je treba davat
  "  pozor na vnorene stejnojmenne elementy (i prazdne).
  let include = 1
  call XmlParseSTag()
  if s:stagTempEmptyElement
    return "stag"
  endif
  while include > 0
    if !search("<\\/\\?" . s:stagTempElementName . "\\|<!", "W")
      return "none"
    endif
    let type = XmlNodeType()
    if type == "cdata"
      if !search(s:patCDEnd, "W")
        echoerr "Nelze najit konec sekce CDATA koncici na pozici " .
              \ XmlPrintPos(".")
        return "none"
      endif
    elseif type == "comment"
      if !search("-->", "W")
        echoerr "Nelze najit konec komentare koncici na pozici " .
              \ XmlPrintPos(".")
        return "none"
      endif
    elseif type == "etag"
      let include = include - 1 "Jsme venku z jedne urovne uzavreni
    elseif type == "stag"
      call XmlParseSTag()
      if !s:stagTempEmptyElement
        let include = include + 1
      endif
    endif
  endwhile
  return "etag"
endfunction


" ################################################################
" #                     Start Tag Completion                     # 
" ################################################################

" Param: lnum  cislo radku, kde se doplnuje
" Param: cnum  cislo sloupce, kde se doplnuje
" Var: s:stagElementName
" Var: s:stagAttributeName
" Var: s:stagNamespaceList
" Var: s:stagComplType
" Var: s:stagComplValue
" Var: s:stagEmptyElement
" Var: s:stagAttributeDict
" Var: s:attrValueQuoting
" Var: s:attrValueQuoteType
" Var: s:stagTempEmptyElement
" Return: retezec "stag" | "text"
function! XmlParseCurrentSTag(lnum, cnum)
  let cnum = a:cnum + 1 " Musi byt 'za'
  " Note: Ve vzorku pouzivame Name misto QName proto, ze QName 
  "       nezachyti situaci, kdy dosud napsana cast jmena konci 
  "       dvojteckou (to znamena, ze je zapsan prefix NS).
  " %# "<" Name? %l%c ( S+ Attribute )* ( "/>" | ">" )?
  let patSTagEname = "\\%#<\\(" . s:patName . "\\)\\?\\%" . a:lnum .
        \ "l\\%" . cnum . "c\\(\\%(" . s:patS . "\\+" .
        \ s:patAttribute . "\\)*\\)" . s:patS . "*\\(\\/>\\|>\\)\\?"
  " Note: Ve vzorku pouzivame Name misto QName proto, ze QName 
  "       nezachyti situaci, kdy dosud napsana cast jmena konci 
  "       dvojteckou (to znamena, ze je zapsan prefix NS).
  " %# "<" QName? S+ ( Attribute S+ )* Name? %l%c ( S+ Attribute )*
  " ( "/>" | ">" )?
  let patSTagAname = "\\%#<\\(" . s:patQName . "\\)" . s:patS . "\\+" .
        \ "\\(\\%(" . s:patAttribute . s:patS . "\\+\\)*\\)\\("
        \ . s:patName . "\\)\\?\\%" . a:lnum . "l\\%" . cnum . "c\\("
        \ . "\\%(" . s:patS . "\\+" . s:patAttribute . 
        \ "\\)*\\)\\(\\/>\\|>\\)\\?"
  " %# "<" QName? S+ ( Attribute S+ )* AttName Eq %l%c ( S+ Attribute )*
  " ( "/>" | ">" )?
  let patSTagAnameEq = "\\%#<\\(" . s:patQName . "\\)" . s:patS . "\\+"
        \ . "\\(\\%(" . s:patAttribute . s:patS . "\\+\\)*\\)\\("
        \ . s:patQName . "\\)" . s:patEq . "\\%" . a:lnum . "l\\%"
        \ . cnum . "c\\(\\%("
        \ . s:patS . "\\+" . s:patAttribute . "\\)*\\)\\(\\/>\\|>\\)\\?"
  " %# "<" QName? S+ ( Attribute S+ )* AttName Eq
  " ( ( "'" ( Char - "'" )* ) | ( '"' ( Char - '"' )* ) ) %l%c 
  " ( S+ Attribute )* ( "/>" | ">" )?
  let patSTagAvalueNotClosed = "\\%#<\\(" . s:patQName . "\\)" . s:patS 
        \ . "\\+"
        \ . "\\(\\%(" . s:patAttribute . s:patS . "\\+\\)*\\)\\("
        \ . s:patQName . "\\)" . s:patEq . "\\('[^']*\\|\"[^\"]*\\)"
        \ . "\\%" . a:lnum . "l\\%" . cnum . "c\\(\\%("
        \ . s:patS . "\\+" . s:patAttribute . "\\)*\\)\\(\\/>\\|>\\)\\?"
  " %# "<" QName? S+ ( Attribute S+ )* AttName Eq
  " (( "'" ( Char - "'" )* %l%c "'" ) | ( '"' ( Char - '"' )* %l%c '"' ))
  " ( S+ Attribute )* ( "/>" | ">" )?
  let patSTagAvalue = "\\%#<\\(" . s:patQName . "\\)" . s:patS . "\\+"
        \ . "\\(\\%(" . s:patAttribute . s:patS . "\\+\\)*\\)\\("
        \ . s:patQName . "\\)" . s:patEq . "\\('[^']*"
        \ . "\\%" . a:lnum . "l\\%" . cnum . "c'\\|\"[^\"]*"
        \ . "\\%" . a:lnum . "l\\%" . cnum . "c\"\\)\\(\\%("
        \ . s:patS . "\\+" . s:patAttribute . "\\)*\\)\\(\\/>\\|>\\)\\?"
  let dist = XmlDistance(line("."), col("."), a:lnum, a:cnum) + 2
  let s:attrValueQuoteType = "\""
  let s:attrValueQuoting = "none"
  let s:stagAttributeName = ""
  let s:stagComplValue = ""
  let s:stagTempNamespaceList = ListNew()

  " Rozliseni, co se doplnuje
  if search(patSTagEname) " Doplnujeme jmeno elementu
    let patSTagEname = substitute(patSTagEname, 
          \ "\\\\%\\%(\\#\\|\\d\\+l\\)", "", "g")
    let patSTagEname = substitute(patSTagEname, 
          \ "\\%(\\\\%\\)\\@<=\\d\\+c", dist . "c", "g")
    " Uprava vzorku pro vyhledavani v retezci (odstranime informace
    " o pozici)
    let str = XmlMatchStr(patSTagEname)
    let s:stagComplType = "ename"
    let s:stagComplValue = substitute(str, patSTagEname, "\\1",
          \ "")
    let s:stagElementName = s:stagComplValue
    let strAttr = substitute(str, patSTagEname, "\\2", "")

  elseif search(patSTagAname) " Doplnujeme jmeno atributu
    let patSTagAname = substitute(patSTagAname,
          \ "\\\\%\\%(\\#\\|\\d\\+l\\)", "", "g")
    let patSTagAname = substitute(patSTagAname, 
          \ "\\%(\\\\%\\)\\@<=\\d\\+c", dist . "c", "g")
    " Uprava vzorku pro vyhledavani v retezci (odstranime informace
    " o pozici)
    let str = XmlMatchStr(patSTagAname)
    let s:stagComplType = "aname"
    let s:stagElementName = substitute(str, patSTagAname, "\\1",
          \ "")
    let s:stagComplValue = substitute(str, patSTagAname, "\\3",
          \ "")
    let strAttr = substitute(str, patSTagAname, "\\2", "") . " " .
          \ substitute(str, patSTagAname, "\\4", "")

  elseif search(patSTagAnameEq) " Doplnujeme hodnotu atributu vc. 
    " uvozovek
    let patSTagAnameEq = substitute(patSTagAnameEq,
          \ "\\\\%\\%(\\#\\|\\d\\+l\\)", "", "g")
    let patSTagAnameEq = substitute(patSTagAnameEq,
          \ "\\%(\\\\%\\)\\@<=\\d\\+c", dist . "c", "g")
    " Uprava vzorku pro vyhledavani v retezci (odstranime informace
    " o pozici)
    let str = XmlMatchStr(patSTagAnameEq)
    let s:stagComplType = "avalue"
    let s:stagElementName = substitute(str, patSTagAnameEq,
          \ "\\1", "")
    let s:stagAttributeName = substitute(str, patSTagAnameEq,
          \ "\\3", "")
    let strAttr = substitute(str, patSTagAname, "\\2", "") . " " .
          \ substitute(str, patSTagAname, "\\4", "")
    let s:stagComplValue = ""
    let s:attrValueQuoting = "none"
    let s:attrValueQuoteType = "\""

  elseif search(patSTagAvalue)  " Doplnujeme hodnotu atributu
    let patSTagAvalue = substitute(patSTagAvalue,
          \ "\\\\%\\%(\\#\\|\\d\\+l\\)", "", "g")
    let patSTagAvalue = substitute(patSTagAvalue, 
          \ "\\%(\\\\%\\)\\@<=\\d\\+c", dist . "c", "g")
    " Uprava vzorku pro vyhledavani v retezci (odstranime informace
    " o pozici)
    let str = XmlMatchStr(patSTagAvalue)
    let s:stagComplType = "avalue"
    let s:stagElementName = substitute(str, patSTagAvalue,
          \ "\\1", "")
    let s:stagAttributeName = substitute(str, patSTagAvalue,
          \ "\\3", "")
    let attval = substitute(str, patSTagAvalue, "\\4", "")
    let s:stagComplValue = strpart(attval, 1, strlen(attval) - 2)
    " Hodnota je uzavrena v uvozovkach
    let strAttr = substitute(str, patSTagAvalue, "\\2", "") . 
          \ substitute(str, patSTagAvalue, "\\5", "")
    let s:attrValueQuoting = "both"
    let s:attrValueQuoteType = strpart(attval, 0, 1)

  elseif search(patSTagAvalueNotClosed) " Doplnujeme hodnotu atributu
    " vcetne. zaviraci uvozovky
    let patSTagAvalueNotClosed = substitute(patSTagAvalueNotClosed,
          \ "\\\\%\\%(\\#\\|\\d\\+l\\)", "", "g")
    let patSTagAvalueNotClosed = substitute(patSTagAvalueNotClosed, 
          \ "\\%(\\\\%\\)\\@<=\\d\\+c", dist . "c", "g")
    " Uprava vzorku pro vyhledavani v retezci (odstranime informace
    " o pozici)
    let str = XmlMatchStr(patSTagAvalueNotClosed)
    let s:stagComplType = "avalue"
    let s:stagElementName = substitute(str, patSTagAvalueNotClosed, 
          \ "\\1", "")
    let s:stagAttributeName = substitute(str, 
          \ patSTagAvalueNotClosed, "\\3", "")
    let attval = substitute(str, patSTagAvalueNotClosed, "\\4", "")
    let s:stagComplValue = strpart(attval, 1) " Na zacatku je 
    " uvozovka
    let strAttr = substitute(str, patSTagAvalueNotClosed, "\\2", "") . 
          \ " " . substitute(str, patSTagAvalueNotClosed, "\\5", "")
    let s:attrValueQuoting = "start"
    let s:attrValueQuoteType = strpart(attval, 0, 1)

  else
    echoerr "XmlParseCurrentSTag: spatny vzorek"
    return "text"
  endif

  " Parametry nezavisle na pouzitem vzorku
  let s:stagNamespaceList = XmlStr2NamespaceList(strAttr)
  let s:stagAttributeDict = XmlStr2AttributeDict(strAttr)
  if strpart(str, strlen(str) - 2) == "/>"
    let s:stagEmptyElement = 1
    let s:stagTempEmptyElement = 1
  else
    let s:stagEmptyElement = 0
    let s:stagTempEmptyElement = 0
  endif
  call XmlResolveNamespace()  " Priprava pro doplnovani
  call XmlResolveDoctype()
  return "stag"
endfunction


" Zpracuje otviraci tag elementu (i prazdneho elementu). Tag musi mit
" spravnou syntaxi.
" Var: s:stagTempElementName
" Var: s:stagTempNamespaceList
" Var: s:stagTempEmptyElement
" Return: string "stag" 
" TODO: pozor na pridavani NS pri prochazeni dokumentu (prechazime i
" vnorene elementy)
function! XmlParseSTag()
  let str = XmlMatchStr(s:patSTagFull)
  let s:stagTempElementName = substitute(str, s:patSTagFull, "\\1", "")
  let attribs = substitute(str, s:patSTagFull, "\\2", "")
  let empty = substitute(str, s:patSTagFull, "\\3", "")
  if empty == "/"
    let s:stagTempEmptyElement = 1
  else
    let s:stagTempEmptyElement = 0
  end
  let nslist = XmlStr2NamespaceList(attribs)
  let s:stagTempNamespaceList = ListConcat(s:stagTempNamespaceList, nslist)
  return "stag"
endfunction " XmlParseSTag()


" Zpracuje DOCTYPE deklaraci dokumentu.
" Var: s:doctypePublic
" Var: s:doctypeSystem
" Return: string "doctype"
function! XmlParseDoctype()
  let doctype = XmlMatchStr(s:patdoctypedecl)
  let doctype = substitute(doctype, "\n", " ", "g")
  if match(doctype, "SYSTEM") != -1
    let s:doctypePublic = ""
    let s:doctypeSystem = substitute(doctype, s:patdoctypedecl, "\\1",
          \ "")
  else
    let s:doctypePublic = substitute(doctype, s:patdoctypedecl, "\\2",
          \ "")
    let s:doctypeSystem = substitute(doctype, s:patdoctypedecl, "\\3",
          \ "")
  endif
  " Odstraneni uvozovek
  if s:doctypePublic != ""
    let s:doctypePublic = strpart(s:doctypePublic, 1, 
          \ strlen(s:doctypePublic) - 2)
  endif
  let s:doctypeSystem = strpart(s:doctypeSystem, 1, 
        \ strlen(s:doctypeSystem) - 2)
  return "doctype"
endfunction " XmlParseDoctype()


" Vyhleda definice NS zpracovavaneho otviraciho tagu.
" Return: ""
function! XmlResolveNamespace()
  if g:xmlResolveFull == "yes"
    call XmlResolveNSFull()
  elseif g:xmlResolveFull == "no"
    call XmlResolveNSRoot()
  endif
  call XmlPatchNamespaces()
  return ""
endfunction


" Zpracuje otviraci tag korenoveho elementu dokumentu za predpokladu,
" ze tento neni prave doplnovan.
" Return: ""
function! XmlResolveNSRoot()
  let lnum = line(".")
  let cnum = col(".") " Pozice doplnovaneho start tagu
  call cursor(1, 1)
  if XmlFollowingTag() == "none"
    echohl WarningMsg
    echo "Zda se, ze v dokumentu neni zatim zadny tag"
    echohl None
  else
    if !(line(".") == lnum && col(".") == cnum) " Nedoplnujeme korenovy
      " tag -> muzeme ho bez obav zpracovat
      call XmlParseSTag()
    endif
  endif
endfunction


" Zpracuje otviraci tagy rodicovskych elementu az ke korenovemu.
" Return: ""
function! XmlResolveNSFull()
  let parent = XmlParent()
  while parent != "none"
    call XmlParseSTag()
    let parent = XmlParent()
  endwhile
  return ""
endfunction


" Najde a zpracuje definici DOCTYPE, je-li uvedena.
" Return: string "doctype" | "none"
function! XmlResolveDoctype()
  call cursor(1, 1)
  let type = XmlNodeType()
  while type != "doctype"
    if type == "comment"
      if !search("-->", "W")
        echoerr "Nelze najit konec komentare zacinajici na pozici " .
              \ XmlPrintPos(".")
      endif
    elseif type == "xmldecl" || type == "pi"  " Toto je povoleno pred
      " korenovym elementem
    elseif type == "stag" " Korenovy element - DOCTYPE musi byt pred
      " nim, takze v nasem pripade neni pritomno
      return "none"
    else  " Vse ostatni je chyba - nesmi se vyskytnout
      echoerr "Neocekavany typ uzlu na pozici " . XmlPrintPos()
      return "none"
    endif
    if !search("<", "W")
      return "none"
    endif
    let type = XmlNodeType()
  endwhile
  return XmlParseDoctype()
endfunction " XmlResolveDoctype()


" Doplnovani otviraciho tagu.
" Return: doplnovaci prikaz
function! XmlCompleteSTag()
  if s:stagComplType == "ename"
    return XmlCompleteSTagElementName()
  elseif s:stagComplType == "aname"
    return XmlCompleteSTagAttrName()
  elseif s:stagComplType == "avalue"
    return XmlCompleteSTagAttrValue()
  else
    echoerr "Neplatna hodnota pro doplneni STag: "
          \ . s:stagComplType
  endif
endfunction " XmlCompleteSTag()


" Doplni jmeno elementu v otviracim tagu.
" TODO: sloucit ruzne varianty XmlCompleteSTag* do XmlCompleteSTag?
"   (zalezi na rozsahu).
function! XmlCompleteSTagElementName()
  let file = XmlFileLookupSTag()
  if file != ""
    call XmlWriteDictSTag(file)
    return "\<C-X>\<C-K>"
  endif
  return "\<C-N>"
endfunction


" Doplni jmeno atributu
function! XmlCompleteSTagAttrName()
  let file = XmlFileLookupSTag()
  if file != ""
    call XmlWriteDictSTag(file)
    return "\<C-X>\<C-K>"
  endif
  return "\<C-N>"
endfunction


" Doplni hodnotu atributu
function! XmlCompleteSTagAttrValue()
  " Vyridime doplnovani uvozovek
  if s:attrValueQuoting == "none"
    exe "normal i" . s:attrValueQuoteType . s:attrValueQuoteType .
          \ "a"
  elseif s:attrValueQuoting == "start"
    exe "normal i" . s:attrValueQuoteType
  endif
  let file = XmlFileLookupSTag()
  if file != ""
    call XmlWriteDictSTag(file)
    return "\<C-X>\<C-K>"
  endif
  return "\<C-N>"
endfunction


" Vyhleda doplnovaci soubor na zaklade URI jmenneho prostoru elementu,
" SYSTEM URI, nebo PUBLIC identifikatoru.
" Return: jmeno souboru nebo ""
" Note: V pripade, ze doplnujeme jmeno elementu, muze byt dosud zadana
"   cast jmena jen zacatkem prefixu NS. To muze zpusobit nevhodne 
"   chovani, je-li v default NS element zacinajici tymz retezcem. 
"   Default NS pritom muze byt urcen jak pomoci xmlns, tak DOCTYPE.
function! XmlFileLookupSTag()
  let ns = s:XmlNamespacePrefix(s:stagElementName)
  if ns =~? "^xml$"
    let uri = "http://www.w3.org/XML/1998/namespace"
  else
    let uri = XmlDictLookup(s:stagNamespaceList, ns)
  endif
  let file1 = XmlDictLookup(s:nslist, uri)
  " Verejny identifikator DOCTYPE ma prednost pred systemovym.
  let file2 = XmlDictLookup(s:dtpublist, s:doctypePublic)
  let file3 = XmlDictLookup(s:dtsyslist, s:doctypeSystem)
  if file1 != ""
    return file1
  elseif file2 != ""
    return file2
  else
    return file3
  endif
  return ""
endfunction " XmlFileLookupSTag()



" Zapise do slovniku seznam doplnovani pro STag.
" Param: file  soubor obsahujici definice (bez adresarove cesty)
" Return: ""
function! XmlWriteDictSTag(file)
  if s:stagComplType == "ename"
    " Vychozi nastaveni prohledava vsechna dostupna jmena elementu
    let pat = "/^" . s:XmlLocalName(s:stagComplValue) .
	  \ "[^:\\/]*:/s/^\\([^:]*\\):.*/\\1/p"
    if g:xmlSubelements == "yes" " Pouzijeme omezeni
      let uri = XmlDictLookup(s:stagNamespaceList,
	    \ s:XmlNamespacePrefix(s:stagComplValue))
      let name = s:XmlLocalName(s:stagComplValue)
      " Zkusi najit nadrazeny element soucasneho. Pokud neexistuje,
      " znamena to bud, ze doplnujeme korenovy element, nebo je nekde
      " neco opravdu spatne.
      let lnum = line(".")
      let cnum = col(".") " Pozice doplnovaneho start tagu
      " Vratime se na otviraci zavorku
      call cursor(lnum, cnum - strlen(s:stagComplValue) - 1)
      if XmlParent() == "stag"
	let pat = "\\%^" . s:XmlLocalName(s:stagTempElementName) .
	      \ "\\/{" . uri . "}" . name .
	      \ "%s%^.*}\\(.*\\)%\\1%p"
      endif
      call cursor(lnum, cnum) " Vrat se zpet
    endif
  elseif s:stagComplType == "aname"
    let ns = s:XmlNamespacePrefix(s:stagComplValue)
    let atlist = ListMap(s:stagAttributeDict, "ListCar")
    " Ze slovniku atributu vytahneme jen jmena atributu
    let atlist = ListMap(atlist, "XmlQualifiedAttributeName")
    " Jmena prevedeme do Clarkovy notace
    let pat = "\\%^\\(" . s:XmlLocalName(s:stagElementName) .
          \ ":" . XmlListJoin(atlist, ":\\|" .
          \ s:XmlLocalName(s:stagElementName) . ":") . ":\\)%b;"
    if ns =~? "^xml$"
      let uri = "http://www.w3.org/XML/1998/namespace"
    elseif ns != ""
      let uri = XmlDictLookup(s:stagNamespaceList, ns)
    else  " Nema prefix -> patri k elementu
      let uri = ""
    endif
    let pat = pat .
          \ "\\%^" . s:XmlLocalName(s:stagElementName) . ":{" .
          \ uri . "}" . s:XmlLocalName(s:stagComplValue)
          \ . "%s%[^:]*:{[^}]*}\\([^:]*\\).*%\\1%p"
  elseif s:stagComplType == "avalue"
    let ns = s:XmlNamespacePrefix(s:stagAttributeName)
    if ns =~? "^xml$"
      let uri = "http://www.w3.org/XML/1998/namespace"
    elseif ns != ""
      let uri = XmlDictLookup(s:stagNamespaceList, ns)
    else  " Nema prefix -> patri k elementu
      let uri = ""
    endif
    let pat = "\\%^" . s:XmlLocalName(s:stagElementName) . ":{" .
          \ uri . "}" . s:XmlLocalName(s:stagAttributeName)
          \ . ":" . s:stagComplValue
          \ . "%s%.*:\\(.*\\)%\\1%p"
  else
    echoerr "XmlWriteDictSTag: chybny typ doplnovani"
  endif
  call system("sed -ne '" . pat . "' " . g:xmlCompletionDir . "/" . 
        \ a:file . " > " . g:xmlTemporaryDict)
endfunction " XmlWriteDictSTag(file)


" ################################################################
" #                       End Tag Completion                     #  
" ################################################################

" Param: lnum  cislo radku, kde se doplnuje
" Param: cnum  cislo sloupce, kde se doplnuje
" Var: s:etagElementName
" Var: s:etagComplValue
" Var: s:etagHasEndBracket
" Return: retezec "etag" | "text"
function! XmlParseCurrentETag(lnum, cnum)
  let cnum = a:cnum + 1 " Musi byt 'za'
  " Note: Ve vzorcich pouzivame Name misto QName proto, ze QName 
  "       nezachyti situaci, kdy dosud napsana cast jmena konci 
  "       dvojteckou (to znamena, ze je zapsan prefix NS).
  let patETag = "\\%#<\\/\\(" . s:patName . "\\)\\?\\%"
        \ . a:lnum . "l\\%" . cnum . "c" . "\\(>\\?\\)"
  if search(patETag)
    let patETag = substitute(patETag, 
          \ "\\\\%\\%(\\#\\|\\d\\+[lc]\\)", "", "g")
    let str = XmlMatchStr(patETag)
    let s:etagElementName = substitute(str, patETag, "\\1", "")
    let s:etagComplValue = s:etagElementName  " Tataz hodnota
    let s:etagHasEndBracket = strlen(substitute(str, patETag,
          \ "\\2", ""))
    " Pokud ma zaviraci zavorku, delka daneho retezce bude 1
  else
    let s:etagElementName = ""
    let s:etagComplValue = ""
    let s:etagHasEndBracket = 0
    return "text"
  endif
  return "etag"
endfunction


" Doplnovani zaviraciho tagu. V pripade nesrovnalosti (chybi otviraci
" tag, dosud zapsana cast jmena nesouhlasi s jmenem otviraciho tagu) 
" vypise chybu.
" Return: doplnovaci prikaz
function! XmlCompleteETag()
  let lnum = line(".")
  let cnum = col(".")
  let open = XmlStartTag()
  if open != "stag" " Nepodarilo se najit odpovidajici otviraci tag
    echoerr "XmlCompleteETag: Nelze najit prislusny otviraci tag"
    let remainder = ""
  else
    " call XmlParseSTag() " Ziskame jmeno tagu
    " Note: Neni treba, provadime v ramci XmlStartTag()
    let remainder = strpart(s:stagTempElementName,
          \ strlen(s:etagComplValue))
    if !s:etagHasEndBracket
      let remainder = remainder . ">" " Pridame zavorku
    endif
  endif
  call cursor(lnum, cnum)
  exe "normal i" . remainder
  if s:etagHasEndBracket
    normal l
  endif
  return "\<C-O>a"
endfunction " XmlCompleteETag()


" Zpracuje zaviraci tag elementu.
" Var: s:etagElementName
" Return: string "etag" 
function! XmlParseETag()
  let str = XmlMatchStr(s:patETag)
    let s:etagElementName = substitute(str, s:patETag, "\\1", "")
  return "etag"
endfunction


" ################################################################
" #               Processing Instruction Completion              #   
" ################################################################

" Ziska jmeno (target) PI.
" Param: lnum  cislo radku, kde se doplnuje
" Param: cnum  cislo sloupce, kde se doplnuje
" Var: s:piTarget
" Return: retezec "pi" | "text"
" TODO: ziskavat doplnovanou hodnotu - klicove slovo pod kurzorem
function! XmlParseCurrentPI(lnum, cnum)
  let target = XmlMatchStr("<?" . s:patPITarget)
  if target == ""
    return "text"
  endif
  let s:piTarget = strpart(target, 2) " Vynech zavorku
  return "pi"
endfunction


" Doplnovani procesnich instrukci
" Return: ""
function! XmlCompletePI()
  let file = XmlDictLookup(s:pilist, s:piTarget)
  if file != ""
    call XmlWriteDictPI(file)
    return "\<C-X>\<C-K>"
  endif
  return ""
endfunction " XmlCompletePI()


" Prepis doplnovaciho slovniku slovnikem pro cil PI
" Param: file  soubor obsahujici definice (bez adresarove cesty)
" Return: ""
function! XmlWriteDictPI(file)
  " Jen prekopirujeme obsah souboru
  call system("cat " . g:xmlCompletionDir . "/" . a:file . " > "
        \ . g:xmlTemporaryDict)
  return ""
endfunction " XmlWriteDictPI()


" ################################################################
" #                   XML Declaration Completion                 #   
" ################################################################ 

" Param: lnum  cislo radku, kde se doplnuje
" Param: cnum  cislo sloupce, kde se doplnuje
" Var: s:xmldeclAttributeName
" Var: s:xmldeclComplType
" Var: s:xmldeclComplValue
" Return: retezec "xmldecl" | "text"
" TODO: bylo by asi vhodne predpokladat jednoradkovou definici
function! XmlParseCurrentXmlDecl(lnum, cnum)
  let cnum = a:cnum + 1 " Musi byt 'za'
  let patDeclAttr = s:patName . s:patEq . s:patAttValue
  " %# "<?[xX][mM][lL]" S+ ( DeclAttr S+ )* Name? %l%c ( S+ DeclAttr )*
  " S* ( "?>" )?
  let patAname = "\\%#<?[xX][mM][lL]" . s:patS . "\\+"
        \ . "\\(\\%(" . patDeclAttr . s:patS . "\\+\\)*\\)\\("
        \ . s:patName . "\\)\\?\\%" . a:lnum . "l\\%" . cnum . "c\\("
        \ . "\\%(" . s:patS . "\\+" . patDeclAttr . 
        \ "\\)*\\)\\%(?>\\)\\?"
  " %# "<?[xX][mM][lL]" S+ ( DeclAttr S+ )* AttName Eq %l%c
  " ( S+ DeclAttr )* S* ( "?>" )?
  let patAnameEq = "\\%#<?[xX][mM][lL]" . s:patS . "\\+" .
        \ "\\(\\%(" . patDeclAttr . s:patS . "\\+\\)*\\)\\("
        \ . s:patName . "\\)" . s:patEq . "\\%" . a:lnum . "l\\%"
        \ . cnum . "c\\(\\%("
        \ . s:patS . "\\+" . patDeclAttr . "\\)*\\)\\%(?>\\)\\?"
  " %# "<?[xX][mM][lL]" S+ ( DeclAttr S+ )* AttName Eq
  " ( ( "'" ( Char - "'" )* ) | ( '"' ( Char - '"' )* ) ) %l%c 
  " ( S+ DeclAttr )* S* ( "?>" )?
  let patAvalueNotClosed = "\\%#<?[xX][mM][lL]" . s:patS . "\\+"
        \ . "\\(\\%(" . patDeclAttr . s:patS . "\\+\\)*\\)\\("
        \ . s:patName . "\\)" . s:patEq . "\\('[^']*\\|\"[^\"]*\\)"
        \ . "\\%" . a:lnum . "l\\%" . cnum . "c\\(\\%("
        \ . s:patS . "\\+" . patDeclAttr . "\\)*\\)\\%(?>\\)\\?"
  " %# "<?[xX][mM][lL]" S+ ( DeclAttr S+ )* AttName Eq
  " (( "'" ( Char - "'" )* %l%c "'" ) | ( '"' ( Char - '"' )* %l%c '"' ))
  " ( S+ DeclAttr )* S* ( "?>" )?
  let patAvalue = "\\%#<?[xX][mM][lL]" . s:patS . "\\+"
        \ . "\\(\\%(" . patDeclAttr . s:patS . "\\+\\)*\\)\\("
        \ . s:patName . "\\)" . s:patEq . "\\('[^']*"
        \ . "\\%" . a:lnum . "l\\%" . cnum . "c'\\|\"[^\"]*"
        \ . "\\%" . a:lnum . "l\\%" . cnum . "c\"\\)\\(\\%("
        \ . s:patS . "\\+" . patDeclAttr . "\\)*\\)\\%(?>\\)\\?"
  let dist = XmlDistance(line("."), col("."), a:lnum, a:cnum) + 2
  let s:attrValueQuoteType = "\""
  let s:attrValueQuoting = "none"
  let s:xmldeclAttributeName = ""
  let s:xmldeclComplValue = ""
  " Rozliseni, co se doplnuje
  if search(patAname) " Doplnujeme jmeno atributu
    let patAname = substitute(patAname,
          \ "\\\\%\\%(\\#\\|\\d\\+l\\)", "", "g")
    let patAname = substitute(patAname, 
          \ "\\%(\\\\%\\)\\@<=\\d\\+c", dist . "c", "g")
    " Uprava vzorku pro vyhledavani v retezci (odstranime informace
    " o pozici)
    let str = XmlMatchStr(patAname)
    let s:xmldeclComplType = "aname"
    let s:xmldeclComplValue = substitute(str, patAname, "\\2",
          \ "")
    let strAttr = substitute(str, patAname, "\\1", "") . " " .
          \ substitute(str, patAname, "\\3", "")
  elseif search(patAnameEq) " Doplnujeme hodnotu atributu vc. 
    " uvozovek
    let patAnameEq = substitute(patAnameEq,
          \ "\\\\%\\%(\\#\\|\\d\\+l\\)", "", "g")
    let patAnameEq = substitute(patAnameEq,
          \ "\\%(\\\\%\\)\\@<=\\d\\+c", dist . "c", "g")
    " Uprava vzorku pro vyhledavani v retezci (odstranime informace
    " o pozici)
    let str = XmlMatchStr(patAnameEq)
    let s:xmldeclComplType = "avalue"
    let s:xmldeclAttributeName = substitute(str, patAnameEq,
          \ "\\2", "")
    let strAttr = substitute(str, patAnameEq, "\\1", "") . " " .
          \ substitute(str, patAnameEq, "\\3", "")
    let s:xmldeclComplValue = ""
    let s:attrValueQuoting = "none"
    let s:attrValueQuoteType = "\""
  elseif search(patAvalue)  " Doplnujeme hodnotu atributu
    let patAvalue = substitute(patAvalue,
          \ "\\\\%\\%(\\#\\|\\d\\+l\\)", "", "g")
    let patAvalue = substitute(patAvalue, 
          \ "\\%(\\\\%\\)\\@<=\\d\\+c", dist . "c", "g")
    " Uprava vzorku pro vyhledavani v retezci (odstranime informace
    " o pozici)
    let str = XmlMatchStr(patAvalue)
    let s:xmldeclComplType = "avalue"
    let s:xmldeclAttributeName = substitute(str, patAvalue,
          \ "\\2", "")
    let attval = substitute(str, patAvalue, "\\3", "")
    let s:xmldeclComplValue = strpart(attval, 1, strlen(attval) - 2)
    " Hodnota je uzavrena v uvozovkach
    let strAttr = substitute(str, patAvalue, "\\1", "") . 
          \ substitute(str, patAvalue, "\\4", "")
    let s:attrValueQuoting = "both"
    let s:attrValueQuoteType = strpart(attval, 0, 1)
  elseif search(patAvalueNotClosed) " Doplnujeme hodnotu atributu
    " vcetne zaviraci uvozovky
    let patAvalueNotClosed = substitute(patAvalueNotClosed,
          \ "\\\\%\\%(\\#\\|\\d\\+l\\)", "", "g")
    let patAvalueNotClosed = substitute(patAvalueNotClosed, 
          \ "\\%(\\\\%\\)\\@<=\\d\\+c", dist . "c", "g")
    " Uprava vzorku pro vyhledavani v retezci (odstranime informace
    " o pozici)
    let str = XmlMatchStr(patAvalueNotClosed)
    let s:xmldeclComplType = "avalue"
    let s:xmldeclAttributeName = substitute(str, 
          \ patAvalueNotClosed, "\\2", "")
    let attval = substitute(str, patAvalueNotClosed, "\\3", "")
    let s:xmldeclComplValue = strpart(attval, 1) " Na zacatku je 
    " uvozovka
    let strAttr = substitute(str, patAvalueNotClosed, "\\1", "") . 
          \ " " . substitute(str, patAvalueNotClosed, "\\4", "")
    let s:attrValueQuoting = "start"
    let s:attrValueQuoteType = strpart(attval, 0, 1)
  else
    echoerr "XmlParseCurrentXmlDecl: spatny vzorek"
    return "text"
  endif
    call XmlDump("xmldecl")
  return "xmldecl"
endfunction " XmlParseCurrentXmlDecl()


" Doplnovani XML deklarace (PI s cilem xml)
" Return: doplnovani
function! XmlCompleteXmlDecl()
  if s:xmldeclComplType == "aname"
  elseif s:xmldeclComplType == "avalue"
    if s:attrValueQuoting == "none"
      exe "normal i" . s:attrValueQuoteType . s:attrValueQuoteType .
          \ "a"
    elseif s:attrValueQuoting == "start"
      exe "normal i" . s:attrValueQuoteType
    endif
  else  " Neplatna hodnota
    echoerr "Spatny typ doplnovani v XML deklaraci"
    return "\<C-N>"
  endif
  call XmlWriteDictXmlDecl(s:xmlDeclFile)
  return "\<C-X>\<C-K>"
endfunction " XmlCompleteXmlDecl()


" Zapise do slovniku seznam doplnovani pro XML deklaraci.
" Param: file  soubor obsahujici definice (bez adresarove cesty)
" Return: ""
function! XmlWriteDictXmlDecl(file)
  if s:xmldeclComplType == "aname"
    let pat = "\\%^" . s:xmldeclComplValue
          \ . "%s%^\\([^:]*\\).*%\\1%p"
  elseif s:xmldeclComplType == "avalue"
    let pat = "\\%^" . s:xmldeclAttributeName . ":"
          \ . s:xmldeclComplValue . "%s%^[^:]*:\\([^:]*\\)%\\1%p"
  else
    echoerr "XmlWriteDictXmlDecl: chybny typ doplnovani"
  endif
  call system("sed -ne '" . pat . "' " . g:xmlCompletionDir . "/" . 
        \ a:file . " > " . g:xmlTemporaryDict)
  return ""
endfunction " XmlWriteDictXmlDecl(file)


" ################################################################
" #                       XML Manipulation                       #
" ################################################################

" Z retezce atributu elementu vybere definice NS.
" Param: str  retezec obsahujici atributy
" Return: seznam consu, kde klicem je jmeno NS (bez prefixu xmlns:)
"   a hodnotou hodnota atributu (URI NS).
function! XmlStr2NamespaceList(str)
  let patNamespaceDef =  "\\(" . s:patNSAttName . "\\)" . s:patEq .
        \ "\\(" . s:patAttValue . "\\)"
  let result = ListNew()
  let pos = 0
  let str = matchstr(a:str, patNamespaceDef, pos)
  while str != "" " Dokud je mozne jit dal
    let prefix = substitute(str, patNamespaceDef, "\\1", "")
    let prefix = s:XmlLocalName(prefix)
    if prefix == "xmlns"  " Default NS
      let prefix = ""
    endif
    let uri = substitute(str, patNamespaceDef, "\\2", "")
    let uri = strpart(uri, 1, strlen(uri) - 2)  " Pryc s uvozovkami
    let pos = matchend(a:str, patNamespaceDef, pos)
    " Pridame dalsi NS
    let result = ListConcat(result, ListNew(ListCons(prefix, uri))) 
    let str = matchstr(a:str, patNamespaceDef, pos)
  endwhile
  return result
endfunction


" Z retezce atributu elementu vytvori slovnik atributu.
" Param: str  retezec obsahujici (plne zadane) atributy otviraciho tagu
" Return: slovnik atributu otviraciho tagu (klicem je plne kvalifikovane
"         jmeno atributu a hodnotou je hodnota atributu)
function! XmlStr2AttributeDict(str)
  let patAttribute = "\\(" . s:patQName . "\\)" . s:patEq .
        \ "\\(" . s:patAttValue . "\\)"
  let dict = ListNew()
  let pos = 0
  let str = matchstr(a:str, patAttribute, pos)
  while str != "" " Dokud je mozne jit dal
    let name = substitute(str, patAttribute, "\\1", "")
    if name =~ s:patNSAttName
      continue  " Deklarace jmennych prostoru nechceme
    endif
    let value = substitute(str, patAttribute, "\\2", "")
    let value = strpart(value, 1, strlen(value) - 2)
    let pos = matchend(a:str, patAttribute, pos)
    " Pridame dalsi atribut
    let dict = ListConcat(dict, ListNew(ListCons(name, value)))
    let str = matchstr(a:str, patAttribute, pos)
  endwhile
  return dict
endfunction " XmlStr2AttributeDict(str)


" Porovna prvek seznamu a zadany retezec
" Param: elem  prvek seznamu
" Param: str  retezec k porovnani
" Return: 1, pokud se prvek rovna retezci, jinak 0
function! XmlCarEq(elem, str)
  if ListCar(a:elem) == a:str
    return 1
  endif
  return 0
endfunction " XmlCarEq(elem, str)


" Zjisti lokalni cast kvalifikovaneho jmena.
" Param: qname  plne kvalifikovane jmeno
" Return: lokalni cast jmena
function! s:XmlLocalName(qname)
  let delim = strridx(a:qname, ":") + 1
  if delim == 0  " Zadny NS
    return a:qname
  endif
  return strpart(a:qname, delim)
endfunction " s:XmlLocalName(qname)


" Zjisti prefix jmenneho prostoru kvalifikovaneho jmena.
" Param: qname  plne kvalifikovane jmeno
" Return: prefix NS, pokud je pritomen
function! s:XmlNamespacePrefix(qname)
  let delim = strridx(a:qname, ":")
  if delim == -1  " Zadny NS
    return ""
  endif
  return strpart(a:qname, 0, delim)
endfunction " s:XmlNamespacePrefix(qname)


" Provede 'zkulturneni' seznamu NS:
" * prevede definice zadane pomoci dalsiho prefixu na odpovidajici URI 
" * odstrani duplicitni definice prefixu
" TODO: prevadet prazdne NS na neco rozpoznatelneho, napr. mezeru nebo
" vykricnik
" TODO: doplnit 
" Return: pocet prevadenych prefixu, ke kterym se nepodarilo najit URI
function! XmlPatchNamespaces()
  " Prozatim jen spoji jmenne prostory akt. elementu a rodic. elementu
  let s:stagNamespaceList = ListConcat(
        \ s:stagNamespaceList, s:stagTempNamespaceList)
  return 0
endfunction


" V zadanem slovniku vyhleda 1. polozku, jejiz car se rovna a:value. 
" Param: dict  Prohledavany slovnik (implementacne seznamu consu)
" Param: value  vyhledavana hodnota
" Return: URI svazane s prefixem nebo "", nebyl-li prefix nalezen
function! XmlDictLookup(dict, value)
  return ListCdar(ListFilter(a:dict, "XmlCarEq", a:value))
endfunction


" V zadanem kvalifikovanem jmene atributu nahradi prefix NS 
" odpovidajici URI
" podle Clarkovy notace ({uri}local-name). Vyjimkou je jmeno bez
" prefixu, kde prida na zacatek jmena prazdne slozene zavorky.
" K vyhledani URI pouziva slovnik s:stagNamespaceList.
" Param: name  kvalifikovane jmeno
" Return: kvalifikovane jmeno v Clarkove notaci
function! XmlQualifiedAttributeName(name)
  let prefix = s:XmlNamespacePrefix(a:name)
  if prefix != ""
    let uri = XmlDictLookup(s:stagNamespaceList, prefix)
  else
    let uri = ""
  endif
  return "{" .  uri . "}" . s:XmlLocalName(a:name)
endfunction " XmlQualifiedAttributeName(name)


" Spoji prvky seznamu do retezce. Mezi kazde dva prvky vklada dany
" oddelovaci retezec.
" Warning: Zpetne lomitko je treba escapovat, tj. pokud chceme jako
"          oddelovac \, musime zadat \\
" Param: list  seznam
" Param: string  oddelovaci retezec
" Return: retezec prvku seznamu
" TODO: presunout do cons.vim
" TODO: upravit pro prochazeni do hloubky
function! XmlListJoin(list, string)
  if !ListNull(a:list)
    let car = ListCar(a:list)
    let cdr = ListCdr(a:list)
    if ListNull(cdr) " Jednoprvkovy seznam
      return car
    else
      return car . a:string . XmlListJoin(cdr, a:string)
    endif
  endif
  return ""
endfunction


" ###############################################################
"                     Auxiliary functions
" ###############################################################

" Pocet znaku mezi pozicemi line1:col1 a line2:col2 bez koncu
" radku nebo -1, pokud je nektera pozice neplatna.
" Warning: Pouziva fci line2byte(), ktera je dostupna pouze pri 
" zkompilovani s +byte_offset.
" Param: line1  cislo radku 1. pozice
" Param: col1  cislo sloupce 1. pozice
" Param: line2  cislo radku 2. pozice
" Param: col2  cislo sloupce 2. pozice
" Return: Pocet znaku mezi obema pozicemi bez koncu radku
function! XmlDistance(line1, col1, line2, col2)
  let dist = 0
  " Nejake kontroly
  if (a:line1 < 1) || (a:line2 > line("$"))
    return -1
  endif
  " Kontrola pozic
  let line1 = a:line1
  let line2 = a:line2
  let col1 = a:col1
  let col2 = a:col2
  if line1 > line2
    let line2 = a:line1
    let line1 = a:line2
  elseif line1 == line2
    if col1 > col2
      let col1 = a:col2
      let col2 = a:col1
    elseif col1 == col2
      return 0  " Tataz pozice
    endif
  endif
  if exists("*line2byte")  " Rychlejsi zpusob
    let offset1 = line2byte(line1)
    let offset2 = line2byte(line2)
    let eolsize = 1
    if &fileformat == "dos"
      let eolsize = 2
    endif
    let dist = offset2 - offset1 - (line2 - line1) * eolsize
  else
    let i = line1 + 0
    while i < line2 + 0
      let dist = dist + strlen(getline(i))
      let i = i + 1
    endwhile
  endif
  return dist - col1 + col2
endfunction " XmlDistance(line1, col1, line2, col2)


" Na pozici kurzoru najde definici XML tagu.
" Param: pattern  hledany vzorek
" Reg: m
" Return: Retezec vyhovujici vzorku nebo ""
function! XmlMatchStr(pattern)
  " let oldwrap = &wrapscan
  let lnum = line(".")
  let cnum = col(".")
  " set nowrapscan
  if search("<", "W")
    let elnum = line(".")
    call cursor(lnum, cnum)
  else
    let elnum = line("$")
  endif
  exe "silent .," . elnum . "yank m"
  " let &wrapscan = oldwrap
  let str = strpart(@m, cnum - 1)
  let str = substitute(str, "\n", " ", "g")
  return matchstr(str, a:pattern)
endfunction " XmlMatchStr(pattern)


" Porovna dve pozice v souboru.
" Warning: Pouziva fci line2byte(), ktera je dostupna pouze pri 
" zkompilovani s +byte_offset.
" Param: line1  cislo radku 1. pozice
" Param: col1  cislo sloupce 1. pozice
" Param: line2  cislo radku 2. pozice
" Param: col2  cislo sloupce 2. pozice
" Return: -1, 0, 1
function! XmlComparePos(line1, col1, line2, col2)
  let offset1 = line2byte(a:line1) + a:col1
  let offset2 = line2byte(a:line2) + a:col2
  if offset1 < offset2
    return -1
  elseif offset1 == offset2
    return 0
  endif
  return 1
endfunction


" ###############################################################
" #                       Setting Functions                     # 
" ###############################################################

" Prida mapovani jmenneho prostoru na definicni soubor na zacatek 
" definicniho seznamu.
" Param: ns   uri jmenneho prostoru
" Param: file   definicni soubor
" Var: s:nslist  novou polozku prida na zacatek seznamu
" Return: 0
function! XmlAddNamespaceDef(ns, file)
  let s:nslist = ListCons(ListCons(a:ns, a:file), s:nslist)
endfunction


" Prida mapovani SYSTEM id na definicni soubor na zacatek definicniho 
" seznamu.
" Param: dt   SYSTEM identifikator
" Param: file   definicni soubor
" Var: s:dtsyslist  novou polozku prida na zacatek seznamu
" Return: 0
function! XmlAddDoctypeSystemDef(dt, file)
  let s:dtsyslist = ListCons(ListCons(a:dt, a:file), s:dtsyslist)
endfunction


" Prida mapovani PUBLIC id na definicni soubor na zacatek definicniho 
" seznamu.
" Param: dt  PUBLIC identifikator
" Param: file  definicni soubor
" Var: s:dtpublist  novou polozku prida na zacatek seznamu
" Return: 0
function! XmlAddDoctypePublicDef(dt, file)
  let s:dtpublist = ListCons(ListCons(a:dt, a:file), s:dtpublist)
endfunction


" Prida mapovani cile (jmena) procesni instrukce na definicni soubor
" na zacatek definicniho seznamu.
" Param: target  cil PI
" Param: file  definicni soubor
" Var: s:pilist  novou polozku prida na zacatek seznamu
" Return: 0
function! XmlAddPITargetDef(target, file)
  let s:pilist = ListCons(ListCons(a:target, a:file), s:pilist)
endfunction


" ###############################################################
" #                           Debug                             #
" ###############################################################

" Vyhleda vzorek
" Param: pattern  Hledany vzorek
function! XmlTestPattern(pattern)
  let @/ = s:pat{a:pattern}
  set hlsearch
endfunction


" Vytiskne obsah vsech promennych tykajicich se daneho typu doplnovani
" Param: type  typ doplnovani, jeden z "stag", "etag", ...
" Return: ""
function! XmlDump(type)
  let vars = ListNew()
  echohl WarningMsg
  if a:type == "stag"
    let vars = ListNew("stagTempElementName", "stagTempEmptyElement")
    call XmlDictDump("stagTempNamespaceList")
  elseif a:type == "curstag"
    let vars = ListNew("stagElementName", 
          \ "stagEmptyElement",
          \ "stagAttributeName", 
          \ "stagComplType", "stagComplValue",
          \ "attrValueQuoting", "attrValueQuoteType")
    call XmlDictDump("stagNamespaceList")
  elseif a:type == "etag"
    let vars = ListNew("etagElementName", "etagComplValue",
          \ "etagHasEndBracket")
  elseif a:type == "xmldecl"
    let vars = ListNew("xmldeclAttributeName", "xmldeclComplType",
          \ "xmldeclComplValue",
          \ "attrValueQuoting", "attrValueQuoteType")
  endif
  call ListMap(vars, "XmlDumpPrint")
  echohl None
  return
endfunction


" Param: item  Jmeno skriptove promenne bez uvodniho "s:"
" Return: ""
function! XmlDumpPrint(item)
  exe "let tmp = s:" . a:item
  echo a:item . " = '" . tmp . "'"
  return
endfunction


" Vytiskne obsah slovniku
" Param: dict  slovnik k vytisteni
" Return: ""
function! XmlDictDump(dict)
  echo a:dict . " = {\n"
  if exists("g:" . a:dict)
    call ListMap(g:{a:dict}, "XmlDictPrintItem")
  elseif exists("s:" . a:dict)
    call ListMap(s:{a:dict}, "XmlDictPrintItem")
  endif
  echo "}"
  return
endfunction


function! XmlDictPrintItem(item)
  echo "  \"" . ListCar(a:item) . "\" => \"" . ListCdr(a:item) . 
        \ "\",\n"
endfunction


" Tiskne pozici v textu.
function! XmlPrintPos(...)
  if a:0 == 0
    let lnum = line(".")
    let cnum = virtcol(".")
  elseif a:0 == 1  " Zadana pozice
    let lnum = line(a:1)
    let cnum = virtcol(a:1)
  elseif a:0 == 2  " Zadana pozice
    let lnum = a:1
    let cnum = a:2
  endif
  return "(" . lnum . "," . cnum . ")"
endfunction


" ################################################################
" #                            Settings                          #
" ################################################################

call XmlAddNamespaceDef("http://www.w3.org/1999/XSL/Transform",
      \ "xslt-1.0")
call XmlAddNamespaceDef("http://www.w3.org/1999/XSL/Format", "fo-1.0")
call XmlAddNamespaceDef("http://www.w3.org/2001/XMLSchema", "wxs-1.0")
" call XmlAddNamespaceDef("http://www.w3.org/2001/XMLSchema-instance",
        " \ "xschema-instance-1.0")
call XmlAddNamespaceDef("http://www.w3.org/1999/xlink", "xlink-1.0")
call XmlAddNamespaceDef("http://www.w3.org/2001/XInclude",
	\ "xinclude-1.0")
call XmlAddNamespaceDef("http://www.w3.org/1998/math/MathML",
	\ "mathml-2.0")
call XmlAddNamespaceDef("http://www.w3.org/2000/svg", "svg-1.1")
call XmlAddNamespaceDef("http://www.w3.org/1999/xhtml",
	\ "xhtml-1.1")
call XmlAddNamespaceDef("http://relaxng.org/ns/structure/1.0",
        \ "relaxng-1.0")
call XmlAddDoctypeSystemDef(
        \ "http://www.oasis-open.org/docbook/xml/4.2/docbookx.dtd",
	\ "docbook-4.2")
call XmlAddDoctypeSystemDef(
        \ "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd", "svg-1.1")
call XmlAddDoctypePublicDef("-//OASIS//DTD DocBook XML V4.2//EN",
	\ "docbook-4.2")
call XmlAddDoctypePublicDef("-//W3C//DTD SVG 1.1//EN", "svg-1.1")
call XmlAddDoctypePublicDef("-//W3C//DTD XHTML 1.0 Strict//EN", 
      \ "xhtml-1.1")

call XmlAddPITargetDef("php", "php-4.0.6.dict")

inoremap <C-J> <C-R>=XmlComplete()<CR>

let xml_completion_loaded = 1

"vim:tw=72:sts=2:sw=2

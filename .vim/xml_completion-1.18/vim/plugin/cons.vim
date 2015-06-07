" File: cons.vim
" Author: David Tardon <xtardo00@stud.fit.vutbr.cz>
" Last Change: 13.01.2006 11:32
" Requires: Vim-6.0

" Modul pro praci s teckovymi pary a seznamy jako v Lispu nebo Schemu.
" Teckovy par (cons) je reprezentovan retezcem, kde zacatek je oznacen
" "#B", stred (tecka) "#." a konec "#E". Mrizky v obsahu jsou nahrazeny
" za "#,", aby nemohlo dojit k vyskytu vyse vypsanych kombinaci.

if exists("loaded_cons")
  finish
endif


" Nahradi vsechny vyskyty znaku "#" v retezci dvojici "#,".
function s:Escape(str)
  if a:str == ""
    return ""
  endif
  return substitute(a:str, "#", "\#,", "g")
endfunction " s:Escape(str)


" Nahradi vsechny vyskyty dvojice znaku "#," v retezci znakem "#".
function s:UnEscape(str)
  if a:str == ""
    return ""
  endif
  return substitute(a:str, "\#,", "#", "g")
endfunction " s:UnEscape(str)


function s:IsList(list)
  if match(a:list, "^#B.*#\..*#E$") == 0
    return 1
  endif
endfunction " s:IsList(list)


" Vraci pozici ridici sekvence "#." odpovidajici pocatecnimu "#B" 
" v zadanem seznamu.
" function s:DotPos(aList)
  " let begins = 1
  " let pos = 2 " Vynechame uvodni #B
  " while begins
    " let pos = matchend(a:aList, "\#[BE\.]", pos)  " Preskocime 
    " nasledujici ridici sekvenci
    " let char = strpart(a:aList, pos - 1, 1) " Podivame se, co to bylo
    " if char == "B"  " Dalsi vnoreny cons
      " let begins = begins + 1
    " elseif char == "."
      " if begins == 1  " Nasli jsme
        " let begins = 0
      " endif
    " elseif char == "E"  " Uzavirame jednu uroven
      " let begins = begins - 1
    " else  " Chyba
      " echoerr "Neco je spatne (str=\"" . a:aList . "\", begins=". begins
        " \ . ", char=" . char . ", pos =" . pos . ")"
    " endif
  " endwhile
  " return pos - 2  " Posledni hledani nastavilo pozici dva znaky za #.
" endfunction " s:DotPos(aList)


" Konstruktor teckoveho paru (consu). Vraci retezec obsahujici dany cons.
function! ListCons(car, cdr)
  return "#B" . s:Escape(a:car . "") . "#." . s:Escape(a:cdr . "") . "#E"
  " Zretezeni parametru s "" je kvuli hodnote 0, kterou fce bere jako
  " prazdny retezec (a predava ji tak do s:Escape).
endfunction " ListCons(car, cdr)


" Predikat prazdnosti seznamu.
" Vraci 1, je-li seznam prazdny.
function! ListNull(list)
  if a:list == ""
    return 1
  endif
endfunction " ListNull(list)


" Vraci prvni prvek seznamu. V pripade prazdneho seznamu vraci prazdny
" seznam.
function! ListCar(list)
  if ListNull(a:list)
    return ""
  endif
  return s:UnEscape(strpart(a:list, 2, stridx(a:list, "\#.") - 2))
endfunction " ListCar(list)


" Vraci prvni prvek seznamu. V pripade prazdneho seznamu vraci prazdny
" seznam.
function! ListCdr(list)
  if ListNull(a:list)
    return ""
  endif
  let cdrBegin = stridx(a:list, "\#.") + 2 " Pozice za teckou
  let cdrLen = strlen(a:list) - cdrBegin - 2 " Odecte koncove #E
  " return s:UnEscape(strpart(a:aList, carLen, strlen(a:aList) - carLen - 2))
  return s:UnEscape(strpart(a:list, cdrBegin, cdrLen))
endfunction " ListCdr(list)


" Vraci seznam argumentu nebo prazdny seznam. Maximalni mozny pocet 
" argumentu je 20 (viz omezeni vimu). Pro konstrukce delsich seznamu
" je treba pouzit kombinaci ListNew() a ListConcat().
function! ListNew(...)
  if a:0 == 0
    return ""
  endif
  let i = a:0
  let result = ""
  while i
    let result = ListCons(a:{i}, result)
    let i = i - 1
  endwhile
  return result
endfunction " ListNew(...)


" Vraci n-ty prvek seznamu. Je-li seznam prazdny nebo kratsi nez n,
" vraci prazdny seznam.
" Prvky jsou pocitany od 1.
function! ListNth(list, n)
  if ListNull(a:list)
    return ""
  elseif a:n <= 0
    return ""
  elseif a:n == 1
    return ListCar(a:list)
  endif
  return ListNth(ListCdr(a:list), a:n - 1)
endfunction " ListNth(list, n)


" Zretezeni dvou seznamu
function! ListConcat(list1, list2)
  if ListNull(a:list1)
    return a:list2
  endif
  return ListCons(ListCar(a:list1), ListConcat(ListCdr(a:list1), a:list2))
endfunction " ListConcat(list1, list2)


" Vraci seznam v opacnem poradi.
function! ListReverse(list)
  let reverse = ListNew() " Navratova hodnota
  let verse = a:list
  while ! ListNull(verse)
    let reverse = ListCons(ListCar(verse), reverse) " Postupne odebira
    " prvky ze zacatku seznamu a vklada je na zacatek vysledneho 
    " seznamu.
    let verse = ListCdr(verse)
  endwhile
  return reverse
endfunction " ListReverse(list)


" Pristupove zkratky jako v clispu
function! ListCaar(list)
  return ListCar(ListCar(a:list))
endfunction

function! ListCadr(list)
  return ListCar(ListCdr(a:list))
endfunction

function! ListCdar(list)
  return ListCdr(ListCar(a:list))
endfunction

function! ListCaaar(list)
  return ListCar(ListCar(ListCar(a:list)))
endfunction

function! ListCaadr(list)
  return ListCar(ListCar(ListCdr(a:list)))
endfunction

function! ListCadar(list)
  return ListCar(ListCdr(ListCar(a:list)))
endfunction

function! ListCaddr(list)
  return ListCar(ListCdr(ListCdr(a:list)))
endfunction

function! ListCaaaar(list)
  return ListCar(ListCar(ListCar(ListCar(a:list))))
endfunction

function! ListCaaadr(list)
  return ListCar(ListCar(ListCar(ListCdr(a:list))))
endfunction

function! ListCaadar(list)
  return ListCar(ListCar(ListCdr(ListCar(a:list))))
endfunction

function! ListCaaddr(list)
  return ListCar(ListCar(ListCdr(ListCdr(a:list))))
endfunction

function! ListCadaar(list)
  return ListCar(ListCdr(ListCar(ListCar(a:list))))
endfunction

function! ListCadadr(list)
  return ListCar(ListCdr(ListCar(ListCdr(a:list))))
endfunction

function! ListCaddar(list)
  return ListCar(ListCdr(ListCdr(ListCar(a:list))))
endfunction

function! ListCadddr(list)
  return ListCar(ListCdr(ListCdr(ListCdr(a:list))))
endfunction


" Nad kazdym prvkem seznamu a:list provede operaci danou funkci a:func
" (pripadne dalsi parametry funkce se predavaji ze zbytku parametru 
" ListMap).
" Vraci seznam takovychto prvku.
function! ListMap(list, func, ...)
  if ListNull(a:list)
    return a:list
  endif
  let param = ""  " Dalsi parametry pro predikat
  let delim = ""
  if a:0 > 0  " Mame nejake parametry navic
    let i = 1
    while i <= a:0 " Sestavime retezec doplnkovych parametru
      let param = param . ",\"" . a:{i} . "\""  " Parametry jako retezce
      let i = i + 1
    endwhile
    let delim = ","
    let param = strpart(param, 1) " Odstran uvodni carku
  endif
  let car = ListCar(a:list)
  exe "let result = " . a:func . "(\"" . car . "\"" . delim . param . ")"
  if a:0 != 0  " Byly nejake dalsi parametry
    exe "let result = ListCons(\"" . result . "\", ListMap(ListCdr(\"" .
          \ a:list . "\"),\"" . a:func . "\"," . param . "))"
    return result
  else
    return ListCons(result, ListMap(ListCdr(a:list), a:func))
  endif
endfunction " ListMap(list, func, ...)


" Vraci seznam vsech prvku seznamu a:list vyhovujicich predikatu 
" a:func(car(a:list), ...).
function! ListFilter(list, func, ...)
  " echoerr "Paramcount = " . a:0
  if ListNull(a:list)
    return a:list
  endif
  let param = ""  " Dalsi parametry pro predikat
  let delim = ""
  if a:0 > 0  " Mame nejake parametry navic
    let i = 1
    while i <= a:0 " Sestavime retezec doplnkovych parametru
      let param = param . ",\"" . a:{i} . "\""
      let i = i + 1
    endwhile
    let delim = ","
    let param = strpart(param, 1) " Odstran uvodni carku
  endif
  let car = ListCar(a:list)
  exe "let cond = " . a:func . "(\"" . car . "\"" . delim . param . ")"
  if a:0 != 0  " Byly nejake dalsi parametry
    let remainder = ListNew()
    exe "let remainder = ListFilter(ListCdr(\"" . a:list . "\"), \""
          \ . a:func . "\"," . param . ")"
    if cond
      return ListCons(car, remainder)
    else
      " return ListFilter(ListCdr(a:list), a:func, param)
      return remainder
    endif
  else
    if cond
      return ListCons(car, ListFilter(ListCdr(a:list), a:func))
    else
      return ListFilter(ListCdr(a:list), a:func))
    endif
  endif
endfunction " ListFilter(list, func, ...)


" Vraci delku seznamu a:list.
function! ListLength(list)
  if ListNull(a:list)
    return 0
  else
    return 1 + ListLength(ListCdr(a:list))
endfunction


" Vraci true, je li a:list seznam.
function! ListListp(list)
  return s:IsList(a:list)
endfunction


" let loaded_cons = 1

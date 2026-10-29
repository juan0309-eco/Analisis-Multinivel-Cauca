*==============================================================================
* 15c_figuras.do
* C6: Figuras 6 y 7 reestimadas con M4r, en el formato del informe.
*
* CAMBIOS RESPECTO DE 15b_lecturas.do (bloque [3])
*   - Sin title() ni note() dentro de la imagen. En el informe el número y el
*     título van en el párrafo de estilo "Rotulo" encima de la figura, y el pie
*     en el párrafo de estilo "Nota" debajo (APA 7). Nada de eso va en el PNG.
*   - La Figura 6 vuelve a ser el INTERCEPTO de la sede, como en el informe
*     actual ("Efectos aleatorios de sede ordenados por magnitud"), no el
*     gradiente. El 15b graficó el gradiente por error.
*   - La Figura 7 recupera la orientación del informe: intercepto en el eje Y,
*     pendiente en el eje X.
*   - Mismas opciones de ejes y de esquema que el bloque [6] del
*     09_tablas_graficos_v5.do, para que no desentonen con las demás.
*   - xsize/ysize fijados para que al insertarlas a 5,9 pulgadas de ancho
*     queden con la misma altura que las Figuras 3 a 7 actuales.
*
* ENTRADA : Efectos_sede_M4r_20261013.dta   Base_Estimacion.dta
* SALIDAS : log_15c_figuras_AAAAMMDD_HHMM.log
*           Fig6_efectos_sede_C6_AAAAMMDD.png
*           Fig7_int_pend_C6_AAAAMMDD.png
*           Fig7_int_pend_C6_sincolor_AAAAMMDD.png   (versión sin leyenda)
*==============================================================================
version 17
clear all
set more off
set varabbrev off
if "$TESIS_CONFIG" == "" do "C:\Users\RYZEN 5\Desktop\Tesis Multinivel\Definitivo\00_config.do"
cd "$RAIZ"

local fin = "20261013"          // fecha de los archivos de 15 y 15b

capture log close _all
local f = string(date(c(current_date),"DMY"),"%tdCCYYNNDD")
local h = subinstr(substr(c(current_time),1,5),":","",.)
log using "log_15c_figuras_`f'_`h'.log", text name(fase15c)
display "Inicio: " c(current_date) " " c(current_time)

*------------------------------------------------------------------------------
* [1] ZONA DE CADA SEDE (para la versión coloreada de la Figura 7)
*------------------------------------------------------------------------------
use "Base_Estimacion.dta", clear
mi extract 1, clear
collapse (mean) rural, by(cole_cod_dane_sede)
tempfile sedes
save "`sedes'"

*------------------------------------------------------------------------------
* [2] EFECTOS ALEATORIOS DE M4r
*------------------------------------------------------------------------------
use "Efectos_sede_M4r_`fin'.dta", clear
merge 1:1 cole_cod_dane_sede using "`sedes'", keep(master match)
tabulate _merge
drop _merge

label variable b_int  "Efecto aleatorio del intercepto de la sede"
label variable b_pend "Efecto aleatorio de la pendiente de la sede"

display _newline "--- Descriptivos de los efectos predichos (BLUP, imputación 1) ---"
summarize b_int b_pend se_int se_pend
correlate b_int b_pend

*------------------------------------------------------------------------------
* [3] FIGURA 6: interceptos de sede ordenados
*     Mismas opciones que el bloque [6] del 09: banda gris, línea negra,
*     yline(0) discontinua, sin leyenda y sin título dentro de la imagen.
*------------------------------------------------------------------------------
sort b_int
generate long rango = _n
generate double lo = b_int - 1.96*se_int
generate double hi = b_int + 1.96*se_int

twoway (rarea lo hi rango, color(gs13))                                      ///
       (line b_int rango, lcolor(black)),                                    ///
    yline(0, lpattern(dash) lcolor(gs8))                                     ///
    legend(off)                                                              ///
    ytitle("Efecto aleatorio de la sede (puntos)")                           ///
    xtitle("Sedes ordenadas por su efecto estimado")                         ///
    xsize(5.9) ysize(4.1)                                                    ///
    name(g_caterpillar, replace)
graph export "Fig6_efectos_sede_C6_`f'.png", replace width(2000)

display _newline "--- Sedes con mayor efecto positivo ---"
gsort -b_int
list sede_id b_int in 1/5, clean noobs
display _newline "--- Sedes con mayor efecto negativo ---"
sort b_int
list sede_id b_int in 1/5, clean noobs

*------------------------------------------------------------------------------
* [4] FIGURA 7: intercepto frente a pendiente
*     Orientación del informe: intercepto en Y, pendiente en X.
*     Se exportan dos versiones; elija una sola para el documento.
*------------------------------------------------------------------------------

* (a) Versión idéntica a la del informe actual: un solo color, sin leyenda.
twoway (scatter b_int b_pend, msymbol(oh) mcolor(gs6))                       ///
       (lfit b_int b_pend, lcolor(black)),                                   ///
    legend(off)                                                              ///
    ytitle("Intercepto de la sede")                                          ///
    xtitle("Pendiente socioeconómica de la sede")                            ///
    xsize(5.9) ysize(4.1)                                                    ///
    name(g_grad_sincolor, replace)
graph export "Fig7_int_pend_C6_sincolor_`f'.png", replace width(2000)

* (b) Versión distinguiendo zona. La diferencia entre sedes rurales y urbanas
*     es el resultado nuevo de C6, de modo que aquí la leyenda sí aporta.
twoway (scatter b_int b_pend if rural <  0.5, msymbol(oh) mcolor(gs6))       ///
       (scatter b_int b_pend if rural >= 0.5, msymbol(th) mcolor(gs10))      ///
       (lfit b_int b_pend, lcolor(black)),                                   ///
    legend(order(1 "Urbana" 2 "Rural") rows(1) size(small) region(lstyle(none))) ///
    ytitle("Intercepto de la sede")                                          ///
    xtitle("Pendiente socioeconómica de la sede")                            ///
    xsize(5.9) ysize(4.1)                                                    ///
    name(g_grad_color, replace)
graph export "Fig7_int_pend_C6_`f'.png", replace width(2000)

display _newline "--- Correlación de los efectos predichos, por zona ---"
correlate b_int b_pend
foreach z in 0 1 {
    display _newline "rural = `z':"
    capture noisily correlate b_int b_pend if (rural >= 0.5) == `z'
}

display _newline "Fin: " c(current_date) " " c(current_time)
log close fase15c

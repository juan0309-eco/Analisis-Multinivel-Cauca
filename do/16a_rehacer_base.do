********************************************************************************
* PROYECTO : Desempeno Saber 11 en sedes oficiales del Cauca, 2018-2023
* SCRIPT   : 16A - REGENERACION DE Base_Estimacion.dta (C7)
* ENTRADA  : Base_Multinivel_MI.dta  (ya actualizada por el 07c con PARCHE 3)
* SALIDA   : Base_Estimacion.dta, log_16a_rehacer_base_<hoy>.log
* STATA    : 17
********************************************************************************
* PARA QUE SIRVE
* Base_Estimacion.dta NO la produce el 07c: la produce el bloque [2] del
* 08_estimacion_v5.do. Cuando cambian las variables de Nivel 3 hay que volver
* a generarla, pero correr el 08 completo re-estimaria toda la progresion
* transversal del Objetivo 3, que son horas de computo ya hechas.
*
* Este script reproduce EXACTAMENTE el bloque [2] del 08 y nada mas. El codigo
* esta copiado literal, sin "mejoras", para que la base resultante sea
* identica a la que produjo las Tablas 8 a 13 salvo por las variables
* municipales nuevas.
*
* VERIFICACION OBLIGATORIA AL FINAL
* El tabstat de c_inse, cwc_inse, inse_prom_sede y c_inse_prom_sede debe
* coincidir con el del bloque [2.2] de log_08_estimacion.log. Si no coincide,
* PARAR: algo cambio en la base imputada y todo el Capitulo 4 estaria en
* cuestion, no solo C7.
********************************************************************************

clear all
set more off
set varabbrev off
version 17

if "$TESIS_CONFIG" == "" do "C:\Users\RYZEN 5\Desktop\Tesis Multinivel\Definitivo\00_config.do"
cd "$RAIZ"

* ----------------------------------------------------------------------
* FECHA DE LAS SALIDAS. Cambiar en cada corrida nueva.
* ----------------------------------------------------------------------
local hoy "20261019c"

* Guard: ningun log se sobrescribe nunca. Es la leccion del incidente del
* 13 de octubre, cuando un `log using ..., replace` destruyo la salida del
* bloque [7] del 10_blindaje.do.
capture log close _all
capture confirm file "log_16a_rehacer_base_`hoy'.log"
if _rc == 0 {
    display as error "Ya existe log_16a_rehacer_base_`hoy'.log."
    display as error "Cambiar el local hoy antes de volver a correr."
    exit 602
}

log using "log_16a_rehacer_base_`hoy'.log", text name(fase16a)

timer clear 1
timer on 1


********************************************************************************
* [0] VERIFICACION PREVIA: las variables nuevas tienen que estar
********************************************************************************

display _newline "{hline 78}"
display "[0] VERIFICACION DE LA ENTRADA"
display "{hline 78}"

use "Base_Multinivel_MI.dta", clear

foreach v in tasa_hom_eb tasa_hom_eb_bar tasa_hom_eb_dev ///
             iica iica_bar iica_dev {
    capture confirm variable `v'
    if _rc != 0 {
        display as error "`v' no esta en Base_Multinivel_MI.dta."
        display as error "Correr 04 v5, 06 v3 y 07c con los parches de C7"
        display as error "antes de este script."
        exit 111
    }
}
display "Las seis variables nuevas de C7 estan presentes."

quietly count
display "Filas del conjunto imputado: " r(N) " (esperadas: 1.464.750)"

mi describe


********************************************************************************
* [1] BLOQUE [2] DEL 08_estimacion_v5.do, LITERAL
********************************************************************************
* Copiado sin cambios. Los comentarios originales se conservan porque explican
* por que las derivadas se registran como IMPUTADAS y no como pasivas.

display _newline "{hline 78}"
display "[1] RECONSTRUCCION DE LAS VARIABLES DERIVADAS"
display "{hline 78}"

* `mi register passive` obliga a que las observaciones completas tengan el
* mismo valor en todas las imputaciones. Eso es correcto para una variable que
* depende solo de los datos del propio estudiante, pero no para una media de
* conglomerado, que depende de los valores imputados de sus companeros y
* cambia legitimamente entre imputaciones.
*
* La solucion: dejar las derivadas vacias en m = 0 y registrarlas como
* imputadas. Asi Stata no las sincroniza. La estimacion nunca usa m = 0.

capture drop inse_prom_sede c_inse cwc_inse c_inse_prom_sede

bysort _mi_m cole_cod_dane_sede year: egen double _prom = ///
    mean(estu_inse_individual)
generate double inse_prom_sede = _prom if _mi_m > 0
drop _prom
label variable inse_prom_sede "INSE medio de la cohorte de la sede"

bysort _mi_m year: egen double _gm = mean(estu_inse_individual)
generate double c_inse = estu_inse_individual - _gm if _mi_m > 0
drop _gm
label variable c_inse "INSE centrado en la gran media del ano"

generate double cwc_inse = estu_inse_individual - inse_prom_sede if _mi_m > 0
label variable cwc_inse "INSE centrado en la media de la sede"

bysort _mi_m year: egen double _gms = mean(inse_prom_sede)
generate double c_inse_prom_sede = inse_prom_sede - _gms if _mi_m > 0
drop _gms
label variable c_inse_prom_sede "INSE medio de la sede, centrado"

mi register imputed inse_prom_sede c_inse cwc_inse c_inse_prom_sede


********************************************************************************
* [2] VERIFICACION
********************************************************************************

display _newline "{hline 78}"
display "[2] VERIFICACION"
display "{hline 78}"

display _newline "--- El promedio de sede debe ser constante dentro de la sede-ano ---"
bysort _mi_m cole_cod_dane_sede year: egen double _sd_prom = sd(inse_prom_sede)
quietly count if _sd_prom > 1e-8 & !missing(_sd_prom)
display "Observaciones con promedio de sede inconsistente: " r(N) " (debe ser 0)"
assert r(N) == 0
drop _sd_prom

quietly count if _mi_m > 0 & missing(c_inse)
display "Valores faltantes de c_inse en las imputaciones: " r(N) " (debe ser 0)"
assert r(N) == 0

display _newline "{hline 78}"
display "COMPARAR ESTE TABSTAT CON log_08_estimacion.log, BLOQUE [2.2]."
display "Si no coincide, PARAR: la base imputada cambio."
display "{hline 78}"
tabstat c_inse cwc_inse inse_prom_sede c_inse_prom_sede if _mi_m == 1, ///
    stat(n mean sd min max) format(%9.4f)


********************************************************************************
* [3] IDENTIFICADORES DE NIVEL
********************************************************************************

capture drop sede_id mcpio_id
egen long sede_id  = group(cole_cod_dane_sede)
egen long mcpio_id = group(cole_cod_mcpio_ubicacion)
mi register regular sede_id mcpio_id

display _newline "--- Identificadores ---"
quietly levelsof mcpio_id if _mi_m == 1, local(mm)
display "Municipios: " wordcount("`mm'") " (esperados: 42)"
quietly levelsof sede_id if _mi_m == 1, local(ss)
display "Sedes: " wordcount("`ss'") " (esperadas: 437)"


********************************************************************************
* [4] CONTROL DE LAS VARIABLES NUEVAS DE C7
********************************************************************************

display _newline "{hline 78}"
display "[4] VARIABLES NUEVAS DE C7 EN LA BASE DE ESTIMACION"
display "{hline 78}"

tabstat tasa_homicidios tasa_hom_eb iica if _mi_m == 1, ///
    by(year) stat(n mean sd) format(%9.4f)

foreach v in tasa_hom_eb_bar tasa_hom_eb_dev iica_bar iica_dev {
    quietly count if _mi_m > 0 & missing(`v')
    display "  `v': filas sin valor en m>0 = " r(N)
}

* Deben ser constantes dentro de cada municipio-ano, como el resto del Nivel 3.
bysort _mi_m cole_cod_mcpio_ubicacion year: egen double _sd_eb = sd(tasa_hom_eb)
quietly count if _sd_eb > 1e-10 & !missing(_sd_eb)
display _newline "Municipio-ano con tasa suavizada no constante: " r(N) " (debe ser 0)"
assert r(N) == 0
drop _sd_eb


********************************************************************************
* [5] GUARDADO
********************************************************************************

* Los bloques de variables se redefinen en cada script que las use: las
* globales NO se guardan dentro del .dta.
global v_n1 mujer edad repitente lectura_30min libros_26omas ///
            trabaja_mas20 internet_hogar computador_hogar

global v_n2 ln_matricula ratio_alumnos_docente pct_planta z_posgrado ///
            dotacion_tic rural ju_unica tecnico tecnico_academico ///
            cole_femenino

compress
save "Base_Estimacion.dta", replace

timer off 1
display _newline "--- Tiempo total ---"
timer list 1

display _newline "{hline 78}"
display "Base_Estimacion.dta REGENERADA con las variables de C7."
display "Siguiente: 16_territorial.do"
display "{hline 78}"

log close fase16a

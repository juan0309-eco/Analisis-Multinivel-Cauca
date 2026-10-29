********************************************************************************
* PROYECTO : Desempeno Saber 11 en sedes oficiales del Cauca, 2018-2023
* SCRIPT   : 11C - PENDIENTES ANUALES DE LA VULNERABILIDAD (TABLA 14) (C1)
* ENTRADA  : ML4b.ster, generado por el bloque [2] de 11_estructura_aleatoria.do
* SALIDA   : log_11c_tabla14.log y Tabla14_C1.dta
* STATA    : 17
********************************************************************************
* QUE RESUELVE
* La Tabla 14 del informe reporta, para cada cohorte, la pendiente de la
* vulnerabilidad dentro del municipio: la suma del termino principal y su
* interaccion con el ano, con el error estandar de esa combinacion lineal.
*
* Esas cifras provienen de ML4, la especificacion de dos componentes aleatorios.
* ML4b ya esta estimado con la estructura nueva, pero el bloque [2] del 11 solo
* guardo el .ster y el contraste conjunto; las combinaciones lineales por ano no
* se calcularon. Este script las extrae sin reestimar nada.
*
* TIEMPO: segundos.
********************************************************************************

clear all
set more off
set varabbrev off
version 17

if "$TESIS_CONFIG" == "" do "C:\Users\RYZEN 5\Desktop\Tesis Multinivel\Definitivo\00_config.do"
cd "$RAIZ"

capture log close _all
local tarea "11c_tabla14"
local hoy   "20261024"          // <<< etiqueta de la proxima corrida

capture confirm file "log_`tarea'_`hoy'.log"
if _rc == 0 {
    display as error "Ya existe log_`tarea'_`hoy'.log."
    display as error "Cambiar el local hoy (por ejemplo, anadir un sufijo b, c...)."
    exit 602
}
log using "log_`tarea'_`hoy'.log", text name(fase11c)

display _newline "{hline 78}"
display "PENDIENTES ANUALES DE LA VULNERABILIDAD DENTRO DEL MUNICIPIO (ML4b)"
display "{hline 78}"

capture confirm file "ML4b.ster"
if _rc != 0 {
    display as error "ML4b.ster no existe. Correr el bloque [2] del 11 primero."
    exit 601
}

estimates use "ML4b.ster"

display _newline "--- Parametros disponibles ---"
display "Revisar los nombres antes de confiar en cualquier lincom."
matrix list e(b), nonames format(%9.4f)

tempname p14
postfile `p14' int year double b se z p lb ub using "Tabla14_C1.dta", replace

* 2018 es la categoria de referencia: la pendiente es el termino principal solo.
display _newline "{hline 60}"
display "2018 (categoria de referencia)"
display "{hline 60}"
lincom vuln_dev
post `p14' (2018) (r(estimate)) (r(se)) (r(estimate)/r(se)) ///
    (2*normal(-abs(r(estimate)/r(se)))) (r(lb)) (r(ub))

foreach a in 2019 2020 2021 2022 2023 {
    display _newline "{hline 60}"
    display "`a'"
    display "{hline 60}"
    capture noisily lincom vuln_dev + `a'.year#c.vuln_dev
    if _rc == 0 {
        post `p14' (`a') (r(estimate)) (r(se)) (r(estimate)/r(se)) ///
            (2*normal(-abs(r(estimate)/r(se)))) (r(lb)) (r(ub))
    }
    else {
        display as error "Fallo el lincom de `a'. Revisar el nombre del"
        display as error "termino de interaccion en el matrix list de arriba."
    }
}

postclose `p14'

display _newline(2) "{hline 78}"
display "TABLA 14 CON LA ESTRUCTURA NUEVA"
display "{hline 78}"

use "Tabla14_C1.dta", clear
format b se z p lb ub %9.4f
generate str24 ic = "[" + string(lb, "%6.2f") + "; " + string(ub, "%6.2f") + "]"
list year b se ic p, clean noobs

display _newline "Las tres columnas que pide la Tabla 14 son: Pendiente (b),"
display "Intervalo de confianza (ic) y p. El error estandar va entre"
display "parentesis debajo de la pendiente, como en el resto del capitulo."
display _newline "Recordatorio: el contraste conjunto de las cinco interacciones"
display "en ML4b da chi2(5) = 0,96 con p = 0,965, de modo que ninguna pendiente"
display "anual sostiene una conclusion por si sola, aunque alguna se acercara"
display "al umbral."

log close fase11c

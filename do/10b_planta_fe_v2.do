********************************************************************************
* PROYECTO : Desempeño Saber 11 en sedes oficiales del Cauca, 2018-2023
* SCRIPT   : 10b - CORRECCIÓN DEL BLOQUE [7] DEL BLINDAJE  (versión 2)
* ENTRADA  : Base_Multinivel_PCA.dta
* SALIDA   : log_10b_planta_fe.log
* STATA    : 17
********************************************************************************
* LOS DOS ERRORES CORREGIDOS
*
* (1) r(451), "repeated time values within panel".
*     `Base_Multinivel_PCA.dta` está a nivel de ESTUDIANTE, así que la
*     combinación sede-año no identifica las filas. Para `xtreg, fe` basta con
*     declarar la unidad de los efectos fijos: `xtset sede_id`, sin variable de
*     tiempo. Los efectos de año entran igual como indicadoras.
*
* (2) r(111), "c_inse not found".
*     `c_inse` no existe en esta base. Se construye en el script 08, sobre el
*     conjunto YA IMPUTADO, porque allí depende de los valores imputados del
*     índice socioeconómico. Aquí, que se trabaja sobre casos completos, hay
*     que construirlo desde `estu_inse_individual` con la misma definición:
*     el índice menos la media general de su año.
*
* POR QUÉ ESTE EJERCICIO NO REEMPLAZA AL MODELO PRINCIPAL
* Corre sobre casos completos, no sobre las veinte imputaciones, y con efectos
* fijos de sede en lugar de la estructura multinivel de tres niveles. Es una
* prueba de robustez deliberadamente exigente, no una especificación rival: su
* único propósito es averiguar si el coeficiente de la planta docente sobrevive
* cuando se descarta toda diferencia permanente entre establecimientos.
********************************************************************************

clear all
set more off
set varabbrev off
version 17

if "$TESIS_CONFIG" == "" do "C:\Users\RYZEN 5\Desktop\Tesis Multinivel\Definitivo\00_config.do"
cd "$RAIZ"

capture log close _all
local tarea "10b_planta_fe"
local hoy   "20261024"          // <<< etiqueta de la proxima corrida

capture confirm file "log_`tarea'_`hoy'.log"
if _rc == 0 {
    display as error "Ya existe log_`tarea'_`hoy'.log."
    display as error "Cambiar el local hoy (por ejemplo, anadir un sufijo b, c...)."
    exit 602
}
log using "log_`tarea'_`hoy'.log", text name(fase10b)

use "Base_Multinivel_PCA.dta", clear

********************************************************************************
* [0] VERIFICACIÓN DE INSUMOS
********************************************************************************
* Antes de estimar se comprueba que exista cada variable. Si falta alguna, el
* script lo dice y muestra qué hay en la base, en vez de detenerse con un
* código de error que no explica nada.

local necesarias punt_global estu_inse_individual mujer edad repitente ///
                 ln_matricula ratio_alumnos_docente pct_planta          ///
                 dotacion_tic ju_unica year cole_cod_dane_sede

local faltantes ""
foreach v of local necesarias {
    capture confirm variable `v'
    if _rc != 0 local faltantes "`faltantes' `v'"
}

if "`faltantes'" != "" {
    display as error _newline "Faltan estas variables: `faltantes'"
    display "Variables disponibles en la base:"
    describe, simple
    exit 111
}

display _newline "Todas las variables necesarias están presentes."

* ----------------------------------------------------------------------
* [0.1] Construcción del índice centrado
* ----------------------------------------------------------------------
* Misma definición que usa el script 08: el índice individual menos la media
* general de su año. Se recalcula aquí porque esta base es anterior a la
* imputación y no lo trae.

capture drop c_inse
bysort year: egen double _gm_inse = mean(estu_inse_individual)
generate double c_inse = estu_inse_individual - _gm_inse
drop _gm_inse
label variable c_inse "INSE centrado en la gran media del año"

display _newline "--- Verificación del centrado ---"
tabstat c_inse estu_inse_individual, by(year) stat(n mean sd) format(%9.4f)
display "La media de c_inse debe ser cero en cada año."


********************************************************************************
* [1] EFECTOS FIJOS DE SEDE
********************************************************************************

capture drop sede_id
egen long sede_id = group(cole_cod_dane_sede)
xtset sede_id

display _newline "{hline 78}"
display "[1] EFECTOS FIJOS DE SEDE SOBRE LA MUESTRA SIN IMPUTAR"
display "{hline 78}"
display "Descarta toda diferencia permanente entre sedes y usa solo la"
display "variación de la planta docente dentro de cada establecimiento."

quietly count if !missing(punt_global, c_inse, mujer, edad, repitente) & ///
                 !missing(ln_matricula, ratio_alumnos_docente, pct_planta) & ///
                 !missing(dotacion_tic, ju_unica)
display _newline "Observaciones con datos completos: " r(N) " de " _N
display "La diferencia frente a las 69.750 del modelo principal es el costo"
display "de trabajar sin imputación, y hay que declararla."

xtreg punt_global c_inse mujer edad repitente ///
      ln_matricula ratio_alumnos_docente pct_planta dotacion_tic ///
      ju_unica i.year, fe cluster(sede_id)

estimates store FE_sede

display _newline "--- Lectura del coeficiente de pct_planta ---"
display "Si conserva signo positivo, el resultado no puede atribuirse"
display "enteramente a diferencias fijas entre establecimientos. Si pierde"
display "significancia, hay que declarar que la identificación es"
display "principalmente transversal."


********************************************************************************
* [2] CONTRASTE CON LA MISMA ESPECIFICACIÓN SIN EFECTOS FIJOS
********************************************************************************
* La comparación entre ambas columnas es lo informativo. Si el coeficiente cae
* mucho al introducir los efectos fijos, buena parte de la asociación provenía
* de diferencias permanentes entre establecimientos y no de la evolución de la
* planta dentro de cada uno.

display _newline "{hline 78}"
display "[2] MISMA ESPECIFICACIÓN CON EFECTOS ALEATORIOS DE SEDE"
display "{hline 78}"

xtreg punt_global c_inse mujer edad repitente ///
      ln_matricula ratio_alumnos_docente pct_planta dotacion_tic ///
      ju_unica i.year, re cluster(sede_id)

estimates store RE_sede

display _newline "--- Comparación de los coeficientes ---"
estimates table FE_sede RE_sede, keep(pct_planta ln_matricula ///
    ratio_alumnos_docente dotacion_tic ju_unica c_inse) ///
    b(%9.4f) se(%9.4f) stats(N)


********************************************************************************
* [3] VARIACIÓN DISPONIBLE PARA IDENTIFICAR EL COEFICIENTE
********************************************************************************
* Cuánta variación de la planta docente queda una vez descontadas las
* diferencias fijas entre sedes. Es exactamente la que identifica el
* coeficiente del bloque [1], y su magnitud determina la potencia disponible.

display _newline "{hline 78}"
display "[3] VARIACIÓN DE LA PLANTA DOCENTE DENTRO Y ENTRE SEDES"
display "{hline 78}"

preserve
    egen byte _t = tag(cole_cod_dane_sede year)
    keep if _t == 1
    capture drop sede_id
    egen long sede_id = group(cole_cod_dane_sede)
    xtset sede_id year
    xtsum pct_planta ln_matricula ratio_alumnos_docente dotacion_tic

    display _newline "--- Sedes cuya planta docente NO cambia en el periodo ---"
    bysort sede_id: egen double _sd_planta = sd(pct_planta)
    egen byte _ts = tag(sede_id)
    quietly count if _ts == 1 & _sd_planta < 0.001 & !missing(_sd_planta)
    local sin_var = r(N)
    quietly count if _ts == 1 & !missing(_sd_planta)
    display "Sedes sin variación temporal: `sin_var' de " r(N)
    display "Esas sedes no aportan nada a la estimación con efectos fijos."
restore

display _newline "{hline 78}"
display "BLOQUE 7 COMPLETADO."
display "{hline 78}"

log close fase10b

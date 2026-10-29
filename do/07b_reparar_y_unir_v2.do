********************************************************************************
* PROYECTO : Desempeño Saber 11 en sedes oficiales del Cauca, 2018-2023
* SCRIPT   : 07B - REPARACIÓN DE MI_Sedes.dta Y UNIÓN DE LOS DOS NIVELES
* ENTRADA  : MI_Sedes.dta, MI_Estudiantes.dta   (generados por el 07)
* SALIDA   : Base_Multinivel_MI.dta
* STATA    : 17
* VERSIÓN  : 2 - reconstrucción de _mi_miss reescrita con un bucle
********************************************************************************
* QUÉ ARREGLA ESTE SCRIPT
* La Parte A de la primera versión del script 07 terminaba con un `keep` que
* conservaba `_mi_m` e `_mi_id` pero omitía `_mi_miss`. Esa es la tercera
* variable de sistema que Stata necesita para reconocer un archivo como
* conjunto de imputación, y sin ella `mi merge` se detiene.
*
* No hay que reimputar nada. Las 20 imputaciones de ambos niveles están
* guardadas y son válidas; solo falta reponer una columna que se deduce de los
* datos que ya existen.
*
* CÓMO SE RECONSTRUYE
* `_mi_miss` vale 1 cuando la observación original tenía algún valor faltante
* en las variables registradas como imputadas. Esa información sigue en las
* filas de m = 0, que conservan los datos sin imputar. Se revisa cada variable
* en la fila de m = 0 de cada observación y el resultado se propaga a sus 20
* copias.
********************************************************************************

clear all
set more off
set varabbrev off
version 17

if "$TESIS_CONFIG" == "" do "C:\Users\RYZEN 5\Desktop\Tesis Multinivel\Definitivo\00_config.do"
cd "$RAIZ"

capture log close _all
local tarea "07b_union"
local hoy   "20261024"          // <<< etiqueta de la proxima corrida

capture confirm file "log_`tarea'_`hoy'.log"
if _rc == 0 {
    display as error "Ya existe log_`tarea'_`hoy'.log."
    display as error "Cambiar el local hoy (por ejemplo, anadir un sufijo b, c...)."
    exit 602
}
log using "log_`tarea'_`hoy'.log", text name(fase7b)


********************************************************************************
* [1] REPARACIÓN DE MI_Sedes.dta
********************************************************************************

display _newline "{hline 78}"
display "[1] REPARACIÓN DEL CONJUNTO DE IMPUTACIÓN DE SEDES"
display "{hline 78}"

use "MI_Sedes.dta", clear

quietly count
display "Filas totales: " r(N) "   (esperadas: " 2447*21 ")"

capture confirm variable _mi_miss
if _rc == 0 {
    display "El archivo ya tiene _mi_miss. No hace falta repararlo."
}
else {
    display "Falta _mi_miss. Reconstruyendo a partir de las filas de m = 0..."

    * Al ordenar por identificador y número de imputación, la primera fila de
    * cada grupo es la de m = 0, que conserva los datos tal como llegaron.
    sort _mi_id _mi_m

    generate byte _mi_miss = 0

    foreach v in ln_matricula ratio_alumnos_docente pct_planta pct_posgrado ///
                 dotacion_tic tecnico tecnico_academico {
        by _mi_id: replace _mi_miss = 1 if missing(`v'[1])
    }

    quietly count if _mi_miss == 1 & _mi_m == 0
    display "Observaciones marcadas como incompletas: " r(N) " (esperadas: 134)"

    order _mi_m _mi_id _mi_miss, first
}

* `mi update` revisa la consistencia interna del conjunto y corrige lo que
* pueda quedar descuadrado. Si el archivo estuviera realmente dañado, aquí se
* detendría.
mi update

display _newline "--- Estado del conjunto de sedes tras la reparación ---"
mi describe

save "MI_Sedes.dta", replace
display _newline "MI_Sedes.dta reparado."


********************************************************************************
* [2] UNIÓN DE LOS DOS NIVELES
********************************************************************************

display _newline "{hline 78}"
display "[2] UNIÓN DE LOS DOS CONJUNTOS DE IMPUTACIÓN"
display "{hline 78}"

use "MI_Estudiantes.dta", clear

quietly count
display "Filas del conjunto de estudiantes: " r(N)

* `mi merge` empareja imputación con imputación: la número 7 del estudiante se
* cruza con la número 7 de su sede. Un `merge` ordinario mezclaría imputaciones
* distintas y produciría combinaciones que nunca fueron generadas juntas.
mi merge m:1 cole_cod_dane_sede year using "MI_Sedes.dta", generate(_m_mi)

display _newline "--- Resultado de la unión ---"
tabulate _m_mi
assert _m_mi == 3
drop _m_mi


********************************************************************************
* [3] VARIABLES DERIVADAS
********************************************************************************
* Todas se recalculan DENTRO de cada imputación. El agrupamiento incluye
* `_mi_m` y `year`: sin lo primero se mezclarían imputaciones distintas, sin lo
* segundo se promediarían seis cohortes en un mismo valor.

display _newline "{hline 78}"
display "[3] VARIABLES DERIVADAS"
display "{hline 78}"

* Media socioeconómica de la cohorte, sobre el INSE ya imputado.
capture drop inse_prom_sede
bysort _mi_m cole_cod_dane_sede year: egen double inse_prom_sede = ///
    mean(estu_inse_individual)
mi register passive inse_prom_sede
label variable inse_prom_sede "INSE medio de la cohorte de la sede (imputado)"

* Centrado en la gran media del año. Especificación principal del Objetivo 3.
bysort _mi_m year: egen double _gm_inse = mean(estu_inse_individual)
generate double c_inse = estu_inse_individual - _gm_inse
drop _gm_inse
mi register passive c_inse
label variable c_inse "INSE centrado en la gran media del año"

* Centrado en la media de la sede. Mide la posición del estudiante frente a sus
* propios compañeros; su coeficiente es el efecto dentro de la sede y la
* diferencia con el de `inse_prom_sede` es el efecto composicional.
generate double cwc_inse = estu_inse_individual - inse_prom_sede
mi register passive cwc_inse
label variable cwc_inse "INSE centrado en la media de la sede"

* La media de sede también se centra, para que el intercepto conserve
* interpretación en el modelo con centrado al clúster.
bysort _mi_m year: egen double _gm_sede = mean(inse_prom_sede)
generate double c_inse_prom_sede = inse_prom_sede - _gm_sede
drop _gm_sede
mi register passive c_inse_prom_sede
label variable c_inse_prom_sede "INSE medio de la sede, centrado"

capture drop inse_sede_obs


********************************************************************************
* [4] DIAGNÓSTICO
********************************************************************************

display _newline "{hline 78}"
display "[4] DIAGNÓSTICO DEL CONJUNTO FINAL"
display "{hline 78}"

mi describe

display _newline "--- Observado frente a completado: INSE ---"
quietly summarize estu_inse_individual if _mi_m == 0
display "  Observados (m = 0):  media " %8.4f r(mean) "   n = " r(N)
quietly summarize estu_inse_individual if _mi_m == 1
display "  Completos (m = 1):   media " %8.4f r(mean) "   n = " r(N)
display "  Una diferencia moderada es correcta: los casos sin dato no son"
display "  iguales a los completos."

display _newline "--- Proporciones antes y después de imputar ---"
foreach v in mujer lectura_30min libros_26omas trabaja_mas20 ///
             internet_hogar computador_hogar tecnico {
    quietly summarize `v' if _mi_m == 0
    local p0 = r(mean)
    quietly summarize `v' if _mi_m > 0
    display "  `v': observado " %6.4f `p0' "   tras imputar " %6.4f r(mean)
}

display _newline "--- Rangos: ninguna imputación debe salirse de lo posible ---"
foreach v in pct_planta dotacion_tic ln_matricula estu_inse_individual {
    quietly summarize `v' if _mi_m > 0
    display "  `v': [" %8.4f r(min) " , " %8.4f r(max) "]"
}
quietly count if _mi_m > 0 & (pct_planta < 0 | pct_planta > 1)
display "Valores de pct_planta fuera de [0,1]: " r(N) " (debe ser 0)"
assert r(N) == 0
quietly count if _mi_m > 0 & dotacion_tic < 0
display "Valores negativos de dotacion_tic: " r(N) " (debe ser 0)"
assert r(N) == 0

* Comprobación central de la estrategia en dos partes: los estudiantes de una
* misma sede deben compartir exactamente el mismo valor en cada imputación.
display _newline "--- Constancia de las variables de sede dentro de la sede-año ---"
bysort _mi_m cole_cod_dane_sede year: egen double _sd_mat = sd(ln_matricula)
quietly count if _sd_mat > 1e-8 & !missing(_sd_mat)
display "Sede-año con matrícula no constante entre sus estudiantes: " r(N) ///
        " (debe ser 0)"
assert r(N) == 0
drop _sd_mat

bysort _mi_m cole_cod_dane_sede year: egen double _sd_tic = sd(dotacion_tic)
quietly count if _sd_tic > 1e-8 & !missing(_sd_tic)
display "Sede-año con dotación no constante entre sus estudiantes: " r(N) ///
        " (debe ser 0)"
assert r(N) == 0
drop _sd_tic

display _newline "--- Faltantes remanentes en las variables del modelo ---"
* El índice y su descomposición ya NO viajan dentro del conjunto imputado: el
* script 07 v3 los retira porque dejaron de ser predictores de la imputación.
* Los reincorpora el 07c, que es ahora un paso obligatorio de la cadena.
mi xeq 1: misstable summarize punt_global estu_inse_individual c_inse       ///
    cwc_inse inse_prom_sede mujer lectura_30min libros_26omas              ///
    trabaja_mas20 internet_hogar computador_hogar ln_matricula pct_planta  ///
    z_posgrado dotacion_tic tecnico rural ju_unica


********************************************************************************
* [5] GUARDADO
********************************************************************************

compress
save "Base_Multinivel_MI.dta", replace

display _newline "{hline 78}"
display "IMPUTACIÓN COMPLETADA: Base_Multinivel_MI.dta (M = 20)"
display "MI_Sedes.dta y MI_Estudiantes.dta se conservan por si hace falta"
display "rehacer la unión sin volver a imputar."
display "Siguiente: 07c_actualizar_nivel3.do (incorpora el Nivel 3), y luego el 08."
display "{hline 78}"

log close fase7b

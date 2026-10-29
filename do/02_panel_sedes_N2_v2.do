********************************************************************************
* PROYECTO : Desempeño Saber 11 en sedes oficiales del Cauca, 2018-2023
* SCRIPT   : 02 - FASE 2. PANEL DE SEDES EDUCATIVAS (NIVEL 2)
* ENTRADA  : N1_Saber11_2018_2023.dta
*            Panel_matricula.xlsx, Panel_doc.xlsx, Panel_estabilidad.xlsx
* SALIDA   : N2_Sedes_sinTIC.dta
* STATA    : 17
* VERSIÓN  : 2 - el esqueleto de sede-año se construye desde la base ICFES
********************************************************************************
* LÓGICA DEL SCRIPT
* El punto de partida NO son los Excel del DANE sino la base de estudiantes
* depurada. De ella salen dos cosas: la lista exacta de sede-año con la que
* estamos trabajando (2.447 según la corrida del 01) y los atributos de sede
* de origen ICFES. Los paneles del DANE se pegan encima de ese esqueleto, de
* modo que ninguna sede de la muestra analítica puede desaparecer por un
* problema de cobertura de una fuente externa.
*
* ALCANCE
* El panel TIC no entra todavía: viene en hojas anuales sin consolidar y
* requiere reconstruir la variable desde la fuente.
*
* REGLA INQUEBRANTABLE
* Un dato ausente no se convierte en cero. Los vacíos se conservan como
* missing verdadero y los resuelve la imputación múltiple.
********************************************************************************

clear all
set more off
set varabbrev off
version 17

if "$TESIS_CONFIG" == "" do "C:\Users\RYZEN 5\Desktop\Tesis Multinivel\Definitivo\00_config.do"
cd "$RAIZ"

capture log close _all
local tarea "02_panel_sedes_N2"
local hoy   "20261024"          // <<< etiqueta de la proxima corrida

capture confirm file "log_`tarea'_`hoy'.log"
if _rc == 0 {
    display as error "Ya existe log_`tarea'_`hoy'.log."
    display as error "Cambiar el local hoy (por ejemplo, anadir un sufijo b, c...)."
    exit 602
}
log using "log_`tarea'_`hoy'.log", text name(fase2)

* Interruptor: convertir la matrícula igual a cero en missing.
* Se deja en 1 porque una matrícula de cero no es un tamaño de sede válido,
* pero el bloque [1] reporta cuántos casos son ANTES de aplicarlo, así que
* puede ponerse en 0 y volver a correr si el diagnóstico lo desaconseja.
local cero_matricula_a_missing = 1


********************************************************************************
* [0] ESQUELETO DE SEDE-AÑO Y ATRIBUTOS DE ORIGEN ICFES
********************************************************************************

display _newline "{hline 78}"
display "[0] ESQUELETO DE SEDE-AÑO DESDE LA BASE DE ESTUDIANTES"
display "{hline 78}"

use "N1_Saber11_2018_2023.dta", clear

quietly count
display "Estudiantes en la base de Nivel 1: " r(N)

keep cole_cod_dane_sede cole_cod_mcpio_ubicacion year               ///
     rural cole_femenino cole_masculino tecnico mixto               ///
     sede_principal ju_unica ju_completa                            ///
     estu_inse_individual punt_global

* Se renombra el carácter técnico/académico: "mixto" se confunde con sede de
* género mixto cuando ambas variables aparecen juntas en una tabla.
rename mixto tecnico_academico

* ----------------------------------------------------------------------
* [0.1] JORNADA: DE ATRIBUTO DEL ESTUDIANTE A ATRIBUTO DE LA SEDE
* ----------------------------------------------------------------------
* La jornada única fue una política de establecimiento, así que se consolida
* como atributo de la sede aunque cambie de un año a otro. Se construyen dos
* versiones y ambas se conservan:
*   pct_unica : proporción de estudiantes de la sede-año en jornada única
*   ju_unica  : dummy por regla de mayoría (más de la mitad de la cohorte)
* Se guardan las dos porque en las sede-año con una sola jornada coinciden
* por construcción, y la diferencia solo aparece en el pequeño grupo con
* jornadas mixtas.

bysort cole_cod_dane_sede year: egen double pct_unica    = mean(ju_unica)
bysort cole_cod_dane_sede year: egen double pct_completa = mean(ju_completa)

* Cuántas sede-año tienen la jornada repartida entre categorías.
egen byte _tag = tag(cole_cod_dane_sede year)
quietly count if _tag == 1 & pct_unica > 0 & pct_unica < 1
display _newline "Sede-año con jornada única repartida (ni 0 ni 1): " r(N)
quietly count if _tag == 1
display "Total de sede-año: " r(N)
drop _tag

* ----------------------------------------------------------------------
* [0.2] COLAPSO A SEDE-AÑO
* ----------------------------------------------------------------------
* Los atributos de establecimiento se promedian. Si son realmente constantes
* dentro de la sede-año, el promedio queda exactamente en 0 o en 1; cualquier
* valor intermedio delata una inconsistencia de la fuente. El bloque [0.3]
* verifica precisamente eso, en vez de darlo por hecho.

collapse (mean) rural cole_femenino cole_masculino tecnico             ///
                tecnico_academico sede_principal                       ///
                pct_unica pct_completa                                 ///
                inse_prom_sede = estu_inse_individual                  ///
                mcpio_mean = cole_cod_mcpio_ubicacion                  ///
         (min)  mcpio_min = cole_cod_mcpio_ubicacion                   ///
         (max)  mcpio_max = cole_cod_mcpio_ubicacion                   ///
         (count) evaluados_sede = punt_global,                         ///
         by(cole_cod_dane_sede year)

quietly count
display _newline "Sede-año en el esqueleto: " r(N)

* ----------------------------------------------------------------------
* [0.3] VERIFICACIÓN DE CONSTANCIA DE LOS ATRIBUTOS
* ----------------------------------------------------------------------
display _newline "--- Atributos que deberían ser constantes dentro de la sede-año ---"
foreach v in rural cole_femenino cole_masculino tecnico tecnico_academico sede_principal {
    quietly count if `v' > 0 & `v' < 1 & !missing(`v')
    display "  `v': sede-año con valor intermedio (inconsistencia): " r(N)
}

* Una sede no puede estar en dos municipios a la vez.
quietly count if mcpio_min != mcpio_max
display "  Sede-año asignadas a más de un municipio: " r(N)
generate long cole_cod_mcpio_ubicacion = round(mcpio_mean)
drop mcpio_mean mcpio_min mcpio_max
label variable cole_cod_mcpio_ubicacion "Código DANE del municipio"

* ----------------------------------------------------------------------
* [0.4] JORNADA ÚNICA COMO DUMMY DE SEDE
* ----------------------------------------------------------------------
generate byte ju_unica = (pct_unica > 0.5) if !missing(pct_unica)
label variable ju_unica    "Sede en jornada única (regla de mayoría)"
label variable pct_unica   "Proporción de la cohorte en jornada única"
label variable pct_completa "Proporción de la cohorte en jornada completa"

* Cuántas sede-año clasificaría distinto una regla de presencia en vez de
* mayoría. Es la magnitud del margen de discrecionalidad de esta decisión.
quietly count if pct_unica > 0 & ju_unica == 0
display _newline "Sede-año con algo de jornada única que la regla de mayoría clasifica como 0: " r(N)

* ----------------------------------------------------------------------
* [0.5] DIAGNÓSTICO DE LOS ATRIBUTOS ESCASOS
* ----------------------------------------------------------------------
* Una dummy que solo vale 1 en un puñado de sede-año produce un coeficiente
* inestable y no interpretable. Conviene saberlo antes de ponerla en el modelo.
display _newline "--- Frecuencia de los atributos de sede (sobre sede-año) ---"
foreach v in rural cole_femenino cole_masculino tecnico tecnico_academico ju_unica {
    quietly count if `v' == 1
    display "  `v' == 1 en " r(N) " sede-año"
}

display _newline "--- Evolución de la jornada única ---"
tabstat ju_unica pct_unica, by(year) stat(n mean) format(%9.4f)

label variable rural             "Sede rural (1 = sí)"
label variable cole_femenino     "Sede exclusivamente femenina (1 = sí)"
label variable cole_masculino    "Sede exclusivamente masculina (1 = sí)"
label variable tecnico           "Sede de carácter técnico (1 = sí)"
label variable tecnico_academico "Sede de carácter técnico/académico (1 = sí)"
label variable sede_principal    "Sede principal del establecimiento (1 = sí)"
label variable inse_prom_sede    "INSE promedio de la cohorte (escala original)"
label variable evaluados_sede    "Estudiantes evaluados en la sede-año"

isid cole_cod_dane_sede year
save "temp_esqueleto.dta", replace


********************************************************************************
* [1] PANEL DE MATRÍCULA
********************************************************************************
* Se procesa primero por ser el denominador de dos variables derivadas.

display _newline "{hline 78}"
display "[1] PANEL DE MATRÍCULA"
display "{hline 78}"

import excel "Panel_matricula.xlsx", sheet("Panel_matricula") firstrow clear

quietly count
display "Filas leídas (base nacional): " r(N)

rename periodo year
keep cole_cod_dane_sede year matricula

* Llave a string con el mismo contrato del script 01: %20.0f, sin decimales.
capture confirm string variable cole_cod_dane_sede
if _rc != 0 {
    quietly tostring cole_cod_dane_sede, replace format(%20.0f) force
}
quietly replace cole_cod_dane_sede = trim(cole_cod_dane_sede)

quietly destring year matricula, replace force
quietly keep if inrange(year, 2018, 2023)

display _newline "--- Diagnóstico de matrícula (nacional) ---"
tabulate year, missing
quietly count if missing(matricula)
display "Sede-año con matrícula vacía: " r(N)
quietly count if matricula == 0
display "Sede-año con matrícula igual a cero: " r(N)
quietly count if matricula > 0 & matricula < 10 & !missing(matricula)
display "Sede-año con matrícula entre 1 y 9: " r(N)
tabstat matricula, stat(n mean sd p1 p50 p99 min max) format(%9.1f)

if `cero_matricula_a_missing' == 1 {
    quietly replace matricula = . if matricula == 0
    display "Aplicado: matrícula igual a cero convertida en missing."
}

quietly drop if missing(cole_cod_dane_sede) | cole_cod_dane_sede == "" | missing(year)
isid cole_cod_dane_sede year
save "temp_matricula.dta", replace


********************************************************************************
* [2] PANEL DE DOCENTES Y FORMACIÓN
********************************************************************************

display _newline "{hline 78}"
display "[2] PANEL DE DOCENTES"
display "{hline 78}"

import excel "Panel_doc.xlsx", sheet("Panel_doc") firstrow clear

quietly count
display "Filas leídas (base nacional): " r(N)

rename periodo year
rename docentes docentes_doc
keep cole_cod_dane_sede year docentes_doc pct_posgrado

capture confirm string variable cole_cod_dane_sede
if _rc != 0 {
    quietly tostring cole_cod_dane_sede, replace format(%20.0f) force
}
quietly replace cole_cod_dane_sede = trim(cole_cod_dane_sede)

quietly destring year docentes_doc pct_posgrado, replace force
quietly keep if inrange(year, 2018, 2023)

display _newline "--- Diagnóstico de docentes y posgrado (nacional) ---"
tabstat docentes_doc pct_posgrado, stat(n mean sd min p50 max) format(%9.4f)

quietly count if pct_posgrado > 1 & !missing(pct_posgrado)
display "Valores de pct_posgrado por encima de 1: " r(N) " (deben ser 0)"
quietly count if docentes_doc == 0
display "Sede-año con cero docentes reportados: " r(N)

quietly drop if missing(cole_cod_dane_sede) | cole_cod_dane_sede == "" | missing(year)
isid cole_cod_dane_sede year
save "temp_docentes.dta", replace


********************************************************************************
* [3] PANEL DE ESTABILIDAD DOCENTE
********************************************************************************

display _newline "{hline 78}"
display "[3] PANEL DE ESTABILIDAD DOCENTE"
display "{hline 78}"

import excel "Panel_estabilidad.xlsx", sheet("Panel_estabilidad") firstrow clear

quietly count
display "Filas leídas (base nacional): " r(N)

rename periodo year
rename docentes docentes_estab
keep cole_cod_dane_sede year planta_con_escalafon planta_sin_escalafon ///
     contrato_con_escalafon contrato_sin_escalafon docentes_estab pct_planta

capture confirm string variable cole_cod_dane_sede
if _rc != 0 {
    quietly tostring cole_cod_dane_sede, replace format(%20.0f) force
}
quietly replace cole_cod_dane_sede = trim(cole_cod_dane_sede)

quietly destring year docentes_estab pct_planta planta_con_escalafon ///
    planta_sin_escalafon contrato_con_escalafon contrato_sin_escalafon, ///
    replace force
quietly keep if inrange(year, 2018, 2023)

display _newline "--- Diagnóstico de estabilidad (nacional) ---"
tabstat pct_planta planta_con_escalafon planta_sin_escalafon ///
        contrato_con_escalafon contrato_sin_escalafon, ///
        stat(n mean sd min p50 max) format(%9.4f)

* Coherencia interna: las cuatro categorías son proporciones y suman 1, y
* pct_planta debe ser la suma de las dos categorías de planta.
generate double _suma4 = planta_con_escalafon + planta_sin_escalafon + ///
                         contrato_con_escalafon + contrato_sin_escalafon
quietly count if abs(_suma4 - 1) > 0.001 & !missing(_suma4)
display "Sede-año donde las cuatro categorías NO suman 1: " r(N)

generate double _planta_calc = planta_con_escalafon + planta_sin_escalafon
quietly count if abs(_planta_calc - pct_planta) > 0.001 & !missing(pct_planta)
display "Sede-año donde pct_planta != planta_con + planta_sin: " r(N)
drop _suma4 _planta_calc

quietly drop if missing(cole_cod_dane_sede) | cole_cod_dane_sede == "" | missing(year)
isid cole_cod_dane_sede year
save "temp_estabilidad.dta", replace


********************************************************************************
* [4] CRUCE SOBRE EL ESQUELETO
********************************************************************************
* El esqueleto manda: se conservan sus 2.447 filas pase lo que pase. Las
* variables del DANE que no crucen quedan vacías y las imputa MICE.

display _newline "{hline 78}"
display "[4] CRUCE DE LOS PANELES DANE SOBRE EL ESQUELETO"
display "{hline 78}"

use "temp_esqueleto.dta", clear

merge 1:1 cole_cod_dane_sede year using "temp_matricula.dta", ///
    keep(master match) generate(_m_mat)
display _newline "--- Cruce con matrícula ---"
tabulate _m_mat

merge 1:1 cole_cod_dane_sede year using "temp_docentes.dta", ///
    keep(master match) generate(_m_doc)
display _newline "--- Cruce con docentes ---"
tabulate _m_doc

merge 1:1 cole_cod_dane_sede year using "temp_estabilidad.dta", ///
    keep(master match) generate(_m_est)
display _newline "--- Cruce con estabilidad ---"
tabulate _m_est

display _newline "--- Sede-año de la muestra SIN datos DANE, por año ---"
display "Matrícula:"
tabulate year if _m_mat == 1
display "Docentes:"
tabulate year if _m_doc == 1
display "Estabilidad:"
tabulate year if _m_est == 1

drop _m_mat _m_doc _m_est


********************************************************************************
* [5] LOS DOS CONTEOS DE DOCENTES
********************************************************************************
* Panel_doc y Panel_estabilidad reportan cifras distintas de docentes para la
* misma sede-año, aun viniendo ambas del DANE. Cada proporción se calcula con
* el total de su propia base (así vienen construidas y así se conservan), pero
* el cociente alumnos/docente necesita un único denominador.

display _newline "{hline 78}"
display "[5] DISCREPANCIA ENTRE LOS DOS CONTEOS DE DOCENTES"
display "{hline 78}"

generate double dif_docentes = docentes_estab - docentes_doc
label variable dif_docentes "Docentes (estabilidad) menos docentes (formación)"

quietly count if !missing(docentes_doc) & !missing(docentes_estab)
local n_ambos = r(N)
display "Sede-año con ambos conteos disponibles: `n_ambos'"

if `n_ambos' > 0 {
    quietly count if dif_docentes == 0 & !missing(dif_docentes)
    display "  Coinciden exactamente: " r(N) " (" %5.2f 100*r(N)/`n_ambos' "%)"
    quietly count if dif_docentes > 0 & !missing(dif_docentes)
    display "  Estabilidad reporta MÁS: " r(N)
    quietly count if dif_docentes < 0 & !missing(dif_docentes)
    display "  Formación reporta MÁS: " r(N)

    display _newline "--- Magnitud de la diferencia ---"
    tabstat dif_docentes, stat(n mean sd p1 p25 p50 p75 p99 min max) format(%9.2f)

    display _newline "--- Correlación entre los dos conteos ---"
    correlate docentes_doc docentes_estab
}


********************************************************************************
* [6] VARIABLES DERIVADAS
********************************************************************************
* Los vacíos se propagan como vacíos. Nada se rellena con cero.

display _newline "{hline 78}"
display "[6] CONSTRUCCIÓN DE VARIABLES DERIVADAS"
display "{hline 78}"

* (6.1) Tamaño de la sede
generate double ln_matricula = ln(matricula)
label variable ln_matricula "Tamaño de la sede (logaritmo de la matrícula)"

* (6.2) Razón alumnos por docente.
*       DECISIÓN: el denominador es docentes_doc, el conteo del panel de
*       formación. Un conteo de cero docentes no es un dato válido para un
*       cociente, así que esos casos quedan en missing.
generate double ratio_alumnos_docente = matricula / docentes_doc ///
    if docentes_doc > 0 & !missing(docentes_doc)
label variable ratio_alumnos_docente "Razón alumnos por docente"

* Versión con el otro conteo, reservada para la prueba de robustez.
generate double ratio_alt = matricula / docentes_estab ///
    if docentes_estab > 0 & !missing(docentes_estab)
label variable ratio_alt "Razón alumnos/docente (conteo de estabilidad)"

label variable matricula      "Matrícula total de la sede"
label variable docentes_doc   "Docentes (panel de formación)"
label variable docentes_estab "Docentes (panel de estabilidad)"
label variable pct_planta     "Proporción de docentes de planta (0 a 1)"
label variable pct_posgrado   "Proporción de docentes con posgrado (0 a 1)"

display _newline "--- Variables derivadas (muestra analítica) ---"
tabstat ln_matricula ratio_alumnos_docente ratio_alt pct_planta pct_posgrado, ///
        stat(n mean sd p1 p50 p99 min max) format(%9.4f)

quietly count if !missing(ratio_alumnos_docente) & !missing(ratio_alt)
if r(N) > 0 {
    display _newline "--- Correlación entre las dos versiones de la razón ---"
    correlate ratio_alumnos_docente ratio_alt
}


********************************************************************************
* [7] PANEL DE CONTROL DE LA FASE 2
********************************************************************************

display _newline "{hline 78}"
display "[7] PANEL DE CONTROL"
display "{hline 78}"

display _newline "--- Sede-año por año ---"
tabulate year, missing

display _newline "--- Cobertura de las variables del DANE ---"
misstable summarize matricula ln_matricula docentes_doc docentes_estab ///
    ratio_alumnos_docente pct_planta pct_posgrado

display _newline "--- Descriptivos de Nivel 2 por año ---"
tabstat ln_matricula ratio_alumnos_docente pct_planta pct_posgrado ///
        rural ju_unica inse_prom_sede evaluados_sede, ///
        by(year) stat(n mean sd) format(%9.4f)

display _newline "--- Variación within y between de las variables de sede ---"
* Codificación numérica de la sede solo para el xtset del diagnóstico.
egen long sede_id = group(cole_cod_dane_sede)
xtset sede_id year
xtsum ln_matricula ratio_alumnos_docente pct_planta pct_posgrado ju_unica rural

isid cole_cod_dane_sede year
assert inrange(year, 2018, 2023)
assert !missing(cole_cod_mcpio_ubicacion)
display _newline "Llaves verificadas: sede-año única, municipio sin vacíos."


********************************************************************************
* [8] GUARDADO
********************************************************************************

drop sede_id
order cole_cod_dane_sede cole_cod_mcpio_ubicacion year ///
      matricula ln_matricula docentes_doc ratio_alumnos_docente ///
      pct_planta pct_posgrado rural ju_unica

compress
save "N2_Sedes_sinTIC.dta", replace

erase "temp_esqueleto.dta"
erase "temp_matricula.dta"
erase "temp_docentes.dta"
erase "temp_estabilidad.dta"

display _newline "{hline 78}"
display "PANEL DE SEDES CONSOLIDADO: N2_Sedes_sinTIC.dta"
display "Pendiente: incorporar el panel TIC desde sus hojas anuales."
display "{hline 78}"

log close fase2

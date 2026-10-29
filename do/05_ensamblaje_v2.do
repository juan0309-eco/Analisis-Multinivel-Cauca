********************************************************************************
* PROYECTO : Desempeño Saber 11 en sedes oficiales del Cauca, 2018-2023
* SCRIPT   : 05 - FASE 5. ENSAMBLAJE DE LOS TRES NIVELES
* ENTRADA  : N1_Saber11_2018_2023.dta   (69.750 estudiantes)
*            N2_Sedes_2018_2023.dta     (2.447 sede-año)
*            N3_Municipios_2018_2023.dta (252 municipio-año)
* SALIDA   : Base_Multinivel_2018_2023.dta
* STATA    : 17
* VERSIÓN  : 2 - corrige colisiones de nombres y verifica los prerrequisitos
********************************************************************************
* REQUISITO PREVIO
* N2_Sedes_2018_2023.dta debe venir de 03_panel_tic_N2_v2.do, que es el que
* construye z_posgrado. Si se corrió la primera versión del 03, esa variable no
* existe y el script se detiene con un mensaje explícito en el bloque [2].
*
* POR QUÉ ESTE CRUCE DEBE SER PERFECTO
* El panel de sedes se construyó a partir de la propia base de estudiantes, y
* el panel municipal cubre los 42 municipios del molde. Por construcción, cada
* estudiante tiene que encontrar su sede-año y su municipio-año. Por eso el
* script no se conforma con reportar porcentajes de cruce: los exige con
* `assert`.
*
* DOS SOLAPAMIENTOS DE NOMBRES QUE HAY QUE RESOLVER ANTES DEL MERGE
* Primero: la base de estudiantes trae versiones a NIVEL DE ESTUDIANTE de los
* atributos de sede (rural, jornada, carácter, género de la sede). El panel de
* sedes trae las consolidadas a sede-año, que son las autoritativas. Stata, ante
* un nombre repetido, conserva silenciosamente el del master, así que esas
* columnas se eliminan explícitamente. Sin ese paso, `ju_unica` entraría con el
* valor del estudiante y no con la regla de mayoría de la sede.
* Segundo: la base de estudiantes ya contiene `tag_sede` y `tag_mcpio`,
* generados en el script 01. Se eliminan para poder recrearlos aquí.
*
* ALCANCE
* Este es el punto final del proceso de depuración y consolidación. El PCA del
* índice de vulnerabilidad, la imputación múltiple y la estimación van en
* scripts posteriores.
********************************************************************************

clear all
set more off
set varabbrev off
version 17

if "$TESIS_CONFIG" == "" do "C:\Users\RYZEN 5\Desktop\Tesis Multinivel\Definitivo\00_config.do"
cd "$RAIZ"

capture log close _all
local tarea "05_ensamblaje"
local hoy   "20261024"          // <<< etiqueta de la proxima corrida

capture confirm file "log_`tarea'_`hoy'.log"
if _rc == 0 {
    display as error "Ya existe log_`tarea'_`hoy'.log."
    display as error "Cambiar el local hoy (por ejemplo, anadir un sufijo b, c...)."
    exit 602
}
log using "log_`tarea'_`hoy'.log", text name(fase5)


********************************************************************************
* [1] BASE DE ESTUDIANTES (NIVEL 1)
********************************************************************************

display _newline "{hline 78}"
display "[1] BASE DE ESTUDIANTES"
display "{hline 78}"

use "N1_Saber11_2018_2023.dta", clear

quietly count
display "Estudiantes: " r(N)
display _newline "--- Distribución por año ---"
tabulate year, missing

* ----------------------------------------------------------------------
* [1.1] LIMPIEZA DE COLUMNAS QUE COLISIONARÍAN CON EL MERGE
* ----------------------------------------------------------------------
* Atributos de sede a nivel de estudiante: se generaron en el 01 solo para
* poder construir el esqueleto de sede-año. Ya cumplieron su función.
foreach v in rural cole_femenino cole_masculino tecnico mixto ///
             sede_principal ju_unica ju_completa                ///
             inse_prom_sede evaluados_sede {
    capture drop `v'
}

* Marcadores y auxiliares que se recrean más adelante.
foreach v in tag_sede tag_mcpio sede_id mcpio_id n2_incompleto {
    capture drop `v'
}

display _newline "Columnas conflictivas eliminadas."
display "Los atributos de sede vendrán del panel de sedes, no del estudiante."


********************************************************************************
* [2] CRUCE CON EL NIVEL 2
********************************************************************************

display _newline "{hline 78}"
display "[2] CRUCE CON EL PANEL DE SEDES"
display "{hline 78}"

merge m:1 cole_cod_dane_sede year using "N2_Sedes_2018_2023.dta", ///
    generate(_m_n2)

display _newline "--- Resultado del cruce ---"
display "  1 = estudiante sin sede en el panel  <- no debería existir"
display "  2 = sede-año sin estudiantes         <- no debería existir"
display "  3 = cruce exitoso"
tabulate _m_n2

quietly count if _m_n2 == 1
if r(N) > 0 {
    display as error "ATENCIÓN: hay estudiantes sin su sede-año en el panel."
    display as error "Revisar el formato de cole_cod_dane_sede en ambas bases."
    list cole_cod_dane_sede year if _m_n2 == 1 in 1/20, clean noobs
}

assert _m_n2 == 3
display _newline "Verificado: los " _N " estudiantes encontraron su sede-año."
drop _m_n2

* ----------------------------------------------------------------------
* [2.1] VERIFICACIÓN DE PRERREQUISITO
* ----------------------------------------------------------------------
* z_posgrado solo existe si el panel de sedes se construyó con la versión 2 del
* script 03. Sin ella, la formación docente entraría al modelo con la variable
* cruda, que no es comparable entre años.
capture confirm variable z_posgrado
if _rc != 0 {
    display as error "{hline 78}"
    display as error "ERROR: N2_Sedes_2018_2023.dta no contiene z_posgrado."
    display as error "Ese archivo viene de la PRIMERA versión del script 03."
    display as error "Vuelva a correr 03_panel_tic_N2_v2.do y repita este script."
    display as error "{hline 78}"
    log close fase5
    exit 111
}
display "Verificado: z_posgrado presente (panel de sedes construido con 03 v2)."


********************************************************************************
* [3] CRUCE CON EL NIVEL 3
********************************************************************************
* Recordatorio: en el panel municipal `year` es el año de la COHORTE y los
* datos corresponden a `year - 1`. El rezago ya está aplicado, así que aquí se
* cruza directamente por año de cohorte.

display _newline "{hline 78}"
display "[3] CRUCE CON EL PANEL MUNICIPAL"
display "{hline 78}"

merge m:1 cole_cod_mcpio_ubicacion year using "N3_Municipios_2018_2023.dta", ///
    generate(_m_n3)

display _newline "--- Resultado del cruce ---"
tabulate _m_n3

quietly count if _m_n3 == 1
if r(N) > 0 {
    display as error "ATENCIÓN: hay estudiantes sin su municipio-año."
    tabulate cole_cod_mcpio_ubicacion if _m_n3 == 1
}

assert _m_n3 == 3
display _newline "Verificado: todos los estudiantes encontraron su municipio-año."
drop _m_n3

* Confirmación del rezago: cada año de cohorte debe traer el dato del año
* anterior. Si esto falla, el desplazamiento temporal se perdió en algún punto.
assert year_dato == year - 1
display "Verificado: el rezago de un período está intacto."


********************************************************************************
* [4] INTEGRIDAD DE LA ESTRUCTURA JERÁRQUICA
********************************************************************************
* Un modelo de tres niveles exige anidamiento estricto: cada estudiante en una
* sede, cada sede en un municipio. Si una sede apareciera en dos municipios, la
* estructura sería cruzada y no jerárquica, y `mixed` estimaría algo distinto
* de lo que dice el marco teórico.

display _newline "{hline 78}"
display "[4] VERIFICACIÓN DE LA ESTRUCTURA JERÁRQUICA"
display "{hline 78}"

preserve
    keep cole_cod_dane_sede cole_cod_mcpio_ubicacion
    duplicates drop
    quietly duplicates tag cole_cod_dane_sede, generate(_sede_multi)
    quietly count if _sede_multi > 0
    display "Sedes asignadas a más de un municipio: " r(N) " (debe ser 0)"
    assert _sede_multi == 0
restore

* Identificadores numéricos consecutivos. `mixed` los necesita numéricos y el
* código DANE de la sede es una cadena.
egen long sede_id  = group(cole_cod_dane_sede)
egen long mcpio_id = group(cole_cod_mcpio_ubicacion)
label variable sede_id  "Identificador numérico de la sede (Nivel 2)"
label variable mcpio_id "Identificador numérico del municipio (Nivel 3)"

display _newline "--- Tamaño de cada nivel ---"
quietly summarize sede_id
display "Sedes distintas: " r(max)
quietly summarize mcpio_id
display "Municipios distintos: " r(max)

egen byte tag_sede  = tag(sede_id year)
egen byte tag_mcpio = tag(mcpio_id year)
label variable tag_sede  "Marca una fila por sede-año"
label variable tag_mcpio "Marca una fila por municipio-año"

quietly count if tag_sede == 1
display "Sede-año: " r(N)
quietly count if tag_mcpio == 1
display "Municipio-año: " r(N)

display _newline "--- Estudiantes por sede-año ---"
preserve
    quietly keep if tag_sede == 1
    tabstat evaluados_sede, by(year) stat(n mean sd p10 p50 p90 min max) ///
        format(%9.1f)
restore

* Grupos con un solo estudiante aportan poco a la estimación de la varianza de
* sede. Se cuentan para poder declararlo en la metodología.
quietly count if tag_sede == 1 & evaluados_sede == 1
display _newline "Sede-año con un solo estudiante evaluado: " r(N)
quietly count if tag_sede == 1 & evaluados_sede < 5
display "Sede-año con menos de 5 estudiantes: " r(N)


********************************************************************************
* [5] PANEL DE CONTROL DE LA BASE CONSOLIDADA
********************************************************************************

display _newline "{hline 78}"
display "[5] PANEL DE CONTROL"
display "{hline 78}"

display _newline "--- NIVEL 1: variable dependiente y covariables ---"
tabstat punt_global estu_inse_individual edad mujer repitente, ///
        by(year) stat(n mean sd) format(%9.4f)

display _newline "--- NIVEL 1: valores perdidos antes de MICE ---"
tabstat inse_miss mujer_miss trabaja_mas20_miss lectura_30min_miss ///
        libros_26omas_miss internet_miss compu_miss, ///
        by(year) stat(mean) format(%9.4f)

display _newline "--- NIVEL 2: variables de sede (una fila por sede-año) ---"
tabstat ln_matricula ratio_alumnos_docente pct_planta z_posgrado ///
        dotacion_tic rural ju_unica tecnico if tag_sede == 1, ///
        by(year) stat(n mean sd) format(%9.4f)

display _newline "--- NIVEL 3: variables municipales (una fila por municipio-año) ---"
tabstat tasa_homicidios ln_coca ln_inversion_pc if tag_mcpio == 1, ///
        by(year) stat(n mean sd) format(%9.4f)

display _newline "--- Cobertura de todas las variables del modelo ---"
misstable summarize punt_global estu_inse_individual edad mujer         ///
    lectura_30min libros_26omas trabaja_mas20 internet_hogar            ///
    computador_hogar ln_matricula ratio_alumnos_docente pct_planta      ///
    z_posgrado dotacion_tic rural ju_unica tecnico                      ///
    tasa_homicidios ln_coca ln_inversion_pc

* Cuántos estudiantes arrastran algún vacío de Nivel 2. Es la magnitud del
* trabajo que le queda a la imputación en ese nivel.
generate byte n2_incompleto = missing(ln_matricula) | missing(pct_planta) | ///
                              missing(dotacion_tic) | missing(z_posgrado)
label variable n2_incompleto "Alguna variable de sede vacía (1 = sí)"
quietly count if n2_incompleto == 1
display _newline "Estudiantes con alguna variable de sede vacía: " r(N) ///
        " (" %5.2f 100*r(N)/_N "%)"
tabulate year n2_incompleto, row nofreq

display _newline "--- Descomposición de la varianza del puntaje (referencia) ---"
* Modelo nulo de tres niveles: da la partición inicial que responde al
* Objetivo 2. Se estima aquí solo como verificación de que la estructura
* jerárquica funciona; la estimación formal va sobre los datos imputados.
quietly mixed punt_global || mcpio_id: || sede_id: , mle
estat icc


********************************************************************************
* [6] GUARDADO
********************************************************************************

display _newline "{hline 78}"
display "[6] GUARDADO"
display "{hline 78}"

order estu_consecutivo cole_cod_dane_sede sede_id                       ///
      cole_cod_mcpio_ubicacion mcpio_id year year_dato                  ///
      punt_global estu_inse_individual mujer edad                       ///
      ln_matricula pct_planta z_posgrado dotacion_tic rural ju_unica    ///
      tasa_homicidios ln_coca ln_inversion_pc

compress
save "Base_Multinivel_2018_2023.dta", replace

quietly count
display _newline "Base consolidada: " r(N) " estudiantes"
quietly count if tag_sede == 1
display "                  " r(N) " sede-año"
quietly count if tag_mcpio == 1
display "                  " r(N) " municipio-año"

display _newline "{hline 78}"
display "ENSAMBLAJE COMPLETADO: Base_Multinivel_2018_2023.dta"
display "Siguiente: PCA del índice de vulnerabilidad e imputación múltiple."
display "{hline 78}"

log close fase5

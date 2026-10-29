********************************************************************************
* PROYECTO : Desempeño Saber 11 en sedes oficiales del Cauca, 2018-2023
* SCRIPT   : 07 - IMPUTACIÓN MÚLTIPLE POR ECUACIONES ENCADENADAS
* ENTRADA  : N2_Sedes_2018_2023.dta      (2.447 sede-año)
*            N3_Municipios_PCA.dta       (252 municipio-año)
*            Base_Multinivel_PCA.dta     (69.750 estudiantes)
* SALIDA   : MI_Sedes.dta        (2.447 sede-año, M = 20)
*            MI_Estudiantes.dta  (69.750 estudiantes, M = 20)
* SIGUIENTE: 07b_reparar_y_unir.do, que une los dos conjuntos
* STATA    : 17
* VERSIÓN  : 3 - el modelo de imputación deja de usar el índice de
*                vulnerabilidad y pasa a usar sus tres dimensiones crudas
********************************************************************************
* QUÉ CAMBIA EN LA VERSIÓN 3 Y POR QUÉ
* La versión 2 incluía `indice_vuln` entre los predictores auxiliares de los dos
* modelos de imputación. Eso creaba una dependencia indeseable: cada vez que el
* índice se reconstruye (por ejemplo, al corregir la serie de coca) los valores
* imputados quedan desactualizados y la única salida limpia es repetir cuatro
* horas de cómputo, o bien declarar una limitación en la metodología.
*
* La versión 3 sustituye el índice por las TRES dimensiones que lo componen:
* `tasa_homicidios`, `ln_coca` y `ln_inversion_pc`. El cambio tiene tres
* ventajas y ningún costo:
*
*   1. El espacio de información es el mismo o mayor. El índice es el primer
*      componente principal de esas tres variables estandarizadas, es decir una
*      combinación lineal con pesos fijos. Incluirlas por separado abarca ese
*      mismo espacio sin imponer los pesos.
*
*   2. El modelo de imputación deja de ser más restrictivo que el de análisis.
*      El script 08 estima las tres dimensiones por separado (modelo ML3). La
*      regla estándar es que el modelo de imputación sea al menos tan rico como
*      el de análisis; con el índice solo, no lo era.
*
*   3. Se elimina la circularidad de imputar covariables con un índice derivado
*      de los mismos datos municipales que después actúan como regresores.
*
* Consecuencia práctica: los valores imputados ya no dependen del índice, de
* modo que reconstruirlo no obliga a reimputar y la limitación desaparece del
* Capítulo 3 en lugar de tener que declararse.
********************************************************************************
* ADVERTENCIA DE TIEMPO
* Este es el script caro del proyecto: unas cuatro horas en total, de las
* cuales tres corresponden a la Parte B. Por eso la unión de los dos niveles
* se hace en un script aparte: si algo falla al unir, no hay que volver a
* imputar.
*
* EL PROBLEMA QUE RESUELVE LA ESTRUCTURA EN DOS PARTES
* Las variables de sede son constantes dentro de cada sede-año: todos los
* estudiantes de un mismo establecimiento comparten la misma matrícula y la
* misma proporción de docentes de planta. Si se imputaran a nivel de estudiante,
* el algoritmo asignaría valores distintos a compañeros de curso, lo que rompe
* la definición de la variable e infla artificialmente la varianza de Nivel 2.
*
* Además, los faltantes de Nivel 2 no son aleatorios entre estudiantes: son
* sede-año completas sin registro administrativo. Once sede-año sin datos DANE
* y 105 sin registro de dotación. Imputar eso a nivel de estudiante trataría
* como 1.614 casos independientes lo que en realidad son 105.
*
* POR QUÉ PMM Y NO REGRESIÓN LINEAL
* El emparejamiento por media predictiva (`pmm`) toma como valor imputado uno
* efectivamente observado en un caso con predicción similar. Eso garantiza que
* ninguna imputación caiga fuera del rango posible: `pct_planta` no puede
* superar uno, `dotacion_tic` no puede ser negativa y `ln_matricula` no puede
* corresponder a media persona. La regresión lineal no ofrece esa garantía.
********************************************************************************

clear all
set more off
set varabbrev off
set seed 2026
version 17

if "$TESIS_CONFIG" == "" do "C:\Users\RYZEN 5\Desktop\Tesis Multinivel\Definitivo\00_config.do"
cd "$RAIZ"

capture log close _all
local tarea "07_imputacion"
local hoy   "20261024"          // <<< etiqueta de la proxima corrida

capture confirm file "log_`tarea'_`hoy'.log"
if _rc == 0 {
    display as error "Ya existe log_`tarea'_`hoy'.log."
    display as error "Cambiar el local hoy (por ejemplo, anadir un sufijo b, c...)."
    exit 602
}
log using "log_`tarea'_`hoy'.log", text name(fase7)

* Número de imputaciones. Veinte es la referencia habitual cuando la fracción
* de información perdida ronda el 10%, que es el caso de este proyecto.
local M = 20

timer clear 1
timer on 1


********************************************************************************
* PARTE A. IMPUTACIÓN DE LAS VARIABLES DE SEDE (2.447 SEDE-AÑO)
********************************************************************************

display _newline "{hline 78}"
display "PARTE A. IMPUTACIÓN EN EL NIVEL DE SEDE"
display "{hline 78}"

use "N2_Sedes_2018_2023.dta", clear

* Los archivos guardados por los scripts 03 y 05 conservan un `xtset` que
* apunta a `sede_id`, variable que esos scripts crean para el diagnóstico y
* borran antes de guardar. `mi set` se niega a trabajar con esa inconsistencia.
capture xtset, clear

* El contexto municipal entra como predictor: una sede sin registro
* administrativo sigue perteneciendo a un municipio del que sí se conoce todo.
merge m:1 cole_cod_mcpio_ubicacion year using "N3_Municipios_PCA.dta", ///
    keepusing(tasa_homicidios ln_coca ln_inversion_pc) ///
    keep(match) nogenerate

quietly count
display "Sede-año: " r(N)

display _newline "--- Faltantes antes de imputar ---"
misstable summarize ln_matricula ratio_alumnos_docente pct_planta ///
    pct_posgrado dotacion_tic tecnico tecnico_academico

* ----------------------------------------------------------------------
* [A.1] Declaración del conjunto de imputación
* ----------------------------------------------------------------------
mi set flong
mi set M = 0

mi register imputed ln_matricula ratio_alumnos_docente pct_planta ///
    pct_posgrado dotacion_tic tecnico tecnico_academico

* Variables completas que actúan como predictoras. `rural`, `ju_unica` y el
* tamaño de la cohorte evaluada son los mejores predictores disponibles de las
* condiciones administrativas de una sede sin registro.
mi register regular rural ju_unica cole_femenino cole_masculino ///
    sede_principal inse_prom_sede evaluados_sede year ///
    tasa_homicidios ln_coca ln_inversion_pc

* ----------------------------------------------------------------------
* [A.2] Imputación encadenada
* ----------------------------------------------------------------------
* `augment` protege contra la separación perfecta en los modelos logit, que es
* un riesgo real con variables binarias poco frecuentes.
mi impute chained                                                         ///
    (pmm, knn(10)) ln_matricula ratio_alumnos_docente pct_planta          ///
                   pct_posgrado dotacion_tic                              ///
    (logit, augment) tecnico tecnico_academico                            ///
    = rural ju_unica cole_femenino sede_principal inse_prom_sede          ///
      evaluados_sede i.year tasa_homicidios ln_coca ln_inversion_pc,      ///
    add(`M') rseed(2026) dots

display _newline "--- Resumen del conjunto imputado de sede ---"
mi describe

* ----------------------------------------------------------------------
* [A.3] Estandarización intra-anual de la formación docente
* ----------------------------------------------------------------------
* z_posgrado NO se imputa: se deriva de pct_posgrado imputado. Al declararla
* pasiva, la estandarización se rehace dentro de cada imputación, de modo que
* la media y la desviación de cada año se calculan sobre datos completos.
* Imputarla directamente rompería la relación entre ambas variables.
bysort _mi_m year: egen double _mpos = mean(pct_posgrado)
bysort _mi_m year: egen double _spos = sd(pct_posgrado)
generate double z_posgrado_mi = (pct_posgrado - _mpos) / _spos
drop _mpos _spos

capture drop z_posgrado
rename z_posgrado_mi z_posgrado
mi register passive z_posgrado
label variable z_posgrado "Docentes con posgrado, estandarizado dentro del año"

display _newline "--- Verificación de z_posgrado por imputación y año ---"
tabstat z_posgrado if _mi_m > 0, by(year) stat(n mean sd) format(%9.4f)
display "Se espera media cero y desviación uno en cada año."

* ----------------------------------------------------------------------
* [A.4] Guardado del conjunto de sedes
* ----------------------------------------------------------------------
* Las TRES variables de sistema (_mi_m, _mi_id y _mi_miss) tienen que
* sobrevivir al `keep`. Sin `_mi_miss`, Stata deja de reconocer el archivo
* como conjunto de imputación y `mi merge` se detiene.
keep cole_cod_dane_sede year _mi_m _mi_id _mi_miss                        ///
     ln_matricula ratio_alumnos_docente pct_planta pct_posgrado           ///
     z_posgrado dotacion_tic tecnico tecnico_academico

save "MI_Sedes.dta", replace
display _newline "Parte A completada: MI_Sedes.dta"


********************************************************************************
* PARTE B. IMPUTACIÓN DE LAS VARIABLES INDIVIDUALES (69.750 ESTUDIANTES)
********************************************************************************

display _newline "{hline 78}"
display "PARTE B. IMPUTACIÓN EN EL NIVEL DE ESTUDIANTE"
display "{hline 78}"

use "Base_Multinivel_PCA.dta", clear
capture xtset, clear

* Las variables de sede salen de aquí: vienen imputadas de la Parte A.
foreach v in ln_matricula ratio_alumnos_docente pct_planta pct_posgrado ///
             z_posgrado dotacion_tic tecnico tecnico_academico          ///
             ratio_alt dotacion_tic_total inse_prom_sede {
    capture drop `v'
}

* El índice y su descomposición se retiran aquí. Ya no son predictores del
* modelo de imputación y conservarlos solo lograría que el archivo resultante
* arrastrara una versión del índice que puede quedar obsoleta. El script 07c
* los reincorpora, actualizados, después de la unión.
foreach v in indice_vuln indice_vuln_anual vuln_bar vuln_dev {
    capture drop `v'
}

quietly count
display "Estudiantes: " r(N)

display _newline "--- Faltantes antes de imputar ---"
misstable summarize estu_inse_individual mujer lectura_30min ///
    libros_26omas trabaja_mas20 internet_hogar computador_hogar

* ----------------------------------------------------------------------
* [B.1] Media de la cohorte como predictor de contexto
* ----------------------------------------------------------------------
* El modelo de imputación debe reconocer que los estudiantes están agrupados en
* sedes. Incluir la media observada del índice socioeconómico de la sede-año
* traslada esa información al modelo sin necesidad de 437 variables indicadoras.
bysort cole_cod_dane_sede year: egen double inse_sede_obs = ///
    mean(estu_inse_individual)
label variable inse_sede_obs "INSE medio observado de la cohorte (predictor)"

quietly count if missing(inse_sede_obs)
display "Estudiantes sin media de sede observada: " r(N)

* ----------------------------------------------------------------------
* [B.2] Declaración del conjunto de imputación
* ----------------------------------------------------------------------
mi set flong
mi set M = 0

mi register imputed estu_inse_individual mujer lectura_30min ///
    libros_26omas trabaja_mas20 internet_hogar computador_hogar

mi register regular punt_global edad repitente estrato year ///
    rural ju_unica evaluados_sede inse_sede_obs ///
    tasa_homicidios ln_coca ln_inversion_pc

* ----------------------------------------------------------------------
* [B.3] Imputación encadenada, separada por año
* ----------------------------------------------------------------------
* La imputación corre por año porque son cortes transversales repetidos: cada
* cohorte es una muestra distinta y el patrón de faltantes cambia entre años
* (la tasa de ausencia del cuestionario familiar cae a un tercio en 2020).
* Imputar de forma agrupada impondría una estructura común que los datos no
* respaldan.
*
* La variable dependiente entra como predictora. Omitirla sesgaría hacia cero
* las asociaciones entre el puntaje y las covariables imputadas, que es
* precisamente lo que el estudio quiere estimar.
mi impute chained                                                          ///
    (pmm, knn(10)) estu_inse_individual                                    ///
    (logit, augment) mujer lectura_30min libros_26omas trabaja_mas20       ///
                     internet_hogar computador_hogar                       ///
    = punt_global edad repitente rural ju_unica evaluados_sede             ///
      inse_sede_obs tasa_homicidios ln_coca ln_inversion_pc,               ///
    add(`M') rseed(2026) by(year) dots

display _newline "--- Resumen del conjunto imputado de estudiante ---"
mi describe

save "MI_Estudiantes.dta", replace
display _newline "Parte B completada: MI_Estudiantes.dta"


********************************************************************************
* CIERRE
********************************************************************************
* La unión de los dos conjuntos, las variables derivadas y los diagnósticos
* están en 07b_reparar_y_unir.do. Los dos archivos generados aquí NO se borran:
* con lo que cuesta producirlos, conviene que sobrevivan por si hay que rehacer
* la unión sin volver a imputar.

timer off 1
display _newline "--- Tiempo de ejecución ---"
timer list 1

display _newline "{hline 78}"
display "PARTES A Y B COMPLETADAS."
display "Archivos generados: MI_Sedes.dta y MI_Estudiantes.dta"
display ""
display "El modelo de imputación NO usó el índice de vulnerabilidad, sino sus"
display "tres dimensiones crudas. Los valores imputados son por tanto"
display "independientes de cómo se construya el índice."
display ""
display "Siguiente: correr 07b_reparar_y_unir_v2.do y después 07c."
display "{hline 78}"

log close fase7

********************************************************************************
* PROYECTO : Desempeño Saber 11 en sedes oficiales del Cauca, 2018-2023
* SCRIPT   : 14 - SENSIBILIDAD DE MUESTRA Y DIAGNÓSTICOS (corrección C5)
* ENTRADA  : Base_Estimacion.dta
* SALIDA   : log_14_sensibilidad_20261013.log
*            C5_*.ster, diag_*_20261013.png, C5_ajuste_20261013.dta
* STATA    : 17
* VERSIÓN  : 2 - revisión del borrador de C5.md
********************************************************************************
* QUÉ CAMBIA RESPECTO DEL BORRADOR DE C5.md
*
* [E1] LA ESTRUCTURA ALEATORIA. El borrador usaba
*          || mcpio_id: || mcpio_anio: || sede_anio:
*      que es la escritura ANIDADA que C1 descartó: en ella el componente
*      municipio-año se estima en la frontera (9,72e-09) y `estat icc` devuelve
*      el mismo valor para municipio y para municipio|municipio
*      [log_11_estructura.log, bloque 1(a); anexo_registro_C1, §2].
*      La especificación vigente es la CRUZADA:
*          || mcpio_id: || mcpio_id: R.year || sede_id: || sede_anio: , reml
*      Correr el borrador habría producido tres horas de resultados no
*      comparables con el Capítulo 4.
*
* [E2] `predict, reffects` necesita CUATRO nombres, no tres: la estructura
*      cruzada tiene cuatro ecuaciones de efectos aleatorios.
*
* [E3] El M5 de casos completos usaba la especificación anterior a C6 (dos
*      componentes, MLE, sin efectos de año) y omitía la variante CON controles
*      de medición, que es la que decide según la regla fijada de antemano.
*
* [E4] `egen` corría antes de `mi extract`, dejando variables sin registrar en
*      el conjunto `mi`. Ahora se extrae primero y se deriva después.
*
* [P1] El log llevaba `replace`. Prohibido: así se perdió la salida del bloque
*      [7] del `10` el 13 de octubre [anexo_registro_C2, §8]. Log fechado, sin
*      `replace`, con comprobación previa de existencia.
*
* [P3] Orden invertido. El bloque de casos completos decide si hay que
*      reimputar; si saliera que sí, las submuestras habría que repetirlas.
*      Por eso va primero.
*
* TRAMPA DE NOMENCLATURA (anexo_registro_C1, §2)
* En la estructura cruzada, las dos ecuaciones del municipio comparten nivel:
*      municipio      lns1_1_1
*      municipio-año  lns1_2_1     <- NO lns2_1_1
*      sede           lns2_1_1     <- NO lns3_1_1
*      sede-año       lns3_1_1     <- NO lns4_1_1 (no existe)
* Este script no extrae varianzas por nombre, pero si se añade algún bloque que
* lo haga, hay que usar estos.
*
* ANTES DE CORRER: copiar literalmente de 15_gradiente_medicion.do las dos
* líneas de M5 con controles de medición y verificar el nombre y el centrado de
* c_sd_inse. Si no coinciden con los de abajo, la comparación con casos
* completos NO será comparable con la Tabla 25b y no sirve para aplicar la
* regla de decisión de C5.
********************************************************************************

clear all
set more off
set varabbrev off
set seed 2026
version 17

if "$TESIS_CONFIG" == "" do "C:\Users\RYZEN 5\Desktop\Tesis Multinivel\Definitivo\00_config.do"
cd "$RAIZ"

* ---------------------------------------------------------------------------
* Log fechado. NUNCA `replace`: un log es evidencia, no un archivo de trabajo.
* ---------------------------------------------------------------------------
capture log close _all

* DOS ETIQUETAS DISTINTAS, y conviene no confundirlas:
*
*   `hoy`   etiqueta las SALIDAS de esta corrida: el log, los .ster, los .png.
*           Cambia en cada corrida, porque el log nunca se sobrescribe. Si se
*           reanuda el script el mismo día, añadir un sufijo: 20261013b, c, ...
*
*   `fbase` etiqueta la base de trabajo que dejó el bloque [0] y que leen los
*           bloques [1] a [3]. NO cambia: apunta a un archivo que ya está en
*           disco. Si se vuelve a correr el bloque [0], lo reescribe bajo este
*           mismo nombre, que es lo que se quiere.
local hoy   "20261014"
local fbase "20261013"

capture confirm file "log_14_sensibilidad_`hoy'.log"
if _rc == 0 {
    display as error "Ya existe log_14_sensibilidad_`hoy'.log."
    display as error "Cambiar el local hoy (anadir un sufijo) o renombrar el anterior."
    exit 602
}
log using "log_14_sensibilidad_`hoy'.log", text name(fase14)

* ---------------------------------------------------------------------------
* INTERRUPTORES. Los bloques [0] y [1] ya están hechos; esta corrida ejecuta
* el [2] y el [3].
* ---------------------------------------------------------------------------
* ESTADO AL 14 DE OCTUBRE
* Los bloques [0] y [1] ya corrieron y sus resultados están cerrados; no se
* vuelven a ejecutar. La regla de decisión de C5 se aplicó sobre el bloque [1]
* y su veredicto fue no reimputar, de modo que `07_imputacion_v3.do` queda
* intacto y esta corrida no puede cambiarlo.
*
* Lo que falta es el bloque [2], que es el que responde a la petición del tutor
* de controlar la influencia de Popayán, y el bloque [3], que produce el anexo
* de diagnósticos. Van juntos en una sola corrida: el [2] primero, porque es el
* que el informe ya promete en 3.4.4 y en 4.5.
*
* Tiempos observados frente a los estimados: el bloque [0] tardó 430,49 s (3,6
* veces lo previsto, por entrada y salida) y el bloque [1] 942,82 s (un tercio
* de lo previsto, porque es estimación). Las cifras de abajo están corregidas
* con esa experiencia.
local hacer_prev      = 0    // [0] verificaciones y conteos   (hecho: 7 min 10 s)
local hacer_cc        = 0    // [1] casos completos            (hecho: 15 min 43 s)
local hacer_muestras  = 1    // [2] submuestras                (1 h 15 - 2 h 15)
local hacer_diag      = 1    // [3] diagnósticos y ajuste      (20-35 min)

* Globales idénticas a 08_estimacion_v5.do, bloque [2.4]
global v_n1 mujer edad repitente lectura_30min libros_26omas ///
            trabaja_mas20 internet_hogar computador_hogar
global v_n2 ln_matricula ratio_alumnos_docente pct_planta z_posgrado ///
            dotacion_tic rural ju_unica tecnico tecnico_academico ///
            cole_femenino
global v_mun tasa_homicidios_bar tasa_homicidios_dev ln_coca_bar ///
             ln_coca_dev ln_inversion_pc_bar ln_inversion_pc_dev

timer clear


********************************************************************************
* [0] VERIFICACIONES PREVIAS Y CONTEOS
********************************************************************************
* Barato y rápido. Evita descubrir a las dos horas que falta una variable o que
* 19001 no es el código que se supone.

if `hacer_prev' == 1 {

    timer on 1
    display _newline "{hline 78}"
    display "[0] VERIFICACIONES PREVIAS"
    display "{hline 78}"

    use "Base_Estimacion.dta", clear

    * --- [0.1] Que estén todas las variables del modelo ---
    foreach v of global v_n1 {
        confirm variable `v'
    }
    foreach v of global v_n2 {
        confirm variable `v'
    }
    foreach v of global v_mun {
        confirm variable `v'
    }
    confirm variable punt_global estu_inse_individual indice_vuln
    confirm variable cole_cod_dane_sede cole_cod_mcpio_ubicacion year
    confirm variable mcpio_id sede_id
    display "Todas las variables del modelo están presentes."

    * --- [0.2] Faltantes con fecha propia ---
    * El log_07 es del 21 de agosto. C5 necesita su propia constancia.
    display _newline "--- Faltantes de Nivel 1 en m = 0 (sobre 69.750) ---"
    mi xeq 0: misstable summarize estu_inse_individual mujer lectura_30min ///
        libros_26omas trabaja_mas20 internet_hogar computador_hogar

    display _newline "--- Faltantes de Nivel 2 en m = 0, a nivel de estudiante ---"
    mi xeq 0: misstable summarize ln_matricula ratio_alumnos_docente ///
        pct_planta pct_posgrado z_posgrado dotacion_tic tecnico ///
        tecnico_academico

    display _newline "--- Estado del conjunto de imputación ---"
    mi describe

    * --- [0.3] Identificadores de la estructura cruzada ---
    capture drop mcpio_anio sede_anio
    egen long mcpio_anio = group(cole_cod_mcpio_ubicacion year)
    egen long sede_anio  = group(cole_cod_dane_sede year)
    mi register regular mcpio_anio sede_anio

    quietly summarize mcpio_anio
    display _newline "Combinaciones municipio-año: " r(max) " (esperadas: 252)"
    quietly summarize sede_anio
    display "Combinaciones sede-año: " r(max) " (esperadas: 2.447)"

    * --- [0.4] ¿Es 19001 Popayán? ---
    * log_08, bloque [1]: el municipio mayor del agrupado tiene 13.962
    * estudiantes. Si 19001 no es ese, el código está mal y hay que corregirlo
    * antes de estimar nada "sin Popayán".
    display _newline "--- Verificación del código de Popayán ---"
    quietly count if cole_cod_mcpio_ubicacion == 19001 & _mi_m == 0
    local n19001 = r(N)
    display "Estudiantes en el municipio 19001: `n19001'"
    display "Esperado si 19001 es Popayán: 13.962 [log_08, bloque 1]"

    preserve
        keep if _mi_m == 0
        contract cole_cod_mcpio_ubicacion
        gsort -_freq
        display _newline "Cinco municipios con más estudiantes:"
        list in 1/5, clean noobs
    restore

    if `n19001' != 13962 {
        display as error _newline "ATENCIÓN: 19001 no reúne 13.962 estudiantes."
        display as error "Verificar el código de Popayán antes del bloque [2]."
    }

    * --- [0.5] N de cada submuestra ---
    capture drop _t n_anios panel_bal popayan
    egen byte _t = tag(cole_cod_dane_sede year) if _mi_m == 0
    bysort cole_cod_dane_sede: egen byte n_anios = total(_t)
    drop _t
    generate byte panel_bal = (n_anios == 6)
    generate byte popayan   = (cole_cod_mcpio_ubicacion == 19001)
    mi register regular n_anios panel_bal popayan

    display _newline "--- Tamaño de cada submuestra (m = 0) ---"
    tabulate panel_bal if _mi_m == 0
    tabulate repitente if _mi_m == 0
    tabulate popayan   if _mi_m == 0

    * --- [0.6] Tamaño de la muestra de casos completos ---
    * No es aleatoria: está sesgada hacia las sedes con mejor reporte. Sirve
    * como cota de la atenuación, nunca como estimador preferido.
    display _newline "--- Casos completos con el modelo completo ---"
    quietly count if _mi_m == 0 & !missing(punt_global, estu_inse_individual, ///
        mujer, edad, repitente, lectura_30min, libros_26omas,                 ///
        trabaja_mas20, internet_hogar, computador_hogar)
    display "Completos en Nivel 1: " r(N) " de 69.750"
    quietly count if _mi_m == 0 & !missing(ln_matricula,                      ///
        ratio_alumnos_docente, pct_planta, z_posgrado, dotacion_tic,          ///
        tecnico, tecnico_academico)
    display "Completos en Nivel 2: " r(N) " de 69.750"

    save "C5_Base_Trabajo_`fbase'.dta", replace
    display _newline "Base de trabajo guardada: C5_Base_Trabajo_`fbase'.dta"

    timer off 1
    display _newline "Tiempo del bloque [0]:"
    timer list 1
}


********************************************************************************
* [1] CASOS COMPLETOS: EL BLOQUE QUE DECIDE
********************************************************************************
* Acota empíricamente la atenuación de la interacción de M5 que produce omitir
* pct_planta del modelo de imputación de Nivel 1 (H6).
*
* La regla de decisión está fijada en el registro de C5, antes de esta corrida.
* Lo esencial: la retirada del hallazgo en C6 descansa en la interacción CON
* controles de medición (0,063; E. E. 0,101), no en la versión sin ellos. Por
* tanto el estimador que decide es CC_M5_ctrl, no CC_M5.

if `hacer_cc' == 1 {

    timer on 2
    display _newline "{hline 78}"
    display "[1] CASOS COMPLETOS (m = 0, derivadas recalculadas)"
    display "{hline 78}"

    * Falla rápido y con mensaje claro si la base del bloque [0] no está donde
    * se espera, en vez de abortar con un r(601) sin contexto.
    capture confirm file "C5_Base_Trabajo_`fbase'.dta"
    if _rc != 0 {
        display as error "No se encuentra C5_Base_Trabajo_`fbase'.dta."
        display as error "Correr el bloque [0] o ajustar el local fbase."
        exit 601
    }

    use "C5_Base_Trabajo_`fbase'.dta", clear

    * Primero se extrae, después se deriva. Al revés deja variables sin
    * registrar dentro del conjunto `mi`.
    mi extract 0, clear

    * En m = 0 las variables centradas están vacías por diseño
    * [log_08, bloque 2.1]. Se reconstruyen sobre los observados.
    drop inse_prom_sede c_inse cwc_inse c_inse_prom_sede

    bysort cole_cod_dane_sede year: egen double inse_prom_sede = ///
        mean(estu_inse_individual)
    label variable inse_prom_sede "INSE medio de la cohorte (observados)"

    bysort year: egen double _gm = mean(estu_inse_individual)
    generate double c_inse = estu_inse_individual - _gm
    drop _gm

    generate double cwc_inse = estu_inse_individual - inse_prom_sede

    bysort year: egen double _gms = mean(inse_prom_sede)
    generate double c_inse_prom_sede = inse_prom_sede - _gms
    drop _gms

    * Control de medición de C6: dispersión del índice dentro de la cohorte de
    * sede, centrada en la media del año.
    * >>> VERIFICAR CONTRA 15_gradiente_medicion.do ANTES DE CORRER <<<
    bysort cole_cod_dane_sede year: egen double _sd_inse = ///
        sd(estu_inse_individual)
    bysort year: egen double _gsd = mean(_sd_inse)
    generate double c_sd_inse = _sd_inse - _gsd
    drop _gsd
    label variable c_sd_inse "DE del INSE en la cohorte de sede, centrada"

    display _newline "--- Dispersión del índice dentro de la cohorte ---"
    tabstat _sd_inse, by(year) stat(n mean sd min max) format(%9.4f)

    * Cohortes de al menos diez estudiantes (quinta fila de la Tabla 25b)
    bysort cole_cod_dane_sede year: generate long _n_coh = _N
    generate byte coh10 = (_n_coh >= 10)
    tabulate coh10

    * ----------------------------------------------------------------------
    * MUESTRA COMÚN. `sd()` devuelve faltante en las cohortes con un solo
    * estudiante con INSE observado, de modo que c_sd_inse no existe en esas
    * filas y los modelos CON controles de medición estimarían sobre MENOS
    * observaciones que los que van sin ellos. Sin esta marca, una caída de la
    * interacción entre [1.2] y [1.3] sería inseparable de un cambio de muestra.
    * ----------------------------------------------------------------------
    generate byte muestra_ctrl = !missing(c_sd_inse)
    label variable muestra_ctrl "Cohorte con dispersión del INSE calculable"

    quietly count if missing(_sd_inse)
    display _newline "Estudiantes sin dispersión calculable: " r(N)
    quietly levelsof sede_anio if missing(_sd_inse), local(sa_sin)
    display "Sede-año afectadas: " `: word count `sa_sin''
    tabulate muestra_ctrl

    * --- [1.1] ML3b sobre casos completos ---
    display _newline "--- CC_ML3b: temporal con cuatro componentes ---"
    mixed punt_global c_inse $v_n1 $v_n2 $v_mun ib2018.year              ///
        || mcpio_id: || mcpio_id: R.year                                 ///
        || sede_id: || sede_anio: , reml
    display "Observaciones utilizadas: " e(N)
    estimates save "C5_CC_ML3b_`hoy'.ster", replace

    * --- [1.2] M5 SIN controles de medición ---
    * Comparable con la TERCERA fila de la Tabla 25b.
    display _newline "--- CC_M5: sin controles de medición ---"
    mixed punt_global c.cwc_inse##c.pct_planta c.cwc_inse##c.indice_vuln ///
        c_inse_prom_sede $v_n1 $v_n2 ib2018.year                         ///
        || mcpio_id: || mcpio_id: R.year                                 ///
        || sede_id: cwc_inse, covariance(unstructured)                   ///
        || sede_anio: , reml
    display "Observaciones utilizadas: " e(N)
    estimates save "C5_CC_M5_`hoy'.ster", replace

    display _newline "Contraste conjunto de las dos interacciones:"
    testparm c.cwc_inse#c.pct_planta c.cwc_inse#c.indice_vuln
    display "Comparar con: 0,223 (0,101), p conjunto 0,016, Holm 0,055"
    display "[anexo_registro_C6, Tabla 25b, tercera fila]"

    * --- [1.2b] El mismo modelo sobre la muestra común ---
    * Es el que se compara con [1.3]. La diferencia entre [1.2] y [1.2b] mide
    * el efecto del cambio de muestra; la diferencia entre [1.2b] y [1.3] mide
    * el efecto de los controles. Sin este modelo las dos cosas van juntas.
    display _newline "--- CC_M5_com: sin controles, sobre la muestra común ---"
    mixed punt_global c.cwc_inse##c.pct_planta c.cwc_inse##c.indice_vuln ///
        c_inse_prom_sede $v_n1 $v_n2 ib2018.year if muestra_ctrl == 1    ///
        || mcpio_id: || mcpio_id: R.year                                 ///
        || sede_id: cwc_inse, covariance(unstructured)                   ///
        || sede_anio: , reml
    display "Observaciones utilizadas: " e(N)
    estimates save "C5_CC_M5_com_`hoy'.ster", replace
    testparm c.cwc_inse#c.pct_planta c.cwc_inse#c.indice_vuln

    * --- [1.3] M5 CON controles de medición: EL ESTIMADOR QUE DECIDE ---
    * Comparable con la CUARTA fila de la Tabla 25b.
    display _newline "--- CC_M5_ctrl: con controles de medición ---"
    mixed punt_global c.cwc_inse##c.pct_planta c.cwc_inse##c.indice_vuln ///
        c.cwc_inse##c.c_sd_inse c.cwc_inse##i.rural                      ///
        c_inse_prom_sede $v_n1 $v_n2 ib2018.year                         ///
        || mcpio_id: || mcpio_id: R.year                                 ///
        || sede_id: cwc_inse, covariance(unstructured)                   ///
        || sede_anio: , reml
    display "Observaciones utilizadas: " e(N)
    estimates save "C5_CC_M5_ctrl_`hoy'.ster", replace

    display _newline "Contraste conjunto de las dos interacciones declaradas:"
    testparm c.cwc_inse#c.pct_planta c.cwc_inse#c.indice_vuln
    display "Comparar con: 0,063 (0,101), p 0,537, p conjunto 0,194"
    display "[anexo_registro_C6, Tabla 25b, cuarta fila]"
    display ""
    display "REGLA: la reimputación revierte la retirada del hallazgo SOLO si"
    display "ESTA interacción alcanza Holm <= 0,05. Que lo alcance en [1.2] es"
    display "insuficiente y no se presentará como motivo para reabrirlo."
    display ""
    display "REGLA DE DIRECCIÓN: la hipótesis de atenuación predice que el"
    display "coeficiente de casos completos sea MAYOR en valor absoluto que el"
    display "imputado. Si sale menor, la hipótesis no recibe respaldo y no se"
    display "reimputa, cualquiera que sea la magnitud de la diferencia."

    * --- [1.4] M5 con controles, cohortes de diez o más ---
    * Opcional. Comparable con la QUINTA fila de la Tabla 25b.
    display _newline "--- CC_M5_ctrl10: cohortes de al menos diez ---"
    mixed punt_global c.cwc_inse##c.pct_planta c.cwc_inse##c.indice_vuln ///
        c.cwc_inse##c.c_sd_inse c.cwc_inse##i.rural                      ///
        c_inse_prom_sede $v_n1 $v_n2 ib2018.year if coh10 == 1           ///
        || mcpio_id: || mcpio_id: R.year                                 ///
        || sede_id: cwc_inse, covariance(unstructured)                   ///
        || sede_anio: , reml
    display "Observaciones utilizadas: " e(N)
    estimates save "C5_CC_M5_ctrl10_`hoy'.ster", replace
    display "Comparar con: 0,040 (0,107), p 0,707, p conjunto 0,386"
    display "[anexo_registro_C6, Tabla 25b, quinta fila]"

    save "C5_Base_CC_`hoy'.dta", replace

    timer off 2
    display _newline "Tiempo del bloque [1]:"
    timer list 2
}


********************************************************************************
* [2] SUBMUESTRAS SOBRE LA BASE IMPUTADA
********************************************************************************
* Produce la tabla de sensibilidad del apartado 4.5. Usa cinco imputaciones,
* como los procedimientos de inferencia de C1 [anexo_registro_C1, §6], y se
* declara así en la nota de la tabla.

if `hacer_muestras' == 1 {

    timer on 3
    display _newline "{hline 78}"
    display "[2] SUBMUESTRAS (imputaciones 1 a 5)"
    display "{hline 78}"

    use "C5_Base_Trabajo_`fbase'.dta", clear

    local cond1 "1"
    local cond2 "panel_bal == 1"
    local cond3 "repitente == 0"
    local cond4 "popayan == 0"

    local nom1 "Muestra completa"
    local nom2 "Panel balanceado de sedes"
    local nom3 "Sin repitentes de la prueba"
    local nom4 "Sin Popayan"

    forvalues s = 1/4 {

        display _newline "{hline 78}"
        display "SUBMUESTRA `s': `nom`s''"
        display "{hline 78}"

        display _newline "--- S`s'_ML3b ---"
        mi estimate, imputations(1/5) dots post: mixed punt_global       ///
            c_inse $v_n1 $v_n2 $v_mun ib2018.year if `cond`s''           ///
            || mcpio_id: || mcpio_id: R.year                             ///
            || sede_id: || sede_anio: , reml
        estimates save "C5_S`s'_ML3b_`hoy'.ster", replace

        display _newline "--- S`s'_M3cwc agrupado ---"
        mi estimate, imputations(1/5) dots post: mixed punt_global       ///
            cwc_inse c_inse_prom_sede $v_n1 $v_n2 indice_vuln            ///
            ib2018.year if `cond`s''                                     ///
            || mcpio_id: || mcpio_id: R.year                             ///
            || sede_id: || sede_anio: , reml
        estimates save "C5_S`s'_M3cwc_`hoy'.ster", replace

        display _newline "Contraste de igualdad entre efectos:"
        test cwc_inse = c_inse_prom_sede
        lincom cwc_inse - c_inse_prom_sede
    }

    * --- Indicadora de Popayán en lugar de excluirlo ---
    * El 3.4.4 corregido nombra a Popayán; esta es la forma de controlarlo sin
    * perder sus observaciones.
    display _newline "{hline 78}"
    display "SUBMUESTRA 5: muestra completa con indicadora de Popayan"
    display "{hline 78}"
    mi estimate, imputations(1/5) dots post: mixed punt_global           ///
        c_inse $v_n1 $v_n2 $v_mun popayan ib2018.year                    ///
        || mcpio_id: || mcpio_id: R.year                                 ///
        || sede_id: || sede_anio: , reml
    estimates save "C5_S5_ML3b_popayan_`hoy'.ster", replace

    timer off 3
    display _newline "Tiempo del bloque [2]:"
    timer list 3
}


********************************************************************************
* [3] DIAGNÓSTICOS Y AJUSTE (sobre m = 1)
********************************************************************************
* Punto F de la hoja de ruta: tabla de diagnósticos y ajuste.
*
* AVISO SOBRE AIC/BIC: sólo son comparables entre modelos ajustados por máxima
* verosimilitud ORDINARIA sobre la misma muestra. Por eso la progresión anual
* usa `mle` y no `reml`: bajo REML la verosimilitud depende de la parte fija y
* los criterios no son comparables entre especificaciones con distintos
* regresores. Esto queda escrito aquí para que el anexo lo declare.

if `hacer_diag' == 1 {

    timer on 4
    display _newline "{hline 78}"
    display "[3] DIAGNÓSTICOS Y AJUSTE (primera imputación)"
    display "{hline 78}"

    * Si el `predict ... reffects` del bloque [3.2] aborta por memoria, los
    * resultados del bloque [2] YA están escritos en este log: no se pierden.
    * Para reanudar sólo el sub-bloque que falló, poner hacer_muestras = 0,
    * dejar hacer_diag = 1 y cambiar `hoy` a "20261014b".
    capture confirm file "C5_Base_Trabajo_`fbase'.dta"
    if _rc != 0 {
        display as error "No se encuentra C5_Base_Trabajo_`fbase'.dta."
        display as error "Correr el bloque [0] o ajustar el local fbase."
        exit 601
    }

    use "C5_Base_Trabajo_`fbase'.dta", clear
    mi extract 1, clear

    * --- [3.1] Ajuste de la progresión, cohorte por cohorte ---
    * Mismas especificaciones del 08, bloque [3]: dos componentes y MLE.
    tempname pa
    postfile `pa' int year str8 modelo double ll aic bic int gl ///
        using "C5_ajuste_`hoy'.dta", replace

    display _newline "Ano  Modelo    log-verosimilitud       AIC         BIC"

    foreach a in 2018 2019 2020 2021 2022 2023 {

        * M0: modelo nulo
        quietly mixed punt_global if year == `a' ///
            || mcpio_id: || sede_id: , mle
        quietly estat ic
        matrix S = r(S)
        post `pa' (`a') ("M0") (S[1,3]) (S[1,5]) (S[1,6]) (S[1,4])
        display "`a'  M0      " %12.2f S[1,3] %12.2f S[1,5] %12.2f S[1,6]

        * M1a: gradiente total
        quietly mixed punt_global c_inse mujer edad if year == `a' ///
            || mcpio_id: || sede_id: , mle
        quietly estat ic
        matrix S = r(S)
        post `pa' (`a') ("M1a") (S[1,3]) (S[1,5]) (S[1,6]) (S[1,4])
        display "`a'  M1a     " %12.2f S[1,3] %12.2f S[1,5] %12.2f S[1,6]

        * M1: bloque individual completo
        quietly mixed punt_global c_inse $v_n1 if year == `a' ///
            || mcpio_id: || sede_id: , mle
        quietly estat ic
        matrix S = r(S)
        post `pa' (`a') ("M1") (S[1,3]) (S[1,5]) (S[1,6]) (S[1,4])
        display "`a'  M1      " %12.2f S[1,3] %12.2f S[1,5] %12.2f S[1,6]

        * M2: añade condiciones institucionales
        quietly mixed punt_global c_inse $v_n1 $v_n2 if year == `a' ///
            || mcpio_id: || sede_id: , mle
        quietly estat ic
        matrix S = r(S)
        post `pa' (`a') ("M2") (S[1,3]) (S[1,5]) (S[1,6]) (S[1,4])
        display "`a'  M2      " %12.2f S[1,3] %12.2f S[1,5] %12.2f S[1,6]

        * M3: añade vulnerabilidad
        quietly mixed punt_global c_inse $v_n1 $v_n2 indice_vuln ///
            if year == `a' || mcpio_id: || sede_id: , mle
        quietly estat ic
        matrix S = r(S)
        post `pa' (`a') ("M3") (S[1,3]) (S[1,5]) (S[1,6]) (S[1,4])
        display "`a'  M3      " %12.2f S[1,3] %12.2f S[1,5] %12.2f S[1,6]

        * M3cwc: referencia del capítulo
        quietly mixed punt_global cwc_inse c_inse_prom_sede $v_n1 $v_n2 ///
            indice_vuln if year == `a' || mcpio_id: || sede_id: , mle
        quietly estat ic
        matrix S = r(S)
        post `pa' (`a') ("M3cwc") (S[1,3]) (S[1,5]) (S[1,6]) (S[1,4])
        display "`a'  M3cwc   " %12.2f S[1,3] %12.2f S[1,5] %12.2f S[1,6]
    }

    postclose `pa'

    display _newline "Tabla de ajuste guardada: C5_ajuste_`hoy'.dta"
    display "Nota: AIC y BIC comparables solo dentro de cada cohorte, porque la"
    display "muestra cambia entre anos. Estimados por MLE, no por REML."

    * --- [3.2] Supuestos sobre el modelo temporal ---
    display _newline "--- Supuestos distribucionales de ML3b ---"
    mixed punt_global c_inse $v_n1 $v_n2 $v_mun ib2018.year              ///
        || mcpio_id: || mcpio_id: R.year                                 ///
        || sede_id: || sede_anio: , reml
    estimates save "C5_diag_ML3b_`hoy'.ster", replace

    * CUATRO efectos aleatorios, no tres: municipio, municipio-ano, sede y
    * sede-ano. Operación pesada: C1 ya chocó con un fallo de memoria al
    * intentar Kenward-Roger sobre el municipio mayor, de 13.962 estudiantes
    * [anexo_registro_C1, §5]. Si aquí falla, correr este sub-bloque solo.
    predict double re_mcpio re_mcpio_anio re_sede re_sede_anio, reffects
    predict double res, residuals

    capture drop _tm _tsa
    egen byte _tm  = tag(mcpio_id)
    egen byte _tsa = tag(sede_anio)

    qnorm re_mcpio if _tm == 1, title("Efectos aleatorios de municipio")
    graph export "diag_qq_mcpio_`hoy'.png", replace width(1600)

    qnorm re_sede_anio if _tsa == 1, title("Efectos aleatorios de sede-año")
    graph export "diag_qq_sede_anio_`hoy'.png", replace width(1600)

    qnorm res, title("Residuos individuales")
    graph export "diag_qq_residuos_`hoy'.png", replace width(1600)

    display _newline "--- Desviación estándar residual por año ---"
    tabstat res, by(year)  stat(n mean sd) format(%9.3f)

    display _newline "--- Desviación estándar residual por zona ---"
    tabstat res, by(rural) stat(n mean sd) format(%9.3f)

    timer off 4
    display _newline "Tiempo del bloque [3]:"
    timer list 4
}


********************************************************************************
* CIERRE
********************************************************************************

display _newline "{hline 78}"
display "SCRIPT 14 TERMINADO."
display ""
display "Tiempos por bloque:"
timer list
display ""
display "Con este log se cierran los dos marcadores [PENDIENTE C5] que quedan"
display "en el informe: la tabla de sensibilidad de 4.5 y la nota del Anexo E."
display ""
display "NO rellenar ningun marcador hasta que este log este cerrado y revisado."
display "{hline 78}"

log close fase14

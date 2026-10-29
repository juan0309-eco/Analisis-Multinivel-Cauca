********************************************************************************
* PROYECTO : Desempeño Saber 11 en sedes oficiales del Cauca, 2018-2023
* SCRIPT   : 10 - BLINDAJE FRENTE A LAS OBJECIONES DEL JURADO
* ENTRADA  : Base_Estimacion.dta, Base_Multinivel_PCA.dta, N3_Municipios_PCA.dta
*            y los archivos .ster generados por el 08 y el 11
* SALIDA   : log_10_blindaje.log  (todo el contenido es para el documento)
* STATA    : 17
********************************************************************************
* ESTADO DESPUÉS DE C1 Y C2 (13 de octubre de 2026)
*
* Este script se corrió completo el 23 de agosto de 2026 y su log alimenta el
* Anexo F del informe. Dos bloques quedaron superados por correcciones
* posteriores y sus interruptores están en 0:
*
*   [6] TOST del efecto composicional. Retirado en C2. Cargaba M3_cwc.ster,
*       residuo de la versión 4 del 08 que ningún script de la cadena genera, y
*       su lincom calculaba beta_w - beta_b, que es el negativo del efecto
*       contextual. Sustituido por 12_composicional.do y la Tabla 11b.
*
*   [7] Planta docente. Terminó en r(451) por `xtset sede_id year` sobre datos
*       a nivel de estudiante. Corregido aparte en 10b_planta_fe_v2.do.
*
* Además, el bloque [1] pasa a leer ML3b.ster en lugar de ML3.ster, según lo
* decidido en C1: la estructura aleatoria de dos componentes quedó reemplazada
* por la de cuatro. Si se reejecuta el bloque [1], el EMD que produce es el de
* la columna ML3b de la Tabla 28 y no el de la especificación antigua.
*
* AL REEJECUTAR: los bloques [2] y [3] tardan horas y estiman sobre la
* estructura aleatoria ANTIGUA a propósito, porque su función es documentar que
* ni REML ni el estimador sándwich explican los desplazamientos reportados en
* el Capítulo 4. No cambiarles la estructura: perderían su objeto.
********************************************************************************
* QUÉ RESUELVE CADA BLOQUE
*
* [1] Cotas sustantivas de los coeficientes nulos.
*     Objeción: "no se distingue entre no hay efecto y no hay potencia".
*     No requiere reestimar: reescala los coeficientes ya guardados a puntos de
*     examen por desviación estándar dentro del municipio, y calcula el efecto
*     mínimo detectable. Es el bloque de mayor rendimiento y el más rápido.
*
* [2] Reestimación por REML.
*     Objeción: con 42 municipios, la máxima verosimilitud subestima el
*     componente de varianza de Nivel 3. REML corrige justamente ese sesgo.
*
* [3] Errores estándar robustos por clúster.
*     Objeción: no se declara si los errores son de máxima verosimilitud o
*     corregidos, habiendo heterocedasticidad entre cohortes.
*
* [4] Prueba de la hipótesis de selección de sobrevivientes.
*     Objeción: las tres explicaciones del resultado nulo de violencia se
*     afirman pero no se prueban. Esta sí se puede poner a prueba.
*
* [5] Los dos atípicos del FUT frente a la vulnerabilidad.
*     Objeción: puede que no sean error de reporte sino crisis administrativa
*     en los municipios más vulnerables.
*
* [6] RETIRADO EN C2. Prueba de equivalencia para el contraste de centrado.
*     La objeción que atendía (un contraste de diferencia nula no distingue
*     "no hay efecto composicional" de "no hay potencia para detectarlo") queda
*     resuelta en 12_composicional.do, bloques [1] a [3], que además identifica
*     el efecto con potencia declarada. NO REACTIVAR.
*
* [7] RETIRADO. Diagnóstico de la hipótesis rival sobre los docentes de planta.
*     Falla con r(451). Corregido en 10b_planta_fe_v2.do.
*
* TIEMPO: los bloques [1], [4] y [5] tardan minutos. El [2] y el [3] reestiman
* modelos mixtos sobre veinte imputaciones y tardan horas. Cada uno tiene su
* propio interruptor.
********************************************************************************

clear all
set more off
set varabbrev off
version 17

if "$TESIS_CONFIG" == "" do "C:\Users\RYZEN 5\Desktop\Tesis Multinivel\Definitivo\00_config.do"
cd "$RAIZ"

capture log close _all
local tarea "10_blindaje"
local hoy   "20261024"          // <<< etiqueta de la proxima corrida

capture confirm file "log_`tarea'_`hoy'.log"
if _rc == 0 {
    display as error "Ya existe log_`tarea'_`hoy'.log."
    display as error "Cambiar el local hoy (por ejemplo, anadir un sufijo b, c...)."
    exit 602
}
log using "log_`tarea'_`hoy'.log", text name(fase10)

local hacer_cotas    = 1    // [1] rápido. Lee ML3b.ster (C1)
local hacer_reml     = 1    // [2] LENTO
local hacer_robust   = 1    // [3] LENTO
local hacer_desercion= 1    // [4] rápido
local hacer_atipicos = 1    // [5] rápido
local hacer_tost     = 0    // [6] RETIRADO EN C2: ver 12_composicional.do
local hacer_planta   = 0    // [7] RETIRADO: r(451). Ver 10b_planta_fe_v2.do

global v_n1 mujer edad repitente lectura_30min libros_26omas ///
            trabaja_mas20 internet_hogar computador_hogar

global v_n2 ln_matricula ratio_alumnos_docente pct_planta z_posgrado ///
            dotacion_tic rural ju_unica tecnico tecnico_academico ///
            cole_femenino


********************************************************************************
* [1] COTAS SUSTANTIVAS DE LOS COEFICIENTES NULOS
********************************************************************************
* El coeficiente de homicidios está en puntos por unidad de la tasa, una escala
* en la que cualquier número parece pequeño. Reescalarlo a puntos por
* desviación estándar DENTRO del municipio lo vuelve interpretable y convierte
* un resultado nulo en una cota: en lugar de "no encontramos efecto" se puede
* afirmar "descartamos efectos mayores que X".
*
* Las desviaciones within salen del xtsum del script 06. Se recalculan aquí en
* vez de copiarse a mano, para que el número del documento no se desactualice.

if `hacer_cotas' == 1 {

    display _newline "{hline 78}"
    display "[1] COTAS SUSTANTIVAS DE LOS COEFICIENTES DEL ENTORNO"
    display "{hline 78}"

    use "N3_Municipios_PCA.dta", clear
    xtset cole_cod_mcpio_ubicacion year

    quietly xtsum tasa_homicidios
    scalar sd_w_hom = r(sd_w)
    quietly xtsum ln_coca
    scalar sd_w_coca = r(sd_w)
    quietly xtsum ln_inversion_pc
    scalar sd_w_inv = r(sd_w)

    display _newline "--- Desviaciones estándar dentro del municipio ---"
    display "Homicidios:  " %8.4f sd_w_hom
    display "Coca:        " %8.4f sd_w_coca
    display "Inversión:   " %8.4f sd_w_inv

    * CAMBIO DE C1: la especificación vigente es ML3b, con municipio-año y
    * sede-año. ML3.ster corresponde a la estructura de dos componentes, que el
    * Capítulo 4 ya no reporta como principal.
    estimates use "ML3b.ster"

    display _newline "--- Efecto por desviación dentro del municipio ---"
    display "Cada lincom devuelve el cambio en puntos de examen asociado a una"
    display "desviación estándar temporal de la variable, con su intervalo."

    display _newline "Homicidios:"
    lincom sd_w_hom * tasa_homicidios_dev
    scalar b_hom = r(estimate)
    scalar se_hom = r(se)

    display _newline "Coca:"
    lincom sd_w_coca * ln_coca_dev
    scalar b_coca = r(estimate)
    scalar se_coca = r(se)

    display _newline "Asignación del SGP:"
    lincom sd_w_inv * ln_inversion_pc_dev
    scalar b_inv = r(estimate)
    scalar se_inv = r(se)

    * ----------------------------------------------------------------------
    * [1.1] Efecto mínimo detectable
    * ----------------------------------------------------------------------
    * El EMD es la magnitud más pequeña que el diseño habría detectado con 80%
    * de potencia al 5% de significancia: (1,96 + 0,84) por el error estándar.
    * Si el EMD es pequeño frente a la escala del examen, el resultado nulo NO
    * puede atribuirse a falta de potencia, que es exactamente lo que hay que
    * demostrar.
    display _newline "--- Efecto mínimo detectable (80% de potencia, 5%) ---"
    display "Variable          EMD (puntos por DE dentro)"
    display "Homicidios        " %8.3f 2.802*se_hom
    display "Coca              " %8.3f 2.802*se_coca
    display "Asignación SGP    " %8.3f 2.802*se_inv

    display _newline "Desviación estándar del puntaje global: 45,98 puntos."
    display "Un EMD de un punto equivale a 0,023 desviaciones del puntaje."
    display "El nulo se enuncia como cota: los datos no respaldan, en esta"
    display "muestra, un efecto mayor que ese umbral. No autorizan a afirmar"
    display "que el efecto sea cero."
}


********************************************************************************
* [2] REESTIMACIÓN POR MÁXIMA VEROSIMILITUD RESTRINGIDA
********************************************************************************
* Con 42 grupos de Nivel 3, la máxima verosimilitud ordinaria subestima el
* componente de varianza municipal. REML corrige el sesgo por los grados de
* libertad consumidos al estimar los efectos fijos.
*
* NOTA DE C1: este bloque conserva a propósito la estructura aleatoria de dos
* componentes. Su función es separar qué parte del desplazamiento de los
* coeficientes proviene del método de estimación y qué parte de la estructura,
* y para eso debe cambiar una sola cosa a la vez. El resultado quedó en el
* Anexo F.2: REML no explica ninguno de los desplazamientos.

if `hacer_reml' == 1 {

    display _newline "{hline 78}"
    display "[2] REESTIMACIÓN POR REML"
    display "{hline 78}"

    * --- Modelo nulo (rápido: no usa imputación) ---
    use "Base_Multinivel_PCA.dta", clear
    capture drop sede_id mcpio_id
    egen long sede_id  = group(cole_cod_dane_sede)
    egen long mcpio_id = group(cole_cod_mcpio_ubicacion)

    display _newline "--- Modelo nulo por REML ---"
    mixed punt_global || mcpio_id: || sede_id: , reml
    estimates save "M0_pool_reml.ster", replace
    estat icc

    display _newline "Comparar con la partición por máxima verosimilitud"
    display "reportada en la Tabla 7: municipio 11,8% y sede 15,8%."
    display "La partición vigente de cinco componentes está en la Tabla 7b."

    * --- ML3 por REML ---
    use "Base_Estimacion.dta", clear
    display _newline "--- ML3 por REML (varias horas) ---"
    mi estimate, dots post: mixed punt_global c_inse $v_n1 $v_n2 ///
        tasa_homicidios_bar tasa_homicidios_dev ///
        ln_coca_bar ln_coca_dev ///
        ln_inversion_pc_bar ln_inversion_pc_dev ///
        ib2018.year || mcpio_id: || sede_id: , reml
    estimates save "ML3_reml.ster", replace
}


********************************************************************************
* [3] ERRORES ESTÁNDAR ROBUSTOS POR CLÚSTER
********************************************************************************
* Los errores de máxima verosimilitud suponen correctamente especificada la
* estructura de covarianza. La varianza residual crece de 1.237 a 1.395 puntos
* entre 2018 y 2023, lo que es heterocedasticidad entre cohortes. El estimador
* sándwich no exige esa especificación correcta.
*
* NOTA: con `vce(robust)` en un modelo de tres niveles, Stata agrupa por la
* unidad de nivel más alto, es decir el municipio. Con 42 clústeres el
* estimador robusto es él mismo poco preciso, así que se reporta como
* verificación y no como especificación principal. Conviene declararlo.
*
* NOTA DE C1: igual que el bloque [2], conserva la estructura antigua a
* propósito. El error estándar que produce para ln_inversion_pc_dev, 1,617,
* coincide con el de ML3b hasta la cuarta cifra. Esa coincidencia es coherente
* con la especificación adoptada; no es una prueba de ella.

if `hacer_robust' == 1 {

    display _newline "{hline 78}"
    display "[3] ERRORES ESTÁNDAR ROBUSTOS"
    display "{hline 78}"

    use "Base_Estimacion.dta", clear

    display _newline "--- ML1 con errores robustos ---"
    mi estimate, dots post: mixed punt_global c_inse $v_n1 $v_n2 ///
        indice_vuln ib2018.year || mcpio_id: || sede_id: , mle vce(robust)
    estimates save "ML1_robust.ster", replace

    display _newline "--- ML3 con errores robustos ---"
    mi estimate, dots post: mixed punt_global c_inse $v_n1 $v_n2 ///
        tasa_homicidios_bar tasa_homicidios_dev ///
        ln_coca_bar ln_coca_dev ///
        ln_inversion_pc_bar ln_inversion_pc_dev ///
        ib2018.year || mcpio_id: || sede_id: , mle vce(robust)
    estimates save "ML3_robust.ster", replace

    display _newline "Comparar los errores estándar de ln_inversion_pc_dev,"
    display "tasa_homicidios_dev y ln_coca_dev con los de ML3b (Tabla 13)."
}


********************************************************************************
* [4] HIPÓTESIS DE SELECCIÓN DE SOBREVIVIENTES
********************************************************************************
* El capítulo 4 sostiene que el resultado nulo de la violencia puede deberse a
* que el conflicto saca a los estudiantes del sistema antes del grado once, de
* modo que sus efectos quedan fuera de una muestra construida sobre quienes sí
* presentaron el examen. Esa afirmación se puede poner a prueba.
*
* Si la hipótesis es cierta, los municipios donde más creció la violencia
* deberían mostrar una caída relativa en el número de estudiantes presentados.
* La prueba no es concluyente —el número de evaluados también depende de la
* demografía y de la cobertura— pero es mucho más que una conjetura.

if `hacer_desercion' == 1 {

    display _newline "{hline 78}"
    display "[4] PRUEBA DE LA HIPÓTESIS DE SELECCIÓN"
    display "{hline 78}"

    use "Base_Multinivel_PCA.dta", clear

    collapse (count) evaluados = punt_global ///
             (mean)  tasa_homicidios ln_coca indice_vuln, ///
             by(cole_cod_mcpio_ubicacion year)

    xtset cole_cod_mcpio_ubicacion year

    * Escala logarítmica: interesa el cambio proporcional, no el absoluto.
    generate double ln_eval = ln(evaluados)
    label variable ln_eval "Log de estudiantes presentados en el municipio"

    display _newline "--- Evaluados por municipio-año ---"
    xtsum evaluados ln_eval tasa_homicidios

    * --- (a) Correlación de los cambios entre 2018 y 2023 ---
    preserve
        keep cole_cod_mcpio_ubicacion year ln_eval tasa_homicidios
        quietly reshape wide ln_eval tasa_homicidios, ///
            i(cole_cod_mcpio_ubicacion) j(year)

        generate double d_eval = ln_eval2023 - ln_eval2018
        generate double d_hom  = tasa_homicidios2023 - tasa_homicidios2018
        label variable d_eval "Cambio del log de evaluados, 2018 a 2023"
        label variable d_hom  "Cambio de la tasa de homicidios, 2018 a 2023"

        display _newline "--- Cambio en evaluados frente a cambio en homicidios ---"
        display "Si la selección por violencia operara, se esperaría una"
        display "correlación NEGATIVA: donde más creció la violencia, menos"
        display "estudiantes llegaron a presentar la prueba."
        correlate d_eval d_hom
        regress d_eval d_hom

        display _newline "--- Municipios con mayor caída relativa de evaluados ---"
        gsort d_eval
        list cole_cod_mcpio_ubicacion d_eval d_hom in 1/10, clean noobs
    restore

    * --- (b) Especificación de panel con efectos fijos ---
    * Más exigente que la anterior: usa los seis años y compara a cada
    * municipio consigo mismo, con efectos fijos de año.
    display _newline "--- Panel de evaluados con efectos fijos de municipio y año ---"
    xtreg ln_eval tasa_homicidios i.year, fe cluster(cole_cod_mcpio_ubicacion)

    display _newline "Un coeficiente negativo y significativo respaldaría la"
    display "hipótesis de selección. Uno nulo indica que la violencia no se"
    display "asocia con el tamaño de la cohorte evaluada, lo que DEBILITA esa"
    display "explicación del resultado nulo y hay que declararlo así."
}


********************************************************************************
* [5] LOS DOS ATÍPICOS DEL FUT FRENTE A LA VULNERABILIDAD
********************************************************************************
* El capítulo trata las dos observaciones anómalas de inversión ejecutada como
* errores de reporte. Cabe una lectura alternativa: que sean municipios en
* crisis administrativa real, y que esa crisis coincida con alta vulnerabilidad.
* Si así fuera, excluirlos no sería depurar sino recortar justamente el
* segmento donde la asociación importaría más.

if `hacer_atipicos' == 1 {

    display _newline "{hline 78}"
    display "[5] PERFIL DE LOS MUNICIPIO-AÑO ATÍPICOS DEL FUT"
    display "{hline 78}"

    use "N3_Municipios_PCA.dta", clear

    capture confirm variable ln_inv_fut_pc
    if _rc != 0 {
        display "ln_inv_fut_pc no está en N3_Municipios_PCA.dta."
        display "Correr el 04 v4 antes de este bloque."
    }
    else {
        generate byte atipico_fut = (ln_inv_fut_pc < 12) if !missing(ln_inv_fut_pc)

        display _newline "--- Perfil de los atípicos ---"
        list cole_cod_mcpio_ubicacion year ln_inv_fut_pc ///
             tasa_homicidios ln_coca indice_vuln vuln_bar ///
             if atipico_fut == 1, clean noobs

        display _newline "--- Comparación con el resto de la muestra ---"
        tabstat tasa_homicidios ln_coca indice_vuln vuln_bar, ///
            by(atipico_fut) stat(n mean sd) format(%9.4f)

        display _newline "--- Posición de esos municipios en el ranking ---"
        preserve
            egen byte _t = tag(cole_cod_mcpio_ubicacion)
            keep if _t == 1
            gsort -vuln_bar
            generate int rango_vuln = _n
            list rango_vuln cole_cod_mcpio_ubicacion vuln_bar in 1/12, clean noobs
        restore

        display _newline "Si los atípicos están entre los municipios más"
        display "vulnerables, hay que declararlo: la exclusión de R5b no es"
        display "neutral y el capítulo debe decirlo en lugar de presentar la"
        display "depuración como puramente técnica."
    }
}


********************************************************************************
* [6] RETIRADO EN C2 - PRUEBA DE EQUIVALENCIA PARA EL CONTRASTE DE CENTRADO
********************************************************************************
* RETIRADO EN C2 (13 de octubre de 2026). NO REACTIVAR.
*
* Por qué se retira, en tres puntos:
*
*   1. Cargaba M3_cwc.ster, que ningún script de la cadena genera. El 08 v5
*      produce M3cwc_2018 ... M3cwc_2023, M4_cwc y M5_cwc. El archivo existía en
*      disco como residuo de la versión 4 y por eso el `estimates use` no falló
*      el 23 de agosto, pero el resultado no es reproducible.
*
*   2. El lincom calculaba cwc_inse - c_inse_prom_sede, es decir beta_w -
*      beta_b, que es el NEGATIVO del efecto contextual. El Anexo F.6 leyó ese
*      intervalo como si acotara el efecto composicional por arriba, cuando lo
*      acotaba por el extremo contrario.
*
*   3. La pregunta de fondo quedó resuelta mejor en 12_composicional.do. El
*      bloque [2] de ese script descompone la media de la sede en componente
*      permanente y desviación de cohorte: el primero es 1,946 (0,248) y el
*      segundo 0,010 (0,106), con un efecto mínimo detectable de 0,296 por
*      unidad. Eso es una cota con potencia declarada, que es justamente lo que
*      el TOST pretendía dar y no daba.
*
* La Tabla 33 del Anexo F.6 se retira del informe y se sustituye por la Tabla
* 11b. El código se conserva comentado como registro de lo que se hizo.
*
*   if `hacer_tost' == 1 {
*       estimates use "M3cwc_pool.ster"
*       local margen = 0.10
*       lincom c_inse_prom_sede - cwc_inse
*       scalar dif   = r(estimate)
*       scalar sedif = r(se)
*       scalar t_inf = (dif - (-`margen')) / sedif
*       scalar t_sup = (dif - `margen') / sedif
*       scalar p_tost = max(1 - normal(t_inf), normal(t_sup))
*       display "p del TOST: " %8.4f p_tost
*   }
*
* Si alguna vez se reactivara, dos condiciones: cargar M3cwc_pool.ster, que sí
* genera el 12, y plantear el lincom como c_inse_prom_sede - cwc_inse para que
* el margen se declare sobre beta_c y no sobre su negativo.
********************************************************************************


********************************************************************************
* [7] RETIRADO - HIPÓTESIS RIVAL SOBRE LOS DOCENTES DE PLANTA
********************************************************************************
* RETIRADO. Este bloque terminaba en r(451), "repeated time values within
* panel", por `xtset sede_id year` sobre Base_Multinivel_PCA.dta, que está a
* nivel de ESTUDIANTE: una misma sede tiene decenas de filas en el mismo año.
*
* Corregido en 10b_planta_fe_v2.do, que hace `xtset sede_id` sin variable de
* tiempo. Sus resultados son los de la Tabla 34 del Anexo F.7: el coeficiente
* de pct_planta pasa de 12,179 (2,543) con efectos aleatorios a 0,895 (2,175)
* con efectos fijos de sede, de modo que la asociación se identifica
* predominantemente entre sedes y no dentro de ellas.
*
* La parte diagnóstica del bloque (correlaciones de pct_planta con ruralidad y
* tamaño, y xtsum sobre N2_Sedes_2018_2023.dta) sí corrió sin error el 23 de
* agosto y su salida está en log_10_blindaje.log. No hace falta repetirla.
********************************************************************************


********************************************************************************
* CIERRE
********************************************************************************

display _newline "{hline 78}"
display "BLINDAJE COMPLETADO."
display "Bloques vigentes: [1] a [5]."
display "[6] retirado en C2, sustituido por 12_composicional.do."
display "[7] retirado, corregido en 10b_planta_fe_v2.do."
display "{hline 78}"

log close fase10

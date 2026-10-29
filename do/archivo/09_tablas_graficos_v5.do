********************************************************************************
* PROYECTO : Desempeño Saber 11 en sedes oficiales del Cauca, 2018-2023
* SCRIPT   : 09 - TABLAS Y GRÁFICOS
* ENTRADA  : archivos .ster del script 08, ICC_por_year.dta, Base_Estimacion.dta
* SALIDA   : archivos .rtf para Word y gráficos .png
* STATA    : 17
* VERSIÓN  : 5 - el Objetivo 3 se reporta AÑO POR AÑO; el modelo contextual
*                M3ctx es la especificación de referencia
*
* CORRECCIÓN DEL 19-08-2026 (misma versión 3, no reestima nada)
* [7] La tabla de robustez no incluía R5 (inversión ejecutada del FUT) ni
* R6 (recaudo tributario), añadidas en el 08 v3. Ya se agregaron.
* [2] La columna de M5 mostraba dos filas fantasma (`pct_planta` y `c_inse`
* repetidos con coeficiente 0 y ee "(.)"), artefacto de que M5 especifica
* `c.c_inse##c.pct_planta` y `c.c_inse##c.indice_vuln` a la vez que
* `pct_planta` sigue en $v_n2. Se agregó `noomitted` a los esttab de [2] y
* [7] para suprimir esas filas sin tocar los coeficientes reales.
********************************************************************************
* ESTE SCRIPT NO ESTIMA NADA
* Lee los modelos guardados por el 08 y arma las tablas. Cambiar el formato de
* una tabla no obliga a repetir horas de estimación. La única excepción es el
* gráfico de efectos aleatorios, que necesita predecirlos sobre una imputación.
*
* CORRECCIÓN DE LA VERSIÓN 1
* El filtro `drop(*:lns*)` fallaba porque `mixed` guarda los parámetros
* aleatorios como ECUACIONES propias (lns1_1_1, lns2_1_1, lnsig_e, atr1_1_1_2)
* y no como coeficientes dentro de la ecuación principal. Se reemplaza por
* `keep(punt_global:*)`, que conserva los efectos fijos sin importar cuántos
* parámetros aleatorios tenga cada modelo.
*
* REQUISITOS
* Los comandos `esttab` y `estout` no vienen con Stata:
*     ssc install estout, replace
*
* POR QUÉ RTF Y NO COPIAR A MANO
* Exportar a RTF permite abrir la tabla directamente en Word con los números ya
* puestos. Transcribir coeficientes a mano es la fuente más común de
* discrepancias entre lo que dice el texto y lo que dice la tabla.
********************************************************************************

clear all
set more off
set varabbrev off
version 17

if "$TESIS_CONFIG" == "" do "C:\Users\RYZEN 5\Desktop\Tesis Multinivel\Definitivo\00_config.do"
cd "$RAIZ"

capture log close _all
local tarea "09_tablas"
local hoy   "20261024"          // <<< etiqueta de la proxima corrida

capture confirm file "log_`tarea'_`hoy'.log"
if _rc == 0 {
    display as error "Ya existe log_`tarea'_`hoy'.log."
    display as error "Cambiar el local hoy (por ejemplo, anadir un sufijo b, c...)."
    exit 602
}
log using "log_`tarea'_`hoy'.log", text name(fase9)

capture which esttab
if _rc != 0 {
    display as error "Falta el paquete estout. Ejecute: ssc install estout, replace"
    exit 111
}

* Esquema gráfico único para las cuatro figuras. Un documento con figuras de
* estilos distintos se lee como un collage.
set scheme s1mono


********************************************************************************
* [1] TABLA Y GRÁFICOS DE LA PARTICIÓN DE LA VARIANZA (OBJETIVO 2)
********************************************************************************

display _newline "{hline 78}"
display "[1] OBJETIVO 2"
display "{hline 78}"

use "ICC_por_year.dta", clear

foreach v in icc_mcpio icc_sede icc_est {
    generate double p_`v' = 100 * `v'
}

format p_* %6.2f
format v_* %9.1f

display _newline "--- Partición de la varianza por año (porcentajes) ---"
list year p_icc_mcpio p_icc_sede p_icc_est, clean noobs

display _newline "--- Componentes de varianza en unidades de puntaje ---"
list year v_mcpio v_sede v_est, clean noobs

export delimited using "Tabla_Obj2_ICC.csv", replace

* --- Figura 1: composición de la varianza ---
generate double acum1 = p_icc_mcpio
generate double acum2 = p_icc_mcpio + p_icc_sede
generate double acum3 = 100

twoway (area acum3 year, color(gs14))                                        ///
       (area acum2 year, color(gs10))                                        ///
       (area acum1 year, color(gs5)),                                        ///
    legend(order(3 "Municipio" 2 "Sede" 1 "Estudiante") rows(1) position(6)) ///
    ytitle("Porcentaje de la varianza total") xtitle("Año de la cohorte")    ///
    ylabel(0(20)100, angle(horizontal)) xlabel(2018(1)2023)                  ///
    title("") name(g_icc_area, replace)
graph export "Fig_Obj2_particion.png", replace width(2000)

* --- Figura 2: las dos cuotas que se mueven ---
* La cuota del municipio es casi plana; el intercambio ocurre entre sede y
* estudiante, así que conviene un gráfico que lo aísle.
twoway (connected p_icc_sede year, msymbol(O) lpattern(solid))               ///
       (connected p_icc_mcpio year, msymbol(S) lpattern(dash)),              ///
    legend(order(1 "Sede" 2 "Municipio") rows(1) position(6))                ///
    ytitle("Porcentaje de la varianza total") xtitle("Año de la cohorte")    ///
    ylabel(8(2)22, angle(horizontal)) xlabel(2018(1)2023)                    ///
    title("") name(g_icc_lineas, replace)
graph export "Fig_Obj2_evolucion.png", replace width(2000)


********************************************************************************
* [2] TABLAS DE LA PROGRESIÓN TRANSVERSAL ANUAL (OBJETIVO 3)
********************************************************************************
* Se producen tres tablas de distinta extensión, pensadas para lugares
* distintos del documento:
*
*   Tabla_Obj3_anual_resumen.rtf
*       Los coeficientes que el capítulo discute, con una columna por cohorte,
*       tomados del modelo contextual M3ctx. Es la tabla del CUERPO: responde
*       de un vistazo si las magnitudes se movieron durante el periodo.
*
*   Tabla_Obj3_anual_<año>.rtf   (seis archivos)
*       La progresión completa M1a -> M3ctx de cada cohorte. Son las tablas
*       del ANEXO.
*
*   Tabla_Obj3_cwc_anual.rtf
*       Los dos coeficientes del centrado al clúster por cohorte. También del
*       ANEXO, porque su función es descartar la falacia ecológica y no
*       constituir un hallazgo en sí.

display _newline "{hline 78}"
display "[2] OBJETIVO 3 - PROGRESIÓN ANUAL"
display "{hline 78}"

* ----------------------------------------------------------------------
* [2.1] Tabla compacta del modelo contextual, una columna por cohorte
* ----------------------------------------------------------------------
* Se usa M3ctx y no M3 porque es la especificación de referencia: al incluir
* el INSE medio de la sede, el coeficiente individual deja de ser una mezcla
* del efecto dentro y entre sedes.

capture estimates clear
local cols_res ""
foreach a in 2018 2019 2020 2021 2022 2023 {
    capture estimates use "M3ctx_`a'.ster"
    if _rc == 0 {
        estimates store R`a'
        local cols_res "`cols_res' R`a'"
    }
    else {
        display as error "No se encontró M3ctx_`a'.ster"
    }
}

if "`cols_res'" != "" {
    esttab `cols_res' using "Tabla_Obj3_anual_resumen.rtf", replace          ///
        b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) noomitted                   ///
        keep(c_inse c_inse_prom_sede pct_planta rural ln_matricula           ///
             ratio_alumnos_docente z_posgrado dotacion_tic ju_unica          ///
             indice_vuln)                                                    ///
        mtitles("2018" "2019" "2020" "2021" "2022" "2023")                   ///
        title("Modelo contextual estimado por separado en cada cohorte")     ///
        addnotes("Cada columna es un modelo multinivel de tres niveles estimado solo con la cohorte de ese año." ///
                 "c_inse mide el efecto dentro de la sede y c_inse_prom_sede el efecto contextual del establecimiento." ///
                 "Todos incluyen el bloque individual e institucional completo; se muestran los coeficientes discutidos en el texto." ///
                 "El coeficiente de sedes exclusivamente femeninas se omite por descansar en unas cinco sedes por año.") ///
        nogaps compress

    esttab `cols_res', b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) noomitted    ///
        keep(c_inse c_inse_prom_sede pct_planta rural ln_matricula indice_vuln) ///
        mtitles("2018" "2019" "2020" "2021" "2022" "2023") nogaps compress
}

* ----------------------------------------------------------------------
* [2.2] Tablas extensas: la progresión completa de cada cohorte
* ----------------------------------------------------------------------
foreach a in 2018 2019 2020 2021 2022 2023 {

    capture estimates clear
    local cols ""
    foreach m in M1a M1 M2 M3 M3ctx {
        capture estimates use "`m'_`a'.ster"
        if _rc == 0 {
            estimates store P`m'
            local cols "`cols' P`m'"
        }
    }

    if "`cols'" != "" {
        esttab `cols' using "Tabla_Obj3_anual_`a'.rtf", replace              ///
            b(3) se(3) star(* 0.10 ** 0.05 *** 0.01)                         ///
            keep(punt_global:*) noomitted                                    ///
            mtitles("M1a" "M1" "M2" "M3" "M3ctx")                            ///
            title("Progresión de modelos, cohorte `a'")                      ///
            addnotes("M1a estima el gradiente socioeconómico total; M1 el gradiente neto de la dotación del hogar." ///
                     "M3ctx añade el INSE medio de la sede, con lo que el coeficiente individual pasa a medir el efecto dentro de la sede." ///
                     "Estimación por máxima verosimilitud sobre 20 imputaciones múltiples.") ///
            nogaps compress
        display "Generada: Tabla_Obj3_anual_`a'.rtf"
    }
}

* ----------------------------------------------------------------------
* [2.3] Figura: evolución del gradiente socioeconómico
* ----------------------------------------------------------------------
* Una figura comunica la estabilidad o la tendencia mejor que una fila de
* números, que es justamente la pregunta que motiva estimar año por año.

preserve
    use "Coef_por_year.dta", clear
    keep if inlist(modelo, "M1a", "M3ctx")

    generate double lo = b_ind - 1.96*se_ind
    generate double hi = b_ind + 1.96*se_ind

    generate byte mod = 1 if modelo == "M1a"
    replace     mod = 2 if modelo == "M3ctx"

    display _newline "--- Datos de la figura de evolución ---"
    list year modelo b_ind lo hi, clean noobs

    twoway (rarea lo hi year if mod == 1, color(gs13))                       ///
           (connected b_ind year if mod == 1, msymbol(O) lcolor(black)       ///
                mcolor(black))                                               ///
           (rarea lo hi year if mod == 2, color(gs15))                       ///
           (connected b_ind year if mod == 2, msymbol(S) lpattern(dash)      ///
                lcolor(black) mcolor(black)),                                ///
        legend(order(2 "Gradiente total (M1a)"                               ///
                     4 "Efecto dentro de la sede (M3ctx)")                   ///
               rows(1) position(6) size(small))                              ///
        ytitle("Puntos por unidad del índice socioeconómico")                ///
        xtitle("Año de la cohorte")                                          ///
        xlabel(2018(1)2023) yline(0, lpattern(dot) lcolor(gs8))              ///
        name(g_grad_anual, replace)

    graph export "Fig_Obj3_evolucion_coef.png", replace width(2000)
    display "Generada: Fig_Obj3_evolucion_coef.png"
restore


********************************************************************************
* [3] VARIANZA EXPLICADA POR BLOQUE, COHORTE POR COHORTE
********************************************************************************
* La comparación correcta es contra el modelo nulo DEL MISMO AÑO: usar el nulo
* agrupado mezclaría la varianza de seis cohortes distintas.

display _newline "{hline 78}"
display "[3] VARIANZA EXPLICADA POR BLOQUE Y POR COHORTE"
display "{hline 78}"

display _newline "Año   Modelo   Municipio     Sede    Residuo   R2mcpio  R2sede"

foreach a in 2018 2019 2020 2021 2022 2023 {

    capture estimates use "M0_`a'.ster"
    if _rc != 0 {
        display as error "Falta M0_`a'.ster"
        continue
    }
    scalar vm0 = exp(2*_b[lns1_1_1:_cons])
    scalar vs0 = exp(2*_b[lns2_1_1:_cons])
    scalar vr0 = exp(2*_b[lnsig_e:_cons])
    display "`a'  Nulo   " %9.2f vm0 " " %9.2f vs0 " " %9.2f vr0

    foreach m in M1a M1 M2 M3 M3ctx {
        capture estimates use "`m'_`a'.ster"
        if _rc == 0 {
            scalar vm = exp(2*_b[lns1_1_1:_cons])
            scalar vs = exp(2*_b[lns2_1_1:_cons])
            scalar vr = exp(2*_b[lnsig_e:_cons])
            display "`a'  `m'  " %9.2f vm " " %9.2f vs " " %9.2f vr ///
                    "   " %6.3f (vm0-vm)/vm0 "  " %6.3f (vs0-vs)/vs0
        }
    }
}

display _newline "La reducción proporcional respecto del modelo nulo es la"
display "medida habitual de varianza explicada en modelos multinivel. Un valor"
display "negativo es posible y no indica error: ocurre cuando una covariable de"
display "un nivel redistribuye varianza entre niveles."


********************************************************************************
* [3B] EL GRADIENTE SOCIOECONÓMICO, COHORTE POR COHORTE
********************************************************************************
* El ICFES construye el índice socioeconómico a partir de ítems que incluyen la
* tenencia de computador e internet. Incluir esas variables junto al índice le
* pide a este que explique lo que queda tras descontar parte de su propio
* contenido, de modo que el coeficiente resultante es un efecto PARCIAL.
*
* M1a estima el gradiente TOTAL. La diferencia entre ambos es la fracción de la
* asociación socioeconómica que opera a través de la dotación material del
* hogar. Los dos se reportan porque responden a preguntas distintas.

display _newline "{hline 78}"
display "[3B] GRADIENTE SOCIOECONÓMICO POR COHORTE"
display "{hline 78}"

use "Base_Estimacion.dta", clear

display _newline "Año   SD INSE   SD puntaje   Total   Ptos/SD   En SD   Dentro sede   Absorbido"

foreach a in 2018 2019 2020 2021 2022 2023 {

    quietly summarize estu_inse_individual if _mi_m == 1 & year == `a'
    scalar sd_inse = r(sd)
    quietly summarize punt_global if _mi_m == 1 & year == `a'
    scalar sd_punt = r(sd)

    scalar b_total = .
    scalar b_dentro = .

    capture estimates use "M1a_`a'.ster"
    if _rc == 0 scalar b_total = _b[c_inse]

    capture estimates use "M3ctx_`a'.ster"
    if _rc == 0 scalar b_dentro = _b[c_inse]

    if !missing(b_total) & !missing(b_dentro) {
        display "`a'  " %7.3f sd_inse "  " %8.3f sd_punt "  " ///
                %7.4f b_total "  " %7.3f b_total*sd_inse "  " ///
                %6.4f b_total*sd_inse/sd_punt "  " %9.4f b_dentro "  " ///
                %6.1f 100*(1 - b_dentro/b_total) "%"
    }
}

display _newline "La última columna es la fracción del gradiente total que"
display "absorben las variables del hogar y la composición de la sede."


********************************************************************************
* [4] EFECTO CONTEXTUAL: LAS DOS PARAMETRIZACIONES
********************************************************************************
* M3ctx y M3cwc contienen la misma información escrita de dos formas. Bajo
* centrado al clúster los dos coeficientes son ortogonales y se leen directo:
* uno es el efecto dentro de la sede y el otro el efecto entre sedes. Bajo
* centrado en la gran media, el coeficiente de la media de sede mide
* directamente el efecto CONTEXTUAL, es decir la diferencia entre ambos.
*
* El contraste de igualdad es lo que decide si existe un efecto composicional
* distinguible del individual. Estimarlo por cohorte permite ver si esa
* conclusión se sostiene en todas o si el promedio del periodo oculta
* comportamientos distintos.

display _newline "{hline 78}"
display "[4] EFECTO CONTEXTUAL POR COHORTE"
display "{hline 78}"

capture estimates clear
local cols_cwc ""
foreach a in 2018 2019 2020 2021 2022 2023 {
    capture estimates use "M3cwc_`a'.ster"
    if _rc == 0 {
        estimates store C`a'
        local cols_cwc "`cols_cwc' C`a'"
    }
}

if "`cols_cwc'" != "" {
    esttab `cols_cwc' using "Tabla_Obj3_cwc_anual.rtf", replace              ///
        b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) noomitted                   ///
        keep(cwc_inse c_inse_prom_sede)                                      ///
        mtitles("2018" "2019" "2020" "2021" "2022" "2023")                   ///
        title("Especificación con centrado al clúster, por cohorte")         ///
        addnotes("cwc_inse mide la ventaja del estudiante frente a sus propios compañeros de sede." ///
                 "c_inse_prom_sede mide el efecto de estudiar en una sede de mayor nivel socioeconómico." ///
                 "Ambos modelos incluyen el bloque individual, el institucional y el índice de vulnerabilidad.") ///
        nogaps compress
}

display _newline "--- Contraste dentro frente a entre sedes, por cohorte ---"
display "Año    Dentro    Entre    Diferencia   Error est.        p"

foreach a in 2018 2019 2020 2021 2022 2023 {
    capture estimates use "M3cwc_`a'.ster"
    if _rc == 0 {
        scalar b_w = _b[cwc_inse]
        scalar b_b = _b[c_inse_prom_sede]
        quietly lincom cwc_inse - c_inse_prom_sede
        display "`a'  " %8.4f b_w "  " %8.4f b_b "  " %10.4f r(estimate) ///
                "  " %10.4f r(se) "  " ///
                %8.4f 2*(1-normal(abs(r(estimate)/r(se))))
    }
}

display _newline "Si el contraste no se rechaza en ninguna cohorte, la"
display "conclusión se sostiene en todo el periodo y no es un promedio que"
display "oculte comportamientos distintos entre años."

********************************************************************************
* [5] TABLA DEL OBJETIVO 4
********************************************************************************

display _newline "{hline 78}"
display "[5] OBJETIVO 4"
display "{hline 78}"

foreach m in ML1 ML2 ML3 ML4 {
    capture estimates use "`m'.ster"
    if _rc == 0 {
        estimates store `m'
    }
    else {
        display as error "No se encontró `m'.ster"
    }
}

esttab ML1 ML2 ML3 ML4 using "Tabla_Obj4_temporal.rtf", replace        ///
    b(3) se(3) star(* 0.10 ** 0.05 *** 0.01)                           ///
    keep(punt_global:*)                                                ///
    mtitles("ML1" "ML2" "ML3" "ML4")                                   ///
    title("Cortes transversales repetidos y entorno municipal rezagado") ///
    addnotes("ML2 descompone el índice en componente entre municipios y componente dentro del municipio." ///
             "ML3 aplica la misma descomposición a las tres dimensiones por separado." ///
             "Los datos municipales corresponden al año anterior al de la cohorte.") ///
    nogaps compress

esttab ML1 ML2 ML3 ML4, b(3) se(3) star(* 0.10 ** 0.05 *** 0.01)      ///
    keep(punt_global:*) mtitles("ML1" "ML2" "ML3" "ML4") nogaps compress

* ----------------------------------------------------------------------
* [5.1] Pendiente de la vulnerabilidad en cada año
* ----------------------------------------------------------------------
* Los coeficientes de la interacción no se leen directamente: cada uno es la
* diferencia respecto de 2018. La pendiente de un año es la suma del efecto
* principal más su interacción, y eso es lo que se reporta.

capture estimates use "ML4.ster"
if _rc == 0 {
    display _newline "--- Asociación entre vulnerabilidad y puntaje, por año ---"

    display _newline "2018 (categoría de referencia):"
    lincom vuln_dev

    foreach a in 2019 2020 2021 2022 2023 {
        display _newline "`a':"
        lincom vuln_dev + `a'.year#c.vuln_dev
    }
}


********************************************************************************
* [6] EFECTOS ALEATORIOS DE SEDE
********************************************************************************
* Este bloque sí estima: predecir efectos aleatorios exige un ajuste individual,
* porque no están definidos sobre el conjunto combinado de imputaciones. Se usa
* la primera imputación y así debe declararse en el pie de la figura.

display _newline "{hline 78}"
display "[6] EFECTOS ALEATORIOS DE SEDE"
display "{hline 78}"

use "Base_Estimacion.dta", clear
mi extract 1, clear

display _newline "Reestimando M4 sobre la primera imputación para predecir los"
display "efectos aleatorios. Esto tarda unos minutos."

global v_n1 mujer edad repitente lectura_30min libros_26omas ///
            trabaja_mas20 internet_hogar computador_hogar
global v_n2 ln_matricula ratio_alumnos_docente pct_planta z_posgrado ///
            dotacion_tic rural ju_unica tecnico tecnico_academico ///
            cole_femenino

quietly mixed punt_global cwc_inse c_inse_prom_sede $v_n1 $v_n2 indice_vuln ///
    || mcpio_id: || sede_id: cwc_inse , mle covariance(unstructured)

predict double re_*, reffects
predict double se_*, reses

display _newline "--- Efectos aleatorios generados ---"
describe re_* se_*
display "El orden es: municipio, luego pendiente y constante de la sede."

* --- Figura 3: efectos aleatorios de sede ordenados ---
* Muestra qué sedes rinden por encima o por debajo de lo que predicen sus
* características observables.
preserve
    egen byte _t = tag(sede_id)
    keep if _t == 1

    * El nombre de la constante de sede depende de cuántos niveles y pendientes
    * tenga el modelo. Se toma la última variable generada, que corresponde a
    * la constante del nivel más interno.
    unab lista_re : re_*
    local n_re : word count `lista_re'
    local vre : word `n_re' of `lista_re'
    unab lista_se : se_*
    local vse : word `n_re' of `lista_se'
    display "Usando `vre' como constante de sede."

    generate double lo = `vre' - 1.96*`vse'
    generate double hi = `vre' + 1.96*`vse'
    sort `vre'
    generate long rango = _n

    twoway (rarea lo hi rango, color(gs13))                                  ///
           (line `vre' rango, lcolor(black)),                                ///
        yline(0, lpattern(dash) lcolor(gs8))                                 ///
        legend(off)                                                          ///
        ytitle("Efecto aleatorio de la sede (puntos)")                       ///
        xtitle("Sedes ordenadas por su efecto estimado")                     ///
        name(g_caterpillar, replace)
    graph export "Fig_Obj3_efectos_sede.png", replace width(2000)

    display _newline "--- Sedes con mayor efecto positivo ---"
    gsort -`vre'
    list sede_id `vre' in 1/5, clean noobs
    display _newline "--- Sedes con mayor efecto negativo ---"
    sort `vre'
    list sede_id `vre' in 1/5, clean noobs
restore

* --- Figura 4: gradiente socioeconómico por sede ---
* La correlación positiva entre pendiente e intercepto significa que las sedes
* con mejor desempeño medio tienen gradientes más pronunciados. El gráfico lo
* muestra de forma directa.
preserve
    egen byte _t = tag(sede_id)
    keep if _t == 1

    unab lista_re : re_*
    local n_re : word count `lista_re'
    local v_cons : word `n_re' of `lista_re'
    local pos_pend = `n_re' - 1
    local v_pend : word `pos_pend' of `lista_re'
    display "Constante de sede: `v_cons'   Pendiente de sede: `v_pend'"

    twoway (scatter `v_cons' `v_pend', msymbol(oh) mcolor(gs6))              ///
           (lfit `v_cons' `v_pend', lcolor(black)),                          ///
        legend(off)                                                          ///
        ytitle("Intercepto de la sede")                                      ///
        xtitle("Pendiente socioeconómica de la sede")                        ///
        name(g_gradiente, replace)
    graph export "Fig_Obj3_gradiente.png", replace width(2000)
restore


********************************************************************************
* [7] TABLA DE ROBUSTEZ
********************************************************************************

display _newline "{hline 78}"
display "[7] ROBUSTEZ"
display "{hline 78}"

* R5 y R6 (añadidos en el 08 v3) reemplazan la medida principal de inversión
* por la inversión ejecutada del FUT y por el recaudo tributario municipal,
* respectivamente. Antes de esta corrección la tabla de robustez no las
* incluía, aunque ya se guardaban en R5_inv_fut.ster y R6_ing_trib.ster.
foreach m in R1_indice_anual R3_parsimonioso R5_inv_fut R5b_inv_fut_dep R6_ing_trib {
    capture estimates use "`m'.ster"
    if _rc == 0 {
        estimates store `m'
    }
    else {
        display as error "No se encontró `m'.ster"
    }
}

capture estimates use "ML1.ster"
if _rc == 0 estimates store ML1b

esttab ML1b R1_indice_anual R3_parsimonioso R5_inv_fut R5b_inv_fut_dep R6_ing_trib using "Tabla_robustez.rtf", replace ///
    b(3) se(3) star(* 0.10 ** 0.05 *** 0.01)                            ///
    keep(punt_global:*) noomitted                                       ///
    mtitles("Principal" "Índice alternativo" "Parsimonioso" "FUT completo" "FUT depurado" "Recaudo tributario") ///
    title("Pruebas de robustez")                                        ///
    addnotes("El índice alternativo estandariza las tres dimensiones dentro de cada año; correlaciona 0,96 con el principal." ///
             "La especificación parsimoniosa se reporta como robustez, no como resultado principal." ///
             "R5 sustituye la inversión principal por la inversión ejecutada del FUT (ln_inv_fut_pc); R6 la sustituye por el recaudo tributario municipal (ln_ing_trib_pc)." ///
             "R5b repite R5 sobre la serie del FUT sin el municipio-año con error de reporte, por lo que su número de observaciones es menor." ///
             "Todas conservan la descomposición entre/dentro del municipio; el coeficiente relevante es el componente dentro (_dev).") ///
    nogaps compress

esttab ML1b R1_indice_anual R3_parsimonioso R5_inv_fut R5b_inv_fut_dep R6_ing_trib, b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
    keep(punt_global:*) noomitted ///
    mtitles("Principal" "Índ. anual" "Parsim." "FUT" "FUT dep." "Trib.") nogaps compress


********************************************************************************
* [8] CIERRE
********************************************************************************

display _newline "{hline 78}"
display "TABLAS Y GRÁFICOS GENERADOS"
display "  Tabla_Obj2_ICC.csv"
display "  Tabla_Obj3_progresion.rtf"
display "  Tabla_Obj3_centrados.rtf"
display "  Tabla_Obj4_temporal.rtf"
display "  Tabla_robustez.rtf"
display "  Fig_Obj2_particion.png"
display "  Fig_Obj2_evolucion.png"
display "  Fig_Obj3_efectos_sede.png"
display "  Fig_Obj3_gradiente.png"
display "{hline 78}"

log close fase9

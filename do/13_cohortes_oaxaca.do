********************************************************************************
* PROYECTO : Desempeno Saber 11 en sedes oficiales del Cauca, 2018-2023
* SCRIPT   : 13 - CONTRASTES ENTRE COHORTES Y OAXACA-BLINDER (C3)
* ENTRADA  : Base_Estimacion.dta
* SALIDA   : log_13_cohortes_<hoy>.log
*            MC_cohortes_<hoy>.ster
*            C3_oaxaca_<hoy>.dta, C3_holm_<hoy>.dta
* STATA    : 17
********************************************************************************
* QUE RESUELVE
* El Capitulo 4 afirma cuatro cambios entre cohortes leyendo la secuencia de un
* coeficiente a lo largo de las columnas de las Tablas 8 y 10: que la brecha
* rural "se consolido", que la planta docente "crece", y el vaiven de beta_w y
* de beta_b. Ninguno tiene contraste formal. Este script los contrasta en un
* modelo agrupado con interacciones variable x ano, y descompone la diferencia
* bruta de medias entre 2018 y 2023 en composicion y retornos.
*
* ESTRUCTURA ALEATORIA: LA DE C1, NO LA ANIDADA
* El borrador de C3.md usaba || mcpio_id: || mcpio_anio: || sede_anio:, que es
* la opcion 3 que C1 descarto: ahi el componente municipio-ano se estima en
* 9,72e-09, en la frontera [log_11_estructura.log, bloque 1(a)]. Ademas esa
* estructura NO tiene efecto permanente de sede, y rural tiene variacion dentro
* de la sede igual a cero: su error estandar quedaria calculado como si las 5,6
* cohortes de cada sede fueran independientes. Como T1 es justamente un
* contraste sobre rural, seria el error exacto que C1 corrigio.
* Mismo error de clase que el E1 de C5 y la incidencia 1 de C7.
*
* NUMERACION DE PARAMETROS EN LA ESTRUCTURA CRUZADA (verificada en C1)
*     municipio      lns1_1_1
*     municipio-ano  lns1_2_1     <- NO lns2_1_1
*     sede           lns2_1_1     <- NO lns3_1_1
*     sede-ano       lns3_1_1     <- NO lns4_1_1 (no existe)
* Por eso el bloque [1] imprime matrix list e(b) ANTES de extraer nada.
*
* TIEMPOS ESPERADOS
*   [0]  4-8 min    (dominado por los `use`; el [0] del 14 tardo 430,49 s)
*   [1]  45-80 min  (ML1b solo = 1.577,80 s; [1] del 12 = 1.762,26 s;
*                    ML3b_iica = 2.099,51 s; aqui se anaden ~20 parametros)
*   [2]  25-45 min  (cinco mi extract + diez corridas de oaxaca)
*   [3]  < 1 min
*   Total aproximado: 1 h 15 min a 2 h 15 min.
*
* COMO CORRERLO
* Primero SOLO el bloque [0]. Despues SOLO el [1], y DETENERSE a aplicar Holm
* antes de lanzar el [2]. Cada corrida cambia el local `hoy'.
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
* Mismo guard de 14_sensibilidad_diagnosticos.do. Si una corrida aborta, el
* sufijo de ese dia queda quemado: pasar a b, c, d, como hizo C7.
* ---------------------------------------------------------------------------
capture log close _all

* DOS ETIQUETAS DISTINTAS, como en 14_sensibilidad_diagnosticos.do:
*
*   `hoy'   etiqueta las SALIDAS de esta corrida: el log y los .ster. Cambia en
*           cada corrida, porque el log nunca se sobrescribe. Si se reanuda el
*           script el mismo dia, anadir un sufijo: 20261022b, c, ...
*
*   `fbase' etiqueta la base de trabajo que dejo el bloque [0] y que leen los
*           bloques [1] y [2]. NO cambia: apunta a un archivo que ya esta en
*           disco. Si se vuelve a correr el [0], lo reescribe con ese nombre.
*
* Esta separacion es obligatoria: sin ella, cambiar `hoy' para correr el bloque
* [2] por separado romperia el `use' de la base. Es el defecto de diseno que
* C5 destapo el 13 de octubre.
local hoy   "20261023b"
local fbase "20261022"

capture confirm file "log_13_cohortes_`hoy'.log"
if _rc == 0 {
    display as error "Ya existe log_13_cohortes_`hoy'.log."
    display as error "Cambiar el local hoy (anadir un sufijo) o renombrar el anterior."
    exit 602
}
log using "log_13_cohortes_`hoy'.log", text name(fase13)

timer clear
timer on 1

* ---------------------------------------------------------------------------
* INTERRUPTORES DE BLOQUE
* ---------------------------------------------------------------------------
* Estado tras las corridas del 22 de octubre:
*   log_13_cohortes_20261022.log   bloques [0] y [1]. [0] dejo
*                                  C3_Base_Trabajo_20261022.dta y [1] dejo
*                                  MC_cohortes_20261022.ster y
*                                  C3_holm_20261022.dta. No repetirlos.
*   log_13_cohortes_20261022b.log  bloques [2] y [3], con el bloque [3] sin
*                                  z_posgrado combinado y con las columnas
*                                  truncadas. Esta corrida los repite ya
*                                  parcheados; son unos dos minutos.
local hacer_prep   = 0    // [0] verificaciones e identificadores. Rapido.
local hacer_inter  = 0    // [1] LENTO: agrupado con interacciones, 20 imput.
local hacer_oaxaca = 1    // [2] LENTO: Oaxaca-Blinder, 5 imputaciones
local hacer_rubin  = 1    // [3] combinacion de Rubin. Rapido.

* ---------------------------------------------------------------------------
* BLOQUES DE VARIABLES. Identicos a los del 08_estimacion_v5.do, bloque [2.4]
* ---------------------------------------------------------------------------
global v_n1 mujer edad repitente lectura_30min libros_26omas ///
            trabaja_mas20 internet_hogar computador_hogar

global v_n2 ln_matricula ratio_alumnos_docente pct_planta z_posgrado ///
            dotacion_tic rural ju_unica tecnico tecnico_academico ///
            cole_femenino

* $v_n2 SIN rural y SIN pct_planta: esas dos entran por la via de `##`, que ya
* incluye sus efectos principales. Repetirlas produce las notas de colinealidad
* que C5 documento en el apartado 6.2 y ensucia el log sin cambiar el modelo.
global v_n2_int ln_matricula ratio_alumnos_docente z_posgrado ///
                dotacion_tic ju_unica tecnico tecnico_academico ///
                cole_femenino

* Lista de la Oaxaca PRINCIPAL: $v_n2 sin z_posgrado. Ver bloque [0.9].
global v_n2_oax ln_matricula ratio_alumnos_docente pct_planta ///
                dotacion_tic rural ju_unica tecnico tecnico_academico ///
                cole_femenino

* Estructura aleatoria de C1, textual.
global RE "|| mcpio_id: || mcpio_id: R.year || sede_id: || sede_anio:"


********************************************************************************
* [0] PREPARACION Y VERIFICACIONES
********************************************************************************

if `hacer_prep' == 1 {

    display _newline(2) "{hline 78}"
    display "[0] PREPARACION"
    display "{hline 78}"

    timer clear 2
    timer on 2

    use "Base_Estimacion.dta", clear

    * Base_Estimacion.dta ya trae sede_id y mcpio_id creados y registrados como
    * regulares por el bloque [2.3] del 08. Aqui solo se anade sede_anio.
    * Una a una: `drop` es todo o nada, y con datos mi hay que desregistrar
    * antes de borrar (misma nota del bloque [1] del 11).
    foreach v in sede_anio {
        capture mi unregister `v'
        capture drop `v'
    }
    egen long sede_anio = group(cole_cod_dane_sede year)
    mi register regular sede_anio
    mi update

    display _newline "--- Verificacion de identificadores ---"
    quietly count if missing(sede_anio) | missing(sede_id) | missing(mcpio_id)
    display "Filas sin identificador: " r(N) " (debe ser 0)"
    assert r(N) == 0

    display _newline "--- Variables que exige este script ---"
    foreach v in punt_global cwc_inse c_inse_prom_sede c_inse ///
                 estu_inse_individual indice_vuln year {
        confirm variable `v'
    }
    foreach v of global v_n1 {
        confirm variable `v'
    }
    foreach v of global v_n2 {
        confirm variable `v'
    }
    display "Todas presentes."

    display _newline "--- Tamano de las dos cohortes de la Oaxaca ---"
    quietly count if _mi_m == 1 & year == 2018
    local n18 = r(N)
    quietly count if _mi_m == 1 & year == 2023
    local n23 = r(N)
    display "2018: `n18'   2023: `n23'   (esperados 11.456 y 12.366)"

    display _newline "--- Medias brutas del puntaje, para enmarcar la Oaxaca ---"
    tabstat punt_global edad repitente estu_inse_individual ///
        if _mi_m == 1 & inlist(year, 2018, 2023), by(year) ///
        stat(n mean sd) format(%9.4f)

    save "C3_Base_Trabajo_`fbase'.dta", replace

    timer off 2
    display _newline "--- Tiempo del bloque [0] ---"
    timer list 2
}


********************************************************************************
* [0.9] REGLA DE DECISION, IMPRESA ANTES DE ESTIMAR NADA
********************************************************************************
* Se imprime dentro del propio log, como hicieron C5 (apartado 4.1) y C7
* (bloque 0.9), para que la constancia de su anterioridad no dependa del
* registro escrito en el chat.

display _newline(2) "{hline 78}"
display "[0.9] FAMILIA DE CONTRASTES Y CORRECCION POR MULTIPLICIDAD"
display "      FIJADAS ANTES DE ESTIMAR. NINGUN UMBRAL SE MUEVE DESPUES."
display "{hline 78}"
display ""
display "FAMILIA F-C3. Cuatro pruebas CONJUNTAS, una por cada afirmacion de"
display "cambio entre cohortes que el Capitulo 4 sostiene hoy:"
display ""
display "  T1  i(2019/2023).year#c.rural             -> 4.3.2 'se consolido'"
display "  T2  i(2019/2023).year#c.pct_planta        -> 4.3.2 'crece de 15,3 a 17,4'"
display "  T3  i(2019/2023).year#c.cwc_inse          -> 4.3.2 vaiven de beta_w"
display "  T4  i(2019/2023).year#c.c_inse_prom_sede  -> 4.3.2 'la brecha se ensancha'"
display ""
display "Cada T es UN contraste conjunto de cinco coeficientes, no cinco pruebas."
display ""
display "CORRECCION: Holm sobre las cuatro, al 5 %. Umbrales por orden creciente"
display "de p: 0,0125 / 0,0167 / 0,0250 / 0,0500."
display ""
display "PROCEDIMIENTO ANIDADO: solo una T que supere Holm habilita a examinar"
display "sus anos por separado, con Holm sobre las cinco comparaciones DENTRO de"
display "esa variable. Si la conjunta no supera Holm, NINGUN ano individual se"
display "reporta como significativo y la afirmacion del Capitulo 4 se retira."
display ""
display "NO ENTRAN EN LA FAMILIA: cole_femenino x ano y tecnico_academico x ano."
display "El Capitulo 4 no afirma tendencia sobre ellas. Ampliar la familia tras"
display "ver T1-T4 seria lo que C7 rechazo con la variable minas."
display ""
display "OAXACA-BLINDER: NO es confirmatoria. Sin correccion por multiplicidad y"
display "sin promocion de ninguna contribucion individual a hallazgo. Se reporta"
display "el reparto agregado y SOLO EL SIGNO de las contribuciones de edad y"
display "repitente, que es lo que la fila 4 de C3 necesita."
display ""
display "ESPECIFICACION DE LA OAXACA, fijada aqui:"
display "  - La principal va SIN z_posgrado. El borrador de C3 sostenia que su"
display "    aporte de composicion es cero por estar estandarizada por ano;"
display "    C7 (apartado 4.1) demuestra que es falso: promediada POR ESTUDIANTE"
display "    vale 0,2841 en 2018 y 0,0102 en 2023. Incluirla atribuiria a"
display "    composicion un cambio de criterio de reporte del DANE."
display "  - Se corre una variante CON z_posgrado solo para medir cuanto mueve."
display "  - Se usa estu_inse_individual SIN centrar: c_inse esta centrado en"
display "    cada ano y borraria la diferencia de composicion que se busca."
display "  - La version sin INSE existe porque el indice salta entre 2019 y 2020"
display "    por una razon que el diccionario del ICFES no documenta [4.1.2]."
display "  - cole_femenino entra, pero su contribucion detallada NO se interpreta:"
display "    30 sede-ano en todo el periodo."
display "  - Cinco imputaciones, combinadas por las reglas de Rubin, y se reporta"
display "    ademas el rango entre imputaciones, como hace C1 (apartado 6)."
display "{hline 78}"


********************************************************************************
* [1] AGRUPADO CON INTERACCIONES VARIABLE X ANO
********************************************************************************
* Centrado al cluster, igual que el bloque [1] de 12_composicional.do, porque
* las afirmaciones que se contrastan son las de las Tablas 10 y 11. Las filas
* de rural y pct_planta son identicas bajo los dos esquemas de centrado
* (apartado 4.3.1), de modo que T1 y T2 valen igual para la Tabla 8.

if `hacer_inter' == 1 {

    display _newline(2) "{hline 78}"
    display "[1] AGRUPADO CON INTERACCIONES VARIABLE X ANO"
    display "{hline 78}"

    capture confirm file "C3_Base_Trabajo_`fbase'.dta"
    if _rc != 0 {
        display as error "No se encuentra C3_Base_Trabajo_`fbase'.dta."
        display as error "Correr el bloque [0] o ajustar el local fbase."
        exit 601
    }
    use "C3_Base_Trabajo_`fbase'.dta", clear

    timer clear 3
    timer on 3

    mi estimate, dots post: mixed punt_global                            ///
        c.cwc_inse##ib2018.year                                          ///
        c.c_inse_prom_sede##ib2018.year                                  ///
        c.rural##ib2018.year                                             ///
        c.pct_planta##ib2018.year                                        ///
        $v_n1 $v_n2_int indice_vuln                                      ///
        $RE , reml

    timer off 3
    display _newline "--- Tiempo del bloque [1] ---"
    timer list 3

    estimates save "MC_cohortes_`hoy'.ster", replace

    * Los nombres REALES antes de tocar nada. Es la leccion del ensayo 11a.
    display _newline "--- Nombres reales de los parametros ---"
    matrix list e(b)

    * ------------------------------------------------------------------
    * [1.1] Las cuatro pruebas conjuntas de la familia F-C3
    * ------------------------------------------------------------------
    display _newline "{hline 78}"
    display "[1.1] FAMILIA F-C3: CUATRO CONTRASTES CONJUNTOS"
    display "{hline 78}"

    tempname ph
    postfile `ph' str4 prueba str24 variable double chi2 df p ///
        using "C3_holm_`hoy'.dta", replace

    local k = 1
    foreach v in rural pct_planta cwc_inse c_inse_prom_sede {

        local nom : word `k' of "T1" "T2" "T3" "T4"

        display _newline "--- `nom': i(2019/2023).year#c.`v' ---"

        * En `mixed` el termino se almacena con el factor delante. Si la
        * primera escritura falla con r(111), se intenta la inversa antes de
        * rendirse, y se deja constancia.
        capture noisily testparm i(2019/2023).year#c.`v'
        if _rc != 0 {
            display as error "Fallo la primera escritura (codigo " _rc ")."
            display as error "Intentando c.`v'#i(2019/2023).year."
            capture noisily testparm c.`v'#i(2019/2023).year
        }

        if _rc == 0 {
            post `ph' ("`nom'") ("`v'") (r(chi2)) (r(df)) (r(p))
        }
        else {
            display as error "`nom' no se pudo contrastar. Leer los nombres"
            display as error "del matrix list e(b) de arriba y corregirlos."
            post `ph' ("`nom'") ("`v'") (.) (.) (.)
        }

        local ++k
    }

    postclose `ph'

    * ------------------------------------------------------------------
    * [1.2] Holm sobre las cuatro pruebas
    * ------------------------------------------------------------------
    display _newline "{hline 78}"
    display "[1.2] CORRECCION DE HOLM SOBRE LA FAMILIA F-C3"
    display "{hline 78}"

    preserve
        use "C3_holm_`hoy'.dta", clear
        sort p
        generate int orden   = _n
        generate double umbral = 0.05 / (4 - orden + 1)

        * Holm es secuencial: en cuanto una prueba falla, todas las siguientes
        * fallan tambien, aunque su p sea menor que su propio umbral.
        generate byte pasa = .
        local corto = 0
        forvalues i = 1/`=_N' {
            if `corto' == 0 & p[`i'] <= umbral[`i'] {
                quietly replace pasa = 1 in `i'
            }
            else {
                quietly replace pasa = 0 in `i'
                local corto = 1
            }
        }

        format p umbral %9.4f
        format chi2 %9.2f
        list prueba variable chi2 df p umbral pasa, clean noobs

        display _newline "pasa = 1: la afirmacion correspondiente del Capitulo 4"
        display "puede sostenerse y se habilita el examen por anos."
        display "pasa = 0: la afirmacion SE RETIRA. No se reporta ningun ano"
        display "individual como significativo, cualquiera que sea su p."

        save "C3_holm_`hoy'.dta", replace
    restore

    * ------------------------------------------------------------------
    * [1.3] Comparaciones por ano: DESCRIPTIVAS mientras Holm no habilite
    * ------------------------------------------------------------------
    * Se imprimen siempre, porque el texto nuevo necesita la magnitud de la
    * diferencia 2023 frente a 2018 aunque no sea significativa. Lo que NO se
    * hace es leer su significancia si la conjunta no paso Holm.
    display _newline "{hline 78}"
    display "[1.3] DIFERENCIA 2023 FRENTE A 2018, POR VARIABLE"
    display "ATENCION: descriptivas. Su p NO se lee si la conjunta no paso Holm."
    display "{hline 78}"

    foreach v in rural pct_planta cwc_inse c_inse_prom_sede {
        display _newline "--- `v': 2023 frente a 2018 ---"
        capture noisily lincom _b[2023.year#c.`v']
        if _rc != 0 {
            display as error "Nombre no encontrado. Probar _b[c.`v'#2023.year]."
            capture noisily lincom _b[c.`v'#2023.year]
        }
    }

    display _newline "--- Pendiente de cada ano, para las cuatro variables ---"
    display "Cada una es la suma del termino principal y su interaccion."
    foreach v in rural pct_planta cwc_inse c_inse_prom_sede {
        display _newline "=== `v' ==="
        display "2018 (referencia):"
        capture noisily lincom _b[`v']
        forvalues a = 2019/2023 {
            display "`a':"
            capture noisily lincom _b[`v'] + _b[`a'.year#c.`v']
        }
    }
}


********************************************************************************
* [2] OAXACA-BLINDER, 2018 FRENTE A 2023
********************************************************************************
* `oaxaca` no admite mixed ni mi estimate de forma fiable, de modo que se corre
* dentro de un bucle sobre imputaciones y se combina por Rubin en el bloque [3].
*
* ORDEN OBLIGATORIO: mi extract PRIMERO, egen/generate DESPUES. Al reves se
* crean variables sin registrar en el conjunto mi, que es el error E4 de C5.
*
* Cuatro especificaciones por imputacion:
*   A  principal       sin z_posgrado, CON estu_inse_individual
*   B  sin INSE        sin z_posgrado, sin estu_inse_individual
*   C  con z_posgrado  solo para medir cuanto mueve (C7, apartado 4.1)
*   D  sin INSE y con z_posgrado

if `hacer_oaxaca' == 1 {

    display _newline(2) "{hline 78}"
    display "[2] DESCOMPOSICION DE OAXACA-BLINDER, 2018 FRENTE A 2023"
    display "{hline 78}"

    capture which oaxaca
    if _rc != 0 {
        capture ssc install oaxaca, replace
        if _rc != 0 {
            display as error "No se pudo instalar oaxaca. Instalarlo a mano y"
            display as error "volver a correr SOLO este bloque."
            exit 601
        }
    }

    timer clear 4
    timer on 4

    * Las cadenas van holgadas a proposito: "D_sinINSE_posg" son 14 caracteres
    * y "exp_estu_inse_individual" son 24. Con str12 y str16 se truncarian sin
    * aviso, y el bloque [3] no encontraria nunca esas filas al compararlas por
    * nombre. Es un fallo silencioso, no un error de ejecucion.
    tempname po
    postfile `po' int m str16 espec str32 componente ///
        double b se using "C3_oaxaca_`hoy'.dta", replace

    forvalues m = 1/5 {

        display _newline(2) "{hline 78}"
        display "IMPUTACION `m'"
        display "{hline 78}"

        use "C3_Base_Trabajo_`fbase'.dta", clear
        mi extract `m', clear

        keep if inlist(year, 2018, 2023)
        generate byte y2023 = (year == 2023)

        quietly count
        display "Observaciones de las dos cohortes: " r(N)

        forvalues e = 1/4 {

            * `detalle' lista las contribuciones individuales que se extraen.
            * En las especificaciones sin INSE no se pide esa fila, para que el
            * log no se llene de avisos de una variable que no esta en el
            * modelo a proposito.
            if `e' == 1 {
                local nom     "A_principal"
                local lista   "estu_inse_individual $v_n1 $v_n2_oax"
                local detalle "edad repitente estu_inse_individual"
            }
            if `e' == 2 {
                local nom     "B_sinINSE"
                local lista   "$v_n1 $v_n2_oax"
                local detalle "edad repitente"
            }
            if `e' == 3 {
                local nom     "C_conposg"
                local lista   "estu_inse_individual $v_n1 $v_n2"
                local detalle "edad repitente estu_inse_individual z_posgrado"
            }
            if `e' == 4 {
                local nom     "D_sinINSE_posg"
                local lista   "$v_n1 $v_n2"
                local detalle "edad repitente z_posgrado"
            }

            display _newline "--- Oaxaca, m = `m', especificacion `nom' ---"

            capture noisily oaxaca punt_global `lista',      ///
                by(y2023) pooled vce(cluster sede_id) detail

            if _rc != 0 {
                display as error "oaxaca fallo (codigo " _rc "). Reintentando"
                display as error "con la opcion relax. SI ESE REINTENTO"
                display as error "FUNCIONA, hay una variable omitida en una de"
                display as error "las dos cohortes: identificarla ANTES de"
                display as error "interpretar nada."
                capture noisily oaxaca punt_global `lista',  ///
                    by(y2023) pooled vce(cluster sede_id) detail relax
            }

            if _rc == 0 {

                * Los nombres REALES, una sola vez, antes de extraer nada.
                * oaxaca organiza e(b) por ECUACIONES: el reparto agregado vive
                * en `overall' y el detalle en `explained' y `unexplained'.
                * Escribir _b[difference] sin la ecuacion no encuentra nada, y
                * dentro de un `capture post' eso no da error: simplemente no
                * escribe la fila y el bloque [3] sale vacio.
                if `m' == 1 & `e' == 1 {
                    display _newline "--- Nombres reales de e(b) en oaxaca ---"
                    matrix list e(b)
                    display _newline "Si las ecuaciones NO se llaman overall,"
                    display "explained y unexplained, corregir las lineas de"
                    display "abajo antes de seguir."
                }

                foreach c in difference explained unexplained {
                    capture post `po' (`m') ("`nom'") ("`c'") ///
                        (_b[overall:`c']) (_se[overall:`c'])
                    if _rc != 0 {
                        display as error "No se pudo leer overall:`c'."
                    }
                }

                * Contribuciones detalladas que la fila 4 de C3 necesita.
                foreach c of local detalle {
                    capture post `po' (`m') ("`nom'") ("exp_`c'") ///
                        (_b[explained:`c']) (_se[explained:`c'])
                    if _rc != 0 {
                        display as error "No se pudo leer explained:`c'."
                    }
                }
            }
            else {
                display as error "`nom' no se estimo en m = `m'."
            }
        }
    }

    postclose `po'

    timer off 4
    display _newline "--- Tiempo del bloque [2] ---"
    timer list 4
}


********************************************************************************
* [3] COMBINACION DE RUBIN Y RESUMEN
********************************************************************************
* Qbar = media de los Q_m
* Ubar = media de las varianzas dentro de cada imputacion (se^2)
* B    = varianza muestral de los Q_m, con divisor M-1
* T    = Ubar + (1 + 1/M) * B
* nu   = (M-1) * (1 + Ubar / ((1 + 1/M) * B))^2
*
* Con M = 5 los grados de libertad pueden salir muy bajos. Se reportan, y el
* rango entre imputaciones se reporta junto a ellos, como hizo C1.

if `hacer_rubin' == 1 {

    display _newline(2) "{hline 78}"
    display "[3] COMBINACION DE RUBIN SOBRE LAS CINCO IMPUTACIONES"
    display "{hline 78}"

    capture confirm file "C3_oaxaca_`hoy'.dta"
    if _rc != 0 {
        display as error "No se encuentra C3_oaxaca_`hoy'.dta. Correr el [2]."
        exit 601
    }

    use "C3_oaxaca_`hoy'.dta", clear

    generate double u = se^2

    display _newline "Espec.             Componente                    Qbar" ///
        "     EE(T)       t      gl       p       min       max"

    levelsof espec, local(especs)
    foreach e of local especs {
        foreach c in difference explained unexplained ///
                     exp_edad exp_repitente exp_estu_inse_individual ///
                     exp_z_posgrado {

            quietly count if espec == "`e'" & componente == "`c'"
            local M = r(N)
            if `M' < 2 continue

            quietly summarize b if espec == "`e'" & componente == "`c'"
            scalar qbar = r(mean)
            scalar Bv   = r(Var)
            scalar bmin = r(min)
            scalar bmax = r(max)

            quietly summarize u if espec == "`e'" & componente == "`c'"
            scalar ubar = r(mean)

            scalar Tv = ubar + (1 + 1/`M')*Bv
            scalar sev = sqrt(Tv)
            scalar tv  = qbar/sev

            * Cuando la cantidad no depende de la imputacion, la varianza entre
            * imputaciones es cero y los grados de libertad de Rubin se
            * disparan. Es lo que ocurre con la diferencia bruta, que solo usa
            * punt_global, sin un solo valor faltante.
            *
            * El umbral va sobre los GRADOS DE LIBERTAD, no sobre Bv. En la
            * corrida del 23 de octubre, Bv no era cero exacto sino ruido de
            * coma flotante: positivo, distinto entre corridas (1,8e+53 el 22,
            * 1,5e+53 el 23) y suficiente para que la rama de la t se ejecutara
            * y ttail devolviera valor perdido. Por encima de un millon de
            * grados de libertad la t y la normal coinciden en toda cifra que
            * se vaya a reportar, asi que se usa la normal y se declara el
            * valor como asintotico.
            scalar nu = .
            scalar pv = .
            if Bv > 0 {
                scalar nu = (`M'-1) * (1 + ubar/((1 + 1/`M')*Bv))^2
            }
            if missing(nu) | nu > 1e6 {
                scalar nu = .
                scalar pv = 2*normal(-abs(tv))
            }
            else {
                scalar pv = 2*ttail(nu, abs(tv))
            }

            display %-18s "`e'" %-26s "`c'" ///
                %10.3f qbar %10.3f sev %8.2f tv ///
                %8.1f nu %8.4f pv %10.3f bmin %10.3f bmax
        }
    }

    display _newline "{hline 78}"
    display "LECTURA. ATENCION A LA DIRECCION DEL SIGNO. Con by(y2023), el"
    display "grupo 1 es 2018 y el grupo 2 es 2023, de modo que la diferencia"
    display "y todas las contribuciones estan en la metrica 2018 MENOS 2023."
    display "Un gl vacio significa que la cantidad no varia entre imputaciones"
    display "y que el valor p es el asintotico, calculado con la normal."
    display "Un valor NEGATIVO significa que ese componente empuja a 2023 por"
    display "encima de 2018; uno POSITIVO, que lo empuja por debajo."
    display ""
    display "La fila 4 de C3 se decide con el signo de exp_repitente. Repetir"
    display "la prueba SUMA entre 3,9 y 8,5 puntos [Tabla 8], de modo que la"
    display "caida de repitentes del 16,2 % al 10,7 % [Tabla 3] RESTA puntos a"
    display "2023 y por tanto debe aparecer con signo POSITIVO en esta tabla."
    display "Si sale negativa, revisar la direccion de by(y2023) antes de"
    display "escribir una sola linea del informe."
    display ""
    display "Ninguna contribucion individual se promueve a hallazgo. La Oaxaca"
    display "es descriptiva por la regla impresa en el bloque [0.9]."
    display "{hline 78}"
}


********************************************************************************
* CIERRE
********************************************************************************

timer off 1
display _newline "--- Tiempo total de ejecucion ---"
timer list 1

display _newline "{hline 78}"
display "BLOQUE C3 COMPLETADO."
display "Siguiente: aplicar Holm del bloque [1.2] a las filas 1 y 2 de C3, y"
display "el signo de exp_repitente del bloque [3] a la fila 4."
display "NO rellenar ningun [R-C3] del libro de correcciones sin este log."
display "{hline 78}"

log close fase13

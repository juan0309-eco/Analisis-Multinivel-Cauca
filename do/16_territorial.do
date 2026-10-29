********************************************************************************
* PROYECTO : Desempeno Saber 11 en sedes oficiales del Cauca, 2018-2023
* SCRIPT   : 16 - VALIDEZ DE INDICADORES TERRITORIALES Y SELECCION (C7)
* ENTRADA  : N3_Municipios_PCA.dta, N2_Sedes_2018_2023.dta, Base_Estimacion.dta
* SALIDA   : log_16_territorial_<hoy>.log y archivos .ster fechados
* STATA    : 17
* REVISION : 19 de octubre de 2026, tras la corrida del bloque [1]
********************************************************************************
* QUE CAMBIA RESPECTO DE LA VERSION ANTERIOR, Y POR QUE
*
* La corrida del bloque [1] a las 10:32 del 19 de octubre
* [log_16_territorial_20261019b.log] evaluo las precondiciones fijadas de
* antemano y arrojo:
*
*   P1(i)   DE_dentro(tasa_hom_eb) = 25,8738 < 28,66           SI
*   P1(ii)  corr(eb, TerriData) 0,8959 < corr(cruda, td) 0,8976 NO
*   P2      razon dentro/total de iica = 0,541 >= 0,20          SI
*
* P1 exigia LAS DOS y falla. Conforme a la regla impresa en ese mismo log
* antes de cualquier estimacion, el suavizado se declara NO INFORMATIVO y no
* se lee ningun coeficiente de tasa_hom_eb. En consecuencia:
*
*   - Se RETIRA el modelo ML3b_eb del bloque [3].
*   - Se RETIRA tasa_hom_eb de los bloques [2] y [5].
*   - La variable permanece en la base como documentacion del ejercicio.
*
* El argumento sustantivo apunta en la misma direccion y no depende de ningun
* umbral: la razon DE_dentro/DE_total es 0,616 en la serie cruda y 0,617 en la
* suavizada, y las dos correlacionan 0,9968 en niveles y 0,9940 en
* desviaciones dentro del municipio. A efectos de estimacion son la misma
* variable. El encogimiento afecta al NIVEL de los municipios pequenos, no a
* la variacion temporal que identifica el coeficiente dentro.
*
* UMBRAL DE iica_dev: SE MANTIENE EN 0,025, NO SE RELAJA A 0,05
* La familia F1 se declaro con dos miembros y uno se retiro por una
* precondicion fijada de antemano. Pasar a 0,05 porque ahora queda una sola
* prueba seria ganar potencia por haber mirado el bloque [1]. Se conserva el
* umbral que la correccion de Holm habria impuesto al menor de dos valores p.
*
* HALLAZGO NUEVO, NO PREVISTO, QUE ESTE SCRIPT AMPLIA EN EL BLOQUE [1.8]
* La validacion contra TerriData, que era instrumental, mostro que la serie de
* la Policia crece por un factor de 3,06 entre 2017 y 2022 mientras la de
* TerriData lo hace por 1,48, y que la concordancia entre ambas sube de forma
* monotona de 0,4931 a 0,9800. El patron es el de una fuente que completa su
* cobertura, no el de un fenomeno que crece. Es material de 4.1.4, de la Tabla
* 6 y de las limitaciones, NO un canal nuevo: tasa_hom_td entra SOLO como
* validacion descriptiva y no se estima ningun modelo con ella.
*
* ESTADO DE LA CADENA: TODA HECHA
*   1. 04 v5   HECHO, log_04_panel_municipal_N3_20261019.log
*   2. 06 v3   HECHO, log_06_pca_vulnerabilidad_20261019.log
*              Indice reproducido exacto: KMO 0,5308, autovalor 1,3724,
*              cargas 0,6696 / 0,5745 / -0,4707, indice anual 0,9571.
*   3. 07c     HECHO, log_07c_actualizar_n3_20261019c.log
*              M = 20, 43 variables regulares, los seis assert pasados.
*   4. 16a     HECHO, log_16a_rehacer_base_20261019c.log, 137,08 s
*              VERIFICACION CRITICA SUPERADA: el tabstat de c_inse, cwc_inse,
*              inse_prom_sede y c_inse_prom_sede reproduce las VEINTE cifras
*              del bloque [2.2] de log_08_estimacion.log (8,5798 / 7,0650 /
*              4,9165 / 4,8681, con los mismos min y max). Base_Estimacion.dta
*              es la misma que produjo las Tablas 8 a 13 mas las variables de
*              C7, de modo que los coeficientes son comparables.
*
* RESULTADO DEL BLOQUE [2], ya corrido [log_16_territorial_20261019c]
*   superv = evaluados / matricula, 2.436 sede-ano, media 0,0749.
*   beta = 5,17e-06 (EE 1,92e-05), p agrupado 0,789, p salvaje 0,7907,
*   IC [-0,0000302; 0,0000617], EMD por DE dentro 0,001543.
*   VEREDICTO F2: NO SE DETECTA, con cota estrecha. El EMD es el 7,6% de una
*   DE dentro de la sede y el 2,1% de la razon media (derivados).
*   Corroboracion municipal: desercion_of beta 0,003861 (0,005317), p 0,472,
*   salvaje 0,5214, EMD 0,427018 (41% de una DE dentro, derivado).
*   Exploratorio y NO promovible: cob_neta_media beta 0,0151338 (0,0073835),
*   p 0,047, signo POSITIVO y contrario a la hipotesis de seleccion, sin
*   bootstrap salvaje y fuera de toda familia declarada.
*
* ESTRUCTURA ALEATORIA
* La principal es la CRUZADA de C1. La anidada || mcpio_id: || mcpio_anio:
* || sede_anio: esta descartada: ahi el componente municipio-ano se estima en
* 9,72e-09 [log_11_estructura.log, bloque 1(a)].
*
* ADVERTENCIA DE TIEMPO
* Con ML3b_eb retirado, el bloque [3] estima UN modelo: entre 30 y 50 min.
********************************************************************************

clear all
set more off
set varabbrev off
version 17

if "$TESIS_CONFIG" == "" do "C:\Users\RYZEN 5\Desktop\Tesis Multinivel\Definitivo\00_config.do"
cd "$RAIZ"

* ----------------------------------------------------------------------
* FECHA DE LAS SALIDAS. Cambiar en cada corrida nueva.
* ----------------------------------------------------------------------
local hoy "20261019d"

capture log close _all
capture confirm file "log_16_territorial_`hoy'.log"
if _rc == 0 {
    display as error "Ya existe log_16_territorial_`hoy'.log."
    display as error "Cambiar el local hoy antes de volver a correr."
    exit 602
}

log using "log_16_territorial_`hoy'.log", text name(fase16)

* ----------------------------------------------------------------------
* INTERRUPTORES DE BLOQUE
* ----------------------------------------------------------------------
* ESTADO AL 19/10/2026, 10:55
*   [1]   corrio a las 10:32 [log_16_territorial_20261019b.log]. HECHO.
*   [1.8] corrio a las 10:52 [log_16_territorial_20261019c.log]. HECHO.
*   [2]   corrio a las 10:52 [log_16_territorial_20261019c.log]. HECHO.
*   [3]   ABORTO con r(111): el 16 se lanzo 18 segundos ANTES del 16a, de modo
*         que Base_Estimacion.dta todavia no tenia iica_bar. El 16a termino a
*         las 10:54:44 y la base ya las tiene [log_16a_rehacer_base_20261019c,
*         bloque 4: iica_bar e iica_dev sin faltantes y constantes dentro de
*         cada municipio-ano].
*   [4] y [5] no llegaron a correr.
*
* Esta corrida hace SOLO lo que falta. Los bloques [1.8] y [2] quedan en 0
* porque sus resultados son validos: leen N3_Municipios_PCA.dta y
* N2_Sedes_2018_2023.dta, que estaban correctos desde las 10:31:57 y no
* dependen de Base_Estimacion.dta. Volver a correrlos solo duplicaria salida.
* ----------------------------------------------------------------------
local hacer_valid  = 0    // [1.8] HECHO en log_16_territorial_20261019c
local hacer_deser  = 0    // [2]   HECHO en log_16_territorial_20261019c
local hacer_ml     = 1    // [3] ML3b_iica, un solo modelo: 30-50 min
local hacer_posg   = 1    // [4] posgrado entre sedes: 8-15 min
local hacer_tres   = 1    // [5] tres procedimientos para iica: 15-25 min

timer clear
timer on 1

global v_n1 mujer edad repitente lectura_30min libros_26omas ///
            trabaja_mas20 internet_hogar computador_hogar

global v_n2 ln_matricula ratio_alumnos_docente pct_planta z_posgrado ///
            dotacion_tic rural ju_unica tecnico tecnico_academico ///
            cole_femenino

global RE "|| mcpio_id: || mcpio_id: R.year || sede_id: || sede_anio:"

display _newline "{hline 78}"
display "ESTRUCTURA ALEATORIA: $RE"
display "{hline 78}"


********************************************************************************
* [0.9] LA REGLA, ACTUALIZADA TRAS LA CORRIDA DEL BLOQUE [1]
********************************************************************************

display _newline(2) "{hline 78}"
display "[0.9] CRITERIO VIGENTE"
display "{hline 78}"
display "ESTADO DE LAS PRECONDICIONES, evaluadas el 19/10/2026 a las 10:32"
display "[log_16_territorial_20261019b.log, bloque 1.3 y 1.4]:"
display "   P1(i)  25,8738 < 28,66                      SI"
display "   P1(ii) 0,8959 frente a 0,8976               NO"
display "   P2     razon de iica 0,541 >= 0,20          SI"
display ""
display "CONSECUENCIA. P1 exigia las dos y falla: el suavizado se declara NO"
display "   INFORMATIVO. ML3b_eb se retira y ningun coeficiente de"
display "   tasa_hom_eb se lee. El margen de P1(ii) es 0,0017, una septima"
display "   parte del error estandar de una correlacion de 0,90 sobre 238"
display "   observaciones (derivado), de modo que la cifra no admite mas"
display "   precision de la que tiene; pero el argumento que cierra el punto"
display "   no es ese, sino que las dos series son la misma variable:"
display "   razon dentro/total 0,616 frente a 0,617, correlacion 0,9968 en"
display "   niveles y 0,9940 en desviaciones dentro del municipio."
display ""
display "FAMILIAS VIGENTES."
display "   F1 = {iica_dev}. UMBRAL 0,025, NO 0,05: la familia se declaro con"
display "        dos miembros y uno se retiro por una precondicion fijada de"
display "        antemano. Relajar el umbral seria ganar potencia por haber"
display "        mirado el bloque [1]."
display "   F2 = canal de desercion, una prueba confirmatoria al 5%."
display "   F3 = z_posgrado_bar, una prueba al 5%."
display "   Los componentes _bar NO son confirmatorios (apartado 3.6.3)."
display "   Todo lo demas es EXPLORATORIO, incluido ln_ing_trib_pc_bar y"
display "   cualquier coeficiente de minas."
display ""
display "PROMOCION. iica_dev se declara robusto solo si p <= 0,025 en los TRES"
display "   procedimientos del apartado 3.6.1. En uno o dos: evidencia"
display "   parcial. En ninguno: nulo, con su EMD como cota."
display ""
display "SI iica_dev SOBREVIVE Y LOS HOMICIDIOS NO, no se concluye que el"
display "   conflicto importe y la violencia letal no, sin contrastarlo: en"
display "   desviaciones dentro del municipio las dos comparten el 23% de su"
display "   varianza (0,4832 al cuadrado, derivado). El bloque [3] las estima"
display "   juntas para que el contraste sea posible."
display ""
display "DESERCION. YA RESUELTO en el bloque [2]: NO SE DETECTA, con cota de"
display "   0,001543 por DE dentro. Conforme a lo decidido antes de correr, la"
display "   frase de 4.4.3 que declara la via descartada se retira igual, y"
display "   con ella su eco en 5.4: el diseno de F.4 estaba mal planteado y un"
display "   diseno mal planteado no descarta nada. Lo que la sustituye es mas"
display "   fuerte que lo que habia, porque acota."
display ""
display "TASA DE TERRIDATA. Entra SOLO como validacion descriptiva de 4.1.4 y"
display "   de las limitaciones. No se estima ningun modelo con ella: fue"
display "   examinada despues de ver datos y un canal elegido asi no puede"
display "   ser confirmatorio."
display ""
display "ALCANCE DEL HALLAZGO DE FUENTES, precisado por el bloque [1.8]."
display "   Sobre el panel balanceado de 35 municipios, la razon de medias"
display "   Policia/TerriData sube de 0,486 a 1,025 de forma monotona y el"
display "   crecimiento es x2,980 frente a x1,411. PERO la concordancia en"
display "   DESVIACIONES dentro del municipio es ESTABLE, no creciente:"
display "   0,8309 / 0,7237 / 0,8179 / 0,8219 / 0,8834 / 0,8296, con 0,7781 en"
display "   el conjunto. La discrepancia esta por tanto en el NIVEL y no en la"
display "   variacion temporal relativa, y los efectos fijos de ano de ML3b"
display "   absorben la parte comun a todos los municipios. Se declara como"
display "   limitacion de validez descriptiva (Tabla 6, 4.1.4, 1.6) y como"
display "   cuarta explicacion POSIBLE del nulo, NO como amenaza establecida"
display "   al coeficiente. Lo que no absorben los efectos de ano es una"
display "   mejora heterogenea entre municipios; la estabilidad de las"
display "   desviaciones sugiere que no domina, pero no lo prueba, y asi se"
display "   escribe."
display ""
display "POSGRADO. Relevante solo si cambia de signo o cruza el 5% en"
display "   direccion contraria. Si no, acotacion (Regla 3 de C5)."
display "{hline 78}"


********************************************************************************
* [1.8] VALIDACION DE FUENTES SOBRE EL PANEL BALANCEADO
********************************************************************************
* El bloque [1] de la corrida anterior comparo las dos series sobre 238 de las
* 252 observaciones, con entre 38 y 41 municipios segun el ano. Esa comparacion
* mezcla el nivel con la composicion: un ano con menos municipios reportados
* puede dar una media distinta sin que cambie nada.
*
* Aqui se repite sobre el subconjunto de municipios con los SEIS anos de
* TerriData, que es la unica comparacion que admite lectura temporal.

if `hacer_valid' == 1 {

    display _newline(2) "{hline 78}"
    display "[1.8] VALIDACION DE FUENTES, PANEL BALANCEADO"
    display "{hline 78}"

    use "N3_Municipios_PCA.dta", clear
    xtset cole_cod_mcpio_ubicacion year

    bysort cole_cod_mcpio_ubicacion: egen byte _nd = total(!missing(tasa_hom_td))

    quietly levelsof cole_cod_mcpio_ubicacion if _nd == 6, local(mb)
    display "Municipios con los seis anos de TerriData: " wordcount("`mb'") ///
            " de 42"
    quietly levelsof cole_cod_mcpio_ubicacion if _nd < 6, local(mi)
    display "Municipios con algun ano faltante: " wordcount("`mi'")
    if wordcount("`mi'") > 0 {
        display "  Codigos: `mi'"
    }

    display _newline "--- Cuantos anos faltan, por municipio incompleto ---"
    preserve
        keep if _nd < 6
        egen byte _t = tag(cole_cod_mcpio_ubicacion)
        keep if _t == 1
        list cole_cod_mcpio_ubicacion _nd, clean noobs
    restore

    preserve
        keep if _nd == 6

        display _newline "--- Las dos series sobre el panel balanceado ---"
        tabstat tasa_homicidios tasa_hom_eb tasa_hom_td, ///
            by(year) stat(n mean sd p50 min max) format(%9.3f)

        display _newline "--- Razon Policia / TerriData, por ano ---"
        display "    (si la serie de la Policia estuviera completa desde el"
        display "     principio, esta razon deberia ser estable)"
        generate double _ratio = tasa_homicidios / tasa_hom_td if tasa_hom_td > 0
        forvalues y = 2018/2023 {
            quietly summarize tasa_homicidios if year == `y', meanonly
            local mp = r(mean)
            quietly summarize tasa_hom_td if year == `y', meanonly
            local mt = r(mean)
            display "  `y': Policia " %8.3f `mp' "   TerriData " %8.3f `mt' ///
                    "   razon de medias " %6.3f `mp'/`mt'
        }
        drop _ratio

        display _newline "--- Crecimiento 2018-2023 de cada serie ---"
        foreach v in tasa_homicidios tasa_hom_td {
            quietly summarize `v' if year == 2018, meanonly
            local v0 = r(mean)
            quietly summarize `v' if year == 2023, meanonly
            display "  `v': " %8.3f `v0' " -> " %8.3f r(mean) ///
                    "   factor " %6.3f r(mean)/`v0'
        }

        display _newline "--- Concordancia por ano, panel balanceado ---"
        forvalues y = 2018/2023 {
            quietly correlate tasa_homicidios tasa_hom_td if year == `y'
            display "  `y': r = " %7.4f r(rho) "   (N = " r(N) ")"
        }

        display _newline "--- Variacion entre y dentro, las dos fuentes ---"
        xtset cole_cod_mcpio_ubicacion year
        xtsum tasa_homicidios tasa_hom_td

        display _newline "--- Concordancia en desviaciones dentro del municipio ---"
        bysort cole_cod_mcpio_ubicacion: egen double _tdb = mean(tasa_hom_td)
        generate double _tdd = tasa_hom_td - _tdb
        bysort cole_cod_mcpio_ubicacion: egen double _thb = mean(tasa_homicidios)
        generate double _thd = tasa_homicidios - _thb
        correlate _thd _tdd
        forvalues y = 2018/2023 {
            quietly correlate _thd _tdd if year == `y'
            display "  `y': r de las desviaciones = " %7.4f r(rho)
        }
        drop _tdb _tdd _thb _thd
    restore

    display _newline "{hline 78}"
    display "LECTURA. Si la razon de medias sube de forma monotona y la"
    display "concordancia tambien, el patron es el de una fuente que completa"
    display "su cobertura. Eso NO invalida el Objetivo 4, pero anade una"
    display "cuarta explicacion al nulo de 4.4.3 que hay que declarar: parte"
    display "de la variacion dentro del municipio puede ser mejora de"
    display "registro y no cambio real. Va a 4.1.4, Tabla 6 y 1.6."
    display "{hline 78}"
}


********************************************************************************
* [2] CANAL DE DESERCION Y SELECCION: EL SUSTITUTO DE F.4
********************************************************************************
* F.4 correlacionaba el cambio en homicidios con el cambio en el NUMERO BRUTO
* de evaluados, que confunde seleccion con demografia.
*
*   [2.A] principal: razon de evaluados sobre matricula de la sede
*   [2.B] corroboracion: tasa de desercion intraanual del municipio
*
* NINGUNA ES LA TASA DE SUPERVIVENCIA DE GRADO NOVENO. La matricula por grado
* no existe en las fuentes empleadas [02_panel_sedes_N2_v2.do, bloque 1]. Va
* declarado como limitacion.
*
* TIMING: desercion_of y tasa_homicidios estan ambas en year_dato, de modo que
* la asociacion es CONTEMPORANEA en tiempo real, no rezagada.
*
* tasa_hom_eb NO aparece en este bloque: retirada por P1.

if `hacer_deser' == 1 {

    display _newline(2) "{hline 78}"
    display "[2] CANAL DE DESERCION Y SELECCION"
    display "{hline 78}"

    capture which boottest
    if _rc != 0 {
        capture ssc install boottest, replace
        if _rc != 0 {
            display as error "No se pudo instalar boottest. Sin bootstrap"
            display as error "salvaje no se aplica la regla de 3.6.1."
        }
    }

    * ------------------------------------------------------------------
    * [2.A] PRINCIPAL: razon de supervivencia aproximada, por sede
    * ------------------------------------------------------------------
    capture confirm file "N2_Sedes_2018_2023.dta"
    if _rc != 0 {
        display as error "No encuentro N2_Sedes_2018_2023.dta."
        display as error "Es la salida del 03_panel_tic_N2_v2.do. Ajustar el"
        display as error "nombre del archivo en esta linea."
        exit 601
    }

    use "N2_Sedes_2018_2023.dta", clear

    display _newline "--- Insumos de la razon ---"
    misstable summarize evaluados_sede matricula, all

    generate double superv = evaluados_sede / matricula ///
        if matricula > 0 & !missing(matricula)
    label variable superv "Evaluados en once sobre matricula total de la sede"

    quietly count if missing(superv)
    display "Sede-ano sin razon calculable: " r(N) " de " _N

    display _newline "--- Distribucion de la razon, por ano ---"
    tabstat superv, by(year) stat(n mean sd p10 p50 p90 min max) format(%9.4f)

    merge m:1 cole_cod_mcpio_ubicacion year using "N3_Municipios_PCA.dta", ///
        keep(master match) keepusing(tasa_homicidios iica ///
        desercion_of cob_neta_media) generate(_m_n3)
    tabulate _m_n3
    assert _m_n3 == 3
    drop _m_n3

    egen long sede_id = group(cole_cod_dane_sede)
    xtset sede_id year

    display _newline "--- Variacion de la razon entre y dentro de la sede ---"
    xtsum superv

    * DE dentro del municipio de la variable explicativa, para el EMD.
    preserve
        keep cole_cod_mcpio_ubicacion year tasa_homicidios
        duplicates drop
        xtset cole_cod_mcpio_ubicacion year
        quietly xtsum tasa_homicidios
        scalar sdw_h = r(sd_w)
    restore
    display _newline "DE dentro del municipio, tasa cruda: " %8.4f sdw_h

    display _newline "--- [2.A.1] PRUEBA CONFIRMATORIA DE F2 ---"
    display "Efectos fijos de sede y de ano, errores agrupados por municipio."
    xtreg superv tasa_homicidios i.year, fe ///
        vce(cluster cole_cod_mcpio_ubicacion)
    estimates save "C7_superv_fe_`hoy'.ster", replace

    scalar b_superv   = _b[tasa_homicidios]
    scalar se_superv  = _se[tasa_homicidios]
    quietly test tasa_homicidios
    scalar p_superv   = r(p)
    scalar emd_superv = 2.802 * se_superv * sdw_h
    display _newline "  beta por DE dentro: " %10.6f b_superv*sdw_h
    display "  p agrupado:         " %6.4f p_superv
    display "  EMD por DE dentro:  " %10.6f emd_superv

    capture noisily boottest tasa_homicidios, weighttype(webb) reps(9999) ///
        seed(2026) nograph
    if _rc == 0 {
        display "  p bootstrap salvaje: " %6.4f r(p)
    }

    display _newline "--- [2.A.2] Verificacion con el denominador rezagado ---"
    * Solo cubre las cohortes 2020-2023: la matricula arranca en 2018.
    generate double superv_l2 = evaluados_sede / L2.matricula ///
        if L2.matricula > 0 & !missing(L2.matricula)
    quietly count if !missing(superv_l2)
    display "  Sede-ano con razon rezagada: " r(N)
    capture noisily xtreg superv_l2 tasa_homicidios i.year, fe ///
        vce(cluster cole_cod_mcpio_ubicacion)

    * ------------------------------------------------------------------
    * [2.B] CORROBORACION: desercion intraanual del municipio
    * ------------------------------------------------------------------
    display _newline(2) "--- [2.B] DESERCION MUNICIPAL ---"

    use "N3_Municipios_PCA.dta", clear
    xtset cole_cod_mcpio_ubicacion year

    * ADVERTENCIA DE SERIE: repitencia_of pasa de ~1% a ~6% entre 2019 y 2020
    * [log_04, bloque 5], lo que delata un cambio de criterio de reporte en la
    * serie educativa de TerriData. desercion_of cae a 1,73 ese mismo ano,
    * compatible con las politicas de promocion de la pandemia. Los efectos de
    * ano absorben el nivel, no un cambio en lo que mide el indicador.
    display _newline "--- Desercion y repitencia por ano: quiebre de reporte ---"
    tabstat desercion_of repitencia_of cob_neta_media, ///
        by(year) stat(n mean sd min max) format(%9.3f)

    quietly xtsum tasa_homicidios
    scalar sdw_h2 = r(sd_w)

    display _newline "--- Desercion sobre homicidios, efectos fijos ---"
    xtreg desercion_of tasa_homicidios i.year, fe ///
        vce(cluster cole_cod_mcpio_ubicacion)
    estimates save "C7_deser_mcpio_`hoy'.ster", replace
    display "  beta por DE dentro: " %10.6f _b[tasa_homicidios]*sdw_h2
    display "  EMD por DE dentro:  " %10.6f ///
        2.802*_se[tasa_homicidios]*sdw_h2
    capture noisily boottest tasa_homicidios, weighttype(webb) reps(9999) ///
        seed(2026) nograph

    * ------------------------------------------------------------------
    * [2.C] SECUNDARIO Y EXPLORATORIO: cobertura en media
    * ------------------------------------------------------------------
    * El profesor pide cuantificar la seleccion con la cobertura en media.
    * No esta en ninguna familia declarada: se reporta, no se promueve.
    display _newline "--- [2.C] EXPLORATORIO: cobertura neta en media ---"
    xtreg cob_neta_media tasa_homicidios i.year, fe ///
        vce(cluster cole_cod_mcpio_ubicacion)
}


********************************************************************************
* [3] ML3b CON EL IICA
********************************************************************************
* UN SOLO MODELO. ML3b_eb retirado por P1.
*
* Se conserva la tasa CRUDA junto al IICA para que el unico cambio frente a la
* Tabla 13 sea la incorporacion del indicador adicional de conflicto, y para
* que el contraste entre ambas medidas sea posible dentro del mismo modelo:
* en desviaciones dentro del municipio comparten el 23% de su varianza.

if `hacer_ml' == 1 {

    display _newline(2) "{hline 78}"
    display "[3] ML3b_iica"
    display "{hline 78}"

    use "Base_Estimacion.dta", clear

    foreach v in iica_bar iica_dev {
        capture confirm variable `v'
        if _rc != 0 {
            display as error "`v' no esta en Base_Estimacion.dta."
            display as error "Correr 07c y 16a_rehacer_base.do antes."
            exit 111
        }
    }

    foreach v in mcpio_anio sede_anio {
        capture mi unregister `v'
        capture drop `v'
    }
    egen long mcpio_anio = group(cole_cod_mcpio_ubicacion year)
    egen long sede_anio  = group(cole_cod_dane_sede year)
    mi register regular mcpio_anio sede_anio
    mi update

    quietly count if missing(sede_anio)
    display "Filas sin sede_anio: " r(N) " (debe ser 0)"
    assert r(N) == 0

    timer clear 2
    timer on 2

    display _newline "--- ML3b_iica ---"
    mi estimate, dots post: mixed punt_global c_inse $v_n1 $v_n2      ///
        tasa_homicidios_bar tasa_homicidios_dev                       ///
        iica_bar iica_dev                                             ///
        ln_coca_bar ln_coca_dev                                       ///
        ln_inversion_pc_bar ln_inversion_pc_dev ib2018.year $RE , reml
    estimates save "ML3b_iica_`hoy'.ster", replace

    display _newline "--- Contrastes de ML3b_iica ---"
    display "El coeficiente confirmatorio es iica_dev, umbral 0,025."
    lincom iica_dev
    test iica_bar = iica_dev
    testparm iica_bar iica_dev

    display _newline "--- Las dos medidas de conflicto, contrastadas ---"
    * Esto es lo que impide concluir que el conflicto importa y la violencia
    * letal no, por el solo hecho de que una cruce el umbral y la otra no.
    test iica_dev = tasa_homicidios_dev
    testparm iica_dev tasa_homicidios_dev

    display _newline "--- Conjunto de los componentes temporales ---"
    * Comparable con el chi2(3) = 3,79, p = 0,285 de ML3b [log_11, bloque 2].
    test tasa_homicidios_dev iica_dev ln_coca_dev ln_inversion_pc_dev

    display _newline "--- Comparacion con la Tabla 13 ---"
    display "tasa_homicidios_dev en ML3b: -0,009 (0,010)."
    lincom tasa_homicidios_dev

    timer off 2
    display _newline "--- Tiempo del modelo ---"
    timer list 2

    display _newline "{hline 78}"
    display "RECORDATORIO: lo de arriba es UN procedimiento de los tres."
    display "Nada se promueve sin el bloque [5], y con p <= 0,025."
    display "{hline 78}"
}


********************************************************************************
* [4] POSGRADO: SOLO LA VARIACION ENTRE SEDES
********************************************************************************
* SOBRE EL ORDEN DE egen Y mi: el egen va sobre el mi flong completo, con
* bysort _mi_m, y la derivada se registra como IMPUTADA para que Stata no la
* sincronice entre imputaciones. Es el patron del bloque [2.1] del 08 y es
* deliberado. NO convertirlo en `mi passive` ni mover el egen detras de un
* `mi extract`.

if `hacer_posg' == 1 {

    display _newline(2) "{hline 78}"
    display "[4] POSGRADO: PROMEDIO DEL PERIODO POR SEDE"
    display "{hline 78}"

    use "Base_Estimacion.dta", clear

    foreach v in mcpio_anio sede_anio z_posgrado_bar {
        capture mi unregister `v'
        capture drop `v'
    }
    egen long mcpio_anio = group(cole_cod_mcpio_ubicacion year)
    egen long sede_anio  = group(cole_cod_dane_sede year)
    mi register regular mcpio_anio sede_anio
    mi update

    * Un valor por sede-ano, no uno por estudiante.
    egen byte _ts = tag(_mi_m cole_cod_dane_sede year)
    bysort _mi_m cole_cod_dane_sede: egen double _sz = ///
        total(z_posgrado * _ts)
    bysort _mi_m cole_cod_dane_sede: egen double _ns = ///
        total(_ts * (!missing(z_posgrado)))
    generate double z_posgrado_bar = _sz / _ns if _mi_m > 0 & _ns > 0
    label variable z_posgrado_bar "Posgrado estandarizado, promedio del periodo de la sede"
    drop _ts _sz _ns

    mi register imputed z_posgrado_bar
    mi update

    quietly count if _mi_m > 0 & missing(z_posgrado_bar)
    display "Filas sin promedio de posgrado en m>0: " r(N)

    display _newline "--- z_posgrado frente a su promedio de sede ---"
    tabstat z_posgrado z_posgrado_bar if _mi_m == 1, ///
        by(year) stat(n mean sd) format(%9.4f)

    local v_n2_alt : subinstr global v_n2 "z_posgrado" "z_posgrado_bar", word
    display _newline "Bloque de Nivel 2 empleado:"
    display "  `v_n2_alt'"

    display _newline "--- ML1b con el promedio de posgrado (m = 1 a 5) ---"
    mi estimate, imputations(1/5) dots post: mixed punt_global c_inse ///
        $v_n1 `v_n2_alt' indice_vuln ib2018.year $RE , reml
    estimates save "ML1b_posgrado_bar_`hoy'.ster", replace
    lincom z_posgrado_bar

    display _newline "--- Control: ML1b original con m = 1 a 5 ---"
    * Para que la comparacion no mezcle el cambio de variable con el cambio
    * de numero de imputaciones.
    mi estimate, imputations(1/5) dots post: mixed punt_global c_inse ///
        $v_n1 $v_n2 indice_vuln ib2018.year $RE , reml
    estimates save "ML1b_control_m5_`hoy'.ster", replace
    lincom z_posgrado

    display _newline "{hline 78}"
    display "COMPARAR las dos lineas anteriores entre si, y la segunda contra"
    display "el z_posgrado de ML1b en la Tabla 13 (veinte imputaciones)."
    display "{hline 78}"
}


********************************************************************************
* [5] LOS TRES PROCEDIMIENTOS PARA EL IICA
********************************************************************************
* Sin este bloque iica_dev no puede promoverse. Calcado del bloque [4] del
* 11_estructura_aleatoria.do para que los numeros sean comparables con la
* Tabla 30. Solo iica: tasa_hom_eb retirada por P1.

if `hacer_tres' == 1 {

    display _newline(2) "{hline 78}"
    display "[5] EFECTOS FIJOS, BOOTSTRAP SALVAJE Y DOS ETAPAS"
    display "{hline 78}"

    capture which boottest
    if _rc != 0 {
        capture ssc install boottest, replace
        if _rc != 0 {
            display as error "No se pudo instalar boottest. Sin este bloque,"
            display as error "iica_dev no puede promoverse. Declararlo."
            exit 601
        }
    }

    use "N3_Municipios_PCA.dta", clear
    xtset cole_cod_mcpio_ubicacion year
    quietly xtsum iica
    scalar sdw_iica = r(sd_w)
    display "DE dentro del municipio, iica: " %10.6f sdw_iica

    tempname pi
    postfile `pi' int m str20 variable str12 procedimiento ///
        double b p_cluster p_salvaje emd ///
        using "Inferencia_C7_`hoy'.dta", replace

    forvalues m = 1/5 {

        display _newline(2) "--- IMPUTACION `m' ---"

        * --- (a) Efectos fijos de municipio y ano ---
        use "Base_Estimacion.dta", clear
        mi extract `m', clear

        capture drop mcpio_anio
        egen long mcpio_anio = group(cole_cod_mcpio_ubicacion year)

        areg punt_global c_inse $v_n1 $v_n2                           ///
            tasa_homicidios iica ln_coca ln_inversion_pc ib2018.year,  ///
            absorb(mcpio_id) vce(cluster mcpio_id)

        scalar b_v = _b[iica]
        quietly test iica
        scalar p_cl = r(p)

        scalar p_wb  = .
        scalar emd_v = .
        capture noisily boottest iica, weighttype(webb) reps(9999) ///
            seed(2026) nograph
        if _rc == 0 {
            scalar p_wb = r(p)
            matrix CI = r(CI)
            if rowsof(CI) == 1 {
                scalar se_b  = (CI[1,2] - CI[1,1]) / (2*1.96)
                scalar emd_v = 2.802*se_b*sdw_iica
            }
            else {
                display as error "iica (m=`m'): intervalo disjunto en " ///
                    rowsof(CI) " tramos. EMD a mano."
            }
        }

        display "iica (m=`m'): b = " %10.6f b_v                       ///
            "   p cluster = " %6.4f p_cl                              ///
            "   p salvaje = " %6.4f p_wb                              ///
            "   EMD = " %10.6f emd_v

        post `pi' (`m') ("iica") ("efectos fijos") (b_v) (p_cl) (p_wb) (emd_v)

        * --- (b) Dos etapas: cada municipio-ano cuenta una vez ---
        display _newline "--- Dos etapas, m = `m' ---"

        quietly areg punt_global c_inse $v_n1 $v_n2, absorb(mcpio_anio)
        predict double d_ma, d

        collapse (mean) d_ma tasa_homicidios iica ln_coca ln_inversion_pc ///
            (count) n_est = punt_global, by(mcpio_id year)

        quietly count
        display "Observaciones de la segunda etapa: " r(N) " (esperadas: 252)"

        capture noisily regress d_ma tasa_homicidios iica ln_coca ///
            ln_inversion_pc i.year i.mcpio_id [aw = n_est], vce(cluster mcpio_id)
        if _rc != 0 {
            display as error "La segunda etapa fallo en m = `m'. Codigo: " _rc
            continue
        }

        scalar b_v = _b[iica]
        quietly test iica
        scalar p_cl = r(p)

        scalar p_wb  = .
        scalar emd_v = .
        capture noisily boottest iica, weighttype(webb) reps(9999) ///
            seed(2026) nograph
        if _rc == 0 {
            scalar p_wb = r(p)
            matrix CI = r(CI)
            if rowsof(CI) == 1 {
                scalar se_b  = (CI[1,2] - CI[1,1]) / (2*1.96)
                scalar emd_v = 2.802*se_b*sdw_iica
            }
        }

        display "iica (m=`m', dos etapas): b = " %10.6f b_v           ///
            "   p cluster = " %6.4f p_cl                              ///
            "   p salvaje = " %6.4f p_wb                              ///
            "   EMD = " %10.6f emd_v

        post `pi' (`m') ("iica") ("dos etapas") (b_v) (p_cl) (p_wb) (emd_v)
    }

    postclose `pi'

    display _newline(2) "{hline 78}"
    display "[5.1] RANGO ENTRE IMPUTACIONES"
    display "{hline 78}"

    use "Inferencia_C7_`hoy'.dta", clear
    format b p_cluster p_salvaje emd %10.6f
    list, clean noobs sepby(procedimiento)

    display _newline "--- Rango por procedimiento ---"
    tabstat b p_cluster p_salvaje emd, by(procedimiento) ///
        stat(n min max) format(%10.6f)

    display _newline "UMBRAL VIGENTE PARA iica_dev: 0,025, no 0,05."
}


********************************************************************************
* [6] CIERRE
********************************************************************************

timer off 1
display _newline "--- Tiempo total ---"
timer list 1

display _newline "{hline 78}"
display "C7 COMPLETADA EN LA PARTE COMPUTACIONAL."
display "Aplicar la regla del bloque [0.9] ANTES de redactar."
display "No rellenar ningun [R-C7] con cifras que no esten en este log."
display "{hline 78}"

log close fase16

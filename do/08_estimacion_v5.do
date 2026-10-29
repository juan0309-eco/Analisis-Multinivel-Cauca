********************************************************************************
* PROYECTO : Desempeño Saber 11 en sedes oficiales del Cauca, 2018-2023
* SCRIPT   : 08 - ESTIMACIÓN DE LOS MODELOS MULTINIVEL
* ENTRADA  : Base_Multinivel_MI.dta   (mi flong, M = 20)
*            Base_Multinivel_PCA.dta  (sin imputar, para los modelos nulos)
* SALIDA   : archivos .ster con cada modelo estimado
* STATA    : 17
* VERSIÓN  : 5 - el Objetivo 3 pasa a estimarse AÑO POR AÑO, y el centrado
*                sigue las recomendaciones de Enders y Tofighi (2007)
********************************************************************************
* ADVERTENCIA DE TIEMPO
* Cada modelo mixto de tres niveles sobre 69.750 observaciones tarda entre uno
* y tres minutos, y `mi estimate` lo repite veinte veces. Con doce modelos, la
* ejecución completa se mide en horas.
*
* Por eso el script está dividido en bloques con interruptores al inicio. Cada
* modelo se guarda en su propio archivo .ster apenas termina, de modo que una
* interrupción no obliga a repetir lo ya estimado.
*
* POR QUÉ LOS MODELOS NULOS NO NECESITAN IMPUTACIÓN
* El modelo nulo solo involucra la variable dependiente, y `punt_global` no
* tiene un solo valor faltante en las 69.750 observaciones. La partición de la
* varianza es idéntica en las veinte imputaciones, y estimarla sobre la base
* sin imputar da el mismo resultado en una fracción del tiempo.
*
* POR QUÉ HAY DOS VERSIONES DEL GRADIENTE SOCIOECONÓMICO
* El ICFES construye el índice socioeconómico a partir de ítems que incluyen la
* tenencia de computador y de conexión a internet. Al incluir esas variables
* junto al índice, el modelo le pide a este que explique lo que queda después
* de descontar parte de su propio contenido, y su coeficiente cae.
*
* M1a estima el gradiente TOTAL, sin las variables del hogar. M1 estima el
* gradiente NETO de la dotación material. Ambos son correctos y responden a
* preguntas distintas; reportar solo el segundo subestima la asociación
* socioeconómica.
********************************************************************************

clear all
set more off
set varabbrev off
version 17

if "$TESIS_CONFIG" == "" do "C:\Users\RYZEN 5\Desktop\Tesis Multinivel\Definitivo\00_config.do"
cd "$RAIZ"

capture log close _all
local tarea "08_estimacion"
local hoy   "20261024"          // <<< etiqueta de la proxima corrida

capture confirm file "log_`tarea'_`hoy'.log"
if _rc == 0 {
    display as error "Ya existe log_`tarea'_`hoy'.log."
    display as error "Cambiar el local hoy (por ejemplo, anadir un sufijo b, c...)."
    exit 602
}
log using "log_`tarea'_`hoy'.log", text name(fase8)

* ----------------------------------------------------------------------
* INTERRUPTORES DE BLOQUE
* ----------------------------------------------------------------------
* Poner en 0 los bloques ya estimados para reanudar sin repetirlos.
local hacer_obj2   = 1    // modelos nulos y partición de varianza
local hacer_obj3   = 1    // progresión transversal AÑO POR AÑO
local hacer_m4m5   = 1    // pendiente aleatoria e interacciones (agrupado)
local hacer_obj4   = 1    // cortes repetidos, tiempo y descomposición Mundlak
local hacer_robust = 1    // pruebas de robustez

timer clear
timer on 1


********************************************************************************
* [1] MODELOS NULOS Y PARTICIÓN DE LA VARIANZA (OBJETIVO 2)
********************************************************************************

if `hacer_obj2' == 1 {

    display _newline "{hline 78}"
    display "[1] PARTICIÓN DE LA VARIANZA"
    display "{hline 78}"

    use "Base_Multinivel_PCA.dta", clear
    capture xtset, clear

    capture drop sede_id mcpio_id
    egen long sede_id  = group(cole_cod_dane_sede)
    egen long mcpio_id = group(cole_cod_mcpio_ubicacion)

    * --- Modelo nulo agrupado ---
    display _newline "--- Modelo nulo, pool 2018-2023 ---"
    mixed punt_global || mcpio_id: || sede_id: , mle
    estimates save "M0_pool.ster", replace
    estat icc

    * --- Modelo nulo por año ---
    * Insumo del gráfico de evolución del ICC.
    display _newline "--- Modelos nulos por año ---"

    tempname pm
    postfile `pm' int year double icc_mcpio icc_sede icc_est ///
        double v_mcpio v_sede v_est using "ICC_por_year.dta", replace

    foreach a in 2018 2019 2020 2021 2022 2023 {
        display _newline "  Año `a'"
        quietly mixed punt_global if year == `a' || mcpio_id: || sede_id: , mle
        estimates save "M0_`a'.ster", replace

        matrix b = e(b)
        scalar v3 = exp(2*_b[lns1_1_1:_cons])
        scalar v2 = exp(2*_b[lns2_1_1:_cons])
        scalar v1 = exp(2*_b[lnsig_e:_cons])
        scalar vt = v3 + v2 + v1

        post `pm' (`a') (v3/vt) (v2/vt) (v1/vt) (v3) (v2) (v1)
        display "    Municipio: " %6.4f v3/vt "   Sede: " %6.4f v2/vt ///
                "   Estudiante: " %6.4f v1/vt
    }
    postclose `pm'

    display _newline "--- Evolución de la partición de la varianza ---"
    preserve
        use "ICC_por_year.dta", clear
        list, clean noobs
    restore
}


********************************************************************************
* [2] PREPARACIÓN DE LA BASE IMPUTADA
********************************************************************************

display _newline "{hline 78}"
display "[2] PREPARACIÓN DE LA BASE IMPUTADA"
display "{hline 78}"

use "Base_Multinivel_MI.dta", clear

* ----------------------------------------------------------------------
* [2.1] Reconstrucción de las variables derivadas
* ----------------------------------------------------------------------
* `mi register passive` obliga a que las observaciones completas tengan el
* mismo valor en todas las imputaciones. Eso es correcto para una variable que
* depende solo de los datos del propio estudiante, pero no para una media de
* conglomerado, que depende de los valores imputados de sus compañeros y
* cambia legítimamente entre imputaciones.
*
* La solución: dejar las derivadas vacías en m = 0 y registrarlas como
* imputadas. Así Stata no las sincroniza. La estimación nunca usa m = 0.

capture drop inse_prom_sede c_inse cwc_inse c_inse_prom_sede

bysort _mi_m cole_cod_dane_sede year: egen double _prom = ///
    mean(estu_inse_individual)
generate double inse_prom_sede = _prom if _mi_m > 0
drop _prom
label variable inse_prom_sede "INSE medio de la cohorte de la sede"

bysort _mi_m year: egen double _gm = mean(estu_inse_individual)
generate double c_inse = estu_inse_individual - _gm if _mi_m > 0
drop _gm
label variable c_inse "INSE centrado en la gran media del año"

generate double cwc_inse = estu_inse_individual - inse_prom_sede if _mi_m > 0
label variable cwc_inse "INSE centrado en la media de la sede"

bysort _mi_m year: egen double _gms = mean(inse_prom_sede)
generate double c_inse_prom_sede = inse_prom_sede - _gms if _mi_m > 0
drop _gms
label variable c_inse_prom_sede "INSE medio de la sede, centrado"

mi register imputed inse_prom_sede c_inse cwc_inse c_inse_prom_sede

* ----------------------------------------------------------------------
* [2.2] Verificación
* ----------------------------------------------------------------------
display _newline "--- El promedio de sede debe ser constante dentro de la sede-año ---"
bysort _mi_m cole_cod_dane_sede year: egen double _sd_prom = sd(inse_prom_sede)
quietly count if _sd_prom > 1e-8 & !missing(_sd_prom)
display "Observaciones con promedio de sede inconsistente: " r(N) " (debe ser 0)"
assert r(N) == 0
drop _sd_prom

quietly count if _mi_m > 0 & missing(c_inse)
display "Valores faltantes de c_inse en las imputaciones: " r(N) " (debe ser 0)"
assert r(N) == 0

display _newline "--- Descriptivos de las variables centradas ---"
tabstat c_inse cwc_inse inse_prom_sede c_inse_prom_sede if _mi_m == 1, ///
    stat(n mean sd min max) format(%9.4f)

* ----------------------------------------------------------------------
* [2.3] Identificadores de nivel
* ----------------------------------------------------------------------
capture drop sede_id mcpio_id
egen long sede_id  = group(cole_cod_dane_sede)
egen long mcpio_id = group(cole_cod_mcpio_ubicacion)
mi register regular sede_id mcpio_id

* ----------------------------------------------------------------------
* [2.4] Bloques de variables
* ----------------------------------------------------------------------
* El modelo completo incluye todas las variables comprometidas en el
* anteproyecto. Las que resulten no significativas se reportan igual: omitir
* una variable prometida obliga a justificarlo, y un coeficiente sin
* significancia es un resultado, no un problema.
global v_n1 mujer edad repitente lectura_30min libros_26omas ///
            trabaja_mas20 internet_hogar computador_hogar

global v_n2 ln_matricula ratio_alumnos_docente pct_planta z_posgrado ///
            dotacion_tic rural ju_unica tecnico tecnico_academico ///
            cole_femenino

save "Base_Estimacion.dta", replace


********************************************************************************
* [3] OBJETIVO 3 - PROGRESIÓN TRANSVERSAL, AÑO POR AÑO
********************************************************************************
* CAMBIO DE FONDO RESPECTO DE LA VERSIÓN 4
* La versión anterior estimaba esta progresión sobre el conjunto agrupado de
* los seis años. Eso mezcla seis cohortes cuya composición cambió durante el
* periodo: el índice socioeconómico salta entre 2019 y 2020, los repitentes
* caen del 16,2% al 10,7% y la jornada única se expande en 2020. Los
* coeficientes absorbían en parte esas diferencias de cohorte.
*
* Ahora cada año se estima por separado. Un modelo transversal describe una
* cohorte, y con seis cortes lo que corresponde es seis modelos.
*
* LAS VARIABLES CENTRADAS YA ESTABAN LISTAS
* El bloque [2.1] construye c_inse, cwc_inse y c_inse_prom_sede DENTRO DE CADA
* AÑO. Estimar con `if year == a` es por tanto directamente consistente: el
* centrado de cada cohorte se hace contra su propia media.
*
* LOS SEIS MODELOS DE CADA AÑO
*   M1a   gradiente socioeconómico total, sin las variables del hogar
*   M1    bloque individual completo
*   M2    añade las condiciones institucionales
*   M3    añade la vulnerabilidad macro-territorial
*   M3ctx modelo contextual: M3 más el INSE medio de la sede
*   M3cwc reparametrización del anterior con centrado al clúster
*
* POR QUÉ APARECE M3ctx, QUE NO EXISTÍA ANTES
* Enders y Tofighi (2007) advierten que un predictor de Nivel 1 centrado en la
* gran media conserva variación entre clústeres, de modo que su coeficiente es
* una mezcla del efecto individual y del composicional. Citando a Raudenbush y
* Bryk, el estimador jerárquico bajo centrado en la gran media es inapropiado
* para el efecto de nivel individual: es una mezcla no interpretable, ni el uno
* ni el otro.
*
* La solución que proponen es incluir la media del clúster junto al predictor
* individual. Al hacerlo, el coeficiente de c_inse pasa a ser una estimación
* limpia del efecto dentro de la sede, y el de c_inse_prom_sede mide el efecto
* contextual, es decir cuánto añade el nivel socioeconómico del establecimiento
* por encima del propio. Por eso M3ctx, y no M3, es el modelo que debe leerse
* para interpretar el gradiente.
*
* POR QUÉ ADEMÁS SE ESTIMA M3cwc
* M3ctx y M3cwc son parametrizaciones EQUIVALENTES del mismo modelo: contienen
* la misma información escrita de dos formas. La versión con centrado al
* clúster tiene la ventaja de que sus dos coeficientes son ortogonales y se
* leen de forma directa, uno como efecto dentro de la sede y otro como efecto
* entre sedes. El bloque [3.1] verifica numéricamente la identidad algebraica
* que las liga.
*
* SOBRE EL CENTRADO DE LA MEDIA DE SEDE
* `c_inse_prom_sede` entra centrada en la media del año, no en métrica bruta.
* Es una variable de Nivel 2 y, siguiendo a Enders y Tofighi, la elección entre
* métrica bruta y centrado en la gran media afecta ÚNICAMENTE al intercepto y a
* ningún otro coeficiente. Centrarla es preferible porque el intercepto pasa a
* ser el puntaje esperado en una sede de nivel socioeconómico promedio; en
* métrica bruta sería el puntaje esperado en una sede con INSE medio de cero,
* un valor imposible dado que la escala va de 29,7 a 61,6.
********************************************************************************

if `hacer_obj3' == 1 {

    use "Base_Estimacion.dta", clear

    * Archivo donde se acumulan los coeficientes de cada año, para armar
    * después la tabla de evolución y la figura sin reabrir los .ster.
    tempname pc
    postfile `pc' int year str8 modelo                                     ///
        double b_ind se_ind b_ctx se_ctx b_planta se_planta                ///
        double b_rural se_rural b_matric se_matric b_vuln se_vuln          ///
        double v_mcpio v_sede v_resid                                      ///
        using "Coef_por_year.dta", replace

    foreach a in 2018 2019 2020 2021 2022 2023 {

        display _newline(2) "{hline 78}"
        display "COHORTE `a'"
        display "{hline 78}"

        * --- M1a: gradiente socioeconómico total ---
        display _newline "--- M1a_`a': gradiente total ---"
        mi estimate, dots post: mixed punt_global c_inse mujer edad         ///
            if year == `a' || mcpio_id: || sede_id: , mle
        estimates save "M1a_`a'.ster", replace
        post `pc' (`a') ("M1a") (_b[c_inse]) (_se[c_inse])                  ///
            (.) (.) (.) (.) (.) (.) (.) (.) (.) (.)                         ///
            (exp(2*_b[lns1_1_1:_cons])) (exp(2*_b[lns2_1_1:_cons]))         ///
            (exp(2*_b[lnsig_e:_cons]))

        * --- M1: bloque individual completo ---
        display _newline "--- M1_`a': características individuales ---"
        mi estimate, dots post: mixed punt_global c_inse $v_n1              ///
            if year == `a' || mcpio_id: || sede_id: , mle
        estimates save "M1_`a'.ster", replace
        post `pc' (`a') ("M1") (_b[c_inse]) (_se[c_inse])                   ///
            (.) (.) (.) (.) (.) (.) (.) (.) (.) (.)                         ///
            (exp(2*_b[lns1_1_1:_cons])) (exp(2*_b[lns2_1_1:_cons]))         ///
            (exp(2*_b[lnsig_e:_cons]))

        * --- M2: añade condiciones institucionales ---
        display _newline "--- M2_`a': añade Nivel 2 ---"
        mi estimate, dots post: mixed punt_global c_inse $v_n1 $v_n2        ///
            if year == `a' || mcpio_id: || sede_id: , mle
        estimates save "M2_`a'.ster", replace
        post `pc' (`a') ("M2") (_b[c_inse]) (_se[c_inse]) (.) (.)           ///
            (_b[pct_planta]) (_se[pct_planta]) (_b[rural]) (_se[rural])     ///
            (_b[ln_matricula]) (_se[ln_matricula]) (.) (.)                  ///
            (exp(2*_b[lns1_1_1:_cons])) (exp(2*_b[lns2_1_1:_cons]))         ///
            (exp(2*_b[lnsig_e:_cons]))

        * --- M3: añade vulnerabilidad macro-territorial ---
        * Con 42 municipios en un solo año este coeficiente se estima con muy
        * poca precisión. Intervalos anchos son lo esperable, no un fallo.
        display _newline "--- M3_`a': añade Nivel 3 ---"
        mi estimate, dots post: mixed punt_global c_inse $v_n1 $v_n2        ///
            indice_vuln if year == `a' || mcpio_id: || sede_id: , mle
        estimates save "M3_`a'.ster", replace
        post `pc' (`a') ("M3") (_b[c_inse]) (_se[c_inse]) (.) (.)           ///
            (_b[pct_planta]) (_se[pct_planta]) (_b[rural]) (_se[rural])     ///
            (_b[ln_matricula]) (_se[ln_matricula])                          ///
            (_b[indice_vuln]) (_se[indice_vuln])                            ///
            (exp(2*_b[lns1_1_1:_cons])) (exp(2*_b[lns2_1_1:_cons]))         ///
            (exp(2*_b[lnsig_e:_cons]))

        * --- M3ctx: modelo contextual (ESPECIFICACIÓN DE REFERENCIA) ---
        * Al incluir el INSE medio de la sede, el coeficiente de c_inse deja de
        * ser una mezcla y pasa a estimar el efecto dentro de la sede.
        display _newline "--- M3ctx_`a': modelo contextual ---"
        mi estimate, dots post: mixed punt_global c_inse c_inse_prom_sede   ///
            $v_n1 $v_n2 indice_vuln if year == `a'                          ///
            || mcpio_id: || sede_id: , mle
        estimates save "M3ctx_`a'.ster", replace

        display _newline "¿Aporta el nivel socioeconómico de la sede por encima"
        display "del propio? Si este coeficiente no difiere de cero, no hay"
        display "efecto contextual distinguible en la cohorte `a'."
        lincom c_inse_prom_sede

        scalar b_ctx_cgm = _b[c_inse_prom_sede]
        post `pc' (`a') ("M3ctx") (_b[c_inse]) (_se[c_inse])                ///
            (_b[c_inse_prom_sede]) (_se[c_inse_prom_sede])                  ///
            (_b[pct_planta]) (_se[pct_planta]) (_b[rural]) (_se[rural])     ///
            (_b[ln_matricula]) (_se[ln_matricula])                          ///
            (_b[indice_vuln]) (_se[indice_vuln])                            ///
            (exp(2*_b[lns1_1_1:_cons])) (exp(2*_b[lns2_1_1:_cons]))         ///
            (exp(2*_b[lnsig_e:_cons]))

        * --- M3cwc: la misma información con centrado al clúster ---
        display _newline "--- M3cwc_`a': centrado al clúster ---"
        mi estimate, dots post: mixed punt_global cwc_inse c_inse_prom_sede ///
            $v_n1 $v_n2 indice_vuln if year == `a'                          ///
            || mcpio_id: || sede_id: , mle
        estimates save "M3cwc_`a'.ster", replace

        display _newline "--- Efecto dentro de la sede frente a efecto entre sedes, `a' ---"
        test cwc_inse = c_inse_prom_sede
        lincom cwc_inse - c_inse_prom_sede

        * ------------------------------------------------------------------
        * [3.1] Verificación de la equivalencia entre las dos parametrizaciones
        * ------------------------------------------------------------------
        * Kreft, de Leeuw y Aiken (1995) demuestran que el coeficiente de la
        * media de sede bajo centrado en la gran media equivale a la diferencia
        * entre los dos coeficientes bajo centrado al clúster. Si los dos
        * números no coinciden, hay un error en la construcción de las
        * variables centradas.
        scalar dif_cwc = _b[c_inse_prom_sede] - _b[cwc_inse]
        display _newline "Verificación de la identidad de Kreft para `a':"
        display "  Coeficiente contextual bajo gran media: " %8.4f b_ctx_cgm
        display "  Diferencia entre y dentro bajo clúster: " %8.4f dif_cwc
        display "  Ambos deben coincidir salvo error numérico."

        post `pc' (`a') ("M3cwc") (_b[cwc_inse]) (_se[cwc_inse])            ///
            (_b[c_inse_prom_sede]) (_se[c_inse_prom_sede])                  ///
            (.) (.) (.) (.) (.) (.) (.) (.)                                 ///
            (exp(2*_b[lns1_1_1:_cons])) (exp(2*_b[lns2_1_1:_cons]))         ///
            (exp(2*_b[lnsig_e:_cons]))
    }

    postclose `pc'

    * ----------------------------------------------------------------------
    * [3.2] Varianza explicada por bloque, contra el modelo nulo del MISMO año
    * ----------------------------------------------------------------------
    display _newline(2) "{hline 78}"
    display "[3.2] VARIANZA EXPLICADA POR BLOQUE, POR COHORTE"
    display "{hline 78}"
    display _newline "Año   Modelo   Var.mcpio  Var.sede  Var.resid  R2mcpio  R2sede"

    foreach a in 2018 2019 2020 2021 2022 2023 {
        capture estimates use "M0_`a'.ster"
        if _rc != 0 {
            display as error "Falta M0_`a'.ster. Correr el bloque [1] primero."
            continue
        }
        scalar vm0 = exp(2*_b[lns1_1_1:_cons])
        scalar vs0 = exp(2*_b[lns2_1_1:_cons])
        scalar vr0 = exp(2*_b[lnsig_e:_cons])
        display "`a'  Nulo    " %9.2f vm0 " " %9.2f vs0 " " %9.2f vr0

        foreach m in M1a M1 M2 M3 M3ctx {
            capture estimates use "`m'_`a'.ster"
            if _rc == 0 {
                scalar vm = exp(2*_b[lns1_1_1:_cons])
                scalar vs = exp(2*_b[lns2_1_1:_cons])
                scalar vr = exp(2*_b[lnsig_e:_cons])
                display "`a'  `m'   " %9.2f vm " " %9.2f vs " " %9.2f vr ///
                        "  " %6.3f (vm0-vm)/vm0 "  " %6.3f (vs0-vs)/vs0
            }
        }
    }

    display _newline "Nota de lectura: seis años por veinte coeficientes son"
    display "ciento veinte contrastes. Estas series se examinan buscando"
    display "estabilidad o tendencia; un coeficiente significativo en un año"
    display "aislado es esperable por azar y no sostiene una conclusión."
}


********************************************************************************
* [4] HETEROGENEIDAD DEL GRADIENTE ENTRE SEDES (COMPLEMENTO AGRUPADO)
********************************************************************************
* Estos dos modelos SÍ se estiman sobre el conjunto agrupado, y la razón es de
* diseño, no de comodidad. Ambos describen cómo varía el gradiente ENTRE SEDES,
* y estimar una pendiente aleatoria con covarianza no restringida sobre las
* cuatrocientas sedes de una sola cohorte produce estimaciones frágiles. El
* agrupado dispone de las 2.447 combinaciones de sede y año.
*
* CAMBIO RESPECTO DE LA VERSIÓN 4: AMBOS PASAN A CENTRADO AL CLÚSTER
* Enders y Tofighi (2007) son explícitos en dos puntos que afectan a estos
* modelos, y solo a estos:
*
*   (a) El centrado en la gran media induce una dependencia entre interceptos y
*       pendientes que comprime artificialmente la varianza de la pendiente y
*       la sesga hacia cero. Con centrado al clúster ese sesgo desaparece.
*       Raudenbush y Bryk recomiendan el centrado al clúster precisamente para
*       detectar y estimar correctamente la heterogeneidad de la pendiente.
*
*   (b) En interacciones entre niveles, el centrado en la gran media puede
*       producir una interacción significativa cuando no existe ninguna en la
*       población. Hofmann y Gavin (1998) lo demostraron con datos artificiales.
*       El motivo es que el término mezcla la moderación del efecto individual
*       con la moderación del efecto composicional.
*
* Por eso M4 y M5 usan `cwc_inse` y añaden `c_inse_prom_sede` como covariable
* de Nivel 2. El coeficiente de la interacción pasa a ser una estimación limpia
* de la moderación entre niveles.

if `hacer_m4m5' == 1 {

    display _newline "{hline 78}"
    display "[4] PENDIENTE ALEATORIA E INTERACCIONES (AGRUPADO, CWC)"
    display "{hline 78}"

    use "Base_Estimacion.dta", clear

    * --- M4: pendiente aleatoria del gradiente dentro de la sede ---
    * La correlación entre pendiente e intercepto indica si las sedes de mejor
    * desempeño compensan o amplifican la desventaja de origen.
    display _newline "--- M4: pendiente aleatoria del INSE entre sedes ---"
    mi estimate, dots post: mixed punt_global cwc_inse c_inse_prom_sede     ///
        $v_n1 $v_n2 indice_vuln                                             ///
        || mcpio_id: || sede_id: cwc_inse , mle covariance(unstructured)
    estimates save "M4_cwc.ster", replace

    * --- M5: interacciones entre niveles ---
    display _newline "--- M5: interacciones entre niveles ---"
    mi estimate, dots post: mixed punt_global c.cwc_inse##c.pct_planta      ///
        c.cwc_inse##c.indice_vuln c_inse_prom_sede $v_n1 $v_n2              ///
        || mcpio_id: || sede_id: cwc_inse , mle covariance(unstructured)
    estimates save "M5_cwc.ster", replace

    display _newline "--- ¿Moderan las condiciones institucionales el gradiente? ---"
    testparm c.cwc_inse#c.pct_planta c.cwc_inse#c.indice_vuln
}



********************************************************************************
* [5] CORTES REPETIDOS Y DESCOMPOSICIÓN DE MUNDLAK (OBJETIVO 4)
********************************************************************************

if `hacer_obj4' == 1 {

    display _newline "{hline 78}"
    display "[5] OBJETIVO 4 - TIEMPO Y ENTORNO MUNICIPAL"
    display "{hline 78}"

    use "Base_Estimacion.dta", clear

    * --- ML1: efectos fijos de año ---
    display _newline "--- ML1: añade efectos fijos de año ---"
    mi estimate, dots post: mixed punt_global c_inse $v_n1 $v_n2 ///
        indice_vuln ib2018.year || mcpio_id: || sede_id: , mle
    estimates save "ML1.ster", replace

    * --- ML2: descomposición de Mundlak del índice ---
    * `vuln_bar` compara territorios; `vuln_dev` compara al municipio consigo
    * mismo y es el coeficiente libre de las diferencias fijas entre territorios.
    display _newline "--- ML2: descomposición entre y dentro de municipio ---"
    mi estimate, dots post: mixed punt_global c_inse $v_n1 $v_n2 ///
        vuln_bar vuln_dev ib2018.year || mcpio_id: || sede_id: , mle
    estimates save "ML2.ster", replace

    display _newline "--- Contraste: componente entre frente a componente dentro ---"
    test vuln_bar = vuln_dev

    * --- ML3: las tres dimensiones por separado ---
    display _newline "--- ML3: homicidios, coca e inversión por separado ---"
    mi estimate, dots post: mixed punt_global c_inse $v_n1 $v_n2 ///
        tasa_homicidios_bar tasa_homicidios_dev ///
        ln_coca_bar ln_coca_dev ///
        ln_inversion_pc_bar ln_inversion_pc_dev ///
        ib2018.year || mcpio_id: || sede_id: , mle
    estimates save "ML3.ster", replace

    display _newline "--- Contrastes por dimensión ---"
    test tasa_homicidios_bar = tasa_homicidios_dev
    test ln_coca_bar = ln_coca_dev
    test ln_inversion_pc_bar = ln_inversion_pc_dev
    test tasa_homicidios_dev ln_coca_dev ln_inversion_pc_dev

    * --- ML4: interacción entre vulnerabilidad y año ---
    display _newline "--- ML4: la asociación cambia en el tiempo ---"
    mi estimate, dots post: mixed punt_global c_inse $v_n1 $v_n2 ///
        vuln_bar c.vuln_dev##ib2018.year || mcpio_id: || sede_id: , mle
    estimates save "ML4.ster", replace

    display _newline "--- ¿Aporta la interacción? ---"
    testparm c.vuln_dev#i.year
}


********************************************************************************
* [6] PRUEBAS DE ROBUSTEZ
********************************************************************************

if `hacer_robust' == 1 {

    display _newline "{hline 78}"
    display "[6] ROBUSTEZ"
    display "{hline 78}"

    use "Base_Estimacion.dta", clear

    * --- R1: índice con estandarización intra-anual ---
    display _newline "--- R1: índice alternativo ---"
    quietly mi estimate, post: mixed punt_global c_inse $v_n1 $v_n2 ///
        indice_vuln_anual ib2018.year || mcpio_id: || sede_id: , mle
    estimates save "R1_indice_anual.ster", replace

    * --- R2: razón alumnos/docente con el otro conteo ---
    display _newline "--- R2: denominador alternativo del ratio ---"
    capture confirm variable ratio_alt
    if _rc == 0 {
        local v_n2_alt : subinstr global v_n2 "ratio_alumnos_docente" "ratio_alt"
        quietly mi estimate, post: mixed punt_global c_inse $v_n1 `v_n2_alt' ///
            indice_vuln ib2018.year || mcpio_id: || sede_id: , mle
        estimates save "R2_ratio_alt.ster", replace
    }
    else {
        display "ratio_alt no está en la base; se omite esta prueba."
    }

    * --- R3: modelo parsimonioso ---
    * Va como robustez, no como resultado principal: seleccionar por
    * significancia las variables que contrastan hipótesis sería búsqueda de
    * especificación.
    display _newline "--- R3: especificación parsimoniosa ---"
    quietly mi estimate, post: mixed punt_global c_inse mujer edad repitente ///
        ln_matricula pct_planta rural ju_unica vuln_bar vuln_dev ib2018.year ///
        || mcpio_id: || sede_id: , mle
    estimates save "R3_parsimonioso.ster", replace

    * --- R5: medida fiscal alternativa, inversión ejecutada (FUT) ---
    * `ln_inv_fut_pc` proviene del Formulario Único Territorial y mide inversión
    * EJECUTADA, no asignada. En logaritmo y per cápita correlaciona 0,53 con la
    * medida principal, así que es una comprobación genuina. Y tiene casi el
    * doble de variación dentro del municipio (0,286 frente a 0,163), de modo
    * que ofrece más potencia para identificar el componente temporal.
    display _newline "--- R5: inversión ejecutada del FUT ---"
    quietly mi estimate, post: mixed punt_global c_inse $v_n1 $v_n2 ///
        tasa_homicidios_bar tasa_homicidios_dev ln_coca_bar ln_coca_dev ///
        ln_inv_fut_pc_bar ln_inv_fut_pc_dev ib2018.year ///
        || mcpio_id: || sede_id: , mle
    estimates save "R5_inv_fut.ster", replace
    display _newline "Componente dentro de la inversión ejecutada:"
    lincom ln_inv_fut_pc_dev

    * --- R6: esfuerzo fiscal propio ---
    * `ln_ing_trib_pc` mide recaudo tributario municipal, no transferencias.
    * Correlaciona 0,06 con la medida principal en niveles, de modo que es la
    * prueba más exigente: si también se asocia con el desempeño, el canal es
    * la capacidad fiscal en general; si no, el canal es específicamente el de
    * las transferencias del SGP.
    * --- R5b: la misma prueba con la serie depurada del atípico ---
    * `ln_inv_fut_pc_x` es idéntica a `ln_inv_fut_pc` salvo por el municipio-año
    * de 2022 con un error de reporte, que queda en faltante. La comparación
    * entre R5 y R5b responde una pregunta concreta: si R5 no confirma el
    * hallazgo principal, ¿es porque el canal fiscal no se sostiene, o porque un
    * solo dato mal reportado infló la varianza temporal de la variable?
    display _newline "--- R5b: inversión ejecutada, serie depurada ---"
    capture confirm variable ln_inv_fut_pc_x_dev
    if _rc == 0 {
        quietly mi estimate, post: mixed punt_global c_inse $v_n1 $v_n2 ///
            tasa_homicidios_bar tasa_homicidios_dev ln_coca_bar ln_coca_dev ///
            ln_inv_fut_pc_x_bar ln_inv_fut_pc_x_dev ib2018.year ///
            || mcpio_id: || sede_id: , mle
        estimates save "R5b_inv_fut_dep.ster", replace
        display _newline "Observaciones utilizadas: " e(N)
        display "Componente dentro de la inversión ejecutada, sin el atípico:"
        lincom ln_inv_fut_pc_x_dev
    }
    else {
        display "ln_inv_fut_pc_x_dev no está en la base."
        display "Correr el 04 v4 y el 07c antes de esta prueba."
    }

    display _newline "--- R6: ingresos tributarios per cápita ---"
    quietly mi estimate, post: mixed punt_global c_inse $v_n1 $v_n2 ///
        tasa_homicidios_bar tasa_homicidios_dev ln_coca_bar ln_coca_dev ///
        ln_ing_trib_pc_bar ln_ing_trib_pc_dev ib2018.year ///
        || mcpio_id: || sede_id: , mle
    estimates save "R6_ing_trib.ster", replace
    display _newline "Componente dentro del recaudo tributario:"
    lincom ln_ing_trib_pc_dev

    * --- R4: colinealidad ---
    * El VIF se calcula sobre una regresión agrupada, que es el diagnóstico
    * convencional. Los dos comandos van en una sola llamada a `mi xeq`, porque
    * cada llamada abre un contexto nuevo y no conserva la estimación anterior.
    * Los coeficientes de esta regresión NO son interpretables: ignora el
    * agrupamiento y mezcla variación entre y dentro de las unidades.
    display _newline "--- R4: factores de inflación de varianza ---"
    mi xeq 1: regress punt_global c_inse $v_n1 $v_n2 indice_vuln; estat vif
}


********************************************************************************
* [7] CIERRE
********************************************************************************

timer off 1
display _newline "--- Tiempo total de ejecución ---"
timer list 1

display _newline "{hline 78}"
display "ESTIMACIÓN COMPLETADA."
display "Modelos guardados en archivos .ster."
display "Siguiente: 09_tablas_graficos.do, que los lee sin volver a estimar."
display "{hline 78}"

log close fase8

********************************************************************************
* PROYECTO : Desempeno Saber 11 en sedes oficiales del Cauca, 2018-2023
* SCRIPT   : 12 - EFECTO COMPOSICIONAL: PERMANENTE, COHORTE Y MEDICION (C2)
* ENTRADA  : Base_Estimacion.dta, Base_Multinivel_PCA.dta, M3cwc_<ano>.ster
* SALIDA   : log_12_composicional.log, Base_C2.dta,
*            M3cwc_pool.ster, M3cwc_perm_dev.ster, M3cwc_fe_sede.ster
* STATA    : 17
********************************************************************************
* QUE RESUELVE
* El Anexo F.6 del informe descansa en M3_cwc.ster, un archivo que ningun
* script de la cadena genera: 08_estimacion_v5.do produce M3cwc_2018 ... 
* M3cwc_2023, M4_cwc y M5_cwc, pero no M3_cwc. El bloque [6] de 10_blindaje.do
* lo carga sin error porque el archivo seguia en disco, generado por la version
* 4 del 08. Este script lo reemplaza y ademas pone a prueba si la brecha entre
* el efecto entre sedes y el efecto dentro de la sede sobrevive cuando (a) la
* media de la cohorte se descompone en componente permanente y desviacion
* anual, y (b) se corrige el efecto dentro por error de medida del INSE.
*
* ESTRUCTURA ALEATORIA
* Los bloques [1] y [2] son AGRUPADOS sobre los seis anos y por tanto usan la
* estructura adoptada en C1, por REML, igual que ML1b-ML4b:
*     || mcpio_id: || mcpio_id: R.year || sede_id: || sede_anio:
*
* Los .ster por ano (M3cwc_2018 ... M3cwc_2023) NO se reestiman. Dentro de un
* solo ano, sede_anio coincide con sede_id y el choque municipio-ano con el
* efecto permanente del municipio, de modo que los dos componentes nuevos son
* inestimables. La estructura de dos componentes es la correcta para ellos.
*
* NUMERACION DE PARAMETROS EN LA ESTRUCTURA CRUZADA (verificada en C1)
*     municipio      lns1_1_1
*     municipio-ano  lns1_2_1     <- NO lns2_1_1
*     sede           lns2_1_1     <- NO lns3_1_1
*     sede-ano       lns3_1_1     <- NO lns4_1_1 (no existe)
*
* TIEMPOS ESPERADOS (calculo derivado de log_11: ML1b = 1.577,80 s)
*     [0] 1-2 min    [1] 30-45 min    [2] 35-50 min
*     [3] 5-15 min   [4] < 1 min      [5] < 1 min
*     Total aproximado: 1 h 15 min a 1 h 45 min.
*
* QUE HAY QUE CAMBIAR EN OTROS SCRIPTS
* 10_blindaje.do, bloque [6]: `estimates use "M3_cwc.ster"` pasa a ser
* `estimates use "M3cwc_pool.ster"`. Y si se conserva ese bloque, invertir el
* lincom a `c_inse_prom_sede - cwc_inse`: tal como esta calcula beta_w - beta_b,
* que es el negativo del efecto contextual, y de ahi viene el error de lectura
* del Anexo F.6. Lo recomendable es dejar hacer_tost = 0 y sustituir la Tabla
* 33 por la Tabla 11b que sale de los bloques [1] a [3] de este script.
********************************************************************************

clear all
set more off
set varabbrev off
version 17

if "$TESIS_CONFIG" == "" do "C:\Users\RYZEN 5\Desktop\Tesis Multinivel\Definitivo\00_config.do"
cd "$RAIZ"

capture log close _all
local tarea "12_composicional"
local hoy   "20261024"          // <<< etiqueta de la proxima corrida

capture confirm file "log_`tarea'_`hoy'.log"
if _rc == 0 {
    display as error "Ya existe log_`tarea'_`hoy'.log."
    display as error "Cambiar el local hoy (por ejemplo, anadir un sufijo b, c...)."
    exit 602
}
log using "log_`tarea'_`hoy'.log", text name(fase12)

timer clear
timer on 1

* ----------------------------------------------------------------------
* INTERRUPTORES DE BLOQUE
* ----------------------------------------------------------------------
* Poner en 0 los bloques ya corridos para reanudar sin repetirlos. El [0] debe
* haber corrido al menos una vez: los demas leen Base_C2.dta.
local hacer_prep    = 1    // [0] construye Base_C2.dta. Rapido.
local hacer_pool    = 1    // [1] LENTO
local hacer_permdev = 1    // [2] LENTO
local hacer_fe      = 1    // [3] minutos
local hacer_conf    = 1    // [4] rapido
local hacer_medida  = 1    // [5] rapido

global v_n1 mujer edad repitente lectura_30min libros_26omas ///
            trabaja_mas20 internet_hogar computador_hogar

global v_n2 ln_matricula ratio_alumnos_docente pct_planta z_posgrado ///
            dotacion_tic rural ju_unica tecnico tecnico_academico ///
            cole_femenino

* Covariables de sede que SI varian dentro de la sede a lo largo del periodo.
* Las cuatro restantes de $v_n2 son invariantes y las absorbe el efecto fijo
* del bloque [3]. Se listan aparte para que mi estimate no tropiece con una
* variable que Stata omita en unas imputaciones y no en otras.
global v_n2_fe ln_matricula ratio_alumnos_docente pct_planta z_posgrado ///
               dotacion_tic ju_unica


********************************************************************************
* [0] PREPARACION: sede_anio, media permanente y desviacion de cohorte
********************************************************************************
* El promedio permanente se toma sobre SEDE-ANOS, no sobre estudiantes, para
* que una cohorte grande no pese mas en la media permanente de la sede.

if `hacer_prep' == 1 {

    display _newline "{hline 78}"
    display "[0] PREPARACION DE LA BASE DE C2"
    display "{hline 78}"

    use "Base_Estimacion.dta", clear

    * --- Identificador de sede-ano para la estructura aleatoria de C1 ---
    capture drop sede_anio
    egen long sede_anio = group(cole_cod_dane_sede year)
    mi register regular sede_anio

    * --- Media permanente y desviacion de cohorte ---
    capture drop inse_sede_perm inse_sede_dev
    egen byte _tsa = tag(_mi_m cole_cod_dane_sede year) if _mi_m > 0
    bysort _mi_m cole_cod_dane_sede: egen double _suma = ///
        total(inse_prom_sede * _tsa)
    bysort _mi_m cole_cod_dane_sede: egen double _nsa  = total(_tsa)

    generate double inse_sede_perm = _suma / _nsa                    if _mi_m > 0
    generate double inse_sede_dev  = inse_prom_sede - inse_sede_perm if _mi_m > 0

    * Centrado de la componente permanente sobre la media NO PONDERADA de las
    * sedes, coherente con la forma en que se construyo. Solo mueve el
    * intercepto; ningun otro coeficiente depende de esta eleccion.
    egen byte _ts = tag(_mi_m cole_cod_dane_sede) if _mi_m > 0
    bysort _mi_m: egen double _sp = total(inse_sede_perm * _ts)
    bysort _mi_m: egen double _np = total(_ts)
    replace inse_sede_perm = inse_sede_perm - _sp/_np if _mi_m > 0

    drop _tsa _ts _suma _nsa _sp _np

    label variable inse_sede_perm "INSE medio permanente de la sede (centrado)"
    label variable inse_sede_dev  "Desviacion de la cohorte respecto de su sede"
    mi register imputed inse_sede_perm inse_sede_dev
    mi update

    * ----------------------------------------------------------------------
    * [0.1] Verificaciones
    * ----------------------------------------------------------------------
    display _newline "--- La media permanente debe ser constante dentro de la sede ---"
    bysort _mi_m cole_cod_dane_sede: egen double _sd_perm = sd(inse_sede_perm)
    quietly count if _sd_perm > 1e-8 & !missing(_sd_perm)
    display "Observaciones con media permanente inconsistente: " r(N) " (debe ser 0)"
    assert r(N) == 0
    drop _sd_perm

    quietly count if _mi_m > 0 & missing(inse_sede_dev)
    display "Faltantes de inse_sede_dev en las imputaciones: " r(N) " (debe ser 0)"
    assert r(N) == 0

    display _newline "--- Descriptivos de las nuevas variables (m = 1) ---"
    tabstat inse_prom_sede inse_sede_perm inse_sede_dev cwc_inse ///
        c_inse_prom_sede if _mi_m == 1, stat(n mean sd min max) format(%9.4f)

    display _newline "--- Numero de sede-anos observados por sede ---"
    display "Una sede con una sola cohorte no aporta nada a inse_sede_dev."
    preserve
        keep if _mi_m == 1
        egen byte _t  = tag(cole_cod_dane_sede year)
        bysort cole_cod_dane_sede: egen int _nper = total(_t)
        egen byte _t2 = tag(cole_cod_dane_sede)
        tabulate _nper if _t2 == 1
    restore

    save "Base_C2.dta", replace
}


********************************************************************************
* [1] MODELO AGRUPADO CON EFECTOS DE ANO Y LA ESTRUCTURA DE C1
********************************************************************************
* Reemplaza al M3_cwc de la version 4, que la cadena vigente no reproduce y que
* alimentaba el Anexo F.6.

if `hacer_pool' == 1 {

    display _newline "{hline 78}"
    display "[1] AGRUPADO CON CENTRADO AL CLUSTER, ESTRUCTURA DE C1"
    display "{hline 78}"

    use "Base_C2.dta", clear

    timer on 2
    mi estimate, dots post: mixed punt_global cwc_inse c_inse_prom_sede   ///
        $v_n1 $v_n2 indice_vuln ib2018.year                              ///
        || mcpio_id: || mcpio_id: R.year || sede_id: || sede_anio: , reml
    timer off 2
    estimates save "M3cwc_pool.ster", replace

    display _newline "--- beta_c agrupado = beta_b - beta_w ---"
    lincom c_inse_prom_sede - cwc_inse

    display _newline "--- Contraste de igualdad entre dentro y entre ---"
    test cwc_inse = c_inse_prom_sede

    display _newline "--- Tiempo del bloque [1] ---"
    timer list 2
}


********************************************************************************
* [2] MEDIA PERMANENTE DE LA SEDE FRENTE A DESVIACION DE CADA COHORTE
********************************************************************************
* Es la prueba decisiva de C2. Si lo que predice el puntaje es la componente
* permanente y no la desviacion anual, lo que distingue a las sedes de mayor
* nivel socioeconomico es una diferencia persistente entre ellas, compatible
* con seleccion y con calidad, y no el cambio de composicion de una cohorte a
* otra (logica de Hoxby, 2000).

if `hacer_permdev' == 1 {

    display _newline "{hline 78}"
    display "[2] COMPONENTE PERMANENTE FRENTE A DESVIACION DE COHORTE"
    display "{hline 78}"

    use "Base_C2.dta", clear

    timer on 3
    mi estimate, dots post: mixed punt_global cwc_inse inse_sede_perm     ///
        inse_sede_dev $v_n1 $v_n2 indice_vuln ib2018.year                ///
        || mcpio_id: || mcpio_id: R.year || sede_id: || sede_anio: , reml
    timer off 3
    estimates save "M3cwc_perm_dev.ster", replace

    display _newline "--- Anade la composicion de la cohorte por encima del individuo? ---"
    test inse_sede_dev = cwc_inse
    lincom inse_sede_dev - cwc_inse

    display _newline "--- Es la componente permanente distinta de la de cohorte? ---"
    test inse_sede_perm = inse_sede_dev
    lincom inse_sede_perm - inse_sede_dev

    display _newline "--- Componente permanente frente al efecto dentro ---"
    lincom inse_sede_perm - cwc_inse

    display _newline "Nota: los contrastes son de Wald. Los modelos [1] y [2] NO"
    display "son comparables por razon de verosimilitudes, porque REML con"
    display "distintos efectos fijos no admite esa comparacion."

    display _newline "--- Tiempo del bloque [2] ---"
    timer list 3
}


********************************************************************************
* [3] EFECTOS FIJOS DE SEDE: LA MEDIA SE IDENTIFICA SOLO ENTRE COHORTES
********************************************************************************
* Con efecto fijo de sede, el coeficiente de inse_prom_sede se identifica
* exclusivamente con la variacion de la media entre cohortes de una misma sede,
* que es lo mismo que mide inse_sede_dev en el bloque [2]. Sirve de
* verificacion sin supuestos distribucionales sobre el intercepto de sede.
*
* `cmdok` se incluye por si areg no esta en la lista de comandos oficialmente
* soportados por mi estimate; es inocuo si si lo esta.

if `hacer_fe' == 1 {

    display _newline "{hline 78}"
    display "[3] EFECTOS FIJOS DE SEDE"
    display "{hline 78}"

    use "Base_C2.dta", clear

    mi estimate, dots post cmdok: areg punt_global cwc_inse inse_prom_sede ///
        $v_n1 $v_n2_fe ib2018.year,                                        ///
        absorb(sede_id) vce(cluster sede_id)
    estimates save "M3cwc_fe_sede.ster", replace

    display _newline "--- Composicion de cohorte frente a efecto dentro, con EF de sede ---"
    lincom inse_prom_sede - cwc_inse

    display _newline "rural, cole_femenino, tecnico y tecnico_academico quedan"
    display "fuera a proposito: no varian dentro de la sede y las absorbe el"
    display "efecto fijo. inse_prom_sede entra en metrica bruta porque, con"
    display "efecto fijo de sede, centrarla solo moveria el intercepto."
}


********************************************************************************
* [4] CONFIABILIDAD DE LA MEDIA DE COHORTE
********************************************************************************
* ATENCION: este bloque NO entrega la rho del bloque [5]. Lo que `loneway`
* reporta es la confiabilidad de la MEDIA del grupo, que es la cantidad que
* atenua beta_b y que resulta ser alta. La confiabilidad del INSE INDIVIDUAL,
* que es la que atenua beta_w, no se puede estimar con estos datos y entra en
* el bloque [5] como supuesto declarado.

if `hacer_conf' == 1 {

    display _newline "{hline 78}"
    display "[4] CONFIABILIDAD DE LA MEDIA DE COHORTE"
    display "{hline 78}"

    use "Base_Multinivel_PCA.dta", clear
    capture drop sede_anio
    egen long sede_anio = group(cole_cod_dane_sede year)

    forvalues a = 2018/2023 {
        display _newline "--- Confiabilidad de la media de cohorte, `a' ---"
        capture noisily loneway estu_inse_individual sede_anio if year == `a'
        if _rc != 0 {
            display as error "loneway fallo en `a' (codigo " _rc ")."
            display "Alternativa: mixed estu_inse_individual if year == `a'"
            display "|| sede_anio: , mle  y lambda = n*icc / (1 + (n-1)*icc)."
        }
    }
}


********************************************************************************
* [5] COTA POR ERROR DE MEDIDA DEL INSE INDIVIDUAL Y ESTANDARIZACION
********************************************************************************
* El error de medida del INSE es individual, de modo que se concentra en la
* parte dentro de la sede: la media de la cohorte lo promedia sobre unos 29
* estudiantes y queda practicamente limpia. De ahi que beta_w se atenue mucho
* mas que beta_b y que beta_c se infle por los dos lados a la vez, que es el
* efecto fantasma de Televantou et al. (2015).
*
*   lambda_w = 1 - (1 - rho) * Var(c_inse) / Var(cwc_inse)
*   beta_w corregido = beta_w / lambda_w
*
* rho es un SUPUESTO. Si el ICFES no publica la confiabilidad del indice, se
* reporta como rango declarado y asi se escribe en el documento.

if `hacer_medida' == 1 {

    display _newline "{hline 78}"
    display "[5] ERROR DE MEDIDA Y ESTANDARIZACION, POR COHORTE"
    display "{hline 78}"

    use "Base_C2.dta", clear

    forvalues a = 2018/2023 {

        quietly summarize c_inse if _mi_m == 1 & year == `a'
        scalar v_tot = r(Var)
        quietly summarize cwc_inse if _mi_m == 1 & year == `a'
        scalar v_w  = r(Var)
        scalar sd_w = r(sd)
        quietly summarize c_inse_prom_sede if _mi_m == 1 & year == `a'
        scalar sd_b = r(sd)

        capture quietly estimates use "M3cwc_`a'.ster"
        if _rc != 0 {
            display as error "Falta M3cwc_`a'.ster. Correr el bloque [3] del 08."
            continue
        }
        scalar bw = _b[cwc_inse]
        scalar bb = _b[c_inse_prom_sede]

        display _newline "Cohorte `a'"
        display "  beta_w = " %6.4f (bw) "   beta_b = " %6.4f (bb) ///
                "   beta_c = " %6.4f (bb - bw)
        display "  Por DE:  beta_w x " %5.3f (sd_w) " = " %6.3f (bw*sd_w) ///
                "    beta_b x " %5.3f (sd_b) " = " %6.3f (bb*sd_b)
        display "  Razon por unidad = " %5.2f (bb/bw) ///
                "   Razon por DE = " %5.2f ((bb*sd_b)/(bw*sd_w))

        foreach rho in 0.7 0.8 0.9 {
            scalar lam = 1 - (1 - `rho') * v_tot / v_w
            display "  rho = `rho': lambda_w = " %5.3f (lam) ///
                "   beta_w corregido = " %6.3f (bw/lam) ///
                "   beta_b = " %6.3f (bb)
        }
    }

    display _newline "Nota: beta_b tambien esta atenuado, por un factor del orden"
    display "de 1 - (1-rho)*Var(c_inse) / (n*Var(c_inse_prom_sede)), con n"
    display "cercano a 29. Es del 1 al 2 por ciento y la correccion lo ignora,"
    display "de modo que el ejercicio es conservador respecto de la brecha."
}


********************************************************************************
* CIERRE
********************************************************************************

timer off 1
display _newline "--- Tiempo total de ejecucion ---"
timer list 1

display _newline "{hline 78}"
display "BLOQUE C2 COMPLETADO."
display "Siguiente: 10_blindaje.do bloque [6] y retirada del Anexo F.6."
display "{hline 78}"

log close fase12

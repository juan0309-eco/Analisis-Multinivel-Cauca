********************************************************************************
* PROYECTO : Desempeño Saber 11 en sedes oficiales del Cauca, 2018-2023
*            Modelo multinivel de 3 niveles (estudiante / sede / municipio)
* SCRIPT   : 01 - FASE 1. DEPURACIÓN DE MICRODATOS ICFES (NIVEL 1)
* SALIDA   : N1_Saber11_2018_2023.dta  (pool de cortes transversales repetidos)
* STATA    : 17
* VERSIÓN  : 2 - el INSE se conserva CRUDO en toda la depuración
********************************************************************************
* NOTA DE DISEÑO
* Esta NO es una base panel de individuos. Son cortes transversales repetidos:
* cada año contiene una cohorte distinta de estudiantes. Por eso no se declara
* xtset a nivel de estudiante ni se usan operadores de rezago sobre las filas
* individuales. Las únicas llaves que deben sobrevivir a esta fase son:
*   - cole_cod_dane_sede          (string, %20.0f)  -> encadena con Nivel 2
*   - cole_cod_mcpio_ubicacion    (numérica)        -> encadena con Nivel 3
*   - year                        (numérica)        -> encadena con ambos
*
* TRATAMIENTO DEL INSE
* estu_inse_individual queda en sus unidades originales. Ni el centrado en la
* gran media ni el centrado al clúster se aplican aquí: son transformaciones
* de estimación, no de depuración, y hacerlas ahora impediría reportar los
* descriptivos del Objetivo 1 en la escala real del índice. Ambas quedan para
* el do-file de estimación, después de la imputación múltiple.
********************************************************************************

clear all
set more off
set varabbrev off
version 17

if "$TESIS_CONFIG" == "" do "C:\Users\RYZEN 5\Desktop\Tesis Multinivel\Definitivo\00_config.do"
cd "$RAIZ"

capture log close _all
local tarea "01_depuracion_N1"
local hoy   "20261024"          // <<< etiqueta de la proxima corrida

capture confirm file "log_`tarea'_`hoy'.log"
if _rc == 0 {
    display as error "Ya existe log_`tarea'_`hoy'.log."
    display as error "Cambiar el local hoy (por ejemplo, anadir un sufijo b, c...)."
    exit 602
}
log using "log_`tarea'_`hoy'.log", text name(fase1)

* Fechas reales de aplicación de Saber 11, calendario A (semestre 2)
local fecha2018 "12 08 2018"
local fecha2019 "11 08 2019"
local fecha2020 "15 11 2020"
local fecha2021 "22 08 2021"
local fecha2022 "04 09 2022"
local fecha2023 "13 08 2023"

* Variables que deben existir en cada archivo anual.
local vars_llave    periodo estu_consecutivo cole_cod_dane_sede               ///
                    cole_cod_dane_establecimiento cole_cod_mcpio_ubicacion    ///
                    cole_cod_depto_ubicacion cole_mcpio_ubicacion             ///
                    cole_nombre_sede cole_sede_principal cole_codigo_icfes

local vars_filtro   cole_calendario cole_naturaleza cole_jornada estu_grado   ///
                    estu_discapacidad estu_agregado estu_estudiante           ///
                    estu_privado_libertad estu_fechanacimiento

local vars_result   punt_global punt_matematicas punt_lectura_critica         ///
                    punt_c_naturales punt_sociales_ciudadanas punt_ingles

local vars_n1       estu_genero estu_inse_individual estu_nse_individual      ///
                    estu_horassemanatrabaja estu_dedicacionlecturadiaria      ///
                    fami_numlibros fami_tieneinternet fami_tienecomputador    ///
                    fami_educacionmadre fami_educacionpadre                   ///
                    fami_estratovivienda fami_personashogar                   ///
                    fami_cuartoshogar estu_repite

local vars_n2icfes  cole_area_ubicacion cole_caracter cole_genero             ///
                    estu_nse_establecimiento

local vars_todas    `vars_llave' `vars_filtro' `vars_result' `vars_n1' `vars_n2icfes'


********************************************************************************
* BUCLE ANUAL DE DEPURACIÓN
********************************************************************************

foreach y in 2018 2019 2020 2021 2022 2023 {

    display _newline(2)
    display "{hline 78}"
    display "PROCESANDO AÑO `y'"
    display "{hline 78}"

    * ------------------------------------------------------------------
    * [1] IMPORTACIÓN
    * ------------------------------------------------------------------
    capture noisily import delimited "Examen_Saber_11_`y'2.txt", ///
        delimiter(";") varnames(1) stringcols(_all) encoding("UTF-8") clear

    if _rc != 0 {
        display as error "No se pudo leer Examen_Saber_11_`y'2.txt. Año omitido."
        continue
    }

    quietly count
    local n_bruto = r(N)
    display "Registros en el archivo bruto: `n_bruto'"

    * ------------------------------------------------------------------
    * [2] VERIFICACIÓN DE PRESENCIA DE VARIABLES
    * ------------------------------------------------------------------
    foreach v of local vars_todas {
        capture confirm variable `v'
        if _rc != 0 {
            display as error "  AVISO: la variable `v' NO existe en `y'. Se crea vacía."
            quietly generate str1 `v' = ""
        }
    }

    keep `vars_todas'

    * ------------------------------------------------------------------
    * [3] NORMALIZACIÓN DE CADENAS (mayúsculas, espacios y acentos)
    * ------------------------------------------------------------------
    quietly ds, has(type string)
    local strvars `r(varlist)'

    foreach v of local strvars {
        quietly replace `v' = trim(itrim(upper(`v')))
        quietly replace `v' = "" if inlist(`v', ".", "NA", "N/A", "NULL")
        foreach par in "Á A" "É E" "Í I" "Ó O" "Ú U" "Ü U" "Ñ N" {
            local orig : word 1 of `par'
            local dest : word 2 of `par'
            quietly replace `v' = subinstr(`v', "`orig'", "`dest'", .)
        }
    }

    * ------------------------------------------------------------------
    * [4] TIPADO DE LLAVES Y CONVERSIÓN NUMÉRICA
    * ------------------------------------------------------------------
    quietly replace cole_cod_dane_sede = subinstr(cole_cod_dane_sede, ".0", "", .) ///
        if strpos(cole_cod_dane_sede, ".0") == strlen(cole_cod_dane_sede) - 1
    quietly replace cole_cod_dane_sede = trim(cole_cod_dane_sede)

    quietly destring cole_cod_mcpio_ubicacion cole_cod_depto_ubicacion ///
        cole_cod_dane_establecimiento cole_codigo_icfes, replace force

    quietly destring `vars_result' estu_inse_individual estu_nse_establecimiento ///
        estu_grado estu_repite periodo, replace force

    generate int year = `y'
    label variable year "Año de presentación de la prueba"

    * ------------------------------------------------------------------
    * [5] EMBUDO DE FILTROS - se reporta el efecto de cada uno
    * ------------------------------------------------------------------
    display _newline "--- EMBUDO DE FILTROS, AÑO `y' ---"
    local n_prev = _N

    * (5.1) Departamento del Cauca (código DANE 19)
    quietly drop if cole_cod_depto_ubicacion != 19
    display "  Fuera del Cauca (depto != 19) ..... removidos: " `n_prev' - _N
    local n_prev = _N

    * (5.2) Calendario A
    tabulate cole_calendario, missing
    quietly keep if cole_calendario == "A"
    display "  Calendario distinto de A .......... removidos: " `n_prev' - _N
    local n_prev = _N

    * (5.3) Naturaleza oficial
    quietly keep if cole_naturaleza == "OFICIAL"
    display "  Sector no oficial ................. removidos: " `n_prev' - _N
    local n_prev = _N

    * (5.4) Jornadas diurnas regulares.
    *       Se excluyen NOCHE y SABATINA: educación de adultos y por
    *       flexibilización, con lógica institucional distinta al bachillerato
    *       regular. También se pierden aquí los registros con jornada vacía.
    tabulate cole_jornada, missing
    quietly keep if inlist(cole_jornada, "UNICA", "MANANA", "TARDE", "COMPLETA")
    display "  Jornada NOCHE / SABATINA / vacía .. removidos: " `n_prev' - _N
    local n_prev = _N

    * (5.5) Grado 11
    quietly keep if estu_grado == 11
    display "  Grado distinto de 11 .............. removidos: " `n_prev' - _N
    local n_prev = _N

    * (5.6) Marca oficial de agregado del ICFES.
    *       DECISIÓN CERRADA: se activa. Deja solo a los estudiantes que el
    *       ICFES imputa a la cohorte del colegio en el informe nacional, que
    *       es la población sobre la que se define el Nivel 2.
    *       Se tabula ANTES de filtrar para distinguir los "N" reales de las
    *       celdas vacías: ambos se van con el keep, pero no son lo mismo.
    tabulate estu_agregado, missing
    quietly keep if estu_agregado == "S"
    display "  estu_agregado != S ................ removidos: " `n_prev' - _N
    local n_prev = _N

    * (5.7) Privados de la libertad
    quietly drop if estu_privado_libertad == "S"
    display "  Privados de la libertad ........... removidos: " `n_prev' - _N
    local n_prev = _N

    * (5.8) Condición de discapacidad.
    *       La prueba se aplica con ajustes razonables y los puntajes no son
    *       estrictamente comparables. Se tabula antes para dejar constancia
    *       de la distribución del año.
    tabulate estu_discapacidad, missing
    quietly keep if estu_discapacidad == "N"
    display "  Discapacidad declarada / vacía .... removidos: " `n_prev' - _N
    local n_prev = _N

    * (5.9) Integridad de llaves y del resultado
    quietly drop if missing(cole_cod_dane_sede) | cole_cod_dane_sede == ""
    quietly drop if missing(cole_cod_mcpio_ubicacion)
    quietly drop if missing(estu_consecutivo) | estu_consecutivo == ""
    quietly drop if missing(punt_global)
    display "  Llaves o punt_global vacíos ....... removidos: " `n_prev' - _N
    local n_prev = _N

    * (5.10) Exámenes anulados o incompletos.
    *        Un cero en cualquiera de las cuatro áreas de escala 0-100 es
    *        estructuralmente imposible en una prueba efectivamente presentada.
    *        INGLÉS QUEDA FUERA DE LA REGLA: allí el -1, no el 0, marca
    *        "no contestó ninguna pregunta".
    generate byte anulado = (punt_matematicas == 0 | punt_lectura_critica == 0 | ///
                             punt_c_naturales == 0 | punt_sociales_ciudadanas == 0)
    quietly count if anulado == 1
    display "  Exámenes anulados (subpuntaje 0) ... detectados: " r(N)
    quietly drop if anulado == 1
    drop anulado
    local n_prev = _N

    * (5.11) Duplicados de estudiante dentro del mismo año
    quietly duplicates tag estu_consecutivo, generate(_dup)
    quietly count if _dup > 0
    display "  Registros con estu_consecutivo repetido: " r(N)
    quietly duplicates drop estu_consecutivo, force
    capture drop _dup
    local n_prev = _N

    * ------------------------------------------------------------------
    * [6] EDAD AL MOMENTO DEL EXAMEN
    * ------------------------------------------------------------------
    local dd : word 1 of `fecha`y''
    local mm : word 2 of `fecha`y''
    local aa : word 3 of `fecha`y''

    generate double fecnac = date(estu_fechanacimiento, "DMY")
    format fecnac %td
    quietly count if missing(fecnac)
    display "  Fecha de nacimiento ilegible ...... casos: " r(N)

    generate double fec_examen = mdy(`mm', `dd', `aa')
    format fec_examen %td
    label variable fec_examen "Fecha de aplicación Saber 11"

    generate byte edad = floor((fec_examen - fecnac) / 365.25)
    label variable edad "Edad cumplida al momento del examen"

    quietly count if !inrange(edad, 15, 21)
    display "  Edad fuera del rango 15-21 ........ removidos: " r(N)
    quietly keep if inrange(edad, 15, 21)

    drop fecnac

    * ------------------------------------------------------------------
    * [7] VARIABLE DEPENDIENTE Y PUNTAJES POR ÁREA
    * ------------------------------------------------------------------
    label variable punt_global              "Puntaje global Saber 11"
    label variable punt_matematicas         "Puntaje matemáticas"
    label variable punt_lectura_critica     "Puntaje lectura crítica"
    label variable punt_c_naturales         "Puntaje ciencias naturales"
    label variable punt_sociales_ciudadanas "Puntaje sociales y ciudadanas"

    quietly replace punt_ingles = . if punt_ingles == -1
    label variable punt_ingles "Puntaje inglés (-1 recodificado a missing)"

    * ------------------------------------------------------------------
    * [8] RECODIFICACIÓN DE VARIABLES DE NIVEL 1
    * ------------------------------------------------------------------
    * REGLA GENERAL: los vacíos se conservan como missing verdadero. No se
    * imputa nada aquí; MICE es un paso posterior y necesita ver el patrón
    * de faltantes intacto. Cada variable recodificada lleva su bandera _miss.

    * (8.1) Sexo
    generate byte mujer_miss = missing(estu_genero) | estu_genero == ""
    generate byte mujer = (estu_genero == "F") if mujer_miss == 0
    label variable mujer "Mujer (1 = sí)"

    * (8.2) INSE individual - SE CONSERVA CRUDO.
    *       Solo se limpian los valores imposibles (negativos). El índice queda
    *       en su escala original para los descriptivos del Objetivo 1. Las
    *       transformaciones (centrado en la gran media y al clúster) se
    *       aplican en el do-file de estimación.
    quietly replace estu_inse_individual = . if estu_inse_individual < 0
    generate byte inse_miss = missing(estu_inse_individual)
    label variable estu_inse_individual "INSE individual (escala original ICFES)"
    label variable inse_miss "INSE individual faltante (1 = sí)"

    * (8.3) Trabajo intensivo (más de 20 horas semanales)
    generate byte trabaja_mas20_miss = missing(estu_horassemanatrabaja) | ///
                                       estu_horassemanatrabaja == ""
    generate byte trabaja_mas20 = inlist(estu_horassemanatrabaja,        ///
        "ENTRE 21 Y 30 HORAS", "MAS DE 30 HORAS") if trabaja_mas20_miss == 0
    label variable trabaja_mas20 "Trabaja más de 20 horas por semana (1 = sí)"

    * (8.4) Lectura diaria por entretenimiento (más de 30 minutos)
    generate byte lectura_30min_miss = missing(estu_dedicacionlecturadiaria) | ///
                                       estu_dedicacionlecturadiaria == ""
    generate byte lectura_30min = inlist(estu_dedicacionlecturadiaria,   ///
        "ENTRE 30 Y 60 MINUTOS", "ENTRE 1 Y 2 HORAS", "MAS DE 2 HORAS")  ///
        if lectura_30min_miss == 0
    label variable lectura_30min "Lee más de 30 minutos diarios (1 = sí)"

    * (8.5) Libros en el hogar (26 o más)
    generate byte libros_26omas_miss = missing(fami_numlibros) | fami_numlibros == ""
    generate byte libros_26omas = inlist(fami_numlibros,                 ///
        "26 A 100 LIBROS", "MAS DE 100 LIBROS") if libros_26omas_miss == 0
    label variable libros_26omas "26 o más libros en el hogar (1 = sí)"

    * (8.6) Internet y computador en el hogar
    generate byte internet_miss = missing(fami_tieneinternet) | fami_tieneinternet == ""
    generate byte internet_hogar = (fami_tieneinternet == "SI") if internet_miss == 0
    label variable internet_hogar "Internet en el hogar (1 = sí)"

    generate byte compu_miss = missing(fami_tienecomputador) | fami_tienecomputador == ""
    generate byte computador_hogar = (fami_tienecomputador == "SI") if compu_miss == 0
    label variable computador_hogar "Computador en el hogar (1 = sí)"

    * (8.7) Repitencia de la prueba.
    *       DECISIÓN CERRADA: los repitentes NO se excluyen. Entran como
    *       control de Nivel 1.
    generate byte repitente = (estu_repite != 0 & !missing(estu_repite))
    label variable repitente "Ha presentado Saber 11 en más de un periodo (1 = sí)"

    * (8.8) Variables auxiliares del hogar (descriptivos e insumos de MICE)
    generate byte educ_madre_sup_miss = missing(fami_educacionmadre) | ///
                                        fami_educacionmadre == ""
    generate byte educ_madre_sup = inlist(fami_educacionmadre,           ///
        "TECNICA O TECNOLOGICA COMPLETA", "EDUCACION PROFESIONAL COMPLETA", ///
        "POSTGRADO") if educ_madre_sup_miss == 0
    label variable educ_madre_sup "Madre con educación superior completa (1 = sí)"

    generate byte educ_padre_sup_miss = missing(fami_educacionpadre) | ///
                                        fami_educacionpadre == ""
    generate byte educ_padre_sup = inlist(fami_educacionpadre,           ///
        "TECNICA O TECNOLOGICA COMPLETA", "EDUCACION PROFESIONAL COMPLETA", ///
        "POSTGRADO") if educ_padre_sup_miss == 0
    label variable educ_padre_sup "Padre con educación superior completa (1 = sí)"

    generate byte estrato = real(subinstr(fami_estratovivienda, "ESTRATO ", "", .))
    quietly replace estrato = 0 if fami_estratovivienda == "SIN ESTRATO"
    label variable estrato "Estrato de la vivienda (0 = sin estrato)"

    * ------------------------------------------------------------------
    * [9] ATRIBUTOS DE SEDE DE ORIGEN ICFES (insumos del Nivel 2)
    * ------------------------------------------------------------------
    * Se generan a nivel de estudiante; la consolidación a sede-año va en Fase 2.
    generate byte rural = (cole_area_ubicacion == "RURAL") ///
        if !missing(cole_area_ubicacion) & cole_area_ubicacion != ""
    label variable rural "Sede rural (1 = sí)"

    generate byte ju_unica    = (cole_jornada == "UNICA")
    generate byte ju_completa = (cole_jornada == "COMPLETA")
    label variable ju_unica    "Jornada única (1 = sí)"
    label variable ju_completa "Jornada completa (1 = sí)"

    generate byte tecnico = (cole_caracter == "TECNICO") ///
        if !missing(cole_caracter) & cole_caracter != ""
    generate byte mixto = (cole_caracter == "TECNICO/ACADEMICO") ///
        if !missing(cole_caracter) & cole_caracter != ""
    label variable tecnico "Sede de carácter técnico (1 = sí)"
    label variable mixto   "Sede de carácter técnico/académico (1 = sí)"

    generate byte cole_femenino  = (cole_genero == "FEMENINO")  if cole_genero != ""
    generate byte cole_masculino = (cole_genero == "MASCULINO") if cole_genero != ""
    label variable cole_femenino  "Sede exclusivamente femenina (1 = sí)"
    label variable cole_masculino "Sede exclusivamente masculina (1 = sí)"

    generate byte sede_principal = (cole_sede_principal == "S") ///
        if cole_sede_principal != ""
    label variable sede_principal "Sede principal del establecimiento (1 = sí)"

    * ------------------------------------------------------------------
    * [10] CIERRE DEL AÑO
    * ------------------------------------------------------------------
    quietly count
    display _newline "RESULTADO AÑO `y': " r(N) " estudiantes (de `n_bruto' brutos)"

    quietly egen byte _tag = tag(cole_cod_dane_sede)
    quietly count if _tag == 1
    display "                  " r(N) " sedes distintas"
    drop _tag

    quietly egen byte _tag = tag(cole_cod_mcpio_ubicacion)
    quietly count if _tag == 1
    display "                  " r(N) " municipios distintos"
    drop _tag

    compress
    save "N1_saber11_`y'.dta", replace
}


********************************************************************************
* CONSOLIDACIÓN DEL POOL 2018-2023
********************************************************************************

display _newline(2)
display "{hline 78}"
display "CONSOLIDANDO EL POOL DE CORTES TRANSVERSALES REPETIDOS"
display "{hline 78}"

use "N1_saber11_2018.dta", clear
foreach y in 2019 2020 2021 2022 2023 {
    append using "N1_saber11_`y'.dta"
}

* ----------------------------------------------------------------------
* [11] AGREGADOS DE COHORTE POR SEDE-AÑO (EN ESCALA ORIGINAL DEL INSE)
* ----------------------------------------------------------------------
* Se agrupa por sede Y AÑO. Agrupar solo por sede mezclaría seis cohortes
* distintas en un mismo promedio. El promedio se calcula sobre el INSE crudo,
* de modo que queda expresado en la misma escala que la variable individual y
* es directamente reportable en la tabla de descriptivos.
bysort cole_cod_dane_sede year: egen double inse_prom_sede = ///
    mean(estu_inse_individual)
label variable inse_prom_sede "INSE promedio de la cohorte (sede-año, escala original)"

* OJO: cuenta a los estudiantes que sobrevivieron a todos los filtros, no al
* total de inscritos en la sede. Es el tamaño de la cohorte ANALÍTICA.
bysort cole_cod_dane_sede year: egen int evaluados_sede = count(punt_global)
label variable evaluados_sede "Estudiantes evaluados en la sede-año (muestra analítica)"

* ----------------------------------------------------------------------
* [12] PANEL DE CONTROL DE LA FASE 1
* ----------------------------------------------------------------------
display _newline "--- CONTEO FINAL POR AÑO ---"
tabulate year, missing

egen byte tag_sede  = tag(cole_cod_dane_sede year)
egen byte tag_mcpio = tag(cole_cod_mcpio_ubicacion year)

display _newline "--- SEDES-AÑO Y MUNICIPIOS-AÑO ---"
tabulate year if tag_sede == 1
tabulate year if tag_mcpio == 1

display _newline "--- VARIABLE DEPENDIENTE ---"
tabstat punt_global, by(year) stat(n mean sd min max) format(%9.2f)

display _newline "--- INSE INDIVIDUAL EN ESCALA ORIGINAL (insumo del Objetivo 1) ---"
tabstat estu_inse_individual, by(year) stat(n mean sd p25 p50 p75 min max) ///
        format(%9.2f)

display _newline "--- INSE PROMEDIO DE LA SEDE (sede-año) ---"
tabstat inse_prom_sede if tag_sede == 1, by(year) stat(n mean sd min max) ///
        format(%9.2f)

display _newline "--- VALORES PERDIDOS EN NIVEL 1 (antes de MICE) ---"
tabstat mujer_miss inse_miss trabaja_mas20_miss lectura_30min_miss ///
        libros_26omas_miss internet_miss compu_miss, ///
        by(year) stat(mean) format(%9.4f)

display _newline "--- VERIFICACIÓN DE LLAVES ---"
codebook cole_cod_dane_sede cole_cod_mcpio_ubicacion year, compact
assert !missing(cole_cod_mcpio_ubicacion)
assert cole_cod_dane_sede != ""
assert inrange(year, 2018, 2023)
display "Llaves verificadas: sin vacíos, tipos correctos."

* Comprobación explícita de que el INSE NO quedó centrado.
quietly summarize estu_inse_individual, meanonly
display "Media del INSE en el pool (debe ser distinta de 0): " %6.2f r(mean)
assert abs(r(mean)) > 1
display "Confirmado: el INSE se conserva en escala original."

* ----------------------------------------------------------------------
* [13] GUARDADO
* ----------------------------------------------------------------------
order estu_consecutivo cole_cod_dane_sede cole_cod_mcpio_ubicacion year ///
      punt_global mujer edad estu_inse_individual

compress
save "N1_Saber11_2018_2023.dta", replace

display _newline "{hline 78}"
display "FASE 1 COMPLETADA. Base de Nivel 1 lista: N1_Saber11_2018_2023.dta"
display "El INSE queda crudo; el centrado se aplica en el do-file de estimación."
display "{hline 78}"

log close fase1

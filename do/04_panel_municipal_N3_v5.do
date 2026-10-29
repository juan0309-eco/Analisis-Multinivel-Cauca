********************************************************************************
* PROYECTO : Desempeño Saber 11 en sedes oficiales del Cauca, 2018-2023
* SCRIPT   : 04 - FASE 4. PANEL MUNICIPAL (NIVEL 3)
* ENTRADA  : IPC anual desde el año 1955 a 2025.xlsx
*            Panel_homicidios.xlsx, Hectareas Coca.xlsx
*            Panel_inversion.xlsx  (hojas Panel_inversion y Panel_caracterizacion)
* SALIDA   : N3_Municipios_2018_2023.dta
* STATA    : 17
* VERSIÓN  : 5 - añade la tasa de homicidios suavizada por Bayes empírico (C7)
*                y el log deja de llevar `replace`
********************************************************************************
* QUÉ CAMBIA RESPECTO DE LA VERSIÓN 4
*
* 1. El bloque [2] construye `tasa_hom_eb`, la tasa de homicidios suavizada por
*    el estimador global de Bayes empírico (Marshall, 1991). Motivo: 85
*    municipio-año registran entre uno y cinco homicidios y otros 29 registran
*    cero, de modo que 114 de 252 tienen cinco o menos. En esos casos un solo
*    caso mueve la tasa varios puntos y buena parte de su variación temporal es
*    ruido de muestreo, que atenúa el coeficiente hacia cero. La corrección C7
*    pone esa explicación a prueba.
*
* 2. El log lleva fecha y NO lleva `replace`. El log de la versión 4,
*    `log_04_panel_municipal_N3.log`, respalda la Tabla 6, la Tabla 21 y el
*    Anexo F.5 del informe y debe conservarse intacto.
*
* QUÉ CAMBIABA LA VERSIÓN 4 RESPECTO DE LA 1
*
* La variable de inversión no era «la inversión pública municipal». El indicador
* extraído de TerriData es «Libre Inversión», que corresponde a la asignación
* del Sistema General de Participaciones al componente de propósito general en
* su rubro de libre inversión. No es la asignación educativa del SGP, y la
* mayoría de municipios del Cauca no están certificados en educación, de modo
* que el canal hacia los establecimientos es indirecto.
*
* Esta versión conserva esa variable como medida principal —mide precisamente
* los recursos discrecionales de que dispone el municipio para bienes públicos
* locales— pero incorpora cuatro medidas fiscales alternativas para probar si
* el resultado depende del componente específico elegido:
*
*   inv_fut       inversión efectivamente ejecutada, fuente FUT en vez de SICODIS
*   sgp_total     total asignado por el SGP, todos los componentes
*   sgp_pae       asignación especial de alimentación escolar
*   ing_trib_pc   ingresos tributarios per cápita, esfuerzo fiscal propio
*
* La última es la prueba más exigente: correlaciona 0,06 con la principal, de
* modo que mide capacidad fiscal por una vía completamente distinta.
*
* Se añade además una hoja de caracterización territorial que NO entra a los
* modelos. Cobertura, deserción, repitencia, tránsito a la superior, incidencia
* del conflicto y penetración de internet son resultados codeterminados con el
* desempeño; incluirlos como predictores contaminaría la estimación. Sirven
* para describir el contexto municipal en el capítulo de resultados.
*
* MATIZ QUE INTRODUCE C7: `iica` y `minas` NO son resultados educativos, de modo
* que sí pueden entrar a los modelos como indicadores adicionales de conflicto.
* `desercion_of` y `cob_neta_media` siguen fuera como predictores, pero la
* primera se emplea como variable DEPENDIENTE en la prueba del canal de
* deserción que sustituye al Anexo F.4.
*
* POR QUÉ LA COCA CAMBIA DE FUENTE
* El archivo propio `Hectareas Coca.xlsx` traía la columna como texto con
* formatos mezclados, y la conversión producía magnitudes inconsistentes: el
* mismo municipio-año aparecía dividido por mil en unas filas y multiplicado
* por diez en otras. La comprobación contra la serie de TerriData arrojó una
* correlación de 0,026 cuando debía ser cercana a uno, con los mismos dígitos
* en distinta posición decimal.
*
* Se adopta la serie de TerriData, que además cubre las 252 combinaciones de
* municipio y año en lugar de 186 y trae ceros explícitos donde no hay cultivo,
* en vez de ceros inferidos por ausencia de fila.
*
* ESTRUCTURA TEMPORAL
* Los paneles cubren 2017-2022 y se desplazan en +1 al final: una fila con
* year = 2018 contiene condiciones municipales de 2017. La deflactación se
* aplica ANTES del desplazamiento, sobre el año real del dato.
********************************************************************************

clear all
set more off
set varabbrev off
version 17

if "$TESIS_CONFIG" == "" do "C:\Users\RYZEN 5\Desktop\Tesis Multinivel\Definitivo\00_config.do"
cd "$RAIZ"

* ----------------------------------------------------------------------
* FECHA DE LAS SALIDAS. Cambiar en cada corrida nueva.
* El guard impide sobrescribir un log existente: es la lección del incidente
* del 13 de octubre, cuando un `log using ..., replace` destruyó la salida
* del bloque [7] del 10_blindaje.do.
* ----------------------------------------------------------------------
local hoy "20261019"

capture log close _all
capture confirm file "log_04_panel_municipal_N3_`hoy'.log"
if _rc == 0 {
    display as error "Ya existe log_04_panel_municipal_N3_`hoy'.log."
    display as error "Cambiar el local hoy antes de volver a correr."
    exit 602
}

log using "log_04_panel_municipal_N3_`hoy'.log", text name(fase4)


********************************************************************************
* [1] DEFLACTORES A PARTIR DEL IPC
********************************************************************************
* El archivo trae VARIACIONES anuales dic-dic en proporción, no el índice en
* nivel. Hay que encadenarlas y rebasar a 2018. Los encabezados están en la
* fila 4, con la columna A vacía, así que el import arranca en B4.

display _newline "{hline 78}"
display "[1] DEFLACTORES"
display "{hline 78}"

import excel "IPC anual desde el año 1955 a 2025.xlsx", ///
    sheet("IPC 1955 A 2025") cellrange(B4) firstrow clear

rename *, lower
quietly ds
local cols `r(varlist)'
local col_anio : word 1 of `cols'
local col_ipc  : word 2 of `cols'
rename `col_anio' year_dato
rename `col_ipc'  ipc_var

quietly destring year_dato ipc_var, replace force
quietly drop if missing(year_dato) | missing(ipc_var)

quietly summarize ipc_var
display "Variación media del IPC: " %8.5f r(mean)
if r(mean) > 0.5 {
    display as error "AVISO: la serie parece venir en PORCENTAJE, no en proporción."
}

sort year_dato
generate double ipc_indice = 1 in 1
quietly replace ipc_indice = ipc_indice[_n-1] * (1 + ipc_var) in 2/l

quietly summarize ipc_indice if year_dato == 2018
quietly replace ipc_indice = ipc_indice / r(mean)

generate double deflactor = 1 / ipc_indice
label variable deflactor "Deflactor a pesos constantes de 2018"

display _newline "  Año   Índice(2018=1)   Deflactor"
forvalues y = 2017/2022 {
    quietly summarize ipc_indice if year_dato == `y', meanonly
    local i = r(mean)
    quietly summarize deflactor if year_dato == `y', meanonly
    display "  `y'      " %10.5f `i' "     " %9.5f r(mean)
}

quietly summarize ipc_indice if year_dato == 2017, meanonly
scalar i2017 = r(mean)
quietly summarize ipc_indice if year_dato == 2022, meanonly
display _newline "Inflación acumulada 2017-2022: " %6.2f 100*(r(mean)/i2017 - 1) "%"

keep year_dato deflactor ipc_indice
quietly keep if inrange(year_dato, 2017, 2022)
isid year_dato
tempfile deflactores
save `deflactores', replace


********************************************************************************
* [2] PANEL DE HOMICIDIOS: EL MOLDE DE 42 MUNICIPIOS
********************************************************************************

display _newline "{hline 78}"
display "[2] PANEL DE HOMICIDIOS"
display "{hline 78}"

import excel "Panel_homicidios.xlsx", sheet("Panel_homicidios") firstrow clear
rename *, lower
capture rename homicidio homicidios
keep cole_cod_mcpio_ubicacion year homicidios pob
rename year year_dato
quietly destring cole_cod_mcpio_ubicacion year_dato homicidios pob, replace force

tabulate year_dato, missing

* Una celda vacía significa que el municipio no registró ningún caso ese año:
* el panel se construyó agregando registros individuales y un municipio-año
* sin registros no genera fila.
quietly count if missing(homicidios)
display _newline "Municipio-año con homicidios vacíos: " r(N) " -> se codifican como CERO"
quietly replace homicidios = 0 if missing(homicidios)

assert !missing(pob) & pob > 0

generate double tasa_homicidios = homicidios / pob * 100000
label variable tasa_homicidios "Tasa de homicidios por 100.000 habitantes (t-1)"
label variable homicidios      "Homicidios registrados (t-1)"
label variable pob             "Población municipal (t-1)"

tabstat tasa_homicidios homicidios pob, by(year_dato) ///
    stat(n mean sd p50 min max) format(%9.2f)

quietly count if homicidios <= 5 & homicidios > 0
display _newline "Municipio-año con 5 o menos homicidios: " r(N)


* ======================= PARCHE 1 DE C7 — INICIO ==============================
* [2.1] TASA SUAVIZADA POR BAYES EMPÍRICO (Marshall, 1991)
* ------------------------------------------------------------------------------
* Estimador global, calculado POR AÑO DEL DATO:
*   m    = tasa media del departamento ese año, ponderada por población
*   s2   = varianza entre municipios, descontada la varianza de muestreo
*   w_i  = s2 / (s2 + m/pob_i)        peso de la tasa cruda del municipio
*   EB_i = w_i*r_i + (1-w_i)*m        encogimiento hacia la media departamental
*
* Un municipio grande recibe w cercano a 1 y casi no se mueve; uno pequeño
* recibe w bajo y su tasa se acerca a la media del departamento. Es
* exactamente el ruido que la corrección C7 quiere separar de la señal.
*
* Va AQUÍ, antes del `tempfile molde`, para que la variable viaje al
* ensamblaje del bloque [6]. Y usa `year_dato` porque el desplazamiento a
* `year` todavía no ha ocurrido: eso pasa en el bloque [7].

display _newline "{hline 78}"
display "[2.1] TASA SUAVIZADA POR BAYES EMPÍRICO (C7)"
display "{hline 78}"

bysort year_dato: egen double _H = total(homicidios)
bysort year_dato: egen double _P = total(pob)
generate double _m = _H / _P
generate double _r = homicidios / pob
bysort year_dato: egen double _s2 = total(pob * (_r - _m)^2)
replace _s2 = _s2 / _P
bysort year_dato: egen double _pbar = mean(pob)
replace _s2 = max(_s2 - _m/_pbar, 0)
generate double _w = _s2 / (_s2 + _m/pob)
generate double tasa_hom_eb = 100000 * (_w*_r + (1 - _w)*_m)
label variable tasa_hom_eb "Tasa de homicidios suavizada (Bayes empírico) (t-1)"

* Estas cifras deciden la precondición P1 del criterio de C7 y hay que poder
* citarlas desde este log.
display _newline "--- Peso w por año: cuánto se encoge cada tasa ---"
tabstat _w, by(year_dato) stat(n mean sd min max) format(%9.4f)

display _newline "--- Municipios con mayor encogimiento (w más bajo) ---"
gsort _w
list cole_cod_mcpio_ubicacion year_dato pob homicidios tasa_homicidios ///
     tasa_hom_eb _w in 1/10, clean noobs
sort cole_cod_mcpio_ubicacion year_dato

display _newline "--- Tasa cruda frente a tasa suavizada, por año ---"
tabstat tasa_homicidios tasa_hom_eb, by(year_dato) ///
    stat(n mean sd p50 min max) format(%9.2f)

display _newline "--- Correlación entre las dos series ---"
correlate tasa_homicidios tasa_hom_eb

drop _H _P _m _r _s2 _pbar _w
* ======================== PARCHE 1 DE C7 — FIN ================================


isid cole_cod_mcpio_ubicacion year_dato
tempfile molde
save `molde', replace


********************************************************************************
* [4] VARIABLES FISCALES MUNICIPALES
********************************************************************************
* Todas provienen de TerriData del DNP, filtradas por municipios del Cauca,
* años 2017-2022 y corte de diciembre. Las de origen SGP vienen de SICODIS y
* las de operaciones efectivas de caja del FUT.

display _newline "{hline 78}"
display "[4] VARIABLES FISCALES"
display "{hline 78}"

import excel "Panel_inversion.xlsx", sheet("Panel_inversion") firstrow clear
rename *, lower
capture drop municipio
rename year year_dato

quietly destring cole_cod_mcpio_ubicacion year_dato inversion sgp_educacion ///
    sgp_pae sgp_total inv_fut ing_trib_pc transf_pc, replace force
quietly drop if missing(cole_cod_mcpio_ubicacion) | missing(year_dato)

label variable inversion     "SGP libre inversión, pesos corrientes"
label variable sgp_educacion "SGP educación, pesos corrientes"
label variable sgp_pae       "SGP alimentación escolar, pesos corrientes"
label variable sgp_total     "SGP total asignado, pesos corrientes"
label variable inv_fut       "Inversión ejecutada (FUT), pesos corrientes"
label variable ing_trib_pc   "Ingresos tributarios per cápita, pesos corrientes"
label variable transf_pc     "Transferencias nacionales per cápita, pesos corrientes"

display _newline "--- Variables fiscales en pesos corrientes ---"
tabstat inversion sgp_educacion sgp_pae sgp_total inv_fut, ///
    by(year_dato) stat(n mean p50) format(%15.0f)

display _newline "--- Correlaciones entre las medidas fiscales ---"
correlate inversion sgp_educacion sgp_pae sgp_total inv_fut ing_trib_pc transf_pc

display _newline "ADVERTENCIA sobre sgp_educacion: su rango va de 138 millones a"
display "161.076 millones porque Popayán está certificado en educación y recibe"
display "la asignación completa, mientras los municipios no certificados solo"
display "reciben el componente de calidad. NO debe usarse como predictor: el"
display "coeficiente compararía Popayán con el resto, no capacidad fiscal."

isid cole_cod_mcpio_ubicacion year_dato
tempfile fiscal
save `fiscal', replace


********************************************************************************
* [5] CARACTERIZACIÓN TERRITORIAL
********************************************************************************
* Cobertura, deserción, repitencia y tránsito a la educación superior son
* resultados educativos codeterminados con el puntaje; incluirlos como
* predictores contaminaría la estimación.
*
* MATIZ DE C7: `iica` y `minas` no son resultados educativos y sí pueden
* entrar a los modelos como indicadores adicionales de conflicto (apartado
* 3.4.4). `desercion_of` se emplea como variable DEPENDIENTE en la prueba del
* canal de deserción. `cob_neta_media` se cita como descriptiva de
* representatividad en el apartado 3.3.

display _newline "{hline 78}"
display "[5] CARACTERIZACIÓN TERRITORIAL"
display "{hline 78}"

import excel "Panel_inversion.xlsx", sheet("Panel_caracterizacion") firstrow clear
rename *, lower
capture drop municipio
rename year year_dato

quietly ds cole_cod_mcpio_ubicacion year_dato, not
quietly destring `r(varlist)' cole_cod_mcpio_ubicacion year_dato, replace force

label variable cob_neta_total   "Cobertura neta total (%)"
label variable cob_neta_media   "Cobertura neta en educación media (%)"
label variable cob_neta_secund  "Cobertura neta en secundaria (%)"
label variable cob_bruta_media  "Cobertura bruta en educación media (%)"
label variable desercion_of     "Deserción intra-anual, sector oficial (%)"
label variable repitencia_of    "Repitencia, sector oficial (%)"
label variable transito_sup     "Tránsito inmediato a educación superior (%)"
label variable iica             "Índice de Incidencia del Conflicto Armado"
label variable coca_terridata   "Hectáreas de coca según TerriData"
label variable minas            "Eventos de minas antipersonal"
label variable tasa_hom_td      "Tasa de homicidio intencional (TerriData)"
label variable internet_mcpio   "Penetración de acceso fijo a internet"
label variable pct_va_primario  "Valor agregado en actividades primarias (%)"
label variable fecundidad_10_19 "Tasa de fecundidad, mujeres de 10 a 19 años"

display _newline "--- Contexto educativo y territorial del municipio ---"
tabstat cob_neta_media desercion_of repitencia_of transito_sup ///
        iica internet_mcpio pct_va_primario, ///
    by(year_dato) stat(n mean sd) format(%9.2f)

* C7: cobertura de las cuatro variables que hasta ahora no se tabulaban.
* `, all` es obligatorio: sin él, misstable imprime SOLO las variables que
* tienen faltantes, y un bloque vacío no documenta cobertura.
display _newline "--- Cobertura de las variables territoriales (C7) ---"
misstable summarize iica minas tasa_hom_td desercion_of cob_neta_media, all

display _newline "--- Descriptivos de minas y de la tasa de TerriData ---"
tabstat minas tasa_hom_td, by(year_dato) ///
    stat(n mean sd p50 min max) format(%9.3f)

isid cole_cod_mcpio_ubicacion year_dato
tempfile carac
save `carac', replace


********************************************************************************
* [6] ENSAMBLAJE
********************************************************************************

display _newline "{hline 78}"
display "[6] ENSAMBLAJE DEL PANEL MUNICIPAL"
display "{hline 78}"

use `molde', clear

* --- Fiscales ---
merge 1:1 cole_cod_mcpio_ubicacion year_dato using `fiscal', ///
    keep(master match) generate(_m_fis)
tabulate _m_fis
assert _m_fis == 3
drop _m_fis

* --- Caracterización ---
merge 1:1 cole_cod_mcpio_ubicacion year_dato using `carac', ///
    keep(master match) generate(_m_car)
tabulate _m_car
assert _m_car == 3
drop _m_car

* --- Coca, tomada de TerriData ---
* La serie viene completa para las 252 observaciones y con ceros explícitos.
generate double coca = coca_terridata
label variable coca "Hectáreas de coca sembradas, TerriData (t-1)"

quietly count if missing(coca)
display _newline "Municipio-año sin dato de coca: " r(N) " (debe ser 0)"
assert !missing(coca)

quietly count if coca == 0
display "Municipio-año sin cultivo detectado (cero explícito): " r(N)

generate double ln_coca = ln(coca + 1)
label variable ln_coca "Log de hectáreas de coca, ln(coca+1) (t-1)"

display _newline "--- Hectáreas de coca por año ---"
tabstat coca ln_coca, by(year_dato) stat(n mean sd p50 max) format(%10.2f)

* --- Deflactación, sobre el año REAL del dato ---
merge m:1 year_dato using `deflactores', keep(master match) generate(_m_def)
assert _m_def == 3
drop _m_def

* Todas las variables monetarias pasan a pesos constantes de 2018.
foreach v in inversion sgp_educacion sgp_pae sgp_total inv_fut {
    generate double `v'_r = `v' * deflactor
}
foreach v in ing_trib_pc transf_pc {
    generate double `v'_r = `v' * deflactor
}

* --- Versiones per cápita ---
generate double inversion_pc = inversion_r     / pob
generate double sgp_pae_pc   = sgp_pae_r       / pob
generate double sgp_total_pc = sgp_total_r     / pob
generate double inv_fut_pc   = inv_fut_r       / pob

label variable inversion_pc "SGP libre inversión per cápita, pesos de 2018 (t-1)"
label variable sgp_pae_pc   "SGP alimentación escolar per cápita, pesos de 2018 (t-1)"
label variable sgp_total_pc "SGP total per cápita, pesos de 2018 (t-1)"
label variable inv_fut_pc   "Inversión ejecutada per cápita, pesos de 2018 (t-1)"
label variable ing_trib_pc_r "Ingresos tributarios per cápita, pesos de 2018 (t-1)"

* --- Logaritmos ---
foreach v in inversion_pc sgp_pae_pc sgp_total_pc inv_fut_pc {
    generate double ln_`v' = ln(`v') if `v' > 0
}
generate double ln_ing_trib_pc = ln(ing_trib_pc_r) if ing_trib_pc_r > 0

label variable ln_inversion_pc "Log de la asignación SGP de libre inversión per cápita (t-1)"
label variable ln_inv_fut_pc   "Log de la inversión ejecutada per cápita (t-1)"
label variable ln_sgp_total_pc "Log del SGP total per cápita (t-1)"
label variable ln_sgp_pae_pc   "Log del SGP de alimentación escolar per cápita (t-1)"
label variable ln_ing_trib_pc  "Log de los ingresos tributarios per cápita (t-1)"

display _newline "--- Efecto de la deflactación sobre la medida principal ---"
tabstat inversion inversion_r inversion_pc, by(year_dato) ///
    stat(n mean p50) format(%15.0f)

display _newline "--- Medidas fiscales per cápita en pesos de 2018 ---"
tabstat inversion_pc inv_fut_pc sgp_total_pc sgp_pae_pc ing_trib_pc_r, ///
    by(year_dato) stat(n mean sd) format(%12.1f)


********************************************************************************
* [7] DESPLAZAMIENTO TEMPORAL
********************************************************************************

display _newline "{hline 78}"
display "[7] REZAGO DE UN PERÍODO"
display "{hline 78}"

generate int year = year_dato + 1
label variable year      "Año de la cohorte Saber 11 (llave de cruce)"
label variable year_dato "Año real del dato municipal (year - 1)"

tabulate year_dato year
assert inrange(year, 2018, 2023)


********************************************************************************
* [8] PANEL DE CONTROL
********************************************************************************

display _newline "{hline 78}"
display "[8] PANEL DE CONTROL"
display "{hline 78}"

quietly count
display "Observaciones municipio-año: " r(N) " (esperadas: 252)"
isid cole_cod_mcpio_ubicacion year

display _newline "--- Cobertura de las variables del modelo ---"
misstable summarize tasa_homicidios tasa_hom_eb ln_coca ln_inversion_pc ///
    ln_inv_fut_pc ln_sgp_total_pc ln_sgp_pae_pc ln_ing_trib_pc, all

display _newline "--- Descriptivos por año de cohorte ---"
tabstat tasa_homicidios tasa_hom_eb ln_coca ln_inversion_pc ln_inv_fut_pc ///
    ln_ing_trib_pc, by(year) stat(n mean sd min max) format(%12.4f)

display _newline "--- Variación within y between de las medidas fiscales ---"
* Decide qué medidas alternativas tienen suficiente variación temporal para la
* descomposición de Mundlak. Una variable casi enteramente transversal no
* aporta a la parte within del Objetivo 4.
xtset cole_cod_mcpio_ubicacion year
xtsum tasa_homicidios ln_coca ln_inversion_pc ln_inv_fut_pc ///
      ln_sgp_total_pc ln_sgp_pae_pc ln_ing_trib_pc

* C7: la comparación que decide la precondición P1(i). La referencia es la
* desviación dentro del municipio de la tasa cruda, 28,66 [Tabla 21].
display _newline "--- C7: tasa cruda frente a suavizada, y los indicadores nuevos ---"
xtsum tasa_homicidios tasa_hom_eb iica minas tasa_hom_td ///
      desercion_of cob_neta_media

display _newline "--- C7: razón DE_dentro / DE_total ---"
display "    (umbral de la precondición P2: 0,20, la razón del SGP en Tabla 21)"
foreach v in tasa_homicidios tasa_hom_eb iica minas {
    quietly xtsum `v'
    display "  `v': DE_total " %9.4f r(sd) ///
            "  DE_dentro " %9.4f r(sd_w) ///
            "  razón " %6.3f r(sd_w)/r(sd)
}

display _newline "--- C7: concordancia con la fuente independiente ---"
correlate tasa_homicidios tasa_hom_eb tasa_hom_td

display _newline "--- Correlación entre las medidas fiscales en logaritmo ---"
correlate ln_inversion_pc ln_inv_fut_pc ln_sgp_total_pc ln_sgp_pae_pc ln_ing_trib_pc

display _newline "--- Valores atípicos en la inversión ejecutada ---"
* El FUT tiene errores de reporte ocasionales. Un municipio-año con un valor
* dos órdenes de magnitud por debajo del resto casi con seguridad es uno.
quietly summarize ln_inv_fut_pc, detail
scalar p1_fut = r(p1)
quietly count if ln_inv_fut_pc < 12 & !missing(ln_inv_fut_pc)
scalar n_atip_fut = r(N)
display "Municipio-año con log de inversión ejecutada menor que 12: " r(N)
if r(N) > 0 {
    list cole_cod_mcpio_ubicacion year_dato inv_fut_pc ln_inv_fut_pc ///
        if ln_inv_fut_pc < 12, clean noobs
}

* ----------------------------------------------------------------------
* [8.1] Versión de la inversión ejecutada sin el atípico
* ----------------------------------------------------------------------
* La versión 3 se limitaba a listar el atípico y dejaba la decisión al analista,
* pero la descomposición de Mundlak se calculaba igualmente sobre la serie
* completa. Eso contamina DOS coeficientes a la vez: el promedio del municipio
* queda arrastrado hacia abajo, y la desviación de ese año se vuelve enorme,
* justo en la variable cuyo componente temporal se quiere identificar en R5.
*
* La versión 4 construye una segunda serie con el atípico puesto en faltante y
* calcula su descomposición sobre las observaciones restantes. NO reemplaza a
* la original: las dos quedan en la base para que el capítulo de resultados
* pueda reportar la prueba con y sin el atípico y mostrar si la conclusión
* depende de un solo dato mal reportado.
generate double ln_inv_fut_pc_x = ln_inv_fut_pc
replace ln_inv_fut_pc_x = . if ln_inv_fut_pc < 12
label variable ln_inv_fut_pc_x "Log de la inversión ejecutada per cápita, sin el atípico de reporte (t-1)"

quietly count if missing(ln_inv_fut_pc_x) & !missing(ln_inv_fut_pc)
display _newline "Municipio-año excluidos de la serie depurada: " r(N)

display _newline "--- Comparación de las dos series ---"
tabstat ln_inv_fut_pc ln_inv_fut_pc_x, stat(n mean sd min max) format(%9.4f)

display _newline "--- Variación entre y dentro del municipio, con y sin el atípico ---"
* Este es el cuadro que decide si el atípico explica el resultado de R5: si la
* variación dentro del municipio cae mucho al depurar la serie, el dinamismo
* que justificaba usar el FUT venía en buena parte del error de reporte.
xtsum ln_inversion_pc ln_inv_fut_pc ln_inv_fut_pc_x

display _newline "--- Contexto educativo municipal (no entra a los modelos) ---"
tabstat cob_neta_media desercion_of repitencia_of transito_sup, ///
    by(year) stat(n mean sd) format(%9.2f)

* C7: advertencia de serie. repitencia_of pasa de ~1% a ~6% entre 2019 y 2020,
* lo que delata un cambio de criterio de reporte en la serie educativa de
* TerriData. desercion_of cae a 1,73 ese mismo año, compatible con las
* políticas de promoción de la pandemia. Los efectos de año absorben el nivel,
* no un cambio en lo que mide el indicador. Va declarado en la nota de la tabla.
display _newline "AVISO C7: el salto de repitencia_of entre 2019 y 2020 indica"
display "cambio de criterio de reporte en la serie educativa de TerriData."
display "Leer desercion_of con esa reserva."


********************************************************************************
* [9] DESCOMPOSICIÓN DE MUNDLAK DE LAS MEDIDAS FISCALES ALTERNATIVAS
********************************************************************************
* La descomposición del índice, de las tres dimensiones principales y, desde
* C7, de la tasa suavizada y el IICA, se hace en el script 06. Aquí se prepara
* la de las medidas fiscales alternativas, que solo se usan en las pruebas de
* robustez del Objetivo 4.

display _newline "{hline 78}"
display "[9] DESCOMPOSICIÓN ENTRE Y DENTRO PARA LAS ALTERNATIVAS"
display "{hline 78}"

* `egen mean` ignora los faltantes, de modo que el promedio de la serie
* depurada se calcula sobre las observaciones válidas del municipio y la
* desviación queda en faltante solo para el municipio-año excluido.
foreach v in ln_inv_fut_pc ln_inv_fut_pc_x ln_sgp_total_pc ln_sgp_pae_pc ln_ing_trib_pc {
    bysort cole_cod_mcpio_ubicacion: egen double `v'_bar = mean(`v')
    generate double `v'_dev = `v' - `v'_bar
}

label variable ln_inv_fut_pc_bar   "Inversión ejecutada promedio del municipio (entre)"
label variable ln_inv_fut_pc_dev   "Desviación de la inversión ejecutada (dentro)"
label variable ln_inv_fut_pc_x_bar "Inversión ejecutada promedio, serie depurada (entre)"
label variable ln_inv_fut_pc_x_dev "Desviación de la inversión ejecutada, serie depurada (dentro)"
label variable ln_ing_trib_pc_bar  "Ingresos tributarios promedio del municipio (entre)"
label variable ln_ing_trib_pc_dev  "Desviación de los ingresos tributarios (dentro)"

display _newline "--- Verificación de la descomposición ---"
foreach v in ln_inv_fut_pc ln_ing_trib_pc {
    generate double _chk = `v'_bar + `v'_dev - `v'
    quietly summarize _chk
    display "  `v': error máximo " %12.10f max(abs(r(max)), abs(r(min)))
    drop _chk
}


********************************************************************************
* [10] GUARDADO
********************************************************************************

order cole_cod_mcpio_ubicacion year year_dato ///
      tasa_homicidios tasa_hom_eb homicidios pob coca ln_coca ///
      inversion inversion_r inversion_pc ln_inversion_pc ///
      inv_fut_pc ln_inv_fut_pc ln_inv_fut_pc_x sgp_total_pc ln_sgp_total_pc ///
      sgp_pae_pc ln_sgp_pae_pc ing_trib_pc_r ln_ing_trib_pc deflactor ///
      iica minas tasa_hom_td desercion_of cob_neta_media

compress
save "N3_Municipios_2018_2023.dta", replace

display _newline "{hline 78}"
display "NIVEL 3 CERRADO: N3_Municipios_2018_2023.dta"
display "RECORDATORIO: year es el año de la COHORTE; los datos son de year - 1."
display "La medida principal de inversión es ln_inversion_pc (SGP libre"
display "inversión). Las alternativas van solo en las pruebas de robustez."
display "NUEVO EN v5: tasa_hom_eb, la tasa suavizada por Bayes empírico (C7)."
display "Siguiente: 06_pca_vulnerabilidad_v3.do"
display "{hline 78}"

log close fase4

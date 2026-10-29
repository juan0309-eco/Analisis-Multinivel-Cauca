********************************************************************************
* PROYECTO : Desempeño Saber 11 en sedes oficiales del Cauca, 2018-2023
* SCRIPT   : 03 - FASE 3. PANEL TIC Y CIERRE DEL NIVEL 2
* ENTRADA  : Panel_tic.xlsx (hojas 2018_tic ... 2023_tic)
*            N2_Sedes_sinTIC.dta
* SALIDA   : N2_Sedes_2018_2023.dta
*            TIC_largo_2018_2023.dta (archivo fuente en formato largo)
* STATA    : 17
* VERSIÓN  : 2 - incorpora z_posgrado y el diagnóstico de ceros explícitos
********************************************************************************
* EL ERROR ESTRUCTURAL QUE ESTE SCRIPT CORRIGE
*
* La versión anterior calculaba
*     bienes_tic = SEDECOM_CANTIDAD - SEDECOM_CANT_SINUSO
* y obtenía valores negativos, hasta -1.451 en la fila más extrema. Esa resta
* afectaba a 56.719 filas, el 11,7% de la base.
*
* SEDECOM_CANTIDAD no es el inventario total: son los equipos desplegados. En
* las hojas de 2021 en adelante, SEDECOM_CANT_PRESTA + SEDECOM_CANT_SEDE suma
* exactamente SEDECOM_CANTIDAD en la totalidad de las filas (verificado: cero
* discrepancias). Esa descomposición reparte por ubicación los equipos en
* servicio; los inservibles no están prestados ni operando, así que quedan
* fuera de CANTIDAD y restarlos los descontaba dos veces.
*
* Reconstrucción correcta:
*     equipos_funcionales = suma de SEDECOM_CANTIDAD sobre los tres tipos
*     equipos_total       = equipos_funcionales + suma de SEDECOM_CANT_SINUSO
*
* SOBRE LA AUSENCIA DE FILAS
* Las 25.619 filas con CANTIDAD = 0 coinciden exactamente con las filas que
* tienen CANTIDAD = 0 y SIN USO > 0: no existe ninguna fila con ambos en cero.
* La fuente crea registro solo cuando la sede posee al menos un equipo de ese
* tipo, en servicio o inservible. Por tanto la ausencia de fila SÍ significa
* cero equipos, la suma sobre los tipos presentes es correcta, y n_tipos_tic
* NO debe entrar como control: la variedad de equipos es parte de la dotación,
* no un confusor de ella.
********************************************************************************

clear all
set more off
set varabbrev off
version 17

if "$TESIS_CONFIG" == "" do "C:\Users\RYZEN 5\Desktop\Tesis Multinivel\Definitivo\00_config.do"
cd "$RAIZ"

capture log close _all
local tarea "03_panel_tic"
local hoy   "20261024"          // <<< etiqueta de la proxima corrida

capture confirm file "log_`tarea'_`hoy'.log"
if _rc == 0 {
    display as error "Ya existe log_`tarea'_`hoy'.log."
    display as error "Cambiar el local hoy (por ejemplo, anadir un sufijo b, c...)."
    exit 602
}
log using "log_`tarea'_`hoy'.log", text name(fase3)


********************************************************************************
* [1] LECTURA DE LAS HOJAS ANUALES
********************************************************************************
* Las hojas de 2018 a 2020 traen 8 columnas y las de 2021 a 2023 traen 10.
* El archivo largo se guarda como .dta permanente para poder inspeccionarlo
* después sin volver a leer el Excel ni depender de un tempfile.

local primero = 1

foreach y in 2018 2019 2020 2021 2022 2023 {

    display _newline "{hline 78}"
    display "LEYENDO HOJA `y'_tic"
    display "{hline 78}"

    capture noisily import excel "Panel_tic.xlsx", sheet("`y'_tic") firstrow clear
    if _rc != 0 {
        display as error "No se pudo leer la hoja `y'_tic. Año omitido."
        continue
    }

    quietly count
    display "Filas leídas: " r(N)

    rename *, lower

    * Presencia de las columnas de desglose por ubicación.
    local tiene_desglose = 0
    capture confirm variable sedecom_cant_presta
    if _rc == 0 {
        capture confirm variable sedecom_cant_sede
        if _rc == 0 local tiene_desglose = 1
    }
    if `tiene_desglose' == 1 {
        display "Hoja `y': incluye el desglose PRESTA / SEDE."
    }
    else {
        display "Hoja `y': sin desglose PRESTA / SEDE (esperado en 2018-2020)."
        quietly generate double sedecom_cant_presta = .
        quietly generate double sedecom_cant_sede   = .
    }

    keep sede_codigo periodo_id periodo_anio equipocom_id equipocom_nombre ///
         sedecom_cantidad sedecom_cant_sinuso sedecom_cant_presta sedecom_cant_sede

    capture confirm string variable sede_codigo
    if _rc != 0 {
        quietly tostring sede_codigo, replace format(%20.0f) force
    }
    quietly replace sede_codigo = trim(sede_codigo)
    rename sede_codigo cole_cod_dane_sede

    quietly destring periodo_id periodo_anio equipocom_id sedecom_cantidad   ///
        sedecom_cant_sinuso sedecom_cant_presta sedecom_cant_sede,           ///
        replace force

    rename periodo_anio year

    * ------------------------------------------------------------------
    * Diagnósticos de la hoja
    * ------------------------------------------------------------------
    display _newline "--- Olas de recolección (periodo_id) y años ---"
    tabulate periodo_id year, missing

    display _newline "--- Tipos de equipo ---"
    tabulate equipocom_nombre, missing

    quietly duplicates tag cole_cod_dane_sede year equipocom_id, generate(_dup)
    quietly count if _dup > 0
    display _newline "Filas con sede-año-tipo repetido: " r(N)
    drop _dup

    quietly count if sedecom_cant_sinuso > sedecom_cantidad & ///
                     !missing(sedecom_cant_sinuso, sedecom_cantidad)
    display "Filas donde SIN USO supera a CANTIDAD: " r(N)
    quietly count if sedecom_cantidad == 0 & sedecom_cant_sinuso > 0 & ///
                     !missing(sedecom_cant_sinuso)
    display "Filas con CANTIDAD = 0 y SIN USO > 0: " r(N)
    quietly count if sedecom_cantidad == 0 & sedecom_cant_sinuso == 0
    display "Filas con CANTIDAD = 0 y SIN USO = 0: " r(N) ///
            "  (si es 0, la fuente nunca registra ausencia total)"

    if `tiene_desglose' == 1 {
        generate double _chk = sedecom_cant_presta + sedecom_cant_sede
        quietly count if abs(_chk - sedecom_cantidad) > 0.001 & !missing(_chk)
        display "Filas donde PRESTA + SEDE != CANTIDAD: " r(N) ///
                "  (debe ser 0 si la lectura es correcta)"
        drop _chk
    }

    quietly drop if missing(cole_cod_dane_sede) | cole_cod_dane_sede == ""

    if `primero' == 1 {
        quietly save "TIC_largo_2018_2023.dta", replace
        local primero = 0
    }
    else {
        quietly append using "TIC_largo_2018_2023.dta"
        quietly save "TIC_largo_2018_2023.dta", replace
    }
}


********************************************************************************
* [2] DIAGNÓSTICO DEL ARCHIVO LARGO COMPLETO
********************************************************************************

use "TIC_largo_2018_2023.dta", clear

display _newline "{hline 78}"
display "[2] DIAGNÓSTICO DEL PANEL TIC EN FORMATO LARGO"
display "{hline 78}"

quietly count
display "Filas totales (una por sede-año-tipo de equipo): " r(N)

display _newline "--- Tipos de equipo por año ---"
tabulate equipocom_nombre year

display _newline "--- Estadísticos de las cantidades ---"
tabstat sedecom_cantidad sedecom_cant_sinuso, ///
        by(year) stat(n mean sd p50 min max) format(%9.2f)

* ----------------------------------------------------------------------
* [2.1] MAGNITUD DEL ERROR DE LA FÓRMULA ANTERIOR
* ----------------------------------------------------------------------
* Cifras para el informe metodológico.
display _newline "--- Magnitud del problema que generaba negativos ---"
generate double _resta_vieja = sedecom_cantidad - sedecom_cant_sinuso
quietly count if _resta_vieja < 0 & !missing(_resta_vieja)
display "Filas que la fórmula anterior habría dejado en negativo: " r(N)
quietly summarize _resta_vieja if _resta_vieja < 0
display "Mínimo que producía la resta: " r(min)
display _newline "Filas negativas por año:"
tabulate year if _resta_vieja < 0
drop _resta_vieja

* ----------------------------------------------------------------------
* [2.2] ¿LA FUENTE REGISTRA CEROS EXPLÍCITOS?
* ----------------------------------------------------------------------
* De esto depende cómo se interpreta la ausencia de una fila. Si toda fila con
* cantidad cero tiene equipos sin uso, entonces el archivo solo registra tipos
* de equipo que la sede efectivamente posee, y no tener fila equivale a no
* tener equipos de ese tipo.
display _newline "--- Ceros explícitos en la fuente ---"
quietly count if sedecom_cantidad == 0
display "Filas con CANTIDAD = 0: " r(N)
quietly count if sedecom_cantidad == 0 & sedecom_cant_sinuso == 0
display "De ellas, con SIN USO también en 0: " r(N) ///
        "  (si es 0, no hay registro de ausencia total)"

bysort cole_cod_dane_sede year: egen byte n_ceros = total(sedecom_cantidad == 0)
egen byte _tag = tag(cole_cod_dane_sede year)
display _newline "--- Tipos de equipo en cero por sede-año ---"
tabulate n_ceros if _tag == 1
tabulate n_ceros year if _tag == 1
drop n_ceros _tag


********************************************************************************
* [3] COLAPSO A SEDE-AÑO
********************************************************************************
* Aquí ocurre la suma de los tres tipos de equipo que faltaba en la hoja
* consolidada del archivo original.

display _newline "{hline 78}"
display "[3] COLAPSO A SEDE-AÑO SUMANDO LOS TRES TIPOS DE EQUIPO"
display "{hline 78}"

collapse (sum)   equipos_funcionales = sedecom_cantidad          ///
                 equipos_sinuso      = sedecom_cant_sinuso       ///
                 equipos_prestamo    = sedecom_cant_presta       ///
         (count) n_tipos_tic         = equipocom_id,             ///
         by(cole_cod_dane_sede year)

generate double equipos_total = equipos_funcionales + equipos_sinuso

label variable equipos_funcionales "Equipos de cómputo en servicio (suma de los 3 tipos)"
label variable equipos_sinuso      "Equipos de cómputo sin uso (suma de los 3 tipos)"
label variable equipos_total       "Inventario total de equipos (en servicio + sin uso)"
label variable n_tipos_tic         "Tipos de equipo que posee la sede (documentación, NO control)"

quietly count
display "Sede-año en el panel TIC nacional: " r(N)

quietly count if equipos_funcionales < 0
display _newline "Sede-año con equipos funcionales negativos: " r(N) " (debe ser 0)"
assert equipos_funcionales >= 0

display _newline "--- Distribución del número de tipos que posee la sede ---"
tabulate n_tipos_tic year

display _newline "--- Equipos por sede-año (nacional) ---"
tabstat equipos_funcionales equipos_sinuso equipos_total, ///
        by(year) stat(n mean sd p50 max) format(%9.2f)

isid cole_cod_dane_sede year
tempfile tic_sedeanio
save `tic_sedeanio', replace


********************************************************************************
* [4] CRUCE SOBRE EL PANEL DE SEDES
********************************************************************************
* El panel de sedes manda: sus 2.447 filas se conservan. Una sede ausente del
* archivo TIC queda en missing, NO en cero: no responder la encuesta de
* dotación no es lo mismo que no tener equipos.

display _newline "{hline 78}"
display "[4] CRUCE CON EL PANEL DE SEDES"
display "{hline 78}"

use "N2_Sedes_sinTIC.dta", clear

quietly count
display "Sede-año en el panel de sedes: " r(N)

merge 1:1 cole_cod_dane_sede year using `tic_sedeanio', ///
    keep(master match) generate(_m_tic)

display _newline "--- Resultado del cruce ---"
tabulate _m_tic

display _newline "--- Sede-año sin datos TIC, por año ---"
tabulate year if _m_tic == 1

generate byte tic_miss = (_m_tic == 1)
label variable tic_miss "Sede-año sin registro en el panel TIC (1 = sí)"
drop _m_tic


********************************************************************************
* [5] DOTACIÓN TIC POR ESTUDIANTE
********************************************************************************

display _newline "{hline 78}"
display "[5] CONSTRUCCIÓN DE LA DOTACIÓN TIC"
display "{hline 78}"

generate double dotacion_tic = equipos_funcionales / matricula ///
    if matricula > 0 & !missing(matricula)
label variable dotacion_tic "Equipos de cómputo en servicio por estudiante"

generate double dotacion_tic_total = equipos_total / matricula ///
    if matricula > 0 & !missing(matricula)
label variable dotacion_tic_total "Equipos totales por estudiante (incluye sin uso)"

assert dotacion_tic >= 0 if !missing(dotacion_tic)
display "Verificado: ninguna dotación negativa."

display _newline "--- Dotación TIC por año ---"
tabstat dotacion_tic dotacion_tic_total, ///
        by(year) stat(n mean sd p10 p50 p90 min max) format(%9.4f)

* El gradiente según el número de tipos es real, no sesgo de reporte: una sede
* con tres tipos de equipo está efectivamente mejor dotada. Se reporta como
* documentación del punto, no como motivo para controlar por n_tipos_tic.
display _newline "--- Dotación según cuántos tipos de equipo posee la sede ---"
tabstat dotacion_tic, by(n_tipos_tic) stat(n mean sd p50) format(%9.4f)


********************************************************************************
* [6] CORRECCIÓN DE LA COMPARABILIDAD INTERTEMPORAL DE pct_posgrado
********************************************************************************
* PROBLEMA
* pct_posgrado cae de 0,331 en 2018 a 0,141 en 2023, con quiebres bruscos en
* 2021 y 2022, y su desviación estándar se desploma de 0,304 a 0,164. El xtsum
* arroja varianza within (0,227) mayor que la between (0,140): la proporción de
* docentes con posgrado variaría más dentro de una misma sede a lo largo de
* seis años que entre sedes distintas. Eso es implausible para una
* característica institucional —el cuerpo docente rota lentamente y nadie
* pierde un posgrado— y apunta a un cambio en el criterio de reporte del DANE.
*
* SOLUCIÓN ADOPTADA
* Estandarización DENTRO DE CADA AÑO sobre la muestra del Cauca. La variable
* resultante mide cuántas desviaciones está una sede por encima del promedio de
* las sedes caucanas de su mismo año. Esto neutraliza a la vez el salto de
* nivel y el colapso de la dispersión, porque cada año se normaliza contra su
* propia escala.
*
* SUPUESTO QUE ASUME
* Que el cambio de criterio afectó de manera similar a todas las sedes, de modo
* que el ORDENAMIENTO relativo se conserva aunque los niveles no. Es un
* supuesto, pero mucho más débil que asumir que un 0,33 de 2018 y un 0,14 de
* 2023 miden lo mismo.
*
* COSTO
* Se pierde toda lectura temporal de la formación docente. Debe declararse en
* la metodología: z_posgrado responde a "qué sedes tienen más docentes con
* posgrado", nunca a "cómo evolucionó la formación docente en el Cauca".
*
* NOTA PARA EL SCRIPT DE IMPUTACIÓN
* z_posgrado NO debe imputarse directamente. Se imputa pct_posgrado y se
* recalcula z_posgrado como variable pasiva dentro de mi passive, para que la
* estandarización se rehaga en cada imputación.

display _newline "{hline 78}"
display "[6] ESTANDARIZACIÓN INTRA-ANUAL DE pct_posgrado"
display "{hline 78}"

display _newline "--- Serie cruda: el problema de comparabilidad ---"
tabstat pct_posgrado, by(year) stat(n mean sd p25 p50 p75) format(%9.4f)

bysort year: egen double _media_pos = mean(pct_posgrado)
bysort year: egen double _sd_pos    = sd(pct_posgrado)

generate double z_posgrado = (pct_posgrado - _media_pos) / _sd_pos
label variable z_posgrado ///
    "Docentes con posgrado, estandarizado dentro del año (sin lectura temporal)"

drop _media_pos _sd_pos

* La variable cruda se conserva solo como documentación de la fuente.
label variable pct_posgrado ///
    "Proporción de docentes con posgrado (CRUDA - no comparable entre años)"

display _newline "--- Serie estandarizada: media 0 y SD 1 en cada año ---"
tabstat z_posgrado, by(year) stat(n mean sd min max) format(%9.4f)

display _newline "--- Correlación entre la cruda y la estandarizada, por año ---"
* Dentro de cada año la transformación es lineal, así que el ordenamiento se
* conserva íntegro: la correlación anual debe ser exactamente 1.
foreach y in 2018 2019 2020 2021 2022 2023 {
    quietly correlate pct_posgrado z_posgrado if year == `y'
    display "  `y': " %6.4f r(rho)
}


********************************************************************************
* [7] PANEL DE CONTROL DEL NIVEL 2 COMPLETO
********************************************************************************

display _newline "{hline 78}"
display "[7] PANEL DE CONTROL DEL NIVEL 2"
display "{hline 78}"

display _newline "--- Cobertura de todas las variables de sede ---"
misstable summarize matricula ln_matricula ratio_alumnos_docente ///
    pct_planta pct_posgrado z_posgrado equipos_funcionales dotacion_tic

display _newline "--- Descriptivos por año ---"
tabstat ln_matricula ratio_alumnos_docente pct_planta z_posgrado ///
        dotacion_tic rural ju_unica, ///
        by(year) stat(n mean sd) format(%9.4f)

display _newline "--- Variación within y between ---"
egen long sede_id = group(cole_cod_dane_sede)
xtset sede_id year
xtsum dotacion_tic ln_matricula ratio_alumnos_docente pct_planta ///
      pct_posgrado z_posgrado

display _newline "--- Correlación entre las variables de sede ---"
correlate ln_matricula ratio_alumnos_docente pct_planta z_posgrado ///
          dotacion_tic rural ju_unica

isid cole_cod_dane_sede year
assert inrange(year, 2018, 2023)
assert !missing(cole_cod_mcpio_ubicacion)
display _newline "Llaves verificadas."


********************************************************************************
* [8] GUARDADO
********************************************************************************

drop sede_id
order cole_cod_dane_sede cole_cod_mcpio_ubicacion year ///
      matricula ln_matricula ratio_alumnos_docente pct_planta z_posgrado ///
      dotacion_tic equipos_funcionales rural ju_unica

compress
save "N2_Sedes_2018_2023.dta", replace

display _newline "{hline 78}"
display "NIVEL 2 CERRADO: N2_Sedes_2018_2023.dta"
display "Archivo fuente en formato largo: TIC_largo_2018_2023.dta"
display "Siguiente: Fase 4, panel municipal de Nivel 3 con inversión deflactada."
display "{hline 78}"

log close fase3

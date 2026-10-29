********************************************************************************
* PROYECTO : Desempeño Saber 11 en sedes oficiales del Cauca, 2018-2023
* SCRIPT   : 06 - ÍNDICE DE VULNERABILIDAD MACRO-TERRITORIAL Y MUNDLAK
* ENTRADA  : N3_Municipios_2018_2023.dta   (252 municipio-año)
*            Base_Multinivel_2018_2023.dta (69.750 estudiantes)
* SALIDA   : N3_Municipios_PCA.dta
*            Base_Multinivel_PCA.dta
* STATA    : 17
********************************************************************************
* POR QUÉ ESTE SCRIPT VA ANTES DE LA IMPUTACIÓN
* El panel municipal no tiene valores perdidos, así que el índice se construye
* completo. Eso permite además que entre al modelo de imputación como variable
* auxiliar sin necesidad de imputarlo a él.
*
* SOBRE QUÉ SE ESTIMA EL PCA
* Sobre las 252 observaciones municipio-año, NO sobre las 69.750 filas de
* estudiante. Estimarlo sobre las filas de estudiante ponderaría cada municipio
* por su número de evaluados, de modo que Popayán pesaría decenas de veces más
* que un municipio pequeño en la definición de los pesos del componente.
*
* Tampoco se estima sobre 42 medias municipales, como hacía la versión
* anterior. Eso producía un índice constante en el tiempo e impedía cualquier
* análisis de variación temporal, que es justamente lo que pide el Objetivo 4.
*
* QUÉ ENTREGA
* 1. El índice y su descomposición de Mundlak en componente entre municipios
*    (`vuln_bar`) y componente dentro del municipio (`vuln_dev`).
* 2. La misma descomposición para las tres variables por separado, porque el
*    Objetivo 4 presenta ambas especificaciones.
* 3. Los diagnósticos del PCA para el capítulo de metodología.
********************************************************************************

clear all
set more off
set varabbrev off
version 17

cd "C:\Users\RYZEN 5\Desktop\Tesis Multinivel\Objetivo 2"

capture log close _all
log using "log_06_pca_vulnerabilidad.log", replace text name(fase6)


********************************************************************************
* [1] PREPARACIÓN DE LOS INSUMOS
********************************************************************************

display _newline "{hline 78}"
display "[1] INSUMOS DEL ÍNDICE"
display "{hline 78}"

use "N3_Municipios_2018_2023.dta", clear

quietly count
display "Observaciones municipio-año: " r(N) " (esperadas: 252)"
assert _N == 252

xtset cole_cod_mcpio_ubicacion year

* Las tres dimensiones entran con la forma funcional en que se usarán después:
* la tasa de homicidios en nivel, coca e inversión en logaritmo.
display _newline "--- Insumos del índice ---"
tabstat tasa_homicidios ln_coca ln_inversion_pc, ///
        stat(n mean sd min max) format(%9.4f)

display _newline "--- Matriz de correlaciones ---"
correlate tasa_homicidios ln_coca ln_inversion_pc

* Estandarización agrupada sobre las 252 observaciones. No se estandariza por
* año: eso eliminaría las diferencias de nivel entre años, que son parte de la
* variación que el índice debe capturar.
foreach v in tasa_homicidios ln_coca ln_inversion_pc {
    quietly summarize `v'
    generate double z_`v' = (`v' - r(mean)) / r(sd)
}

label variable z_tasa_homicidios "Tasa de homicidios estandarizada"
label variable z_ln_coca         "Log de hectáreas de coca estandarizado"
label variable z_ln_inversion_pc "Log de inversión per cápita estandarizado"


********************************************************************************
* [2] ANÁLISIS DE COMPONENTES PRINCIPALES
********************************************************************************

display _newline "{hline 78}"
display "[2] ANÁLISIS DE COMPONENTES PRINCIPALES"
display "{hline 78}"

pca z_tasa_homicidios z_ln_coca z_ln_inversion_pc, components(1)

display _newline "--- Autovalores y varianza explicada ---"
estat loadings
matrix ev = e(Ev)
display "Autovalor 1: " %6.4f ev[1,1]
display "Autovalor 2: " %6.4f ev[1,2]
display "Autovalor 3: " %6.4f ev[1,3]
display "Varianza explicada por el primer componente: " ///
        %6.2f 100*ev[1,1]/3 "%"

* ----------------------------------------------------------------------
* [2.1] ADECUACIÓN MUESTRAL
* ----------------------------------------------------------------------
* El KMO es el indicador que un lector con formación estadística va a buscar.
* Se reporta completo, con el valor global y el de cada variable, y se declara
* explícitamente si queda por debajo del umbral convencional de 0,60.
display _newline "--- Medida de adecuación muestral de Kaiser-Meyer-Olkin ---"
estat kmo

quietly estat kmo
scalar kmo_global = r(kmo)
display _newline "KMO global: " %6.4f kmo_global
if kmo_global < 0.60 {
    display "ADVERTENCIA: el KMO está por debajo de 0,60, el umbral que la"
    display "convención considera adecuado para análisis factorial. Debe"
    display "declararse en la metodología junto con la varianza explicada."
}

display _newline "--- Prueba de esfericidad de Bartlett ---"
* `factortest` no requiere ningún paquete de usuario que falte: el problema es
* que la llamada anterior iba precedida de `quietly`, así que Stata calculaba
* el estadístico y lo descartaba sin mostrarlo ni guardarlo en ningún r().
* Aquí se calcula directamente desde el determinante de la matriz de
* correlaciones, sin depender de un comando externo:
*     chi2 = -[(n-1) - (2p+5)/6] * ln(det(R))   con  df = p(p-1)/2
quietly correlate z_tasa_homicidios z_ln_coca z_ln_inversion_pc
local n_bartlett = r(N)
matrix R_bartlett = r(C)
local p_bartlett = 3
scalar det_r = det(R_bartlett)
scalar chi2_bartlett = -((`n_bartlett' - 1) - (2*`p_bartlett' + 5)/6) * ln(det_r)
local df_bartlett = `p_bartlett' * (`p_bartlett' - 1) / 2
scalar pval_bartlett = chi2tail(`df_bartlett', chi2_bartlett)

display "Determinante de la matriz de correlaciones: " %8.6f det_r
display "Chi2(" `df_bartlett' ") = " %8.3f chi2_bartlett
display "p-valor: " %8.6f pval_bartlett
if pval_bartlett < 0.05 {
    display "Se rechaza la hipótesis de que la matriz de correlaciones es la"
    display "identidad: hay correlación suficiente entre las tres variables"
    display "para justificar el análisis de componentes principales."
}
else {
    display "ADVERTENCIA: no se rechaza esfericidad. El PCA no está justificado"
    display "por la prueba de Bartlett, aunque el KMO pueda ser aceptable."
}


********************************************************************************
* [3] CONSTRUCCIÓN DEL ÍNDICE
********************************************************************************

display _newline "{hline 78}"
display "[3] CONSTRUCCIÓN DEL ÍNDICE"
display "{hline 78}"

predict double indice_vuln, score

* ----------------------------------------------------------------------
* [3.1] ORIENTACIÓN DEL SIGNO
* ----------------------------------------------------------------------
* El signo de un componente principal es arbitrario: el algoritmo puede
* devolver el vector o su opuesto. El índice debe orientarse de modo que los
* valores altos signifiquen MAYOR vulnerabilidad, es decir más homicidios,
* más coca y menos inversión. Se verifica contra los homicidios y se invierte
* si hace falta.
quietly correlate indice_vuln tasa_homicidios
scalar signo = r(rho)
display "Correlación entre el índice y la tasa de homicidios: " %6.4f signo

if signo < 0 {
    quietly replace indice_vuln = -indice_vuln
    display "El signo se invirtió para que los valores altos indiquen mayor"
    display "vulnerabilidad."
}
else {
    display "El signo original ya orienta el índice hacia mayor vulnerabilidad."
}

* Reescalado a media cero y desviación uno, de modo que un punto del índice
* equivalga a una desviación estándar y los coeficientes sean interpretables.
quietly summarize indice_vuln
quietly replace indice_vuln = (indice_vuln - r(mean)) / r(sd)
label variable indice_vuln "Índice de vulnerabilidad macro-territorial (t-1)"

display _newline "--- Verificación de la orientación ---"
correlate indice_vuln tasa_homicidios ln_coca ln_inversion_pc
display "Se espera: positiva con homicidios y coca, negativa con inversión."

display _newline "--- Distribución del índice por año ---"
tabstat indice_vuln, by(year) stat(n mean sd min max) format(%9.4f)


********************************************************************************
* [4] VERSIÓN ALTERNATIVA PARA ROBUSTEZ
********************************************************************************
* Estandarización dentro de cada año antes del PCA. Esta versión elimina las
* diferencias de nivel entre años y deja solo el ordenamiento relativo de los
* municipios dentro de cada corte. Se conserva como prueba de robustez, no
* como especificación principal.

display _newline "{hline 78}"
display "[4] VERSIÓN DE ROBUSTEZ CON ESTANDARIZACIÓN INTRA-ANUAL"
display "{hline 78}"

foreach v in tasa_homicidios ln_coca ln_inversion_pc {
    bysort year: egen double _m_`v' = mean(`v')
    bysort year: egen double _s_`v' = sd(`v')
    generate double za_`v' = (`v' - _m_`v') / _s_`v'
    drop _m_`v' _s_`v'
}

quietly pca za_tasa_homicidios za_ln_coca za_ln_inversion_pc, components(1)
matrix ev_a = e(Ev)
display "Varianza explicada, versión intra-anual: " %6.2f 100*ev_a[1,1]/3 "%"

predict double indice_vuln_anual, score
quietly correlate indice_vuln_anual tasa_homicidios
if r(rho) < 0 quietly replace indice_vuln_anual = -indice_vuln_anual
quietly summarize indice_vuln_anual
quietly replace indice_vuln_anual = (indice_vuln_anual - r(mean)) / r(sd)
label variable indice_vuln_anual "Índice de vulnerabilidad, estandarización intra-anual"

display _newline "--- Correlación entre las dos versiones del índice ---"
correlate indice_vuln indice_vuln_anual

drop za_* z_tasa_homicidios z_ln_coca z_ln_inversion_pc


********************************************************************************
* [5] DESCOMPOSICIÓN DE MUNDLAK
********************************************************************************
* La descomposición separa dos preguntas que un coeficiente único confunde:
*   `_bar` : los municipios más vulnerables EN PROMEDIO, ¿tienen peor
*            desempeño? Es comparación entre territorios.
*   `_dev` : cuando un municipio se vuelve más vulnerable de lo habitual EN
*            ÉL MISMO, ¿cae su desempeño? Es variación temporal dentro del
*            territorio, y es la que se acerca a una interpretación causal.
* El contraste de igualdad entre ambos coeficientes es el resultado central
* del Objetivo 4.

display _newline "{hline 78}"
display "[5] DESCOMPOSICIÓN ENTRE Y DENTRO DE MUNICIPIO"
display "{hline 78}"

* --- Índice ---
bysort cole_cod_mcpio_ubicacion: egen double vuln_bar = mean(indice_vuln)
generate double vuln_dev = indice_vuln - vuln_bar
label variable vuln_bar "Vulnerabilidad promedio del municipio (componente entre)"
label variable vuln_dev "Desviación de la vulnerabilidad respecto de su promedio (componente dentro)"

* --- Las tres variables por separado ---
* El Objetivo 4 presenta ambas especificaciones, así que las tres dimensiones
* reciben el mismo tratamiento. Se conservan en unidades naturales para que
* los coeficientes admitan lectura sustantiva.
foreach v in tasa_homicidios ln_coca ln_inversion_pc {
    bysort cole_cod_mcpio_ubicacion: egen double `v'_bar = mean(`v')
    generate double `v'_dev = `v' - `v'_bar
}

label variable tasa_homicidios_bar "Tasa de homicidios promedio del municipio (entre)"
label variable tasa_homicidios_dev "Desviación de la tasa de homicidios (dentro)"
label variable ln_coca_bar         "Log de coca promedio del municipio (entre)"
label variable ln_coca_dev         "Desviación del log de coca (dentro)"
label variable ln_inversion_pc_bar "Log de inversión per cápita promedio (entre)"
label variable ln_inversion_pc_dev "Desviación del log de inversión per cápita (dentro)"

display _newline "--- Descomposición de varianza del índice ---"
xtsum indice_vuln vuln_bar vuln_dev

display _newline "--- Descomposición de las tres dimensiones ---"
xtsum tasa_homicidios ln_coca ln_inversion_pc

* Verificación aritmética de la descomposición.
generate double _chk = vuln_bar + vuln_dev - indice_vuln
quietly summarize _chk
assert abs(r(max)) < 1e-8 & abs(r(min)) < 1e-8
display _newline "Verificado: el componente entre más el componente dentro"
display "reconstruye el índice exactamente."
drop _chk

* Los dos componentes son ortogonales por construcción. Se comprueba porque un
* valor distinto de cero indicaría un error en el cálculo de las medias.
quietly correlate vuln_bar vuln_dev
display "Correlación entre los dos componentes: " %8.6f r(rho) " (debe ser ~0)"


********************************************************************************
* [6] PANEL DE CONTROL Y GUARDADO DEL NIVEL 3
********************************************************************************

display _newline "{hline 78}"
display "[6] PANEL DE CONTROL DEL NIVEL 3"
display "{hline 78}"

display _newline "--- Municipios con mayor vulnerabilidad promedio ---"
preserve
    egen byte _t = tag(cole_cod_mcpio_ubicacion)
    keep if _t == 1
    gsort -vuln_bar
    list cole_cod_mcpio_ubicacion vuln_bar tasa_homicidios_bar ///
         ln_coca_bar ln_inversion_pc_bar in 1/10, clean noobs
restore

display _newline "--- Municipios con mayor aumento de la vulnerabilidad ---"
preserve
    keep cole_cod_mcpio_ubicacion year indice_vuln
    quietly reshape wide indice_vuln, i(cole_cod_mcpio_ubicacion) j(year)
    generate double cambio = indice_vuln2023 - indice_vuln2018
    gsort -cambio
    list cole_cod_mcpio_ubicacion indice_vuln2018 indice_vuln2023 cambio ///
         in 1/10, clean noobs
restore

isid cole_cod_mcpio_ubicacion year
compress
save "N3_Municipios_PCA.dta", replace


********************************************************************************
* [7] INCORPORACIÓN A LA BASE MULTINIVEL
********************************************************************************

display _newline "{hline 78}"
display "[7] INCORPORACIÓN A LA BASE MULTINIVEL"
display "{hline 78}"

keep cole_cod_mcpio_ubicacion year indice_vuln indice_vuln_anual ///
     vuln_bar vuln_dev ///
     tasa_homicidios_bar tasa_homicidios_dev ///
     ln_coca_bar ln_coca_dev ///
     ln_inversion_pc_bar ln_inversion_pc_dev
tempfile n3pca
save `n3pca', replace

use "Base_Multinivel_2018_2023.dta", clear

merge m:1 cole_cod_mcpio_ubicacion year using `n3pca', generate(_m_pca)
tabulate _m_pca
assert _m_pca == 3
drop _m_pca

display _newline "Índice incorporado a las " _N " observaciones de estudiante."

* Comprobación de que el índice no tiene faltantes: es la condición que permite
* usarlo como variable auxiliar completa en el modelo de imputación.
quietly count if missing(indice_vuln)
display "Estudiantes sin valor del índice: " r(N) " (debe ser 0)"
assert !missing(indice_vuln)

display _newline "--- Índice en la base de estudiantes, por año ---"
tabstat indice_vuln vuln_bar vuln_dev, by(year) stat(n mean sd) format(%9.4f)

compress
save "Base_Multinivel_PCA.dta", replace

display _newline "{hline 78}"
display "ÍNDICE CONSTRUIDO: Base_Multinivel_PCA.dta"
display "Siguiente: 07_imputacion.do (MICE con 20 imputaciones)."
display "{hline 78}"

log close fase6

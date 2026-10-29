# Desempeño en Saber 11 en las sedes oficiales del Cauca, 2018-2023: cadena de Stata

Código de la tesis de pregrado en Economía de Juan Pablo Muñoz Paz (Universidad del Cauca, 2026), *Análisis multinivel del desempeño escolar: una evaluación de los efectos institucionales y macro-territoriales del Cauca en el sector oficial (2018-2023)*, dirigida por Juan José Caicedo Collazos. El estudio usa modelos multinivel de estudiante, sede y municipio sobre las cohortes 2018-2023 de Saber 11.

- **DOI de esta versión:** [10.5281/zenodo.23777593](https://doi.org/10.5281/zenodo.23777593)
- **Repositorio:** https://github.com/juan0309-eco/Analisis-Multinivel-Cauca
- **Cómo citar:** Muñoz Paz, J. P. (2026). *Cadena de procesamiento en Stata de «Análisis multinivel del desempeño escolar: una evaluación de los efectos institucionales y macro-territoriales del Cauca en el sector oficial (2018-2023)»* (Versión 1.0) [Software]. Zenodo. https://doi.org/10.5281/zenodo.23777593

El repositorio contiene los do-files, los registros de ejecución (logs) y este archivo. **No contiene datos**: ni los microdatos ni los paneles construidos a partir de ellos. Las fuentes se descargan de los portales oficiales del apartado 2 y se citan en el apartado «Fuentes de datos y software» del informe.

---

## 1. Contenido

| Carpeta o archivo | Qué es |
|---|---|
| `do/` | Los 30 do-files de la cadena, del `01` al `18`, y cuatro herramientas: `00_config.do`, `00_master.do`, `00_validar.do` y `99_huella.do` |
| `do/archivo/` | Siete versiones superadas que conservan la evidencia de logs citados (apartado 6) |
| `logs/` | Los registros de ejecución que respaldan las cifras del informe, con su nombre original |
| `logs/verificacion/` | El registro de la prueba de la cadena completa en la carpeta de verificación |
| `README.md` | Este archivo |
| `LICENSE` | Licencia MIT del código |
| `CITATION.cff` | Datos de citación, que leen GitHub y Zenodo |

**Licencias.** Los do-files se distribuyen con la licencia MIT (`LICENSE`). Los logs y este README, con la licencia Creative Commons Atribución 4.0 Internacional (CC BY 4.0).

**Datos personales.** Los logs muestran tablas agregadas, códigos DANE de municipio y conteos. No listan registros de estudiantes ni nombres de sedes.

---

## 2. Fuentes de datos y dónde descargarlas

Ninguna fuente se redistribuye aquí. Los nombres de archivo son los que esperan los do-files: si el portal entrega otro nombre, hay que renombrarlo o ajustar el script. La columna «Consulta» da la fecha del archivo que usó la cadena.

| # | Fuente | Entidad | Dónde descargar | Qué se usa | Archivo que espera la cadena | Consulta | Script |
|---|---|---|---|---|---|---|---|
| 1 | Resultados de Saber 11, periodo 2 de cada año (calendario A), 2018-2023 | Instituto Colombiano para la Evaluación de la Educación (ICFES) | DataIcfes, con registro: https://www.icfes.gov.co/investigaciones/data-icfes/. Página de las bases de Saber 11 en DataIcfes 2.0 (exige inicio de sesión): https://icfesgovco.sharepoint.com/sites/DataIcfes2.0/SitePages/Saber11_Bases-y-documentaci%C3%B3n%20t%C3%A9cnica.aspx `[por verificar]` | Microdatos individuales del examen y del cuestionario socioeconómico; índice socioeconómico (INSE) | `Examen_Saber_11_<año>2.txt`, un archivo por año, separado por punto y coma | 25-02-2026 | 01 |
| 2 | Educación Formal (EDUC), formulario C-600, 2018-2023 | Departamento Administrativo Nacional de Estadística (DANE) | Archivo Nacional de Datos, colección «Educación»: https://microdatos.dane.gov.co/index.php/catalog/EDU-Microdatos. Catálogos por año: 2018 = 615, 2019 = 669, 2020 = 722, 2021 = 752, 2022 = 801, 2023 = 834 (`https://microdatos.dane.gov.co/index.php/catalog/<número>`) | Módulos por sede: «Alumnos matriculados por jornadas y nivel educativo (educación tradicional, CLEI y modelos educativos)»; «Máximo nivel educativo alcanzado por los docentes…»; «Docentes ocupados en la sede educativa según escalafón y tipo de vinculación laboral»; «Tenencia y número de equipos de cómputo por sede educativa» (en los años recientes, «Tenencia y número de bienes TIC por sede educativa») | `Panel_matricula.xlsx`, `Panel_doc.xlsx`, `Panel_estabilidad.xlsx` y `Panel_tic.xlsx` (hojas `2018_tic` a `2023_tic`). Son paneles nacionales por sede y año que el autor armó con esos módulos, fuera de la cadena (nota 1) | Matrícula: 06-03-2026. Docentes y estabilidad: 10-03-2026. TIC: 15-08-2026 | 02, 03 |
| 3 | TerriData, series municipales 2017-2022, corte de diciembre | Departamento Nacional de Planeación (DNP) | https://terridata.dnp.gov.co/ | Asignación del SGP para libre inversión y demás asignaciones (origen SICODIS); inversión ejecutada e ingresos tributarios (origen FUT); superficie sembrada con coca; Índice de Incidencia del Conflicto Armado; eventos de minas antipersonal; tasa de homicidio intencional; deserción intraanual; cobertura neta en media | `Panel_inversion.xlsx`, con las hojas `Panel_inversion` y `Panel_caracterizacion` | 18-08-2026 | 04 |
| 4 | Presuntos homicidios | Instituto Nacional de Medicina Legal y Ciencias Forenses | Portal Nacional de Datos Abiertos, conjunto «Presuntos Homicidios. Colombia, 2015 a 2024. Cifras definitivas»: https://www.datos.gov.co/Justicia-y-Derecho/Presuntos-Homicidios-Colombia-2015-a-2024-Cifras-d/vtub-3de2 | Numerador de la tasa municipal de homicidios | `Panel_homicidios.xlsx`: hoja `Panel_homicidios` (municipio, año, homicidios y población) y hoja con los registros individuales descargados | 14-03-2026 (CSV exportado el 11-03-2026) | 04 |
| 5 | Población municipal por área, sexo y edad: series 2005-2017 y 2018-2042 | DANE | https://www.dane.gov.co/index.php/estadisticas-por-tema/demografia-y-poblacion/proyecciones-de-poblacion. Archivos: https://www.dane.gov.co/files/censo2018/proyecciones-de-poblacion/Municipal/DCD-area-sexo-edad-proypoblacion-Mun-2005-2017_VP.xlsx y https://www.dane.gov.co/files/censo2018/proyecciones-de-poblacion/Municipal/PPED-AreaSexoEdadMun-2018-2042_VP.xlsx | Denominador de la tasa de homicidios: total general del municipio (2017 de la serie 2005-2017; 2018-2022 de la serie 2018-2042) | Columna `pob` de `Panel_homicidios.xlsx` | 14-03-2026 | 04 |
| 6 | Índice de precios al consumidor (IPC), variación anual diciembre a diciembre | DANE | https://www.dane.gov.co/index.php/estadisticas-por-tema/precios-y-costos/indice-de-precios-al-consumidor-ipc | Deflactor de las series fiscales (pesos de 2018) | `IPC anual desde el año 1955 a 2025.xlsx`, hoja `IPC 1955 A 2025`, encabezados en la fila 4 | 12-08-2026 | 04 |

**Nota 1. Los paneles del DANE.** El 02 y el 03 leen los cuatro paneles ya armados. Cada uno apila, para 2018-2023, el módulo correspondiente del C-600 y deja una fila por sede y año (`cole_cod_dane_sede`, `periodo`). Las variables que lee el 02 son `matricula`; `docentes` y `pct_posgrado`; `docentes`, `pct_planta` y las cuatro proporciones por escalafón y vinculación. El 03 lee `sede_codigo`, `periodo_id`, `periodo_anio`, `equipocom_id`, `equipocom_nombre`, `sedecom_cantidad`, `sedecom_cant_sinuso` y, desde 2021, `sedecom_cant_presta` y `sedecom_cant_sede`.

**Nota 2. Los archivos del ICFES.** Los seis archivos que usó la cadena contienen solo registros del Cauca: 14.211 en 2018, la cifra de «Registros brutos del archivo» de la Tabla 24 del informe. Si se descarga un archivo con todo el país, el filtro 5.1 del 01 lo recorta al Cauca y la primera fila de esa tabla cambia. Los filtros siguientes no cambian.

**Nota 3. El IPC.** El archivo reúne la variación anual del IPC de 1955 a 2025, con la nota «Fuente: DANE». Los años que usa la cadena son 2017 a 2022.

**Condiciones de uso.**
- **DANE** (fuentes 2, 5 y 6): sus términos autorizan «el uso, aprovechamiento, transformación y análisis» de la información, con la cita «Fuente: Departamento Administrativo Nacional de Estadística: www.dane.gov.co». La ficha del C-600 de 2020 la describe como de uso público y gratuito.
- **Datos abiertos** (fuente 4): el portal publica con la licencia Creative Commons Atribución-CompartirIgual 4.0. La licencia del conjunto debe confirmarse en su ficha.
- **ICFES** (fuente 1): DataIcfes exige registro y no publica una licencia.
- **TerriData** (fuente 3): las condiciones no pudieron consultarse.

Por todo eso, el repositorio no incluye datos.

**Software.** Stata 17 (StataCorp, 2021) y cuatro paquetes de SSC: `estout` (Jann, 2007), `mimrgns` (Klein, 2014; SSC S457795), `boottest` (Roodman et al., 2019) y `oaxaca` (Jann, 2008). Se instalan con `ssc install <paquete>`. `00_config.do` avisa si falta alguno.

---

## 3. Antes de correr

1. Crear dos carpetas: una para los do-files y otra para los datos.
2. Copiar los archivos del apartado 2 en la carpeta de datos.
3. Abrir `00_config.do` y cambiar las dos rutas, que hoy apuntan a la máquina del autor:
   - `RAIZ_DO`, la carpeta de los do-files (hoy `C:\Users\RYZEN 5\Desktop\Tesis Multinivel\Definitivo`);
   - `RAIZ_REAL`, la carpeta de los datos (hoy `…\Tesis Multinivel\Objetivo 2`).
4. Cambiar la misma ruta en la primera línea de cada do-file: `if "$TESIS_CONFIG" == "" do "…\00_config.do"`. Esa línea solo se usa cuando el script se corre suelto, sin el master.

Todo script empieza igual:

```stata
if "$TESIS_CONFIG" == "" do "C:\…\Definitivo\00_config.do"
cd "$RAIZ"
```

---

## 4. Cómo correr

**Desde el master (`00_master.do`).**
1. `local modo` en `"normal"` o `"verif"`. El modo `verif` trabaja en `verificacion/`, una copia con las bases imputadas en M = 2, y nunca toca la carpeta real.
2. Poner en 1 los interruptores de los scripts que se quieren correr. Todos vienen en 0: correr el master sin editarlo no hace nada.
3. Cambiar el `local hoy` de cada script encendido. Si su log ya existe, el guard lo detiene con r(602).
4. En modo normal, los scripts que sobrescriben bases o `.ster` sin fecha exigen además `permitir_reescribir = 1`.

**Un script suelto.** Abrirlo, cambiar su `local hoy` y correrlo.

**Reglas de registro.** Ningún log se sobrescribe. Los `.ster` y las tablas nuevas llevan la etiqueta `hoy` y no llevan `replace`. Los `.ster` sin fecha del 08, 10, 11 y 12 conservan su nombre, porque otros scripts los leen así; esos scripts se reejecutan solo en modo `verif`.

---

## 5. La cadena, en orden

Tiempos de los cronómetros de cada log; «—» = sin cronómetro.

| # | Script | Produce | Tiempo |
|---|---|---|---|
| 01 | `01_depuracion_N1_ICFES_v2.do` | Base de estudiantes depurada | — |
| 02 | `02_panel_sedes_N2_v2.do` | Panel de sedes sin TIC | — |
| 03 | `03_panel_tic_N2_v2.do` | Panel de sedes completo | — |
| 04 | `04_panel_municipal_N3_v5.do` | Panel municipal | — |
| 05 | `05_ensamblaje_v2.do` | Base de tres niveles | — |
| 06 | `06_pca_vulnerabilidad_v3.do` | Índice de vulnerabilidad y descomposición | — |
| 07 | `07_imputacion_v3.do` | Imputación múltiple, M = 20 | 16.616,32 s |
| 07b | `07b_reparar_y_unir_v2.do` | Base imputada | — |
| 07c | `07c_actualizar_nivel3.do` | Nivel 3 en la base imputada (la sobrescribe) | — |
| 08 | `08_estimacion_v5.do` | Modelos nulos y progresión por cohorte | 20.774,50 s |
| 10 | `10_blindaje.do` | Verificaciones del Anexo F | 1 h 44 min |
| 10b | `10b_planta_fe_v2.do` | Planta docente con efectos fijos (Tabla 13) | — |
| 11a | `11a_ensayo_estructura.do` | Ensayo; no alimenta el informe | — |
| 11 | `11_estructura_aleatoria.do` | Estructura de cuatro componentes, ML1b–ML4b | 14.645,60 s |
| 11b | `11b_emd.do` | Efecto mínimo detectable | — |
| 11c | `11c_tabla14.do` | Pendientes anuales de ML4b (Tabla 30) | — |
| 12 | `12_composicional.do` | Composición permanente y de cohorte (Tabla 16) | 4.087,56 s |
| 13 | `13_cohortes_oaxaca.do` | Contrastes entre cohortes y Oaxaca–Blinder | 3.002,16 s |
| 14 | `14_sensibilidad_diagnosticos.do` | Casos completos, submuestras y diagnósticos | 29 min + 1 h 23 min + 4 min |
| 14b | `14b_cierre_bloque1.do` | Cierre del bloque 1 del 14 | — |
| 14c | `14c_popayan.do` | Descomposición sin Popayán | 2.793,06 s |
| 15a | `15a_ensayo_gradiente.do` | Ensayo; no alimenta el informe | — |
| 15 | `15_gradiente_medicion.do` | Heterogeneidad del gradiente | 8 h 30 min |
| 15b | `15b_lecturas.do` | Combinaciones lineales del 15 | — |
| 15c | `15c_figuras.do` | Figuras 6 y 7 | — |
| 16a | `16a_rehacer_base.do` | Base de estimación con el Nivel 3 ampliado | 137,08 s |
| 16 | `16_territorial.do` | Validez de los indicadores territoriales | 3.409,31 s |
| 17 | `17_diagnosticos_C7_v2.do` | Diagnósticos de los municipios sin homicidios registrados; Figuras 8 a 10 | 160,83 s |
| 18 | `18_robustez_R1R3.do` | R1b y R3b con cuatro componentes | 2.899,32 s |
| 09 | `09_tablas_graficos_v6.do` | Tablas 12 y 42, tabla del Objetivo 4, robustez y figuras | — |

El 09 va al final en el master porque lee los `.ster` del 11, del 15 y del 18. La construcción y la estimación (01 a 09) suman al menos 10 h 23 min; las verificaciones, al menos 20 h 46 min (Anexo E, Tabla 37).

**Cadena mínima cuando cambia el Nivel 3:** 04 → 06 → 07c → 16a, sin repetir el 07 ni el 08.

---

## 6. Archivos superados (`do/archivo/`)

| Archivo | Por qué se conserva |
|---|---|
| `00_master_1.do` | Roto; se guarda como antecedente |
| `04_panel_municipal_N3_v4.do` | Su log (`log_04_panel_municipal_N3.log`) respalda las Tablas 9 y 28 y el Anexo F.4 |
| `06_pca_vulnerabilidad_v2.do` | Su log (`log_06_pca_vulnerabilidad.log`) respalda las Tablas 25 a 28 del Anexo B |
| `07c_actualizar_nivel3_preC7.do` | Produjo `log_07c_actualizar_n3.log`. No correr |
| `09_tablas_graficos_v5.do` | Superado por el v6. Produjo `log_09_tablas.log` |
| `16_territorial_1.do` | Duplicado del 16. Produjo `log_16_territorial_20261019c.log` |
| `17_diagnosticos_C7.do` | Superado por el v2. Produjo `log_17_diagnosticos_C7_20261022.log`, cuyo bloque [2] termina en r(459) |

---

## 7. Comprobaciones

| Herramienta | Uso |
|---|---|
| `00_validar.do` | Lee los do-files como texto y busca 13 tipos de defecto y los scripts que faltan (V8). Cambiar `local hoy` y correrlo |
| `99_huella.do` | Guarda b, se y varianzas de cada `.ster` y compara dos huellas valor por valor |

Resultados:
- Huella idéntica antes y después de la reorganización de los do-files: 116 `.ster`, 7.159 valores, 0 distintos (`log_99_huella_comparar_20261024b.log`). La carpeta real tampoco cambió con la prueba de la cadena (`log_99_huella_comparar_20261024c.log`).
- Prueba de la cadena en `verificacion/`: 15 scripts terminados con código 0 (`logs/verificacion/log_00_master_20261024v.log`).
- Validador al 29-10-2026: 33 do-files revisados, 0 hallazgos abiertos y 0 de 33 archivos ausentes (`log_00_validar_20261029b.log`).
- El 09 v6 reproduce las cifras de control del informe (`log_09_tablas_20261029.log`; figuras con coma decimal en `log_09_tablas_20261029b.log`).

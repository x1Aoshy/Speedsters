# Datos post-publish (build 09-22): "+1 Speed Speedster Escape"

Universo 10447471170. Informe de datos escrito el 2026-09-24 y complemento de `INFORME.md` (misma carpeta). Todas las cifras salen de CSV de Creator Hub exportados el 09-24 entre las 22:17 y las 22:25 hora local (≈04:25Z del 09-25). Las series largas vienen de `DataAnalysis/`. Cinco análisis (retención, monetización, funnels, estabilidad y descubrimiento) pasaron por un verificador que recalculó cada cifra. Aquí solo uso las conclusiones marcadas como **correctas** o con **error menor**, ya corregidas. Cuando una conclusión rechazada aporta algo, lo indico.

**Convenciones**
- Fechas de los CSV diarios en **UTC**. Los archivos de rendimiento y errores usan ventanas de 04:00Z a 04:00Z, que equivalen al día local (UTC-6).
- R$ = Robux netos.
- "Impresiones" = *unique users with impressions*, que no es lo mismo que el número de impresiones.
- `[N]` = carpeta `newdata 24 09 26`. `[DA]` = carpeta `DataAnalysis`. Abrevio los nombres de archivo quitando el rango de fechas cuando no hay ambigüedad.
- Las copias "(1)" de impresiones y plays son idénticas byte a byte (md5) y cuento cada una una sola vez.

**Límites de los datos**
- Los archivos **diarios** (DAU, sesiones, D1, ingresos por fuente, impresiones) terminan el **09-23**. Solo hay **un día completo post-publish** con DAU, D1 de cohorte y pagadores.
- Los ingresos en tiempo real y los funnels llegan al **09-24**. El 09-25 solo tiene ≈4 h, así que es **parcial**.
- La hora exacta del publish del 09-22 **no aparece en ningún CSV**. Por eso el 09-22 se trata como día mixto.

---

## 1. Veredicto en 10 líneas

1. **Errores: sí, el publish los arregló.** Errores y warnings pasaron de 3,465,132 a 101,153 por día (−97%, −93% por CCU), mejor que el objetivo de ≈0.33M. Ninguna firma arreglada el 09-22 sigue en el top 25 (`[N]/[DA] Errors and warnings…`, `…by count.csv`). H16 queda cerrado.
2. **Rendimiento: mejora moderada a nivel Total.** FPS 27.53 → 29.36 (+7%). CPU de cliente 11.02 → 9.31 ms (−15.5%). Crash y memoria no cambian. **No se puede confirmar si los tiers de teléfono funcionan**, porque la exportación nueva no trae el desglose por plataforma.
3. **D1 sube, pero no se puede atribuir al publish.** La cohorte del 09-22 tiene 12.74%, la mejor desde el 09-12. Pero el 09-17 y el 09-18 ya estaban en 11.3% y 10.6%, y la cohorte del 09-22 se unió en parte con el build viejo. La primera cohorte limpia (09-23) se puede leer a partir del **09-25**.
4. **Sesión: sin efecto visible.** La sesión media volvió a ≈11 min el **09-20**, antes del build, y el 09-23 marca 10.48 con un cambio fuerte en la mezcla de jugadores. Las sesiones por DAU siguen en 1.26-1.31, frente a 1.41 antes del 09-13.
5. **Ingresos por jugador: sin cambios.** Comparando miércoles con miércoles, la conversión es 0.347% frente a 0.350% y el ARPDAU 0.336 frente a 0.332. El total cae porque cae el DAU, no por el build.
6. **La caída de ingresos del 09-21 fue de tráfico.** Impresiones Home −75% y DAU −68%, mientras la conversión y el ARPDAU subieron. Esto responde la pregunta que dejó abierta INFORME 1.2.
7. **Funnels:** el desbloqueo de World 2 entre nuevos se multiplica por ≈4.5 con la puerta de 6R+L50 (el requisito de L50 nunca es el que frena). La recompensa AFK se multiplica por 2-3, pero sigue en 3-4%. El primer paso en la cinta no cambia (88-90%).
8. **Lo más roto hoy es el descubrimiento.** El 09-23 tuvo 280,987 impresiones (−73% frente al 09-22), el mínimo desde el 08-26. Los nuevos usuarios netos fueron ≥4k.
9. **Otras cosas que siguen rotas:**
   - La conversión está en 0.35%, frente a 1.1% antes del 09-13, porque no hay SKU barato (H14).
   - El funnel de la ruleta de pago no mide nada (M28).
   - La escalera de rebirth pierde un ≈40% por peldaño en la primera sesión.
   - Solo un ≈20% de quienes eligen quest la reclaman.
10. **Conclusión:** el build arregló la estabilidad, pero **no hay todavía evidencia de efecto en retención ni en tráfico**. Hacen falta 3-4 cohortes (09-23..09-26) y las impresiones de 09-24 a 09-29.

---

## 2. Línea de tiempo actualizada (08-22 → 09-24)

### 2.1 Por semana

Fuentes: `[N] Daily active users-`, `Day 1 retention-`, `Average session time-`, `Average playtime-`, `Sessions-`, `Robux sources-`, `Paying users-`, `Payer conversion rate-`, `Universe- Unique users with impressions`. Los meses anteriores salen de las versiones `[DA]` de los mismos archivos, sin revisiones entre exportaciones.

| Semana (UTC) | DAU/día | Impresiones/día | D1 (media de cohortes) | Sesión (min) | Juego/DAU (min) | Sesiones/DAU | Ingresos R$/día | Pagadores/día | Conversión |
|---|---|---|---|---|---|---|---|---|---|
| 08-23..08-29 | 46,379 | – | 11.01% (08-18..24) | – | – | – | 14,250 | 364 | 0.78% |
| 08-30..09-05 | 259,707 | 3,995,774 | 15.93% (08-25..31) | – | – | – | 105,478 | 2,972 | 1.14% |
| **09-06..09-12 (pre-U2)** | 257,404 | 5,307,856 | **14.80%** | **11.93** | **16.79** | **1.407** | **118,511** | **2,883** | **1.12%** |
| 09-13..09-19 (U2) | 197,772 | ≈3.84M | 9.09% | 9.44 | 12.10 | 1.281 | 65,805 | 751 | 0.38% |
| 09-20..09-23 | 102,228 | – | 9.51% (09-20..22) | – | – | – | 40,968 | 366 | 0.36% |

### 2.2 Por día (09-12 → 09-24)

Las fuentes son las mismas. D1 es el de la **cohorte** que entró ese día.

| Fecha | Marca | DAU | Impresiones | D1 cohorte | Sesión | Juego/DAU | Ses./DAU | Ingresos R$ | Pagadores | Conv. |
|---|---|---|---|---|---|---|---|---|---|---|
| 09-12 | Publish U2 (~18:30-21:40Z) | 308,685 | 5,559,734 | 13.46% | 11.36 | 16.27 | 1.432 | 150,720 | 3,112 | 1.01% |
| **09-13** | **1.er día U2** | 332,192 | 4,909,226 | **6.67%** | 9.02 | 11.75 | 1.304 | 107,933 | **1,446** | **0.44%** |
| 09-14 | | 227,487 | 4,603,139 | 8.89% | 9.26 | 11.53 | 1.245 | 71,340 | 934 | 0.41% |
| 09-15 | | 241,859 | 6,146,258 | 8.27% | 9.07 | 11.42 | 1.259 | 68,779 | 890 | 0.37% |
| **09-16** | **Impresiones −55%** | 140,727 | **2,770,207** | 9.25% | 9.32 | 11.88 | 1.274 | 46,774 | 493 | 0.35% |
| 09-17 | | 145,337 | 2,868,826 | 11.32% | 9.90 | 12.80 | 1.294 | 54,484 | 508 | 0.35% |
| 09-18 | | 131,275 | 2,584,150 | 10.56% | 9.90 | 12.99 | 1.312 | 49,720 | 423 | 0.32% |
| 09-19 | Update 3 (~17:06Z según INFORME) | 165,526 | 2,981,323 | 8.69% | 9.63 | 12.30 | 1.277 | 61,606 | 565 | 0.34% |
| 09-20 | Pico de domingo | 221,510 | 4,422,222 | **5.45%** | 10.94 | 13.74 | 1.256 | 82,578 | 688 | 0.31% |
| **09-21** | **Publish del 09-20 (~03:55Z, INFORME); caída de tráfico** | **70,500** | **1,154,970** | 10.34% | 11.01 | 14.11 | 1.282 | **34,228** | 330 | 0.47% |
| **09-22** | **Publish "final fixes" (hora desconocida; día mixto)** | 80,885 | 1,057,160 | **12.74%** | 11.01 | 13.94 | 1.265 | 34,957 | 320 | 0.40% |
| 09-23 | 1.er día completo post-publish | **36,018** | **280,987** | disponible ≈09-25 | 10.48 | 13.69 | 1.306 | **12,110** | 125 | 0.35% |
| 09-24 | | sin export | sin export | ≈09-26 | – | – | – | 21,881 (tiempo real) | – | – |

Notas:
- El 09-20 tiene la peor D1 **desde el 08-12**, que fue 3.90% en la semana de lanzamiento. No es la peor de la historia.
- La cifra de 09-24 sale de `[N] Robux Spent (Realtime)- … 08-29..09-25`.
- El 09-23 está **completo**: las 24 filas horarias de `[N] Hourly Robux spent` suman 12,110, igual que el diario.

---

## 3. Retención y engagement

**D1 por cohorte** (`[N] Day 1 retention- … 08-05..09-22.csv`, fila Total; las 3 exportaciones coinciden):

| Día | Semana 08-30..09-01 | Semana 09-06..08 | Semana 09-13..15 | Semana 09-20..22 |
|---|---|---|---|---|
| Domingo | 14.10 | 14.42 | 6.67 | 5.45 |
| Lunes | 16.33 | 14.07 | 8.89 | 10.34 |
| Martes | 17.21 | 15.20 | 8.27 | **12.74** |

- **La cohorte del 09-22 mejora +4.5 pp frente al martes anterior** y cierra un ≈64% de la brecha del 09-13 (14.80 → 9.09).
- **No es el comienzo de una tendencia nueva.** El 09-17 (11.32) y el 09-18 (10.56) ya estaban a ese nivel. El 09-19 (8.69) y el 09-20 (5.45) fueron un bache intermedio.
- La cohorte del 09-22 se unió en parte con el build viejo. **No se atribuye al publish** hasta que las cohortes del 09-23 y el 09-24 se mantengan en ≥12%.
- La proporción de plays desde Home Recommendation fue 75.4% el 09-22 y 76.8% el 09-15 (`[N] Universe- Unique users with plays`). Por eso **no es un efecto de cambio en las fuentes de tráfico**. Que el algoritmo, más restringido, esté enviando usuarios con más intención es una **hipótesis** que no se ha probado.
- **Tamaño de muestra:** la cohorte del 09-23 tiene entre ≈4k y ≈13k nuevos, así que el error es de ≈±1 pp. Con eso se puede ver un movimiento de ≥3 pp, pero hacen falta 3-4 cohortes para confirmarlo.

**Engagement.** El 09-20 subió antes del build; después del 09-22 no hay mejora adicional.

| Periodo | Sesión media (min) | Juego/DAU (min) | Sesiones/DAU |
|---|---|---|---|
| 09-06..12 | 11.93 | 16.79 | 1.407 (rango 1.38-1.43) |
| 09-13..19 | 9.44 | 12.10 | 1.281 |
| 09-20 / 21 / 22 | 10.94 / 11.01 / 11.01 | 13.74 / 14.11 / 13.94 | 1.256 / 1.282 / 1.265 |
| 09-23 | 10.48 | 13.69 | 1.306 |

Fuentes: `Average session time-`, `Average playtime-`, `Sessions-` y `Daily active users-`.

- La sesión media ha recuperado un ≈63% de la brecha y el juego por DAU un ≈39%.
- Las **sesiones por DAU no se han recuperado** desde el 09-13.
- La bajada del 09-23 (−0.53 min) cabe dentro del cambio de mezcla: los nuevos eran el 58.9% del DAU el 09-22 y el 11.2% el 09-23. El área bajo la curva de primera sesión es 11.90 min.
- La mezcla también contamina las sesiones por DAU, así que el 1.306 del 09-23 **no es una señal limpia del build**.
- El salto del 09-20 coincide con Update 3 (AFK Mode). **Hipótesis:** AFK podría inflar la sesión sin que haya engagement real.

**Serie de 30 min, "Session time by place"** (media de 49 intervalos; es otra base distinta del diario):

| Ventana | Media (min) | Mediana (min) | Archivo |
|---|---|---|---|
| 09-19 | 7.99 | – | `[DA] …2026-09-18T22…` |
| 09-21 (local) | 8.98 | – | `[DA] …2026-09-21T04…` |
| 09-23 (local) | 8.25 | 7.89 | `[N] …2026-09-24T04…`, serie "previous" |
| 09-24 (local) | 8.06 | 8.02 | `[N] …2026-09-24T04…`, serie "current" |

Tampoco aquí hay señal de mejora. El archivo nuevo no tiene desglose por plataforma.

**Base de jugadores que vuelven** (proxy = DAU − delta del MAU diario; es un límite superior):

| Periodo | Jugadores que vuelven |
|---|---|
| 09-06..12 | ≈72.7k/día |
| 09-13..19 | ≈54.3k/día |
| 09-20 | 56.0k |
| 09-21 | 33.0k |
| 09-22 | 33.2k |
| 09-23 | 32.0k |

- Fuentes: `Daily active users-` y `Monthly active users by day-`.
- La caída de domingo a lunes del 09-20 al 09-21 es de −41%. En semanas anteriores fue de +1% (09-06 → 09-07) y de −25% (09-13 → 09-14).
- **Hipótesis:** el recorte del Daily y la pérdida de superficies de Home afectaron también a los jugadores que vuelven.
- Este proxy **dejará de funcionar a partir de ≈09-28**, cuando las cohortes grandes de septiembre salgan de la ventana de 30 días y el delta del MAU se vuelva negativo.

**D7** (`[N] Day 7 retention- … 07-30..09-16`):

| Cohortes | D7 | D7/D1 |
|---|---|---|
| 08-25..31 | 1.89% | 11.9% |
| 09-01..07 | 1.21% | 7.6% |
| 09-06..12 | 1.04% | 7.0% |
| 09-13..16 | 0.68% | 8.2% |

- **El D7 ya caía antes del 09-13.** Recuperar D1 no devolverá por sí solo el D7 al 2%.
- No hay D7 de ninguna cohorte posterior al 09-16. El D30 solo existe hasta la cohorte del 08-24 y es ruido.

**Primera sesión** (`New user first session retention`, agregados de 28 días): los agregados no se mueven.

| Ventana | A 90 s | A 5 min | A 10 min |
|---|---|---|---|
| 08-22..09-18 | 84.71% | 67.00% | 49.51% |
| 08-24..09-20 | 84.80% | 66.51% | 48.92% |
| 08-27..09-23 | 84.83% | 66.45% | 48.84% |

- Una estimación aproximada, **solo como hipótesis**, sugiere que las cohortes del 09-19 y el 09-20 perdieron más jugadores entre los minutos 3 y 10: ≈59% seguían a los 5 min y ≈40% a los 10 min.
- Que el 09-21 y el 09-22 volvieran a lo normal **no es robusto**: depende del supuesto usado para la estimación.
- Los primeros 90 s no han empeorado en ninguna ventana.

**Stickiness (DAU/MAU)** no sirve ahora como métrica de engagement. Estaba en 0.105 en 09-06..12 y en 0.0084 el 09-23 (`Stickiness (DAU-MAU)-`), porque el MAU (4.31M) está inflado por la llegada masiva de septiembre.

---

## 4. Monetización

### 4.1 Qué pasó el 09-21

| Métrica (archivo) | 09-19 | 09-20 | 09-21 | Cambio 20 → 21 |
|---|---|---|---|---|
| Ingresos (`Robux sources-`) | 61,606 | 82,578 | 34,228 | −58.6% |
| DAU (`Daily active users-`) | 165,526 | 221,510 | 70,500 | −68.2% |
| Impresiones Home (`Unique users with impressions`) | 2,811,846 | 4,297,431 | 1,076,448 | −75% |
| Plays Home (`Unique users with plays`) | 83,612 | 128,218 | 28,106 | −78% |
| Pagadores (`Paying users-`) | 565 | 688 | 330 | −52% |
| Conversión (`Payer conversion rate-`) | 0.34% | 0.311% | 0.468% | sube |
| ARPDAU (`ARPDAU`) | 0.372 | 0.373 | 0.486 | +30% |
| ARPPU (`ARPPU`) | 109.0 | 120.0 | 103.7 | **−14%** |

- **La caída es de tráfico.** La conversión y el ARPDAU subieron (el ARPPU bajó).
- Parte de la subida por DAU puede ser un efecto de mezcla, con menos nuevos que pagan poco. Es una **hipótesis**.
- El 09-20 no fue un pico de monetización. El ARPDAU del 09-17 al 09-20 fue 0.375 / 0.379 / 0.372 / 0.373. Lo único que subió por jugador fue el cubo "Other" de productos de desarrollador, de 103 a 148 R$ por cada 1k DAU. Que eso se deba a los SKU nuevos de Update 3 (packs de la ruleta, AFK x5) es **hipótesis**.
- **Por horas** (`[DA]` horarios 09-19T03… y `[N] Hourly Robux spent`):
  - Entre las 00 y las 04Z del 09-21 se ingresaron 7,253 R$, frente a 10.6-13.7k del 09-17 al 09-19 (−32 a −47%).
  - Entre las 04 y las 14Z, después del publish de ~03:55Z, se ingresaron 7,115, frente a 15.4-19.1k (−54 a −63%). La caída **se hizo más profunda después del publish**.
  - Con 4 h de datos no se puede ni culpar ni exculpar al build. Los datos horarios son ruidosos: una sola venta vale 559 R$.

### 4.2 La ruptura real es el 09-13 (confirma H14)

- Los productos de desarrollador x2, x4 y x10 Speed de la OG y Flight (producto) vendían ≈22.7k R$/día en 09-06..12 (22,362 el 09-12). Desde el **09-13 venden 0** (`[N] Universe- Robux Spent (Realtime) … 08-29..09-25.csv`).
- El x2 a 3 R$ vendía ≈2,070 unidades/día. Los pagadores bajaron de 2,883 a 751 por día. La coincidencia casi 1:1 **no es evidencia**: una unidad no es un comprador único.
- **Los pases aguantaron:** 184.7 R$ por cada 1k DAU en 09-06..12 frente a 182.5 en 09-13..19. Los productos de desarrollador cayeron de 275.7 a 150.3. Hacker Treadmill es ≈52% de los pases.
- **Corrección a INFORME §6** (M10):
  - Revive se vende a **18 R$ netos (≈25-26 R$ de lista)**, no a 9. Son ≈25 unidades/día ahora, frente a ≈400/día antes del 09-13.
  - Flight (producto) se vendía a 175 netos (≈250 R$) desde el 08-31, no a 79. El salto fue de ≈250 a 799, no de 79 a 799.
- **Speed Tier 4** (3641610998) vendía con unidad de 245 R$ netos del 08-31 al 09-19. El 09-23, el 09-24 y el 09-25 los valores son múltiplos de 140 y no de 245. **Hay que confirmar en el dashboard** si se cambió el precio (a ≈200 R$) o si existe un segundo SKU con el mismo nombre.

### 4.3 Estado post-publish

| Comparación | Ingresos | DAU | Conversión | ARPDAU | ARPPU |
|---|---|---|---|---|---|
| Miércoles 09-23 frente a miércoles 09-16 | 12,110 frente a 46,774 (−74%) | 36,018 frente a 140,727 (−74%) | 0.347 frente a 0.350% | 0.336 frente a 0.332 | 96.9 frente a 94.9 |
| Jueves 09-24 frente a jueves 09-17 | 21,881 frente a 54,516 (−60%) | sin export | – | – | – |

- El dinero por jugador **no empeoró ni mejoró**. Esto se apoya solo en el 09-23, con 125 pagadores.
- Entre las 14 y las 24Z del 09-22 (hacia el publish) se ingresaron 20,991 R$, frente a 19,860 el día anterior. No hay señal de compras rotas.
- **El 09-23 es el día con menos ingresos desde el 08-26** (7,937).
- **Ofertas casi muertas** (lista para vigilar; las muestras son de unidades sueltas):
  - Secret Trail y Secret Aura: 1 venta cada una del 09-20 al 09-25 (M61).
  - Infinite Revives: 2 ventas.
  - Starter Pack: 45 → 40 → 10 → 6 → 1 → 5 unidades/día del 09-19 al 09-24.
- **"Other" es el 74-88% del ingreso de productos de desarrollador** (79% el 09-20, 88% el 09-23, 74% el 09-24). No se puede evaluar la escalera nueva, los packs de la ruleta, ClaimX5 ni los viajes con esta exportación.
- **Creator Rewards** (`Creator rewards earned-`):
  - Son exactamente 5 R$ por *rewarded active spender*, todo de tipo "Daily engagement".
  - Suman 527,720 R$ estimados para las fechas de juego del 08-11 al 09-23. Se liquidan a los 60 días: el primero el 10-10 y el pico (09-05, 42,530 R$) el 11-04.
  - Equivalen al 14-28% de lo que se gasta en Robux, y el porcentaje va bajando. El 09-23 fueron 2,635 R$.

---

## 5. Funnels: dónde se pierden hoy los jugadores

**Límites de estos datos:**
- Ningún CSV de funnel tiene cohortes anteriores al **09-19**, así que no se puede comparar antes y después del 09-13 con funnels.
- Hay dos generaciones de funnels:
  - **v1**: cohortes del 09-19 al 09-21. Tiene artefactos de backfill, por ejemplo Revive "Purchased 94%" = Dismissed. No se debe usar.
  - **v2**: desde el 09-21. Onboarding_Ladder_v2 empieza el 09-22.
- Solo hay tasas, no conteos.
- Solo el **09-23 y el 09-24** son días completos post-publish.

Abrevio `N25(k)` = `[N] Funnel step completion by cohort- … 2026-08-29…2026-09-25… (k).csv`.

**Puerta de World 2** (confirma que el cambio a 6 rebirths + L50 funciona):

| Puerta | Fuente | 09-19 | 09-20 | 09-21 | 09-22 (mixto) | 09-23 | 09-24 | 09-25 (parcial) |
|---|---|---|---|---|---|---|---|---|
| 7R + L100 | FTUE v1 `World2_Unlocked`, N25(0) | 2.30% | 3.01% | 2.77% | – | – | – | – |
| 6R + L50 | Ladder_v2 `World2Unlocked`, N25(8) | – | – | – | 17.45% | 12.58% | 13.12% | 12.36% |

- El aumento es de **≈4.5x** en días completos comparables (12.58 / 2.77 y 13.12 / 3.01).
- De Rebirth6 a World2Unlocked pasa el 99.7-100%, así que **el requisito de L50 nunca es el que frena**.
- No es un A/B limpio: son funnels distintos y la Ladder solo cuenta la primera sesión de servidor. Pero los dos sesgos juegan **en contra** de la Ladder.
- A la exportación de N25(8) le falta la fila del paso 1 ("Joined").

**Escalera de rebirth de los nuevos** (N25(8), 09-23 / 09-24, solo primera sesión, así que son **límites inferiores**):

| Tramo | Se pierde |
|---|---|
| Joined → Rebirth1 | 29.5% / 27.2% |
| Rebirth1 → Rebirth3 | ≈42% |
| Rebirth3 → Rebirth5 | ≈48% |
| **Rebirth5 → Rebirth6** (un solo peldaño) | **≈40%** |

Antes, cada rebirth individual perdía un 23-29%. El nivel requerido es lineal (5 + 15n, `RebirthSystem.server.luau:54-63`). Por eso el salto en el 5 → 6 apunta más a duración de sesión o cansancio que a un pico de coste. Es una **hipótesis**.

**Resto de pasos** (v2, % del paso 1):

| Funnel (archivo) | 09-21 | 09-22 | 09-23 | 09-24 | Lectura |
|---|---|---|---|---|---|
| Primer paso en la cinta, FirstTreadmillRun (N25(7)) | 89.42 | 90.50 | 88.23 | 89.12 | Plano. El 94.9-96.7% de v1 **no es comparable** (otra definición) |
| Commit de rebirth tras llegar al umbral (N25(6)) | 73.56 | 76.02 | 73.35 | 78.79 | Plano. ≈1/4 de los ciclos no hace rebirth (L33) |
| Quest: Chose / Done / Claimed (N25(11)) | 57.99 / 17.09 / 14.41 | 54.80 / 17.12 / 14.11 | 52.23 / 12.86 / 10.63 | 51.90 / 12.39 / 10.28 | Claimed/Chose baja de 24.8 a ≈20%. Claimed/Done ≈83%: **≈17% termina y no reclama** |
| Starter Pack, clic (N25(10)) | 8.00 | 7.41 | 6.19 | 6.03 | Compras implícitas 7 / 4 / 1 / 3 al día: ruido |
| Revive aplicado (N25(12)) | 0.073 | 0.073 | 0.040 | 0.070 | Casi 0 |
| Ruleta: tirada gratis (N25(9)) | 92.48 | 90.67 | 89.74 | 89.10 | Plano |
| Ruleta: prompt de pago (N25(13)) | 8.28 | 8.39 | 7.38 | 7.25 | **El paso de compra (PaidReceiptGranted) no aparece nunca** |
| AFK: RewardEarned (N25(16)) | 1.69 | 3.72 | 4.40 | 3.24 | Se multiplica por 2-3 con el arreglo, pero **≈96% sale antes de los 60 s** |

- **La bajada de Quests coincide con el publish.** El análisis original decía que era anterior, pero el verificador lo marcó como **erróneo**: el corte 00-04Z del 09-22 en `[DA]` es una foto truncada, no una base. La cohorte del 09-22, ya completa, está en 17.12 / 14.11, al nivel del 09-21, y la bajada aparece el 09-23. Con dos días no se puede atribuir en ninguna dirección.
- Tampoco se puede fechar antes del publish la bajada de clics del Starter Pack.
- **Wheel_Paid_v2 está roto por código.** El cliente manda `State{opened=isOpen}` cada 2 s (`SpinWheelController.client.luau:1450-1452`). El servidor abre una sesión nueva de funnel cada vez (`SpinWheelService.server.luau:446-447`). El paso del recibo (`SpeedProductPurchases.server.luau:1905`) necesita `had(3)` en la misma sesión (`FunnelAnalytics.luau:266`), así que no se registra nunca. v1 sí medía 20 / 47 / 2 tiradas de pago en las cohortes del 09-19 al 09-21 (conteos implícitos). Por eso **hoy no se puede medir la conversión de los packs de la ruleta**.

---

## 6. Estabilidad y rendimiento: antes y después

Ventanas de 30 min, 04Z a 04Z, n = 49 intervalos. Para el 09-21 uso `[DA] …2026-09-21T04…`. Para el 09-23 ("previous") y el 09-24 ("current") uso `[N] …2026-09-24T04…`. La alineación está verificada: la fila "previous" de las 09-25T04 es igual a la "current" de las 09-24T04.

| Métrica (archivo) | 09-19 | 09-21 (pre) | 09-23 (post) | 09-24 (post) | 09-24 frente a 09-21 |
|---|---|---|---|---|---|
| Errores + warnings/día (`Errors and warnings-`) | sin export | 3,465,132 | sin export | 101,153 | **−97.1%** |
| Errores por CCU-intervalo | – | 100.8 | – | 6.76 | −93% |
| — cliente / servidor | – | 2,701,429 / 763,703 | – | 95,265 / 5,888 | servidor −99.2% |
| FPS medio (`Client frame rate-`) | 30.01 | 27.53 | 29.94 | 29.36 | +6.7% |
| FPS ponderado por CCU | 28.63 | 27.35 | 29.86 | 29.48 | +7.8% (ya por encima del 09-19) |
| CPU de cliente, ms (`Client CPU time-`) | 13.58 | 11.02 | sin serie | 9.31 | −15.5% (animación −35%, física −24%, scripts −12%) |
| Memoria, GB / % (`Client memory usage…`) | 1.084 / 23.5 | 1.067 / 23.4 | 1.100 / 24.0 | 1.068 / 23.6 | igual |
| Crash rate (`Universe- Client crash rate`) | 0.0046 | 0.0050 | 0.0054 | 0.0047 | igual |
| OOM (`Unexpected out of memory exits-`) | 153 | 111 | 77 | 74 | por CCU sube, pero con conteos de 0 a 3 por intervalo y un posible suelo de reporte: no es fiable |
| CCU pico, media / máximo (`Peak concurrent players-`) | 1,551 / 4,511 | 701 / 1,319 | 335 / 497 | 305 / 397 | −56% / −70% |

**Matices:**
- El 69% de los errores del 09-21 vino de 8 picos de cliente (2.39M). Que fueran eventos de tacos es una **hipótesis**, porque el CSV no marca eventos.
- Comparado con la base del 09-21 sin esos picos, los errores de cliente por CCU bajan un **60%**, no un 92%.
- Ninguna firma del top 25 nuevo apareció por primera vez después del 09-20 21:55 local, así que **no entró ningún tipo de error nuevo**.
- Una firma antigua sí creció: `rbxassetid://10468693967` "not authorized" tiene 9,970 al día. En el 09-21 no estaba en el top 25, cuyo corte era 1,571, así que creció al menos ×6 en conteo y ×14 por CCU.
- **La estabilidad no explica la caída de CCU y DAU del 09-23.** Los errores bajaron, el FPS subió y los crashes no cambiaron. El benchmark del Top-200 se mantuvo (341,228 → 340,748), así que la caída no es del mercado entero.
- **Tiers de teléfono:** sin verificar. Antes del publish, el FPS en teléfono era 26.33 (09-19) y 23.53 (09-21), con los teléfonos en el 63.5-67.3% del CCU. La exportación nueva no tiene plataforma.

**Errores que quedan** (`[N] Errors and warnings by count.csv`, top 25 = 94,772, que es el 93.7% del total):

| Recuento/día | Firma | Archivo:línea | Arreglo |
|---|---|---|---|
| 14,607 (14.4% del total; +23% por CCU) | Remote event discarded: `StaminaSync` | `src/common/ServerScriptService/Bootstrap.server.luau:90` (UnreliableRemoteEvent), `:178` FireClient, llamado en `:197`, `:355` (PlayerAdded) y `:445`; listener `StaminaSyncClient.client.luau:11-15` | No hacer FireClient hasta que el cliente esté listo (DataLoaded, o un ping de "ready"). El atributo de `:181-184` ya entrega el primer valor. Que la causa sea una carrera con el cliente es plausible, pero no está verificado |
| 9,970 + 438 (servidor) | Sonido not authorized `10468693967` (servidor: `77131850715240`) | No aparece ni en `src` ni en los scripts de los 3 places. `77131850715240` está en `src/assets/GalacticOpenSource.rbxm` | Buscarlo en Studio (probablemente es un `SoundId` de contenido del place). Volver a subirlo con el dueño del universo o quitarlo |
| 6,671 | Animation sanitized ID failed | `R15SpeedsterRun.client.luau:104,106,108`; `Config.luau:342` | Volver a subir idle, cinta, caída y vuelo con el dueño del universo |
| 4,466 + 4,436 + 513 | Ambiencias no cargadas | `ZoomArenaAmbience.client.luau:43,47,192-194`; `World2SixSevenAreaAmbience.client.luau:41,157` | Volver a subirlas, o cargarlas por proximidad (también baja los HTTP 429) |
| 618 | Formato de sonido no soportado `96750121076266` | `Config.luau:853`; `SpeedsterClient.client.luau:36`; `SpeedGainPopupSoundPatch.client.luau:67` | Sustituir por un audio válido |
| 5,751 (+108% por CCU) | `GuiService.SelectedObject` inválido | 12 sitios, entre ellos `IconController.luau:817,821`, `ConsoleUiScale.client.luau:216,264,343` y `SpinWheelController.client.luau:1103` | Un helper de guarda (Visible, Selectable, IsDescendantOf) |
| 744 + 571 (servidor) | DataStore `StandardWriteExperienceThrottled` en UpdateAsync `SpeedsterEscape_MainSave_v17` | `DataStoreAdapter.luau:61-63`; `Config.luau:1192`; origen de las escrituras en `QuestService.server.luau:8,191` | P0-4 / H2: juntar las escrituras |
| 493 + 486 (servidor) | "Cannot fire RagdollEvent from a sandboxed thread" | Script de place W3 `Workspace.Stage 6.Pyramid.Pyramid.Smooth Block Model.Script:72,74` (no está en `src`; el place lo atribuye la lectura con Lune) | **Bug de gameplay:** la trampa de la pirámide no hace ragdoll. En Studio, usar siempre la vía `SetAttribute('Ragdolled')`, o envolver el Fire en pcall con fallback |
| 621 + 463 | CosmeticService: no puede restaurar aura o trail porque la parte no está lista | `CosmeticService.luau:495-512` | Carrera benigna |
| ≈23k | Fallos de red de sonido (Timedout, NetFail, DNS, 429…) + ForgeVFX `--!native` 4,099 + Mesh 4,995 | Motor o red | Bajan si se reduce el número de cargas simultáneas |

Los problemas de assets de sonido y animación suman ≈50k, **la mitad del total**. Los casos de permiso o formato (27.1k) pesan más que el ruido de red (23.0k). Ya no aparecen en el top 25 (cada uno por debajo de 438/día):
- Tacos: 1.94M + 193k.
- GetUp: 741k.
- ASMR:142: 157k.
- IMC:944: 70k.
- TreeSlammers:172: 14.5k.
- SpinWheel:543: 8.8k.

Para confirmar que están en ≈0 hace falta la lista completa.

---

## 7. Descubrimiento, audiencia y reseñas

**Descubrimiento** (`Universe- Unique users with impressions` / `…with plays`, `Not interested rate…`, `User ratings-`):

| Ventana | Impresiones/día | Plays/día | PTR Home | "Not interested" por millón | Like % |
|---|---|---|---|---|---|
| 09-06..12 | 5,307,856 | 186,785 | 2.63% | 91.8 | 90.5 |
| 09-13..15 | 5,219,541 | 200,513 | 2.96% | 66.1 | 90.1 |
| 09-16..20 | 3,125,345 | 114,255 | 2.81% | 51.8 | 90.7 |
| 09-21..22 | 1,106,065 | 44,950 | 3.14% | 34.5 | 85.2 |
| 09-23 | 280,987 | 12,439 | 3.06% | 46.9 (≈13 eventos) | 77.4 (24/7) |

**Descubrimiento:**
- Roblox muestra el juego mucho menos. La gente que lo ve lo pulsa igual que antes y los "not interested" **bajan**.
- El día de la caída (09-21) el PTR de Home sí bajó de 2.98% a 2.61%. Con menos oferta de impresiones el PTR tiende a subir, así que un PTR estable **solo exculpa débilmente** al icono y la miniatura.
- Las caídas del 09-16 y el 09-21 son reales y no son efectos del día de la semana: el benchmark de la misma semana se mantiene (×1.02-1.04).
- La "recuperación" del 09-19 y el 09-20 es sobre todo estacionalidad del fin de semana. El DAU/benchmark fue 0.41 el 09-16 y 0.40 el 09-20.
- **El 09-23 es el mínimo desde el 08-26.** Home cayó −91% de miércoles a miércoles.
- **Hipótesis:** el algoritmo reacciona a las señales de retención y engagement (causa n.º 8 del INFORME, consecuencia y no causa). Encaja con que la cohorte del 09-20 tuviera un D1 de 5.45%, medido justo el 09-21.

**Friends:**
- Los plays desde Friends cayeron ×15: de 22,223/día en 09-06..12 a 1,481 el 09-23.
- Los plays desde Friends por DAU pasaron de 0.088 a 0.041, así que cayeron más rápido que el DAU. El PTR de Friends sigue en 43-52%.
- Hay menos jugadores que traen amigos. Es la única palanca de tráfico que controla el dueño (M20; **hipótesis**).

**Votos:**
- El like ratio bajó a 85.2% entre el 09-21 y el 09-22 y a 77.4% el 09-23. Son 32 votos negativos de 200, frente a una base de 9.65% (z ≈ 3).
- Es una señal real pero pequeña. No es la primera vez: el 08-26 marcó 77.4% y el 08-27 80.9%.
- Los votos por cada 1k DAU ya bajaban antes del 09-21 (1.86 el 09-16 y 1.23 el 09-20).

**Audiencia:**
- El MAU (totales de `Monthly active users, Gender`) pasó de 3,858,530 (09-17) a 4,213,443 (09-20, +354,913) y a 4,299,624 (09-23, **+86,181**, −76% de crecimiento).
- La mezcla de idiomas no cambia. Los 10 idiomas del tutorial (`TutorialText.luau:22-265`) son exactamente el top 10 y cubren el **95.6%** del MAU, así que no hace falta añadir idiomas.
- Portugués es el mayor sobreíndice en términos absolutos (20.0% del crecimiento frente al 14.6% de la base). Indonesio crece más en términos relativos (+17.2%).
- Brasil aporta el 24.5-25.3% del crecimiento de MAU entre el 09-20 y el 09-23.
- En la exportación por país faltan 29 países desde el 09-20 (285,310 MAU al 09-17: Arabia Saudí, Irak, Vietnam, Kirguistán, EAU…). El MAU en árabe sigue creciendo, así que parece una **omisión de la exportación** (hipótesis). No se debe usar por país.

**Reseñas:**
- `[N] Report_1790310305768.csv` (exportado el 09-25 a las 04:25Z) **no tiene reseñas nuevas**. Es un subconjunto estricto de `Report_1790050407610`. La más reciente es del 09-22 a las 02:14Z.
- Con ≈0.6 comentarios por cada 100 votos y 112 votos, lo esperable era ≈0.7, así que cero no significa nada. Hay **0 opiniones escritas sobre el build del 09-22**.
- De los 20 votos negativos con motivo, **11 (55%) son de justicia del juego**:
  - Hitbox, 5: H4/H5/H6.
  - Saltos, 3: H13.
  - Dificultad, 3: causa n.º 2.
- Les siguen:
  - Acceso a World 2 o regresión, 3: L2 y la puerta.
  - Controles móvil/PC, 2.
  - Precios o "scam", 2: H14/H15.
- La muestra es pequeña y en su mayoría anterior a U2. Aun así coincide con los hallazgos de código del INFORME.

---

## 8. Plan actualizado (P0 / P1 / P2 del INFORME §9, revisado)

**Qué cambia respecto al INFORME**
- **Sale del plan:** P0-1 queda **hecho en lo esencial**. Los errores cayeron −97%, lo que es coherente con el build 09-22 en vivo (es una inferencia, porque la serie de errores no prueba qué build está publicado). H16 queda cerrado.
- **Suben:**
  - La exportación de datos (P0-2, ampliada).
  - La medición de la ruleta de pago (M28, de P1-12 a P0).
  - Los ganchos para volver y traer amigos (M20 y M33, dentro de P1-6).
  - Los assets con error (nuevo).
- **Bajan:** P0-5 (perf en teléfono) pasa a P1. El FPS Total ya volvió al nivel del 09-19 y la estabilidad no explica la caída. Se decide con el export por plataforma.
- **Correcciones a los objetivos del INFORME:**
  - El objetivo "FirstTreadmillRun ≥95%" usaba la definición v1. **En v2 la base es ≈89%.** Propongo como objetivo ≥92% en v2.
  - El precio de Revive en §6 es ≈25 R$ de lista, no 9.
  - Flight pasó de ≈250 R$ a 799, no de 79 a 799.

### P0: hoy o mañana

| # | Acción | Por qué (dato nuevo) | Métrica a vigilar |
|---|---|---|---|
| P0-1b | Anotar la hora exacta de cada publish (versión en Creator Hub) desde ahora, incluidos el 09-19, el 09-21 y el 09-22 | Ningún CSV tiene la hora. El 09-21 y el 09-22 no se pueden partir | – |
| P0-2 (ampliado) | Exportar lo que falta (sección 9): D1 de las cohortes del 09-23 al 09-26, impresiones y plays desde el 09-24, rendimiento **con desglose por plataforma**, productos de desarrollador y pases **solo del 09-13 al 09-24**, y la lista completa de errores | Hoy "Other" es el 74-88% de los productos de desarrollador. No hay plataforma ni place | – |
| P0-8 | A/B de la entrada barata (x2 a 5-9 R$ + un peldaño repetible; nunca ocultar el botón) (H14) | Confirmado: los 4 SKU OG valían ≈22.7k R$/día y la conversión está en 0.35% frente a 1.12% | Pagadores/día, conversión (`Payer conversion rate-`) |
| P0-4 | Quitar el Commit de 10 s de QuestService (H2) | 1,315 throttles de UpdateAsync/día en MainSave_v17 (S13). ≈17% de las quests se terminan y no se reclaman | Throttles en `Errors and warnings by count`; Claimed/Done en N25(11) |
| P0-12 (sube de P1-12, M28) | Arreglar Wheel_Paid_v2: mandar `opened=true` solo en la apertura real (`SpinWheelController.client.luau:1450-1452`, `SpinWheelService.server.luau:446-447`) | Hoy la conversión de los packs de la ruleta no se puede medir | Aparición de PaidReceiptGranted en N25(13) |
| P0-6 | FTUE (H7, M50, H8, M36) | FirstTreadmillRun v2 plano en 88-90% después del tutorial en 10 idiomas | FirstTreadmillRun v2 ≥92%; Rebirth1 en N25(8) (hoy 70-73%) |
| P0-7 | Hitboxes de W1 (H4, H5) | 5 de 20 votos negativos con motivo son de hitbox (la categoría más grande) | Reseñas; muertes por etapa (telemetría L15) |
| P0-11 | AFK: claim y Commit por lotes (H9) + medir la salida | RewardEarned 3.2-4.4%: ≈96% de los AFK terminan antes de los 60 s | AFK v2 RewardEarned; eventos AFK_Exited_v2 |
| P0-3, P0-9, P0-10 | Sin cambios (Rebirth pass H1, DarkZonic y applySavedSkin, guard del panel de admin) | Los datos nuevos no les afectan | Las del INFORME |

### P1: esta semana

| # | Acción | Por qué | Métrica |
|---|---|---|---|
| P1-6 (prioridad dentro de P1: la primera) | Daily por día calendario y reescalado (M14/M15); **auto-claim de quests (M33)**; **favorito, notificaciones e invitación (M20)** | Los jugadores que vuelven bajaron de ≈54k a ≈33k/día desde el 09-21. Los plays desde Friends cayeron ×15. D7/D1 ya caía antes del 09-13 | D1 y D7 por cohorte; plays de Friends por DAU (hoy 0.041) |
| P1-13 (nuevo) | Assets: buscar `10468693967` en Studio; volver a subir las animaciones (`R15SpeedsterRun.client.luau:104-108`, `Config.luau:342`) y las ambiencias; sustituir `96750121076266` | ≈27k errores/día de permiso o formato. `10468693967` creció al menos ×6 | Top 25 de `Errors and warnings by count` |
| P1-14 (nuevo) | Pirámide de W3 Stage 6: ragdoll por atributo (script del place, líneas 72/74) | 979 errores/día. La trampa no funciona | Desaparición de la firma |
| P1-15 (nuevo) | StaminaSync: no disparar antes de que el cliente esté listo (`Bootstrap.server.luau:178,355`) | El 14.4% de los errores restantes | Total de errores/día |
| P1-16 (nuevo, investigar) | Escalera de rebirth de los nuevos: por qué se pierde ≈40% en el 5 → 6 | Es el mayor punto de pérdida medido en progresión | Rebirth6/Rebirth5 en N25(8) (hoy ≈60%) |
| P1-5 (antes P0-5 + P1-11) | Perf en teléfono: retirar los stubs M8/M9/L16/L31 y el arcoíris H12; LOD de auras (M6), etc. | FPS Total +7% y CPU −15.5%. Falta el dato de teléfono para decidir cuánto más invertir | FPS de **teléfono** (re-export por plataforma); OOM por CCU |
| P1-3, P1-4 | Muertes revalidadas (H6); wall-bounce (H13) | Reseñas: saltos 3 y dificultad 3 | Finalización de Stage 1 |
| P1-9, P1-12 | Revive con Infinite Revives dentro (H15); tarjeta del Starter Pack (M25); Secret Aura/Trail (M61) | Revive 0.04-0.07%. Starter Pack a ≈1-5 unidades/día. Secret: 1 venta cada uno | Ventas por SKU (re-export) |
| P1-1, P1-2, P1-7, P1-8, P1-10 | Sin cambios | – | Las del INFORME |

### P2: después

- Todo lo del INFORME §9 P2 sigue igual.
- Se añaden:
  - Guarda de SelectedObject (5.8k/día, S14).
  - Paso "Joined" en la exportación de la Ladder.
  - Evento de telemetría con el tier de teléfono elegido.
  - Aclarar el precio y el SKU de Speed Tier 4.
- La puerta de W2 **se queda en 6R + L50** y no se toca. Revisar la Ladder el 09-29. El requisito de L50 nunca frena; si se quiere simplificar, se podría quitar, pero no es urgente.

---

## 9. Qué datos faltan y cuándo mirarlos

Nota: las métricas diarias de un día UTC suelen estar disponibles al día siguiente.

| Fecha | Qué exportar o mirar | Para qué |
|---|---|---|
| **Ya** | Historial de versiones en Creator Hub con la hora de los publish del 09-19, el 09-21 y el 09-22 | Partir el 09-21 y el 09-22; ver si las caídas de impresiones siguen a un publish |
| **Ya** | Perf 09-23 y 09-24 (FPS, memoria, crash, OOM, CCU, sesión) **con Breakdown = Platform y sin "compare to previous"**; sesión y CCU filtrados por cada place id | Tiers de teléfono; efecto de la puerta de W2 y de la velocidad de caminar x0.5/x0.25 |
| **Ya** | Productos de desarrollador y pases **del 09-13 al 09-24** (o ventas por id); precio vivo de Speed Tier 4 y de la escalera nueva y la de Wins | Sacar el 74-88% "Other"; evaluar la escalera x2..x32, los packs de la ruleta y ClaimX5 |
| **Ya** | Lista completa de "Errors and warnings by count" con su ventana; serie de errores del 09-22 y el 09-23 | Confirmar ≈0 en las firmas arregladas |
| **09-25** | D1 de la cohorte del **09-23** (la primera que entra y vuelve con el build final) | Primera lectura limpia. Esperar ±1 pp |
| **09-25/26** | DAU, sesiones, sesión media, juego/DAU, MAU, pagadores, ARPDAU, conversión e impresiones del **09-24** | Segundo día post-publish. Separar tráfico de efecto por jugador en los 21,881 R$ del 09-24 |
| **09-26** | D1 del 09-24; funnels de nuevo (Ladder con "Joined", Quests, AFK); primera sesión con ventana corta (09-23..25 frente a 09-15..21, por plataforma) | Tendencia de D1; ver si la bajada de Quests coincide con el publish |
| **09-27** | Impresiones y plays por fuente del 09-24 al 09-26 | ¿Se recupera Home? No juzgar el build por impresiones antes del 09-27..29 |
| **09-28** | Empiezan a salir de la ventana de 30 días las cohortes grandes de septiembre | El proxy de jugadores que vuelven (DAU − delta del MAU) deja de valer. Pedir el desglose nuevo/que vuelve de Creator Hub |
| **09-29** | Funnels del 09-23 al 09-28; reseñas nuevas (report); like ratio con ≥500 votos post-publish; D1 de 3-4 cohortes (09-23..26) | Confirmar o descartar la mejora de D1 (objetivo ≥12% sostenido) y la puerta de W2 |
| **09-30** | D7 de la cohorte del 09-22 (09-23 → ≈10-01) | Primera lectura de D7 post-publish |
| **10-10** | Primera liquidación de Creator Rewards (fecha de juego 08-11) | Comprobar que la estimación coincide con lo pagado |

**Datos que ahora no se pueden usar o no existen:**
- `Payer conversion rate, Top Countries` tiene las etiquetas de país vacías.
- El MAU por país omite 29 países desde el 09-20.
- `Universe- Daily active users` (current/previous) no coincide con `Daily active users-` (09-23: 12,336 frente a 36,018). No usarlo sin aclararlo.
- No hay D1 por fuente después del 09-19, ni D1 por idioma.
- Los funnels no tienen conteos, solo tasas.
- No hay datos de rendimiento del servidor (heartbeat, presupuesto de DataStore).

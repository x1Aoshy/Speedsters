# Análisis de datos — +1 Speedster (export 2026-09-15/16)

Fuente: 34 CSVs de Roblox Analytics en `Desktop/Data Analyst`.
Ventana con ingresos reales: **2026-08-11 → 2026-09-14 (35 días)**.

---

## Resumen en una línea

El problema de dinero **no es la canibalización de SKUs**. Es que algo se rompió en
el juego el **13 de septiembre** y desde entonces estás perdiendo **~42.400 R$/día
con el mismo tráfico**. Los multiplicadores por los que discutimos son el **1,4 %**
de los ingresos.

---

## 1. El evento del 13 de septiembre

Comparando la media de **Sep 4–12** contra **Sep 13–14**:

| Métrica | Sep 4–12 | Sep 13–14 | Δ |
|---|---:|---:|---:|
| DAU | 280.423 | 279.840 | **−0,2 %** |
| Ingresos / día | 132.082 R$ | 89.637 R$ | **−32,1 %** |
| Usuarios pagadores | 3.237 | 1.190 | **−63,2 %** |
| Conversión a pago | 1,154 % | 0,425 % | **−63,2 %** |
| ARPDAU | 0,471 | 0,320 | **−32,0 %** |
| Sesión media | 11,9 min | 9,1 min | **−23,1 %** |
| Playtime medio | 16,8 min | 11,6 min | **−30,9 %** |

**El tráfico no se movió. Dos tercios de los compradores desaparecieron.**

Corroboración independiente:

* **Retención D1**: 13–16 % estable hasta Sep 12 → **6,67 % en la cohorte del Sep 13**
  (se partió a la mitad).
* **Playtime total**: 83.686 → 65.065 → 43.697 horas en dos días (**−48 %**).
* **Playtime de suscriptores Plus**: 16,4 → 14,8 → 11,1 → 10,9 min (**−33 %**).
  Éste es el dato que cierra el caso: los Plus son usuarios **ya comprometidos y
  estables**. Si un cambio en la mezcla de tráfico explicara la caída, ellos no se
  verían afectados. Se vieron.
* **Gasto de suscriptores Plus**: 20.939 → 13.388 → 9.612 R$ (**−54 %**).

Y no es un problema de descubrimiento: las impresiones se mantuvieron en 4,6–5,6 M/día
y la tasa de "no me interesa" **mejoró** (118 → 57,5 por millón). El embudo se rompe
**después** de entrar al juego.

### Qué costó

```
Baseline Sep 4-12 : 132.082 R$/día  (280.423 DAU, ARPDAU 0,471)
Sep 13-14         :  89.637 R$/día
Brecha            :  42.445 R$/día  ≈ $149/día DevEx  ≈ $4.457/mes
```

**Correlación, no prueba causal.** Pero encaja exactamente con lo que reportaron en
Discord el 14–15 de septiembre (vuelo roto en ambos mundos, menú de trails/auras roto,
multiplicadores que no se actualizaban, popups desfasados) y con los bugs que encontré
en el código, en particular `setTrailOwned`/`setAuraOwned` llamados antes de declararse,
que tiraba **toda la tienda de cosméticos** por excepción.

**Prueba a hacer:** publicar el build de hoy y ver si ARPDAU vuelve a ~0,47 y la sesión
a ~12 min. Si vuelve, era esto y son 42k R$/día recuperados.

---

## 2. La pregunta de los SKUs, con números

El archivo por ítem resulta ser **solo gamepasses** (lo verifiqué: cuadra exacto,
día a día, con la línea `Passes` del informe de fuentes).

**Ingresos por gamepass, ventana completa (760.438 R$ = 41 % del total):**

| Gamepass | R$ | % de passes | % del total |
|---|---:|---:|---:|
| Hacker Treadmill | 401.794 | 50,0 % | **21,7 %** |
| Valentine Treadmill | 156.906 | 19,5 % | 8,5 % |
| Admin Treadmill | 129.822 | 16,2 % | 7,0 % |
| Infinite Revives | 42.170 | 5,2 % | 2,3 % |
| Starter Pack | 36.005 | 4,5 % | 1,9 % |
| **2x Wins** | **21.576** | **2,7 %** | **1,16 %** |
| Flight | 5.590 | 0,7 % | 0,30 % |
| **2x Speed** | **4.663** | **0,6 %** | **0,25 %** |

Developer Products: 1.092.300 R$ (**59 %** del total).

### Lo que esto significa

1. **Los gamepasses de multiplicador son el 1,4 % del negocio.** Estábamos discutiendo
   cómo proteger un 1,4 % mientras el motor real —los tres pases de treadmill— es el
   **37,2 % de TODOS los ingresos**.
2. **Los pases sí funcionan cuando el valor es fuerte.** Hacker Treadmill solo hace
   401.794 R$. Lo que no funciona es vender un multiplicador como pase caro.
3. **Flight tiene 5.590 R$ y el 100 % está en los últimos 7 días** — acaba de salir.
   Es muy pronto para juzgarlo.

### Lo que NO puedo ver

**No hay desglose por developer product en este export.** No puedo decirte cuánto de
esos 1.092.300 R$ vino de los x2/x4/x8/x16/x32 y cuánto de packs de velocidad, pociones,
revive, skip stage o cosméticos. **Sin eso, la tesis de canibalización no se puede
probar ni refutar.**

Expórtalo desde Creator Dashboard → Monetization → Developer Products (ventas por
producto) y te lo cierro en una pasada.

---

## 3. Quién juega y quién paga

* **MAU ≈ 3,49 M.**
* **Edad:** 9–12 son 918.935 y 13–15 son 407.195. De los verificados, **64 % tiene
  entre 9 y 15 años**.
* **Países:** Brasil 13,2 %, EE. UU. 12,7 %, Filipinas 7,7 %, México 6,1 %,
  Indonesia 3,7 %. Mayoría **LATAM + SEA**, mercados de ARPU bajo. EE. UU., el mercado
  caro, es solo 1 de cada 8.
* **ARPPU medio: 41,2 R$.** El pagador típico compra **un artículo barato**, no un pase
  de 499.
* **Tráfico casi todo orgánico:** Home Recommendation 2,54 M usuarios únicos (73,6 %)
  contra Sponsored Ads 33.150 (**0,96 %**).

**Conclusión de negocio:** empujar a este público hacia un pase de 499 R$ no va a
funcionar. Los dev products baratos no están robándole ventas al gamepass — están
monetizando a gente que **nunca** iba a comprar el gamepass. Quitar el escalón de 20 R$
está bien por integridad del leaderboard (ya lo hice), pero **no esperes que mueva
los ingresos**.

---

## 4. El riesgo estructural de verdad

| Retención | Valor | Referencia sana |
|---|---:|---|
| D1 | 13–16 % | 25–35 % |
| **D7** | **1,0–1,8 %** | 8–12 % |
| D30 | 0,4–3 % | 3–6 % |

**El D7 al 1 % es el número más grave de todo el export.** Significa que el 99 % de
quienes entran no vuelven a la semana. El juego vive **enteramente** del algoritmo de
Home Recommendation. Los ingresos siguen a DAU casi uno a uno, y DAU sigue al algoritmo.
El día que la recomendación se enfríe, esto cae a cero — no hay base retenida que
amortigüe.

Esa es la prioridad número uno por encima de cualquier debate de precios.

---

## 5. Qué haría, en orden

1. **Publicar el build de hoy y medir 48 h.** Si ARPDAU vuelve a ~0,47, recuperas
   ~42k R$/día. Es la acción de mayor retorno y ya está lista.
2. **Exportar el desglose por developer product.** Sin él seguimos opinando sobre
   canibalización en lugar de medirla.
3. **Instrumentar un funnel de compra** (impresión de tienda → clic → prompt →
   compra completada, por SKU). Hoy no hay forma de saber en qué paso se cae la gente.
4. **Atacar el D7.** Cualquier punto de D7 vale mucho más que cualquier cambio de
   precio: el D7 multiplica todo lo demás.
5. **Dejar la escalera de multiplicadores como está ahora** (x2 solo por gamepass) y
   no invertir más tiempo ahí hasta tener el punto 2.

---

## Advertencias metodológicas

* La cohorte D1 del 13-sep puede estar **incompleta** en este export. Confírmala con
  uno nuevo antes de citarla.
* `30D revenue per user, Source` está fechado 2026-06-17, antes de que hubiera
  ingresos; ese archivo **no es utilizable**.
* La caída de Stickiness (DAU/MAU) de 48 % a 6,6 % es en su mayor parte un artefacto
  aritmético: el MAU se infló con el pico viral. No lo leas como retención.
* Todo lo de la sección 1 es **correlación temporal**. La prueba es el A/B contra el
  build corregido.

# Contrato de la API — Sistema de turnos (v1)

Documento de referencia para consumir la API desde el front-end de clientes. Describe todos los
endpoints que usa el front y los que se agregaron en el TP 2. Cada ejemplo se puede reproducir con
`curl` contra el back-end en desarrollo cargado con los seeds (`bin/rails db:seed`).

## Índice

- [1. Configuración general](#1-configuración-general)
- [2. Autenticación](#2-autenticación)
- [3. Formato de errores](#3-formato-de-errores)
- [4. Objetos de respuesta](#4-objetos-de-respuesta)
- [5. Endpoints públicos](#5-endpoints-públicos)
- [6. Endpoints protegidos](#6-endpoints-protegidos)
- [7. Reglas de negocio](#7-reglas-de-negocio)
- [8. Resumen de endpoints](#8-resumen-de-endpoints)

---

## 1. Configuración general

| | |
|---|---|
| URL base (desarrollo) | `http://localhost:3000/api/v1` |
| Formato | JSON. Enviar `Content-Type: application/json` en peticiones con cuerpo y `Accept: application/json`. |
| Codificación | UTF-8 |
| Zona horaria | `America/Argentina/Buenos_Aires` (UTC-03:00). Todas las fechas/horas son del local. |
| CORS | Se permiten los orígenes de la variable `CORS_ORIGINS` (separados por coma). Por defecto `http://localhost:5173` y `http://127.0.0.1:5173`. Solo aplica a `/api/*`. |

### Fechas y horas

| Uso | Formato | Ejemplo |
|---|---|---|
| Fecha (parámetro `date`) | `AAAA-MM-DD` (ISO 8601) | `2026-11-05` |
| Fecha y hora enviada (`scheduled_at`) | ISO 8601. Sin huso horario se interpreta como hora del local. | `2026-11-05T10:30` o `2026-11-05T10:30:00-03:00` |
| Fecha y hora devuelta | ISO 8601 con huso | `2026-11-05T10:30:00-03:00` |
| Horario libre (`slots`) | `HH:MM`, 24 h | `"10:30"` |

### Montos

Los precios y totales se devuelven como número decimal en pesos (`8500.0`). Los montos de un turno
(`price_at_booking`, `total`) son los vigentes **al momento de reservar** y no cambian aunque luego
se modifique el precio del servicio.

---

## 2. Autenticación

Los clientes se autentican con email y contraseña y reciben un **token**. Las rutas protegidas
exigen ese token en el header `Authorization` con el esquema `Bearer`:

```
Authorization: Bearer 3ff36f04e016cc6a063f07457c32f00ae0210b367da75e42
```

- El token se obtiene con [`POST /login`](#post-login) o [`POST /register`](#post-register).
- Cada login genera un token nuevo e invalida el anterior (una sesión activa por cliente).
- El token no vence por tiempo; deja de valer al hacer [`DELETE /logout`](#delete-logout) o al volver a iniciar sesión.
- Si falta o no es válido, la API responde `401` con `{"error": "Token inválido o ausente"}`. El front
  debe descartar la sesión local y pedir login de nuevo.
- La API no usa cookies. El back-office (`/admin`) tiene su propio login con sesión de Rails y no se
  accede desde esta API.

---

## 3. Formato de errores

Toda respuesta de error tiene un campo `error` con un mensaje legible para mostrar al usuario. Los
errores de validación (`422`) agregan `errors`, un objeto con los mensajes completos por campo:

```json
{
  "error": "Revisá los datos ingresados",
  "errors": {
    "email": ["Email ya está en uso"],
    "password": ["Contraseña es demasiado corto (mínimo 8 caracteres)"]
  }
}
```

| Código | Cuándo | Cuerpo |
|---|---|---|
| `400 Bad Request` | Falta el objeto raíz del cuerpo (`client`, `appointment`), fecha con formato inválido o JSON mal formado | `{"error": "Falta el parámetro: client"}` |
| `401 Unauthorized` | Credenciales incorrectas en el login, o token ausente/inválido en una ruta protegida | `{"error": "Token inválido o ausente"}` |
| `404 Not Found` | El recurso no existe, o el turno pertenece a otro cliente | `{"error": "No encontrado"}` |
| `422 Unprocessable Content` | Validación fallida, o una operación que el estado del turno no permite | `{"error": "...", "errors": {...}}` o solo `{"error": "..."}` |

Las claves de `errors` son los nombres de los campos del modelo (`name`, `email`, `scheduled_at`,
`services`, `stylist`, `current_password`, etc.). Cada mensaje ya incluye el nombre del campo en
castellano, así que se puede mostrar tal cual.

> No hay un `403`: un cliente nunca puede ver ni modificar turnos de otro; en ese caso la API responde
> `404` para no revelar que el turno existe.

---

## 4. Objetos de respuesta

### Client

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | integer | |
| `name` | string | |
| `email` | string | Siempre en minúsculas |
| `phone` | string \| null | Opcional |

### Category

| Campo | Tipo |
|---|---|
| `id` | integer |
| `name` | string |

### Service

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | integer | |
| `name` | string | |
| `description` | string \| null | |
| `duration_minutes` | integer | Duración en minutos (> 0) |
| `price` | number | Precio actual en pesos |
| `category` | Category | |

### Stylist (profesional)

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | integer | |
| `name` | string | |
| `specialty` | string | |
| `bio` | string \| null | |
| `photo_url` | string \| null | URL absoluta de la foto, o `null` si no tiene |

### Appointment (turno)

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | integer | |
| `scheduled_at` | string (ISO 8601) | Inicio del turno |
| `ends_at` | string (ISO 8601) | Fin estimado: inicio + suma de duraciones de los servicios |
| `status` | string | `pending`, `confirmed`, `completed` o `cancelled` |
| `status_label` | string | Estado en castellano: `Pendiente`, `Confirmado`, `Realizado`, `Cancelado` |
| `duration_minutes` | integer | Suma de duraciones de los servicios |
| `cancellable` | boolean | `true` si está pendiente o confirmado y todavía no empezó. Indica si se puede cancelar **y** reprogramar |
| `notes` | string \| null | Notas del cliente |
| `total` | number | Suma de `price_at_booking` |
| `stylist` | `{ id, name }` | |
| `services` | `[{ id, name, price_at_booking }]` | Servicios incluidos con el precio pactado |

### Availability (horarios libres)

| Campo | Tipo | Descripción |
|---|---|---|
| `date` | string (`AAAA-MM-DD`) | Día consultado |
| `duration_minutes` | integer | Duración usada para calcular los horarios (mínimo 30) |
| `slots` | string[] | Horarios de inicio libres, `HH:MM`, ordenados |

---

## 5. Endpoints públicos

No requieren token.

### `POST /login`

Inicia sesión de un cliente.

**Cuerpo**

| Campo | Tipo | Obligatorio | Validaciones |
|---|---|---|---|
| `email` | string | sí | Se ignoran mayúsculas y espacios alrededor |
| `password` | string | sí | |

**Respuesta `200`**: `{ token, client }`.

```bash
curl -X POST http://localhost:3000/api/v1/login \
  -H "Content-Type: application/json" \
  -d '{"email":"juan@mail.com","password":"cliente123"}'
```

```json
{
  "token": "ac53fcb2a6fb203ca11cb03bdc6893b960b98479c61fcd50",
  "client": { "id": 1, "name": "Juan López", "email": "juan@mail.com", "phone": "1122334455" }
}
```

**Errores**

| Código | Caso | Cuerpo |
|---|---|---|
| `401` | Email inexistente o contraseña incorrecta | `{"error": "Email o contraseña incorrectos"}` |
| `400` | JSON mal formado | `{"error": "El cuerpo de la petición no es un JSON válido"}` |

---

### `POST /register`

Crea una cuenta de cliente e inicia sesión (devuelve el token, igual que el login). *Nuevo en TP 2.*

**Cuerpo**: objeto `client`.

| Campo | Tipo | Obligatorio | Validaciones |
|---|---|---|---|
| `client.name` | string | sí | No vacío |
| `client.email` | string | sí | Formato de email; único (sin distinguir mayúsculas). Se guarda en minúsculas y sin espacios |
| `client.phone` | string | no | |
| `client.password` | string | sí | Mínimo 8 caracteres |
| `client.password_confirmation` | string | no | Si se envía, debe coincidir con `password` |

**Respuesta `201`**: `{ token, client }`.

```bash
curl -X POST http://localhost:3000/api/v1/register \
  -H "Content-Type: application/json" \
  -d '{"client":{"name":"Ana Pérez","email":"ana@mail.com","phone":"1144556677","password":"secreta123","password_confirmation":"secreta123"}}'
```

```json
{
  "token": "3ff36f04e016cc6a063f07457c32f00ae0210b367da75e42",
  "client": { "id": 7, "name": "Ana Pérez", "email": "ana@mail.com", "phone": "1144556677" }
}
```

**Errores**

| Código | Caso | Ejemplo |
|---|---|---|
| `422` | Validación | `{"error":"Revisá los datos ingresados","errors":{"name":["Nombre no puede estar en blanco"],"email":["Email ya está en uso"],"password":["Contraseña es demasiado corto (mínimo 8 caracteres)"]}}` |
| `400` | Falta el objeto `client` | `{"error": "Falta el parámetro: client"}` |

---

### `GET /categories`

Lista las categorías, ordenadas por nombre.

**Respuesta `200`**: `Category[]`.

```bash
curl http://localhost:3000/api/v1/categories
```

```json
[{ "id": 1, "name": "Cabello" }, { "id": 3, "name": "Piel" }, { "id": 2, "name": "Uñas" }]
```

### `GET /categories/:id`

Una categoría con sus servicios.

| Parámetro de ruta | Tipo |
|---|---|
| `id` | integer |

**Respuesta `200`**: `Category` + `services: Service[]`.

```bash
curl http://localhost:3000/api/v1/categories/1
```

```json
{
  "id": 1,
  "name": "Cabello",
  "services": [
    { "id": 3, "name": "Brushing", "description": "Lavado y brushing.", "duration_minutes": 30, "price": 6000.0, "category": { "id": 1, "name": "Cabello" } }
  ]
}
```

**Errores**

| Código | Caso | Cuerpo |
|---|---|---|
| `404` | Categoría inexistente | `{"error": "No encontrado"}` |

---

### `GET /services`

Lista los servicios, ordenados por nombre. Admite filtros (el de texto es nuevo en TP 2).

| Parámetro de consulta | Tipo | Obligatorio | Descripción |
|---|---|---|---|
| `category_id` | integer | no | Solo servicios de esa categoría |
| `q` | string | no | Busca en el nombre (contiene, sin distinguir mayúsculas) |

**Respuesta `200`**: `Service[]` (vacío si no hay coincidencias).

```bash
curl "http://localhost:3000/api/v1/services?q=corte"
```

```json
[{ "id": 1, "name": "Corte", "description": "Corte y peinado.", "duration_minutes": 30, "price": 8500.0, "category": { "id": 1, "name": "Cabello" } }]
```

### `GET /services/:id`

| Parámetro de ruta | Tipo |
|---|---|
| `id` | integer |

**Respuesta `200`**: `Service`.

```bash
curl http://localhost:3000/api/v1/services/1
```

```json
{ "id": 1, "name": "Corte", "description": "Corte y peinado.", "duration_minutes": 30, "price": 8500.0, "category": { "id": 1, "name": "Cabello" } }
```

**Errores**

| Código | Caso | Cuerpo |
|---|---|---|
| `404` | Servicio inexistente | `{"error": "No encontrado"}` |

---

### `GET /stylists`

Lista los profesionales, ordenados por nombre.

| Parámetro de consulta | Tipo | Obligatorio | Descripción |
|---|---|---|---|
| `q` | string | no | Busca en nombre o especialidad. *Nuevo en TP 2* |

**Respuesta `200`**: `Stylist[]`.

```bash
curl "http://localhost:3000/api/v1/stylists?q=color"
```

```json
[{ "id": 1, "name": "Ana Pérez", "specialty": "Colorista", "bio": "Más de 10 años trabajando con color, mechas y balayage.", "photo_url": null }]
```

### `GET /stylists/:id`

| Parámetro de ruta | Tipo |
|---|---|
| `id` | integer |

**Respuesta `200`**: `Stylist`.

```bash
curl http://localhost:3000/api/v1/stylists/2
```

```json
{ "id": 2, "name": "Martín Gómez", "specialty": "Cortes", "bio": "Cortes clásicos y modernos para todo tipo de cabello.", "photo_url": null }
```

**Errores**

| Código | Caso | Cuerpo |
|---|---|---|
| `404` | Profesional inexistente | `{"error": "No encontrado"}` |

---

### `GET /stylists/:id/availability`

Horarios de inicio libres de un profesional en un día. Si se indican servicios, solo devuelve los
horarios donde entra la duración total sin superponerse con otros turnos ni pasarse del cierre.

| Parámetro | Ubicación | Tipo | Obligatorio | Descripción |
|---|---|---|---|---|
| `id` | ruta | integer | sí | Profesional |
| `date` | consulta | string `AAAA-MM-DD` | sí | Día a consultar |
| `service_ids[]` | consulta | integer (repetible) | no | Servicios a reservar. Sin ellos se asume un bloque de 30 min. *Nuevo en TP 2* |

**Respuesta `200`**: `Availability`. Los domingos, días pasados o días completos devuelven `slots: []`.
Si la fecha es hoy, solo se incluyen horarios que todavía no pasaron.

```bash
curl "http://localhost:3000/api/v1/stylists/1/availability?date=2026-11-05&service_ids[]=1"
```

```json
{ "date": "2026-11-05", "duration_minutes": 30, "slots": ["09:00", "11:30", "12:00", "12:30", "18:30"] }
```

**Errores**

| Código | Caso | Cuerpo |
|---|---|---|
| `400` | `date` ausente o con otro formato | `{"error": "Fecha inválida, usar formato AAAA-MM-DD"}` |
| `404` | Profesional inexistente | `{"error": "No encontrado"}` |

---

## 6. Endpoints protegidos

Requieren `Authorization: Bearer <token>`. Sin token o con uno inválido responden **`401`**
`{"error": "Token inválido o ausente"}` (se omite en cada tabla de errores).

En los ejemplos, `$TOKEN` es el valor devuelto por el login.

### `DELETE /logout`

Cierra la sesión: invalida el token actual.

**Respuesta `204`** sin cuerpo.

```bash
curl -X DELETE http://localhost:3000/api/v1/logout -H "Authorization: Bearer $TOKEN"
```

---

### `GET /me`

Datos del cliente autenticado. *Nuevo en TP 2.*

**Respuesta `200`**: `Client`.

```bash
curl http://localhost:3000/api/v1/me -H "Authorization: Bearer $TOKEN"
```

```json
{ "id": 1, "name": "Juan López", "email": "juan@mail.com", "phone": "1122334455" }
```

### `PATCH /me`

Actualiza los datos del cliente autenticado. Se envían solo los campos a cambiar. *Nuevo en TP 2.*

| Campo | Tipo | Obligatorio | Validaciones |
|---|---|---|---|
| `client.name` | string | no | No vacío |
| `client.email` | string | no | Formato de email; único |
| `client.phone` | string | no | |

**Respuesta `200`**: `Client` actualizado.

```bash
curl -X PATCH http://localhost:3000/api/v1/me \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"client":{"phone":"1199998888"}}'
```

```json
{ "id": 1, "name": "Juan López", "email": "juan@mail.com", "phone": "1199998888" }
```

**Errores**

| Código | Caso | Ejemplo |
|---|---|---|
| `422` | Validación | `{"error":"Revisá los datos ingresados","errors":{"email":["Email no es válido"]}}` |
| `400` | Falta el objeto `client` | `{"error": "Falta el parámetro: client"}` |

### `PATCH /me/password`

Cambia la contraseña. Exige la actual. El token sigue siendo válido. *Nuevo en TP 2.*

| Campo | Tipo | Obligatorio | Validaciones |
|---|---|---|---|
| `client.current_password` | string | sí | Debe ser la contraseña actual |
| `client.password` | string | sí | Mínimo 8 caracteres |
| `client.password_confirmation` | string | no | Si se envía, debe coincidir con `password` |

**Respuesta `204`** sin cuerpo.

```bash
curl -X PATCH http://localhost:3000/api/v1/me/password \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"client":{"current_password":"cliente123","password":"nuevaclave1","password_confirmation":"nuevaclave1"}}'
```

**Errores**

| Código | Caso | Ejemplo |
|---|---|---|
| `422` | Contraseña actual incorrecta | `{"error":"Revisá los datos ingresados","errors":{"current_password":["Contraseña actual es incorrecta"]}}` |
| `422` | Nueva vacía, corta o sin coincidir | `{"error":"Revisá los datos ingresados","errors":{"password_confirmation":["Confirmación de contraseña no coincide"]}}` |
| `400` | Falta el objeto `client` | `{"error": "Falta el parámetro: client"}` |

---

### `GET /appointments`

Turnos del cliente autenticado.

| Parámetro de consulta | Tipo | Obligatorio | Valores |
|---|---|---|---|
| `scope` | string | no | `upcoming`: pendientes o confirmados que todavía no empezaron, del más cercano al más lejano. `history`: pasados, realizados o cancelados, del más reciente al más viejo. Sin `scope`: todos, del más reciente al más viejo. *Nuevo en TP 2* |

**Respuesta `200`**: `Appointment[]`.

```bash
curl "http://localhost:3000/api/v1/appointments?scope=upcoming" -H "Authorization: Bearer $TOKEN"
```

```json
[
  {
    "id": 69,
    "scheduled_at": "2026-11-05T09:00:00-03:00",
    "ends_at": "2026-11-05T09:30:00-03:00",
    "status": "pending",
    "status_label": "Pendiente",
    "duration_minutes": 30,
    "cancellable": true,
    "notes": null,
    "total": 8500.0,
    "stylist": { "id": 1, "name": "Ana Pérez" },
    "services": [{ "id": 1, "name": "Corte", "price_at_booking": 8500.0 }]
  }
]
```

### `GET /appointments/:id`

| Parámetro de ruta | Tipo |
|---|---|
| `id` | integer |

**Respuesta `200`**: `Appointment`.

```bash
curl http://localhost:3000/api/v1/appointments/69 -H "Authorization: Bearer $TOKEN"
```

```json
{
  "id": 69,
  "scheduled_at": "2026-11-05T09:00:00-03:00",
  "ends_at": "2026-11-05T09:30:00-03:00",
  "status": "pending",
  "status_label": "Pendiente",
  "duration_minutes": 30,
  "cancellable": true,
  "notes": null,
  "total": 8500.0,
  "stylist": { "id": 1, "name": "Ana Pérez" },
  "services": [{ "id": 1, "name": "Corte", "price_at_booking": 8500.0 }]
}
```

**Errores**

| Código | Caso | Cuerpo |
|---|---|---|
| `404` | No existe o es de otro cliente | `{"error": "No encontrado"}` |

---

### `POST /appointments`

Reserva un turno. Envía un email de confirmación al cliente.

| Campo | Tipo | Obligatorio | Validaciones |
|---|---|---|---|
| `appointment.stylist_id` | integer | sí | Profesional existente |
| `appointment.scheduled_at` | string ISO 8601 | sí | Ver [reglas de horario](#7-reglas-de-negocio) |
| `appointment.service_ids` | integer[] | sí | Al menos un servicio existente. Los ids inexistentes se ignoran |
| `appointment.notes` | string | no | |

**Respuesta `201`**: `Appointment` creado, con estado `pending`.

```bash
curl -X POST http://localhost:3000/api/v1/appointments \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"appointment":{"stylist_id":1,"scheduled_at":"2026-11-05T09:00","service_ids":[1],"notes":"Primera vez"}}'
```

```json
{
  "id": 69,
  "scheduled_at": "2026-11-05T09:00:00-03:00",
  "ends_at": "2026-11-05T09:30:00-03:00",
  "status": "pending",
  "status_label": "Pendiente",
  "duration_minutes": 30,
  "cancellable": true,
  "notes": "Primera vez",
  "total": 8500.0,
  "stylist": { "id": 1, "name": "Ana Pérez" },
  "services": [{ "id": 1, "name": "Corte", "price_at_booking": 8500.0 }]
}
```

**Errores** (`422`, todos con `error: "Revisá los datos ingresados"`)

| Campo en `errors` | Mensaje | Caso |
|---|---|---|
| `scheduled_at` | `Fecha y hora el estilista ya tiene un turno en ese horario` | Se superpone con otro turno del profesional |
| `scheduled_at` | `Fecha y hora no puede ser en el pasado` | |
| `scheduled_at` | `Fecha y hora debe ser de lunes a sábado` | Domingo |
| `scheduled_at` | `Fecha y hora debe estar dentro del horario de atención (9 a 19 hs)` | Empieza antes de las 9 o termina después de las 19 |
| `scheduled_at` | `Fecha y hora debe coincidir con un bloque de 30 minutos` | Por ejemplo, 10:15 |
| `scheduled_at` | `Fecha y hora no puede estar en blanco` | |
| `services` | `Servicios debe incluir al menos un servicio` | |
| `stylist` | `Profesional debe existir` | `stylist_id` inexistente o ausente |

`400` si falta el objeto `appointment`.

Ejemplo de conflicto:

```json
{
  "error": "Revisá los datos ingresados",
  "errors": { "scheduled_at": ["Fecha y hora el estilista ya tiene un turno en ese horario"] }
}
```

---

### `PATCH /appointments/:id/cancel`

Cancela un turno propio.

**Respuesta `200`**: `Appointment` con `status: "cancelled"` y `cancellable: false`.

```bash
curl -X PATCH http://localhost:3000/api/v1/appointments/69/cancel -H "Authorization: Bearer $TOKEN"
```

```json
{
  "id": 69,
  "scheduled_at": "2026-11-05T17:00:00-03:00",
  "ends_at": "2026-11-05T17:30:00-03:00",
  "status": "cancelled",
  "status_label": "Cancelado",
  "duration_minutes": 30,
  "cancellable": false,
  "notes": null,
  "total": 8500.0,
  "stylist": { "id": 1, "name": "Ana Pérez" },
  "services": [{ "id": 1, "name": "Corte", "price_at_booking": 8500.0 }]
}
```

**Errores**

| Código | Caso | Cuerpo |
|---|---|---|
| `422` | Ya cancelado, realizado o ya empezó (`cancellable: false`) | `{"error": "El turno ya no se puede cancelar"}` |
| `404` | No existe o es de otro cliente | `{"error": "No encontrado"}` |

---

### `GET /appointments/:id/availability`

Horarios libres para **reprogramar** un turno propio: mismo profesional y misma duración, sin
contar el propio turno como ocupado. *Nuevo en TP 2.*

| Parámetro | Ubicación | Tipo | Obligatorio |
|---|---|---|---|
| `id` | ruta | integer | sí |
| `date` | consulta | string `AAAA-MM-DD` | sí |

**Respuesta `200`**: `Availability`.

```bash
curl "http://localhost:3000/api/v1/appointments/69/availability?date=2026-11-05" -H "Authorization: Bearer $TOKEN"
```

```json
{ "date": "2026-11-05", "duration_minutes": 30, "slots": ["09:00", "11:30", "12:00", "17:00"] }
```

**Errores**: `400` fecha inválida; `404` turno inexistente o ajeno.

### `PATCH /appointments/:id/reschedule`

Mueve un turno propio a otra fecha/hora. Se mantienen profesional, servicios y precios. El turno
vuelve a quedar **`pending`** porque el local tiene que confirmar el horario nuevo. *Nuevo en TP 2.*

| Campo | Tipo | Obligatorio | Validaciones |
|---|---|---|---|
| `appointment.scheduled_at` | string ISO 8601 | sí | Las mismas reglas de horario que al reservar |

**Respuesta `200`**: `Appointment` actualizado.

```bash
curl -X PATCH http://localhost:3000/api/v1/appointments/69/reschedule \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"appointment":{"scheduled_at":"2026-11-05T17:00"}}'
```

```json
{
  "id": 69,
  "scheduled_at": "2026-11-05T17:00:00-03:00",
  "ends_at": "2026-11-05T17:30:00-03:00",
  "status": "pending",
  "status_label": "Pendiente",
  "duration_minutes": 30,
  "cancellable": true,
  "notes": null,
  "total": 8500.0,
  "stylist": { "id": 1, "name": "Ana Pérez" },
  "services": [{ "id": 1, "name": "Corte", "price_at_booking": 8500.0 }]
}
```

**Errores**

| Código | Caso | Cuerpo |
|---|---|---|
| `422` | Turno cancelado, realizado o ya empezado | `{"error": "El turno ya no se puede reprogramar"}` |
| `422` | Horario inválido u ocupado | `{"error": "Revisá los datos ingresados", "errors": {"scheduled_at": [...]}}` (mismos mensajes que al reservar) |
| `400` | Falta el objeto `appointment` | `{"error": "Falta el parámetro: appointment"}` |
| `404` | No existe o es de otro cliente | `{"error": "No encontrado"}` |

---

## 7. Reglas de negocio

- **Horario de atención**: lunes a sábado de 9 a 19 hs, en bloques de 30 minutos. El turno completo
  (inicio + duración de todos sus servicios) tiene que entrar antes del cierre.
- **Superposición**: un profesional no puede tener dos turnos activos (`pending` o `confirmed`) que
  se superpongan, teniendo en cuenta la duración de cada uno. Un turno de 90 min a las 10:00 ocupa
  10:00, 10:30 y 11:00. Los turnos cancelados liberan el horario.
- **Pasado**: no se puede reservar ni reprogramar a un horario que ya pasó.
- **Cancelar / reprogramar**: solo turnos `pending` o `confirmed` que todavía no empezaron (campo
  `cancellable`). Reprogramar deja el turno en `pending`.
- **Precio pactado**: se congela el precio de cada servicio al reservar.
- **Estados**: el cliente solo puede pasar un turno a `cancelled`. Confirmar o marcar como realizado
  se hace desde el back-office.

---

## 8. Resumen de endpoints

| Método | Ruta | Auth | Descripción |
|---|---|---|---|
| `POST` | `/login` | — | Iniciar sesión |
| `POST` | `/register` | — | Crear cuenta e iniciar sesión *(TP 2)* |
| `DELETE` | `/logout` | Token | Cerrar sesión |
| `GET` | `/me` | Token | Ver perfil *(TP 2)* |
| `PATCH` | `/me` | Token | Editar perfil *(TP 2)* |
| `PATCH` | `/me/password` | Token | Cambiar contraseña *(TP 2)* |
| `GET` | `/categories` | — | Listar categorías |
| `GET` | `/categories/:id` | — | Categoría con sus servicios |
| `GET` | `/services` | — | Listar servicios (`category_id`, `q`) |
| `GET` | `/services/:id` | — | Ver servicio |
| `GET` | `/stylists` | — | Listar profesionales (`q`) |
| `GET` | `/stylists/:id` | — | Ver profesional |
| `GET` | `/stylists/:id/availability` | — | Horarios libres (`date`, `service_ids[]`) |
| `GET` | `/appointments` | Token | Mis turnos (`scope`) |
| `GET` | `/appointments/:id` | Token | Ver turno |
| `POST` | `/appointments` | Token | Reservar |
| `PATCH` | `/appointments/:id/cancel` | Token | Cancelar |
| `GET` | `/appointments/:id/availability` | Token | Horarios para reprogramar *(TP 2)* |
| `PATCH` | `/appointments/:id/reschedule` | Token | Reprogramar *(TP 2)* |

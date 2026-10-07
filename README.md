# TP1 Programación IV — Sistema de turnos

Backend en Ruby on Rails para un sistema de gestión de turnos de peluquería / centro de estética.

Los clientes reservan turnos online para servicios específicos (corte, color, manicura, etc.) con un
estilista determinado. El personal del local administra estilistas, servicios, categorías y la agenda
desde un back-office.

La definición funcional completa está en [DEFINICION.md](DEFINICION.md).

---

## Estado actual

| Parte | Estado |
|---|---|
| Modelos, migraciones y validaciones | Implementado |
| Portal de clientes (registro, login, reserva con horarios libres, mis turnos, cancelar) | Implementado |
| Back-office `/admin` (dashboard, agenda, turnos, clientes, catálogo, reportes, administradores) | Implementado |
| API `/api/v1` con login por token | Implementado |
| Active Storage (foto del profesional) | Implementado |
| Action Mailer (email de confirmación al reservar) | Implementado |
| Seeds (`db/seeds.rb`) | Implementado |
| Tests de modelos, integración, API y mailer | Implementado |

La app es genérica: el nombre del negocio se configura con la variable de entorno `BUSINESS_NAME`
(por defecto "Estudio Turnos") y en el front el estilista se muestra como "Profesional".

### Usuarios de prueba (seeds)

| Rol | Email | Contraseña | URL |
|---|---|---|---|
| Admin | `admin@turnos.test` | `admin1234` | `/admin` |
| Cliente | `juan@mail.com` | `cliente123` | `/ingresar` |

### Pantallas

| URL | Descripción |
|---|---|
| `/` | Home: equipo de profesionales y servicios con precios |
| `/profesionales/:id` | Horarios libres de un profesional por día |
| `/registro`, `/ingresar` | Alta y login de clientes |
| `/mis-turnos` | Próximos turnos e historial del cliente |
| `/mis-turnos/new` | Reserva: servicios, profesional, fecha y horario (se cargan desde la API) |
| `/admin` | Dashboard: agenda del día, pendientes, facturación del mes, próximos 7 días |
| `/admin/agenda` | Grilla del día (profesionales × horarios); un bloque libre abre "nuevo turno" precargado |
| `/admin/turnos` | Turnos con búsqueda por cliente, rango de fechas, profesional y estado; paginado y exportable a CSV |
| `/admin/clientes` | ABM de clientes (alta desde mostrador), historial y métricas por cliente |
| `/admin/profesionales`, `/admin/servicios`, `/admin/categorias` | Catálogo, con turnos y reservas por ítem |
| `/admin/reportes` | Reporte mensual: facturado, a cobrar, ticket promedio, turnos por día y estado, ranking de profesionales y servicios |
| `/admin/administradores` | ABM de usuarios del back-office (nadie puede borrarse a sí mismo) |

El diseño sigue el sistema visual de Merkén: papel cálido, tinta oscura y acento terracota, con
Instrument Serif para títulos, Syne para texto y DM Mono para datos. Todo vive en
`app/assets/stylesheets/application.css`, sin frameworks.

Horario de atención: lunes a sábado de 9 a 19, en bloques de 30 minutos (`Stylist::OPENING_HOUR`,
`CLOSING_HOUR`, `SLOT_MINUTES`).

En desarrollo los emails no se envían: se guardan en `tmp/mails/`.

---

## Stack

- Ruby 3.3.12
- Rails 8.1.3
- SQLite 3
- Puma
- bcrypt (hash de contraseñas)
- Active Storage (foto de perfil del estilista)

---

## Puesta en marcha

Requisitos: Ruby 3.3.12 instalado (la versión está fijada en `.ruby-version`).

```bash
# 1. Instalar dependencias
bundle install

# 2. Crear la base de datos, aplicar migraciones y cargar los datos de prueba
bin/rails db:setup

# 3. Levantar el servidor
bin/rails server
```

La aplicación queda en `http://localhost:3000`.

Para verificar que arrancó bien: `http://localhost:3000/up` debe responder `200`.
Cualquier otra URL va a dar `404` hasta que se definan las rutas.

### Consola

```bash
bin/rails console
```

Ejemplo para crear datos a mano:

```ruby
categoria = Category.create!(name: "Cabello")
Service.create!(category: categoria, name: "Corte", duration_minutes: 30, price: 8500)
Stylist.create!(name: "Ana Pérez", specialty: "Colorista")
Client.create!(name: "Juan", email: "juan@mail.com", password: "secret123")
```

### Tests

```bash
bin/rails test
```

---

## Modelo de datos

Siete entidades. Los tipos indicados son los de la base; la API los va a serializar a JSON
(`decimal` a número, `datetime` a string ISO 8601).

### Diagrama de relaciones

```
Category ──< Service ──< AppointmentService >── Appointment >── Client
                                                     │
                                                     └──>── Stylist
```

- Una `Category` agrupa muchos `Service`.
- Un `Client` reserva muchos `Appointment`.
- Un `Stylist` atiende muchos `Appointment`.
- Un `Appointment` incluye muchos `Service` a través de `AppointmentService`.

### AdminUser

Personal del local con acceso al back-office. No se expone en la API pública.

| Campo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `id` | integer | — | |
| `name` | string | Sí | |
| `email` | string | Sí | Único, con formato de email válido |
| `password_digest` | string | Sí | Nunca se expone. Se setea vía `password` |

### Client

Usuario final que reserva turnos.

| Campo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `id` | integer | — | |
| `name` | string | Sí | |
| `email` | string | Sí | Único, con formato de email válido |
| `phone` | string | No | |
| `password_digest` | string | Sí | Nunca se expone. Se setea vía `password` |
| `api_token` | string | No | Único. Se genera al hacer login |

El token se genera con `client.regenerate_api_token!` y es un string hexadecimal de 48 caracteres.

### Stylist

Profesional que atiende los turnos. Es una entidad de negocio: **no inicia sesión en el sistema**.

| Campo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `id` | integer | — | |
| `name` | string | Sí | |
| `specialty` | string | Sí | Ej. "Colorista", "Manicura" |
| `bio` | text | No | |
| `photo` | archivo adjunto | No | Active Storage, una sola imagen |

### Category

| Campo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `id` | integer | — | |
| `name` | string | Sí | Único |

No se puede eliminar una categoría que tenga servicios asociados.

### Service

| Campo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `id` | integer | — | |
| `category_id` | integer | Sí | |
| `name` | string | Sí | |
| `description` | text | No | |
| `duration_minutes` | integer | Sí | Entero mayor a 0 |
| `price` | decimal(8,2) | Sí | Mayor o igual a 0 |

No se puede eliminar un servicio que ya esté incluido en algún turno.

### Appointment

| Campo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `id` | integer | — | |
| `client_id` | integer | Sí | |
| `stylist_id` | integer | Sí | |
| `scheduled_at` | datetime | Sí | Fecha y hora del turno |
| `status` | string | Sí | Por defecto `pending` |
| `notes` | text | No | |

Valores posibles de `status`:

| Valor | Significado |
|---|---|
| `pending` | Reservado, pendiente de confirmación |
| `confirmed` | Confirmado por el local |
| `completed` | Turno ya realizado |
| `cancelled` | Cancelado |

Al eliminar un turno se eliminan sus `AppointmentService` asociados.

### AppointmentService

Detalle de los servicios incluidos en un turno.

| Campo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `id` | integer | — | |
| `appointment_id` | integer | Sí | |
| `service_id` | integer | Sí | |
| `price_at_booking` | decimal(8,2) | Sí | Se completa solo al crear |

---

## Reglas de negocio

Estas reglas producen errores de validación. El frontend tiene que mostrarlos al usuario.

**1. Un turno no puede agendarse en el pasado.**
Si `scheduled_at` es anterior al momento actual:
`scheduled_at: "no puede ser en el pasado"`

**2. Un estilista no puede tener dos turnos a la misma hora.**
Se valida contra turnos del mismo estilista, en el mismo `scheduled_at`, cuyo estado no sea
`cancelled`. Si hay conflicto:
`scheduled_at: "el estilista ya tiene un turno en ese horario"`

Nota: la comparación es por horario exacto, no por rango. Dos turnos del mismo estilista a las 10:00
y 10:15 no chocan aunque el servicio dure 30 minutos.

**3. Un mismo servicio no puede repetirse dentro de un turno.**
`service: "ya fue agregado a este turno"`

**4. El precio del servicio se congela al reservar.**
`price_at_booking` se completa automáticamente con el precio del servicio en el momento de la
reserva. Si después el local cambia el precio, los turnos ya reservados mantienen el precio original.
Para mostrar el total de un turno hay que sumar los `price_at_booking`, **no** los `price` actuales
de los servicios.

---

## API

Base: `/api/v1`. Autenticación por token: el login devuelve el `api_token`, que se manda en el header
`Authorization: Bearer <api_token>`.

| Método | Endpoint | Auth | Descripción |
|---|---|---|---|
| `POST` | `/api/v1/login` | No | Body `{ email, password }`. Devuelve `{ token, client }` |
| `DELETE` | `/api/v1/logout` | Sí | Invalida el token |
| `GET` | `/api/v1/categories` | No | Listado de categorías (`/:id` incluye sus servicios) |
| `GET` | `/api/v1/services` | No | Listado de servicios (filtro opcional `?category_id=`) |
| `GET` | `/api/v1/stylists` | No | Listado de profesionales (con `photo_url`) |
| `GET` | `/api/v1/stylists/:id/availability?date=AAAA-MM-DD` | No | Horarios libres del día |
| `GET` | `/api/v1/appointments` | Sí | Turnos del cliente autenticado |
| `GET` | `/api/v1/appointments/:id` | Sí | Detalle de un turno propio |
| `POST` | `/api/v1/appointments` | Sí | Reservar. Body `{ appointment: { stylist_id, scheduled_at, service_ids: [], notes } }` |
| `PATCH` | `/api/v1/appointments/:id/cancel` | Sí | Cancelar un turno propio futuro |

Errores de validación: `422` con `{ "errors": { "scheduled_at": ["Fecha y hora no puede ser en el pasado"] } }`.

Ejemplo:

```bash
TOKEN=$(curl -s -X POST localhost:3000/api/v1/login -H 'Content-Type: application/json' \
  -d '{"email":"juan@mail.com","password":"cliente123"}' | ruby -rjson -e 'puts JSON.parse(STDIN.read)["token"]')
curl -s localhost:3000/api/v1/appointments -H "Authorization: Bearer $TOKEN"
```

---

## Estructura del repositorio

```
app/models/          Las 7 entidades del dominio
config/routes.rb     Rutas (portal, /admin y /api/v1)
db/migrate/          Migraciones
db/schema.rb         Esquema actual de la base
db/seeds.rb          Datos de prueba
test/                Tests de modelos, integración, API y mailer
DEFINICION.md        Definición funcional del proyecto
```

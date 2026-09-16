# TP1 Programación IV — Sistema de turnos

Backend en Ruby on Rails para un sistema de gestión de turnos de peluquería / centro de estética.

Los clientes reservan turnos online para servicios específicos (corte, color, manicura, etc.) con un
estilista determinado. El personal del local administra estilistas, servicios, categorías y la agenda
desde un back-office.

La definición funcional completa está en [DEFINICION.md](DEFINICION.md).

---

## Estado actual

> **Importante para quien arranque el frontend:** la API todavía no está implementada.
> No existe ningún endpoint al que pegarle en este momento.

| Parte | Estado |
|---|---|
| Modelos, migraciones y validaciones | Implementado |
| Tests de modelos | Implementado |
| Rutas (`config/routes.rb`) | Vacío |
| Controllers de API | No existen |
| Back-office `/admin` | No existe |
| Autenticación (login admin / token cliente) | No existe |
| Datos de prueba (`db/seeds.rb`) | Vacío |
| Active Storage (foto de estilista) | Declarado en el modelo, sin endpoint |
| Action Mailer (email de confirmación) | No existe |

Lo único que se puede usar hoy es la consola de Rails (`bin/rails console`) para crear y consultar
registros. La sección [Modelo de datos](#modelo-de-datos) describe las estructuras que la API va a
exponer cuando exista, y sirve para ir diseñando las pantallas.

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

# 2. Crear la base de datos y aplicar migraciones
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

Ejemplo para crear datos a mano mientras no haya seeds:

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

## API prevista

> Nada de esto está implementado todavía. Es el diseño acordado en `DEFINICION.md` y está sujeto a
> cambios. Conviene confirmar el contrato exacto antes de escribir el cliente HTTP.

Base: `/api/v1`

Autenticación por token. El login devuelve el `api_token` del cliente, que se manda en los requests
siguientes mediante el header:

```
Authorization: Bearer <api_token>
```

| Método | Endpoint | Auth | Descripción |
|---|---|---|---|
| `POST` | `/api/v1/login` | No | Login de cliente, devuelve el token |
| `GET` | `/api/v1/stylists` | No | Listado de estilistas |
| `GET` | `/api/v1/services` | No | Listado de servicios |
| `GET` | `/api/v1/categories` | No | Listado de categorías |
| `POST` | `/api/v1/appointments` | Sí | Reservar un turno |
| `GET` | `/api/v1/appointments` | Sí | Turnos del cliente autenticado |

Además, un back-office en `/admin` con sesión tradicional de Rails para el CRUD de estilistas,
categorías, servicios y turnos.

---

## Estructura del repositorio

```
app/models/          Las 7 entidades del dominio
config/routes.rb     Rutas (vacío por ahora)
db/migrate/          Migraciones
db/schema.rb         Esquema actual de la base
db/seeds.rb          Datos de prueba (vacío por ahora)
test/models/         Tests de los modelos
DEFINICION.md        Definición funcional del proyecto
```

---

## Próximos pasos

1. Cargar `db/seeds.rb` con datos de prueba, para poder desarrollar el frontend contra datos reales.
2. Definir las rutas de `/api/v1` y sus controllers.
3. Implementar el login con token y el filtro de autenticación.
4. Implementar el back-office `/admin`.
5. Agregar el mailer de confirmación de turno.

# Todoapp

A Phoenix-backed TODO list with drag-and-drop reordering powered by base-62
fractional indexing.

## Setup

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Visit [`localhost:4000`](http://localhost:4000) for the LiveView UI; the JSON
API lives under `/api`.

> **Heads up:** the `tasks.position` column is collated with `"C"` (byte
> order) so PostgreSQL sorts positions the same way the fractional-index
> generator does. If `mix ecto.migrate` hasn't been run yet, do that first
> or position-based ordering will misbehave.

## API reference

Base URL: `http://localhost:4000/api`. Everything is JSON; pass
`-H 'Content-Type: application/json'` on writes and `-H 'Accept: application/json'`
on reads (the curl examples below include both for copy/paste).

### `GET /tasks` — list all tasks

Returns every task ordered by position (descending). Convenient for small
datasets and the LiveView; for larger number of rows, use
`/tasks/paginated` instead.

```bash
curl -s http://localhost:4000/api/tasks \
  -H 'Accept: application/json' | jq
```

Response:
```json
{ "data": [ { "id": 1, "title": "...", "position": "V", ... } ] }
```

### `GET /tasks/paginated` — cursor-paginated list

Same data, but bounded per request. Default page size is **50**; pass
`?limit=N` to override. Pass back the `next_cursor` from the previous
response as `?after=<cursor>` to walk the next page. `next_cursor` is
`null` when you've reached the end.

```bash
# First page
curl -s 'http://localhost:4000/api/tasks/paginated?limit=20' \
  -H 'Accept: application/json' | jq

# Next page (substitute the value from the previous response)
curl -s 'http://localhost:4000/api/tasks/paginated?limit=20&after=Vk' \
  -H 'Accept: application/json' | jq
```

Response:
```json
{
  "data": [ { "id": 1, "title": "...", "position": "V", ... } ],
  "next_cursor": "Vk"
}
```

### `GET /tasks/:id` — show one task

```bash
curl -s http://localhost:4000/api/tasks/1 \
  -H 'Accept: application/json' | jq
```

Response: `{ "data": { "id": 1, "title": "...", ... } }`. Returns 404 if no
task with that id exists.

### `POST /tasks` — create a task

The request body wraps the task under `"task"`. `title`, `description`, and
`status` are required; **`position` is optional** — when omitted, the
controller derives one strictly greater than the current max position so the
new task lands at the end of the list.

```bash
# With an explicit position
curl -sX POST http://localhost:4000/api/tasks \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json' \
  -d '{"task": {"title": "First", "description": "demo", "status": "pending", "position": "V"}}' | jq

# Without a position (auto-assigned at the end)
curl -sX POST http://localhost:4000/api/tasks \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json' \
  -d '{"task": {"title": "Second", "description": "demo", "status": "pending"}}' | jq
```

Returns 201 with `{ "data": { ... } }` and a `Location` header pointing at
the new task. 422 with `{"errors": ...}` on validation failure.

### `PUT /tasks/:id` (or `PATCH`) — update a task

Same wrapper as create. Any subset of fields can be updated.

```bash
curl -sX PUT http://localhost:4000/api/tasks/1 \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json' \
  -d '{"task": {"status": "in_progress"}}' | jq
```

### `DELETE /tasks/:id` — delete a task

```bash
curl -sX DELETE http://localhost:4000/api/tasks/1 \
  -H 'Accept: application/json' -w '%{http_code}\n'
```

Returns `204 No Content` on success.

### `POST /tasks/:id/reorder` — reorder a task

Takes the **positions** of the neighbours the task should land between.
Either side can be omitted to mean "open-ended" (drop at the very start
or very end). Both omitted yields the middle-of-the-table position
`"V"` — useful for the very first task in an empty list.

```bash
# Drop between two known positions
curl -sX POST http://localhost:4000/api/tasks/3/reorder \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json' \
  -d '{"prev_pos": "a", "next_pos": "b"}' | jq

# Drop at the very beginning
curl -sX POST http://localhost:4000/api/tasks/3/reorder \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json' \
  -d '{"next_pos": "a"}' | jq

# Drop at the very end
curl -sX POST http://localhost:4000/api/tasks/3/reorder \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json' \
  -d '{"prev_pos": "z"}' | jq
```

Returns `200` with the updated task. Returns `400` with
`{"error": "no_space"}` if no string can fit between `prev_pos` and
`next_pos` (e.g. they're equal, or differ by an unfillable boundary like
`"a"` / `"a0"`).

## Typical drag-and-drop flow

A client moving task `T` between visible neighbours `A` and `B`:

1. Read `A.position` and `B.position` from the rendered list.
2. `POST /api/tasks/:T/reorder` with `{"prev_pos": A.position, "next_pos": B.position}`.
3. Use the returned task's new `position` in the UI; subsequent reorders
   continue from there.

If the user drops at the very top or bottom of the column, omit the
corresponding side and the server will generate an open-ended position.

## Running the tests

```bash
mix test
```

The suite covers CRUD, the fractional-index helper (including a
100-iteration stress test), and the cursor pagination endpoint.

## Learn more about Phoenix

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix

import { csrfToken } from "utils/csrf"

class HttpError extends Error {
  constructor(response) {
    super(`HTTP ${response.status}`)
    this.response = response
    this.status = response.status
  }
}

export async function request(url, options = {}) {
  const headers = { "X-CSRF-Token": csrfToken(), ...options.headers }
  const response = await fetch(url, { ...options, headers })
  if (!response.ok) throw new HttpError(response)
  return response
}

export async function getJSON(url) {
  const resp = await request(url, { headers: { Accept: "application/json" } })
  return resp.json()
}

export async function postJSON(url, body) {
  const resp = await request(url, {
    method: "POST",
    headers: { "Content-Type": "application/json", Accept: "application/json" },
    body: JSON.stringify(body)
  })
  return resp.json()
}

export async function patchJSON(url, body) {
  const headers = { Accept: "application/json" }
  const options = { method: "PATCH", headers }
  if (body !== undefined) {
    headers["Content-Type"] = "application/json"
    options.body = JSON.stringify(body)
  }
  const resp = await request(url, options)
  return resp.json()
}

export async function turboGet(url) {
  const resp = await request(url, { headers: { Accept: "text/vnd.turbo-stream.html" } })
  return resp.text()
}

export async function turboPost(url, body) {
  const resp = await request(url, {
    method: "POST",
    headers: { Accept: "text/vnd.turbo-stream.html" },
    body
  })
  return resp.text()
}

export async function turboPatch(url, body) {
  const headers = { Accept: "text/vnd.turbo-stream.html" }
  if (body && !(body instanceof FormData) && !(body instanceof URLSearchParams)) {
    headers["Content-Type"] = "application/json"
    body = JSON.stringify(body)
  }
  const resp = await request(url, { method: "PATCH", headers, body })
  return resp.text()
}

export async function turboDelete(url) {
  const resp = await request(url, {
    method: "DELETE",
    headers: { Accept: "text/vnd.turbo-stream.html" }
  })
  return resp.text()
}

export function fireAndForget(url, options = {}) {
  request(url, options).catch(err => console.error(`Request failed: ${url}`, err))
}

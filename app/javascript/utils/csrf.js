export function csrfToken() {
  return document.querySelector("[name='csrf-token']")?.content
}

export function showError(message, err) {
  if (err) console.error(message, err)
  const el = document.createElement("div")
  el.className = "fixed bottom-4 right-4 bg-red-600 text-white px-4 py-2 rounded-lg shadow-lg text-sm z-50"
  el.textContent = message
  document.body.appendChild(el)
  setTimeout(() => el.remove(), 3000)
}

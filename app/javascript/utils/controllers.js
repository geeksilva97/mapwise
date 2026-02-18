export function findController(application, selector, controllerName) {
  const el = selector.startsWith("#")
    ? document.getElementById(selector.slice(1))
    : document.querySelector(selector)
  if (!el) return null
  return application.getControllerForElementAndIdentifier(el, controllerName)
}

export function findMapController(application) {
  return findController(application, "#map-canvas", "map")
}

export function findDrawingController(application) {
  return findController(application, "[data-controller~='drawing']", "drawing")
}

export function findTrackingController(application) {
  return findController(application, "[data-controller~='tracking']", "tracking")
}

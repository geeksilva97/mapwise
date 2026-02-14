# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin_all_from "app/javascript/utils", under: "utils"

pin "@googlemaps/markerclusterer", to: "https://ga.jspm.io/npm:@googlemaps/markerclusterer@2.5.3/dist/index.esm.js"
pin "fast-deep-equal", to: "https://ga.jspm.io/npm:fast-deep-equal@3.1.3/index.js"
pin "supercluster", to: "https://ga.jspm.io/npm:supercluster@8.0.1/index.js"
pin "kdbush", to: "https://ga.jspm.io/npm:kdbush@4.0.2/index.js"
pin "terra-draw", to: "terra-draw.js"
pin "terra-draw-google-maps-adapter", to: "terra-draw-google-maps-adapter.js"

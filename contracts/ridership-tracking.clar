;; Ridership Tracking Contract
;; Monitors passenger volumes across routes

(define-data-var admin principal tx-sender)

;; Map of routes to route details
(define-map routes
  uint
  {
    route-name: (string-ascii 50),
    route-type: (string-ascii 20), ;; "bus", "train", "subway", "tram"
    start-location: (string-ascii 100),
    end-location: (string-ascii 100),
    total-stops: uint,
    active: bool,
    creation-date: uint
  }
)

;; Map of stops to stop details
(define-map stops
  uint
  {
    route-id: uint,
    stop-name: (string-ascii 100),
    stop-order: uint,
    location: (string-ascii 100),
    active: bool
  }
)

;; Map of ridership records by day, route, and time slot
(define-map daily-ridership
  { day-id: uint, route-id: uint, time-slot: uint }
  {
    passenger-count: uint,
    capacity-percentage: uint,
    weather-condition: (string-ascii 20),
    is-holiday: bool,
    special-event: (string-ascii 100),
    last-updated: uint
  }
)

;; Map of stop-specific ridership (boardings and alightings)
(define-map stop-ridership
  { day-id: uint, stop-id: uint, time-slot: uint }
  {
    boardings: uint,
    alightings: uint,
    last-updated: uint
  }
)

;; Map of transit vehicles
(define-map vehicles
  uint
  {
    vehicle-type: (string-ascii 20), ;; "bus", "train", "subway-car", "tram"
    capacity: uint,
    route-id: uint,
    active: bool,
    registration-date: uint
  }
)

;; Map of data collectors
(define-map data-collectors
  principal
  {
    name: (string-ascii 100),
    organization: (string-ascii 100),
    authorized: bool,
    authorization-date: uint
  }
)

;; Counters for IDs
(define-data-var next-route-id uint u1)
(define-data-var next-stop-id uint u1)
(define-data-var next-vehicle-id uint u1)

;; Initialize the contract
(define-public (initialize)
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1))
    (ok true)
  )
)

;; Register a data collector
(define-public (register-data-collector (name (string-ascii 100)) (organization (string-ascii 100)))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u2))

    (map-set data-collectors
      tx-sender
      {
        name: name,
        organization: organization,
        authorized: true,
        authorization-date: block-height
      }
    )

    (ok true)
  )
)

;; Authorize a data collector
(define-public (authorize-data-collector (collector principal))
  (let (
    (collector-data (unwrap! (map-get? data-collectors collector) (err u3)))
  )
    (asserts! (is-eq tx-sender (var-get admin)) (err u2))

    (map-set data-collectors
      collector
      (merge collector-data {
        authorized: true,
        authorization-date: block-height
      })
    )

    (ok true)
  )
)

;; Revoke data collector authorization
(define-public (revoke-data-collector (collector principal))
  (let (
    (collector-data (unwrap! (map-get? data-collectors collector) (err u3)))
  )
    (asserts! (is-eq tx-sender (var-get admin)) (err u2))

    (map-set data-collectors
      collector
      (merge collector-data { authorized: false })
    )

    (ok true)
  )
)

;; Register a new route
(define-public (register-route
  (route-name (string-ascii 50))
  (route-type (string-ascii 20))
  (start-location (string-ascii 100))
  (end-location (string-ascii 100))
  (total-stops uint)
)
  (let (
    (route-id (var-get next-route-id))
  )
    (asserts! (is-eq tx-sender (var-get admin)) (err u2))

    ;; Create the route
    (map-set routes
      route-id
      {
        route-name: route-name,
        route-type: route-type,
        start-location: start-location,
        end-location: end-location,
        total-stops: total-stops,
        active: true,
        creation-date: block-height
      }
    )

    ;; Increment the route ID counter
    (var-set next-route-id (+ route-id u1))

    (ok route-id)
  )
)

;; Register a new stop
(define-public (register-stop
  (route-id uint)
  (stop-name (string-ascii 100))
  (stop-order uint)
  (location (string-ascii 100))
)
  (let (
    (stop-id (var-get next-stop-id))
    (route (unwrap! (map-get? routes route-id) (err u4)))
  )
    (asserts! (is-eq tx-sender (var-get admin)) (err u2))
    (asserts! (get active route) (err u5))
    (asserts! (<= stop-order (get total-stops route)) (err u6))

    ;; Create the stop
    (map-set stops
      stop-id
      {
        route-id: route-id,
        stop-name: stop-name,
        stop-order: stop-order,
        location: location,
        active: true
      }
    )

    ;; Increment the stop ID counter
    (var-set next-stop-id (+ stop-id u1))

    (ok stop-id)
  )
)

;; Register a new vehicle
(define-public (register-vehicle
  (vehicle-type (string-ascii 20))
  (capacity uint)
  (route-id uint)
)
  (let (
    (vehicle-id (var-get next-vehicle-id))
    (route (unwrap! (map-get? routes route-id) (err u4)))
  )
    (asserts! (is-eq tx-sender (var-get admin)) (err u2))
    (asserts! (get active route) (err u5))

    ;; Create the vehicle
    (map-set vehicles
      vehicle-id
      {
        vehicle-type: vehicle-type,
        capacity: capacity,
        route-id: route-id,
        active: true,
        registration-date: block-height
      }
    )

    ;; Increment the vehicle ID counter
    (var-set next-vehicle-id (+ vehicle-id u1))

    (ok vehicle-id)
  )
)

;; Record daily ridership data
(define-public (record-daily-ridership
  (day-id uint)
  (route-id uint)
  (time-slot uint)
  (passenger-count uint)
  (capacity-percentage uint)
  (weather-condition (string-ascii 20))
  (is-holiday bool)
  (special-event (string-ascii 100))
)
  (let (
    (collector-data (unwrap! (map-get? data-collectors tx-sender) (err u3)))
    (route (unwrap! (map-get? routes route-id) (err u4)))
  )
    ;; Only authorized data collectors can record ridership
    (asserts! (get authorized collector-data) (err u7))
    ;; Route must be active
    (asserts! (get active route) (err u5))
    ;; Time slot must be valid (0-23)
    (asserts! (< time-slot u24) (err u8))
    ;; Capacity percentage must be valid (0-100)
    (asserts! (<= capacity-percentage u100) (err u9))

    ;; Record the ridership data
    (map-set daily-ridership
      { day-id: day-id, route-id: route-id, time-slot: time-slot }
      {
        passenger-count: passenger-count,
        capacity-percentage: capacity-percentage,
        weather-condition: weather-condition,
        is-holiday: is-holiday,
        special-event: special-event,
        last-updated: block-height
      }
    )

    (ok true)
  )
)

;; Record stop-specific ridership data
(define-public (record-stop-ridership
  (day-id uint)
  (stop-id uint)
  (time-slot uint)
  (boardings uint)
  (alightings uint)
)
  (let (
    (collector-data (unwrap! (map-get? data-collectors tx-sender) (err u3)))
    (stop (unwrap! (map-get? stops stop-id) (err u10)))
  )
    ;; Only authorized data collectors can record ridership
    (asserts! (get authorized collector-data) (err u7))
    ;; Stop must be active
    (asserts! (get active stop) (err u11))
    ;; Time slot must be valid (0-23)
    (asserts! (< time-slot u24) (err u8))

    ;; Record the stop ridership data
    (map-set stop-ridership
      { day-id: day-id, stop-id: stop-id, time-slot: time-slot }
      {
        boardings: boardings,
        alightings: alightings,
        last-updated: block-height
      }
    )

    (ok true)
  )
)

;; Update route status
(define-public (update-route-status (route-id uint) (active bool))
  (let (
    (route (unwrap! (map-get? routes route-id) (err u4)))
  )
    (asserts! (is-eq tx-sender (var-get admin)) (err u2))

    ;; Update the route
    (map-set routes
      route-id
      (merge route { active: active })
    )

    (ok true)
  )
)

;; Update stop status
(define-public (update-stop-status (stop-id uint) (active bool))
  (let (
    (stop (unwrap! (map-get? stops stop-id) (err u10)))
  )
    (asserts! (is-eq tx-sender (var-get admin)) (err u2))

    ;; Update the stop
    (map-set stops
      stop-id
      (merge stop { active: active })
    )

    (ok true)
  )
)

;; Update vehicle status
(define-public (update-vehicle-status (vehicle-id uint) (active bool))
  (let (
    (vehicle (unwrap! (map-get? vehicles vehicle-id) (err u12)))
  )
    (asserts! (is-eq tx-sender (var-get admin)) (err u2))

    ;; Update the vehicle
    (map-set vehicles
      vehicle-id
      (merge vehicle { active: active })
    )

    (ok true)
  )
)

;; Get route details
(define-read-only (get-route (route-id uint))
  (map-get? routes route-id)
)

;; Get stop details
(define-read-only (get-stop (stop-id uint))
  (map-get? stops stop-id)
)

;; Get vehicle details
(define-read-only (get-vehicle (vehicle-id uint))
  (map-get? vehicles vehicle-id)
)

;; Get daily ridership data
(define-read-only (get-daily-ridership (day-id uint) (route-id uint) (time-slot uint))
  (map-get? daily-ridership { day-id: day-id, route-id: route-id, time-slot: time-slot })
)

;; Get stop ridership data
(define-read-only (get-stop-ridership (day-id uint) (stop-id uint) (time-slot uint))
  (map-get? stop-ridership { day-id: day-id, stop-id: stop-id, time-slot: time-slot })
)

;; Get data collector details
(define-read-only (get-data-collector (collector principal))
  (map-get? data-collectors collector)
)

;; Transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u2))
    (var-set admin new-admin)
    (ok true)
  )
)


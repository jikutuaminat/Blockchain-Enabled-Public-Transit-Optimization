;; Schedule Adjustment Contract
;; Optimizes transit timing based on demand

(define-data-var admin principal tx-sender)

;; Map of schedule versions
(define-map schedule-versions
  uint
  {
    version-name: (string-ascii 50),
    effective-date: uint,
    expiry-date: uint,
    status: (string-ascii 20), ;; "draft", "approved", "active", "expired"
    created-by: principal,
    approval-date: uint,
    approved-by: principal
  }
)

;; Map of route schedules
(define-map route-schedules
  { version-id: uint, route-id: uint }
  {
    first-departure: uint, ;; minutes from midnight
    last-departure: uint,  ;; minutes from midnight
    peak-frequency: uint,  ;; minutes between departures during peak
    off-peak-frequency: uint, ;; minutes between departures during off-peak
    weekend-frequency: uint,  ;; minutes between departures on weekends
    peak-start-morning: uint, ;; minutes from midnight
    peak-end-morning: uint,   ;; minutes from midnight
    peak-start-evening: uint, ;; minutes from midnight
    peak-end-evening: uint    ;; minutes from midnight
  }
)

;; Map of specific departures
(define-map scheduled-departures
  { version-id: uint, route-id: uint, departure-id: uint }
  {
    departure-time: uint, ;; minutes from midnight
    day-type: (string-ascii 20), ;; "weekday", "saturday", "sunday", "holiday"
    vehicle-id: uint,
    driver-id: uint,
    is-express: bool,
    notes: (string-ascii 200)
  }
)

;; Map of schedule adjustments
(define-map schedule-adjustments
  uint
  {
    route-id: uint,
    adjustment-type: (string-ascii 20), ;; "delay", "cancellation", "addition", "frequency-change"
    start-date: uint,
    end-date: uint,
    reason: (string-ascii 200),
    status: (string-ascii 20), ;; "planned", "active", "completed", "cancelled"
    created-by: principal,
    creation-date: uint
  }
)

;; Map of schedule planners
(define-map schedule-planners
  principal
  {
    name: (string-ascii 100),
    department: (string-ascii 100),
    authorized: bool,
    authorization-date: uint
  }
)

;; Map to track route details (simplified from ridership-tracking)
(define-map routes
  uint
  {
    route-name: (string-ascii 50),
    route-type: (string-ascii 20),
    active: bool
  }
)

;; Counters for IDs
(define-data-var next-version-id uint u1)
(define-data-var next-departure-id uint u1)
(define-data-var next-adjustment-id uint u1)

;; Initialize the contract
(define-public (initialize)
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1))
    (ok true)
  )
)

;; Set route details (admin function to sync with ridership-tracking)
(define-public (set-route-details
  (route-id uint)
  (route-name (string-ascii 50))
  (route-type (string-ascii 20))
  (active bool)
)
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u2))
    (map-set routes route-id {
      route-name: route-name,
      route-type: route-type,
      active: active
    })
    (ok true)
  )
)

;; Register a schedule planner
(define-public (register-planner (name (string-ascii 100)) (department (string-ascii 100)))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u2))

    (map-set schedule-planners
      tx-sender
      {
        name: name,
        department: department,
        authorized: true,
        authorization-date: block-height
      }
    )

    (ok true)
  )
)

;; Authorize a schedule planner
(define-public (authorize-planner (planner principal))
  (let (
    (planner-data (unwrap! (map-get? schedule-planners planner) (err u3)))
  )
    (asserts! (is-eq tx-sender (var-get admin)) (err u2))

    (map-set schedule-planners
      planner
      (merge planner-data {
        authorized: true,
        authorization-date: block-height
      })
    )

    (ok true)
  )
)

;; Revoke planner authorization
(define-public (revoke-planner (planner principal))
  (let (
    (planner-data (unwrap! (map-get? schedule-planners planner) (err u3)))
  )
    (asserts! (is-eq tx-sender (var-get admin)) (err u2))

    (map-set schedule-planners
      planner
      (merge planner-data { authorized: false })
    )

    (ok true)
  )
)

;; Create a new schedule version
(define-public (create-schedule-version
  (version-name (string-ascii 50))
  (effective-date uint)
  (expiry-date uint)
)
  (let (
    (version-id (var-get next-version-id))
    (planner-data (unwrap! (map-get? schedule-planners tx-sender) (err u3)))
  )
    ;; Only authorized planners can create schedule versions
    (asserts! (get authorized planner-data) (err u4))
    ;; Effective date must be before expiry date
    (asserts! (< effective-date expiry-date) (err u5))

    ;; Create the schedule version
    (map-set schedule-versions
      version-id
      {
        version-name: version-name,
        effective-date: effective-date,
        expiry-date: expiry-date,
        status: "draft",
        created-by: tx-sender,
        approval-date: u0,
        approved-by: tx-sender ;; Placeholder, will be updated on approval
      }
    )

    ;; Increment the version ID counter
    (var-set next-version-id (+ version-id u1))

    (ok version-id)
  )
)

;; Set route schedule
(define-public (set-route-schedule
  (version-id uint)
  (route-id uint)
  (first-departure uint)
  (last-departure uint)
  (peak-frequency uint)
  (off-peak-frequency uint)
  (weekend-frequency uint)
  (peak-start-morning uint)
  (peak-end-morning uint)
  (peak-start-evening uint)
  (peak-end-evening uint)
)
  (let (
    (version (unwrap! (map-get? schedule-versions version-id) (err u6)))
    (planner-data (unwrap! (map-get? schedule-planners tx-sender) (err u3)))
    (route (unwrap! (map-get? routes route-id) (err u7)))
  )
    ;; Only authorized planners can set schedules
    (asserts! (get authorized planner-data) (err u4))
    ;; Schedule version must be in draft status
    (asserts! (is-eq (get status version) "draft") (err u8))
    ;; Route must be active
    (asserts! (get active route) (err u9))
    ;; Time validations
    (asserts! (< first-departure last-departure) (err u10))
    (asserts! (< peak-start-morning peak-end-morning) (err u11))
    (asserts! (< peak-start-evening peak-end-evening) (err u12))
    (asserts! (< peak-end-morning peak-start-evening) (err u13))

    ;; Set the route schedule
    (map-set route-schedules
      { version-id: version-id, route-id: route-id }
      {
        first-departure: first-departure,
        last-departure: last-departure,
        peak-frequency: peak-frequency,
        off-peak-frequency: off-peak-frequency,
        weekend-frequency: weekend-frequency,
        peak-start-morning: peak-start-morning,
        peak-end-morning: peak-end-morning,
        peak-start-evening: peak-start-evening,
        peak-end-evening: peak-end-evening
      }
    )

    (ok true)
  )
)

;; Add a specific scheduled departure
(define-public (add-scheduled-departure
  (version-id uint)
  (route-id uint)
  (departure-time uint)
  (day-type (string-ascii 20))
  (vehicle-id uint)
  (driver-id uint)
  (is-express bool)
  (notes (string-ascii 200))
)
  (let (
    (departure-id (var-get next-departure-id))
    (version (unwrap! (map-get? schedule-versions version-id) (err u6)))
    (planner-data (unwrap! (map-get? schedule-planners tx-sender) (err u3)))
    (route (unwrap! (map-get? routes route-id) (err u7)))
  )
    ;; Only authorized planners can add departures
    (asserts! (get authorized planner-data) (err u4))
    ;; Schedule version must be in draft status
    (asserts! (is-eq (get status version) "draft") (err u8))
    ;; Route must be active
    (asserts! (get active route) (err u9))
    ;; Departure time must be valid (0-1439 minutes, representing 00:00 to 23:59)
    (asserts! (< departure-time u1440) (err u14))

    ;; Add the scheduled departure
    (map-set scheduled-departures
      { version-id: version-id, route-id: route-id, departure-id: departure-id }
      {
        departure-time: departure-time,
        day-type: day-type,
        vehicle-id: vehicle-id,
        driver-id: driver-id,
        is-express: is-express,
        notes: notes
      }
    )

    ;; Increment the departure ID counter
    (var-set next-departure-id (+ departure-id u1))

    (ok departure-id)
  )
)

;; Approve a schedule version
(define-public (approve-schedule-version (version-id uint))
  (let (
    (version (unwrap! (map-get? schedule-versions version-id) (err u6)))
  )
    (asserts! (is-eq tx-sender (var-get admin)) (err u2))
    ;; Schedule version must be in draft status
    (asserts! (is-eq (get status version) "draft") (err u8))

    ;; Update the schedule version
    (map-set schedule-versions
      version-id
      (merge version {
        status: "approved",
        approval-date: block-height,
        approved-by: tx-sender
      })
    )

    (ok true)
  )
)

;; Activate a schedule version
(define-public (activate-schedule-version (version-id uint))
  (let (
    (version (unwrap! (map-get? schedule-versions version-id) (err u6)))
  )
    (asserts! (is-eq tx-sender (var-get admin)) (err u2))
    ;; Schedule version must be approved
    (asserts! (is-eq (get status version) "approved") (err u15))

    ;; Update the schedule version
    (map-set schedule-versions
      version-id
      (merge version { status: "active" })
    )

    ;; Set all other active versions to expired
    ;; Note: In a real implementation, this would require iterating through all versions
    ;; which is not practical in Clarity. This would be handled by the application layer.

    (ok true)
  )
)

;; Create a schedule adjustment
(define-public (create-schedule-adjustment
  (route-id uint)
  (adjustment-type (string-ascii 20))
  (start-date uint)
  (end-date uint)
  (reason (string-ascii 200))
)
  (let (
    (adjustment-id (var-get next-adjustment-id))
    (planner-data (unwrap! (map-get? schedule-planners tx-sender) (err u3)))
    (route (unwrap! (map-get? routes route-id) (err u7)))
  )
    ;; Only authorized planners can create adjustments
    (asserts! (get authorized planner-data) (err u4))
    ;; Route must be active
    (asserts! (get active route) (err u9))
    ;; Start date must be before end date
    (asserts! (< start-date end-date) (err u5))

    ;; Create the adjustment
    (map-set schedule-adjustments
      adjustment-id
      {
        route-id: route-id,
        adjustment-type: adjustment-type,
        start-date: start-date,
        end-date: end-date,
        reason: reason,
        status: "planned",
        created-by: tx-sender,
        creation-date: block-height
      }
    )

    ;; Increment the adjustment ID counter
    (var-set next-adjustment-id (+ adjustment-id u1))

    (ok adjustment-id)
  )
)

;; Update adjustment status
(define-public (update-adjustment-status (adjustment-id uint) (status (string-ascii 20)))
  (let (
    (adjustment (unwrap! (map-get? schedule-adjustments adjustment-id) (err u16)))
    (planner-data (unwrap! (map-get? schedule-planners tx-sender) (err u3)))
  )
    ;; Only authorized planners can update adjustments
    (asserts! (get authorized planner-data) (err u4))

    ;; Update the adjustment
    (map-set schedule-adjustments
      adjustment-id
      (merge adjustment { status: status })
    )

    (ok true)
  )
)

;; Get schedule version details
(define-read-only (get-schedule-version (version-id uint))
  (map-get? schedule-versions version-id)
)

;; Get route schedule
(define-read-only (get-route-schedule (version-id uint) (route-id uint))
  (map-get? route-schedules { version-id: version-id, route-id: route-id })
)

;; Get scheduled departure
(define-read-only (get-scheduled-departure (version-id uint) (route-id uint) (departure-id uint))
  (map-get? scheduled-departures { version-id: version-id, route-id: route-id, departure-id: departure-id })
)

;; Get schedule adjustment
(define-read-only (get-schedule-adjustment (adjustment-id uint))
  (map-get? schedule-adjustments adjustment-id)
)

;; Get planner details
(define-read-only (get-planner (planner principal))
  (map-get? schedule-planners planner)
)

;; Get active schedule version
(define-read-only (get-active-schedule-version)
  ;; Note: In a real implementation, this would require iterating through all versions
  ;; which is not practical in Clarity. This would be handled by the application layer.
  ;; This is a placeholder function.
  u0
)

;; Transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u2))
    (var-set admin new-admin)
    (ok true)
  )
)


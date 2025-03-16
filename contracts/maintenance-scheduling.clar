;; Maintenance Scheduling Contract
;; Manages vehicle upkeep based on usage

(define-data-var admin principal tx-sender)

;; Map of maintenance schedules
(define-map maintenance-schedules
  uint
  {
    vehicle-id: uint,
    schedule-type: (string-ascii 50), ;; "routine", "preventive", "major-overhaul"
    interval-type: (string-ascii 20), ;; "mileage", "time", "engine-hours"
    interval-value: uint,
    last-maintenance-date: uint,
    last-maintenance-value: uint, ;; mileage, engine hours, etc.
    next-due-date: uint,
    next-due-value: uint,
    created-by: principal,
    creation-date: uint
  }
)

;; Map of maintenance records
(define-map maintenance-records
  uint
  {
    vehicle-id: uint,
    schedule-id: uint,
    maintenance-type: (string-ascii 50),
    performed-date: uint,
    performed-value: uint, ;; mileage, engine hours, etc.
    technician: principal,
    parts-replaced: (string-ascii 500),
    labor-hours: uint,
    cost: uint,
    notes: (string-ascii 500),
    status: (string-ascii 20) ;; "completed", "partial", "deferred"
  }
)

;; Map of maintenance alerts
(define-map maintenance-alerts
  uint
  {
    vehicle-id: uint,
    schedule-id: uint,
    alert-type: (string-ascii 20), ;; "upcoming", "overdue", "critical"
    alert-date: uint,
    acknowledged: bool,
    acknowledged-by: principal,
    acknowledgment-date: uint
  }
)

;; Map of vehicle usage
(define-map vehicle-usage
  { vehicle-id: uint, date: uint }
  {
    mileage: uint,
    engine-hours: uint,
    fuel-consumed: uint,
    routes-served: (string-ascii 200),
    driver: principal,
    last-updated: uint
  }
)

;; Map of maintenance technicians
(define-map technicians
  principal
  {
    name: (string-ascii 100),
    certification: (string-ascii 100),
    authorized: bool,
    authorization-date: uint
  }
)

;; Map to track vehicle details (simplified from ridership-tracking)
(define-map vehicles
  uint
  {
    vehicle-type: (string-ascii 20),
    active: bool,
    registration-date: uint
  }
)

;; Counters for IDs
(define-data-var next-schedule-id uint u1)
(define-data-var next-record-id uint u1)
(define-data-var next-alert-id uint u1)

;; Initialize the contract
(define-public (initialize)
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u1))
    (ok true)
  )
)

;; Set vehicle details (admin function to sync with ridership-tracking)
(define-public (set-vehicle-details
  (vehicle-id uint)
  (vehicle-type (string-ascii 20))
  (active bool)
  (registration-date uint)
)
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u2))
    (map-set vehicles vehicle-id {
      vehicle-type: vehicle-type,
      active: active,
      registration-date: registration-date
    })
    (ok true)
  )
)

;; Register a maintenance technician
(define-public (register-technician (name (string-ascii 100)) (certification (string-ascii 100)))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u2))

    (map-set technicians
      tx-sender
      {
        name: name,
        certification: certification,
        authorized: true,
        authorization-date: block-height
      }
    )

    (ok true)
  )
)

;; Authorize a technician
(define-public (authorize-technician (technician principal))
  (let (
    (technician-data (unwrap! (map-get? technicians technician) (err u3)))
  )
    (asserts! (is-eq tx-sender (var-get admin)) (err u2))

    (map-set technicians
      technician
      (merge technician-data {
        authorized: true,
        authorization-date: block-height
      })
    )

    (ok true)
  )
)

;; Revoke technician authorization
(define-public (revoke-technician (technician principal))
  (let (
    (technician-data (unwrap! (map-get? technicians technician) (err u3)))
  )
    (asserts! (is-eq tx-sender (var-get admin)) (err u2))

    (map-set technicians
      technician
      (merge technician-data { authorized: false })
    )

    (ok true)
  )
)

;; Create a maintenance schedule
(define-public (create-maintenance-schedule
  (vehicle-id uint)
  (schedule-type (string-ascii 50))
  (interval-type (string-ascii 20))
  (interval-value uint)
  (last-maintenance-date uint)
  (last-maintenance-value uint)
)
  (let (
    (schedule-id (var-get next-schedule-id))
    (vehicle (unwrap! (map-get? vehicles vehicle-id) (err u4)))
    (next-due-date (+ last-maintenance-date (* interval-value u144))) ;; Simplified calculation
    (next-due-value (+ last-maintenance-value interval-value))
  )
    (asserts! (is-eq tx-sender (var-get admin)) (err u2))
    (asserts! (get active vehicle) (err u5))

    ;; Create the maintenance schedule
    (map-set maintenance-schedules
      schedule-id
      {
        vehicle-id: vehicle-id,
        schedule-type: schedule-type,
        interval-type: interval-type,
        interval-value: interval-value,
        last-maintenance-date: last-maintenance-date,
        last-maintenance-value: last-maintenance-value,
        next-due-date: next-due-date,
        next-due-value: next-due-value,
        created-by: tx-sender,
        creation-date: block-height
      }
    )

    ;; Increment the schedule ID counter
    (var-set next-schedule-id (+ schedule-id u1))

    (ok schedule-id)
  )
)

;; Record vehicle usage
(define-public (record-vehicle-usage
  (vehicle-id uint)
  (date uint)
  (mileage uint)
  (engine-hours uint)
  (fuel-consumed uint)
  (routes-served (string-ascii 200))
)
  (let (
    (vehicle (unwrap! (map-get? vehicles vehicle-id) (err u4)))
    (existing-usage (map-get? vehicle-usage { vehicle-id: vehicle-id, date: date }))
  )
    (asserts! (is-eq tx-sender (var-get admin)) (err u2))
    (asserts! (get active vehicle) (err u5))

    ;; Record the vehicle usage
    (map-set vehicle-usage
      { vehicle-id: vehicle-id, date: date }
      {
        mileage: mileage,
        engine-hours: engine-hours,
        fuel-consumed: fuel-consumed,
        routes-served: routes-served,
        driver: tx-sender,
        last-updated: block-height
      }
    )

    ;; Check for maintenance alerts
    ;; Note: In a real implementation, this would require iterating through all schedules
    ;; which is not practical in Clarity. This would be handled by the application layer.

    (ok true)
  )
)

;; Record maintenance performed
(define-public (record-maintenance
  (vehicle-id uint)
  (schedule-id uint)
  (maintenance-type (string-ascii 50))
  (performed-value uint)
  (parts-replaced (string-ascii 500))
  (labor-hours uint)
  (cost uint)
  (notes (string-ascii 500))
  (status (string-ascii 20))
)
  (let (
    (record-id (var-get next-record-id))
    (technician-data (unwrap! (map-get? technicians tx-sender) (err u3)))
    (vehicle (unwrap! (map-get? vehicles vehicle-id) (err u4)))
    (schedule (unwrap! (map-get? maintenance-schedules schedule-id) (err u6)))
  )
    ;; Only authorized technicians can record maintenance
    (asserts! (get authorized technician-data) (err u7))
    ;; Vehicle must be active
    (asserts! (get active vehicle) (err u5))
    ;; Schedule must be for this vehicle
    (asserts! (is-eq (get vehicle-id schedule) vehicle-id) (err u8))

    ;; Record the maintenance
    (map-set maintenance-records
      record-id
      {
        vehicle-id: vehicle-id,
        schedule-id: schedule-id,
        maintenance-type: maintenance-type,
        performed-date: block-height,
        performed-value: performed-value,
        technician: tx-sender,
        parts-replaced: parts-replaced,
        labor-hours: labor-hours,
        cost: cost,
        notes: notes,
        status: status
      }
    )

    ;; Update the maintenance schedule
    (map-set maintenance-schedules
      schedule-id
      (merge schedule {
        last-maintenance-date: block-height,
        last-maintenance-value: performed-value,
        next-due-date: (+ block-height (* (get interval-value schedule) u144)),
        next-due-value: (+ performed-value (get interval-value schedule))
      })
    )

    ;; Increment the record ID counter
    (var-set next-record-id (+ record-id u1))

    (ok record-id)
  )
)

;; Create a maintenance alert
(define-public (create-maintenance-alert
  (vehicle-id uint)
  (schedule-id uint)
  (alert-type (string-ascii 20))
)
  (let (
    (alert-id (var-get next-alert-id))
    (vehicle (unwrap! (map-get? vehicles vehicle-id) (err u4)))
    (schedule (unwrap! (map-get? maintenance-schedules schedule-id) (err u6)))
  )
    (asserts! (is-eq tx-sender (var-get admin)) (err u2))
    (asserts! (get active vehicle) (err u5))
    (asserts! (is-eq (get vehicle-id schedule) vehicle-id) (err u8))

    ;; Create the alert
    (map-set maintenance-alerts
      alert-id
      {
        vehicle-id: vehicle-id,
        schedule-id: schedule-id,
        alert-type: alert-type,
        alert-date: block-height,
        acknowledged: false,
        acknowledged-by: tx-sender, ;; Placeholder, will be updated on acknowledgment
        acknowledgment-date: u0
      }
    )

    ;; Increment the alert ID counter
    (var-set next-alert-id (+ alert-id u1))

    (ok alert-id)
  )
)

;; Acknowledge a maintenance alert
(define-public (acknowledge-alert (alert-id uint))
  (let (
    (alert (unwrap! (map-get? maintenance-alerts alert-id) (err u9)))
  )
    (asserts! (is-eq tx-sender (var-get admin)) (err u2))

    ;; Update the alert
    (map-set maintenance-alerts
      alert-id
      (merge alert {
        acknowledged: true,
        acknowledged-by: tx-sender,
        acknowledgment-date: block-height
      })
    )

    (ok true)
  )
)

;; Get maintenance schedule
(define-read-only (get-maintenance-schedule (schedule-id uint))
  (map-get? maintenance-schedules schedule-id)
)

;; Get maintenance record
(define-read-only (get-maintenance-record (record-id uint))
  (map-get? maintenance-records record-id)
)

;; Get maintenance alert
(define-read-only (get-maintenance-alert (alert-id uint))
  (map-get? maintenance-alerts alert-id)
)

;; Get vehicle usage
(define-read-only (get-vehicle-usage (vehicle-id uint) (date uint))
  (map-get? vehicle-usage { vehicle-id: vehicle-id, date: date })
)

;; Get technician details
(define-read-only (get-technician (technician principal))
  (map-get? technicians technician)
)

;; Check if maintenance is due
(define-read-only (is-maintenance-due (schedule-id uint))
  (match (map-get? maintenance-schedules schedule-id)
    schedule (< (get next-due-date schedule) block-height)
    false)
)

;; Transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u2))
    (var-set admin new-admin)
    (ok true)
  )
)


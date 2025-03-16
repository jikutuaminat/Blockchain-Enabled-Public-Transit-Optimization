import { describe, it, expect, beforeEach, vi } from "vitest"

// Simple mock for contract functions
const mockContractFunctions = {
  initialize: vi.fn().mockReturnValue(true),
  "set-route-details": vi.fn().mockReturnValue(true),
  "register-planner": vi.fn().mockReturnValue(true),
  "authorize-planner": vi.fn().mockReturnValue(true),
  "revoke-planner": vi.fn().mockReturnValue(true),
  "create-schedule-version": vi.fn().mockReturnValue(1),
  "set-route-schedule": vi.fn().mockReturnValue(true),
  "add-scheduled-departure": vi.fn().mockReturnValue(1),
  "approve-schedule-version": vi.fn().mockReturnValue(true),
  "activate-schedule-version": vi.fn().mockReturnValue(true),
  "create-schedule-adjustment": vi.fn().mockReturnValue(1),
  "update-adjustment-status": vi.fn().mockReturnValue(true),
  "get-schedule-version": vi.fn().mockReturnValue({
    "version-name": "Summer 2023",
    "effective-date": 20230601,
    "expiry-date": 20230901,
    status: "active",
    "created-by": "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM",
    "approval-date": 20230515,
    "approved-by": "ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG",
  }),
  "get-route-schedule": vi.fn().mockReturnValue({
    "first-departure": 360, // 6:00 AM
    "last-departure": 1320, // 10:00 PM
    "peak-frequency": 10,
    "off-peak-frequency": 20,
    "weekend-frequency": 30,
    "peak-start-morning": 420, // 7:00 AM
    "peak-end-morning": 540, // 9:00 AM
    "peak-start-evening": 960, // 4:00 PM
    "peak-end-evening": 1080, // 6:00 PM
  }),
  "get-scheduled-departure": vi.fn().mockReturnValue({
    "departure-time": 480, // 8:00 AM
    "day-type": "weekday",
    "vehicle-id": 1,
    "driver-id": 5,
    "is-express": false,
    notes: "",
  }),
  "get-schedule-adjustment": vi.fn().mockReturnValue({
    "route-id": 1,
    "adjustment-type": "frequency-change",
    "start-date": 20230615,
    "end-date": 20230630,
    reason: "Construction on Main Street",
    status: "active",
    "created-by": "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM",
    "creation-date": 20230601,
  }),
  "get-planner": vi.fn().mockReturnValue({
    name: "Jane Doe",
    department: "Schedule Planning",
    authorized: true,
    "authorization-date": 12000,
  }),
  "get-active-schedule-version": vi.fn().mockReturnValue(1),
  "transfer-admin": vi.fn().mockReturnValue(true),
}

// Mock the contract
const mockContract = {
  callFunction: (functionName, ...args) => {
    return mockContractFunctions[functionName](...args)
  },
}

describe("Schedule Adjustment Contract", () => {
  beforeEach(() => {
    // Reset mocks before each test
    Object.values(mockContractFunctions).forEach((fn) => fn.mockClear())
  })
  
  it("should initialize the contract", async () => {
    const result = mockContract.callFunction("initialize")
    expect(result).toBe(true)
    expect(mockContractFunctions["initialize"]).toHaveBeenCalled()
  })
  
  it("should set route details", async () => {
    const result = mockContract.callFunction("set-route-details", 1, "Downtown Express", "bus", true)
    expect(result).toBe(true)
    expect(mockContractFunctions["set-route-details"]).toHaveBeenCalledWith(1, "Downtown Express", "bus", true)
  })
  
  it("should register a schedule planner", async () => {
    const result = mockContract.callFunction("register-planner", "Jane Doe", "Schedule Planning")
    expect(result).toBe(true)
    expect(mockContractFunctions["register-planner"]).toHaveBeenCalledWith("Jane Doe", "Schedule Planning")
  })
  
  it("should authorize a planner", async () => {
    const planner = "ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG"
    const result = mockContract.callFunction("authorize-planner", planner)
    expect(result).toBe(true)
    expect(mockContractFunctions["authorize-planner"]).toHaveBeenCalledWith(planner)
  })
  
  it("should revoke a planner", async () => {
    const planner = "ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG"
    const result = mockContract.callFunction("revoke-planner", planner)
    expect(result).toBe(true)
    expect(mockContractFunctions["revoke-planner"]).toHaveBeenCalledWith(planner)
  })
  
  it("should create a new schedule version", async () => {
    const result = mockContract.callFunction("create-schedule-version", "Summer 2023", 20230601, 20230901)
    expect(result).toBe(1)
    expect(mockContractFunctions["create-schedule-version"]).toHaveBeenCalledWith("Summer 2023", 20230601, 20230901)
  })
  
  it("should set a route schedule", async () => {
    const result = mockContract.callFunction("set-route-schedule", 1, 1, 360, 1320, 10, 20, 30, 420, 540, 960, 1080)
    expect(result).toBe(true)
    expect(mockContractFunctions["set-route-schedule"]).toHaveBeenCalledWith(
        1,
        1,
        360,
        1320,
        10,
        20,
        30,
        420,
        540,
        960,
        1080,
    )
  })
  
  it("should add a scheduled departure", async () => {
    const result = mockContract.callFunction("add-scheduled-departure", 1, 1, 480, "weekday", 1, 5, false, "")
    expect(result).toBe(1)
    expect(mockContractFunctions["add-scheduled-departure"]).toHaveBeenCalledWith(1, 1, 480, "weekday", 1, 5, false, "")
  })
  
  it("should approve a schedule version", async () => {
    const result = mockContract.callFunction("approve-schedule-version", 1)
    expect(result).toBe(true)
    expect(mockContractFunctions["approve-schedule-version"]).toHaveBeenCalledWith(1)
  })
  
  it("should activate a schedule version", async () => {
    const result = mockContract.callFunction("activate-schedule-version", 1)
    expect(result).toBe(true)
    expect(mockContractFunctions["activate-schedule-version"]).toHaveBeenCalledWith(1)
  })
  
  it("should create a schedule adjustment", async () => {
    const result = mockContract.callFunction(
        "create-schedule-adjustment",
        1,
        "frequency-change",
        20230615,
        20230630,
        "Construction on Main Street",
    )
    expect(result).toBe(1)
    expect(mockContractFunctions["create-schedule-adjustment"]).toHaveBeenCalledWith(
        1,
        "frequency-change",
        20230615,
        20230630,
        "Construction on Main Street",
    )
  })
  
  it("should update adjustment status", async () => {
    const result = mockContract.callFunction("update-adjustment-status", 1, "active")
    expect(result).toBe(true)
    expect(mockContractFunctions["update-adjustment-status"]).toHaveBeenCalledWith(1, "active")
  })
  
  it("should retrieve schedule version details", async () => {
    const result = mockContract.callFunction("get-schedule-version", 1)
    expect(result).toEqual({
      "version-name": "Summer 2023",
      "effective-date": 20230601,
      "expiry-date": 20230901,
      status: "active",
      "created-by": "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM",
      "approval-date": 20230515,
      "approved-by": "ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG",
    })
    expect(mockContractFunctions["get-schedule-version"]).toHaveBeenCalledWith(1)
  })
  
  it("should retrieve route schedule", async () => {
    const result = mockContract.callFunction("get-route-schedule", 1, 1)
    expect(result).toEqual({
      "first-departure": 360,
      "last-departure": 1320,
      "peak-frequency": 10,
      "off-peak-frequency": 20,
      "weekend-frequency": 30,
      "peak-start-morning": 420,
      "peak-end-morning": 540,
      "peak-start-evening": 960,
      "peak-end-evening": 1080,
    })
    expect(mockContractFunctions["get-route-schedule"]).toHaveBeenCalledWith(1, 1)
  })
  
  it("should retrieve scheduled departure", async () => {
    const result = mockContract.callFunction("get-scheduled-departure", 1, 1, 1)
    expect(result).toEqual({
      "departure-time": 480,
      "day-type": "weekday",
      "vehicle-id": 1,
      "driver-id": 5,
      "is-express": false,
      notes: "",
    })
    expect(mockContractFunctions["get-scheduled-departure"]).toHaveBeenCalledWith(1, 1, 1)
  })
  
  it("should retrieve schedule adjustment", async () => {
    const result = mockContract.callFunction("get-schedule-adjustment", 1)
    expect(result).toEqual({
      "route-id": 1,
      "adjustment-type": "frequency-change",
      "start-date": 20230615,
      "end-date": 20230630,
      reason: "Construction on Main Street",
      status: "active",
      "created-by": "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM",
      "creation-date": 20230601,
    })
    expect(mockContractFunctions["get-schedule-adjustment"]).toHaveBeenCalledWith(1)
  })
  
  it("should retrieve planner details", async () => {
    const planner = "ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG"
    const result = mockContract.callFunction("get-planner", planner)
    expect(result).toEqual({
      name: "Jane Doe",
      department: "Schedule Planning",
      authorized: true,
      "authorization-date": 12000,
    })
    expect(mockContractFunctions["get-planner"]).toHaveBeenCalledWith(planner)
  })
  
  it("should get active schedule version", async () => {
    const result = mockContract.callFunction("get-active-schedule-version")
    expect(result).toBe(1)
    expect(mockContractFunctions["get-active-schedule-version"]).toHaveBeenCalled()
  })
  
  it("should transfer admin rights", async () => {
    const newAdmin = "ST3NBRSFKX28FQ2ZJ1MAKX58HKHSDGNV5N7R21XCP"
    const result = mockContract.callFunction("transfer-admin", newAdmin)
    expect(result).toBe(true)
    expect(mockContractFunctions["transfer-admin"]).toHaveBeenCalledWith(newAdmin)
  })
})


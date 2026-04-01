# Safety Supervisor — Design v0.3

**Status:** Implemented
**Date:** 2026-03-31

---

## 1. Purpose

The `SafetySupervisor` sits between the planner output and the actuators. If the forward path is threatened, it either scales back throttle (CAUTION) or fully stops the robot (BRAKE). The planner and UI are notified of the current safety state.

---

## 2. Root-Cause Analysis (from v0.2)

The v0.2 binary PASS/BRAKE design caused stop-go oscillation due to three interacting failure modes:

1. **Binary Brake Policy:** The system oscillated at the threshold boundary because there were only two output states — full throttle or zero throttle.
2. **Speed-Dependent Threshold + Instant Brake:** When the supervisor braked, speed dropped, which shrank the threshold, which released the brake, which raised speed, which expanded the threshold, which triggered the brake — a positive feedback loop. The hysteresis couldn't fix this because the threshold itself was moving.
3. **Unfiltered Depth:** Frame-to-frame LiDAR noise triggered the full brake/release cycle even without real obstacle motion.

---

## 3. Safety Policy: Tri-Zone State Machine

### Design Principles

1. **Never allow speed changes to contradict the safety decision that caused them.** A brake triggered at speed `v` must remain in effect until the obstacle distance *genuinely improves*, not until speed drops enough to shrink the threshold.
2. **Smooth commands prevent mechanical oscillation.** The output space must be continuous, not binary. Transitions from full-speed to full-stop pass through intermediate throttle levels.
3. **Sensor noise must be filtered temporally, not just spatially.** Decisions are based on a smoothed depth signal.

### Three Zones

| Zone        | Condition                                  | Action                          |
|-------------|--------------------------------------------|---------------------------------|
| **CLEAR**   | `filteredDepth > clearDistance`             | Pass command unchanged          |
| **CAUTION** | `brakeDistance ≤ filteredDepth ≤ clearDistance` | Scale throttle linearly to 0 |
| **BRAKE**   | `filteredDepth < brakeDistance`             | Full stop                       |

### Zone Boundaries

Each boundary is the maximum of three components:

**Brake Distance:**
```
d_brake = max(minBrakeDistanceM, speed × ttcBrakeS, speed² / (2 × maxDeceleration))
```

**Clear Distance:**
```
d_clear = max(minCautionDistanceM, speed × ttcCautionS, speed² / (2 × maxDeceleration))
```

### Latched Speed

When the supervisor detects a threat (transitions from CLEAR to CAUTION or BRAKE), it **latches the current speed**. All subsequent threshold calculations use `max(latchedSpeed, currentSpeed)` until the state returns to CLEAR.

This prevents the self-contradicting feedback loop: braking reduces speed, but the threshold remains computed from the speed at threat onset.

### Cooldown Timers

- BRAKE must persist for at least `minBrakeDurationS` (0.5s) before transitioning to CAUTION.
- CAUTION must persist for at least `minCautionDurationS` (0.3s) before transitioning to CLEAR.
- BRAKE always transitions through CAUTION (never directly to CLEAR).

### State Transition Diagram

```
                     depth ≥ clearDist AND cooldown expired
               ┌──────────────────────────────────────────┐
               │                                          │
    ┌──────────▼──────────┐    depth < clearDist    ┌─────┴──────────┐
    │       CLEAR         │───────────────────────▶│    CAUTION     │
    │  (pass unchanged)   │                        │ (scale throttle)│
    └─────────────────────┘                        └───────┬────────┘
                                                           │
                                            depth < brakeDist
                                                           │
                                                  ┌────────▼────────┐
                                                  │     BRAKE       │
                                                  │ (full stop)     │
                                                  └─────────────────┘
                                                   exit: cooldown ≥ 0.5s
                                                   → CAUTION → CLEAR
```

---

## 4. Depth Filtering (Asymmetric EMA)

Raw LiDAR depth is smoothed with an Exponential Moving Average:

```
filteredDepth = α × rawDepth + (1 - α) × filteredDepth_prev
```

The alpha is **asymmetric for safety**:
- **Approaching** (rawDepth < filtered): `α = 0.5` — react faster to closing obstacles.
- **Receding** (rawDepth > filtered): `α = 0.3` — slower release prevents premature brake release from noise.

---

## 5. CAUTION Zone Throttle Scaling

In the CAUTION zone, throttle is linearly interpolated between zero and the planner's requested value:

```
scale = (filteredDepth - brakeDistance) / (clearDistance - brakeDistance)
outputThrottle = plannerThrottle × clamp(scale, 0, 1)
```

This creates a smooth deceleration ramp instead of a binary snap.

---

## 6. Configuration

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `fallbackSpeedMPS` | `0.3` | Conservative speed when sensors unavailable |
| `ttcBrakeS` | `1.5` | TTC threshold for BRAKE zone |
| `ttcCautionS` | `2.5` | TTC threshold for CAUTION zone |
| `minBrakeDistanceM` | `0.3` | Absolute minimum BRAKE distance |
| `minCautionDistanceM` | `0.5` | Absolute minimum CAUTION distance |
| `maxDecelerationMPS2` | `0.5` | Max braking deceleration (m/s²) |
| `minBrakeDurationS` | `0.5` | Min time in BRAKE before CAUTION |
| `minCautionDurationS` | `0.3` | Min time in CAUTION before CLEAR |
| `depthEmaAlphaApproaching` | `0.5` | EMA alpha when obstacle approaching |
| `depthEmaAlphaReceding` | `0.3` | EMA alpha when obstacle receding |
| `minSpeedEpsilonMPS` | `0.01` | Division-by-zero guard |

---

## 7. `SafetySupervisorEvent`

```swift
struct SafetySupervisorEvent: Equatable {
    let timestamp: TimeInterval
    let ttc: Float
    let forwardDepth: Float     // raw depth
    let filteredDepth: Float    // EMA-smoothed depth

    enum Action: Equatable {
        case clear
        case caution(throttleScale: Float, reason: String)
        case brakeApplied(String)
    }

    let action: Action
}
```

---

## 8. Extensibility

Future versions can:
- Sample a forward cone instead of one pixel
- Add lateral obstacle detection for steering constraints
- Add speed-adaptive EMA alpha (faster filtering at higher speeds)
- Log full state machine trace for offline analysis
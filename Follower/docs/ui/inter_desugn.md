# SwiftUI Interaction Design Principles for Codex

## 1. Interaction Intent
Every interaction must help the user complete a task faster, safer, or more confidently.
Do not add interaction for novelty.
Every tap, swipe, and animation must have a clear purpose.

## 2. Predictability
Behavior must match iOS conventions wherever possible.
Users should be able to guess what happens before they tap.
Do not surprise users with custom gestures or hidden behavior.

## 3. Navigation
Use standard Apple navigation patterns first.
Prefer NavigationStack, TabView, sheet, popover, and split view when appropriate.
Do not hide core destinations behind unclear custom navigation.

## 4. Primary Action
Each screen should have one clear primary action.
Secondary actions must not compete visually with the main task.
Do not scatter equal-priority buttons across the screen.

## 5. Feedback
Every user action must provide feedback.
Feedback can be visual, textual, haptic, or structural, but it must be immediate and clear.
Do not leave users wondering whether their action worked.

## 6. Motion
Animation must clarify transitions, hierarchy, or state changes.
Use motion sparingly and with restraint.
Do not add bounce, spin, scale, or flourish unless it improves understanding.

## 7. State Handling
Loading, empty, error, disabled, and success states must be explicit.
Users should always know what state the system is in.
Do not leave blank screens or ambiguous placeholders.

## 8. Touch Targets
Interactive elements must be easy to tap.
Spacing should prevent accidental touches.
Do not reduce usability in pursuit of visual compactness.

## 9. Input
Forms must be efficient, forgiving, and clearly structured.
Use native controls whenever possible.
Validation should be timely, specific, and helpful.

## 10. Accessibility
Interaction must remain usable with VoiceOver, Dynamic Type, and Reduce Motion enabled.
Do not make gestures the only way to access important functions.
Do not rely on visual-only cues for critical actions.

## 11. Error Recovery
Errors must be recoverable.
Error messages should explain what happened and what to do next.
Do not expose technical jargon unless the user needs it.

## 12. Interaction Anti-Patterns
Avoid:
- hidden gestures with no visible affordance
- custom controls that replace native behavior
- modal overload
- infinite animation with no purpose
- unclear destructive actions
- “tap around and discover” interfaces
- excessive confirmation dialogs for low-risk actions

## 13. Interaction Quality Standard
The interface should feel calm, direct, and reliable.
Users should never need to fight the UI to finish a task.
# BreakNudgeTimer — specification

**Tagline:** Gentle micro-breaks and long breaks that dim your screen, count down and remind you to rest your eyes.

**Category:** Timers & Reminders

**Inspired by (paid):** Time Out ($9.95 one-time)

**Frameworks:** SwiftUI, AppKit, UserNotifications, IOKit, CoreGraphics, ServiceManagement

**Donation URL (Support button):** https://ko-fi.com/leodavidai

## Spec

What the paid app does: Time Out by Dejal is a long-standing break reminder for the Mac, sold at roughly 9.95 dollars for the full version with a free limited edition, and it holds a consistently high rating from people who want to avoid eye strain and repetitive strain. Alternatives such as Stretchly and Eye Break show the demand. Our free clean-room version covers normal and micro breaks with a gentle overlay.

Feature set: Two repeating break types. Micro breaks, default 20 seconds every 20 minutes, and normal breaks, default 5 minutes every 60 minutes. Each has configurable interval, duration, and message. At break time, the screen gets a translucent overlay with a countdown and a short message, with options to postpone for five minutes or skip when allowed. Work time only counts while the user is active, based on idle time, and the timer resets after a long idle period which counts as a natural break. A pause for one hour or until tomorrow option exists. A do not disturb mode skips breaks while the display is mirrored or a full screen app is in front, optionally.

UI spec: MenuBarExtra showing a small countdown to the next break in the title. The menu offers Take Break Now, Pause for an Hour, Pause Until Tomorrow, Skip Next Break, and Settings. Settings has two sections for break types with steppers for interval and duration, message text fields, toggles for allow skip and allow postpone, sound choice, idle reset minutes, and launch at login. The overlay is a borderless window per display with a blurred material, big countdown, message and buttons. A pre-break notification appears 30 seconds ahead through UserNotifications.

Technical approach: A one-second Timer in a model object accumulates active seconds and uses CGEventSource secondsSinceLastEventType with the combined session state to measure idle time, requiring no permission. Overlay windows use NSWindow at a high level with SwiftUI content on every NSScreen. Notifications are requested through UNUserNotificationCenter. Detecting a full screen app uses NSWorkspace frontmost app together with window bounds from CGWindowListCopyWindowInfo, and display sleep or lock is observed via workspace notifications and distributed notifications for screen lock. Settings use AppStorage. Launch at login uses SMAppService. IOKit is used to read idle time as a fallback through the HID idle time property.

Edge cases and error handling: Sleep and wake reset the timers and count as a break if longer than the break duration. Clock changes use monotonic uptime for intervals. If both break types are due together, only the long break shows. Notification permission denied falls back to the overlay only. Ensure the overlay never traps the user, with Escape always dismissing it unless strict mode is chosen, and even strict mode ends on the timer. About 450 lines.

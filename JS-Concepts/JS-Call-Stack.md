# Call Stack — Summary

Condensed from [33 JavaScript Concepts — Call Stack](https://33jsconcepts.com/concepts/call-stack) (see also [MDN: Call stack](https://developer.mozilla.org/en-US/docs/Glossary/Call_stack)).

---

## What it is

JavaScript uses a **call stack** to know **which function is running** and **where to return** when that function finishes. Each function call adds a frame on top; when the function returns, that frame is removed (**LIFO**: Last In, First Out — like a stack of plates: you only add/remove from the top).

---

## Why it exists

- JS is **single-threaded**: one call stack, one piece of synchronous work at a time.
- Nested calls are tracked so the engine can resume the **caller** after the **callee** returns.

---

## What sits on the stack (execution context / stack frame)

Roughly: arguments, local variables, `this`, where to return, and the **scope chain** (outer scopes — ties into closures).

---

## How it behaves (sync code)

Functions run to completion before their caller continues. Deeper nesting → deeper stack (see “full diagram” style traces on the [same page](https://33jsconcepts.com/concepts/call-stack#full-diagram)).

---

## Stack overflow

The stack has a **limited depth**. **Infinite recursion** or missing/wrong **base case** keeps pushing frames until: **`RangeError: Maximum call stack size exceeded`** (typical in V8/Chrome).

**Fix:** always have a base case and ensure each recursive step moves toward it; use loops when recursion isn’t needed.

---

## Call stack vs async

`setTimeout`, `fetch`, DOM events, etc. **don’t** run the callback immediately on the stack. They go through **Web APIs / task queues** and the **event loop** runs callbacks when the stack is empty — so e.g. `setTimeout(..., 0)` still runs **after** current synchronous code.

See: [Event Loop (MDN)](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Event_loop) and your `JS-Event-Loop.md` note.

---

## Debugging

Errors print a **stack trace** (newest call at top). DevTools **Call Stack** panel shows frames when paused at a breakpoint.

---

## Quick misconceptions (corrected)

| Misconception | Reality |
| --- | --- |
| Call stack = heap | **No** — stack tracks execution; heap holds objects (referenced from frames). |
| `setTimeout(0)` runs immediately | **No** — callback waits for stack to clear (and microtasks, etc.). |
| Multiple functions run at once | **No** for JS code — concurrency is coordinated via the event loop, not parallel JS execution on one stack. |

---

## Key takeaways

1. **LIFO** order for calls and returns.  
2. Each call = new **execution context** / frame.  
3. **Stack overflow** = too deep, usually bad recursion.  
4. **Async** is layered on top: stack for sync; queues + event loop for callbacks.  
5. **Stack traces** show how you reached an error.

**Deeper context on the same site:** [Event Loop](https://33jsconcepts.com/concepts/event-loop) · [Promises](https://33jsconcepts.com/concepts/promises)

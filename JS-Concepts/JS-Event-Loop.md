To understand the **JavaScript Event Loop**, think of it as the system that lets JavaScript handle asynchronous work while running on a single thread.
---
### **1. Core Idea**
JavaScript executes one task at a time on the **Call Stack**.
Long-running or delayed tasks (timers, network, DOM events) are handled by browser/Node APIs, then queued to run later.
The **Event Loop** continuously checks if the call stack is empty and pushes queued callbacks when it can.
---
### **2. Main Parts**
* **Call Stack:** Where synchronous code runs.
* **Web APIs / Node APIs:** Where async operations are handled outside the stack.
* **Callback Queue (Task Queue):** Holds macrotasks (like `setTimeout`, DOM events).
* **Microtask Queue:** Holds higher-priority tasks (like Promise `.then`, `queueMicrotask`, `MutationObserver`).
* **Event Loop:** Moves tasks from queues to stack in the correct order.
---
### **3. Execution Order (Important)**
1. Run all synchronous code on the call stack.
2. Run **all microtasks** in the microtask queue.
3. Run one macrotask from callback queue.
4. Repeat.

Because microtasks run before the next macrotask, Promise callbacks usually run before `setTimeout(..., 0)`.
---
### **4. Example**
```javascript
console.log("A");

setTimeout(() => console.log("B"), 0);

Promise.resolve().then(() => console.log("C"));

console.log("D");
```
Output:
```text
A
D
C
B
```
Explanation:
* `A` and `D` are synchronous.
* Promise `.then` goes to microtask queue (`C`).
* `setTimeout` callback goes to macrotask queue (`B`).
* Microtasks run before macrotasks.
---
### **5. Common Pitfalls**
* **Blocking the stack:** Heavy synchronous loops freeze UI.
* **Too many microtasks:** Can starve macrotasks and delay rendering/events.
* **Assuming `setTimeout(..., 0)` is immediate:** It still waits for current stack + microtasks.
---
### **Quick Rule**
Synchronous first, then microtasks, then macrotasks.

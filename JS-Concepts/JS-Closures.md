To understand **closures** in JavaScript, think of them as a function's ability to remember variables from its outer scope, even after that outer function has finished running.
---
### **1. What Is a Closure?**
A closure is created when an inner function references variables from an outer function and keeps access to them later.
* **Key idea:** Functions in JavaScript carry their lexical environment with them.
* **Why it matters:** This enables private state and powerful function patterns.
---
### **2. Core Example**
```javascript
function createCounter() {
  let count = 0;
  return function () {
    count++;
    return count;
  };
}

const counter = createCounter();
console.log(counter()); // 1
console.log(counter()); // 2
```
* `count` is not global, but it is still accessible to the returned function.
* This is closure in action.
---
### **3. Common Use Cases**
* **Data privacy / encapsulation:** Keep values private without exposing direct access.
* **Function factories:** Create specialized functions from one template.
* **Memoization / caching:** Store previous results in a closed-over variable.
* **Event handlers:** Preserve context across delayed execution.
* **Module pattern:** Group related logic with private internals.
---
### **4. Pitfalls**
* **Shared mutable state:** Multiple functions may accidentally modify the same closed-over variable.
* **Memory retention:** Capturing large objects can keep memory alive longer than expected.
* **Loop issues with `var`:** Closures may capture one shared variable instead of per-iteration values.
---
### **5. `var` vs `let` in Loops**
```javascript
for (var i = 0; i < 3; i++) {
  setTimeout(() => console.log(i), 0); // 3, 3, 3
}

for (let j = 0; j < 3; j++) {
  setTimeout(() => console.log(j), 0); // 0, 1, 2
}
```
* `var` is function-scoped, so callbacks share one variable.
* `let` is block-scoped, so each iteration gets its own binding.
---
### **Quick Rule**
If an inner function still uses outer variables after the outer function has returned, you're using a closure.

**Factory functions** and **ES6 classes** are two ways to define a blueprint and create many similar objects. Factories are plain functions that **return** objects (no `new`). Classes use `class` + `constructor` and instances are created with **`new`**.

Source: [Factories & Classes — 33 JavaScript Concepts](https://33jsconcepts.com/concepts/factories-classes) · [MDN: Classes](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Classes)

---
### **1. Factory function**

A function that builds and returns a new object each call. Can use **`this`** on the returned object, or **closures** for state and privacy.

```js
function createPlayer(name) {
  return {
    name,
    health: 100,
    attack() {
      return `${this.name} attacks!`;
    },
  };
}

const p = createPlayer("Alice"); // no `new`
```

* **Config object** pattern: merge defaults with `{ ...defaults, ...config }`.
* **Closures:** variables inside the factory are **not** on the returned object → **true privacy** (unlike a public `balance` property).
* **Flexible:** can return different shapes based on input (not always the same “type”).
* **`instanceof`** does not apply to plain objects from factories (no constructor prototype chain in the same way).

---
### **2. Constructor functions + `new`**

A function meant to be called with **`new`**: creates an object, wires **`[[Prototype]]`**, runs the body with **`this`** as the new object, returns the object (unless you return another object).

Rough mental model:

1. Create empty object (and set prototype from `Constructor.prototype`).
2. Run constructor with `this` bound to that object.
3. Return `this` (or a non-primitive explicitly returned).

**Pitfall:** calling `Player("Alice")` **without** `new` breaks `this` (global leakage in sloppy mode; error in strict mode).

**Memory:** methods assigned as **`this.method = function () {}`** inside the constructor → **one function per instance**. Better: put methods on **`Constructor.prototype`** so instances share one function.

---
### **3. ES6 `class` (syntactic sugar)**

`class` is **syntax** over constructor + prototype. `typeof MyClass === "function"` still holds.

```js
class Player {
  constructor(name) {
    this.name = name;
    this.health = 100;
  }
  attack() {
    return `${this.name} attacks!`;
  }
}

const p = new Player("Bob");
console.log(p instanceof Player); // true
```

* **Instance methods** in the class body live on **`Player.prototype`** (shared).
* **`static`** methods/properties belong to the **class**, not instances (`Player.fromJSON(...)`).
* **Getters / setters** — accessed like properties; good for validation or derived values.
* **Private fields `#`** — **language-enforced** privacy (SyntaxError if accessed from outside).
* **`extends` / `super`:** subclass constructors must call **`super()`** before using **`this`**.

---
### **4. Privacy: `#` vs closures vs `_underscore`**

| Approach | Enforced? | Notes |
| :--- | :--- | :--- |
| **`_prop`** | No | Convention only; still readable/writable from outside. |
| **Closure in factory** | Yes | Private vars; methods close over them; each instance may own method objects. |
| **`#field` in class** | Yes | True privacy; methods typically still shared on prototype. |

---
### **5. Inheritance vs composition**

* **Inheritance (`extends`):** “**is-a**” hierarchy, shared behavior up the chain, **`instanceof`** works across the chain. Risk: deep trees, awkward overrides (e.g. “bird that can’t fly”).
* **Composition (factories):** small behavior objects/functions merged with spread — “**has** these capabilities.” Flexible; favors **favor composition over inheritance** when behavior mixes don’t fit a single tree.

---
### **6. Factory vs class — quick comparison**

| | **Factory** | **Class** |
| :--- | :--- | :--- |
| **`new`** | Not required | Required |
| **`instanceof`** | Not meaningful for plain returned objects | Works |
| **Shared methods** | Easy to accidentally duplicate per instance | Prototype methods shared by default |
| **Privacy** | Closures (classic) or module scope | `#` private fields |
| **`this` pitfalls** | Avoidable with closures | Extracted methods may lose `this` (bind / arrow fields) |

---
### **7. Common mistakes**

1. **Forgot `new`** on a constructor — use `class` (throws if invoked without `new`) or safe patterns.
2. **`this` before `super()`** in a subclass — call **`super(...)`** first.
3. **`_name` as “private”** — it is not; use **`#`** or closures.
4. **Detached method** — `const fn = obj.method; fn()` loses `this`; closures or arrow class fields can help.

---
### **8. Quick takeaway**

* **Factories:** return objects; great for **composition** and **closure-based** privacy.
* **Classes:** `new`, **prototypes**, **`instanceof`**, **`extends`**, **`#`** for privacy.
* **Classes are sugar** over the prototype model, not a separate object system.
* Prefer **`===` / clear APIs** where relevant; choose factory vs class from **typing needs**, **team style**, and **privacy / composition** requirements.
